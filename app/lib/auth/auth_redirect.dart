import 'auth_access.dart';

abstract final class AuthRoutes {
  static const signIn = '/sign-in';
  static const register = '/register';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const mfaEnroll = '/mfa/enroll';
  static const mfaChallenge = '/mfa/challenge';
  static const reactivate = '/account/reactivate';
  static const recovery = '/account/recovery';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const cases = '/cases';
  static const buddy = '/buddy';
  static const you = '/you';
  static const profile = '/you/settings/profile';
  static const security = '/you/settings/security';
  static const notifications = '/you/settings/notifications';
  static const deleteAccount = '/you/settings/delete';
  static const support = '/you/support';
  static const supportNew = '/you/support/new';

  static String supportTicket(String ticketId) => '/you/support/$ticketId';
  static const billingPremium = '/you/billing/premium';
  static const billingCases = '/you/billing/cases';
  static const legal = '/you/legal';
  static const plans = '/plans';
  static const calculator = '/calculator';
  static const symptoms = '/symptoms';
  static const symptomCheckIn = '/symptoms/check-in';
  static const symptomEventNew = '/symptoms/events/new';
  static String symptomEntry(String entryId) => '/symptoms/$entryId';
  static String symptomSummary(String summaryId) =>
      '/symptoms/summaries/$summaryId';

  static String caseStep(String caseId) => '/cases/$caseId';
  static String caseDocuments(String caseId) => '/cases/$caseId/evidence';
  static String caseDocumentUpload(String caseId) =>
      '/cases/$caseId/evidence/upload';
  static String caseDocument(String caseId, String documentId) =>
      '/cases/$caseId/evidence/$documentId/details';
  static String caseDocumentFacts(String caseId, String documentId) =>
      '/cases/$caseId/evidence/$documentId/facts';
  static String caseExams(String caseId) => '/cases/$caseId/exams';
  static String caseExamNew(String caseId) => '/cases/$caseId/exams/new';
  static String caseExam(String caseId, String examId) =>
      '/cases/$caseId/exams/$examId/details';
  static String caseExamPrep(String caseId, String examId) =>
      '/cases/$caseId/exams/$examId/prep';
  static String caseExamTravel(String caseId, String examId) =>
      '/cases/$caseId/exams/$examId/travel';
  static String casePackage(String caseId) => '/cases/$caseId/package';
  static String casePackageGenerate(String caseId) =>
      '/cases/$caseId/package/generate';
  static String casePackageSubmit(String caseId) =>
      '/cases/$caseId/package/submit';
  static String caseQuestions(String caseId) => '/cases/$caseId/questions';
  static String caseConditions(String caseId) => '/cases/$caseId/conditions';
  static String caseIntent(String caseId) => '/cases/$caseId/intent';
  static String casePrepare(String caseId) => '/cases/$caseId/prepare';
  static String casePrepareForm(String caseId, String formNumber) =>
      '/cases/$caseId/prepare/$formNumber';
  static String caseIdentifiers(String caseId) =>
      '/cases/$caseId/prepare/identifiers';
  static String caseSupplemental(String caseId) =>
      '/cases/$caseId/prepare/supplemental';
  static String caseHigherLevelReview(String caseId) =>
      '/cases/$caseId/prepare/higher-level-review';
  static String caseBoard(String caseId) => '/cases/$caseId/prepare/board';
  static String caseDecisions(String caseId) => '/cases/$caseId/decisions';
  static String caseDecisionUpload(String caseId) =>
      '/cases/$caseId/decisions/upload';
  static String caseDecision(String caseId, String decisionId) =>
      '/cases/$caseId/decisions/$decisionId';
  static String caseCondition(String caseId, String conditionId) =>
      '/cases/$caseId/conditions/$conditionId';
  static String caseConditionQuestions(String caseId, String conditionId) =>
      '/cases/$caseId/conditions/$conditionId/questions';
  static String caseConditionEvidence(String caseId, String conditionId) =>
      '/cases/$caseId/conditions/$conditionId/evidence';
  static String caseConditionConnection(String caseId, String conditionId) =>
      '/cases/$caseId/conditions/$conditionId/connection';
  static String caseConditionLay(String caseId, String conditionId) =>
      '/cases/$caseId/conditions/$conditionId/statements/lay';
  static String caseConditionDoctorDraft(String caseId, String conditionId) =>
      '/cases/$caseId/conditions/$conditionId/statements/doctor-draft';
  static String caseConditionDecisions(String caseId, String conditionId) =>
      '/cases/$caseId/conditions/$conditionId/decisions';

  /// Opens [panel]. When [panel] is null, opens the conditions list.
  static String caseConditionPanel(
    String caseId,
    String conditionId,
    String? panel,
  ) {
    return switch (panel) {
      'questions' => caseConditionQuestions(caseId, conditionId),
      'decisions' => caseConditionDecisions(caseId, conditionId),
      'connection' => caseConditionConnection(caseId, conditionId),
      'lay' => caseConditionLay(caseId, conditionId),
      'doctor' => caseConditionDoctorDraft(caseId, conditionId),
      _ => caseConditions(caseId),
    };
  }

  static String caseOverview(String caseId) => '/cases/$caseId/overview';
  static String caseTasks(String caseId) => '/cases/$caseId/tasks';
  static String caseTimeline(String caseId) => '/cases/$caseId/timeline';
}

const signedOutRoutes = <String>{
  AuthRoutes.signIn,
  AuthRoutes.register,
  AuthRoutes.forgotPassword,
  AuthRoutes.resetPassword,
  AuthRoutes.recovery,
};

/// Returns the path to open, or null when [location] is already allowed.
///
/// [onboardingComplete] is false until the Veteran finishes onboarding.
/// The shell stays closed until then.
String? authRedirect({
  required AuthAccess access,
  required String location,
  bool onboardingComplete = false,
}) {
  switch (access) {
    case AuthAccess.signedOut:
      return signedOutRoutes.contains(location) ? null : AuthRoutes.signIn;
    case AuthAccess.emailVerificationRequired:
      return location == AuthRoutes.verifyEmail ? null : AuthRoutes.verifyEmail;
    case AuthAccess.mfaEnrollmentRequired:
      if (location == AuthRoutes.mfaEnroll || location == AuthRoutes.recovery) {
        return null;
      }
      return AuthRoutes.mfaEnroll;
    case AuthAccess.mfaChallengeInProgress:
      if (location == AuthRoutes.mfaChallenge ||
          location == AuthRoutes.recovery) {
        return null;
      }
      return AuthRoutes.mfaChallenge;
    case AuthAccess.accountRecoveryRequired:
      return location == AuthRoutes.recovery ? null : AuthRoutes.recovery;
    case AuthAccess.deletionScheduled:
      return location == AuthRoutes.reactivate ? null : AuthRoutes.reactivate;
    case AuthAccess.authenticatedReady:
      if (!onboardingComplete) {
        return isOnboardingLocation(location) ? null : AuthRoutes.onboarding;
      }
      if (isShellLocation(location)) return null;
      return AuthRoutes.home;
  }
}

bool isOnboardingLocation(String location) {
  return location == AuthRoutes.onboarding ||
      location.startsWith('${AuthRoutes.onboarding}/');
}

bool isShellLocation(String location) {
  const roots = <String>[
    AuthRoutes.home,
    AuthRoutes.cases,
    AuthRoutes.buddy,
    AuthRoutes.you,
    AuthRoutes.plans,
    AuthRoutes.calculator,
    AuthRoutes.symptoms,
  ];
  for (final root in roots) {
    if (location == root || location.startsWith('$root/')) return true;
  }
  return false;
}
