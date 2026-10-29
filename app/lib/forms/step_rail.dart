import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app/app_scroll.dart';
import '../app/app_theme.dart';

/// Where one step sits in the flow.
///
/// [done] is finished, [current] is open now, [open] is reachable but not done,
/// and [locked] cannot be opened yet.
enum StepRailState { done, current, open, locked }

/// One step in a [StepRail].
class StepRailItem {
  const StepRailItem({required this.label, required this.state, this.onTap});

  final String label;
  final StepRailState state;

  /// Null when the step cannot be opened. A [StepRailState.locked] step is
  /// always null, and the current step does not reopen itself.
  final VoidCallback? onTap;
}

/// The one horizontal step indicator.
///
/// Numbered circles joined by a line, a white check on green when a step is
/// done, a blue circle for the current step, and a muted circle for a locked
/// step. The rail
/// scrolls when the steps do not fit: it centers the current step, a mouse or
/// trackpad can drag it, the wheel moves it sideways, and outlined chevrons at
/// the ends appear only when there is more to see.
///
/// [compact] is the phone rail: smaller circles, no label under them, and the
/// short name on a tooltip. The circles keep their size and the lines between
/// them grow so the row fills the width. When the circles cannot fit, the row
/// scrolls.
class StepRail extends StatefulWidget {
  const StepRail({super.key, required this.steps, this.compact = false});

  final List<StepRailItem> steps;

  final bool compact;

  @override
  State<StepRail> createState() => _StepRailState();
}

