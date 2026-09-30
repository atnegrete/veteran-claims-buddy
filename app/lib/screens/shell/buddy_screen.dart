import 'package:flutter/material.dart';

import 'shell_pages.dart';
import 'signed_in_bar.dart';

const vetBuddyFooter =
    'Please verify important VA or medical information before acting. Do not share sensitive identifiers such as your Social Security number in chat.';

class BuddyScreen extends StatelessWidget {
  const BuddyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ShellPage(
      title: 'Vet Buddy',
      wrapInCard: false,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vet Buddy answers questions about your case. It does not file a claim, and it does not decide one for you.',
            ),
            const SizedBox(height: 12),
            const Text('There are no chats yet.'),
            const SizedBox(height: 16),
            Text(
              vetBuddyFooter,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
