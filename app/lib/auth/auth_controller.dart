import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_access.dart';
import 'auth_gateway.dart';
import 'auth_session.dart';
import 'firebase_auth_gateway.dart';
import 'mfa_challenge.dart';

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => FirebaseAuthGateway(),
);

class AuthGateState {
  const AuthGateState({
    required this.ready,
    required this.session,
    this.mfaChallengeInProgress = false,
    this.deletionScheduled = false,
    this.recoveryRequired = false,
    this.serverAuthConfirmed = false,
    this.serverConfirmFailed = false,
    this.challengeHints = const [],
  });

  const AuthGateState.loading() : this(ready: false, session: null);

  final bool ready;
  final AuthSession? session;
  final bool mfaChallengeInProgress;
  final bool deletionScheduled;
  final bool recoveryRequired;
  final bool serverAuthConfirmed;
  final bool serverConfirmFailed;
  final List<PhoneFactorHint> challengeHints;

  AuthAccess get access {
    final current = session;
    return resolveAuthAccess(
      signedIn: current != null,
      emailVerified: current?.emailVerified ?? false,
      mfaEnrolled: current?.mfaEnrolled ?? false,
      mfaChallengeInProgress: mfaChallengeInProgress,
      deletionScheduled: deletionScheduled,
      recoveryRequired: recoveryRequired,
      serverAuthConfirmed: serverAuthConfirmed,
    );
  }

  AuthGateState copyWith({
    bool? ready,
    Object? session = _keep,
    bool? mfaChallengeInProgress,
    bool? deletionScheduled,
    bool? recoveryRequired,
    bool? serverAuthConfirmed,
    bool? serverConfirmFailed,
    List<PhoneFactorHint>? challengeHints,
  }) {
    return AuthGateState(
      ready: ready ?? this.ready,
      session: session == _keep ? this.session : session as AuthSession?,
      mfaChallengeInProgress:
          mfaChallengeInProgress ?? this.mfaChallengeInProgress,
      deletionScheduled: deletionScheduled ?? this.deletionScheduled,
      recoveryRequired: recoveryRequired ?? this.recoveryRequired,
      serverAuthConfirmed: serverAuthConfirmed ?? this.serverAuthConfirmed,
      serverConfirmFailed: serverConfirmFailed ?? this.serverConfirmFailed,
      challengeHints: challengeHints ?? this.challengeHints,
    );
  }
}

const _keep = Object();

class AuthController extends Notifier<AuthGateState> {
  @override
  AuthGateState build() {
    final gateway = ref.watch(authGatewayProvider);
    final subscription = gateway.watchSession().listen(
      (session) {
        final sameUser =
            session != null && session.uid == state.session?.uid;
        state = state.copyWith(
          ready: true,
          session: session,
          serverAuthConfirmed: sameUser ? state.serverAuthConfirmed : false,
          serverConfirmFailed: sameUser ? state.serverConfirmFailed : false,
        );
        final current = state.session;
        if (current != null &&
            current.emailVerified &&
            current.mfaEnrolled &&
            !state.serverAuthConfirmed) {
          unawaited(confirmServerAuthState());
        }
        if (current != null &&
            current.emailVerified &&
            !current.mfaEnrolled &&
            state.serverAuthConfirmed) {
          unawaited(clearServerAuthState());
        }
      },
      onError: (Object _, StackTrace _) {
        state = state.copyWith(ready: true);
      },
    );
    ref.onDispose(subscription.cancel);
    return const AuthGateState.loading();
  }

  Future<void> createAccount({
    required String email,
    required String password,
  }) {
    return _refreshAfter(
      () => ref.read(authGatewayProvider).createAccount(
            email: email,
            password: password,
          ),
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await ref.read(authGatewayProvider).signIn(
            email: email,
            password: password,
          );
    } on MfaChallengeRequired catch (required) {
      state = state.copyWith(
        ready: true,
        session: null,
        mfaChallengeInProgress: true,
        challengeHints: required.hints,
      );
      return;
    }
    final session = await ref.read(authGatewayProvider).currentSession();
    state = state.copyWith(
      ready: true,
      session: session,
      mfaChallengeInProgress: false,
      challengeHints: const [],
    );
  }

  Future<void> sendEnrollmentCode(String phoneNumber) {
    return ref.read(authGatewayProvider).sendEnrollmentCode(phoneNumber);
  }

