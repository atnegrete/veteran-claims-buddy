import 'dart:typed_data';

import 'package:app/app/app_theme.dart';
import 'package:app/claim/claim_issue.dart';
import 'package:app/claim/claim_issue_repository.dart';
import 'package:app/claim/form_preparation.dart';
import 'package:app/claim/form_recommendations.dart';
import 'package:app/claim/issue_lane.dart';
import 'package:app/screens/shell/issue_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in that drives the Nexus Letters panel straight to the letters phase
/// so the download affordance is on screen. Only the calls the panel makes are
/// implemented; the rest route through [noSuchMethod].
class _FakeNexusService implements FormPreparationService {
  _FakeNexusService();

  int downloadCalls = 0;

  @override
  Future<NexusInterviewState> nexusInterviewStep({
    required String caseId,
    required String issueId,
    String nexusKind = '',
    String? answer,
    bool restart = false,
  }) async => const NexusInterviewState(done: true, answered: 1, total: 1);

  @override
  Future<NexusLetters> generateNexusLetters({
    required String caseId,
    required String issueId,
  }) async => NexusLetters(
    doctorBytes: Uint8List.fromList(const [1, 2, 3]),
    vetBytes: Uint8List.fromList(const [4, 5, 6]),
  );

  @override
  Future<Uint8List> downloadNexusLetter({
    required String caseId,
    required String issueId,
    required String letter,
  }) async {
    downloadCalls++;
    return Uint8List.fromList(const [7, 8, 9]);
  }

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
  id: 'tinnitus',
  conditionId: 'tinnitus',
  displayName: 'Tinnitus',
  activeCaseId: 'case-1',
  status: 'potential',
);

Widget _host(Widget child) => MaterialApp(
  theme: appTheme(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('a clean-copy download button is offered once the letters exist', (
    tester,
  ) async {
    final service = _FakeNexusService();
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
            issueId: 'tinnitus',
            kind: 'doctorDraft',
            heading: 'Nexus Letters',
            intro: 'Two drafts grounded in your saved facts.',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final download = find.widgetWithText(FilledButton, 'Download PDF');
    expect(download, findsOneWidget);
    final button = tester.widget<FilledButton>(download);
    expect(button.onPressed, isNotNull, reason: 'enabled once bytes exist');
    expect(find.text('Doctor draft'), findsOneWidget);
    expect(find.text('Your statement'), findsOneWidget);
    expect(
      find.text('Edit answers'),
      findsNothing,
      reason: 'changes now go through Ask for a change',
    );
  });
}
