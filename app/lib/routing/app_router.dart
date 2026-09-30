import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_redirect.dart';
import '../screens/auth/gate_screens.dart';
import '../screens/auth/mfa_challenge_screen.dart';
import '../screens/auth/mfa_enroll_screen.dart';
import '../screens/auth/password_screens.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/verify_email_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  final router = GoRouter(
    initialLocation: AuthRoutes.signIn,
    refreshListenable: refresh,
    redirect: (context, state) {
      final gate = ref.read(authControllerProvider);
      if (!gate.ready) return null;
      return authRedirect(access: gate.access, location: state.uri.path);
    },
    routes: [
      GoRoute(
        path: AuthRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AuthRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AuthRoutes.verifyEmail,
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: AuthRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AuthRoutes.resetPassword,
        builder: (context, state) => ResetPasswordScreen(
          code: state.uri.queryParameters['oobCode'],
        ),
      ),
      GoRoute(
        path: AuthRoutes.mfaEnroll,
        builder: (context, state) => const MfaEnrollScreen(),
      ),
      GoRoute(
        path: AuthRoutes.mfaChallenge,
        builder: (context, state) => const MfaChallengeScreen(),
      ),
      GoRoute(
        path: AuthRoutes.reactivate,
        builder: (context, state) => const AccountReactivateScreen(),
      ),
      GoRoute(
        path: AuthRoutes.recovery,
        builder: (context, state) => const AccountRecoveryScreen(),
      ),
      GoRoute(
        path: AuthRoutes.onboarding,
        builder: (context, state) => const OnboardingHoldScreen(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _subscription = _ref.listen(authControllerProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
  late final ProviderSubscription<AuthGateState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
