import 'package:flutter/material.dart';

import '../forms/text_input_chain.dart';

/// A chat-style text input with the send button built into the field.
///
/// The one control for sending text to the assistant: Vet Buddy, Ask for a
/// change, and the Nexus gap interview all use it. The text area and the round
/// send button live inside one bordered surface that lights up on focus, so
/// the button reads as part of the field rather than a separate control, and
/// there is no Update, Next, or Send button beside it.
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
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(_onChanged);
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
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  bool get _canSend =>
      widget.enabled && !widget.busy && (widget.allowEmptySend || _hasText);

  void _send() {
    if (!_canSend) return;
    widget.onSend(widget.controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final disabled = !widget.enabled || widget.busy;
    final focused = _focus.hasFocus && !disabled;
    final fill =
        theme.inputDecorationTheme.fillColor ?? scheme.surfaceContainerHighest;
    final counter = quietCount(
      context,
      currentLength: widget.controller.text.length,
      maxLength: widget.maxLength,
      countVisibleFrom: widget.countVisibleFrom,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: focused ? scheme.primary : scheme.outline,
              width: focused ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                // A borderless field so the surrounding surface is the only
                // frame; the send button shares that frame.
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: !disabled,
                  minLines: widget.minLines,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  textCapitalization: widget.textCapitalization,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  cursorColor: scheme.primary,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    counterText: '',
                    hintText: widget.hintText,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _SendButton(
                  tooltip: widget.sendTooltip,
                  busy: widget.busy,
                  onPressed: _canSend ? _send : null,
                ),
              ),
            ],
          ),
        ),
        if (counter != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 6),
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
              : scheme.primary.withValues(alpha: 0.32),
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
                      color: enabled
                          ? scheme.onPrimary
                          : scheme.onPrimary.withValues(alpha: 0.7),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
