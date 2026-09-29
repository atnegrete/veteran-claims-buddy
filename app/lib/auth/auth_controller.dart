import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_access.dart';
import 'auth_gateway.dart';
import 'auth_session.dart';
import 'firebase_auth_gateway.dart';

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
  });

  const AuthGateState.loading() : this(ready: false, session: null);

  final bool ready;
  final AuthSession? session;
  final bool mfaChallengeInProgress;
  final bool deletionScheduled;
  final bool recoveryRequired;

  AuthAccess get access {
    final current = session;
    return resolveAuthAccess(
      signedIn: current != null,
      emailVerified: current?.emailVerified ?? false,
      mfaEnrolled: current?.mfaEnrolled ?? false,
      mfaChallengeInProgress: mfaChallengeInProgress,
      deletionScheduled: deletionScheduled,
      recoveryRequired: recoveryRequired,
    );
  }

  AuthGateState copyWith({
    bool? ready,
    Object? session = _keep,
    bool? mfaChallengeInProgress,
    bool? deletionScheduled,
    bool? recoveryRequired,
  }) {
    return AuthGateState(
      ready: ready ?? this.ready,
      session: session == _keep ? this.session : session as AuthSession?,
      mfaChallengeInProgress:
          mfaChallengeInProgress ?? this.mfaChallengeInProgress,
      deletionScheduled: deletionScheduled ?? this.deletionScheduled,
      recoveryRequired: recoveryRequired ?? this.recoveryRequired,
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
        state = state.copyWith(ready: true, session: session);
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
  }) {
    return _refreshAfter(
      () => ref.read(authGatewayProvider).signIn(
            email: email,
            password: password,
          ),
    );
  }

  Future<void> sendEmailVerification() {
    return ref.read(authGatewayProvider).sendEmailVerification();
  }

  Future<void> refreshSession() => _refreshAfter(() async {});

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
