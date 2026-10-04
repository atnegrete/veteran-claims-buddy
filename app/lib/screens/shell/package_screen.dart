import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_badge.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../claim/claim_review.dart';
import '../../claim/package_guidance.dart';
import '../../claim/package_repository.dart';
import '../../claim/review_repository.dart';
import '../../claim/va_rules.dart';
import 'shell_pages.dart';

class PackageScreen extends StatelessWidget {
  const PackageScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return ShellPage(
      title: 'Package',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EarlierClaimNote(caseId: caseId),
          const Text(
            'The digital package is not generated yet. Generating it is a paid step. This app does not file with the VA.',
          ),
          const SizedBox(height: 12),
          const AppBadge.notFiled(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go(AuthRoutes.casePackageSubmit(caseId)),
            child: const Text('How you submit it'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go(AuthRoutes.casePackageGenerate(caseId)),
            child: const Text('Generate the package'),
          ),
        ],
      ),
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
              const Text(
                'You submit this yourself on VA.gov or by mail. This app does not file it and does not sign it.',
              ),
              const SizedBox(height: 12),
              const AppBadge.notFiled(),
              const SizedBox(height: 16),
              if (drafts.isEmpty)
                const Text(
                  'There is no package to upload yet. The form is not filled here.',
                )
              else
                for (final review in drafts) ...[
                  Text(
                    'This claim has a draft ${reviewTitle(_path(review.type))} for ${review.displayName}. The form is ${review.formId}. That form is not filled here.',
                  ),
                  const SizedBox(height: 12),
                ],
              const Text(
                'Sign where the VA form asks you to. Save the confirmation the VA gives you.',
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
              const Text(
                'Mailing instructions stay on that VA page. Vet Buddy can explain this. It cannot file the claim.',
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
