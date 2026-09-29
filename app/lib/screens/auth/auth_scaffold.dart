import 'package:flutter/material.dart';

const independentProductDisclaimer =
    'Veteran Claims Buddy is an independent service and is not affiliated with or endorsed by the U.S. Department of Veterans Affairs.';

const supportEmail = 'support@veteranclaimsbuddy.com';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Veteran Claims Buddy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class AuthMessageText extends StatelessWidget {
  const AuthMessageText(this.message, {super.key, this.isError = true});

  final String? message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(message!, style: TextStyle(color: color)),
    );
  }
}
