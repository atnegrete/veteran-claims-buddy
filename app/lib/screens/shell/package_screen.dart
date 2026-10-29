import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_badge.dart';
import '../../app/app_ui.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../billing/entitlement_service.dart';
import '../../billing/premium_status_view.dart';
import '../../claim/claim_review.dart';
import '../../claim/issue_lane.dart';
import '../../claim/package_form_repository.dart';
import '../../claim/package_guidance.dart';
import '../../claim/package_repository.dart';
import '../../claim/review_repository.dart';
import '../../claim/va_rules.dart';
import '../../forms/form_catalog.dart';
import '../../forms/package_form.dart';
import 'shell_pages.dart';

class PackageScreen extends ConsumerWidget {
  const PackageScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premiumAsync = ref.watch(premiumStatusProvider);
    final unlocksAsync = ref.watch(caseUnlocksProvider);
    if (premiumAsync.isLoading || unlocksAsync.isLoading) {
      return const ShellPage(
        title: 'Package',
        child: PremiumStatusLoading(),
      );
    }
    final status = premiumAsync.asData?.value ?? PremiumStatus.inactive;
    final unlocks = unlocksAsync.asData?.value ?? const <String>{};
    final unlocked = status.subscriptionActive || unlocks.contains(caseId);
    final entries = ref.watch(packageFormsProvider(caseId)).maybeWhen(
          data: (value) => value,
          orElse: () => const <PackageForm>[],
        );
    return ShellPage(
      title: 'Package',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EarlierClaimNote(caseId: caseId),
          const LeadText(
            'Every form you add to this claim is tracked here. Open one to answer its questions, draft a statement, and preview the fields. Nothing is automatically filed with the VA at any point.',
          ),
          const SizedBox(height: 16),
          _TrackedForms(caseId: caseId, entries: entries),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          const FilingNote(),
          const SizedBox(height: 16),
          if (unlocked) ...[
            const InfoNote(
              tone: InfoNoteTone.success,
              text: 'This case is unlocked. You can prepare and submit the package.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go(AuthRoutes.casePackageSubmit(caseId)),
              child: const Text('How you submit it'),
            ),
          ] else ...[
            const LeadText(
              'The digital package is not generated yet. Generating it is a paid step.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AuthRoutes.casePackageSubmit(caseId)),
              child: const Text('How you submit it'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  context.go(AuthRoutes.casePackageGenerate(caseId)),
              child: const Text('Generate the package'),
            ),
          ],
        ],
      ),
    );
  }
}

/// The live list of forms added to this claim, grouped by form. Each entry
/// opens its form detail for editing and preview.
class _TrackedForms extends StatelessWidget {
  const _TrackedForms({required this.caseId, required this.entries});

