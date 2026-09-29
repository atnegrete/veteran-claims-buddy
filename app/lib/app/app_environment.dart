import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppEnvironment { dev, prod }

/// Resolves the flavor passed by `flutter run` / `flutter build`.
///
/// A release build with no flavor fails. Debug and test runs with no flavor
/// use dev. Release builds may still target dev when `--flavor dev` is set.
AppEnvironment resolveEnvironment(String? flavor, {required bool releaseMode}) {
  switch (flavor) {
    case 'dev':
      return AppEnvironment.dev;
    case 'prod':
      return AppEnvironment.prod;
    case null:
      if (releaseMode) {
        throw StateError(
          'Release builds must set --flavor to dev or prod. '
          'Refusing to guess the environment.',
        );
      }
      return AppEnvironment.dev;
    default:
      throw StateError('Unknown app flavor "$flavor". Expected dev or prod.');
  }
}

AppEnvironment get currentEnvironment =>
    resolveEnvironment(appFlavor, releaseMode: kReleaseMode);

bool get isDevelopment => currentEnvironment == AppEnvironment.dev;

bool get isProduction => currentEnvironment == AppEnvironment.prod;
