import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_ui.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import '../../claim/claim_guide.dart';
import '../../claim/package_form_repository.dart';
import '../../forms/form_catalog.dart';
import '../../forms/package_form.dart';
import 'form_field_editor.dart';
import 'shell_pages.dart';

/// Watermarked preview of Intent to File, opened from Case Info. Back returns
/// there. Download uses the same dialog as the Forms page. Nothing is filed.
class IntentPreviewScreen extends ConsumerStatefulWidget {
  const IntentPreviewScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<IntentPreviewScreen> createState() =>
      _IntentPreviewScreenState();
}

class _IntentPreviewScreenState extends ConsumerState<IntentPreviewScreen> {
  static const _formNumber = '21-0966';

  var _ensureStarted = false;
  String? _error;

  void _scheduleEnsure() {
    if (_ensureStarted || _error != null) return;
    _ensureStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_ensure());
    });
  }

  Future<void> _ensure() async {
    final uid = ref.read(authControllerProvider).session?.uid;
    final def = formDefFor(_formNumber);
    if (uid == null || def == null) {
      if (!mounted) return;
      setState(() => _error = 'That form could not be opened.');
      return;
    }
    try {
      await ref
          .read(packageFormRepositoryProvider)
          .add(
            uid: uid,
            caseId: widget.caseId,
            formNumber: def.formNumber,
            displayLabel: def.shortTitle,
          );
    } on ClaimGuideFailure catch (error) {
      if (error.message == 'This form is already in your package.') return;
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'That could not be added. Try again.');
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _ensureStarted = false;
    });
  }

  Widget _waiting() {
    return const Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final forms = ref.watch(packageFormsProvider(widget.caseId));
    final def = formDefFor(_formNumber);
    return ShellPage(
      title: 'Intent to File',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(112, 48)),
              onPressed: () => context.go(AuthRoutes.caseStep(widget.caseId)),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(height: 12),
          forms.when(
            loading: _waiting,
            error: (_, _) => const ErrorText('That form could not be opened.'),
            data: (all) {
              PackageForm? entry;
              for (final form in all) {
                if (form.formNumber == _formNumber) {
                  entry = form;
                  break;
                }
              }
              if (entry == null) {
                _scheduleEnsure();
                if (_error != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ErrorText(_error!),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(112, 48),
                          ),
                          onPressed: _retry,
                          child: const Text('Try again'),
                        ),
                      ),
                    ],
                  );
                }
                return _waiting();
              }
              if (def == null) {
                return const ErrorText('That form could not be opened.');
              }
              return FormPdfPreview(
                packageFormId: entry.id,
                sectionDrafts: entry.sectionDrafts,
                caseId: widget.caseId,
                formNumber: def.formNumber,
                download: def.download,
              );
            },
          ),
        ],
      ),
    );
  }
}
