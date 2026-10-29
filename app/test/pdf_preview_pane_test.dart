import 'package:app/app/app_theme.dart';
import 'package:app/forms/pdf_preview_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: appTheme(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('PdfPreviewPane shows a spinner while bytes are null', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const PdfPreviewPane(bytes: null)));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PdfPreviewPane shows an error and retries', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _host(
        PdfPreviewPane(
          bytes: null,
          error: 'The preview failed.',
          onRetry: () => retried = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('The preview failed.'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });
}
