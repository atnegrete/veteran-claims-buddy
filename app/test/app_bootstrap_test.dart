import 'package:app/app/app_bootstrap.dart';
import 'package:app/app/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each flavor loads only its own Firebase project', () {
    expect(
      firebaseOptionsFor(AppEnvironment.dev).projectId,
      'veteran-claims-buddy-dev',
    );
    expect(
      firebaseOptionsFor(AppEnvironment.prod).projectId,
      'veteran-claims-buddy-prod',
    );
  });
}
