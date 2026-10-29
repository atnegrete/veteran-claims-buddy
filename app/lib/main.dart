import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account/account_deletion.dart';
import 'account/notification_preferences.dart';
import 'account/profile.dart';
import 'support/support_repository.dart';
import 'support/support_ticket.dart';
import 'app/app_bootstrap.dart';
import 'app/app_environment.dart';
import 'app/app_scroll.dart';
import 'app/app_theme.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_gateway.dart';
import 'billing/entitlement_service.dart';
import 'billing/revenuecat_service.dart';
import 'cases/cases_progress.dart';
import 'claim/claim_decision.dart';
import 'claim/claim_document.dart';
import 'claim/claim_exam.dart';
import 'claim/claim_guide.dart';
import 'claim/claim_issue.dart';
import 'claim/claim_issue_repository.dart';
import 'claim/claim_review.dart';
import 'claim/decision_repository.dart';
import 'claim/document_repository.dart';
import 'claim/exam_repository.dart';
import 'claim/next_action.dart';
import 'claim/next_action_repository.dart';
import 'claim/vet_buddy.dart';
import 'claim/vet_buddy_repository.dart';
import 'claim/discovery_repository.dart';
import 'claim/package_guidance.dart';
import 'claim/package_repository.dart';
import 'claim/questionnaire_catalog.dart';
import 'claim/questionnaire_repository.dart';
import 'claim/review_repository.dart';
import 'claim/symptom_entry.dart';
import 'claim/symptom_repository.dart';
import 'cases/veteran_case.dart';
import 'onboarding/onboarding_progress.dart';
import 'platform/file_picker_registration.dart'
    if (dart.library.html) 'platform/file_picker_registration_web.dart';
import 'routing/app_router.dart';

const authLoadingKey = Key('auth-loading');

void _applyDeletionSchedule(
  WidgetRef ref,
  AsyncValue<Map<String, dynamic>?> account,
) {
  account.whenData((data) {
    ref
        .read(authControllerProvider.notifier)
        .setDeletionScheduled(data?['accountStatus'] == 'deletionScheduled');
  });
}

final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => currentEnvironment,
);

final firebaseProjectIdProvider = Provider<String?>((ref) => null);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFilePicker();
  final environment = currentEnvironment;
  await bootstrapFirebase(environment);
  runApp(
    VeteranClaimsBuddyApp(
      environment: environment,
      projectId: Firebase.app().options.projectId,
    ),
  );
}

class VeteranClaimsBuddyApp extends StatelessWidget {
  const VeteranClaimsBuddyApp({
    super.key,
    this.environment,
    this.projectId,
    this.authGateway,
    this.onboardingComplete = false,
  });

