import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'billing_config.dart';

class BillingFailure implements Exception {
  const BillingFailure(this.message);

  final String message;
}

class BillingRepository {
  BillingRepository(this._functions, this._auth, {BillingConfig? config})
      : _config = config ?? resolveBillingConfig();

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final BillingConfig _config;

  static const caseUnlockProduct = 'claim_package_unlock';

  /// Records a pending Case-unlock purchase for [caseId]. The webhook binds the
  /// next Case-unlock transaction to it. Must be called before a Case unlock is
  /// bought so the right case is unlocked.
  Future<String> createPurchaseIntent(String caseId) async {
    await _auth.currentUser?.getIdToken(true);
    try {
      final result = await _functions
          .httpsCallable('createPurchaseIntent')
          .call({'product': caseUnlockProduct, 'caseId': caseId});
      final data = result.data;
      if (data is Map && data['intentId'] is String) {
        return data['intentId'] as String;
      }
      throw const BillingFailure('That purchase could not be started. Try again.');
    } on FirebaseFunctionsException catch (error) {
      throw BillingFailure(
        error.message ?? 'That purchase could not be started. Try again.',
      );
    }
  }

  bool get hasWebPurchaseLink => _config.hasWebPurchaseLink;

  bool get hasCustomerPortal => _config.hasCustomerPortal;

  /// The hosted purchase link with the Firebase UID appended as the RevenueCat
  /// app user id, so a web purchase lands on the same account.
  Uri? webPurchaseUri() =>
      buildWebPurchaseUri(_config.webPurchaseLink, _auth.currentUser?.uid);

  Uri? customerPortalUri() {
    final url = _config.customerPortalUrl;
    if (url == null || url.isEmpty) return null;
    return Uri.parse(url);
  }
}

/// Builds a RevenueCat Web Purchase Link for [uid].
///
/// RevenueCat requires the App User ID as a **URL path segment**
/// (`https://pay.rev.cat/<token>/<uid>`), not a query parameter; without it the
/// hosted link returns a 404. [Uri.replace] URL-encodes each segment.
Uri? buildWebPurchaseUri(String? link, String? uid) {
  if (link == null || link.isEmpty) return null;
  final base = Uri.parse(link);
  if (uid == null || uid.isEmpty) return base;
  final segments = [
    ...base.pathSegments.where((segment) => segment.isNotEmpty),
    uid,
  ];
  return base.replace(pathSegments: segments);
}

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(
    FirebaseFunctions.instanceFor(region: 'us-central1'),
    FirebaseAuth.instance,
  );
});
