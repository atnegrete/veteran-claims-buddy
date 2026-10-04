import 'package:app/app/app_theme.dart';
import 'package:app/cases/cases_progress.dart';
import 'package:app/claim/claim_issue.dart';
import 'package:app/claim/claim_issue_repository.dart';
import 'package:app/claim/symptom_entry.dart';
import 'package:app/claim/symptom_repository.dart';
import 'package:app/home/home_snapshot.dart';
import 'package:app/screens/shell/symptoms_tracker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('new entries stay on plans until Premium', (tester) async {
    await _pump(tester, premium: false, entries: const []);

    expect(find.text('No entries yet.'), findsOneWidget);
    expect(find.text('New entries need Premium.'), findsOneWidget);
    expect(find.text('Check in'), findsNothing);
    await tester.tap(find.text('Compare plans'));
    await tester.pumpAndSettle();
    expect(find.text('Plans'), findsOneWidget);
  });

  testWidgets('Premium can open a check-in', (tester) async {
    await _pump(tester, premium: true, entries: const []);

    expect(find.text('Check in'), findsOneWidget);
    expect(find.text('Add an event'), findsOneWidget);
    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();
    expect(find.text('Severity 0'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Time'), findsNothing);
  });

  testWidgets('a saved entry stays readable without Premium', (tester) async {
    await _pump(
      tester,
      premium: false,
      entries: const [
        SymptomEntry(
          id: 'entry-1',
          entryType: 'checkIn',
          occurredDate: '2026-10-04',
          occurredTime: '',
          severity: 6,
          duration: 'allDay',
          affectedWork: true,
          limitedActivity: false,
          rested: true,
          tookTreatment: false,
          conditionId: '',
          conditionName: '',
        ),
      ],
    );

    expect(find.text('Check-in · 2026-10-04'), findsOneWidget);
    expect(find.text('New entries need Premium.'), findsOneWidget);
    expect(find.text('Check in'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required bool premium,
  required List<SymptomEntry> entries,
}) async {
  final router = GoRouter(
    initialLocation: '/symptoms',
    routes: [
      GoRoute(
        path: '/symptoms',
        builder: (context, state) => const SymptomsTrackerScreen(),
        routes: [
          GoRoute(
            path: 'check-in',
            builder: (context, state) => const SymptomFormScreen(event: false),
          ),
        ],
      ),
      GoRoute(
        path: '/plans',
        builder: (context, state) => const Scaffold(body: Text('Plans')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeSnapshotProvider.overrideWithValue(
          HomeSnapshot(premiumActive: premium),
        ),
        symptomEntriesProvider.overrideWith((ref) => Stream.value(entries)),
        claimIssuesProvider.overrideWith(
          (ref) => Stream.value(const <ClaimIssue>[]),
        ),
        saveSymptomEntryProvider.overrideWithValue((draft) async {}),
      ],
      child: MaterialApp.router(theme: appTheme(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}
