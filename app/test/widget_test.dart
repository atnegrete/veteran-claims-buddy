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

  testWidgets('finished onboarding opens the first claim question', (
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

    expect(
      find.text('Is this your first VA disability claim?'),
      findsOneWidget,
    );
    expect(find.text('Open Case'), findsOneWidget);
    expect(find.text('Issues'), findsOneWidget);
    expect(find.text('Symptoms Tracker'), findsOneWidget);
    expect(find.text('VA Ratings Calculator'), findsOneWidget);
    expect(find.text('Next action'), findsNothing);
    expect(find.text('Compare plans'), findsNothing);
    await tester.tap(find.text('Yes, this is my first claim'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('headaches, dizziness'), findsOneWidget);
    expect(find.textContaining('eyes or vision'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(
      find.text('Answer the questions marked on this page.'),
      findsOneWidget,
    );
    expect(find.text('Choose an answer.'), findsWidgets);
    await tester.ensureVisible(find.text('Yes').first);
    await tester.tap(find.text('Yes').first);
    await tester.pump();
    expect(find.textContaining('eyes or vision'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Documents').hitTestable());
    await tester.pump();
    await tester.pump();
    expect(
      find.textContaining('Files for this claim stay here'),
      findsOneWidget,
    );
    expect(find.text('Onboarding'), findsNothing);
  });

  testWidgets('an earlier claim can add its paperwork', (tester) async {
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
    await tester.tap(find.text('No, I have an earlier claim'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('It stays in Documents'), findsOneWidget);
    expect(find.text('Add paperwork'), findsOneWidget);
    expect(find.textContaining('headaches, dizziness'), findsNothing);
    await tester.tap(find.text('Add paperwork'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Choose a file'), findsOneWidget);
  });

  testWidgets('Vet Buddy shows the safety footer and You opens support', (
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
    await tester.tap(find.byTooltip('Vet Buddy'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(
      find.textContaining('Do not share sensitive identifiers'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(find.textContaining('This session ended.'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 400));

    await _openAccount(tester);
    expect(find.text('Calculator'), findsNothing);
    expect(find.text('Symptoms'), findsNothing);
    await tester.tap(find.text('Support'));
    await tester.pump();
    await tester.pump();

    expect(find.text(supportEmail), findsOneWidget);
    expect(find.textContaining('medical records'), findsOneWidget);
    expect(find.text('No tickets yet.'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -400),
    );
    await tester.pump();
    await tester.tap(find.text('New ticket').hitTestable());
    await tester.pump();
    await tester.pump();
    expect(find.text('Subject'), findsOneWidget);
    expect(find.text('Send ticket'), findsOneWidget);
  });

  testWidgets('profile saves a name and notifications remember a choice', (
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
    await _openAccount(tester);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -400),
    );
    await tester.pump();
    await tester.tap(find.text('Profile').hitTestable());
    await tester.pump();
    await tester.pump();

    expect(find.text('veteran@example.com'), findsOneWidget);
    expect(find.textContaining('not a legal name'), findsOneWidget);
    expect(find.text('Central'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Saved.'), findsOneWidget);

    await _openAccount(tester);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -500),
    );
    await tester.pump();
    await tester.tap(find.text('Notifications').hitTestable());
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('lock screen'), findsOneWidget);
    expect(find.text('Exam reminders'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
  });

  testWidgets('delete account explains the 30-day wait before scheduling', (
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
          ),
        ),
      ),
    );
    await tester.pump();
    await _openAccount(tester);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -500),
    );
    await tester.pump();
    await tester.tap(find.text('Delete account').hitTestable());
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('permanently removed'), findsOneWidget);
    expect(find.textContaining('does not cancel Premium'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'password');
    await tester.pump();
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byType(Checkbox).hitTestable());
    await tester.pump();
    await tester.ensureVisible(find.text('Schedule deletion'));
    await tester.pump();
    await tester.tap(find.text('Schedule deletion').hitTestable());
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('did not finish'), findsNothing);
    expect(find.textContaining('permanently removed'), findsOneWidget);
  });
}

Future<void> _openAccount(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Account').last);
  await tester.pumpAndSettle();
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
  _RecordingAuthGateway({required AuthSession session})
    : super(session: session);

  String? sentTo;

  @override
  Future<void> sendEnrollmentCode(String phoneNumber) async {
    sentTo = phoneNumber;
  }
}
