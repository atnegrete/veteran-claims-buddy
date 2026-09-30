import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_redirect.dart';
import '../onboarding/onboarding_progress.dart';
import '../screens/auth/gate_screens.dart';
import '../screens/auth/mfa_challenge_screen.dart';
import '../screens/auth/mfa_enroll_screen.dart';
import '../screens/auth/password_screens.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/onboarding/deployments_screen.dart';
import '../screens/onboarding/remaining_screens.dart';
import '../screens/onboarding/service_screen.dart';
import '../screens/onboarding/welcome_screen.dart';
import '../screens/shell/app_shell.dart';
import '../screens/shell/calculator_screen.dart';
import '../screens/shell/case_overview_screen.dart';
import '../screens/shell/cases_screen.dart';
import '../screens/shell/home_screen.dart';
import '../screens/shell/plans_screen.dart';
import '../screens/shell/security_screen.dart';
import '../screens/shell/shell_pages.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  final router = GoRouter(
    initialLocation: AuthRoutes.signIn,
    refreshListenable: refresh,
    redirect: (context, state) {
      final gate = ref.read(authControllerProvider);
      if (!gate.ready) return null;
      return authRedirect(
        access: gate.access,
        location: state.uri.path,
        onboardingComplete: ref.read(onboardingCompleteProvider),
      );
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
        builder: (context, state) => const OnboardingResumeScreen(),
        routes: [
          GoRoute(
            path: 'welcome',
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(
            path: 'service',
            builder: (context, state) => const ServiceScreen(),
          ),
          GoRoute(
            path: 'deployments',
            builder: (context, state) => const DeploymentsScreen(),
          ),
          GoRoute(
            path: 'exposures',
            builder: (context, state) => const ExposuresScreen(),
          ),
          GoRoute(
            path: 'discovery',
            builder: (context, state) => const DiscoveryScreen(),
          ),
          GoRoute(
            path: 'review',
            builder: (context, state) => const ReviewScreen(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: AuthRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AuthRoutes.cases,
            builder: (context, state) => const CasesScreen(),
            routes: [
              GoRoute(
                path: ':caseId/overview',
                builder: (context, state) => CaseOverviewScreen(
                  caseId: state.pathParameters['caseId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AuthRoutes.buddy,
            builder: (context, state) => const BuddyScreen(),
          ),
          GoRoute(
            path: AuthRoutes.you,
            builder: (context, state) => const YouScreen(),
            routes: [
              GoRoute(
                path: 'settings/security',
                builder: (context, state) => const SecurityScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AuthRoutes.plans,
            builder: (context, state) => PlansScreen(
              reason: state.uri.queryParameters['reason'],
              caseId: state.uri.queryParameters['caseId'],
            ),
          ),
          GoRoute(
            path: AuthRoutes.calculator,
            builder: (context, state) => const CalculatorScreen(),
          ),
        ],
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
    _onboardingSubscription = _ref.listen(onboardingCompleteProvider, (
      previous,
      next,
    ) {
      notifyListeners();
    });
  }

  final Ref _ref;
  late final ProviderSubscription<AuthGateState> _subscription;
  late final ProviderSubscription<bool> _onboardingSubscription;

  @override
  void dispose() {
    _subscription.close();
    _onboardingSubscription.close();
    super.dispose();
  }
}
