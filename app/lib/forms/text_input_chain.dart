import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One form whose text fields move from Next to Done.
///
/// Fields register in the order they build. A field that appears later, such
/// as an end date, joins that order. Next focuses the next enabled text field.
class TextInputChain extends StatefulWidget {
  const TextInputChain({super.key, required this.child});

  final Widget child;

  @override
  State<TextInputChain> createState() => _TextInputChainState();
}

class _ChainNode extends FocusNode {}

/// Skips dropdowns, checkboxes, and buttons. Next stays on text fields.
class _ChainPolicy extends ReadingOrderTraversalPolicy {
  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    return super.sortDescendants(
      descendants.where(
        (node) => node is _ChainNode || identical(node, currentNode),
      ),
      currentNode,
    );
  }
}

class _TextInputChainState extends State<TextInputChain> {
  var _order = <FocusNode>[];
  var _frame = <FocusNode>[];

  void _visit(FocusNode node) {
    if (!_frame.contains(node)) _frame.add(node);
  }

  bool _same(List<FocusNode> a, List<FocusNode> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    _frame = [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _same(_order, _frame)) return;
      setState(() => _order = List<FocusNode>.of(_frame));
    });
    return FocusTraversalGroup(
      policy: _ChainPolicy(),
      child: _TextInputChainScope(
        order: _order,
        visit: _visit,
        child: widget.child,
      ),
    );
  }
}

class _TextInputChainScope extends InheritedWidget {
  const _TextInputChainScope({
    required this.order,
    required this.visit,
    required super.child,
  });

  final List<FocusNode> order;
  final void Function(FocusNode node) visit;

  bool hasNext(FocusNode node) {
    final index = order.indexOf(node);
    return index >= 0 && index < order.length - 1;
  }

  static _TextInputChainScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_TextInputChainScope>();
  }

  @override
  bool updateShouldNotify(_TextInputChainScope oldWidget) {
    if (order.length != oldWidget.order.length) return true;
    for (var i = 0; i < order.length; i++) {
      if (!identical(order[i], oldWidget.order[i])) return true;
    }
    return false;
  }
}

/// Email and password hide the count until the text reaches this fraction of the max.
const authCountVisibleFrom = 0.9;

/// True once [currentLength] reaches [countVisibleFrom] of [maxLength].
///
/// The one place the hide-until-near-the-limit rule is decided, shared by
/// [ChainTextField] and the chat input.
bool quietCountVisible(int currentLength, int? maxLength, double? countVisibleFrom) {
  if (maxLength == null || maxLength <= 0 || countVisibleFrom == null) {
    return false;
  }
  return currentLength * 100 >= (maxLength * countVisibleFrom * 100).round();
}

/// The quiet character counter, or null while it should stay hidden.
///
/// A muted `currentLength/maxLength` that appears only once the text nears the
/// limit. Call it directly, or wrap it with [quietCountBuilder] for a
/// [TextField.buildCounter].
Widget? quietCount(
  BuildContext context, {
  required int currentLength,
  required int? maxLength,
  required double? countVisibleFrom,
}) {
  if (!quietCountVisible(currentLength, maxLength, countVisibleFrom)) return null;
  final limit = maxLength!;
  final remaining = (limit - currentLength).clamp(0, limit);
  final theme = Theme.of(context);
  return Text(
    '$currentLength/$limit',
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
    semanticsLabel: MaterialLocalizations.of(
      context,
    ).remainingTextFieldCharacterCount(remaining),
  );
}

/// A [TextField.buildCounter] that shows [quietCount], or null to keep the
/// default counter when [countVisibleFrom] is null.
InputCounterWidgetBuilder? quietCountBuilder(double? countVisibleFrom) {
  if (countVisibleFrom == null) return null;
  return (
    BuildContext context, {
    required int currentLength,
    required int? maxLength,
    required bool isFocused,
  }) {
    return quietCount(
      context,
      currentLength: currentLength,
      maxLength: maxLength,
      countVisibleFrom: countVisibleFrom,
    );
  };
}

/// A text field that joins a [TextInputChain] when one is present.
///
/// An explicit [textInputAction] wins. The last single-line field is Done.
/// The last multiline field keeps Return.
class ChainTextField extends StatefulWidget {
  const ChainTextField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.decoration,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.countVisibleFrom,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final InputDecoration? decoration;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;

  /// When set, the count stays hidden until the text reaches this fraction of
  /// [maxLength]. [authCountVisibleFrom] is 90%.
  final double? countVisibleFrom;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// When set, the chain does not choose Next, Done, or Return.
  final TextInputAction? textInputAction;

  @override
  State<ChainTextField> createState() => _ChainTextFieldState();
}

class _ChainTextFieldState extends State<ChainTextField> {
  late final FocusNode _focus = _ChainNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  bool get _multiline {
    final lines = widget.maxLines;
    return lines == null || lines > 1;
  }

  @override
  Widget build(BuildContext context) {
    final chain = _TextInputChainScope.maybeOf(context);
    final joined =
        chain != null && widget.enabled && widget.textInputAction == null
        ? chain
        : null;
    joined?.visit(_focus);
    final hasNext = joined != null && joined.hasNext(_focus);
    final action =
        widget.textInputAction ??
        (joined == null
            ? null
            : hasNext
            ? TextInputAction.next
            : _multiline
            ? TextInputAction.newline
            : TextInputAction.done);
    final decoration =
        widget.decoration ??
        (widget.maxLength == null ? null : const InputDecoration());
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      decoration: decoration,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      buildCounter: quietCountBuilder(widget.countVisibleFrom),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: action,
    );
  }
}
