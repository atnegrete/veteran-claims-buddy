import 'package:app/claim/claim_document.dart';
import 'package:app/claim/claim_sections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a document accepts pdf jpeg and png under 100 MB', () {
    expect(documentContentType('records.PDF'), 'application/pdf');
    expect(documentContentType('photo.jpeg'), 'image/jpeg');
    expect(documentContentType('scan.png'), 'image/png');
    expect(documentContentType('photo.heic'), isNull);
    expect(documentStorageExtension('image/jpeg'), 'jpg');
    expect(maxDocumentBytes, 100 * 1024 * 1024);
    expect(documentsStatus(0), ClaimSectionStatus.notStarted);
    expect(documentsStatus(1), ClaimSectionStatus.inProgress);
    final document = ClaimDocument.fromData('doc-1', const {
      'caseId': 'case-1',
      'name': 'Decision.pdf',
      'documentType': 'decisionLetter',
      'uploadStatus': 'uploaded',
      'storagePath': 'users/u/documents/doc-1/original.pdf',
      'pageCount': 4,
    });
    expect(document.pageCount, 4);
    expect(
      documentReadingLabel('uploaded', 'needsReview'),
      'Review the statements from this file.',
    );
    expect(documentReadingLabel('uploading', 'processing'), isNull);
    final fact = DocumentFact.fromData('fact-1', const {
      'factText': 'Low-back pain after a lifting injury.',
      'factType': 'symptom',
      'reviewStatus': 'corrected',
      'correctedText': 'Pain after lifting in service.',
      'page': 7,
    });
    expect(fact.factText, 'Low-back pain after a lifting injury.');
    expect(fact.correctedText, 'Pain after lifting in service.');
    expect(fact.page, 7);
    expect(
      ClaimDocument.fromData('doc-2', const {'pageCount': null}).pageCount,
      isNull,
    );
  });
}
