import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/forms/text_input_chain.dart';

void main() {
  testWidgets('Next moves past a dropdown to the next text field', (
    tester,
  ) async {
    final first = TextEditingController();
    final second = TextEditingController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextInputChain(
            child: Column(
              children: [
                ChainTextField(
                  key: const Key('first'),
                  controller: first,
                  decoration: const InputDecoration(labelText: 'First'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: 'a',
                  items: const [DropdownMenuItem(value: 'a', child: Text('A'))],
                  onChanged: (_) {},
                ),
                ChainTextField(
                  key: const Key('second'),
                  controller: second,
                  decoration: const InputDecoration(labelText: 'Second'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final firstField = find.descendant(
      of: find.byKey(const Key('first')),
      matching: find.byType(EditableText),
    );
    final secondField = find.descendant(
      of: find.byKey(const Key('second')),
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(firstField).textInputAction,
      TextInputAction.next,
    );
    expect(
      tester.widget<EditableText>(secondField).textInputAction,
      TextInputAction.done,
    );
    await tester.showKeyboard(firstField);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<EditableText>(firstField).focusNode.hasFocus, isFalse);
    expect(tester.widget<EditableText>(secondField).focusNode.hasFocus, isTrue);
  });

  testWidgets('the last multiline field keeps Return', (tester) async {
    final notes = TextEditingController();
    addTearDown(notes.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextInputChain(
            child: ChainTextField(
              controller: notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).textInputAction,
      TextInputAction.newline,
    );
  });

  testWidgets('the count stays hidden until 90 percent of the max', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChainTextField(
            controller: controller,
            maxLength: 10,
            countVisibleFrom: authCountVisibleFrom,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), '12345678');
    await tester.pump();
    expect(find.text('8/10'), findsNothing);
    await tester.enterText(find.byType(EditableText), '123456789');
    await tester.pump();
    expect(find.text('9/10'), findsOneWidget);
  });
}
