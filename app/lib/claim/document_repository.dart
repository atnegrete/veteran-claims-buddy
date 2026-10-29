import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../forms/file_upload.dart';
import 'claim_document.dart';
import 'claim_guide.dart';

class DocumentRepository {
  DocumentRepository(this._firestore, this._storage, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  Stream<List<ClaimDocument>> watch(String uid, String caseId) {
    return _docs(uid)
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .map((snapshot) {
          return [
            for (final doc in snapshot.docs)
              if (doc.data()['uploadStatus'] == 'uploaded')
                ClaimDocument.fromData(doc.id, doc.data()),
          ];
        });
  }

  Future<void> upload({
    required String uid,
    required String caseId,
    required String fileName,
    required Uint8List bytes,
    required String documentType,
    required String? documentDate,
    required ReportProgress onProgress,
    String packet = '',
  }) async {
    final contentType = documentContentType(fileName);
    final extension = contentType == null
        ? null
        : documentStorageExtension(contentType);
    if (contentType == null || extension == null) {
      throw const ClaimGuideFailure('Use a PDF, JPEG, or PNG.');
    }
    if (bytes.isEmpty || bytes.length > maxDocumentBytes) {
      throw const ClaimGuideFailure('That file must be under 100 MB.');
    }
    if (!documentTypes.containsKey(documentType)) {
      throw const ClaimGuideFailure('Choose what kind of file this is.');
    }
    await _refresh();
    final ref = _docs(uid).doc();
    final storagePath = 'users/$uid/documents/${ref.id}/original.$extension';
    final file = _storage.ref(storagePath);
    try {
      await uploadBytes(
        file: file,
        bytes: bytes,
        contentType: contentType,
        onProgress: onProgress,
      );
    } catch (_) {
      await _deleteFile(file);
      throw const FileUploadException(
        'That file could not be saved. Try the upload again.',
      );
    }
    try {
      await ref.set({
        'caseId': caseId,
        'name': _displayName(fileName),
        'originalFileName': _clip(fileName),
        'documentType': documentType,
        'contentType': contentType,
        'sizeBytes': bytes.length,
        'storagePath': storagePath,
        'uploadStatus': 'uploaded',
        'processingStatus': 'notStarted',
        'documentDate': documentDate,
        'pageCount': null,
        'providerName': null,
        'facilityName': null,
        'tags': <String>[],
        'sha256': null,
        'packet': packet,
        'schemaVersion': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      await _deleteFile(file);
      throw const FileUploadException(
        'That file could not be saved. Try the upload again.',
      );
    }
  }

  Future<void> _deleteFile(Reference file) async {
    try {
      await file.delete();
    } catch (_) {
      // The file may never have landed.
    }
  }

  Future<void> updateDetails({
    required String uid,
    required String documentId,
    required String documentType,
    required String? documentDate,
    String? packet,
  }) async {
    if (!documentTypes.containsKey(documentType)) {
      throw const ClaimGuideFailure('Choose what kind of file this is.');
    }
    await _refresh();
    final data = <String, dynamic>{
      'documentType': documentType,
      'documentDate': documentDate,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final stored = documentType == 'decisionLetter' || documentType == 'dd214'
        ? 'record'
        : packet;
    if (stored != null && stored.isNotEmpty) data['packet'] = stored;
    await _docs(uid).doc(documentId).update(data);
  }

  Stream<List<DocumentFact>> watchFacts(String uid, String documentId) {
    return _docs(uid)
        .doc(documentId)
        .collection('facts')
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              DocumentFact.fromData(doc.id, doc.data()),
          ],
        );
  }

  Future<void> reviewFact({
    required String uid,
    required String documentId,
    required String factId,
    required String reviewStatus,
    required String? correctedText,
  }) async {
    await _refresh();
    await _docs(uid).doc(documentId).collection('facts').doc(factId).update({
      'reviewStatus': reviewStatus,
      'correctedText': correctedText,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove({
    required String uid,
    required String documentId,
    required String storagePath,
  }) async {
    await _refresh();
    if (storagePath.isNotEmpty) {
      try {
        await _storage.ref(storagePath).delete();
      } catch (_) {
        // The record can still be removed if the file is already gone.
      }
    }
    await _docs(uid).doc(documentId).delete();
  }

  Future<void> _refresh() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.getIdToken();
    }
  }

  CollectionReference<Map<String, dynamic>> _docs(String uid) {
    return _firestore.collection('users').doc(uid).collection('documents');
  }

  String _displayName(String fileName) {
    final slash = fileName.replaceAll('\\', '/');
    final base = slash.split('/').last.trim();
    final name = base.isEmpty ? 'Document' : base;
    return name.length <= 120 ? name : name.substring(0, 120);
  }

  String _clip(String fileName) {
    final value = fileName.trim();
    return value.length <= 200 ? value : value.substring(0, 200);
  }
}

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
  );
});

