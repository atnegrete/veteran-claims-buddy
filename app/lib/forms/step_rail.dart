import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app/app_scroll.dart';

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
/// Numbered circles joined by a line, a check when a step is done, a filled
/// circle for the current step, and a muted circle for a locked step. The rail
/// scrolls when the steps do not fit: it centers the current step, a mouse or
/// trackpad can drag it, the wheel moves it sideways, and outlined chevrons at
/// the ends appear only when there is more to see.
class StepRail extends StatefulWidget {
  const StepRail({super.key, required this.steps});

  final List<StepRailItem> steps;

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
    return Row(
      children: [
        if (_overflow) ...[
          _RailArrow(
            tooltip: 'Earlier steps',
            icon: Icons.chevron_left,
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
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
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
    required this.showLineBefore,
    required this.showLineAfter,
    required this.lineBeforeComplete,
    required this.lineAfterComplete,
  });

  final int number;
  final StepRailItem step;
  final bool showLineBefore;
  final bool showLineAfter;
  final bool lineBeforeComplete;
  final bool lineAfterComplete;

  static const _circle = 28.0;
  static const _labelWidth = 96.0;

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
    final circle = Container(
      width: _circle,
      height: _circle,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: current ? scheme.primary : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: current ? scheme.primary : scheme.outline,
          width: current ? 0 : 1.5,
        ),
      ),
      child: done
          ? Icon(Icons.check, size: 16, color: scheme.onSurfaceVariant)
          : Text(
              '$number',
              style: theme.textTheme.labelMedium?.copyWith(
                color: numberColor,
                fontWeight: FontWeight.w700,
              ),
            ),
    );

    Color lineColor(bool show, bool complete) {
      if (!show) return Colors.transparent;
      return complete ? scheme.onSurfaceVariant : scheme.outline;
    }

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _labelWidth,
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
        const SizedBox(height: 6),
        SizedBox(
          width: _labelWidth,
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
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: step.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: column,
          ),
        ),
      ),
    );
  }
}
