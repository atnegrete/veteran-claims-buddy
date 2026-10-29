import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// The server-authoritative Premium projection the client reads.
///
/// `users/{uid}/billing/premium` is written only by the RevenueCat webhook, so
/// gating is identical on web, iOS, and Android. The RevenueCat SDK's own
/// entitlement check only reflects subscriptions; a Case unlock grants Premium
/// through the webhook, so this projection (not the SDK) is the source of truth.
class PremiumStatus {
  const PremiumStatus({
    required this.isActive,
    required this.source,
    required this.premiumUntil,
    required this.willRenew,
    required this.activeCaseLimit,
  });

  /// `'subscription'`, `'caseUnlock'`, or null when Premium is inactive.
  final String? source;
  final bool isActive;
  final DateTime? premiumUntil;
  final bool willRenew;

  /// Non-null (1) when Premium is sourced only from a Case unlock, which caps
  /// the Veteran at one active case at a time. Null under a subscription.
  final int? activeCaseLimit;

  static const inactive = PremiumStatus(
    isActive: false,
    source: null,
    premiumUntil: null,
    willRenew: false,
    activeCaseLimit: null,
  );

  bool get subscriptionActive => isActive && source == 'subscription';

  bool get fromCaseUnlock => isActive && source == 'caseUnlock';

  /// The account held Premium before (subscription or Case unlock) and it has
  /// lapsed. Used to show a friendly "expired" state with a Renew path, as
  /// opposed to a Veteran who never purchased ([premiumUntil] is null).
  bool get expired => !isActive && premiumUntil != null;

  /// Whether the lapsed Premium came from a subscription (vs a Case unlock).
  bool get expiredSubscription => expired && source == 'subscription';

  factory PremiumStatus.fromData(Map<String, dynamic>? data) {
    if (data == null) return PremiumStatus.inactive;
    final until = data['premiumUntil'];
    final untilDate = until is Timestamp ? until.toDate() : null;
    final active =
        data['isActive'] == true &&
        untilDate != null &&
        untilDate.isAfter(DateTime.now());
    final limit = data['activeCaseLimit'];
    // Retain the end date and source even when inactive, so the UI can tell an
    // expired account from one that never subscribed.
    return PremiumStatus(
      isActive: active,
      source: data['source'] as String?,
      premiumUntil: untilDate,
      willRenew: active && data['willRenew'] == true,
      activeCaseLimit: active && limit is int ? limit : null,
    );
  }
}

/// Keeps a StreamProvider in the loading state until auth finishes restoring.
///
/// Right after a web reload the auth session rehydrates asynchronously. During
/// that window `session` is null even though the Veteran is signed in, so we
/// must not report a signed-out/inactive value. A never-emitting stream holds
/// the provider at `AsyncLoading`; once `ready` flips the provider rebuilds
/// (via `ref.watch`) and attaches the real stream.
Stream<T> _pendingWhileAuthRestores<T>(Ref ref) {
  final controller = StreamController<T>();
  ref.onDispose(controller.close);
  return controller.stream;
}

/// Streams the Premium projection for the signed-in Veteran.
///
/// Resolves to [AsyncLoading] while auth is restoring and until the first
/// Firestore snapshot arrives, so callers can show a loading state instead of
/// assuming Premium is inactive.
final premiumStatusProvider = StreamProvider<PremiumStatus>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (!auth.ready) return _pendingWhileAuthRestores<PremiumStatus>(ref);
  final uid = auth.session?.uid;
  if (uid == null) return Stream.value(PremiumStatus.inactive);
  return FirebaseFirestore.instance
      .doc('users/$uid/billing/premium')
      .snapshots()
      .map((snapshot) => PremiumStatus.fromData(snapshot.data()));
});

/// The set of case ids whose Case unlock is still within its one-year window.
final caseUnlocksProvider = StreamProvider<Set<String>>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (!auth.ready) return _pendingWhileAuthRestores<Set<String>>(ref);
  final uid = auth.session?.uid;
  if (uid == null) return Stream.value(const <String>{});
  return FirebaseFirestore.instance
      .collection('users/$uid/caseUnlocks')
      .snapshots()
      .map((snapshot) {
        final now = DateTime.now();
        final unlocked = <String>{};
        for (final doc in snapshot.docs) {
          final until = doc.data()['grantsPremiumUntil'];
          if (until is Timestamp && until.toDate().isAfter(now)) {
            unlocked.add(doc.id);
          }
        }
        return unlocked;
      });
});

/// Whether Premium features (Symptom Tracker, etc.) are on for the account.
///
/// Any active source (subscription or an unexpired Case unlock) turns Premium
/// features on. This collapses the loading state to `false` for pure logic
/// (e.g. the home snapshot); UIs that should not flash the inactive view while
/// the status loads should watch [premiumStatusProvider] (or use
/// `PremiumStatusBuilder`) and handle loading explicitly.
final premiumActiveProvider = Provider<bool>((ref) {
  return ref
      .watch(premiumStatusProvider)
      .maybeWhen(data: (status) => status.isActive, orElse: () => false);
});

/// Whether a claim package may be generated for [caseId].
///
/// A subscription covers every case. A Case unlock covers only the case it was
/// bound to.
final canGeneratePackageProvider = Provider.family<bool, String>((ref, caseId) {
  final status = ref
      .watch(premiumStatusProvider)
      .maybeWhen(data: (value) => value, orElse: () => PremiumStatus.inactive);
  if (status.subscriptionActive) return true;
  final unlocked = ref
      .watch(caseUnlocksProvider)
      .maybeWhen(data: (value) => value, orElse: () => const <String>{});
  return unlocked.contains(caseId);
});
