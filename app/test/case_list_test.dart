import 'package:app/cases/veteran_case.dart';
import 'package:app/home/home_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/cases/cases_progress.dart';
import 'package:app/screens/shell/cases_screen.dart';

void main() {
  test('home follows the working case id and skips an archived case', () {
    final snapshot = homeSnapshotFrom(
      workingCaseId: 'case-1',
      cases: const [
        VeteranCase(id: 'case-1', displayName: 'Back claim', status: 'draft'),
        VeteranCase(id: 'case-2', displayName: 'Knee claim', status: 'draft'),
      ],
    );
    expect(snapshot.workingCase?.displayName, 'Back claim');
    expect(snapshot.workingCase?.statusLabel, 'Draft');

    final archived = homeSnapshotFrom(
      workingCaseId: 'old',
      cases: const [
        VeteranCase(id: 'old', displayName: 'Old claim', status: 'archived'),
      ],
    );
    expect(archived.workingCase, isNull);
  });

  test('a case name is trimmed and kept to 80 characters', () {
    expect(normalizeCaseName('  Back   claim '), 'Back claim');
    expect(normalizeCaseName('   '), isNull);
    expect(normalizeCaseName('x' * 81), isNull);
  });

  test('archived cases do not count toward the limit of 12', () {
    final cases = [
      for (var index = 0; index < 11; index++)
        VeteranCase(id: '$index', displayName: 'Case $index', status: 'draft'),
      const VeteranCase(id: 'old', displayName: 'Old', status: 'archived'),
    ];
    expect(activeCaseCount(cases), 11);
  });

  testWidgets('an empty case list waits for the open case', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          casesProvider.overrideWith((ref) => Stream.value(const <VeteranCase>[])),
          workingCaseIdProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: CasesScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Opening your case.'), findsOneWidget);
    expect(find.text('Start a case'), findsNothing);
    expect(find.textContaining('12'), findsNothing);
  });
}
