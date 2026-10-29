import 'package:app/app/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('named flavors resolve directly', () {
    expect(resolveEnvironment('dev', releaseMode: false), AppEnvironment.dev);
    expect(resolveEnvironment('dev', releaseMode: true), AppEnvironment.dev);
    expect(resolveEnvironment('prod', releaseMode: true), AppEnvironment.prod);
  });

  test('debug with no flavor defaults to dev', () {
    expect(resolveEnvironment(null, releaseMode: false), AppEnvironment.dev);
  });

  test('release with no flavor fails', () {
    expect(() => resolveEnvironment(null, releaseMode: true), throwsStateError);
  });

  test('unknown flavor fails', () {
    expect(
      () => resolveEnvironment('staging', releaseMode: false),
      throwsStateError,
    );
  });
}
