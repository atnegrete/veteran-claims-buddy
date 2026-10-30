import 'package:app/forms/form_actions.dart';
import 'package:app/forms/nested_split.dart';
import 'package:app/screens/shell/shell_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a phone page drops the full-screen card', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShellPage(title: 'Condition name', child: Text('The work')),
        ),
      ),
    );

    expect(find.text('Condition name'), findsOneWidget);
    expect(find.text('The work'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('a wide page keeps the card', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShellPage(title: 'Condition name', child: Text('The work')),
        ),
      ),
    );

    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('a phone form has no card and the intro still reads', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NestedForm(
            intro: 'Two drafts grounded in your saved facts.',
            footer: FormActions(onPrimary: _noop, primaryLabel: 'Continue'),
            child: const Text('The question'),
          ),
        ),
      ),
    );

    expect(find.byType(Card), findsNothing);
    expect(
      find.text('Two drafts grounded in your saved facts.'),
      findsOneWidget,
    );
    expect(find.text('The question'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('a phone step page leaves most of the height for the work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShellPage(
            title: 'Irritable bowel or a similar problem',
            expandChild: true,
            child: NestedSplit(
              open: true,
              steps: const [
                NestedStep(
                  title: 'Nexus Letters',
                  shortTitle: 'Letters',
                  selected: true,
                ),
                NestedStep(
                  title: 'How this connects to service',
                  shortTitle: 'Connection',
                  selected: false,
                  done: true,
                ),
                NestedStep(
                  title: 'How this affects you',
                  shortTitle: 'Effects',
                  selected: false,
                  done: true,
                ),
              ],
              master: const Text('The list'),
              detail: NestedForm(
                title: 'Nexus Letters',
                intro: 'Two drafts grounded in your saved facts: an unsigned letter for your own doctor, and a statement you can sign yourself.',
                footer: FormActions(onBack: _noop, onPrimary: _noop),
                child: const Text('The question'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.renderObject<RenderBox>(
      find.descendant(
        of: find.byType(NestedForm),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    final page = tester.renderObject<RenderBox>(find.byType(ShellPage));
    expect(scrollable.size.height, greaterThan(page.size.height * 0.45));
    expect(find.text('Nexus Letters'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.byTooltip('Connection'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('five phone steps settle', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NestedStepBar(
            steps: [
              NestedStep(
                title: 'Questions about this',
                shortTitle: 'Questions',
                selected: false,
                done: true,
              ),
              NestedStep(
                title: 'New or already decided',
                shortTitle: 'Decision',
                selected: false,
                done: true,
              ),
              NestedStep(
                title: 'How this connects to service',
                shortTitle: 'Connection',
                selected: false,
                done: true,
              ),
              NestedStep(
                title: 'How this affects you',
                shortTitle: 'Effects',
                selected: false,
                done: true,
              ),
              NestedStep(
                title: 'Nexus Letters',
                shortTitle: 'Letters',
                selected: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(find.text('Nexus Letters'), findsOneWidget);
    expect(find.text('Step 5 of 5'), findsOneWidget);
  });
}

void _noop() {}
