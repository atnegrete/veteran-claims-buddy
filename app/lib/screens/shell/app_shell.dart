import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_badge.dart';
import '../../app/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../cases/cases_progress.dart';
import '../../cases/veteran_case.dart';
import '../../claim/claim_document.dart';
import '../../claim/claim_guide.dart';
import '../../claim/claim_issue.dart';
import '../../claim/claim_issue_repository.dart';
import '../../claim/claim_sections.dart';
import '../../claim/decision_repository.dart';
import '../../claim/document_repository.dart';
import '../../claim/exam_repository.dart';
import '../../claim/package_repository.dart';
import '../../claim/questionnaire_catalog.dart';
import '../../claim/questionnaire_repository.dart';
import '../../claim/review_repository.dart';
import '../../onboarding/onboarding_progress.dart';
import '../../platform/push_registration.dart';
import 'signed_in_bar.dart';
import 'vet_buddy_bubble.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(casesProvider, (previous, next) {
      final cases = next.asData?.value;
      if (cases != null) {
        ref.read(caseEnsureProvider.notifier).ensureIfNeeded(cases);
      }
    });
    final loaded = ref.watch(casesProvider).asData?.value;
    if (loaded != null) {
      Future.microtask(
        () => ref.read(caseEnsureProvider.notifier).ensureIfNeeded(loaded),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 600;
        final nav = _ShellNav(location: location);
        return Scaffold(
          appBar: SignedInAppBar(showAccountLink: true, showMenu: narrow),
          drawer: narrow ? Drawer(child: nav) : null,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!narrow)
                SizedBox(
                  width: 248,
                  child: Material(color: AppColors.rail, child: nav),
                ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: _ClaimBody(
                    showBubble: _showBubble(location),
                    caseId:
                        caseIdFromLocation(location) ??
                        ref.watch(workingCaseIdProvider),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClaimBody extends StatelessWidget {
  const _ClaimBody({
    required this.showBubble,
    required this.caseId,
    required this.child,
  });

  final bool showBubble;
  final String? caseId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!showBubble) return child;
    return Stack(
      children: [
        child,
        Positioned(
          right: 16,
          bottom: 16,
          child: VetBuddyBubble(caseId: caseId ?? ''),
        ),
      ],
    );
  }
}

class _ShellNav extends ConsumerStatefulWidget {
  const _ShellNav({required this.location});

  final String location;

  @override
  ConsumerState<_ShellNav> createState() => _ShellNavState();
}

class _ShellNavState extends ConsumerState<_ShellNav> {
  var _caseOpen = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    registerPushForUser(
      uid,
      onRoute: (route) {
        if (!mounted) return;
        context.go(route);
      },
      onMessage: (text) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final caseId =
        caseIdFromLocation(location) ?? ref.watch(workingCaseIdProvider);
    final firstClaim = ref
        .watch(onboardingDocProvider)
        .maybeWhen(data: firstClaimAnswer, orElse: () => null);
    final session = ref
        .watch(questionnaireSessionProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => QuestionnaireSession.empty,
        );
    final issues = ref
        .watch(claimIssuesProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <ClaimIssue>[]);
    final claimed = {
      for (final issue in issues)
        if (caseId != null && issue.activeCaseId == caseId) issue.conditionId,
    };
    final documents = caseId == null
        ? const <ClaimDocument>[]
        : ref
              .watch(claimDocumentsProvider(caseId))
              .maybeWhen(
                data: (value) => value,
                orElse: () => const <ClaimDocument>[],
              );
    final documentCount = documents.length;
    final supplementalCount = documents.where(supportsEarlierClaim).length;
    final examCount = caseId == null
        ? 0
        : ref
              .watch(claimExamsProvider(caseId))
              .maybeWhen(data: (value) => value.length, orElse: () => 0);
    final decisionCount = caseId == null
        ? 0
        : ref
              .watch(claimDecisionsProvider(caseId))
              .maybeWhen(data: (value) => value.length, orElse: () => 0);
    final reviewCount = caseId == null
        ? 0
        : ref
              .watch(claimReviewsProvider(caseId))
              .maybeWhen(data: (value) => value.length, orElse: () => 0);
    final packageStarted =
        caseId != null &&
        ref
            .watch(packageCheckProvider(caseId))
            .maybeWhen(data: (value) => value.started, orElse: () => false);
    final conditions = catalogConditions(session.questions, session.answers);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CaseHeading(
              label: _caseLabel(ref, caseId),
              open: _caseOpen,
              onToggle: () => setState(() => _caseOpen = !_caseOpen),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _caseOpen
                  ? Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: scheme.outline),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SectionRow(
                              label: firstClaimLabel(firstClaim),
                              icon: Icons.flag_outlined,
                              selectedIcon: Icons.flag,
                              selected: _onCaseStep(location),
                              status: firstClaimStatus(
                                firstClaim,
                                supplementalCount: supplementalCount,
                              ),
                              onTap: () => _open(context, _casePath(caseId)),
                            ),
                            _SectionRow(
                              label: 'Questions',
                              icon: Icons.quiz_outlined,
                              selectedIcon: Icons.quiz,
                              selected: _onCaseSection(location, 'questions'),
                              status: questionsStatus(session),
                              onTap: () => _open(
                                context,
                                _sectionPath(caseId, AuthRoutes.caseQuestions),
                              ),
                            ),
                            _SectionRow(
                              label: 'Conditions',
                              icon: Icons.fact_check_outlined,
                              selectedIcon: Icons.fact_check,
                              selected: _onCaseSection(location, 'conditions'),
                              status: issuesStatus(
                                conditions: conditions,
                                claimedIds: claimed,
                              ),
                              onTap: () => _open(
                                context,
                                _sectionPath(caseId, AuthRoutes.caseConditions),
                              ),
                            ),
                            _SectionRow(
                              label: 'My Uploads',
                              icon: Icons.description_outlined,
                              selectedIcon: Icons.description,
                              selected: _onCaseSection(location, 'evidence'),
                              status: documentsStatus(documentCount),
                              onTap: () => _open(
                                context,
                                _sectionPath(caseId, AuthRoutes.caseDocuments),
                              ),
                            ),
                            _SectionRow(
                              label: 'Forms',
                              icon: Icons.article_outlined,
                              selectedIcon: Icons.article,
                              selected: _onCaseSection(location, 'prepare'),
                              status: formsStatus(reviewCount),
                              onTap: () => _open(
                                context,
                                _sectionPath(caseId, AuthRoutes.casePrepare),
                              ),
                            ),
                            _SectionRow(
                              label: 'Package',
                              icon: Icons.inventory_2_outlined,
                              selectedIcon: Icons.inventory_2,
                              selected: _onCaseSection(location, 'package'),
                              status: packageStatus(packageStarted),
                              onTap: () => _open(
                                context,
                                _sectionPath(caseId, AuthRoutes.casePackage),
                              ),
                            ),
                            _SectionRow(
                              label: 'C&P Prep',
                              icon: Icons.event_outlined,
                              selectedIcon: Icons.event,
                              selected: _onCaseSection(location, 'exams'),
                              status: examsStatus(examCount),
                              onTap: () => _open(
                                context,
                                _sectionPath(caseId, AuthRoutes.caseExams),
                              ),
                            ),
                            _SectionRow(
                              label: 'Decisions',
                              icon: Icons.balance_outlined,
                              selectedIcon: Icons.balance,
                              selected: _onCaseSection(location, 'decisions'),
                              status: decisionsStatus(decisionCount),
                              onTap: () => _open(
                                context,
                                _sectionPath(caseId, AuthRoutes.caseDecisions),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 16),
            _ToolRow(
              label: 'Symptoms Tracker',
              icon: Icons.monitor_heart_outlined,
              selected:
                  location == AuthRoutes.symptoms ||
                  location.startsWith('${AuthRoutes.symptoms}/'),
              onTap: () => _open(context, AuthRoutes.symptoms),
            ),
            _ToolRow(
              label: 'VA Ratings Calculator',
              icon: Icons.calculate_outlined,
              selected: location == AuthRoutes.calculator,
              onTap: () => _open(context, AuthRoutes.calculator),
            ),
          ],
        ),
      ),
    );
  }

  String _casePath(String? caseId) {
    if (caseId == null) return AuthRoutes.home;
    return AuthRoutes.caseStep(caseId);
  }

  String _sectionPath(String? caseId, String Function(String id) path) {
    if (caseId == null) return AuthRoutes.home;
    return path(caseId);
  }

  void _open(BuildContext context, String path) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    context.go(path);
  }
}

