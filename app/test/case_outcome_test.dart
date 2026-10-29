import 'package:app/cases/case_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a full denial or a reduction may appeal', () {
    expect(classifyCaseOutcomes(['denied']).appealEligible, isTrue);
    expect(classifyCaseOutcomes(['granted', 'reduced']).appealEligible, isTrue);
    expect(classifyCaseOutcomes(['denied']).pending, isFalse);
  });

  test('a grant or increase is complete-only', () {
    expect(classifyCaseOutcomes(['granted', 'denied']).appealEligible, isFalse);
    expect(classifyCaseOutcomes(['increased']).appealEligible, isFalse);
    expect(classifyCaseOutcomes(['granted', 'denied']).pending, isFalse);
  });

  test('an all-deferred or empty decision stays pending', () {
    expect(classifyCaseOutcomes(['deferred']).pending, isTrue);
    expect(classifyCaseOutcomes(const <String>[]).pending, isTrue);
    expect(classifyCaseOutcomes(['deferred']).appealEligible, isFalse);
  });
}
