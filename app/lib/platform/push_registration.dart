import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../claim/claim_exam.dart';

void Function(String route)? _onRoute;
void Function(String text)? _onMessage;
var _listening = false;
String? _tokenUid;

/// Registers this phone for exam and task reminders. The website waits until
/// a Web Push certificate exists. The lock-screen text stays generic.
Future<void> registerPushForUser(
  String uid, {
  required void Function(String route) onRoute,
  required void Function(String text) onMessage,
}) async {
  _onRoute = onRoute;
  _onMessage = onMessage;
  if (kIsWeb || Firebase.apps.isEmpty) return;
  if (_tokenUid == uid && _listening) return;
  _tokenUid = uid;
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) await savePushToken(uid, token);
    if (_listening) return;
    _listening = true;
    messaging.onTokenRefresh.listen((next) async {
      final current = _tokenUid;
      if (current == null) return;
      try {
        await savePushToken(current, next);
      } catch (error) {
        debugPrint('Push token refresh failed: $error');
      }
    });
    FirebaseMessaging.onMessage.listen((message) {
      final body = message.notification?.body;
      if (body != null && body.isNotEmpty) _onMessage?.call(body);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _open(message.data['route']);
    });
    final initial = await messaging.getInitialMessage();
    _open(initial?.data['route']);
  } catch (error) {
    debugPrint('Push registration failed: $error');
    _listening = false;
    _tokenUid = null;
  }
}

void _open(Object? route) {
  if (route is! String) return;
  if (examReminderRouteOk(route) || taskReminderRouteOk(route)) {
    _onRoute?.call(route);
  }
}

Future<void> savePushToken(String uid, String token) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) await user.getIdToken(true);
  final ref = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('push');
  final existing = await ref.get();
  if (!existing.exists) {
    await ref.set({
      'token': token,
      'schemaVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return;
  }
  if (existing.data()?['token'] == token) return;
  await ref.update({'token': token, 'updatedAt': FieldValue.serverTimestamp()});
}