  final AppEnvironment? environment;
  final String? projectId;
  final AuthGateway? authGateway;
  final bool onboardingComplete;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          environment ?? currentEnvironment,
        ),
        firebaseProjectIdProvider.overrideWithValue(projectId),
        if (authGateway != null) ...[
          authGatewayProvider.overrideWithValue(authGateway!),
          onboardingCompleteProvider.overrideWithValue(onboardingComplete),
          onboardingDocProvider.overrideWith((ref) => Stream.value(null)),
          casesProvider.overrideWith(
            (ref) => Stream.value(const <VeteranCase>[]),
          ),
          premiumStatusProvider.overrideWith(
            (ref) => Stream.value(PremiumStatus.inactive),
          ),
          caseUnlocksProvider.overrideWith(
            (ref) => Stream.value(const <String>{}),
          ),
          ensureWorkingCaseCallerProvider.overrideWith(
            (ref) =>
                () async => 'case-test',
          ),
          accountDeletionClientProvider.overrideWithValue(
            const IdleAccountDeletion(),
          ),
          workingCaseIdProvider.overrideWithValue('case-test'),
          saveFirstClaimProvider.overrideWithValue((bool firstClaim) async {}),
          syncNextActionProvider.overrideWithValue(
            (NextAction action) async {},
          ),
          discoveryProgressProvider.overrideWith(
            (ref) => Stream.value(DiscoveryProgress.empty),
          ),
          saveDiscoveryProvider.overrideWithValue(
            ({
              required String? caseId,
              required Map<String, String> answers,
            }) async {},
          ),
          questionnaireSessionProvider.overrideWith(
            (ref) => Stream.value(
              const QuestionnaireSession(
                answers: {},
                questions: widgetPreviewCatalog,
              ),
            ),
          ),
          claimIssuesProvider.overrideWith(
            (ref) => Stream.value(const <ClaimIssue>[]),
          ),
          claimDocumentsProvider.overrideWith(
            (ref, caseId) => Stream.value(const <ClaimDocument>[]),
          ),
          claimExamsProvider.overrideWith(
            (ref, caseId) => Stream.value(const <ClaimExam>[]),
          ),
          claimDecisionsProvider.overrideWith(
            (ref, caseId) => Stream.value(const <ClaimDecision>[]),
          ),
          claimReviewsProvider.overrideWith(
            (ref, caseId) => Stream.value(const <ClaimReview>[]),
          ),
          reviewCandidatesProvider.overrideWith(
            (ref, caseId) => Stream.value(const <ReviewCandidate>[]),
          ),
          packageCheckProvider.overrideWith(
            (ref, caseId) => Stream.value(PackageCheck.empty),
          ),
          symptomEntriesProvider.overrideWith(
            (ref) => Stream.value(const <SymptomEntry>[]),
          ),
          vetBuddyMessagesProvider.overrideWith(
            (ref, caseId) => Stream.value(const <VetBuddyMessage>[]),
          ),
          vetBuddyChatProvider.overrideWith(
            (ref, caseId) => Stream.value(
              VetBuddyChat(
                activeSessionId: 'old',
                expiresAt: DateTime.utc(2020),
              ),
            ),
          ),
          askVetBuddyProvider.overrideWithValue(
            ({
              required String caseId,
              String text = '',
              bool endSession = false,
            }) async {},
          ),
          saveQuestionnaireProvider.overrideWithValue(
            ({
              required String? caseId,
              required List<CatalogQuestion> questions,
              required Map<String, List<String>> answers,
            }) async {},
          ),
          saveProfileProvider.overrideWithValue(
            ({required String displayName, required String timezone}) async {},
          ),
          notificationPreferencesProvider.overrideWith(
            (ref) => Stream.value(NotificationPreferences.defaults),
          ),
          saveNotificationPreferencesProvider.overrideWith(
            (ref) => (NotificationPreferences preferences) async {},
          ),
          supportTicketsProvider.overrideWith(
            (ref) => Stream.value(const <SupportTicket>[]),
          ),
        ],
      ],
      child: const AuthApp(),
    );
  }
}

class AuthApp extends ConsumerWidget {
  const AuthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(onboardingDocProvider, (_, next) {
      _applyDeletionSchedule(ref, next);
    });
    // Keep the RevenueCat app user id in step with the Firebase sign-in. No-op
    // on web and when no SDK key is passed, so it never blocks startup.
    ref.listen(authControllerProvider.select((state) => state.session?.uid), (
      _,
      uid,
    ) {
      final revenueCat = ref.read(revenueCatServiceProvider);
      if (uid != null) {
        revenueCat.configureAndLogIn(uid);
      } else {
        revenueCat.logOut();
      }
    });
    final accountDoc = ref.watch(onboardingDocProvider);
    Future.microtask(() => _applyDeletionSchedule(ref, accountDoc));

    final gate = ref.watch(authControllerProvider);

    if (!gate.ready) {
      return MaterialApp(
        title: 'Veteran Claims Buddy',
        theme: appTheme(),
        scrollBehavior: const AppScrollBehavior(),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator(key: authLoadingKey)),
        ),
      );
    }

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Veteran Claims Buddy',
      theme: appTheme(),
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
    );
  }
}
