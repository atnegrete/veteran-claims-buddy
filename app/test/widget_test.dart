import 'package:app/app/app_environment.dart';
import 'package:app/auth/auth_gateway.dart';
import 'package:app/auth/auth_session.dart';
import 'package:app/main.dart';
import 'package:app/screens/auth/auth_scaffold.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signed-out dev app shows sign in and the DEV banner', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      const VeteranClaimsBuddyApp(
        environment: AppEnvironment.dev,
        projectId: 'veteran-claims-buddy-dev',
        authGateway: _IdleAuthGateway(),
      ),
    );

    expect(find.text('DEV · veteran-claims-buddy-dev'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('prod app has no DEV banner', (tester) async {
    await _pumpApp(
      tester,
      const VeteranClaimsBuddyApp(
        environment: AppEnvironment.prod,
        projectId: 'veteran-claims-buddy-prod',
        authGateway: _IdleAuthGateway(),
      ),
    );

    expect(find.textContaining('DEV'), findsNothing);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('registration shows the independent-product disclaimer', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      const VeteranClaimsBuddyApp(
        environment: AppEnvironment.dev,
        authGateway: _IdleAuthGateway(),
      ),
    );

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text(independentProductDisclaimer), findsOneWidget);
    expect(find.text('Create account'), findsWidgets);
  });

  testWidgets('unverified session stays on verify email', (tester) async {
    await _pumpApp(
      tester,
      VeteranClaimsBuddyApp(
        environment: AppEnvironment.dev,
        authGateway: _IdleAuthGateway(
          session: const AuthSession(
            uid: 'user-1',
            email: 'veteran@example.com',
            emailVerified: false,
            mfaEnrolled: false,
          ),
        ),
      ),
    );

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.textContaining('veteran@example.com'), findsOneWidget);
    expect(find.text('Add a phone number'), findsNothing);
  });

  testWidgets('verified session without a phone stays on enrollment', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      VeteranClaimsBuddyApp(
        environment: AppEnvironment.prod,
        authGateway: _IdleAuthGateway(
          session: const AuthSession(
            uid: 'user-1',
            email: 'veteran@example.com',
            emailVerified: true,
            mfaEnrolled: false,
          ),
        ),
      ),
    );

    expect(find.text('Add a phone number'), findsOneWidget);
    expect(find.text('Onboarding'), findsNothing);
    expect(find.textContaining('DEV'), findsNothing);
  });
}

Future<void> _pumpApp(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump();
}

class _IdleAuthGateway implements AuthGateway {
  const _IdleAuthGateway({this.session});

  final AuthSession? session;

  @override
  Stream<AuthSession?> watchSession() async* {
    yield session;
  }

  @override
  Future<AuthSession?> currentSession() async => session;

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {}

  @override
  Future<void> signOut() async {}
}
