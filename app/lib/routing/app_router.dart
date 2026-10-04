import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_redirect.dart';
import '../cases/cases_progress.dart';
import '../claim/claim_review.dart';
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
import '../screens/shell/buddy_screen.dart';
import '../screens/shell/calculator_screen.dart';
import '../screens/shell/cases_screen.dart';
import '../screens/shell/decisions_screen.dart';
import '../screens/shell/delete_account_screen.dart';
import '../screens/shell/home_screen.dart';
import '../screens/shell/document_facts_screen.dart';
import '../screens/shell/documents_screen.dart';
import '../screens/shell/exams_screen.dart';
import '../screens/shell/issue_detail_screen.dart';
import '../screens/shell/issues_screen.dart';
import '../screens/shell/questions_screen.dart';
import '../screens/shell/reviews_screen.dart';
import '../screens/shell/notifications_screen.dart';
import '../screens/shell/package_screen.dart';
import '../screens/shell/plans_screen.dart';
import '../screens/shell/profile_screen.dart';
import '../screens/shell/security_screen.dart';
import '../screens/shell/support_screen.dart';
import '../screens/shell/symptoms_tracker_screen.dart';
import '../screens/shell/tasks_screen.dart';
import '../screens/shell/timeline_screen.dart';
import '../screens/shell/you_screen.dart';

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
        builder: (context, state) =>
            ResetPasswordScreen(code: state.uri.queryParameters['oobCode']),
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
            redirect: (context, state) => '${AuthRoutes.onboarding}/review',
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
            redirect: (context, state) {
              final id = ref.read(workingCaseIdProvider);
              if (id == null || id.isEmpty) return null;
              return AuthRoutes.caseStep(id);
            },
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AuthRoutes.cases,
            builder: (context, state) => const CasesScreen(),
            routes: [
              GoRoute(
                path: ':caseId',
                builder: (context, state) =>
                    HomeScreen(caseId: state.pathParameters['caseId']!),
                routes: [
                  GoRoute(
                    path: 'overview',
                    redirect: (context, state) =>
                        AuthRoutes.caseStep(state.pathParameters['caseId']!),
                  ),
                  GoRoute(
                    path: 'questions',
                    builder: (context, state) => QuestionsScreen(
                      caseId: state.pathParameters['caseId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'evidence',
                    builder: (context, state) => DocumentsScreen(
                      caseId: state.pathParameters['caseId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'upload',
                        builder: (context, state) => DocumentsScreen(
                          caseId: state.pathParameters['caseId']!,
                          adding: true,
                        ),
                      ),
                      GoRoute(
                        path: ':documentId',
                        redirect: (context, state) {
                          final path = state.uri.path;
                          if (path.endsWith('/details') ||
                              path.endsWith('/facts')) {
                            return null;
                          }
                          return AuthRoutes.caseDocument(
                            state.pathParameters['caseId']!,
                            state.pathParameters['documentId']!,
                          );
                        },
                        routes: [
                          GoRoute(
                            path: 'details',
                            builder: (context, state) => DocumentDetailsScreen(
                              caseId: state.pathParameters['caseId']!,
                              documentId: state.pathParameters['documentId']!,
                            ),
                          ),
                          GoRoute(
                            path: 'facts',
                            builder: (context, state) => DocumentFactsScreen(
                              caseId: state.pathParameters['caseId']!,
                              documentId: state.pathParameters['documentId']!,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'exams',
                    builder: (context, state) =>
                        ExamsScreen(caseId: state.pathParameters['caseId']!),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => ExamsScreen(
                          caseId: state.pathParameters['caseId']!,
                          adding: true,
                        ),
                      ),
                      GoRoute(
                        path: ':examId',
                        redirect: (context, state) {
                          final path = state.uri.path;
                          if (path.endsWith('/details') ||
                              path.endsWith('/prep') ||
                              path.endsWith('/travel')) {
                            return null;
                          }
                          return AuthRoutes.caseExam(
                            state.pathParameters['caseId']!,
                            state.pathParameters['examId']!,
                          );
                        },
                        routes: [
                          GoRoute(
                            path: 'details',
                            builder: (context, state) => ExamDetailsScreen(
                              caseId: state.pathParameters['caseId']!,
                              examId: state.pathParameters['examId']!,
                            ),
                          ),
                          GoRoute(
                            path: 'prep',
                            builder: (context, state) => ExamPrepScreen(
                              caseId: state.pathParameters['caseId']!,
                              examId: state.pathParameters['examId']!,
                            ),
                          ),
                          GoRoute(
                            path: 'travel',
                            builder: (context, state) => ExamTravelScreen(
                              caseId: state.pathParameters['caseId']!,
                              examId: state.pathParameters['examId']!,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'package',
                    builder: (context, state) =>
                        PackageScreen(caseId: state.pathParameters['caseId']!),
                    routes: [
                      GoRoute(
                        path: 'generate',
                        redirect: (context, state) =>
                            '${AuthRoutes.plans}?reason=package&caseId=${state.pathParameters['caseId']}',
                      ),
                      GoRoute(
                        path: 'submit',
                        builder: (context, state) => PackageSubmitScreen(
                          caseId: state.pathParameters['caseId']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'prepare',
                    builder: (context, state) =>
                        FormsScreen(caseId: state.pathParameters['caseId']!),
                    routes: [
                      GoRoute(
                        path: 'supplemental',
                        builder: (context, state) => ReviewPathScreen(
                          caseId: state.pathParameters['caseId']!,
                          path: ReviewPath.supplemental,
                        ),
                      ),
                      GoRoute(
                        path: 'higher-level-review',
                        builder: (context, state) => ReviewPathScreen(
                          caseId: state.pathParameters['caseId']!,
                          path: ReviewPath.higherLevel,
                        ),
                      ),
                      GoRoute(
                        path: 'board',
                        builder: (context, state) => ReviewPathScreen(
                          caseId: state.pathParameters['caseId']!,
                          path: ReviewPath.board,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'decisions',
                    builder: (context, state) => DecisionsScreen(
                      caseId: state.pathParameters['caseId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'upload',
                        builder: (context, state) => DecisionsScreen(
                          caseId: state.pathParameters['caseId']!,
                          adding: true,
                        ),
                      ),
                      GoRoute(
                        path: ':decisionId',
                        builder: (context, state) => DecisionReviewScreen(
                          caseId: state.pathParameters['caseId']!,
                          decisionId: state.pathParameters['decisionId']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'tasks',
                    builder: (context, state) =>
                        TasksScreen(caseId: state.pathParameters['caseId']!),
                  ),
                  GoRoute(
                    path: 'timeline',
                    builder: (context, state) =>
                        TimelineScreen(caseId: state.pathParameters['caseId']!),
                  ),
                  GoRoute(
                    path: 'issues',
                    builder: (context, state) =>
                        IssuesScreen(caseId: state.pathParameters['caseId']!),
                    routes: [
                      ShellRoute(
                        builder: (context, state, child) => IssueWorkspace(
                          caseId: state.pathParameters['caseId']!,
                          issueId: state.pathParameters['issueId']!,
                          child: child,
                        ),
                        routes: [
                          GoRoute(
                            path: ':issueId',
                            builder: (context, state) =>
                                const SizedBox.shrink(),
                            routes: [
                              GoRoute(
                                path: 'questions',
                                builder: (context, state) =>
                                    IssueQuestionsScreen(
                                      caseId: state.pathParameters['caseId']!,
                                      issueId: state.pathParameters['issueId']!,
                                    ),
                              ),
                              GoRoute(
                                path: 'evidence',
                                builder: (context, state) =>
                                    IssueEvidenceScreen(
                                      caseId: state.pathParameters['caseId']!,
                                      issueId: state.pathParameters['issueId']!,
                                    ),
                              ),
                              GoRoute(
                                path: 'connection',
                                builder: (context, state) =>
                                    IssueConnectionScreen(
                                      caseId: state.pathParameters['caseId']!,
                                      issueId: state.pathParameters['issueId']!,
                                    ),
                              ),
                              GoRoute(
                                path: 'statements',
                                redirect: (context, state) {
                                  final path = state.uri.path;
                                  if (path.endsWith('/lay') ||
                                      path.endsWith('/doctor-draft')) {
                                    return null;
                                  }
                                  return AuthRoutes.caseIssue(
                                    state.pathParameters['caseId']!,
                                    state.pathParameters['issueId']!,
                                  );
                                },
                                routes: [
                                  GoRoute(
                                    path: 'lay',
                                    builder: (context, state) =>
                                        IssueStatementScreen(
                                          caseId:
                                              state.pathParameters['caseId']!,
                                          issueId:
                                              state.pathParameters['issueId']!,
                                          kind: 'lay',
                                          heading: 'Your statement',
                                          intro: 'In your own words. This is not sent to the VA from here.',
                                        ),
                                  ),
                                  GoRoute(
                                    path: 'doctor-draft',
                                    builder: (context, state) =>
                                        IssueStatementScreen(
                                          caseId:
                                              state.pathParameters['caseId']!,
                                          issueId:
                                              state.pathParameters['issueId']!,
                                          kind: 'doctorDraft',
                                          heading: 'Draft for your doctor',
                                          intro: 'A draft you can take to your doctor. This is not a finished medical opinion.',
                                        ),
                                  ),
                                ],
                              ),
                              GoRoute(
                                path: 'decisions',
                                builder: (context, state) =>
                                    IssueDecisionsScreen(
                                      caseId: state.pathParameters['caseId']!,
                                      issueId: state.pathParameters['issueId']!,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
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
                path: 'settings/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: 'settings/security',
                builder: (context, state) => const SecurityScreen(),
              ),
              GoRoute(
                path: 'settings/notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
              GoRoute(
                path: 'settings/delete',
                builder: (context, state) => const DeleteAccountScreen(),
              ),
              GoRoute(
                path: 'support',
                builder: (context, state) => const SupportScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const NewSupportTicketScreen(),
                  ),
                  GoRoute(
                    path: ':ticketId',
                    builder: (context, state) => SupportTicketScreen(
                      ticketId: state.pathParameters['ticketId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'billing/premium',
                builder: (context, state) => const BillingPremiumScreen(),
              ),
              GoRoute(
                path: 'billing/cases',
                builder: (context, state) => const BillingCasesScreen(),
              ),
              GoRoute(
                path: 'legal',
                builder: (context, state) => const LegalScreen(),
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
          GoRoute(
            path: AuthRoutes.symptoms,
            builder: (context, state) => const SymptomsTrackerScreen(),
            routes: [
              GoRoute(
                path: 'check-in',
                builder: (context, state) =>
                    const SymptomFormScreen(event: false),
              ),
              GoRoute(
                path: 'events/new',
                builder: (context, state) =>
                    const SymptomFormScreen(event: true),
              ),
              GoRoute(
                path: 'summaries/:summaryId',
                builder: (context, state) => const SymptomSummaryScreen(),
              ),
              GoRoute(
                path: ':entryId',
                builder: (context, state) => SymptomDetailScreen(
                  entryId: state.pathParameters['entryId']!,
                ),
              ),
            ],
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
    _caseSubscription = _ref.listen(workingCaseIdProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
  late final ProviderSubscription<AuthGateState> _subscription;
  late final ProviderSubscription<bool> _onboardingSubscription;
  late final ProviderSubscription<String?> _caseSubscription;

  @override
  void dispose() {
    _subscription.close();
    _onboardingSubscription.close();
    _caseSubscription.close();
    super.dispose();
  }
}
