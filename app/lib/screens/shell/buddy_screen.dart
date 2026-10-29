import 'package:flutter/material.dart';

import '../../app/app_ui.dart';
import 'shell_pages.dart';
import 'signed_in_bar.dart';

const vetBuddyFooter =
    'Please verify important VA or medical information before acting. Do not share sensitive identifiers such as your Social Security number in chat.';

class BuddyScreen extends StatelessWidget {
  const BuddyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShellPage(
      title: 'Vet Buddy',
      wrapInCard: false,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LeadText(
              'Vet Buddy answers questions about this claim. It does not file, decide, or change it.',
            ),
            const SizedBox(height: 12),
            const LeadText('Ask from the chat bubble on this claim.'),
            const SizedBox(height: 16),
            const InfoNote(text: vetBuddyFooter),
          ],
        ),
      ),
    );
  }
}
