import 'package:app/app/app_theme.dart';
import 'package:app/billing/entitlement_service.dart';
import 'package:app/screens/shell/plans_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    PremiumStatus premium = PremiumStatus.inactive,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumStatusProvider.overrideWith((ref) => Stream.value(premium)),
        ],
        child: MaterialApp(
          theme: appTheme(),
          home: const Scaffold(body: PlansScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the three columns render wide without layout errors', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1100, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Free workspace'), findsOneWidget);
    expect(find.text('Case unlock'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Most coverage'), findsOneWidget);
  });

  testWidgets('the columns stack on a narrow pane', (tester) async {
    await pumpAt(tester, const Size(420, 1200));
    expect(tester.takeException(), isNull);
    expect(find.text('Premium'), findsOneWidget);
  });

  testWidgets('an inactive account sees a Choose a plan button', (tester) async {
    await pumpAt(tester, const Size(1100, 900));
    expect(find.text('Choose a plan'), findsOneWidget);
    expect(find.text('Manage billing'), findsNothing);
  });

  testWidgets('an active subscription sees Manage billing, not a buy button', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const Size(1100, 900),
      premium: PremiumStatus(
        isActive: true,
        source: 'subscription',
        premiumUntil: DateTime.now().add(const Duration(days: 30)),
        willRenew: true,
        activeCaseLimit: null,
      ),
    );
    expect(find.text('Manage billing'), findsOneWidget);
    expect(find.text('Choose a plan'), findsNothing);
  });

  testWidgets('an expired subscription sees an expired note and Renew', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const Size(1100, 900),
      premium: PremiumStatus(
        isActive: false,
        source: 'subscription',
        premiumUntil: DateTime.now().subtract(const Duration(days: 3)),
        willRenew: false,
        activeCaseLimit: null,
      ),
    );
    expect(find.textContaining('expired'), findsWidgets);
    expect(find.text('Renew'), findsOneWidget);
    expect(find.text('Manage billing'), findsNothing);
  });
}
