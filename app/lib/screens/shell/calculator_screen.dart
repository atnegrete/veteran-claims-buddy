import 'package:flutter/material.dart';

import '../../app/app_badge.dart';
import '../../app/app_theme.dart';
import '../../app/app_ui.dart';
import '../../calculator/combined_rating.dart';
import '../../calculator/compensation_rates.dart';
import 'shell_pages.dart';
import 'signed_in_bar.dart';

const ratingChoices = <int>[10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

const _extremityLabels = <Extremity, String>{
  Extremity.none: 'Not a limb',
  Extremity.leftArm: 'Left arm',
  Extremity.rightArm: 'Right arm',
  Extremity.leftLeg: 'Left leg',
  Extremity.rightLeg: 'Right leg',
};

/// The width at which the estimate moves to a fixed right column.
const _wideBreak = 840.0;

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _entries = <RatingEntry>[];
  int _nextPercent = 10;
  Extremity _nextExtremity = Extremity.none;

  bool _spouse = false;
  bool _spouseAid = false;
  int _parents = 0;
  int _childrenUnder18 = 0;
  int _childrenSchool = 0;

  /// Narrow layout only: the pinned estimate shrinks once the inputs scroll.
  bool _collapsed = false;

  void _add() {
    setState(
      () => _entries.add(
        RatingEntry(percent: _nextPercent, extremity: _nextExtremity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unrounded = combinedRatingWithBilateral(_entries);
    final rounded = roundedCombinedRating(unrounded);
    final estimate = _Estimate(
      hasRatings: _entries.isNotEmpty,
      unrounded: unrounded,
      rounded: rounded,
      bilateral: bilateralFactorApplies(_entries),
      cents: _entries.isEmpty
          ? null
          : monthlyCompensationCents(
              rounded,
              CompensationInput(
                spouse: _spouse,
                spouseAid: _spouse && _spouseAid,
                parents: _parents,
                childrenUnder18: _childrenUnder18,
                childrenSchool: _childrenSchool,
              ),
            ),
    );

    return ShellPage(
      title: 'VA Ratings Calculator',
      wrapInCard: false,
      expandChild: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inputs = _InputsColumn(
            entries: _entries,
            nextPercent: _nextPercent,
            nextExtremity: _nextExtremity,
            spouse: _spouse,
            spouseAid: _spouseAid,
            parents: _parents,
            childrenUnder18: _childrenUnder18,
            childrenSchool: _childrenSchool,
            onPercent: (value) => setState(() => _nextPercent = value),
            onExtremity: (value) => setState(() => _nextExtremity = value),
            onAdd: _add,
            onRemove: (index) => setState(() => _entries.removeAt(index)),
            onSpouse: (value) => setState(() {
              _spouse = value;
              if (!value) _spouseAid = false;
            }),
            onSpouseAid: (value) => setState(() => _spouseAid = value),
            onParents: (value) => setState(() => _parents = value),
            onChildrenUnder18: (value) =>
                setState(() => _childrenUnder18 = value),
            onChildrenSchool: (value) =>
                setState(() => _childrenSchool = value),
          );

          if (constraints.maxWidth >= _wideBreak) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SingleChildScrollView(child: inputs)),
                const SizedBox(width: 16),
                SizedBox(
                  width: 360,
                  child: _EstimateCard(estimate: estimate, compact: false),
                ),
              ],
            );
          }

          return Column(
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _EstimateCard(estimate: estimate, compact: _collapsed),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    final collapsed = notification.metrics.pixels > 24;
                    if (collapsed != _collapsed) {
                      setState(() => _collapsed = collapsed);
                    }
                    return false;
                  },
                  child: SingleChildScrollView(child: inputs),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The numbers shown in the estimate panel.
class _Estimate {
  const _Estimate({
    required this.hasRatings,
    required this.unrounded,
    required this.rounded,
    required this.bilateral,
    required this.cents,
  });

  final bool hasRatings;
  final int unrounded;
  final int rounded;
  final bool bilateral;
  final int? cents;

  String get amount => cents == null ? '—' : formatDollars(cents!);
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard({required this.estimate, required this.compact});

  final _Estimate estimate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!estimate.hasRatings) {
      return SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Estimate'),
            const SizedBox(height: 8),
            Text('Add a rating', style: theme.textTheme.headlineSmall),
            if (!compact) ...[
              const SizedBox(height: 6),
              const LeadText(
                'Enter each disability rating to see a combined rating and an '
                'estimated monthly payment.',
              ),
            ],
          ],
        ),
      );
    }

    if (compact) {
      return SurfaceCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Est. monthly payment',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    estimate.amount,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.money,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${estimate.rounded}%', style: theme.textTheme.titleLarge),
                Text(
                  'combined',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Estimated monthly payment'),
          const SizedBox(height: 8),
          Text(
            estimate.amount,
            style: theme.textTheme.displaySmall?.copyWith(
              color: AppColors.money,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Combined rating',
                  value: '${estimate.rounded}%',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Combined value',
                  value: '${estimate.unrounded}%',
                ),
              ),
            ],
          ),
          if (estimate.bilateral) ...[
            const SizedBox(height: 12),
            const AppBadge.secondary(
              label: 'Bilateral factor applied',
              icon: Icons.check,
            ),
          ],
          if (estimate.rounded == 10 || estimate.rounded == 20) ...[
            const SizedBox(height: 12),
            Text(
              'A 10% or 20% rating does not increase for dependents.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.headlineSmall),
      ],
    );
  }
}

