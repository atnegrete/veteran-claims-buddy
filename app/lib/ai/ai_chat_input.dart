import 'package:flutter/material.dart';

import '../forms/text_input_chain.dart';

/// A chat-style text input with the send button built into the field.
///
/// The one control for sending text to the assistant: Vet Buddy, Ask for a
/// change, and the Nexus gap interview all use it. A rounded box with a round
/// send button pinned inside its bottom-right corner, so there is no separate
/// Update, Next, or Send button beside it.
///
/// The parent owns the [controller], the [busy] flag, errors, and clearing on
/// success. This widget raises [onSend] with the trimmed text when the button
/// (or the keyboard send action) fires. The character count stays hidden until
/// the text nears [maxLength], and [maxLength] is set per use so each surface
/// keeps its own limit.
class AiChatInput extends StatefulWidget {
  const AiChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    required this.maxLength,
    this.hintText = 'Message',
    this.minLines = 1,
    this.maxLines = 5,
    this.enabled = true,
    this.busy = false,
    this.sendTooltip = 'Send',
    this.allowEmptySend = false,
    this.countVisibleFrom = authCountVisibleFrom,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;

  /// Called with the trimmed text when the user sends.
  final void Function(String text) onSend;

  final int maxLength;
  final String hintText;
  final int minLines;
  final int maxLines;
  final bool enabled;

  /// Shows a spinner in the send button and blocks the field and sending.
  final bool busy;

  final String sendTooltip;

  /// When true, the send button stays active with an empty field. Used where
  /// the action advances a flow (the gap interview) rather than chats.
  final bool allowEmptySend;

  /// Hide the count until the text reaches this fraction of [maxLength]. Null
  /// never shows it.
  final double? countVisibleFrom;

  final TextCapitalization textCapitalization;

  @override
  State<AiChatInput> createState() => _AiChatInputState();
}

class _AiChatInputState extends State<AiChatInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(AiChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  bool get _canSend =>
      widget.enabled &&
      !widget.busy &&
      (widget.allowEmptySend || _hasText);

  void _send() {
    if (!_canSend) return;
    widget.onSend(widget.controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final counter = quietCount(
      context,
      currentLength: widget.controller.text.length,
      maxLength: widget.maxLength,
      countVisibleFrom: widget.countVisibleFrom,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            TextField(
              controller: widget.controller,
              enabled: widget.enabled && !widget.busy,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              textCapitalization: widget.textCapitalization,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: widget.hintText,
                // The field renders no counter; it sits below, outside the
                // Stack, so the send button stays pinned to the box corner.
                counterText: '',
                contentPadding: const EdgeInsets.fromLTRB(16, 14, 56, 14),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: _SendButton(
                tooltip: widget.sendTooltip,
                busy: widget.busy,
                onPressed: _canSend ? _send : null,
              ),
            ),
          ],
        ),
        if (counter != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: Align(alignment: Alignment.centerRight, child: counter),
          ),
      ],
    );
  }
}

/// The round send button that lives inside [AiChatInput]. Blue fill, white
/// arrow; a spinner while busy; faded when it cannot send.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.tooltip,
    required this.busy,
    required this.onPressed,
  });

  final String tooltip;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !busy;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Material(
          color: enabled
              ? scheme.primary
              : scheme.primary.withValues(alpha: 0.38),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      size: 20,
                      color: scheme.onPrimary,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
