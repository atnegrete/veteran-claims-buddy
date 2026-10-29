import 'package:app/app/app_theme.dart';
import 'package:app/auth/auth_controller.dart';
import 'package:app/cases/cases_progress.dart';
import 'package:app/screens/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _QuietAuth extends AuthController {
  @override
  AuthGateState build() => const AuthGateState(ready: true, session: null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Conditions stays selected on the list and a nested page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> pumpAt(String location) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_QuietAuth.new),
            ensureWorkingCaseCallerProvider.overrideWithValue(
              () async => 'case-1',
            ),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: AppShell(location: location, child: const SizedBox.shrink()),
          ),
        ),
      );
      await tester.pump();
    }

    FontWeight? weightOf(String label) {
      return tester.widget<Text>(find.text(label)).style?.fontWeight;
    }

    await pumpAt('/cases/case-1/conditions');
    expect(weightOf('Conditions'), FontWeight.w600);
    expect(weightOf('Questions'), FontWeight.w400);

    await pumpAt('/cases/case-1/conditions/migraine/questions');
    expect(weightOf('Conditions'), FontWeight.w600);
    expect(weightOf('Questions'), FontWeight.w400);

    await pumpAt('/cases/case-1/questions');
    expect(weightOf('Questions'), FontWeight.w600);
    expect(weightOf('Conditions'), FontWeight.w400);
  });
}
