import 'package:flutter/foundation.dart';

import '../app/app_environment.dart';

/// Public RevenueCat configuration, chosen at runtime by environment and
/// platform.
///
/// Every value here is a **public** RevenueCat value — a publishable SDK key or
/// a hosted URL — so it is safe to ship in the client and to commit. Secrets
/// never live here: the webhook Authorization secret stays in Google Secret
/// Manager, and Stripe secret keys never reach the app.
///
/// Values may be filled in two ways, with the `--dart-define` winning when it
/// is set, so a build can still override a committed value without editing
/// source:
///
/// 1. the constants below (committed, the normal path), or
/// 2. `--dart-define=RC_IOS_KEY=... RC_ANDROID_KEY=... RC_WEB_PURCHASE_LINK=...
///    RC_CUSTOMER_PORTAL_URL=...`.
///
/// The dev entries use the RevenueCat sandbox / Test Store. A `test_...` key
/// **crashes release builds**, so it is only ever returned for the dev
/// environment; a prod (release) build reads the `_prod` entries and asserts
/// the key is not a `test_...` key.
class BillingConfig {
  const BillingConfig({
    this.revenueCatApiKey,
    this.webPurchaseLink,
    this.customerPortalUrl,
  });

  /// The platform's public SDK key (`appl_` on iOS, `goog_` on Android), or
  /// null on web and until a key is configured. Web checkout uses
  /// [webPurchaseLink] instead of the SDK.
  final String? revenueCatApiKey;

  /// Hosted Web Purchase Link for the offering, used for web checkout.
  final String? webPurchaseLink;

  /// A **static** subscription-management URL, used only by billing engines
  /// that expose one (e.g. a Stripe Customer Portal when using Stripe Billing,
  /// or a custom page). This is NOT set for **RevenueCat Billing**, whose portal
  /// is per-subscription and tokenized
  /// (`https://billing.revenuecat.com/{app_id}/{sub_id}?token=...`) and is
  /// delivered to the customer by email or minted on demand via the REST v2
  /// endpoint `authenticated_management_url`. On RevenueCat Billing this stays
  /// null and the "Manage subscription" button falls back to guidance.
  final String? customerPortalUrl;

  bool get hasApiKey => (revenueCatApiKey ?? '').isNotEmpty;
  bool get hasWebPurchaseLink => (webPurchaseLink ?? '').isNotEmpty;
  bool get hasCustomerPortal => (customerPortalUrl ?? '').isNotEmpty;
}

// ===========================================================================
// Fill these from the RevenueCat dashboard. Every value is public and safe to
// commit. Leave an entry empty until you have it.
// ===========================================================================

// Production public SDK keys (Project settings -> API keys).
const String _iosKeyProd = 'appl_RpVFvyJeRDWuoLGWoeWjzFEEXfh';
const String _androidKeyProd = '';

// Development keys (RevenueCat sandbox / Test Store). A `test_...` key must
// never ship in a release build, so it is only returned for the dev environment
// in a non-release build (see [_resolveApiKey]). The Test Store simulates
// purchases in debug on iOS/Android; it does nothing on web.
const String _iosKeyDev = 'test_UDnJyBiUYiaFraUDNTkLFajPsIg';
const String _androidKeyDev = 'test_UDnJyBiUYiaFraUDNTkLFajPsIg';

// Hosted Web Purchase Link for the offering (Funnels -> Purchase Links). The
// same link serves the whole offering; the app appends the App User ID as a
// path segment at runtime.
const String _webPurchaseLinkProd = '';
const String _webPurchaseLinkDev =
    'https://pay.rev.cat/sandbox/mjuzsqkihjadyxzl/';

// Static subscription-management URL. Leave EMPTY on RevenueCat Billing: its
// portal is per-subscription and tokenized, not a fixed URL (see
// [BillingConfig.customerPortalUrl]). Only set these if you move to Stripe
// Billing (your Stripe Customer Portal URL) or host your own management page.
const String _customerPortalUrlProd = '';
const String _customerPortalUrlDev = '';

// Optional `--dart-define` overrides. When set they win over the constants.
const String _iosKeyDefine = String.fromEnvironment('RC_IOS_KEY');
const String _androidKeyDefine = String.fromEnvironment('RC_ANDROID_KEY');
const String _webPurchaseLinkDefine = String.fromEnvironment(
  'RC_WEB_PURCHASE_LINK',
);
const String _customerPortalDefine = String.fromEnvironment(
  'RC_CUSTOMER_PORTAL_URL',
);

/// Resolves the public billing configuration for the current build.
///
/// The parameters exist for tests; production reads [currentEnvironment],
/// [kIsWeb], and [defaultTargetPlatform].
BillingConfig resolveBillingConfig({
  AppEnvironment? environment,
  bool? isWeb,
  TargetPlatform? platform,
}) {
  final prod = (environment ?? currentEnvironment) == AppEnvironment.prod;
  final web = isWeb ?? kIsWeb;
  final target = platform ?? defaultTargetPlatform;

  return BillingConfig(
    revenueCatApiKey: _resolveApiKey(prod: prod, web: web, target: target),
    webPurchaseLink: _firstNonEmpty(
      _webPurchaseLinkDefine,
      prod ? _webPurchaseLinkProd : _webPurchaseLinkDev,
    ),
    customerPortalUrl: _firstNonEmpty(
      _customerPortalDefine,
      prod ? _customerPortalUrlProd : _customerPortalUrlDev,
    ),
  );
}

String? _resolveApiKey({
  required bool prod,
  required bool web,
  required TargetPlatform target,
}) {
  // Flutter web does not use the SDK key; it uses the Web Purchase Link.
  if (web) return null;

  String? key;
  switch (target) {
    case TargetPlatform.iOS:
      key = _firstNonEmpty(_iosKeyDefine, prod ? _iosKeyProd : _iosKeyDev);
      break;
    case TargetPlatform.android:
      key = _firstNonEmpty(
        _androidKeyDefine,
        prod ? _androidKeyProd : _androidKeyDev,
      );
      break;
    default:
      key = null;
  }

  final isTestKey = key?.startsWith('test_') ?? false;
  // A Test Store key crashes release builds and must never be used in prod.
  assert(
    !(prod && isTestKey),
    'A RevenueCat test_ key must not be used in the prod environment.',
  );
  // Never hand a test_ key to a release build, even a dev-flavored one.
  if (kReleaseMode && isTestKey) return null;
  return key;
}

String? _firstNonEmpty(String primary, String fallback) {
  if (primary.isNotEmpty) return primary;
  if (fallback.isNotEmpty) return fallback;
  return null;
}