  final String caseId;
  final List<PackageForm> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LeadText('No forms added yet.'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go(AuthRoutes.casePrepare(caseId)),
            child: const Text('Browse forms'),
          ),
        ],
      );
    }
    final byPacket = <String, List<PackageForm>>{};
    for (final entry in entries) {
      final name = entry.packet.isEmpty ? 'newClaim' : entry.packet;
      byPacket.putIfAbsent(name, () => []).add(entry);
    }
    const order = [
      'record',
      'newClaim',
      'supplemental',
      'higherLevel',
      'board',
      'side',
      'shared',
    ];
    final names = [
      for (final name in order)
        if (byPacket.containsKey(name)) name,
      for (final name in byPacket.keys)
        if (!order.contains(name)) name,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final name in names) ...[
          Eyebrow(_packetHeading(name)),
          const SizedBox(height: 8),
          if (name == 'higherLevel') ...[
            const InfoNote(
              text: 'The VA will not look at new files on a Higher-Level Review.',
            ),
            const SizedBox(height: 8),
          ],
          _FormsInPacket(
            caseId: caseId,
            entries: byPacket[name]!,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

String _packetHeading(String name) {
  if (name == 'side') return 'Other forms';
  for (final entry in claimPacketLabels.entries) {
    if (claimPacketNames[entry.key] == name) return entry.value;
  }
  return name;
}

class _FormsInPacket extends StatelessWidget {
  const _FormsInPacket({required this.caseId, required this.entries});

  final String caseId;
  final List<PackageForm> entries;

  @override
  Widget build(BuildContext context) {
    final byForm = <String, List<PackageForm>>{};
    for (final entry in entries) {
      byForm.putIfAbsent(entry.formNumber, () => []).add(entry);
    }
    final formNumbers = byForm.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final formNumber in formNumbers) ...[
          _FormGroup(
            caseId: caseId,
            def: formDefFor(formNumber),
            formNumber: formNumber,
            group: byForm[formNumber]!,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _FormGroup extends StatelessWidget {
  const _FormGroup({
    required this.caseId,
    required this.def,
    required this.formNumber,
    required this.group,
  });

  final String caseId;
  final VaFormDef? def;
  final String formNumber;
  final List<PackageForm> group;

  String _statusLabel(PackageForm entry) => switch (entry.status) {
        PackageFormStatus.ready => 'Ready to preview',
        PackageFormStatus.needsInput => 'Needs your input',
        PackageFormStatus.draft => 'Auto-filled',
      };

  @override
  Widget build(BuildContext context) {
    final title = def?.shortTitle ?? formNumber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Eyebrow(title)),
            if (group.length > 1)
              AppBadge.primary(label: '${group.length} added'),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < group.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          AppNavRow(
            title: group[i].displayLabel.isEmpty
                ? title
                : group[i].displayLabel,
            subtitle: _statusLabel(group[i]),
            onTap: () {
              final entry = group[i];
              final query = <String, String>{
                if (entry.multiplicityKey.isNotEmpty) 'copy': entry.multiplicityKey,
                if (entry.packet.isNotEmpty) 'packet': entry.packet,
                if (entry.nexusKind.isNotEmpty) 'kind': entry.nexusKind,
              };
              final path = AuthRoutes.casePrepareForm(caseId, formNumber);
              context.go(
                query.isEmpty ? path : Uri(path: path, queryParameters: query).toString(),
              );
            },
          ),
        ],
      ],
    );
  }
}

class PackageSubmitScreen extends ConsumerWidget {
  const PackageSubmitScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(claimReviewsProvider(caseId));
    final check = ref.watch(packageCheckProvider(caseId));
    return ShellPage(
      title: 'How you submit it',
      child: reviews.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('These instructions could not be opened.'),
        data: (drafts) {
          final saved = check.maybeWhen(
            data: (value) => value,
            orElse: () => PackageCheck.empty,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LeadText(
                'Each set is sent on its own on VA.gov or by mail. This app does not file it and does not sign it.',
              ),
              const SizedBox(height: 12),
              const FilingNote(),
              const SizedBox(height: 16),
              if (drafts.isEmpty)
                const LeadText('There is no package to upload yet.')
              else
                for (final review in drafts) ...[
                  Text(
                    'A ${reviewTitle(_path(review.type))} draft for ${review.displayName} is ready. Form ${review.formId} is not filled here.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                ],
              const LeadText(
                'Sign where the VA form asks you to, and save the confirmation the VA gives you.',
              ),
              const SizedBox(height: 8),
              const _VaLink(
                label: 'VA decision reviews',
                url: vaDecisionReviewsUrl,
              ),
              const _VaLink(
                label: 'How to file on VA.gov',
                url: vaHowToFileUrl,
              ),
              const SizedBox(height: 8),
              const InfoNote(
                text: 'Mailing instructions stay on the VA page. Vet Buddy can explain them but cannot file the claim.',
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: saved.openedVaPage,
                onChanged: check.isLoading
                    ? null
                    : (value) =>
                          _save(ref, saved, openedVaPage: value ?? false),
                title: const Text('I opened the VA instructions'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: saved.savedConfirmation,
                onChanged: check.isLoading
                    ? null
                    : (value) =>
                          _save(ref, saved, savedConfirmation: value ?? false),
                title: const Text('I saved the VA confirmation'),
              ),
            ],
          );
        },
      ),
    );
  }

  ReviewPath _path(String type) {
    return switch (type) {
      'higherLevelReview' => ReviewPath.higherLevel,
      'boardAppeal' => ReviewPath.board,
      _ => ReviewPath.supplemental,
    };
  }

  Future<void> _save(
    WidgetRef ref,
    PackageCheck current, {
    bool? openedVaPage,
    bool? savedConfirmation,
  }) async {
    final uid = ref.read(authControllerProvider).session?.uid;
    if (uid == null) return;
    try {
      await ref
          .read(packageCheckRepositoryProvider)
          .save(
            uid: uid,
            caseId: caseId,
            check: PackageCheck(
              openedVaPage: openedVaPage ?? current.openedVaPage,
              savedConfirmation: savedConfirmation ?? current.savedConfirmation,
            ),
          );
    } on Object {
      return;
    }
  }
}

class _VaLink extends StatelessWidget {
  const _VaLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () async {
          final opened = await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
          if (opened || !context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That page could not be opened.')),
          );
        },
        child: Text(label),
      ),
    );
  }
}
