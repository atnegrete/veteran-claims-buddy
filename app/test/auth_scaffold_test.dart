import 'dart:io';

import 'package:app/app/app_theme.dart';
import 'package:app/screens/auth/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the bundled mark matches the brand file', () {
    expect(
      File('assets/brand/logo-mark.svg').readAsStringSync(),
      File('../brand/logo-mark.svg').readAsStringSync(),
    );
  });

  testWidgets('a phone sign-in page stays one column', (tester) async {
    await _pump(tester, const Size(800, 600));

    expect(find.text('Veteran Claims Buddy'), findsOneWidget);
    expect(find.text(authSideDescription), findsNothing);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('a wide sign-in page shows the mark beside the form', (
    tester,
  ) async {
    await _pump(tester, const Size(1200, 800));

    expect(find.text('Veteran Claims Buddy'), findsOneWidget);
    expect(find.text(authSideDescription), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(),
      home: const AuthScaffold(title: 'Sign in', child: SizedBox.shrink()),
    ),
  );
}
