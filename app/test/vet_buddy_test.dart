import 'package:app/claim/vet_buddy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat refuses a social security number and a long account number', () {
    expect(blockedChatIdentifier('123-45-6789'), 'ssn');
    expect(blockedChatIdentifier('the number is 123456789'), 'ssn');
    expect(blockedChatIdentifier('call 5551234567'), isNull);
    expect(blockedChatIdentifier('account 1234567890123'), 'account');
    expect(blockedChatIdentifier('What is still missing?'), isNull);
  });

  test('a session line says when the next message drops the history', () {
    final open = DateTime.utc(2026, 10, 2, 20, 36);
    expect(
      sessionStatusLine(open, DateTime.utc(2026, 10, 2, 20, 20)),
      contains('This session is open until'),
    );
    expect(
      sessionStatusLine(open, DateTime.utc(2026, 10, 2, 20, 36)),
      'This session ended. Your next message starts a new one and will not include this conversation.',
    );
    expect(sessionStatusLine(null, open), isNull);
  });

  test('a new session is marked between turns and old turns stay visible', () {
    const earlier = VetBuddyMessage(id: 'old', role: 'user', content: 'Before');
    const first = VetBuddyMessage(
      id: 'a',
      role: 'user',
      content: 'Now',
      sessionId: 'session-1',
    );
    const second = VetBuddyMessage(
      id: 'b',
      role: 'assistant',
      content: 'Answer',
      sessionId: 'session-2',
    );
    final rows = chatRows(const [earlier, first, second]);
    expect(rows.where((row) => row.divider).length, 2);
    expect(rows.where((row) => row.message != null).length, 3);
    expect(chatRows(const [first]).where((row) => row.divider), isEmpty);
  });

  test('a link opens the matching claim screen', () {
    expect(
      vetBuddyLocation(
        'case-1',
        const VetBuddyLink(target: 'exams', label: 'C&P Prep'),
      ),
      '/cases/case-1/exams',
    );
    expect(
      vetBuddyLocation(
        'case-1',
        const VetBuddyLink(
          target: 'issue',
          label: 'Low back pain',
          issueId: 'back',
        ),
      ),
      '/cases/case-1/issues/back',
    );
    expect(
      vetBuddyLocation(
        'case-1',
        const VetBuddyLink(
          target: 'document',
          label: 'Decision.pdf',
          documentId: 'doc-1',
        ),
      ),
      '/cases/case-1/evidence/doc-1/facts',
    );
    expect(
      vetBuddyLocation(
        'case-1',
        const VetBuddyLink(target: 'https://example.com', label: 'Outside'),
      ),
      isNull,
    );
  });
}
