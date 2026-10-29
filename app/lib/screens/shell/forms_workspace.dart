import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_badge.dart';
import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../claim/form_recommendations.dart';
import '../../claim/form_recommender.dart';
import '../../claim/package_form_repository.dart';
import '../../forms/form_catalog.dart';
import '../../forms/package_form.dart';
import '../../forms/nested_split.dart';
import 'intent_first_mark.dart';
import 'shell_pages.dart';

/// The form list beside the open form. A wide pane shows both. A narrow pane
/// shows only the form; Back on the form returns to the list.
class FormsWorkspace extends ConsumerWidget {
  const FormsWorkspace({
    super.key,
    required this.caseId,
    required this.formNumber,
    required this.child,
  });

  final String caseId;
  final String formNumber;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = formDefFor(formNumber);
    final title = def?.shortTitle ?? 'Form';
    final added = ref
        .watch(packageFormsProvider(caseId))
        .maybeWhen(
          data: (forms) =>
              forms.where((form) => form.formNumber == formNumber).length,
          orElse: () => 0,
        );
    final addedLabel = addedCountLabel(added);
    return LayoutBuilder(
      builder: (context, constraints) {
        // ShellPage pads 24 on each side, and that is the width NestedSplit sees.
        final listHidden = constraints.maxWidth - 48 < NestedSplit.breakWidth;
        return ShellPage(
          title: title,
          titleTrailing: listHidden && addedLabel != null
              ? AppBadge.primary(label: addedLabel)
              : null,
          eyebrow: def?.isEvidence == true ? 'Evidence' : null,
          maxWidth: double.infinity,
          expandChild: true,
          wrapInCard: false,
          child: NestedSplit(
            open: true,
            master: FormsMenu(caseId: caseId, formNumber: formNumber),
            detail: NestedListHidden(hidden: listHidden, child: child),
          ),
        );
      },
    );
  }
}

/// Opens the VA's full form catalog. A card, so it reads as its own action.
class VaFormsCatalogCard extends StatelessWidget {
  const VaFormsCatalogCard({super.key});

  static final _uri = Uri.parse('https://www.va.gov/find-forms/');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppNavRow(
      title: 'Not seeing a form you need?',
      subtitle: 'Check the full list of forms on the VA website.',
      accent: AppColors.sand,
      showChevron: false,
      trailing: Icon(
        Icons.open_in_new,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: () async {
        final opened = await launchUrl(
          _uri,
          mode: LaunchMode.externalApplication,
        );
        if (opened || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That page could not be opened.')),
        );
      },
    );
  }
}

class FormsMenu extends ConsumerWidget {
  const FormsMenu({super.key, required this.caseId, required this.formNumber});

  final String caseId;
  final String formNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(formRecommendationsProvider(caseId));
    final forms = ref
        .watch(packageFormsProvider(caseId))
        .maybeWhen(data: (value) => value, orElse: () => const <PackageForm>[]);
    return NestedForm(
      expandChild: true,
      title: 'Forms',
      child: ListView(
        children: [
          EarlierClaimNote(caseId: caseId),
          for (final packet in formPacketOrder)
            if (filingFormSuggestions(result, packet).isNotEmpty) ...[
              _MenuGroup(
                title: formPacketLabels[packet]!,
                suggestions: filingFormSuggestions(result, packet),
                caseId: caseId,
                formNumber: formNumber,
                forms: forms,
              ),
              const SizedBox(height: 8),
            ],
          if (otherCommonForms(result).isNotEmpty) ...[
            _MenuGroup(
              title: otherCommonFormsTitle,
              suggestions: otherCommonForms(result),
              caseId: caseId,
              formNumber: formNumber,
              forms: forms,
            ),
            const SizedBox(height: 8),
          ],
          const VaFormsCatalogCard(),
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({
    required this.title,
    required this.suggestions,
    required this.caseId,
    required this.formNumber,
    required this.forms,
  });

  final String title;
  final List<FormSuggestion> suggestions;
  final String caseId;
  final String formNumber;
  final List<PackageForm> forms;

  bool _selected(FormSuggestion suggestion, String? copy) {
    if (suggestion.kind == SuggestionKind.evidence) {
      if (formNumber != nexusFormId) return false;
      final key = copy ?? '';
      if (suggestion.multiplicityKey.isEmpty) return key.isEmpty;
      return key == suggestion.multiplicityKey;
    }
    return suggestion.id == formNumber;
  }

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final copy = GoRouterState.of(context).uri.queryParameters['copy'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Eyebrow(title),
        const SizedBox(height: 8),
        for (final suggestion in suggestions)
          SelectRow(
            title: suggestion.title,
            subtitle: formListReason(suggestion, addedCount(forms, suggestion)),
            selected: _selected(suggestion, copy),
            leading: intentFirstRow(suggestion)
                ? const IntentFirstMark()
                : null,
            accent: intentFirstRow(suggestion) ? AppColors.sand : null,
            trailing: switch (addedCountLabel(addedCount(forms, suggestion))) {
              final label? => AppBadge.primary(label: label),
              _ => null,
            },
            onTap: () {
              final route = routeForFormSuggestion(caseId, suggestion);
              if (route != null) context.go(route);
            },
          ),
      ],
    );
  }
}
