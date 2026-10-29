import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import 'billing_config.dart';

/// Wraps the RevenueCat SDK with web-safe guards.
///
/// The SDK's paywalls and store purchases run only on iOS and Android. Web uses
/// a hosted Web Purchase Link instead (see [PlansScreen]), so every method here
/// is a no-op on web. This file deliberately avoids `dart:io`; it uses
/// [kIsWeb] and [defaultTargetPlatform] so it still compiles for web.
class RevenueCatService {
  bool _configured = false;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  bool get isConfigured => _configured;

  String? get _apiKey => resolveBillingConfig().revenueCatApiKey;

  /// Configures the SDK once, then signs the Veteran in so the RevenueCat app
  /// user id equals the Firebase UID. Safe to call on every auth change.
  Future<void> configureAndLogIn(String uid) async {
    if (!isSupported) return;
    final key = _apiKey;
    if (key == null) return; // Keys arrive via --dart-define; skip until then.
    try {
      if (!_configured) {
        await Purchases.setLogLevel(LogLevel.debug);
        await Purchases.configure(
          PurchasesConfiguration(key)..appUserID = uid,
        );
        _configured = true;
      } else {
        await Purchases.logIn(uid);
      }
    } catch (_) {
      // A missing key or an unsupported build should never crash the app.
    }
  }

  Future<void> logOut() async {
    if (!isSupported || !_configured) return;
    try {
      await Purchases.logOut();
    } catch (_) {
      // logOut throws for an anonymous user; ignore.
    }
  }

  /// Presents the dashboard paywall for the current offering. Returns null on
  /// web or when the SDK is not configured.
  Future<PaywallResult?> presentPaywall() async {
    if (!isSupported || !_configured) return null;
    try {
      return await RevenueCatUI.presentPaywall(displayCloseButton: true);
    } catch (_) {
      return null;
    }
  }

  Future<void> restorePurchases() async {
    if (!isSupported || !_configured) return;
    try {
      await Purchases.restorePurchases();
    } catch (_) {
      // Nothing to restore, or an unsupported build.
    }
  }
}

final revenueCatServiceProvider = Provider<RevenueCatService>(
  (ref) => RevenueCatService(),
);
