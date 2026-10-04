import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'claim_guide.dart';
import 'vet_buddy.dart';

class VetBuddyRepository {
  VetBuddyRepository(this._firestore, this._functions, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Stream<VetBuddyChat> watchChat(String uid, String caseId) {
    return _messages(uid, caseId).snapshots().map((snapshot) {
      if (!snapshot.exists) return VetBuddyChat.empty;
      return VetBuddyChat.fromData(snapshot.data() ?? {});
    });
  }

  Stream<List<VetBuddyMessage>> watch(String uid, String caseId) {
    return _messages(uid, caseId).collection('messages').snapshots().map((
      snapshot,
    ) {
      final messages = [
        for (final doc in snapshot.docs)
          VetBuddyMessage.fromData(doc.id, doc.data()),
      ];
      messages.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
      return messages;
    });
  }

  DocumentReference<Map<String, dynamic>> _messages(String uid, String caseId) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(caseId);
  }

  Future<void> ask({
    required String uid,
    required String caseId,
    String text = '',
    bool endSession = false,
  }) async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken();
    try {
      await _functions.httpsCallable('askVetBuddy').call({
        'caseId': caseId,
        if (!endSession) 'text': text,
        if (endSession) 'endSession': true,
      });
    } on FirebaseFunctionsException catch (error) {
      final message = error.message;
      if (error.code == 'invalid-argument' &&
          message != null &&
          message.isNotEmpty) {
        throw ClaimGuideFailure(message);
      }
      throw const ClaimGuideFailure('Vet Buddy could not answer. Try again.');
    }
  }
}

final vetBuddyRepositoryProvider = Provider<VetBuddyRepository>((ref) {
  return VetBuddyRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instanceFor(region: 'us-central1'),
  );
});

final vetBuddyMessagesProvider =
    StreamProvider.family<List<VetBuddyMessage>, String>((ref, caseId) {
      final uid = ref.watch(authControllerProvider).session?.uid;
      if (uid == null || caseId.isEmpty) return Stream.value(const []);
      return ref.watch(vetBuddyRepositoryProvider).watch(uid, caseId);
    });

final vetBuddyChatProvider = StreamProvider.family<VetBuddyChat, String>((
  ref,
  caseId,
) {
  final uid = ref.watch(authControllerProvider).session?.uid;
  if (uid == null || caseId.isEmpty) return Stream.value(VetBuddyChat.empty);
  return ref.watch(vetBuddyRepositoryProvider).watchChat(uid, caseId);
});

typedef AskVetBuddy = Future<void> Function({
  required String caseId,
  String text,
  bool endSession,
});

final askVetBuddyProvider = Provider<AskVetBuddy>((ref) {
  final repository = ref.watch(vetBuddyRepositoryProvider);
  return ({required String caseId, String text = '', bool endSession = false}) {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) {
      throw const ClaimGuideFailure('Sign in again, then try again.');
    }
    return repository.ask(
      uid: uid,
      caseId: caseId,
      text: text,
      endSession: endSession,
    );
  };
});
