import 'package:app/forms/nested_split.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void _noop() {}

void main() {
  testWidgets('a wide pane shows the list and the form', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NestedSplit(
            open: true,
            master: Text('The list'),
            detail: Text('The form'),
          ),
        ),
      ),
    );

    expect(find.text('The list').hitTestable(), findsOneWidget);
    expect(find.text('The form').hitTestable(), findsOneWidget);
  });

  testWidgets('a narrow pane hides the list while the form is open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NestedSplit(
            open: true,
            master: Text('The list'),
            detail: Text('The form'),
          ),
        ),
      ),
    );

    expect(find.text('The form').hitTestable(), findsOneWidget);
    expect(find.text('The list').hitTestable(), findsNothing);
  });

  testWidgets('a narrow condition shows the step rail and hides the cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NestedSplit(
            open: true,
            steps: const [
              NestedStep(
                title: 'Questions about this',
                shortTitle: 'Questions',
                selected: true,
              ),
              NestedStep(
                title: 'Your statement',
                shortTitle: 'Statement',
                selected: false,
              ),
            ],
            master: const Text('The list'),
            detail: const Text('The form'),
          ),
        ),
      ),
    );

    expect(find.text('The form').hitTestable(), findsOneWidget);
    // The part name and the count share one row. Short names sit on the circles.
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('Questions about this').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Questions'), findsOneWidget);
    expect(find.byTooltip('Statement'), findsOneWidget);
    expect(find.text('Questions'), findsNothing);
    expect(find.text('The list').hitTestable(), findsNothing);
  });

  testWidgets('a wide condition keeps the cards and skips the step rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NestedSplit(
            open: true,
            steps: [
              NestedStep(
                title: 'Questions about this',
                shortTitle: 'Questions',
                selected: true,
              ),
            ],
            master: Text('The list'),
            detail: Text('The form'),
          ),
        ),
      ),
    );

    expect(find.text('The list').hitTestable(), findsOneWidget);
    expect(find.text('The form').hitTestable(), findsOneWidget);
    expect(find.text('Step 1 of 1'), findsNothing);
  });

  testWidgets('a finished part shows a check', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
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
                onPressed: _noop,
              ),
              NestedStep(
                title: 'New or already decided',
                shortTitle: 'Decision',
                selected: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('a locked part does not open', (tester) async {
    var opened = false;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NestedStepBar(
            steps: [
              const NestedStep(
                title: 'Questions about this',
                shortTitle: 'Questions',
                selected: true,
              ),
              NestedStep(
                title: 'How this connects to service',
                shortTitle: 'Connection',
                selected: false,
                enabled: false,
                onPressed: () => opened = true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Connection'));
    await tester.pump();
    expect(opened, isFalse);
  });

  testWidgets('a step flow names the part once', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NestedSplit(
            open: true,
            steps: [
              NestedStep(
                title: 'Questions about this',
                shortTitle: 'Questions',
                selected: true,
              ),
            ],
            master: Text('The list'),
            detail: NestedForm(
              title: 'Questions about this',
              child: Text('The form'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Questions about this'), findsOneWidget);
    expect(find.text('The form'), findsOneWidget);
  });

  testWidgets('arrows scroll parts that sit past the edge', (tester) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: NestedStepBar(
                steps: [
                  NestedStep(
                    title: 'Questions about this',
                    shortTitle: 'Questions',
                    selected: true,
                  ),
                  NestedStep(
                    title: 'New or already decided',
                    shortTitle: 'Decision',
                    selected: false,
                  ),
                  NestedStep(
                    title: 'How this connects to service',
                    shortTitle: 'Connection',
                    selected: false,
                  ),
                  NestedStep(
                    title: 'Your statement',
                    shortTitle: 'Statement',
                    selected: false,
                  ),
                  NestedStep(
                    title: 'Draft for your doctor',
                    shortTitle: 'Doctor letter',
                    selected: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Doctor letter').hitTestable(), findsNothing);
    expect(find.byTooltip('Later steps'), findsOneWidget);

    for (var i = 0; i < 12; i++) {
      if (find.text('Doctor letter').hitTestable().evaluate().isNotEmpty) {
        break;
      }
      await tester.tap(find.byTooltip('Later steps'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Doctor letter').hitTestable(), findsOneWidget);
  });

  testWidgets('the issue shell keeps the issue id', (tester) async {
    final router = GoRouter(
      initialLocation: '/cases/c1/conditions/i1/statements/doctor-draft',
      routes: [
        GoRoute(
          path: '/cases/:caseId/conditions',
          builder: (context, state) => const Text('Issues'),
          routes: [
            ShellRoute(
              builder: (context, state, child) {
                return Column(
                  children: [
                    Text('shell ${state.pathParameters['issueId']}'),
                    Expanded(child: child),
                  ],
                );
              },
              routes: [
                GoRoute(
                  path: ':issueId',
                  builder: (context, state) => const SizedBox.shrink(),
                  routes: [
                    GoRoute(
                      path: 'statements/doctor-draft',
                      builder: (context, state) => const Text('Draft'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('shell i1'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
  });
}
