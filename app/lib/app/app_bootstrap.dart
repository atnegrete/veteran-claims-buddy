import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options_dev.dart' as firebase_dev;
import '../firebase_options_prod.dart' as firebase_prod;
import 'app_environment.dart';

/// Options for one flavor. The prod binary only references the prod options.
FirebaseOptions firebaseOptionsFor(AppEnvironment environment) {
  switch (environment) {
    case AppEnvironment.dev:
      return firebase_dev.DefaultFirebaseOptions.currentPlatform;
    case AppEnvironment.prod:
      return firebase_prod.DefaultFirebaseOptions.currentPlatform;
  }
}

/// reCAPTCHA site key for web App Check. Empty until the owner registers a key
/// in the Firebase console (Phase 6, step 6C) and passes it with
/// `--dart-define=APP_CHECK_WEB_KEY=...`. Web App Check stays off until then.
const String appCheckWebSiteKey = String.fromEnvironment('APP_CHECK_WEB_KEY');

Future<void> bootstrapFirebase(AppEnvironment environment) async {
  await Firebase.initializeApp(
    options: firebaseOptionsFor(environment),
  );
  await activateAppCheck(environment);
  if (environment == AppEnvironment.dev) {
    // Fictional console numbers only. A real number is rejected.
    // Production keeps the live reCAPTCHA check.
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
  }
}

/// Turns on App Check attestation. Enforcement stays OFF in the Firebase
/// console (Phase 6, step 6E); activating here only makes tokens flow so the
/// console metrics can be watched before enforcement is ever enabled.
///
/// Dev builds use debug providers. The debug token each build prints is
/// registered once in the console (step 6B). Prod builds use Play Integrity on
/// Android and App Attest on Apple. Web stays off until a reCAPTCHA site key
/// exists (step 6C).
Future<void> activateAppCheck(AppEnvironment environment) async {
  if (kIsWeb && appCheckWebSiteKey.isEmpty) {
    // Web needs a reCAPTCHA site key from the console. Owner gate 6C.
    return;
  }
  final isDev = environment == AppEnvironment.dev;
  await FirebaseAppCheck.instance.activate(
    providerAndroid: isDev
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple:
        isDev ? const AppleDebugProvider() : const AppleAppAttestProvider(),
    providerWeb: appCheckWebSiteKey.isEmpty
        ? null
        : ReCaptchaV3Provider(appCheckWebSiteKey),
  );
}
