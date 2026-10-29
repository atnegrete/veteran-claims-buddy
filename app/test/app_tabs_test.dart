import 'package:app/app/app_tabs.dart';
import 'package:app/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: appTheme(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('shows every tab label', (tester) async {
    await tester.pumpWidget(
      _host(
        AppTabs(
          tabs: const [AppTab(label: 'Doctor draft'), AppTab(label: 'Your statement')],
          selected: 0,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Doctor draft'), findsOneWidget);
    expect(find.text('Your statement'), findsOneWidget);
  });

  testWidgets('tapping an inactive tab reports its index', (tester) async {
    int? picked;
    await tester.pumpWidget(
      _host(
        AppTabs(
          tabs: const [AppTab(label: 'Doctor draft'), AppTab(label: 'Your statement')],
          selected: 0,
          onChanged: (index) => picked = index,
        ),
      ),
    );

    await tester.tap(find.text('Your statement'));
    expect(picked, 1);
  });

  testWidgets('the active tab does not re-report itself', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(
        AppTabs(
          tabs: const [AppTab(label: 'Doctor draft'), AppTab(label: 'Your statement')],
          selected: 0,
          onChanged: (_) => calls++,
        ),
      ),
    );

    await tester.tap(find.text('Doctor draft'));
    expect(calls, 0, reason: 'the active tab is not tappable');
  });
}
