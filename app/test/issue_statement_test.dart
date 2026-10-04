import 'package:app/app/app_theme.dart';
import 'package:app/claim/claim_issue.dart';
import 'package:app/claim/claim_issue_repository.dart';
import 'package:app/claim/issue_record_repository.dart';
import 'package:app/screens/shell/issue_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the doctor draft shows Back and Save', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          claimIssuesProvider.overrideWith(
            (ref) => Stream.value(const [
              ClaimIssue(
                id: 'headache',
                conditionId: 'headache',
                displayName: 'Headache',
                activeCaseId: 'case-1',
                status: 'potential',
              ),
            ]),
          ),
          issueStatementProvider.overrideWith((ref, key) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: appTheme(),
          home: const Scaffold(
            body: IssueStatementScreen(
              caseId: 'case-1',
              issueId: 'headache',
              kind: 'doctorDraft',
              heading: 'Draft for your doctor',
              intro: 'A draft you can take to your doctor. This is not a finished medical opinion.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Draft for your doctor'), findsOneWidget);
    expect(
      find.text('Nothing is filed with the VA at this step.'),
      findsOneWidget,
    );
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
