import 'package:app/app/app_theme.dart';
import 'package:app/forms/step_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('back opens the previous step and a later step stays closed', (
    tester,
  ) async {
    var selected = -1;
    var nextCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: StepForm(
            labels: const ['Welcome', 'Service', 'Deployments'],
            currentIndex: 1,
            farthestIndex: 1,
            onStepSelected: (index) => selected = index,
            onNext: () => nextCount++,
            child: const Text('Service form'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(selected, 0);

    selected = -1;
    await tester.ensureVisible(find.text('Deployments'));
    await tester.tap(find.text('Deployments'));
    await tester.pump();
    expect(selected, -1);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(nextCount, 1);

    final back = tester.getRect(find.widgetWithText(OutlinedButton, 'Back'));
    final next = tester.getRect(find.widgetWithText(FilledButton, 'Continue'));
    expect(next.left - back.right, greaterThanOrEqualTo(24));
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('a step already reached can be opened again', (tester) async {
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: StepForm(
            labels: const ['Welcome', 'Service', 'Deployments'],
            currentIndex: 1,
            farthestIndex: 2,
            onStepSelected: (index) => selected = index,
            onNext: () {},
            child: const Text('Service form'),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Deployments'));
    await tester.tap(find.text('Deployments'));
    await tester.pump();
    expect(selected, 2);
  });
}
