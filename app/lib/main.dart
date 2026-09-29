import 'package:flutter/material.dart';

import 'app/app_environment.dart';

void main() {
  runApp(const VeteranClaimsBuddyApp());
}

class VeteranClaimsBuddyApp extends StatelessWidget {
  const VeteranClaimsBuddyApp({super.key});

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
      home: const PlaceholderHome(),
    );
  }
}

class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Veteran Claims Buddy')),
      body: Center(
        child: Text('Environment: ${currentEnvironment.name}'),
      ),
    );
  }
}
