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
}
