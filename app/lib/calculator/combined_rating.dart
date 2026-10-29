/// VA combined rating from 38 CFR 4.25, without the bilateral factor.
///
/// Ratings are applied largest first. Each one is taken against the
/// efficiency that is still left, and that step is rounded to a whole number.
int unroundedCombinedRating(List<int> ratings) {
  final sorted = [
    for (final rating in ratings)
      if (rating > 0) rating,
  ]..sort((a, b) => b.compareTo(a));
  var combined = 0;
  for (final rating in sorted) {
    combined += (rating * (100 - combined) / 100).round();
    if (combined > 100) return 100;
  }
  return combined;
}

/// Combined values ending in 5 or more move up to the next 10.
int roundedCombinedRating(int unrounded) {
  if (unrounded <= 0) return 0;
  final ones = unrounded % 10;
  final base = unrounded - ones;
  final rounded = ones >= 5 ? base + 10 : base;
  return rounded > 100 ? 100 : rounded;
}

/// A body part a rating may affect, used for the bilateral factor.
///
/// `none` is a disability that is not a paired limb.
enum Extremity { none, leftArm, rightArm, leftLeg, rightLeg }

extension ExtremityLimb on Extremity {
  bool get isArm => this == Extremity.leftArm || this == Extremity.rightArm;
  bool get isLeg => this == Extremity.leftLeg || this == Extremity.rightLeg;
}

/// One disability: a percent and the limb it affects, if any.
class RatingEntry {
  const RatingEntry({required this.percent, this.extremity = Extremity.none});

  final int percent;
  final Extremity extremity;
}

/// Whether the bilateral factor applies to [entries].
///
/// Under 38 CFR 4.26 it applies only when both sides of a pair are affected:
/// a left and a right arm, or a left and a right leg.
bool bilateralFactorApplies(List<RatingEntry> entries) {
  final active = [
    for (final entry in entries)
      if (entry.percent > 0) entry,
  ];
  bool has(Extremity side) => active.any((entry) => entry.extremity == side);
  final arms = has(Extremity.leftArm) && has(Extremity.rightArm);
  final legs = has(Extremity.leftLeg) && has(Extremity.rightLeg);
  return arms || legs;
}

/// Combined rating with the 38 CFR 4.26 bilateral factor applied.
///
/// Qualifying bilateral disabilities (both arms and/or both legs) are combined
/// first, 10% of that value is added, and the result is combined with the
/// remaining disabilities. The returned value is unrounded.
int combinedRatingWithBilateral(List<RatingEntry> entries) {
  final active = [
    for (final entry in entries)
      if (entry.percent > 0) entry,
  ];
  bool has(Extremity side) => active.any((entry) => entry.extremity == side);
  final armsPaired = has(Extremity.leftArm) && has(Extremity.rightArm);
  final legsPaired = has(Extremity.leftLeg) && has(Extremity.rightLeg);

  final bilateral = <int>[];
  final others = <int>[];
  for (final entry in active) {
    final qualifies =
        (entry.extremity.isArm && armsPaired) ||
        (entry.extremity.isLeg && legsPaired);
    (qualifies ? bilateral : others).add(entry.percent);
  }

  if (bilateral.isEmpty) return unroundedCombinedRating(others);

  final combinedBilateral = unroundedCombinedRating(bilateral);
  final withFactor = combinedBilateral + (combinedBilateral * 0.1).round();
  return unroundedCombinedRating([withFactor, ...others]);
}
