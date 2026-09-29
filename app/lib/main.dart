import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_bootstrap.dart';
import 'app/app_environment.dart';
import 'app/dev_banner.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_gateway.dart';
import 'routing/app_router.dart';

const authLoadingKey = Key('auth-loading');

final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => currentEnvironment,
);

final firebaseProjectIdProvider = Provider<String?>((ref) => null);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = currentEnvironment;
  await bootstrapFirebase(environment);
  runApp(
    VeteranClaimsBuddyApp(
      environment: environment,
      projectId: Firebase.app().options.projectId,
    ),
  );
}

class VeteranClaimsBuddyApp extends StatelessWidget {
  const VeteranClaimsBuddyApp({
    super.key,
    this.environment,
    this.projectId,
    this.authGateway,
  });

  final AppEnvironment? environment;
  final String? projectId;
  final AuthGateway? authGateway;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          environment ?? currentEnvironment,
        ),
        firebaseProjectIdProvider.overrideWithValue(projectId),
        if (authGateway != null)
          authGatewayProvider.overrideWithValue(authGateway!),
      ],
      child: const AuthApp(),
    );
  }
}

class AuthApp extends ConsumerWidget {
  const AuthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appEnvironmentProvider);
    final projectId = ref.watch(firebaseProjectIdProvider);
    final gate = ref.watch(authControllerProvider);
    final banner = environment == AppEnvironment.dev
        ? DevBanner(projectId: projectId)
        : null;

    if (!gate.ready) {
      return MaterialApp(
        title: 'Veteran Claims Buddy',
        theme: _theme,
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?banner,
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(key: authLoadingKey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Veteran Claims Buddy',
      theme: _theme,
      routerConfig: router,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?banner,
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }
}

final _theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1F4E79),
    brightness: Brightness.dark,
  ),
);
