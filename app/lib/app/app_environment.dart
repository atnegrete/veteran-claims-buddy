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

/// Flutter web does not support `--flavor`, so the environment is passed with
/// `--dart-define=APP_ENV=dev|prod` instead. Mobile keeps using `--flavor`,
/// which populates [appFlavor]. When both are absent the existing rules apply:
/// debug/test default to dev, a release build refuses to guess.
const String _appEnvDefine = String.fromEnvironment('APP_ENV');

AppEnvironment get currentEnvironment => resolveEnvironment(
      _appEnvDefine.isNotEmpty ? _appEnvDefine : appFlavor,
      releaseMode: kReleaseMode,
    );

bool get isDevelopment => currentEnvironment == AppEnvironment.dev;

bool get isProduction => currentEnvironment == AppEnvironment.prod;
