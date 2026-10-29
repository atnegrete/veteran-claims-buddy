import 'package:app/forms/va_file_number_note.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a tap shows the tooltip', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VaFileNumberNote())),
    );

    expect(find.textContaining('track the claims file'), findsNothing);
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pump();
    expect(find.textContaining('track the claims file'), findsOneWidget);
    expect(find.byTooltip(VaFileNumberNote.message), findsOneWidget);
  });

  testWidgets('hover shows the tooltip and leaving closes it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VaFileNumberNote())),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(500, 500));
    await gesture.moveTo(tester.getCenter(find.byIcon(Icons.info_outline)));
    await tester.pump();
    expect(find.textContaining('track the claims file'), findsOneWidget);

    await gesture.moveTo(const Offset(700, 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('track the claims file'), findsNothing);
  });
}
