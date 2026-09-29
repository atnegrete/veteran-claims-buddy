import 'package:app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('placeholder shows the dev environment', (WidgetTester tester) async {
    await tester.pumpWidget(const VeteranClaimsBuddyApp());

    expect(find.text('Veteran Claims Buddy'), findsWidgets);
    expect(find.text('Environment: dev'), findsOneWidget);
  });
}
