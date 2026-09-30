import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';
import 'signed_in_bar.dart';

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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go(AuthRoutes.security),
              child: const Text('Security'),
            ),
          ),
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
    this.wrapInCard = true,
  });

  final String title;
  final Widget child;
  final bool wrapInCard;

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
              if (wrapInCard) SurfaceCard(child: child) else child,
            ],
          ),
        ),
      ),
    );
  }
}
