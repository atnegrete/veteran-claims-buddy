import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../forms/canonical_profile.dart';
import '../forms/form_catalog.dart';
import '../forms/va_form_mapping.dart';
import '../onboarding/onboarding_progress.dart';
import 'claim_guide.dart';
import 'identifiers_repository.dart';

/// Server-backed preparation: AI statement drafting and deterministic PDF
/// generation. Both are Cloud Functions; nothing here files with the VA.
/// A watermarked preview PDF plus the fields still blank, returned by
/// [FormPreparationService.preview].
class FormPreviewResult {
  const FormPreviewResult({required this.bytes, required this.missing});

  final Uint8List bytes;
  final List<FormPreviewGap> missing;
}

/// A required field the preview could not fill yet.
class FormPreviewGap {
  const FormPreviewGap({required this.label, this.group});

  final String label;
  final String? group;
}

/// One interview question returned by the Nexus Letters gap interview.
class NexusQuestion {
  const NexusQuestion({required this.slotId, required this.prompt, this.help = ''});

  final String slotId;
  final String prompt;
  final String help;
}

/// The state of the Nexus Letters interview after one step. When [done] is
/// true, [question] is null and the letters can be generated.
class NexusInterviewState {
  const NexusInterviewState({
    required this.done,
    this.question,
    this.answered = 0,
    this.total = 0,
  });

  final bool done;
  final NexusQuestion? question;
  final int answered;
  final int total;
}

/// The two generated Nexus Letters as watermarked PDF bytes: the physician
/// draft and the veteran-signable statement.
class NexusLetters {
  const NexusLetters({required this.doctorBytes, required this.vetBytes});

  final Uint8List doctorBytes;
  final Uint8List vetBytes;
}

