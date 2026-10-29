import 'package:app/billing/entitlement_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an active subscription projection is read as premium', () {
    final until = DateTime.now().add(const Duration(days: 30));
    final status = PremiumStatus.fromData({
      'isActive': true,
      'source': 'subscription',
      'premiumUntil': Timestamp.fromDate(until),
      'willRenew': true,
      'activeCaseLimit': null,
    });
    expect(status.isActive, isTrue);
    expect(status.subscriptionActive, isTrue);
    expect(status.fromCaseUnlock, isFalse);
  });

  test('a case-unlock projection carries the single-case limit', () {
    final until = DateTime.now().add(const Duration(days: 300));
    final status = PremiumStatus.fromData({
      'isActive': true,
      'source': 'caseUnlock',
      'premiumUntil': Timestamp.fromDate(until),
      'willRenew': false,
      'activeCaseLimit': 1,
    });
    expect(status.fromCaseUnlock, isTrue);
    expect(status.subscriptionActive, isFalse);
    expect(status.activeCaseLimit, 1);
  });

  test('an expired or missing projection is inactive', () {
    final past = DateTime.now().subtract(const Duration(days: 1));
    final expired = PremiumStatus.fromData({
      'isActive': true,
      'source': 'caseUnlock',
      'premiumUntil': Timestamp.fromDate(past),
    });
    expect(expired.isActive, isFalse);
    expect(PremiumStatus.fromData(null).isActive, isFalse);
  });

  test('an expired subscription is retained for the expired UI', () {
    final past = DateTime.now().subtract(const Duration(days: 2));
    final status = PremiumStatus.fromData({
      'isActive': false,
      'source': 'subscription',
      'premiumUntil': Timestamp.fromDate(past),
      'willRenew': false,
    });
    expect(status.isActive, isFalse);
    expect(status.expired, isTrue);
    expect(status.expiredSubscription, isTrue);
    expect(status.premiumUntil, isNotNull);
  });

  test('a never-subscribed account is not treated as expired', () {
    expect(PremiumStatus.inactive.expired, isFalse);
    expect(PremiumStatus.fromData(null).expired, isFalse);
  });
}
