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
                  AppBadge.quiet(icon: Icons.check),
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
    expect(tester.takeException(), isNull);
  });
}
