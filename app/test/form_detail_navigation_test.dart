import 'package:app/app/app_theme.dart';
import 'package:app/cases/cases_progress.dart';
import 'package:app/claim/form_preparation.dart';
import 'package:app/claim/package_form_repository.dart';
import 'package:app/forms/nested_split.dart';
import 'package:app/forms/package_form.dart';
import 'package:app/screens/shell/form_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const caseId = 'case-1';

  PackageForm entry(String formNumber) {
    return PackageForm(
      id: 'entry-1',
      caseId: caseId,
      formNumber: formNumber,
      status: PackageFormStatus.ready,
      multiplicityKey: '',
      displayLabel: 'Saved copy',
      answers: const {},
      sectionDrafts: const {},
      statementStatus: StatementStatus.none,
    );
  }

  Future<void> pumpHost(
    WidgetTester tester, {
    List<PackageForm> forms = const [],
    String formNumber = '21-4138',
    bool listHidden = false,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workingCaseIdProvider.overrideWithValue(caseId),
          packageFormsProvider.overrideWith((ref, id) => Stream.value(forms)),
          vaFormMappingProvider.overrideWith((ref, number) async => null),
        ],
        child: MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: NestedListHidden(
              hidden: listHidden,
              child: _Host(formNumber: formNumber),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> switchForm(WidgetTester tester, String formNumber) async {
    tester.state<_HostState>(find.byType(_Host)).switchTo(formNumber);
    await tester.pump();
  }

  testWidgets('a form card opens the overview, not the copy in progress', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('Add to Package'));
    await tester.pump();
    expect(
      find.text('How the condition started or worsened, in your words'),
      findsOneWidget,
    );

    await switchForm(tester, '21-10210');
    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'A statement from someone who witnessed your condition, an event, or how it affects you.',
      ),
      findsOneWidget,
    );
    expect(find.text('Witness full name'), findsNothing);
    expect(find.text('ADD TO PACKAGE'), findsNothing);
  });

  testWidgets('an open copy closes when another form is selected', (
    tester,
  ) async {
    await pumpHost(tester, forms: [entry('21-4138')]);
    await tester.tap(find.text('Saved copy'));
    await tester.pump();
    expect(find.text('PREVIEW'), findsOneWidget);

    await switchForm(tester, '21-10210');
    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'A statement from someone who witnessed your condition, an event, or how it affects you.',
      ),
      findsOneWidget,
    );
    expect(find.text('PREVIEW'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'the form name and close button show only when the list is hidden',
    (tester) async {
      await pumpHost(tester);
      expect(find.text('All forms'), findsNothing);
      expect(find.byTooltip('Close'), findsNothing);
      expect(find.text('Personal statement'), findsNothing);

      await pumpHost(tester, listHidden: true);
      expect(find.text('All forms'), findsNothing);
      expect(find.text('Personal statement'), findsOneWidget);
      expect(find.text('WHAT THIS IS'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsWidgets);
    },
  );
}

class _Host extends StatefulWidget {
  const _Host({required this.formNumber});

  final String formNumber;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String _formNumber = widget.formNumber;

  void switchTo(String formNumber) => setState(() => _formNumber = formNumber);

  @override
  Widget build(BuildContext context) {
    return FormDetailScreen(caseId: 'case-1', formNumber: _formNumber);
  }
}
