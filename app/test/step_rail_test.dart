import 'package:app/app/app_theme.dart';
import 'package:app/forms/step_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(List<StepRailItem> steps, {Size size = const Size(600, 400)}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: size.width,
          child: StepRail(steps: steps),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows a number for each step and a check for a done step', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const [
        StepRailItem(label: 'First', state: StepRailState.done),
        StepRailItem(label: 'Second', state: StepRailState.current),
        StepRailItem(label: 'Third', state: StepRailState.open),
      ]),
    );

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Third'), findsOneWidget);
    // The done step shows a white check on a green circle.
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(Icons.check)).color, Colors.white);
    final circle = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.check),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((circle.decoration as BoxDecoration).color, AppColors.success);
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('an open step runs its tap and a locked step does not', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      _host([
        const StepRailItem(label: 'Done', state: StepRailState.done),
        StepRailItem(
          label: 'Open',
          state: StepRailState.open,
          onTap: () => opened++,
        ),
        const StepRailItem(label: 'Locked', state: StepRailState.locked),
      ]),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(opened, 1);

    // A locked step has no tap, so tapping it changes nothing.
    await tester.tap(find.text('Locked'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('chevrons appear only when the steps overflow', (tester) async {
    await tester.pumpWidget(
      _host(const [
        StepRailItem(label: 'One', state: StepRailState.current),
        StepRailItem(label: 'Two', state: StepRailState.open),
      ], size: const Size(800, 400)),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsNothing);

    tester.view.physicalSize = const Size(200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(const [
        StepRailItem(label: 'One', state: StepRailState.current),
        StepRailItem(label: 'Two', state: StepRailState.open),
        StepRailItem(label: 'Three', state: StepRailState.open),
        StepRailItem(label: 'Four', state: StepRailState.open),
        StepRailItem(label: 'Five', state: StepRailState.open),
        StepRailItem(label: 'Six', state: StepRailState.open),
      ], size: const Size(180, 400)),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('a compact rail keeps the name on the circle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StepRail(
            compact: true,
            steps: const [
              StepRailItem(label: 'Decision', state: StepRailState.done),
              StepRailItem(label: 'Connection', state: StepRailState.current),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Decision'), findsNothing);
    expect(find.text('Connection'), findsNothing);
    expect(find.byTooltip('Decision'), findsOneWidget);
    expect(find.byTooltip('Connection'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('a compact rail stretches the lines across the width', (
    tester,
  ) async {
    Future<double> lineGap(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: const StepRail(
                  compact: true,
                  steps: [
                    StepRailItem(label: 'One', state: StepRailState.done),
                    StepRailItem(label: 'Two', state: StepRailState.current),
                    StepRailItem(label: 'Three', state: StepRailState.open),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final rail = tester.getRect(find.byType(StepRail));
      final first = tester.getRect(find.byTooltip('One'));
      final last = tester.getRect(find.byTooltip('Three'));
      expect(first.left, closeTo(rail.left, 1));
      expect(last.right, closeTo(rail.right, 1));
      return tester.getRect(find.byTooltip('Two')).left - first.right;
    }

    final narrow = await lineGap(220);
    final wide = await lineGap(420);
    expect(wide, greaterThan(narrow + 40));
  });

  testWidgets('a compact rail scrolls when the circles do not fit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: StepRail(
                compact: true,
                steps: [
                  for (var i = 0; i < 12; i++)
                    StepRailItem(
                      label: 'Step $i',
                      state: i == 0
                          ? StepRailState.current
                          : StepRailState.open,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}
