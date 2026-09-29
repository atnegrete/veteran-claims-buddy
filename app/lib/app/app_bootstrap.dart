import 'package:firebase_core/firebase_core.dart';

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

Future<void> bootstrapFirebase(AppEnvironment environment) {
  return Firebase.initializeApp(
    options: firebaseOptionsFor(environment),
  );
}
