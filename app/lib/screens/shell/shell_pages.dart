import 'package:flutter/material.dart';

import 'signed_in_bar.dart';

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
