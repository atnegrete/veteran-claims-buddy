import 'dart:async';
import 'dart:typed_data';

import 'package:app/app/app_theme.dart';
import 'package:app/claim/claim_issue.dart';
import 'package:app/claim/claim_issue_repository.dart';
import 'package:app/claim/form_preparation.dart';
import 'package:app/claim/form_recommendations.dart';
import 'package:app/claim/issue_lane.dart';
import 'package:app/claim/issue_record_repository.dart';
import 'package:app/screens/shell/issue_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for the Cloud Functions client. Only the Nexus Letters calls are
/// implemented; everything else routes through [noSuchMethod].
class _FakeNexusService implements FormPreparationService {
  _FakeNexusService({this.steps = const []});

  final List<NexusInterviewState> steps;
  int calls = 0;

  @override
  Future<NexusInterviewState> nexusInterviewStep({
    required String caseId,
    required String issueId,
    String nexusKind = '',
    String? answer,
    bool restart = false,
  }) async {
    final index = calls < steps.length ? calls : steps.length - 1;
    calls++;
    return steps[index];
  }

  // Generation is left pending so the panel rests in the "generating" phase;
  // no widget test renders a real PDF.
  @override
  Future<NexusLetters> generateNexusLetters({
    required String caseId,
    required String issueId,
  }) => Completer<NexusLetters>().future;

  @override
  Future<Uint8List> reviseNexusLetter({
    required String caseId,
    required String issueId,
    required String letter,
    required String instruction,
  }) async => Uint8List(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _issue = ClaimIssue(
  id: 'headache',
  conditionId: 'headache',
  displayName: 'Headache',
  activeCaseId: 'case-1',
  status: 'potential',
);

Widget _host(Widget child) => MaterialApp(
  theme: appTheme(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('the nexus letters step runs the interview before any preview', (
    tester,
  ) async {
    final service = _FakeNexusService(
      steps: const [
        NexusInterviewState(
          done: false,
          question: NexusQuestion(
            slotId: 'reportedDiagnosis',
            prompt: 'Has a doctor diagnosed this condition?',
          ),
          answered: 0,
          total: 4,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          claimIssuesProvider.overrideWith(
            (ref) => Stream.value(const [_issue]),
          ),
          claimLanesProvider.overrideWith(
            (ref, caseId) => const <IssueLaneResult>[],
          ),
          formPreparationServiceProvider.overrideWithValue(service),
        ],
        child: _host(
          const IssueStatementScreen(
            caseId: 'case-1',
            issueId: 'headache',
            kind: 'doctorDraft',
            heading: 'Nexus Letters',
            intro: 'Two drafts grounded in your saved facts.',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Nexus Letters'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Has a doctor diagnosed this condition?'), findsOneWidget);
    expect(find.text('0 of 4 completed'), findsOneWidget);
    // The old single-draft affordances are gone.
    expect(find.text('Draft with AI'), findsNothing);
    expect(find.text('Evidence and law brief'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finishing the interview auto-generates the letters', (
    tester,
  ) async {
    final service = _FakeNexusService(
      steps: const [
        NexusInterviewState(
          done: false,
          question: NexusQuestion(
            slotId: 'reportedDiagnosis',
            prompt: 'Has a doctor diagnosed this condition?',
          ),
          answered: 0,
          total: 1,
        ),
        NexusInterviewState(done: true, answered: 1, total: 1),
      ],
      // onGenerate stays pending so the panel rests in the generating phase.
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          claimIssuesProvider.overrideWith(
            (ref) => Stream.value(const [_issue]),
          ),
          claimLanesProvider.overrideWith(
            (ref, caseId) => const <IssueLaneResult>[],
          ),
          formPreparationServiceProvider.overrideWithValue(service),
        ],
        child: _host(
          const IssueStatementScreen(
            caseId: 'case-1',
            issueId: 'headache',
            kind: 'doctorDraft',
            heading: 'Nexus Letters',
            intro: 'Two drafts grounded in your saved facts.',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField), 'Yes, tinnitus.');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Preparing your letters…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('how this affects you asks frequency, duration, and impact', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          claimIssuesProvider.overrideWith(
            (ref) => Stream.value(const [_issue]),
          ),
          issueStatementProvider.overrideWith((ref, key) => Stream.value(null)),
        ],
        child: _host(
          const IssueStatementScreen(
            caseId: 'case-1',
            issueId: 'headache',
            kind: 'lay',
            heading: 'How this affects you',
            intro: 'How often it happens, how long it lasts, and what it keeps you from doing. This is not sent to the VA from here.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('How this affects you'), findsOneWidget);
    expect(find.text('How often does this happen?'), findsOneWidget);
    expect(find.text('How long does it last?'), findsOneWidget);
    expect(find.text('What does it keep you from doing?'), findsOneWidget);
    expect(find.text('In your own words'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
