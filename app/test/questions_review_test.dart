import 'package:app/app/app_theme.dart';
import 'package:app/claim/claim_issue.dart';
import 'package:app/claim/claim_issue_repository.dart';
import 'package:app/claim/questionnaire_catalog.dart';
import 'package:app/claim/questionnaire_repository.dart';
import 'package:app/screens/shell/questions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const questions = <CatalogQuestion>[
    CatalogQuestion(
      id: 'head',
      prompt: 'Head?',
      answerType: 'singleChoice',
      section: 'gates',
      order: 0,
      options: [
        CatalogChoice(value: 'yes', label: 'Yes'),
        CatalogChoice(value: 'no', label: 'No'),
      ],
    ),
    CatalogQuestion(
      id: 'head.dx',
      prompt: 'Which problem?',
      answerType: 'multiChoice',
      section: 'head',
      order: 1,
      showWhen: [CatalogRule(questionId: 'head', equals: 'yes')],
      createsEachOption: true,
      options: [CatalogChoice(value: 'migraine', label: 'Migraine')],
    ),
  ];

  testWidgets('a finished list reopens one topic and continues to Issues', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/cases/case-1/questions',
      routes: [
        GoRoute(
          path: '/cases/:caseId/questions',
          builder: (context, state) =>
              const Scaffold(body: CatalogPanel(caseId: 'case-1')),
        ),
        GoRoute(
          path: '/cases/:caseId/conditions',
          builder: (context, state) =>
              const Scaffold(body: Text('Conditions open')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questionnaireSessionProvider.overrideWith(
            (ref) => Stream.value(
              const QuestionnaireSession(
                questions: questions,
                answers: {
                  'head': ['yes'],
                  'head.dx': ['migraine'],
                },
              ),
            ),
          ),
          saveQuestionnaireProvider.overrideWithValue(
            ({
              required String? caseId,
              required List<CatalogQuestion> questions,
              required Map<String, List<String>> answers,
            }) async {},
          ),
          claimIssuesProvider.overrideWith(
            (ref) => Stream.value(const <ClaimIssue>[]),
          ),
        ],
        child: MaterialApp.router(theme: appTheme(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Migraine'), findsOneWidget);
    expect(find.text('Questions'), findsOneWidget);
    expect(
      find.text(
        'Based on your answers, these conditions can likely be added to this claim.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add all to this claim'), findsOneWidget);
    expect(find.text('Add to this claim'), findsOneWidget);
    expect(find.text('On this claim'), findsNothing);
    expect(find.text('Back to the questions'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Back'), findsNothing);

    await tester.tap(find.text('Questions'));
    await tester.pump();

    expect(find.text('Head and nerves'), findsOneWidget);
    expect(find.text('1. Which problem?'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Migraine'), findsOneWidget);
    expect(find.text('Back'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Conditions open'), findsOneWidget);
  });

  testWidgets('add all places only the conditions not already on the claim', (
    tester,
  ) async {
    final added = <String>[];
    final router = GoRouter(
      initialLocation: '/cases/case-1/questions',
      routes: [
        GoRoute(
          path: '/cases/:caseId/questions',
          builder: (context, state) =>
              const Scaffold(body: CatalogPanel(caseId: 'case-1')),
        ),
      ],
    );
    const both = <CatalogQuestion>[
      CatalogQuestion(
        id: 'head',
        prompt: 'Head?',
        answerType: 'singleChoice',
        section: 'gates',
        order: 0,
        options: [
          CatalogChoice(value: 'yes', label: 'Yes'),
          CatalogChoice(value: 'no', label: 'No'),
        ],
      ),
      CatalogQuestion(
        id: 'head.dx',
        prompt: 'Which problem?',
        answerType: 'multiChoice',
        section: 'head',
        order: 1,
        showWhen: [CatalogRule(questionId: 'head', equals: 'yes')],
        createsEachOption: true,
        options: [
          CatalogChoice(value: 'migraine', label: 'Migraine'),
          CatalogChoice(value: 'tinnitus', label: 'Tinnitus'),
        ],
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questionnaireSessionProvider.overrideWith(
            (ref) => Stream.value(
              const QuestionnaireSession(
                questions: both,
                answers: {
                  'head': ['yes'],
                  'head.dx': ['migraine', 'tinnitus'],
                },
              ),
            ),
          ),
          claimIssuesProvider.overrideWith(
            (ref) => Stream.value(const [
              ClaimIssue(
                id: 'head.dx__migraine',
                conditionId: 'head.dx__migraine',
                displayName: 'Migraine',
                activeCaseId: 'case-1',
                status: 'potential',
              ),
            ]),
          ),
          addClaimIssueProvider.overrideWithValue(({
            required String caseId,
            required String conditionId,
            required String displayName,
          }) async {
            added.add('$caseId:$conditionId:$displayName');
          }),
        ],
        child: MaterialApp.router(theme: appTheme(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Added to claim'), findsOneWidget);
    expect(find.text('Add to this claim'), findsOneWidget);
    await tester.tap(find.text('Add all to this claim'));
    await tester.pump();
    await tester.pump();

    expect(added, ['case-1:head.dx__tinnitus:Tinnitus']);
    expect(find.text('Tinnitus'), findsOneWidget);
    expect(find.text('On this claim'), findsNothing);
  });

  testWidgets('a condition on the claim can be removed', (tester) async {
    final removed = <String>[];
    final router = GoRouter(
      initialLocation: '/cases/case-1/questions',
      routes: [
        GoRoute(
          path: '/cases/:caseId/questions',
          builder: (context, state) =>
              const Scaffold(body: CatalogPanel(caseId: 'case-1')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questionnaireSessionProvider.overrideWith(
            (ref) => Stream.value(
              const QuestionnaireSession(
                questions: questions,
                answers: {
                  'head': ['yes'],
                  'head.dx': ['migraine'],
                },
              ),
            ),
          ),
          claimIssuesProvider.overrideWith(
            (ref) => Stream.value(const [
              ClaimIssue(
                id: 'head.dx__migraine',
                conditionId: 'head.dx__migraine',
                displayName: 'Migraine',
                activeCaseId: 'case-1',
                status: 'potential',
              ),
            ]),
          ),
          removeClaimIssueProvider.overrideWithValue(({
            required String caseId,
            required String conditionId,
          }) async {
            removed.add('$caseId:$conditionId');
          }),
        ],
        child: MaterialApp.router(theme: appTheme(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Added to claim'), findsOneWidget);
    expect(find.text('Remove from claim'), findsOneWidget);
    expect(find.text('Add all to this claim'), findsNothing);
    expect(find.text('Add to this claim'), findsNothing);
    expect(find.text('On this claim'), findsNothing);

    await tester.tap(find.text('Remove from claim'));
    await tester.pump();
    await tester.pump();

    expect(removed, ['case-1:head.dx__migraine']);
  });
}
