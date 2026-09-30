import 'package:app/app/app_environment.dart';
import 'package:app/auth/auth_gateway.dart';
import 'package:app/auth/auth_session.dart';
import 'package:app/main.dart';
import 'package:app/screens/auth/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signed-out dev app shows sign in', (tester) async {
    await _pumpApp(
      tester,
      const VeteranClaimsBuddyApp(
        environment: AppEnvironment.dev,
        projectId: 'veteran-claims-buddy-dev',
        authGateway: _IdleAuthGateway(),
      ),
    );

    expect(find.text('DEV · veteran-claims-buddy-dev'), findsNothing);
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
    expect(find.textContaining('before any claim information'), findsOneWidget);
    expect(find.text('Onboarding'), findsNothing);
    expect(find.textContaining('DEV'), findsNothing);
  });

  testWidgets('enrollment sends E.164 and then shows only a masked number', (
    tester,
  ) async {
    final gateway = _RecordingAuthGateway(
      session: const AuthSession(
        uid: 'user-1',
        email: 'veteran@example.com',
        emailVerified: true,
        mfaEnrolled: false,
      ),
    );
    await _pumpApp(
      tester,
      VeteranClaimsBuddyApp(
        environment: AppEnvironment.dev,
        authGateway: gateway,
      ),
    );

    await tester.enterText(find.byType(TextField), '5555550100');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Send code'));
    await tester.tap(find.text('Send code'));
    await tester.pump();
    await tester.pump();

    expect(gateway.sentTo, '+15555550100');
    expect(find.textContaining('Text message ending in 0100'), findsOneWidget);
    expect(find.textContaining('5555550100'), findsNothing);
    expect(find.textContaining('+15555550100'), findsNothing);
  });

  testWidgets('finished onboarding opens Home and can switch to Cases', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      VeteranClaimsBuddyApp(
        environment: AppEnvironment.dev,
        onboardingComplete: true,
        authGateway: _IdleAuthGateway(
          session: const AuthSession(
            uid: 'user-1',
            email: 'veteran@example.com',
            emailVerified: true,
            mfaEnrolled: true,
            maskedPhone: 'Text message ending in 0100',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Opening your case.'), findsOneWidget);
    expect(find.text('Next action'), findsOneWidget);
    expect(find.text('Compare plans'), findsOneWidget);
    await tester.drag(find.byType(ListView).hitTestable(), const Offset(0, -800));
    await tester.pump();
    await tester.tap(find.text('Compare plans').hitTestable());
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('charges a card'), findsOneWidget);
    expect(find.textContaining('\$250'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byIcon(Icons.folder_outlined).hitTestable());
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Opening your case.'), findsOneWidget);
    expect(find.text('Onboarding'), findsNothing);
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
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendEnrollmentCode(String phoneNumber) async {}

  @override
  Future<void> confirmEnrollmentCode(String smsCode) async {}

  @override
  Future<void> sendChallengeCode(String factorUid) async {}

  @override
  Future<void> confirmChallengeCode(String smsCode) async {}

  @override
  Future<void> confirmServerAuthState() async {}

  @override
  Future<void> clearServerAuthState() async {}

  @override
  Future<void> reauthenticate(String password) async {}

  @override
  Future<void> unenrollFactor(String factorUid) async {}
}

class _RecordingAuthGateway extends _IdleAuthGateway {
  _RecordingAuthGateway({required AuthSession session}) : super(session: session);

  String? sentTo;

  @override
  Future<void> sendEnrollmentCode(String phoneNumber) async {
    sentTo = phoneNumber;
  }
}
