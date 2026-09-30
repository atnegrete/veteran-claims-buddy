import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import 'signed_in_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShellPage(
      title: 'Home',
      child: Text(
        'No case yet. When you have one, this page shows its status, the next action, and deadlines.',
      ),
    );
  }
}

class CasesScreen extends StatelessWidget {
  const CasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShellPage(
      title: 'Cases',
      child: Text(
        'No cases yet. You can keep up to 12. Starting one is not open yet.',
      ),
    );
  }
}

class BuddyScreen extends StatelessWidget {
  const BuddyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShellPage(
      title: 'Vet Buddy',
      child: Text('Vet Buddy is not open yet.'),
    );
  }
}

class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    return ShellPage(
      title: 'You',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (session?.email != null) Text(session!.email!),
          if (session?.maskedPhone != null) ...[
            const SizedBox(height: 8),
            Text(session!.maskedPhone!),
          ],
          const SizedBox(height: 16),
          const Text('Security settings are not open yet.'),
        ],
      ),
    );
  }
}

class ShellPage extends StatelessWidget {
  const ShellPage({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              SurfaceCard(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