/// The scrolling side: disabilities, dependents, and the methodology note.
class _InputsColumn extends StatelessWidget {
  const _InputsColumn({
    required this.entries,
    required this.nextPercent,
    required this.nextExtremity,
    required this.spouse,
    required this.spouseAid,
    required this.parents,
    required this.childrenUnder18,
    required this.childrenSchool,
    required this.onPercent,
    required this.onExtremity,
    required this.onAdd,
    required this.onRemove,
    required this.onSpouse,
    required this.onSpouseAid,
    required this.onParents,
    required this.onChildrenUnder18,
    required this.onChildrenSchool,
  });

  final List<RatingEntry> entries;
  final int nextPercent;
  final Extremity nextExtremity;
  final bool spouse;
  final bool spouseAid;
  final int parents;
  final int childrenUnder18;
  final int childrenSchool;
  final ValueChanged<int> onPercent;
  final ValueChanged<Extremity> onExtremity;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<bool> onSpouse;
  final ValueChanged<bool> onSpouseAid;
  final ValueChanged<int> onParents;
  final ValueChanged<int> onChildrenUnder18;
  final ValueChanged<int> onChildrenSchool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DisabilitiesCard(
          entries: entries,
          nextPercent: nextPercent,
          nextExtremity: nextExtremity,
          onPercent: onPercent,
          onExtremity: onExtremity,
          onAdd: onAdd,
          onRemove: onRemove,
        ),
        const SizedBox(height: 12),
        _DependentsCard(
          spouse: spouse,
          spouseAid: spouseAid,
          parents: parents,
          childrenUnder18: childrenUnder18,
          childrenSchool: childrenSchool,
          onSpouse: onSpouse,
          onSpouseAid: onSpouseAid,
          onParents: onParents,
          onChildrenUnder18: onChildrenUnder18,
          onChildrenSchool: onChildrenSchool,
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('How this is estimated', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Ratings combine under 38 CFR 4.25, largest first, with the '
                'bilateral factor added when both arms or both legs are '
                'affected. Monthly pay uses the VA rate table effective '
                'December 1, 2025. Actual compensation depends on an official '
                'VA decision.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DisabilitiesCard extends StatelessWidget {
  const _DisabilitiesCard({
    required this.entries,
    required this.nextPercent,
    required this.nextExtremity,
    required this.onPercent,
    required this.onExtremity,
    required this.onAdd,
    required this.onRemove,
  });

  final List<RatingEntry> entries;
  final int nextPercent;
  final Extremity nextExtremity;
  final ValueChanged<int> onPercent;
  final ValueChanged<Extremity> onExtremity;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Disabilities', style: theme.textTheme.titleMedium),
              ),
              if (entries.isNotEmpty)
                AppBadge.primary(label: '${entries.length} added'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Mark a limb to count it toward the bilateral factor.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 104,
                child: DropdownButtonFormField<int>(
                  initialValue: nextPercent,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Rating'),
                  items: [
                    for (final rating in ratingChoices)
                      DropdownMenuItem(value: rating, child: Text('$rating%')),
                  ],
                  onChanged: (value) {
                    if (value != null) onPercent(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<Extremity>(
                  initialValue: nextExtremity,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Body part'),
                  items: [
                    for (final entry in _extremityLabels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onExtremity(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: secondaryFilledStyle(),
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add rating'),
          ),
          if (entries.isEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'No ratings yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            for (var index = 0; index < entries.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              _EntryCard(
                entry: entries[index],
                onRemove: () => onRemove(index),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// One added disability, in its own raised chip so the list reads clearly.
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onRemove});

  final RatingEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final limb = entry.extremity == Extremity.none
        ? null
        : _extremityLabels[entry.extremity];
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          Text('${entry.percent}%', style: theme.textTheme.titleMedium),
          if (limb != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                limb,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ] else
            const Spacer(),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _DependentsCard extends StatelessWidget {
  const _DependentsCard({
    required this.spouse,
    required this.spouseAid,
    required this.parents,
    required this.childrenUnder18,
    required this.childrenSchool,
    required this.onSpouse,
    required this.onSpouseAid,
    required this.onParents,
    required this.onChildrenUnder18,
    required this.onChildrenSchool,
  });

  final bool spouse;
  final bool spouseAid;
  final int parents;
  final int childrenUnder18;
  final int childrenSchool;
  final ValueChanged<bool> onSpouse;
  final ValueChanged<bool> onSpouseAid;
  final ValueChanged<int> onParents;
  final ValueChanged<int> onChildrenUnder18;
  final ValueChanged<int> onChildrenSchool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Dependents', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'A rating of 30% or higher can pay more with dependents.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Spouse'),
            value: spouse,
            onChanged: onSpouse,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Spouse receives Aid and Attendance'),
            value: spouseAid,
            onChanged: spouse ? onSpouseAid : null,
          ),
          const SizedBox(height: 8),
          _CountRow(
            label: 'Children under 18',
            value: childrenUnder18,
            onChanged: onChildrenUnder18,
          ),
          _CountRow(
            label: 'Children 18+ in school',
            value: childrenSchool,
            onChanged: onChildrenSchool,
          ),
          _CountRow(
            label: 'Dependent parents',
            value: parents,
            max: 2,
            onChanged: onParents,
          ),
        ],
      ),
    );
  }
}

/// A labeled stepper. Avoids a free-text number field for a small count.
class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.max = 20,
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          IconButton.outlined(
            tooltip: 'Fewer',
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton.outlined(
            tooltip: 'More',
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