class _CaseHeading extends StatelessWidget {
  const _CaseHeading({
    required this.label,
    required this.open,
    required this.onToggle,
  });

  final String label;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      expanded: open,
      label: label,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
          child: Row(
            children: [
              Icon(
                open ? Icons.expand_more : Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.status,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final ClaimSectionStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected || status == ClaimSectionStatus.inProgress
        ? scheme.onSurface
        : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 1, 0, 1),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Icon(selected ? selectedIcon : icon, size: 20, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (status == ClaimSectionStatus.done)
                  const AppBadge.quiet(icon: Icons.check),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _caseLabel(WidgetRef ref, String? caseId) {
  if (caseId == null) return openCaseName;
  final cases = ref
      .watch(casesProvider)
      .maybeWhen(data: (value) => value, orElse: () => const <VeteranCase>[]);
  for (final item in cases) {
    if (item.id == caseId) return caseDisplayName(item.displayName);
  }
  return openCaseName;
}

bool _showBubble(String location) {
  if (location == AuthRoutes.home) return true;
  final id = caseIdFromLocation(location);
  if (id == null) return false;
  return location == '/cases/$id' || location.startsWith('/cases/$id/');
}

/// The case whose sections are on screen, when the path is `/cases/:caseId/...`.
String? caseIdFromLocation(String location) {
  final match = RegExp(r'^/cases/([^/]+)').firstMatch(location);
  final id = match?.group(1);
  if (id == null || id.isEmpty) return null;
  return id;
}

bool _onCaseStep(String location) {
  if (location == AuthRoutes.home) return true;
  final id = caseIdFromLocation(location);
  if (id == null) return false;
  return location == '/cases/$id' ||
      location == '/cases/$id/overview' ||
      location == '/cases/$id/intent';
}

bool _onCaseSection(String location, String section) {
  final id = caseIdFromLocation(location);
  if (id == null) return false;
  return location == '/cases/$id/$section' ||
      location.startsWith('/cases/$id/$section/');
}
