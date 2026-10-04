import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_badge.dart';
import '../../app/app_theme.dart';
import '../../auth/auth_redirect.dart';
import '../../claim/claim_document.dart';
import '../../claim/claim_guide.dart';
import '../../claim/document_repository.dart';
import '../../forms/form_actions.dart';
import '../../forms/text_input_chain.dart';
import 'shell_pages.dart';

class DocumentFactsScreen extends ConsumerWidget {
  const DocumentFactsScreen({
    super.key,
    required this.caseId,
    required this.documentId,
  });

  final String caseId;
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = ref.watch(documentFactsProvider(documentId));
    return ShellPage(
      title: 'Statements',
      child: facts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('These statements could not be opened.'),
        data: (items) {
          final saved = [...items]
            ..sort((a, b) {
              final page = (a.page ?? 0).compareTo(b.page ?? 0);
              if (page != 0) return page;
              return a.factText.compareTo(b.factText);
            });
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'These are statements from the file. Confirm one, correct it, or set it aside. Nothing is filed.',
              ),
              const SizedBox(height: 12),
              const AppBadge.notFiled(),
              const SizedBox(height: 16),
              if (saved.isEmpty)
                const Text('No statements were found in this file.')
              else
                for (var i = 0; i < saved.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _FactCard(
                    caseId: caseId,
                    documentId: documentId,
                    fact: saved[i],
                  ),
                ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      context.go(AuthRoutes.caseDocument(caseId, documentId)),
                  child: const Text('File details'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FactCard extends ConsumerStatefulWidget {
  const _FactCard({
    required this.caseId,
    required this.documentId,
    required this.fact,
  });

  final String caseId;
  final String documentId;
  final DocumentFact fact;

  @override
  ConsumerState<_FactCard> createState() => _FactCardState();
}

class _FactCardState extends ConsumerState<_FactCard> {
  final _correction = TextEditingController();
  var _editing = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _correction.dispose();
    super.dispose();
  }

  Future<void> _review(String status, String? correctedText) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(reviewDocumentFactProvider)(
        documentId: widget.documentId,
        factId: widget.fact.id,
        reviewStatus: status,
        correctedText: correctedText,
      );
      if (mounted) setState(() => _editing = false);
    } on ClaimGuideFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'That could not be saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fact = widget.fact;
    final corrected = fact.correctedText;
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FactBadge(status: fact.reviewStatus),
            const SizedBox(height: 8),
            Text(
              factTypeLabels[fact.factType] ?? 'Other',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (fact.conditionText != null) ...[
              const SizedBox(height: 2),
              Text(fact.conditionText!, style: theme.textTheme.titleMedium),
            ],
            const SizedBox(height: 8),
            if (corrected != null) ...[
              Text(
                'From the file',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(fact.factText),
            if (corrected != null) ...[
              const SizedBox(height: 8),
              Text(
                'Your correction',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(corrected),
            ],
            if (fact.page != null || fact.eventDate != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (fact.page != null) 'Page ${fact.page}',
                  if (fact.eventDate != null) fact.eventDate,
                ].join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_editing) ...[
              const SizedBox(height: 12),
              ChainTextField(
                controller: _correction,
                enabled: !_busy,
                minLines: 2,
                maxLines: 6,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Corrected statement',
                ),
              ),
              FormActions(
                onBack: _busy ? null : () => setState(() => _editing = false),
                onPrimary: _busy
                    ? null
                    : () {
                        final text = _correction.text.trim();
                        if (text.isEmpty) {
                          setState(
                            () => _error = 'Add the corrected statement.',
                          );
                          return;
                        }
                        _review('corrected', text);
                      },
                backLabel: 'Cancel',
                primaryLabel: 'Save',
                busy: _busy,
              ),
            ] else ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : () => _review('confirmed', null),
                child: Text(_busy ? 'Saving…' : 'Confirm'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () {
                        _correction.text = corrected ?? fact.factText;
                        setState(() {
                          _editing = true;
                          _error = null;
                        });
                      },
                child: const Text('Correct'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  style: dangerTextStyle(),
                  onPressed: _busy ? null : () => _review('rejected', null),
                  child: const Text('Set aside'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FactBadge extends StatelessWidget {
  const _FactBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      'confirmed' => const AppBadge.secondary(
        label: 'Confirmed',
        icon: Icons.check,
      ),
      'corrected' => const AppBadge.secondary(label: 'Corrected'),
      'rejected' => const AppBadge.quiet(label: 'Set aside'),
      _ => const AppBadge.primary(label: 'Needs a look'),
    };
  }
}
