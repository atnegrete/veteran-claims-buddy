import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_redirect.dart';

/// The brand mark: a navy tile with the white V.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/logo-mark.svg',
      width: size,
      height: size,
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}

/// App bar for every screen after the account is ready to use.
class SignedInAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const SignedInAppBar({
    super.key,
    this.showAccountLink = false,
    this.showMenu = false,
    this.dense = false,
    this.onVetBuddy,
  });

  /// Shell pages can open the account menu. Onboarding cannot.
  final bool showAccountLink;

  /// Narrow windows open the same navigation list from here.
  final bool showMenu;

  /// A shorter bar on a phone, so the page keeps the height.
  final bool dense;

  /// Opens Vet Buddy from the bar. A phone uses this instead of a floating button.
  final VoidCallback? onVetBuddy;

  static const denseHeight = 48.0;

  @override
  Size get preferredSize =>
      Size.fromHeight(dense ? denseHeight : kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authControllerProvider).session?.email;
    return AppBar(
      toolbarHeight: dense ? denseHeight : null,
      automaticallyImplyLeading: false,
      leading: showMenu
          ? IconButton(
              tooltip: 'Open navigation',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu),
            )
          : const Padding(
              padding: EdgeInsets.only(left: 12),
              child: AppLogoMark(),
            ),
      leadingWidth: showMenu ? 56 : 48,
      titleSpacing: 8,
      title: showMenu
          ? const Row(
              children: [
                AppLogoMark(),
                SizedBox(width: 8),
                Expanded(child: Text('Veteran Claims Buddy')),
              ],
            )
          : const Text('Veteran Claims Buddy'),
      actions: [
        if (onVetBuddy != null)
          IconButton(
            tooltip: 'Vet Buddy',
            onPressed: onVetBuddy,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
        PopupMenuButton<String>(
          tooltip: 'Account',
          icon: const Icon(Icons.account_circle_outlined),
          onSelected: (value) {
            switch (value) {
              case 'account':
                context.go(AuthRoutes.you);
              case 'security':
                context.go(AuthRoutes.security);
              case 'signOut':
                ref.read(authControllerProvider.notifier).signOut();
            }
          },
          itemBuilder: (context) => [
            if (email != null)
              PopupMenuItem<String>(enabled: false, child: Text(email)),
            if (email != null) const PopupMenuDivider(),
            if (showAccountLink) ...[
              const PopupMenuItem<String>(
                value: 'account',
                child: Text('Account'),
              ),
              const PopupMenuItem<String>(
                value: 'security',
                child: Text('Security'),
              ),
            ],
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
    return Scaffold(appBar: const SignedInAppBar(), body: body);
  }
}
