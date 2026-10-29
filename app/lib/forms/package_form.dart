/// A form the Veteran added to their package for one claim. This is the live
/// tracker that merges the old Forms and Package sections: each entry is a form
/// on this claim, its answers, and its generation state. Nothing is filed.
library;

/// Where a package form is in its own small lifecycle.
enum PackageFormStatus {
  /// Added, auto-filled from what the claim knows; may still need fields or a
  /// statement.
  draft,

  /// A statement draft or required field is still outstanding.
  needsInput,

  /// Ready to preview / generate.
  ready,
}

PackageFormStatus packageFormStatusFrom(String? value) {
  return switch (value) {
    'needsInput' => PackageFormStatus.needsInput,
    'ready' => PackageFormStatus.ready,
    _ => PackageFormStatus.draft,
  };
}

String packageFormStatusName(PackageFormStatus status) {
  return switch (status) {
    PackageFormStatus.needsInput => 'needsInput',
    PackageFormStatus.ready => 'ready',
    PackageFormStatus.draft => 'draft',
  };
}

/// State of the AI-drafted statement, for statement forms only.
enum StatementStatus { none, pending, drafted }

StatementStatus statementStatusFrom(String? value) {
  return switch (value) {
    'pending' => StatementStatus.pending,
    'drafted' => StatementStatus.drafted,
    _ => StatementStatus.none,
  };
}

String statementStatusName(StatementStatus status) {
  return switch (status) {
    StatementStatus.pending => 'pending',
    StatementStatus.drafted => 'drafted',
    StatementStatus.none => 'none',
  };
}

class PackageForm {
  const PackageForm({
    required this.id,
    required this.caseId,
    required this.formNumber,
    required this.status,
    required this.multiplicityKey,
    required this.displayLabel,
    required this.answers,
    required this.sectionDrafts,
    required this.statementStatus,
    this.statementBody,
    this.revisionId,
    this.generatedFormId,
    this.packet = '',
    this.conditionId = '',
    this.nexusKind = '',
  });

  final String id;
  final String caseId;
  final String formNumber;
  final PackageFormStatus status;

  /// Distinguishes multiple entries of the same form (witness, provider,
  /// employer, issue). Empty for single forms.
  final String multiplicityKey;

  /// A short label for the package list (witness name, provider, issue).
  final String displayLabel;

  /// Per-form question answers.
  final Map<String, String> answers;

  /// Reviewed AI prose for a tailored section, keyed by claim-issue id. On
  /// 21-526EZ this is the "how this condition relates to service" cell. A blank
  /// entry is omitted so the assembled note from the issue is used instead.
  final Map<String, String> sectionDrafts;

  final StatementStatus statementStatus;
  final String? statementBody;
  final String? revisionId;
  final String? generatedFormId;

  /// `newClaim`, `supplemental`, `higherLevel`, `board`, `record`, or `shared`.
  final String packet;

  /// The condition this nexus letter is for. Empty for other forms.
  final String conditionId;

  /// `direct`, `secondary`, `aggravation`, `supplemental`, or empty.
  final String nexusKind;

  static PackageForm fromData(String id, Map<String, dynamic> data) {
    final rawAnswers = data['answers'];
    final answers = <String, String>{};
    if (rawAnswers is Map) {
      rawAnswers.forEach((key, value) {
        if (key is String && value is String) answers[key] = value;
      });
    }
    final rawDrafts = data['sectionDrafts'];
    final sectionDrafts = <String, String>{};
    if (rawDrafts is Map) {
      rawDrafts.forEach((key, value) {
        if (key is String && value is String) sectionDrafts[key] = value;
      });
    }
    final body = data['statementBody'];
    final revision = data['revisionId'];
    final generated = data['generatedFormId'];
    return PackageForm(
      id: id,
      caseId: data['caseId'] as String? ?? '',
      formNumber: data['formNumber'] as String? ?? '',
      status: packageFormStatusFrom(data['status'] as String?),
      multiplicityKey: data['multiplicityKey'] as String? ?? '',
      displayLabel: data['displayLabel'] as String? ?? '',
      answers: answers,
      sectionDrafts: sectionDrafts,
      statementStatus: statementStatusFrom(data['statementStatus'] as String?),
      statementBody: body is String && body.isNotEmpty ? body : null,
      revisionId: revision is String && revision.isNotEmpty ? revision : null,
      generatedFormId: generated is String && generated.isNotEmpty
          ? generated
          : null,
      packet: data['packet'] as String? ?? '',
      conditionId: data['conditionId'] as String? ?? '',
      nexusKind: data['nexusKind'] as String? ?? '',
    );
  }
}
