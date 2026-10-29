import 'package:app/app/app_theme.dart';
import 'package:app/app/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BorderSide _leftEdge(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(InfoNote),
      matching: find.byType(Container),
    ),
  );
  final decoration = container.decoration! as BoxDecoration;
  return (decoration.border! as Border).left;
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: appTheme(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('the filing note renders the standard line', (tester) async {
    await _pump(tester, const FilingNote());
    expect(
      find.text('Nothing is automatically filed with the VA at any point.'),
      findsOneWidget,
    );
    expect(_leftEdge(tester).color, AppColors.sand);
  });

  testWidgets('tone sets the left edge color, not the text', (tester) async {
    await _pump(
      tester,
      const InfoNote(text: 'Saved', tone: InfoNoteTone.success),
    );
    final scheme = Theme.of(tester.element(find.text('Saved'))).colorScheme;
    expect(_leftEdge(tester).color, AppColors.money);
    final text = tester.widget<Text>(find.text('Saved'));
    expect(text.style?.color, scheme.onSurfaceVariant);
  });

  testWidgets('a danger note uses the red edge', (tester) async {
    await _pump(
      tester,
      const InfoNote(text: 'Problem', tone: InfoNoteTone.danger),
    );
    expect(_leftEdge(tester).color, AppColors.dangerText);
  });
}
