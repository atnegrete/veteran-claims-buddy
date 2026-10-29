import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/app_environment.dart';
import 'package:app/billing/billing_config.dart';

void main() {
  test('web never resolves an SDK API key', () {
    final config = resolveBillingConfig(
      environment: AppEnvironment.prod,
      isWeb: true,
      platform: TargetPlatform.iOS,
    );
    expect(config.revenueCatApiKey, isNull);
  });

  test('prod never resolves a test_ key and does not trip the guard', () {
    // Prod may have a real appl_/goog_ key or none yet, but it must never
    // resolve a `test_` key (which would crash a release build).
    for (final target in [TargetPlatform.iOS, TargetPlatform.android]) {
      final config = resolveBillingConfig(
        environment: AppEnvironment.prod,
        isWeb: false,
        platform: target,
      );
      final key = config.revenueCatApiKey;
      expect(key == null || !key.startsWith('test_'), isTrue);
    }
  });

  test('dev resolves the Test Store key on mobile in debug/test', () {
    // Tests run in a non-release VM, so the dev test_ key is returned.
    for (final target in [TargetPlatform.iOS, TargetPlatform.android]) {
      final config = resolveBillingConfig(
        environment: AppEnvironment.dev,
        isWeb: false,
        platform: target,
      );
      expect(config.revenueCatApiKey, startsWith('test_'));
    }
  });

  test('BillingConfig getters reflect emptiness', () {
    const empty = BillingConfig();
    expect(empty.hasApiKey, isFalse);
    expect(empty.hasWebPurchaseLink, isFalse);
    expect(empty.hasCustomerPortal, isFalse);

    const filled = BillingConfig(
      revenueCatApiKey: 'appl_abc',
      webPurchaseLink: 'https://pay.rev.cat/x',
      customerPortalUrl: 'https://rev.cat/portal',
    );
    expect(filled.hasApiKey, isTrue);
    expect(filled.hasWebPurchaseLink, isTrue);
    expect(filled.hasCustomerPortal, isTrue);
  });
}
