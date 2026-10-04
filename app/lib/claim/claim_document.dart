const maxDocumentBytes = 100 * 1024 * 1024;

const documentTypes = <String, String>{
  'serviceTreatmentRecord': 'Service treatment record',
  'privateMedicalRecord': 'Private medical record',
  'vaMedicalRecord': 'VA medical record',
  'decisionLetter': 'Decision letter',
  'dbq': 'Doctor exam form',
  'cpExam': 'Exam report',
  'personalStatement': 'Personal statement',
  'buddyStatement': 'Buddy statement',
  'dd214': 'DD214',
  'personnelRecord': 'Personnel record',
  'imaging': 'Imaging',
  'lab': 'Lab result',
  'nexusOpinion': 'Medical opinion',
  'vaCorrespondence': 'VA letter',
  'other': 'Something else',
};

class ClaimDocument {
  const ClaimDocument({
    required this.id,
    required this.caseId,
    required this.name,
    required this.documentType,
    required this.uploadStatus,
    required this.storagePath,
    this.documentDate,
    this.pageCount,
    this.processingStatus = 'notStarted',
  });

  final String id;
  final String caseId;
  final String name;
  final String documentType;
  final String uploadStatus;
  final String storagePath;
  final String? documentDate;
  final int? pageCount;
  final String processingStatus;

  static ClaimDocument fromData(String id, Map<String, dynamic> data) {
    final date = data['documentDate'];
    final pages = data['pageCount'];
    return ClaimDocument(
      id: id,
      caseId: data['caseId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      documentType: data['documentType'] as String? ?? 'other',
      uploadStatus: data['uploadStatus'] as String? ?? 'uploading',
      storagePath: data['storagePath'] as String? ?? '',
      documentDate: date is String && date.isNotEmpty ? date : null,
      pageCount: pages is int && pages > 0 ? pages : null,
      processingStatus: data['processingStatus'] as String? ?? 'notStarted',
    );
  }
}

/// PDF, JPEG, and PNG only. HEIC waits until a file can be read on the server.
String? documentContentType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  return null;
}

String? documentStorageExtension(String contentType) {
  return switch (contentType) {
    'application/pdf' => 'pdf',
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    _ => null,
  };
}

/// What to tell the Veteran about reading. Null until the file is saved.
String? documentReadingLabel(String uploadStatus, String processingStatus) {
  if (uploadStatus != 'uploaded') return null;
  return switch (processingStatus) {
    'notStarted' || 'queued' => 'Waiting to read this file.',
    'processing' => 'Reading this file.',
    'needsReview' => 'Review the statements from this file.',
    'complete' => 'Nothing in this file needed a review.',
    'failed' => 'This file could not be read.',
    _ => null,
  };
}

const factTypeLabels = <String, String>{
  'diagnosis': 'Diagnosis',
  'symptom': 'Symptom',
  'serviceEvent': 'In service',
  'treatment': 'Treatment',
  'medication': 'Medication',
  'imagingFinding': 'Imaging',
  'functionalImpact': 'Daily effect',
  'medicalOpinion': 'Medical opinion',
  'decisionFinding': 'Decision',
  'other': 'Other',
};

class DocumentFact {
  const DocumentFact({
    required this.id,
    required this.factText,
    required this.factType,
    required this.reviewStatus,
    this.conditionText,
    this.correctedText,
    this.eventDate,
    this.page,
  });

  final String id;
  final String factText;
  final String factType;
  final String reviewStatus;
  final String? conditionText;
  final String? correctedText;
  final String? eventDate;
  final int? page;

  static DocumentFact fromData(String id, Map<String, dynamic> data) {
    final condition = data['conditionText'];
    final corrected = data['correctedText'];
    final date = data['eventDate'];
    final page = data['page'];
    return DocumentFact(
      id: id,
      factText: data['factText'] as String? ?? '',
      factType: data['factType'] as String? ?? 'other',
      reviewStatus: data['reviewStatus'] as String? ?? 'unreviewed',
      conditionText: condition is String && condition.isNotEmpty
          ? condition
          : null,
      correctedText: corrected is String && corrected.isNotEmpty
          ? corrected
          : null,
      eventDate: date is String && date.isNotEmpty ? date : null,
      page: page is int && page > 0 ? page : null,
    );
  }
}