class FormPreparationService {
  FormPreparationService(
    this._functions, {
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  /// Renders a watermarked preview filled from saved identity data, the drafted
  /// statement, and [sectionDrafts] (reviewed prose, including unsaved edits).
  /// Returns the PDF bytes and any required auto fields still blank.
  Future<FormPreviewResult> preview({
    required String packageFormId,
    Map<String, String> sectionDrafts = const {},
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken();
    try {
      final result = await _functions.httpsCallable('previewForm').call({
        'packageFormId': packageFormId,
        'sectionDrafts': sectionDrafts,
      });
      final data = result.data;
      if (data is! Map) {
        throw const ClaimGuideFailure('The preview came back empty.');
      }
      final missing = <FormPreviewGap>[];
      final rawMissing = data['missing'];
      if (rawMissing is List) {
        for (final entry in rawMissing) {
          if (entry is Map) {
            missing.add(
              FormPreviewGap(
                label: '${entry['label'] ?? ''}',
                group: entry['group'] as String?,
              ),
            );
          }
        }
      }
      final encoded = data['pdfBase64'];
      if (encoded is String && encoded.isNotEmpty) {
        return FormPreviewResult(bytes: base64Decode(encoded), missing: missing);
      }
      final path = data['storagePath'];
      if (path is! String || path.isEmpty) {
        throw const ClaimGuideFailure('The preview came back empty.');
      }
      final bytes = await _storage.ref(path).getData(20 * 1024 * 1024);
      if (bytes == null) {
        throw const ClaimGuideFailure('The preview could not be loaded.');
      }
      return FormPreviewResult(bytes: bytes, missing: missing);
    } on FirebaseFunctionsException catch (error) {
      final message = error.message;
      if (message != null && message.isNotEmpty) {
        throw ClaimGuideFailure(message);
      }
      throw ClaimGuideFailure('The preview could not be built (${error.code}).');
    } on FirebaseException catch (error) {
      final message = error.message;
      throw ClaimGuideFailure(
        message != null && message.isNotEmpty
            ? message
            : 'The preview file could not be loaded (${error.code}).',
      );
    }
  }

  /// A clean PDF for the Veteran to keep. It is not stored on the server.
  Future<Uint8List> download({
    required String packageFormId,
    required String legalName,
    required bool signed,
    String ssn = '',
    String signedOn = '',
    Map<String, String> sectionDrafts = const {},
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken();
    try {
      final result = await _functions.httpsCallable('downloadForm').call({
        'packageFormId': packageFormId,
        'legalName': legalName,
        'signed': signed,
        'ssn': ssn,
        'signedOn': signedOn,
        'sectionDrafts': sectionDrafts,
      });
      final data = result.data;
      if (data is! Map) {
        throw const ClaimGuideFailure('The form could not be downloaded.');
      }
      final encoded = data['pdfBase64'];
      if (encoded is! String || encoded.isEmpty) {
        throw const ClaimGuideFailure('The form could not be downloaded.');
      }
      return base64Decode(encoded);
    } on FirebaseFunctionsException catch (error) {
      final message = error.message;
      if (message != null && message.isNotEmpty) {
        throw ClaimGuideFailure(message);
      }
      throw const ClaimGuideFailure('The form could not be downloaded.');
    }
  }

  /// Drafts the "how this condition relates to service" paragraph for one
  /// claimed condition, from the connection notes already saved on that issue.
  Future<String> draftDisabilityExplanation({
    required String caseId,
    required String issueId,
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken();
    try {
      final result = await _functions
          .httpsCallable('draftDisabilityExplanation')
          .call({'caseId': caseId, 'issueId': issueId});
      final data = result.data;
      final body = data is Map ? data['statement'] : null;
      if (body is String && body.trim().isNotEmpty) return body;
      throw const ClaimGuideFailure('The draft came back empty. Try again.');
    } on FirebaseFunctionsException catch (error) {
      final message = error.message;
      if ((error.code == 'invalid-argument' ||
              error.code == 'failed-precondition' ||
              error.code == 'not-found') &&
          message != null &&
          message.isNotEmpty) {
        throw ClaimGuideFailure(message);
      }
      throw const ClaimGuideFailure('The draft could not be written. Try again.');
    }
  }

  /// Drafts a statement for a statement form. [statementKind] is `lay` or
  /// `doctorDraft`. Returns the drafted body.
  Future<String> draftStatement({
    required String caseId,
    required String formNumber,
    required FormStatementKind kind,
    required Map<String, String> answers,
    String nexusKind = '',
    String reasonText = '',
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken();
    try {
      final result = await _functions.httpsCallable('draftFormStatement').call({
        'caseId': caseId,
        'formNumber': formNumber,
        'statementKind': kind == FormStatementKind.doctorDraft
            ? 'doctorDraft'
            : 'lay',
        'answers': answers,
        'nexusKind': nexusKind,
        'reasonText': reasonText,
      });
      final data = result.data;
      final body = data is Map ? data['statement'] : null;
      if (body is String && body.trim().isNotEmpty) return body;
      throw const ClaimGuideFailure('The draft came back empty. Try again.');
    } on FirebaseFunctionsException catch (error) {
      final message = error.message;
      if ((error.code == 'invalid-argument' ||
              error.code == 'failed-precondition') &&
          message != null &&
          message.isNotEmpty) {
        throw ClaimGuideFailure(message);
      }
      throw const ClaimGuideFailure(
        'The draft could not be written. Try again.',
      );
    }
  }

  /// One step of the Nexus Letters interview. Pass [answer] to record the reply
  /// to the open question; omit it on the first call. Pass [restart] to clear
  /// the interview and start over. Returns the next question, or `done`.
  Future<NexusInterviewState> nexusInterviewStep({
    required String caseId,
    required String issueId,
    String nexusKind = '',
    String? answer,
    bool restart = false,
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken();
    try {
      final payload = <String, dynamic>{
        'caseId': caseId,
        'issueId': issueId,
        'nexusKind': nexusKind,
        'restart': restart,
      };
      if (answer != null) payload['answer'] = answer;
      final result = await _functions
          .httpsCallable('nexusInterviewStep')
          .call(payload);
      final data = result.data;
      if (data is! Map) {
        throw const ClaimGuideFailure('The interview could not be opened.');
      }
      NexusQuestion? question;
      final raw = data['question'];
      if (raw is Map) {
        question = NexusQuestion(
          slotId: '${raw['slotId'] ?? ''}',
          prompt: '${raw['prompt'] ?? ''}',
          help: '${raw['help'] ?? ''}',
        );
      }
      final progress = data['progress'];
      return NexusInterviewState(
        done: data['done'] == true,
        question: question,
        answered: progress is Map ? (progress['answered'] as num?)?.toInt() ?? 0 : 0,
        total: progress is Map ? (progress['total'] as num?)?.toInt() ?? 0 : 0,
      );
    } on FirebaseFunctionsException catch (error) {
      final message = error.message;
      if ((error.code == 'invalid-argument' ||
              error.code == 'failed-precondition' ||
              error.code == 'not-found') &&
          message != null &&
          message.isNotEmpty) {
        throw ClaimGuideFailure(message);
      }
      throw const ClaimGuideFailure('The interview could not continue. Try again.');
    }
  }

  /// Generates both Nexus Letters once the interview is complete. Returns the
  /// watermarked PDF bytes for the physician draft and the veteran statement.
  Future<NexusLetters> generateNexusLetters({
    required String caseId,
    required String issueId,
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken();
    try {
      final result = await _functions.httpsCallable('generateNexusLetters').call({
        'caseId': caseId,
        'issueId': issueId,
      });
      final data = result.data;
      final doctor = data is Map ? data['doctorPdfBase64'] : null;
      final vet = data is Map ? data['vetPdfBase64'] : null;
      if (doctor is! String ||
          doctor.isEmpty ||
          vet is! String ||
          vet.isEmpty) {
        throw const ClaimGuideFailure('The letters came back empty. Try again.');
      }
      return NexusLetters(
        doctorBytes: base64Decode(doctor),
        vetBytes: base64Decode(vet),
      );
    } on FirebaseFunctionsException catch (error) {
      final message = error.message;
      if ((error.code == 'invalid-argument' ||
              error.code == 'failed-precondition' ||
              error.code == 'not-found') &&
          message != null &&
          message.isNotEmpty) {
        throw ClaimGuideFailure(message);
      }
      throw const ClaimGuideFailure('The letters could not be prepared. Try again.');
    }
  }

  /// Applies one natural-language change to one Nexus Letter and returns the
  /// updated watermarked PDF bytes. [letter] is `doctor` or `veteran`.
  Future<Uint8List> reviseNexusLetter({
    required String caseId,
    required String issueId,
    required String letter,
    required String instruction,
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken();
    try {
      final result = await _functions.httpsCallable('reviseNexusLetter').call({
        'caseId': caseId,
        'issueId': issueId,
        'letter': letter,
        'instruction': instruction,
      });
      final data = result.data;
      final pdf = data is Map ? data['pdfBase64'] : null;
      if (pdf is! String || pdf.isEmpty) {
        throw const ClaimGuideFailure('The change came back empty. Try again.');
      }
      return base64Decode(pdf);
    } on FirebaseFunctionsException catch (error) {
      final message = error.message;
      if ((error.code == 'invalid-argument' ||
              error.code == 'failed-precondition' ||
              error.code == 'not-found') &&
          message != null &&
          message.isNotEmpty) {
        throw ClaimGuideFailure(message);
      }
      throw const ClaimGuideFailure('The change could not be made. Try again.');
    }
  }

  /// A clean, unwatermarked print copy of one generated Nexus Letter for the
  /// Veteran to keep. [letter] is `doctor` or `veteran`. The letters must
  /// already be generated; nothing is stored from this call.
  Future<Uint8List> downloadNexusLetter({
    required String caseId,
    required String issueId,
    required String letter,
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken();
    try {
      final result = await _functions.httpsCallable('downloadNexusLetter').call({
        'caseId': caseId,
        'issueId': issueId,
        'letter': letter,
      });
      final data = result.data;
      final pdf = data is Map ? data['pdfBase64'] : null;
      if (pdf is! String || pdf.isEmpty) {
        throw const ClaimGuideFailure('The copy came back empty. Try again.');
      }
      return base64Decode(pdf);
    } on FirebaseFunctionsException catch (error) {
      final message = error.message;
      if ((error.code == 'invalid-argument' ||
              error.code == 'failed-precondition' ||
              error.code == 'not-found') &&
          message != null &&
          message.isNotEmpty) {
        throw ClaimGuideFailure(message);
      }
      throw const ClaimGuideFailure('The copy could not be prepared. Try again.');
    }
  }

  /// Fills the official PDF server-side for a package form. Returns the
  /// generated form id. Only works once that form's revision template is
  /// imported (owner gate M13).
  Future<String> generate({required String packageFormId}) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken();
    try {
      final result = await _functions.httpsCallable('generateForm').call({
        'packageFormId': packageFormId,
      });
      final data = result.data;
      final id = data is Map ? data['generatedFormId'] : null;
      if (id is String && id.isNotEmpty) return id;
      throw const ClaimGuideFailure('The form could not be generated.');
    } on FirebaseFunctionsException catch (error) {
      final message = error.message;
      if (error.code == 'failed-precondition' &&
          message != null &&
          message.isNotEmpty) {
        throw ClaimGuideFailure(message);
      }
      throw const ClaimGuideFailure('The form could not be generated.');
    }
  }
}

final formPreparationServiceProvider = Provider<FormPreparationService>((ref) {
  return FormPreparationService(
    FirebaseFunctions.instanceFor(region: 'us-central1'),
  );
});

/// Reads the newest published mapping for a form, or null when none is
/// published yet (before the owner runs the acquisition for that form).
class VaFormMappingRepository {
  VaFormMappingRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<VaFormMapping?> newest(String formNumber) async {
    final snapshot = await _firestore
        .collection('vaFormMappings')
        .where('formNumber', isEqualTo: formNumber)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final docs = snapshot.docs.toList()
      ..sort((a, b) {
        final ar = a.data()['revisionId'] as String? ?? a.id;
        final br = b.data()['revisionId'] as String? ?? b.id;
        return br.compareTo(ar);
      });
    return VaFormMapping.fromData(docs.first.id, docs.first.data());
  }
}

final vaFormMappingRepositoryProvider = Provider<VaFormMappingRepository>((ref) {
  return VaFormMappingRepository(FirebaseFirestore.instance);
});

final vaFormMappingProvider =
    FutureProvider.family<VaFormMapping?, String>((ref, formNumber) {
      return ref.watch(vaFormMappingRepositoryProvider).newest(formNumber);
    });

/// Assembles the canonical profile from the Veteran's stored data (identifiers,
/// profile, service periods). Mirrors `functions/form_generation.js`
/// `canonicalFromDocs` so the on-screen preview and the PDF agree. No AI.
final canonicalProfileProvider = FutureProvider<CanonicalProfile>((ref) async {
  final uid = ref.watch(authControllerProvider).session?.uid;
  if (uid == null) return CanonicalProfile.empty;
  final ids = await ref.watch(identifiersProvider.future);
  final userDoc = await ref.watch(onboardingDocProvider.future);
  final email = ref.watch(authControllerProvider).session?.email;
  final periods = await ref.read(onboardingRepositoryProvider).servicePeriods(uid);

  final values = <String, String>{};
  void put(String key, String? value) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) values[key] = trimmed;
  }

  put(CanonicalKeys.legalFirstName, ids.legalFirstName);
  put(CanonicalKeys.legalMiddleName, ids.legalMiddleName);
  put(CanonicalKeys.legalLastName, ids.legalLastName);
  put(CanonicalKeys.dateOfBirth, ids.dateOfBirth);
  put(CanonicalKeys.ssn, ids.ssn);
  put(CanonicalKeys.vaFileNumber, ids.vaFileNumber);
  put(CanonicalKeys.mailingStreet, ids.mailingStreet);
  put(CanonicalKeys.mailingUnit, ids.mailingUnit);
  put(CanonicalKeys.mailingCity, ids.mailingCity);
  put(CanonicalKeys.mailingState, ids.mailingState);
  put(CanonicalKeys.mailingZip, ids.mailingZip);
  put(
    CanonicalKeys.phone,
    ids.phone.isNotEmpty ? ids.phone : userDoc?['phone'] as String?,
  );
  put(CanonicalKeys.email, email ?? userDoc?['email'] as String?);
  if (periods.isNotEmpty) {
    put(CanonicalKeys.serviceBranch, periods.first.branch);
    put(CanonicalKeys.serviceEntryDate, periods.first.startDate);
    put(CanonicalKeys.serviceSeparationDate, periods.last.endDate);
  }
  values.addAll(deriveCanonicalValues(values));
  return CanonicalProfile(values);
});