  Future<void> confirmEnrollmentCode(String smsCode) async {
    await ref.read(authGatewayProvider).confirmEnrollmentCode(smsCode);
    final session = await ref.read(authGatewayProvider).currentSession();
    state = state.copyWith(ready: true, session: session);
    await confirmServerAuthState();
  }

  Future<void> sendChallengeCode(String factorUid) {
    return ref.read(authGatewayProvider).sendChallengeCode(factorUid);
  }

  Future<void> confirmChallengeCode(String smsCode) async {
    await ref.read(authGatewayProvider).confirmChallengeCode(smsCode);
    final session = await ref.read(authGatewayProvider).currentSession();
    state = state.copyWith(
      ready: true,
      session: session,
      mfaChallengeInProgress: false,
      challengeHints: const [],
    );
    await confirmServerAuthState();
  }

  Future<void> reauthenticate(String password) {
    return ref.read(authGatewayProvider).reauthenticate(password);
  }

  Future<void> removePhoneFactor({
    required String password,
    required String factorUid,
  }) async {
    final gateway = ref.read(authGatewayProvider);
    await gateway.reauthenticate(password);
    await gateway.unenrollFactor(factorUid);
    final session = await gateway.currentSession();
    state = state.copyWith(ready: true, session: session);
    if (session?.mfaEnrolled != true) {
      await clearServerAuthState();
    }
  }

  Future<void>? _serverConfirm;
  Future<void>? _serverClear;

  Future<void> confirmServerAuthState() {
    final existing = _serverConfirm;
    if (existing != null) return existing;
    final run = _writeServerAuthState();
    _serverConfirm = run;
    return run.whenComplete(() {
      if (identical(_serverConfirm, run)) _serverConfirm = null;
    });
  }

  Future<void> clearServerAuthState() {
    final existing = _serverClear;
    if (existing != null) return existing;
    final run = _clearServerAuthState();
    _serverClear = run;
    return run.whenComplete(() {
      if (identical(_serverClear, run)) _serverClear = null;
    });
  }

  Future<void> _clearServerAuthState() async {
    final uid = state.session?.uid;
    if (uid == null || state.session?.mfaEnrolled == true) return;
    try {
      await ref.read(authGatewayProvider).clearServerAuthState();
      if (state.session?.uid != uid) return;
      state = state.copyWith(
        serverAuthConfirmed: false,
        serverConfirmFailed: false,
      );
    } catch (_) {
      if (state.session?.uid != uid) return;
      state = state.copyWith(serverConfirmFailed: true);
      rethrow;
    }
  }

  Future<void> _writeServerAuthState() async {
    if (state.serverAuthConfirmed) return;
    final uid = state.session?.uid;
    if (uid == null) return;
    state = state.copyWith(serverConfirmFailed: false);
    try {
      await ref.read(authGatewayProvider).confirmServerAuthState();
      if (state.session?.uid != uid) return;
      state = state.copyWith(
        serverAuthConfirmed: true,
        serverConfirmFailed: false,
      );
    } catch (_) {
      if (state.session?.uid != uid) return;
      state = state.copyWith(serverConfirmFailed: true);
    }
  }

  Future<void> sendEmailVerification() {
    return ref.read(authGatewayProvider).sendEmailVerification();
  }

  Future<void> refreshSession() {
    return _refreshAfter(
      () => ref.read(authGatewayProvider).reloadCurrentUser(),
    );
  }

  Future<void> sendPasswordReset(String email) {
    return ref.read(authGatewayProvider).sendPasswordReset(email);
  }

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) {
    return ref.read(authGatewayProvider).confirmPasswordReset(
          code: code,
          newPassword: newPassword,
        );
  }

  Future<void> signOut() async {
    await ref.read(authGatewayProvider).signOut();
    final session = await ref.read(authGatewayProvider).currentSession();
    state = state.copyWith(
      ready: true,
      session: session,
      mfaChallengeInProgress: false,
      recoveryRequired: false,
      serverAuthConfirmed: false,
      serverConfirmFailed: false,
      challengeHints: const [],
    );
  }

  Future<void> _refreshAfter(Future<void> Function() action) async {
    await action();
    final session = await ref.read(authGatewayProvider).currentSession();
    state = state.copyWith(ready: true, session: session);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthGateState>(AuthController.new);
