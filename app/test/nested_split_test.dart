import 'package:app/forms/nested_split.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  testWidgets('the issue shell keeps the issue id', (tester) async {
    final router = GoRouter(
      initialLocation: '/cases/c1/issues/i1/statements/doctor-draft',
      routes: [
        GoRoute(
          path: '/cases/:caseId/issues',
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
