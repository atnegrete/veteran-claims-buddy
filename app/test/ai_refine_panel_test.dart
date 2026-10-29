import 'package:app/ai/ai_refine_panel.dart';
import 'package:app/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: appTheme(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets(
    'AiRefinePanel shows the artifact, submits, clears, and lists history',
    (tester) async {
      final received = <String>[];
      await tester.pumpWidget(
        _host(
          AiRefinePanel(
            history: const ['make it shorter'],
            onSubmit: (instruction) async {
              received.add(instruction);
              return true;
            },
            child: const Text('ARTIFACT'),
          ),
        ),
      );

      expect(find.text('ARTIFACT'), findsOneWidget);
      expect(find.text('- make it shorter'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'add my 2010 onset');
      await tester.tap(find.widgetWithText(FilledButton, 'Update'));
      await tester.pump();
      await tester.pump();

      expect(received, ['add my 2010 onset']);
      // The field clears after a successful change.
      expect(find.text('add my 2010 onset'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('AiRefinePanel surfaces an AiRefineFailure message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AiRefinePanel(
          onSubmit: (instruction) async =>
              throw const AiRefineFailure('That is not allowed.'),
          child: const Text('ARTIFACT'),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'do something');
    await tester.tap(find.widgetWithText(FilledButton, 'Update'));
    await tester.pump();
    await tester.pump();

    expect(find.text('That is not allowed.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
