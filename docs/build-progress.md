# Build progress

**Spec:** `Veteran_Claims_Buddy_Engineering_Handoff.md`  
**Routes:** `docs/page-navigation.md` wins if a screen or route disagrees with the handoff.  
**Updated:** 2026-09-29

This file is the implementation checklist. The handoff stays the spec. Update this file in the same change that finishes, blocks, or expands a step. Do not mark a phase complete while any item in it is open. Stop at owner gates.

Status values: `done`, `in progress`, `blocked`, `not started`.

Do not start a later build-sequence step until its checklist has been expanded in this file from the handoff.

## Current position

**Phase 2 is done.** Project ids are `veteran-claims-buddy-dev` and `veteran-claims-buddy-prod`. Both are on Blaze with budget alerts.

Firestore is `nam5` in both projects. Storage is `us-central1` in both projects. FlutterFire options files exist for dev and prod.

**Next owner gate is 4C, `firebase init`.** Functions in that init use `us-central1`, not `nam5`.

## Phase 2 — what the owner does next

Done on 2026-09-29. Ids are in `docs/environment-values.md`.

## Decisions already made

- Flutter is FVM **3.47.5** (Dart 3.13.4). There is no `flutter` binary on PATH. Run `fvm flutter` from `/app`.
- The FVM cache entry named `stable` is Flutter 3.0.5 and does not run on this Mac.
- This Mac is Intel. Flutter 3.47.5 printed a deprecation warning that a future Flutter release will require Apple Silicon. Not a blocker for 3.47.5.
- Dart package name is `app`, because `fvm flutter create ... app` names the package after the directory. The handoff's `veteran_claims_buddy` package name was not passed to create. Keep `app` unless the owner wants a rename.
- Application ids: prod `com.veteranclaimsbuddy.app`, dev `com.veteranclaimsbuddy.app.dev`.
- `default-flavor` is `dev`, so local `fvm flutter run` and `fvm flutter test` use dev when no flavor is passed.
- `flutter_adaptive_scaffold` 0.3.3+1 is discontinued upstream. Kept for now because the handoff requires it.
- Do not commit `.fvm/flutter_sdk`. It is a machine-local symlink. Commit `fvm_config.json` only. The root symlink was removed from the git index on 2026-09-29 and still needs a commit.
- Node on this machine is v24.14.0. Cloud Functions still pin Node 22 when they are initialized.
- Firebase CLI is 15.10.1. `firebase login` is still an owner gate.
- Run FlutterFire with `fvm dart pub global run flutterfire_cli:flutterfire`. The shim on PATH was built for Homebrew Dart 2.18.4. Installed CLI is 1.4.1.
- Firestore is multi-region `nam5` in both projects. Standard edition, Native mode.
- Storage is `us-central1` in both projects. No public read.
- Cloud Functions use `us-central1`. They cannot be deployed to `nam5`. That region is inside the Firestore multi-region and matches Storage.

## Log

| Date | What changed |
| --- | --- |
| 2026-09-29 | Tracker created. Flutter app exists at `/app` from `fvm flutter create` (commit `e7f419b`). Phase 1 packages and flavors started. |
| 2026-09-29 | Phase 1 packages added. Dev and prod flavors configured. `fvm flutter analyze` and `fvm flutter test` passed. `fvm flutter build apk --flavor dev` produced `app-dev-release.apk`. |
| 2026-09-29 | Owner created `veteran-claims-buddy-dev` and `veteran-claims-buddy-prod`, upgraded both to Blaze, and set budget alerts. |
| 2026-09-29 | Firestore location is `nam5`. Storage and Cloud Functions stay `us-central1`. |

## Phase 0 — Owner workstation

- [x] **0A Install/verify Flutter.** FVM 3.47.5. `fvm flutter doctor` on 2026-09-29: Xcode and Chrome are healthy. Remaining warnings: Intel Mac deprecation, Homebrew Dart 2.18.4 is ahead of the Flutter SDK on PATH, and some Android licenses are not accepted. The dev APK still built. From `/app`, the owner can clear the license warning with `fvm flutter doctor --android-licenses`.
- [x] **0B Install Node.js.** `node` v24.14.0.
- [x] **0C Install Firebase CLI.** `firebase` 15.10.1.
- [x] **0D Install FlutterFire CLI.** `flutterfire_cli` 1.4.1, activated with `fvm dart`. Invoke it through `fvm dart pub global run flutterfire_cli:flutterfire`, not the old PATH shim.
- [x] **0E Choose identifiers.** Confirmed by the create command. See decisions above.

