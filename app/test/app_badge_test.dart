import 'package:app/app/app_badge.dart';
import 'package:app/app/app_theme.dart';
import 'package:app/claim/claim_sections.dart';
import 'package:app/screens/shell/progress_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a status badge and a count carry color on the fill', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: const Scaffold(
          body: Column(
            children: [
              ProgressMark(
                status: ClaimSectionStatus.inProgress,
                label: '3 added',
              ),
              ProgressMark(status: ClaimSectionStatus.done),
              Row(
                children: [
                  Expanded(child: Text('Questions')),
                  AppBadge.success(icon: Icons.check),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('3 added'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    expect(find.byIcon(Icons.shield_outlined), findsNothing);
    final scheme = Theme.of(tester.element(find.text('3 added'))).colorScheme;
    final count = tester.widget<Text>(find.text('3 added'));
    expect(count.style?.color, scheme.onSecondary);
    for (final icon in tester.widgetList<Icon>(find.byIcon(Icons.check))) {
      expect(icon.color, Colors.white);
    }
    final done = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(ProgressMark).at(1),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((done.decoration as BoxDecoration).color, AppColors.success);
    expect(tester.takeException(), isNull);
  });
}
