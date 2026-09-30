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
