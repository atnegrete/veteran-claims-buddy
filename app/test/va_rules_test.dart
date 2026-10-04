import 'dart:convert';
import 'dart:io';

import 'package:app/claim/claim_review.dart';
import 'package:app/claim/va_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app uses the checked-in VA rule snapshot', () {
    final file = File('../knowledge/va-rules.json');
    final rules = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(rules['id'], deadlineRuleVersionId);
    expect(rules['reviewDeadlineYears'], reviewDeadlineYears);
    expect(rules['sources'], [
      {
        'id': 'decision-reviews',
        'title': 'VA decision reviews',
        'url': vaDecisionReviewsUrl,
      },
    ]);
    final reviews = rules['reviews'] as List<dynamic>;
    expect(reviews, hasLength(ReviewPath.values.length));
    for (final path in ReviewPath.values) {
      final match = reviews.cast<Map<String, dynamic>>().singleWhere(
        (review) => review['path'] == path.name,
      );
      expect(match['type'], reviewType(path));
      expect(match['formId'], reviewFormId(path));
    }
  });
}
