import 'package:app/ai/ai_chat_input.dart';
import 'package:app/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: appTheme(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('send is disabled until there is text, then reports trimmed text', (
    tester,
  ) async {
    final controller = TextEditingController();
    final sent = <String>[];
    await tester.pumpWidget(
      _host(
        AiChatInput(
          controller: controller,
          maxLength: 500,
          onSend: sent.add,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(sent, isEmpty, reason: 'an empty field cannot send');

    await tester.enterText(find.byType(TextField), '  hello  ');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(sent, ['hello']);

    controller.dispose();
  });

  testWidgets('busy blocks sending and shows a spinner', (tester) async {
    final controller = TextEditingController(text: 'ready');
    final sent = <String>[];
    await tester.pumpWidget(
      _host(
        AiChatInput(
          controller: controller,
          maxLength: 500,
          busy: true,
          onSend: sent.add,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(sent, isEmpty);

    controller.dispose();
  });

  testWidgets('allowEmptySend keeps send active with an empty field', (
    tester,
  ) async {
    final controller = TextEditingController();
    final sent = <String>[];
    await tester.pumpWidget(
      _host(
        AiChatInput(
          controller: controller,
          maxLength: 500,
          allowEmptySend: true,
          onSend: sent.add,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(sent, ['']);

    controller.dispose();
  });

  testWidgets('the counter stays hidden until the text nears the limit', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _host(
        AiChatInput(
          controller: controller,
          maxLength: 10,
          onSend: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '12345678'); // 80%
    await tester.pump();
    expect(find.textContaining('/10'), findsNothing);

    await tester.enterText(find.byType(TextField), '123456789'); // 90%
    await tester.pump();
    expect(find.text('9/10'), findsOneWidget);

    controller.dispose();
  });
}
