import 'package:app/app/app_theme.dart';
import 'package:app/forms/repeatable_entries.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an empty list shows the form', (tester) async {
    await tester.pumpWidget(_host(entries: const [], addingAnother: false));

    expect(find.text('the form'), findsOneWidget);
    expect(find.text('Add Another'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('saved entries hide the form until Add Another', (tester) async {
    var adding = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return RepeatableEntries(
                entries: const [
                  EntryCard(
                    fields: [
                      EntryField(label: 'Branch', value: 'Army'),
                      EntryField(label: 'Component', value: 'Active'),
                      EntryField(label: 'Start date', value: '2010-01-01'),
                      EntryField(label: 'End date', value: 'Present'),
                    ],
                    onRemove: null,
                  ),
                ],
                addingAnother: adding,
                onAddAnother: () => setState(() => adding = true),
                onCancel: () => setState(() => adding = false),
                form: const Text('the form'),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Branch'), findsOneWidget);
    expect(find.text('Army'), findsOneWidget);
    expect(find.text('End date'), findsOneWidget);
    expect(find.text('Present'), findsOneWidget);
    expect(find.text('Add Another'), findsOneWidget);
    expect(find.text('the form'), findsNothing);

    await tester.tap(find.text('Add Another'));
    await tester.pump();

    expect(find.text('the form'), findsOneWidget);
    expect(find.text('Add Another'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(find.text('the form'), findsNothing);
    expect(find.text('Add Another'), findsOneWidget);
  });

  testWidgets('a card labels each value and skips a blank one', (tester) async {
    await tester.pumpWidget(
      _cardHost(
        width: 640,
        fields: const [
          EntryField(label: 'Branch', value: 'Army'),
          EntryField(label: 'Job or occupation', value: ' '),
        ],
      ),
    );

    expect(find.text('Branch'), findsOneWidget);
    expect(find.text('Army'), findsOneWidget);
    expect(find.text('Job or occupation'), findsNothing);

    final label = tester.getTopLeft(find.text('Branch'));
    final value = tester.getTopLeft(find.text('Army'));
    expect(label.dx, lessThan(value.dx));
    expect((label.dy - value.dy).abs(), lessThan(2));
  });

  testWidgets('a narrow card puts the label above the value', (tester) async {
    await tester.pumpWidget(
      _cardHost(
        width: 320,
        fields: const [EntryField(label: 'Branch', value: 'Army')],
      ),
    );

    final label = tester.getTopLeft(find.text('Branch'));
    final value = tester.getTopLeft(find.text('Army'));
    expect(label.dy, lessThan(value.dy));
  });
}

Widget _cardHost({required double width, required List<EntryField> fields}) {
  return MaterialApp(
    theme: appTheme(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: EntryCard(fields: fields, onRemove: null),
        ),
      ),
    ),
  );
}

Widget _host({required List<Widget> entries, required bool addingAnother}) {
  return MaterialApp(
    theme: appTheme(),
    home: Scaffold(
      body: RepeatableEntries(
        entries: entries,
        addingAnother: addingAnother,
        onAddAnother: () {},
        form: const Text('the form'),
      ),
    ),
  );
}
