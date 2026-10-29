import 'package:flutter/material.dart';

/// Thickness of the scrollbar thumb.
const scrollbarThumbThickness = 8.0;

/// Gap between the thumb and the outer edge of the scroll view.
const scrollbarCrossAxisMargin = 2.0;

/// Space kept clear of the thumb: the thumb, its outer gap, and a gap
/// before the content.
const scrollbarGutter = scrollbarThumbThickness + scrollbarCrossAxisMargin + 4.0;

/// Desktop and web scrollbars sit in [scrollbarGutter] beside the content.
///
/// Flutter's default bar paints on top of the page. A text field keeps the
/// platform bar so a line of text does not lose the gutter.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) == Axis.horizontal) {
      return child;
    }
    if (_scrollsEditableText(context)) {
      return super.buildScrollbar(context, child, details);
    }
    final owned = _wrappedByScrollbar(context);
    final desktop = _desktopPlatform(getPlatform(context));
    if (!owned && !desktop) return child;
    final inset = Padding(
      padding: const EdgeInsetsDirectional.only(end: scrollbarGutter),
      child: child,
    );
    if (owned) return inset;
    assert(details.controller != null);
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true,
      interactive: true,
      child: inset,
    );
  }
}

bool _desktopPlatform(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.iOS:
      return false;
  }
}

bool _scrollsEditableText(BuildContext context) {
  return context.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// True when a [Scrollbar] already wraps this scroll view, with no other
/// scroll view between them. That bar paints into the gutter.
bool _wrappedByScrollbar(BuildContext context) {
  var wrapped = false;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is Scrollbar || widget is RawScrollbar) {
      wrapped = true;
      return false;
    }
    if (widget is Scrollable || widget is Viewport) {
      return false;
    }
    return true;
  });
  return wrapped;
}
