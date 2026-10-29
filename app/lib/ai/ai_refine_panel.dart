import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_ui.dart';

/// The confirmed maximum for the free-text tweak prompt. The count stays
/// visible, per `.cursor/rules/form-layout.mdc`.
const aiRefineMaxLength = 500;

/// A reusable "iterate with the AI" control. It shows an artifact ([child],
/// such as a PDF preview) and, under it, a single free-text box where the user
/// asks for a change in plain words. [onSubmit] applies the change and resolves
/// true when it took, so the box can clear. A compact list of the changes
/// already applied sits under the box. Drop this anywhere a screen needs to
/// refine a generated artifact by chatting with the model.
class AiRefinePanel extends StatefulWidget {
  const AiRefinePanel({
    super.key,
    required this.child,
    required this.onSubmit,
    this.title = 'Ask for a change',
    this.intro =
        'Tell the assistant what to change in plain words. It updates this document.',
    this.hintText = 'e.g. make it shorter, or add that my knee pain started in 2010',
    this.history = const <String>[],
    this.maxLength = aiRefineMaxLength,
    this.enabled = true,
    this.submitLabel = 'Update',
  });

  /// The artifact being refined, shown above the controls.
  final Widget child;

  /// Applies one instruction. Resolve true when the change took (the field then
  /// clears); throw [AiRefineFailure] to show a message.
  final Future<bool> Function(String instruction) onSubmit;

  final String title;
  final String intro;
  final String hintText;

  /// The instructions already applied, newest last.
  final List<String> history;

  final int maxLength;
  final bool enabled;
  final String submitLabel;

  @override
  State<AiRefinePanel> createState() => _AiRefinePanelState();
}

/// Thrown by [AiRefinePanel.onSubmit] to surface a message in the panel.
class AiRefineFailure implements Exception {
  const AiRefineFailure(this.message);
  final String message;
}

class _AiRefinePanelState extends State<AiRefinePanel> {
  final _controller = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy || !widget.enabled) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await widget.onSubmit(text);
      if (!mounted) return;
      if (ok) _controller.clear();
    } on AiRefineFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'That change could not be made.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interactive = widget.enabled && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.child,
        const SizedBox(height: 16),
        Eyebrow(widget.title),
        const SizedBox(height: 8),
        LeadText(widget.intro),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          enabled: interactive,
          minLines: 2,
          maxLines: 4,
          maxLength: widget.maxLength,
          textInputAction: TextInputAction.newline,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: widget.hintText),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            style: secondaryFilledStyle(),
            onPressed: interactive ? _submit : null,
            child: Text(_busy ? 'Updating…' : widget.submitLabel),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          ErrorText(_error!),
        ],
        if (widget.history.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Changes you asked for', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final item in widget.history)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '- $item',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
