import 'package:app/calculator/combined_rating.dart';
import 'package:app/home/home_snapshot.dart';
import 'package:app/screens/shell/plans_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('combines ratings largest first and rounds 5 up', () {
    expect(unroundedCombinedRating([10, 10]), 19);
    expect(roundedCombinedRating(19), 20);
    expect(unroundedCombinedRating([50, 30]), 65);
    expect(roundedCombinedRating(65), 70);
    expect(unroundedCombinedRating([60, 10]), 64);
    expect(roundedCombinedRating(64), 60);
    expect(unroundedCombinedRating([40, 20, 10]), 57);
    expect(roundedCombinedRating(57), 60);
    expect(roundedCombinedRating(0), 0);
  });

  test('symptom entry opens plans until Premium is active', () {
    expect(symptomDestination(premiumActive: false), '/plans?reason=symptoms');
    expect(symptomDestination(premiumActive: true), '/symptoms/events/new');
  });

  test('plans copy follows the reason it was opened', () {
    expect(plansLead(reason: 'symptoms'), contains('Premium'));
    expect(plansLead(reason: 'package'), contains('claim package'));
    expect(plansLead(), contains('Case unlock'));
  });
}
