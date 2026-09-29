import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app/app_bootstrap.dart';
import 'app/app_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = currentEnvironment;
  await bootstrapFirebase(environment);
  final packageInfo = await PackageInfo.fromPlatform();
  runApp(
    VeteranClaimsBuddyApp(
      environment: environment,
      projectId: Firebase.app().options.projectId,
      applicationId: packageInfo.packageName,
    ),
  );
}

class VeteranClaimsBuddyApp extends StatelessWidget {
  const VeteranClaimsBuddyApp({
    super.key,
    this.environment,
    this.projectId,
    this.applicationId,
  });

  /// When omitted, the flavor from the running build is used.
  final AppEnvironment? environment;
  final String? projectId;
  final String? applicationId;

  AppEnvironment get _environment => environment ?? currentEnvironment;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veteran Claims Buddy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F4E79),
          brightness: Brightness.dark,
        ),
      ),
      home: PlaceholderHome(
        environment: _environment,
        projectId: projectId,
        applicationId: applicationId,
      ),
    );
  }
}

class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({
    super.key,
    required this.environment,
    this.projectId,
    this.applicationId,
  });

  final AppEnvironment environment;
  final String? projectId;
  final String? applicationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Veteran Claims Buddy')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (environment == AppEnvironment.dev) const _DevBanner(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Environment: ${environment.name}'),
                  Text('Project: ${projectId ?? 'not connected'}'),
                  Text('App id: ${applicationId ?? 'unknown'}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevBanner extends StatelessWidget {
  const _DevBanner();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFB45309),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 28,
          child: Center(
            child: Text(
              'DEV',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
