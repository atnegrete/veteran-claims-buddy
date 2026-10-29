import 'package:app/calculator/combined_rating.dart';
import 'package:app/calculator/compensation_rates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('monthly compensation', () {
    test('10% and 20% ignore dependents', () {
      const withFamily = CompensationInput(spouse: true, childrenUnder18: 3);
      expect(monthlyCompensationCents(10, withFamily), 18042);
      expect(monthlyCompensationCents(20, withFamily), 35666);
    });

    test('a rating below 10 has no rate', () {
      expect(monthlyCompensationCents(0, const CompensationInput()), isNull);
    });

    test('a veteran alone uses the base table', () {
      expect(monthlyCompensationCents(100, const CompensationInput()), 393858);
      expect(monthlyCompensationCents(30, const CompensationInput()), 55247);
    });

    test('a spouse and one child raise the rate', () {
      const input = CompensationInput(spouse: true, childrenUnder18: 1);
      expect(monthlyCompensationCents(100, input), 431899);
    });

    test('extra children add per child beyond the first', () {
      const input = CompensationInput(spouse: true, childrenUnder18: 2);
      // 1-0-1 base plus one extra under-18 child.
      expect(monthlyCompensationCents(100, input), 431899 + 10911);
    });

    test('spouse Aid and Attendance adds its amount', () {
      const input = CompensationInput(spouse: true, spouseAid: true);
      expect(monthlyCompensationCents(100, input), 415817 + 20141);
    });
  });

  group('formatDollars', () {
    test('groups thousands and keeps cents', () {
      expect(formatDollars(393858), '\$3,938.58');
      expect(formatDollars(18042), '\$180.42');
    });
  });

  group('bilateral factor', () {
    test('does not apply without a matched pair', () {
      final entries = [
        const RatingEntry(percent: 10, extremity: Extremity.leftArm),
        const RatingEntry(percent: 20, extremity: Extremity.leftLeg),
      ];
      expect(bilateralFactorApplies(entries), isFalse);
      expect(
        combinedRatingWithBilateral(entries),
        unroundedCombinedRating([10, 20]),
      );
    });

    test('applies when both arms are affected', () {
      final entries = [
        const RatingEntry(percent: 10, extremity: Extremity.leftArm),
        const RatingEntry(percent: 10, extremity: Extremity.rightArm),
      ];
      expect(bilateralFactorApplies(entries), isTrue);
      // 10 and 10 combine to 19, plus 10% of 19 rounds to 2, giving 21.
      expect(combinedRatingWithBilateral(entries), 21);
    });

    test('combines the bilateral block with other disabilities', () {
      final entries = [
        const RatingEntry(percent: 20, extremity: Extremity.leftLeg),
        const RatingEntry(percent: 20, extremity: Extremity.rightLeg),
        const RatingEntry(percent: 40),
      ];
      expect(bilateralFactorApplies(entries), isTrue);
      // Legs: 20 and 20 -> 36, plus 10% (4) -> 40. Then combine 40 and 40.
      expect(combinedRatingWithBilateral(entries), 64);
      expect(roundedCombinedRating(64), 60);
    });
  });
}
