import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';

/// Stand-in until the brand package supplies a logo.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'V',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.5,
          height: 1,
        ),
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

/// App bar for every screen after the account is ready to use.
class SignedInAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const SignedInAppBar({super.key, this.showAccountLink = false});

  /// Shell pages can open You from the account menu. Onboarding cannot.
  final bool showAccountLink;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authControllerProvider).session?.email;
    return AppBar(
      automaticallyImplyLeading: false,
      leading: const Padding(
        padding: EdgeInsets.only(left: 12),
        child: AppLogoMark(),
      ),
      leadingWidth: 48,
      titleSpacing: 8,
      title: const Text('Veteran Claims Buddy'),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Account',
          icon: const Icon(Icons.account_circle_outlined),
          onSelected: (value) {
            switch (value) {
              case 'account':
                context.go(AuthRoutes.you);
              case 'signOut':
                ref.read(authControllerProvider.notifier).signOut();
            }
          },
          itemBuilder: (context) => [
            if (email != null)
              PopupMenuItem<String>(
                enabled: false,
                child: Text(email),
              ),
            if (email != null) const PopupMenuDivider(),
            if (showAccountLink)
              const PopupMenuItem<String>(
                value: 'account',
                child: Text('You'),
              ),
            const PopupMenuItem<String>(
              value: 'signOut',
              child: Text('Sign out'),
            ),
          ],
        ),
      ],
    );
  }
}

class SignedInScaffold extends StatelessWidget {
  const SignedInScaffold({super.key, required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SignedInAppBar(),
      body: body,
    );
  }
}