## Phase 1 — Scaffold the Flutter repository

- [x] **1A Create the Flutter app.** Owner ran `fvm flutter create --org com.veteranclaimsbuddy --platforms=android,ios,web app`.
- [x] **1B Add baseline packages.** Added with `fvm flutter pub add` and no version pins. `flutter_adaptive_scaffold` 0.3.3+1 is marked discontinued on pub.dev. It stays because the handoff names it.
- [x] **1C Configure flavors.** Android product flavors `dev` and `prod`. iOS shared schemes `dev` and `prod` with `Debug-*`, `Release-*`, and `Profile-*` configurations. Dev application id `com.veteranclaimsbuddy.app.dev`. Prod application id `com.veteranclaimsbuddy.app`. Dev display name includes `Dev`.
- [x] **Definition of done.** `fvm flutter analyze` reported no issues. `fvm flutter test` passed. `fvm flutter build apk --flavor dev` built `app/build/app/outputs/flutter-apk/app-dev-release.apk`. A windowed `fvm flutter run --flavor dev` was not launched in that session.

Known build warning, not a failure: Firebase Android plugins still apply the Kotlin Gradle Plugin. A future Flutter release may reject that until those plugins migrate. The dev APK built with the warning.

## Phase 2 — Create Firebase projects

- [x] **2A** Development project `veteran-claims-buddy-dev`. Id recorded in `docs/environment-values.md`.
- [x] **2B** Development project upgraded to Blaze.
- [x] **2C** Development billing budget alerts confirmed by the owner.
- [x] **2D** Production project `veteran-claims-buddy-prod`. No real users seeded.
- [x] **2E** Production project upgraded to Blaze with its own budget alerts.

## Phase 3 — Connect Flutter to Firebase

- [x] **3A** Dev FlutterFire config written: `app/lib/firebase_options_dev.dart`, `app/android/app/src/dev/google-services.json`, `app/ios/config/dev/GoogleService-Info.plist`. iOS build configuration `Debug-dev`.
- [x] **3B** Prod FlutterFire config written: `app/lib/firebase_options_prod.dart`, `app/android/app/src/prod/google-services.json`, `app/ios/config/prod/GoogleService-Info.plist`. iOS build configuration `Debug-prod`.
- [ ] **3C** Bootstrap Firebase by flavor. A production binary must not be able to point at dev.
- [ ] **3D** Dev-only environment banner.
- [ ] **Definition of done.** Dev app connects to the dev project and prod app connects to the prod project. Temporary diagnostic screen shows project id, flavor, and application id.

## Phase 4 — Initialize Firebase backend resources

- [x] **4A** Firestore is Standard edition, Native mode, location `nam5`, in dev and prod.
- [x] **4B** Storage is `us-central1` in dev and prod. No public read.
- [ ] **4C** Owner runs `firebase init` for Firestore, JavaScript Functions, and Storage. Node 22, 2nd-gen Functions. Do not hand-write that skeleton. Functions region in that init is `us-central1`, not `nam5`.
- [ ] **4D** Set `PRIMARY_REGION` to `us-central1`. Same source deploys to dev and prod. Secrets stay per project.

Hosting targets (`marketing` and `app`) are initialized after the Firebase projects exist. Custom domain connection is a separate owner gate and does not block claim-domain work.

## Phase 5 — Authentication and required SMS MFA

