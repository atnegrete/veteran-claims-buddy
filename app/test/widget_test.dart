import 'package:app/app/app_environment.dart';
import 'package:app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dev diagnostic shows the banner and project', (tester) async {
    await tester.pumpWidget(
      const VeteranClaimsBuddyApp(
        environment: AppEnvironment.dev,
        projectId: 'veteran-claims-buddy-dev',
        applicationId: 'com.veteranclaimsbuddy.app.dev',
      ),
    );

    expect(find.text('Veteran Claims Buddy'), findsWidgets);
    expect(find.text('DEV'), findsOneWidget);
    expect(find.text('Environment: dev'), findsOneWidget);
    expect(find.text('Project: veteran-claims-buddy-dev'), findsOneWidget);
    expect(find.text('App id: com.veteranclaimsbuddy.app.dev'), findsOneWidget);
  });

  testWidgets('prod diagnostic has no DEV banner', (tester) async {
    await tester.pumpWidget(
      const VeteranClaimsBuddyApp(
        environment: AppEnvironment.prod,
        projectId: 'veteran-claims-buddy-prod',
        applicationId: 'com.veteranclaimsbuddy.app',
      ),
    );

    expect(find.text('DEV'), findsNothing);
    expect(find.text('Environment: prod'), findsOneWidget);
    expect(find.text('Project: veteran-claims-buddy-prod'), findsOneWidget);
    expect(find.text('App id: com.veteranclaimsbuddy.app'), findsOneWidget);
  });
}
