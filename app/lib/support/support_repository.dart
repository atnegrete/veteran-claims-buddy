import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'support_ticket.dart';

class SupportRepository {
  SupportRepository(this._firestore, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _tickets(String uid) {
    return _firestore.collection('users').doc(uid).collection('supportTickets');
  }

  Stream<List<SupportTicket>> watchTickets(String uid) {
    return _tickets(uid).snapshots().map((snapshot) {
      final tickets = <SupportTicket>[
        for (final doc in snapshot.docs) _ticketFromDoc(doc),
      ];
      tickets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return tickets;
    });
  }

  Stream<SupportTicket?> watchTicket(String uid, String ticketId) {
    return _tickets(uid).doc(ticketId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return _ticketFromDoc(snapshot);
    });
  }

  Stream<List<SupportMessage>> watchMessages(String uid, String ticketId) {
    return _tickets(uid)
        .doc(ticketId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
          final messages = <SupportMessage>[
            for (final doc in snapshot.docs) _messageFromDoc(doc),
          ];
          messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return messages;
        });
  }

  Future<String> createTicket({
    required String uid,
    required String subject,
    required String category,
    required String message,
  }) async {
    final cleanSubject = normalizeSupportText(subject);
    final cleanMessage = message.trim();
    if (!supportSubjectOk(cleanSubject) ||
        !supportMessageOk(cleanMessage) ||
        !supportCategories.containsKey(category)) {
      throw const SupportFailure(
        'Add a subject and a message, then try again.',
      );
    }
    await _refreshToken();
    final ticket = _tickets(uid).doc();
    final now = FieldValue.serverTimestamp();
    await ticket.set({
      'uid': uid,
      'subject': cleanSubject,
      'category': category,
      'status': 'open',
      'priority': 'normal',
      'lastMessageAt': now,
      'createdAt': now,
      'updatedAt': now,
      'schemaVersion': 1,
    });
    await ticket.collection('messages').add({
      'body': cleanMessage,
      'authorRole': 'veteran',
      'createdAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    });
    return ticket.id;
  }

  Future<void> reply({
    required String uid,
    required String ticketId,
    required String message,
    required String currentStatus,
  }) async {
    final cleanMessage = message.trim();
    if (!supportMessageOk(cleanMessage)) {
      throw const SupportFailure('Add a message, then try again.');
    }
    if (currentStatus == 'closed') {
      throw const SupportFailure('This ticket is closed.');
    }
    await _refreshToken();
    final ticket = _tickets(uid).doc(ticketId);
    await ticket.collection('messages').add({
      'body': cleanMessage,
      'authorRole': 'veteran',
      'createdAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    });
    await ticket.update({
      'status': 'waitingOnSupport',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> close({required String uid, required String ticketId}) async {
    await _refreshToken();
    await _tickets(uid).doc(ticketId).update({
      'status': 'closed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _refreshToken() {
    final user = _auth.currentUser;
    if (user == null) return Future.value();
    return user.getIdToken(true);
  }
}

SupportTicket _ticketFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? {};
  return SupportTicket(
    id: doc.id,
    subject: data['subject'] as String? ?? '',
    category: data['category'] as String? ?? 'other',
    status: data['status'] as String? ?? 'open',
    updatedAt: _date(data['updatedAt']),
  );
}

SupportMessage _messageFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? {};
  return SupportMessage(
    id: doc.id,
    body: data['body'] as String? ?? '',
    createdAt: _date(data['createdAt']),
  );
}

DateTime _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  return DateTime.fromMillisecondsSinceEpoch(0);
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(FirebaseFirestore.instance);
});

final supportTicketsProvider = StreamProvider<List<SupportTicket>>((ref) {
  final session = ref.watch(authControllerProvider).session;
  if (session == null) return Stream.value(const []);
  return ref.watch(supportRepositoryProvider).watchTickets(session.uid);
});

final supportTicketProvider = StreamProvider.family<SupportTicket?, String>((
  ref,
  ticketId,
) {
  final session = ref.watch(authControllerProvider).session;
  if (session == null) return Stream.value(null);
  return ref
      .watch(supportRepositoryProvider)
      .watchTicket(session.uid, ticketId);
});

final supportMessagesProvider =
    StreamProvider.family<List<SupportMessage>, String>((ref, ticketId) {
      final session = ref.watch(authControllerProvider).session;
      if (session == null) return Stream.value(const []);
      return ref
          .watch(supportRepositoryProvider)
          .watchMessages(session.uid, ticketId);
    });
