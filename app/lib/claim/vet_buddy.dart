import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/auth_redirect.dart';

/// A Social Security number or a long account number must not be sent.
String? blockedChatIdentifier(String text) {
  if (RegExp(r'\b\d{3}-\d{2}-\d{4}\b').hasMatch(text)) return 'ssn';
  if (RegExp(r'\b\d{9}\b').hasMatch(text)) return 'ssn';
  if (RegExp(r'\b\d{13,}\b').hasMatch(text)) return 'account';
  return null;
}

class VetBuddyChat {
  const VetBuddyChat({this.activeSessionId, this.expiresAt, this.startedAt});

  final String? activeSessionId;
  final DateTime? expiresAt;
  final DateTime? startedAt;

  static const empty = VetBuddyChat();

  bool isOpenAt(DateTime now) => expiresAt != null && expiresAt!.isAfter(now);

  static VetBuddyChat fromData(Map<String, dynamic> data) {
    return VetBuddyChat(
      activeSessionId: data['activeSessionId'] as String?,
      expiresAt: _time(data['sessionExpiresAt']),
      startedAt: _time(data['sessionStartedAt']),
    );
  }
}

class VetBuddyLink {
  const VetBuddyLink({
    required this.target,
    required this.label,
    this.issueId,
    this.documentId,
  });

  final String target;
  final String label;
  final String? issueId;
  final String? documentId;

  static VetBuddyLink? fromData(Map<String, dynamic> data) {
    final target = data['target'] as String? ?? '';
    final label = data['label'] as String? ?? '';
    if (target.isEmpty || label.isEmpty) return null;
    return VetBuddyLink(
      target: target,
      label: label,
      issueId: data['issueId'] as String?,
      documentId: data['documentId'] as String?,
    );
  }
}

class VetBuddyMessage {
  const VetBuddyMessage({
    required this.id,
    required this.role,
    required this.content,
    this.createdAt,
    this.sessionId,
    this.links = const [],
  });

  final String id;
  final String role;
  final String content;
  final DateTime? createdAt;
  final String? sessionId;
  final List<VetBuddyLink> links;

  bool get fromAssistant => role == 'assistant';

  static VetBuddyMessage fromData(String id, Map<String, dynamic> data) {
    return VetBuddyMessage(
      id: id,
      role: data['role'] as String? ?? 'assistant',
      content: data['content'] as String? ?? '',
      createdAt: _time(data['createdAt']),
      sessionId: data['sessionId'] as String?,
      links: _links(data['links']),
    );
  }
}

class ChatRow {
  const ChatRow.message(this.message) : divider = false;
  const ChatRow.divider() : message = null, divider = true;

  final VetBuddyMessage? message;
  final bool divider;
}

List<ChatRow> chatRows(List<VetBuddyMessage> messages) {
  final rows = <ChatRow>[];
  String? previous;
  var started = false;
  for (final message in messages) {
    final key = message.sessionId ?? '';
    if (started && key != previous) {
      rows.add(const ChatRow.divider());
    }
    started = true;
    previous = key;
    rows.add(ChatRow.message(message));
  }
  return rows;
}

String? sessionStatusLine(DateTime? expiresAt, DateTime now) {
  if (expiresAt == null) return null;
  if (!expiresAt.isAfter(now)) {
    return 'This session ended. Your next message starts a new one and will not include this conversation.';
  }
  return 'This session is open until ${chatTimeLabel(expiresAt)}. It uses the claim from when the session started.';
}

String chatTimeLabel(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String? vetBuddyLocation(String caseId, VetBuddyLink link) {
  switch (link.target) {
    case 'questions':
      return AuthRoutes.caseQuestions(caseId);
    case 'issues':
      return AuthRoutes.caseIssues(caseId);
    case 'documents':
      return AuthRoutes.caseDocuments(caseId);
    case 'forms':
      return AuthRoutes.casePrepare(caseId);
    case 'package':
      return AuthRoutes.casePackage(caseId);
    case 'exams':
      return AuthRoutes.caseExams(caseId);
    case 'decisions':
      return AuthRoutes.caseDecisions(caseId);
    case 'issue':
      final issueId = link.issueId;
      if (issueId == null || issueId.isEmpty) return null;
      return AuthRoutes.caseIssue(caseId, issueId);
    case 'document':
      final documentId = link.documentId;
      if (documentId == null || documentId.isEmpty) return null;
      return AuthRoutes.caseDocumentFacts(caseId, documentId);
    default:
      return null;
  }
}

DateTime? _time(Object? value) {
  if (value is Timestamp) return value.toDate();
  return null;
}

List<VetBuddyLink> _links(Object? raw) {
  if (raw is! List) return const [];
  final links = <VetBuddyLink>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final link = VetBuddyLink.fromData(Map<String, dynamic>.from(item));
    if (link != null) links.add(link);
  }
  return links;
}
