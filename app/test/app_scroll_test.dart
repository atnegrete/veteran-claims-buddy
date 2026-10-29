import 'package:app/app/app_scroll.dart';
import 'package:app/app/app_theme.dart';
import 'package:app/forms/nested_split.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a desktop list keeps its content clear of the scrollbar', (
    tester,
  ) async {
    await tester.pumpWidget(_app(platform: TargetPlatform.macOS));

    final content = tester.getRect(find.byKey(_edge));
    final view = tester.getRect(find.byType(ListView));
    expect(
      view.right - content.right,
      greaterThanOrEqualTo(scrollbarGutter - 0.1),
    );
    expect(find.byType(Scrollbar), findsOneWidget);
  });

  testWidgets('a form scrollbar does not cover the action on the right', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(
        platform: TargetPlatform.macOS,
        body: NestedForm(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 1200),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => tapped = true,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final button = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
    final view = tester.getRect(find.byType(SingleChildScrollView));
    expect(view.right - button.right, greaterThanOrEqualTo(scrollbarGutter - 0.1));
    expect(find.byType(Scrollbar), findsOneWidget);

    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('a phone list uses the full width', (tester) async {
    await tester.pumpWidget(_app(platform: TargetPlatform.iOS));

    final content = tester.getRect(find.byKey(_edge));
    final view = tester.getRect(find.byType(ListView));
    expect(view.right - content.right, lessThan(1));
    expect(find.byType(Scrollbar), findsNothing);
  });

  testWidgets('a text field does not lose width to the scrollbar gutter', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        platform: TargetPlatform.macOS,
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: TextField(),
        ),
      ),
    );

    final field = tester.getSize(find.byType(TextField));
    final editable = tester.getSize(find.byType(EditableText));
    expect(field.width - editable.width, lessThan(scrollbarGutter + 32));
  });
}

const _edge = Key('content-edge');

Widget _app({required TargetPlatform platform, Widget? body}) {
  return MaterialApp(
    scrollBehavior: const AppScrollBehavior(),
    theme: appTheme().copyWith(platform: platform),
    home: Scaffold(
      body:
          body ??
          ListView(
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(
                  key: i == 0 ? _edge : null,
                  height: 48,
                  child: const ColoredBox(color: AppColors.card),
                ),
            ],
          ),
    ),
  );
}
