import 'package:flutter/material.dart';

import '../../calculator/combined_rating.dart';
import 'shell_pages.dart';
import 'signed_in_bar.dart';

const ratingChoices = <int>[10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _ratings = <int>[];
  int _next = 10;

  void _add() {
    setState(() => _ratings.add(_next));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unrounded = unroundedCombinedRating(_ratings);
    final rounded = roundedCombinedRating(unrounded);
    return ShellPage(
      title: 'Calculator',
      wrapInCard: false,
      child: Column(
        children: [
          const SurfaceCard(
            child: Text(
              'This estimates a combined VA disability rating. It does not change a case. It does not apply the bilateral factor, and it does not estimate monthly pay. Actual compensation depends on VA rules and an official decision.',
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _next,
                        items: [
                          for (final rating in ratingChoices)
                            DropdownMenuItem(value: rating, child: Text('$rating%')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _next = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(96, 48),
                      ),
                      onPressed: _add,
                      child: const Text('Add'),
                    ),
                  ],
                ),
                if (_ratings.isEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Add a rating to see a combined result.'),
                ] else ...[
                  const SizedBox(height: 8),
                  for (var index = 0; index < _ratings.length; index++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${_ratings[index]}%'),
                      trailing: IconButton(
                        tooltip: 'Remove',
                        onPressed: () => setState(() => _ratings.removeAt(index)),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Combined value $unrounded',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rounded rating $rounded%',
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
