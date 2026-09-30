import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_redirect.dart';
import '../../cases/cases_progress.dart';
import 'signed_in_bar.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  static const destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.folder_outlined),
      selectedIcon: Icon(Icons.folder),
      label: 'Case',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat_bubble),
      label: 'Vet Buddy',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'You',
    ),
  ];

  int get _index {
    if (location == AuthRoutes.cases || location.startsWith('${AuthRoutes.cases}/')) {
      return 1;
    }
    if (location == AuthRoutes.buddy || location.startsWith('${AuthRoutes.buddy}/')) {
      return 2;
    }
    if (location == AuthRoutes.you || location.startsWith('${AuthRoutes.you}/')) {
      return 3;
    }
    return 0;
  }

  void _select(BuildContext context, WidgetRef ref, int index) {
    switch (index) {
      case 1:
        final id = ref.read(workingCaseIdProvider);
        context.go(id == null ? AuthRoutes.cases : AuthRoutes.caseOverview(id));
      case 2:
        context.go(AuthRoutes.buddy);
      case 3:
        context.go(AuthRoutes.you);
      default:
        context.go(AuthRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(casesProvider, (previous, next) {
      final cases = next.asData?.value;
      if (cases != null) {
        ref.read(caseEnsureProvider.notifier).ensureIfNeeded(cases);
      }
    });
    final loaded = ref.watch(casesProvider).asData?.value;
    if (loaded != null) {
      Future.microtask(
        () => ref.read(caseEnsureProvider.notifier).ensureIfNeeded(loaded),
      );
    }
    return AdaptiveScaffold(
      useDrawer: false,
      appBarBreakpoint: Breakpoints.standard,
      appBar: const SignedInAppBar(showAccountLink: true),
      selectedIndex: _index,
      onSelectedIndexChange: (index) => _select(context, ref, index),
      destinations: destinations,
      smallBody: (_) => child,
      body: (_) => child,
    );
  }
}