class _StepRailState extends State<StepRail> {
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  final List<GlobalKey> _keys = [];
  var _overflow = false;
  var _canBack = false;
  var _canForward = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sync();
      _revealCurrent();
    });
  }

  @override
  void didUpdateWidget(StepRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.steps.indexWhere(_isCurrent);
    final after = widget.steps.indexWhere(_isCurrent);
    if (before != after) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealCurrent());
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_sync);
    _scroll.dispose();
    super.dispose();
  }

  static bool _isCurrent(StepRailItem step) =>
      step.state == StepRailState.current;

  void _syncKeys() {
    while (_keys.length < widget.steps.length) {
      _keys.add(GlobalKey());
    }
    if (_keys.length > widget.steps.length) {
      _keys.removeRange(widget.steps.length, _keys.length);
    }
  }

  void _sync() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final overflow = position.maxScrollExtent > 1;
    final canBack = position.pixels > 1;
    final canForward = position.pixels < position.maxScrollExtent - 1;
    if (overflow == _overflow &&
        canBack == _canBack &&
        canForward == _canForward) {
      return;
    }
    setState(() {
      _overflow = overflow;
      _canBack = canBack;
      _canForward = canForward;
    });
  }

  void _revealCurrent() {
    if (!mounted) return;
    final index = widget.steps.indexWhere(_isCurrent);
    if (index < 0 || index >= _keys.length) return;
    final target = _keys[index].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _nudge(int direction) {
    final viewport = _viewport.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !_scroll.hasClients) return;
    final width = viewport.size.width;
    final keys = direction > 0 ? _keys : _keys.reversed;
    for (final key in keys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) continue;
      final left = box.localToGlobal(Offset.zero, ancestor: viewport).dx;
      final right = left + box.size.width;
      if (direction > 0 && right > width + 1) {
        final page = width * 0.85;
        final reveal = right - width + 8;
        _animate(box.size.width <= width ? reveal : page);
        return;
      }
      if (direction < 0 && left < -1) {
        final page = -width * 0.85;
        final reveal = left - 8;
        _animate(box.size.width <= width ? reveal : page);
        return;
      }
    }
  }

  void _animate(double delta) {
    final target = (_scroll.offset + delta).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _onWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients) return;
    if (_scroll.position.maxScrollExtent <= 0) return;
    final delta = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (delta == 0) return;
    final target = (_scroll.offset + delta).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    _syncKeys();
    if (!widget.compact) return _scrollRail();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = widget.steps.length;
        final gaps = count > 1 ? count - 1 : 0;
        final needed =
            count * _RailNode.compactCircle + gaps * _RailNode.compactMinGap;
        if (!width.isFinite || width < needed) return _scrollRail();
        return _stretchedRail();
      },
    );
  }

  /// Circles at the two ends, and a line between each pair that takes the
  /// leftover width.
  Widget _stretchedRail() {
    final scheme = Theme.of(context).colorScheme;
    final steps = widget.steps;
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          KeyedSubtree(
            key: _keys[i],
            child: _RailNode(
              number: i + 1,
              step: steps[i],
              compact: true,
              circleOnly: true,
              showLineBefore: false,
              showLineAfter: false,
              lineBeforeComplete: false,
              lineAfterComplete: false,
            ),
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: steps[i].state == StepRailState.done
                    ? AppColors.success
                    : scheme.outline,
              ),
            ),
        ],
      ],
    );
  }

  Widget _scrollRail() {
    return Row(
      children: [
        if (_overflow) ...[
          _RailArrow(
            tooltip: 'Earlier steps',
            icon: Icons.chevron_left,
            compact: widget.compact,
            onPressed: _canBack ? () => _nudge(-1) : null,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Listener(
            onPointerSignal: _onWheel,
            child: ScrollConfiguration(
              behavior: const _RailScrollBehavior(),
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (notification) {
                  _sync();
                  return false;
                },
                child: SingleChildScrollView(
                  key: _viewport,
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < widget.steps.length; i++)
                        KeyedSubtree(
                          key: _keys[i],
                          child: _RailNode(
                            number: i + 1,
                            step: widget.steps[i],
                            compact: widget.compact,
                            showLineBefore: i > 0,
                            showLineAfter: i < widget.steps.length - 1,
                            lineBeforeComplete:
                                i > 0 &&
                                widget.steps[i - 1].state == StepRailState.done,
                            lineAfterComplete:
                                widget.steps[i].state == StepRailState.done,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_overflow) ...[
          const SizedBox(width: 8),
          _RailArrow(
            tooltip: 'Later steps',
            icon: Icons.chevron_right,
            compact: widget.compact,
            onPressed: _canForward ? () => _nudge(1) : null,
          ),
        ],
      ],
    );
  }
}

/// Mouse and trackpad can drag the rail. The app scrollbar skips horizontal
/// lists, so the rail does not draw one of its own.
class _RailScrollBehavior extends AppScrollBehavior {
  const _RailScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}

class _RailArrow extends StatelessWidget {
  const _RailArrow({
    required this.tooltip,
    required this.icon,
    required this.compact,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final side = compact ? 36.0 : 44.0;
    final button = OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(side, side),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Icon(icon, semanticLabel: tooltip),
    );
    if (onPressed == null) return button;
    return Tooltip(message: tooltip, child: button);
  }
}

/// One numbered circle, the line that joins it to the step before, and its
/// label. The circle shows a check when the step is done.
class _RailNode extends StatelessWidget {
  const _RailNode({
    required this.number,
    required this.step,
    required this.compact,
    required this.showLineBefore,
    required this.showLineAfter,
    required this.lineBeforeComplete,
    required this.lineAfterComplete,
    this.circleOnly = false,
  });

  final int number;
  final StepRailItem step;
  final bool compact;

  /// The circle alone, with no line inside the node. The stretched phone rail
  /// draws the lines between nodes.
  final bool circleOnly;
  final bool showLineBefore;
  final bool showLineAfter;
  final bool lineBeforeComplete;
  final bool lineAfterComplete;

  static const _circle = 28.0;
  static const compactCircle = 22.0;
  static const compactMinGap = 8.0;
  static const _labelWidth = 96.0;
  static const _compactWidth = 44.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = step.state;
    final current = state == StepRailState.current;
    final done = state == StepRailState.done;
    final locked = state == StepRailState.locked;

    final numberColor = current
        ? scheme.onPrimary
        : locked
        ? scheme.onSurfaceVariant
        : scheme.onSurface;
    final circleSize = compact ? compactCircle : _circle;
    final circle = Container(
      width: circleSize,
      height: circleSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done
            ? AppColors.success
            : current
            ? scheme.primary
            : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: done
              ? AppColors.success
              : current
              ? scheme.primary
              : scheme.outline,
          width: current || done ? 0 : 1.5,
        ),
      ),
      child: done
          ? Icon(Icons.check, size: compact ? 14 : 16, color: Colors.white)
          : Text(
              '$number',
              style: theme.textTheme.labelMedium?.copyWith(
                color: numberColor,
                fontWeight: FontWeight.w700,
              ),
            ),
    );

    final node = Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 0 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: step.onTap,
          borderRadius: BorderRadius.circular(12),
          child: circleOnly
              ? circle
              : Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: compact ? 2 : 4,
                  ),
                  child: _labeledCircle(theme, scheme, circle, current),
                ),
        ),
      ),
    );
    if (!compact) return node;
    return Tooltip(message: step.label, child: node);
  }

  Widget _labeledCircle(
    ThemeData theme,
    ColorScheme scheme,
    Widget circle,
    bool current,
  ) {
    final nodeWidth = compact ? _compactWidth : _labelWidth;
    Color lineColor(bool show, bool complete) {
      if (!show) return Colors.transparent;
      return complete ? AppColors.success : scheme.outline;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: nodeWidth,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 2,
                  color: lineColor(showLineBefore, lineBeforeComplete),
                ),
              ),
              circle,
              Expanded(
                child: Container(
                  height: 2,
                  color: lineColor(showLineAfter, lineAfterComplete),
                ),
              ),
            ],
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: nodeWidth,
            child: Text(
              step.label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: current ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