- [ ] **5A** Upgrade DEV Authentication to Identity Platform.
- [ ] **5B** Upgrade PROD Authentication to Identity Platform.
- [ ] **5C** Enable email/password in DEV and PROD.
- [ ] **5D** Enable SMS multi-factor authentication.
- [ ] **5E** Configure DEV fictional/test phone numbers.
- [ ] **5F** Configure SMS region policy.
- [ ] **5G** Email/password flow and verified email.
- [ ] **5H** Prepare Android fingerprint values, then stop.
- [ ] **5H.1** Owner registers the Android DEV fingerprint.
- [ ] **5I** Prepare iOS phone-verification capabilities, then stop.
- [ ] **5I.1** Owner configures Apple APNs authentication for DEV Firebase.
- [ ] **5J** Owner configures a DEV web domain for SMS MFA testing.
- [ ] **5K** Mandatory SMS MFA enrollment.
- [ ] **5L** MFA challenge during sign-in.
- [ ] **5M** Centralized authentication/access state machine. Shell routes stay closed until email is verified and SMS MFA is enrolled.
- [ ] **5N** Server-authoritative MFA enrollment marker.
- [ ] **5O** Firestore and Storage gating before sensitive onboarding data.
- [ ] **5P** MFA recovery and factor-management UX. Lost phone goes to support contact. No self-serve bypass.
- [ ] **5Q** Owner DEV end-to-end auth acceptance test.
- [ ] **Definition of done — Phase 5.** Not complete until 5Q passes.

Production Android fingerprints, production APNs, and the production auth release gate stay closed until a production release is actually being prepared.

## Phase 6 — App Check

Checklist not expanded beyond the handoff rollout. Do not start until Phase 5 is done.

- [ ] Integrate the App Check SDK.
- [ ] Register apps and providers in the Firebase console.
- [ ] Dev uses debug tokens. Production builds do not use debug providers.
- [ ] Enforcement stays off until valid client traffic is confirmed.

## Later build sequence

These follow handoff section 6. Expand each one into concrete tasks in this file before writing that code.

- [ ] **6. Application shell and navigation.** From `docs/page-navigation.md`, not from the handoff feature-folder list.
- [ ] **7. Firestore domain model and repositories.**
- [ ] **8. Dev reset and seed tooling.** Reset must refuse to run against production.
- [ ] **9. Veteran onboarding and service history.**
- [ ] **10. Universal condition discovery and questionnaires.**
- [ ] **11. Claim Issue model and evidence matrices.**
- [ ] **12. File and document management.**
- [ ] **13. Document AI extraction and provenance.**
- [ ] **14. Assistant and agent tool framework.** Vet Buddy reads stored case state. It does not own it.
- [ ] **15. Deterministic next-action and workflow engine.**
- [ ] **16. C&P exam workflows.** Manual in MVP, with a 2-hour push reminder.
- [ ] **17. Decision-letter analysis.**
- [ ] **18. Decision-review workflows.**
- [ ] **19. VA knowledge synchronization.**
- [ ] **20. VA API integrations.** Not an MVP dependency. Self-submission guidance only for MVP.
- [ ] **21. Notifications.**
- [ ] **22. Security hardening and data lifecycle.** Includes the 30-day account deletion grace period.
- [ ] **23. CI/CD, release, TestFlight, and Play testing.**
- [ ] **24. Production launch readiness.**

## Parallel tracks that are not the critical path

- [ ] **Brand package.** `/brand` with logo, mark, wordmark, and tokens. Does not block Phase 1. Do it before polishing the marketing site.
- [ ] **Marketing site.** Static HTML in `/marketing-site` after the brand package. Legal drafts already live in `docs/legal/`.
- [ ] **Domain connection.** Owner gate. Connect `veteranclaimsbuddy.com`, `www`, and `app.veteranclaimsbuddy.com` only when the owner is ready to expose production. The agent reads the DNS records Firebase shows at that time and does not invent them.
- [ ] **AGENTS.md.** Short summary of handoff sections 1–4 and 2A, plus a pointer at this file and `docs/page-navigation.md`.

## Commerce and Print & Mail

Blocked until the matching owner gate is done. Do not add `purchases_flutter` or `flutter_stripe` before then.

- [ ] **38A** Apple developer commerce setup.
- [ ] **38B** Google Play commerce setup.
- [ ] **38C** RevenueCat setup.
- [ ] **38D** Stripe setup.
- [ ] **38E** Print/mail provider setup.
- [ ] Entitlements, `/plans`, and Print & Mail implementation. Expand from handoff section 38 before coding. `/plans` stays the only Premium versus per-Case sales page.

## Explicitly out of the current MVP

- Direct VA filing API.
- Firebase emulators.
- PostgreSQL, Data Connect, Supabase, or a second database.
- Spouse, caregiver, or delegate access.
- A second paywall screen.