final claimDocumentsProvider =
    StreamProvider.family<List<ClaimDocument>, String>((ref, caseId) {
      final uid = ref.watch(authControllerProvider).session?.uid;
      if (uid == null) return Stream.value(const []);
      return ref.watch(documentRepositoryProvider).watch(uid, caseId);
    });

final uploadDocumentProvider = Provider<UploadDocument>((ref) {
  final repository = ref.watch(documentRepositoryProvider);
  return ({
    required String caseId,
    required String fileName,
    required Uint8List bytes,
    required String documentType,
    required String? documentDate,
    required ReportProgress onProgress,
    String packet = '',
  }) {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.upload(
      uid: uid,
      caseId: caseId,
      fileName: fileName,
      bytes: bytes,
      documentType: documentType,
      documentDate: documentDate,
      onProgress: onProgress,
      packet: packet,
    );
  };
});

final updateDocumentProvider = Provider<UpdateDocument>((ref) {
  final repository = ref.watch(documentRepositoryProvider);
  return ({
    required String documentId,
    required String documentType,
    required String? documentDate,
    String? packet,
  }) {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.updateDetails(
      uid: uid,
      documentId: documentId,
      documentType: documentType,
      documentDate: documentDate,
      packet: packet,
    );
  };
});

final documentFactsProvider = StreamProvider.family<List<DocumentFact>, String>(
  (ref, documentId) {
    final uid = ref.watch(authControllerProvider).session?.uid;
    if (uid == null) return Stream.value(const []);
    return ref.watch(documentRepositoryProvider).watchFacts(uid, documentId);
  },
);

final reviewDocumentFactProvider = Provider<ReviewDocumentFact>((ref) {
  final repository = ref.watch(documentRepositoryProvider);
  return ({
    required String documentId,
    required String factId,
    required String reviewStatus,
    required String? correctedText,
  }) {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.reviewFact(
      uid: uid,
      documentId: documentId,
      factId: factId,
      reviewStatus: reviewStatus,
      correctedText: correctedText,
    );
  };
});

final removeDocumentProvider = Provider<RemoveDocument>((ref) {
  final repository = ref.watch(documentRepositoryProvider);
  return ({required String documentId, required String storagePath}) {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.remove(
      uid: uid,
      documentId: documentId,
      storagePath: storagePath,
    );
  };
});

typedef UploadDocument = Future<void> Function({
  required String caseId,
  required String fileName,
  required Uint8List bytes,
  required String documentType,
  required String? documentDate,
  required ReportProgress onProgress,
  String packet,
});

typedef ReviewDocumentFact = Future<void> Function({
  required String documentId,
  required String factId,
  required String reviewStatus,
  required String? correctedText,
});

typedef UpdateDocument = Future<void> Function({
  required String documentId,
  required String documentType,
  required String? documentDate,
  String? packet,
});

typedef RemoveDocument = Future<void> Function({
  required String documentId,
  required String storagePath,
});
