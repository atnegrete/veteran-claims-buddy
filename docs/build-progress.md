# Build progress

**Spec:** `Veteran_Claims_Buddy_Engineering_Handoff.md`  
**Routes:** `docs/page-navigation.md` wins if a screen or route disagrees with the handoff.  
**Updated:** 2026-09-30

This file is the implementation checklist. The handoff stays the spec. Update this file in the same change that finishes, blocks, or expands a step. Do not mark a phase complete while any item in it is open. Stop at owner gates.

Status values: `done`, `in progress`, `blocked`, `not started`.

Do not start a later build-sequence step until its checklist has been expanded in this file from the handoff.

## Current position

**Phase 2 is done.** Project ids are `veteran-claims-buddy-dev` and `veteran-claims-buddy-prod`. Both are on Blaze with budget alerts.

Firestore is `nam5` in both projects. Storage is `us-central1` in both projects. FlutterFire options files exist for dev and prod.

**Gate 4C is done.** One Firebase config serves both projects. Aliases are `dev` and `prod` in `.firebaserc`. There is no second `firebase init` for prod.

**Phase 3 is done.** Owner confirmed both flavor runs on 2026-09-29. The orange DEV banner was removed on 2026-09-30. Debug runs use Flutter's Debug ribbon.

The iOS `GoogleService-Info.plist` files are copied into the app bundle for `Debug`, `Release`, and `Profile` of each flavor. Unflavored iOS configurations do not get a plist.

**Gates 5A–5H.1 are done.** The development Android app has the debug SHA-256. Release builds still share that debug keystore until a real upload key exists.

**iOS phone verification is prepared in the Xcode project.** Push Notifications is on. Background mode includes remote notifications. Debug and Profile use the development push environment. Release uses production. Each flavor build copies its own `GoogleService-Info.plist` into the app.

**Gate 5I.1 is done.** The same APNs `.p8` is uploaded to both the development and production slots on `veteran-claims-buddy-dev`, for `com.veteranclaimsbuddy.app.dev`. The `.p8` stays out of the repo.

**Production APNs stays closed** until a production release. At that time the same file is uploaded to both slots on `veteran-claims-buddy-prod`, for `com.veteranclaimsbuddy.app`.

**SMS enrollment and the sign-in code step are in the app.** A verified account enters a phone number, agrees to the sign-in check, and confirms the 6-digit code. A later sign-in with an enrolled phone stops on `/mfa/challenge` and can choose among enrolled phone factors. The screen shows a masked label, not the raw number. The website uses the same enrollment screen. The dev flavor skips the live reCAPTCHA and accepts only a fictional number from the DEV console. Production keeps the live check. The server-side enrollment marker is still gate 5N, so no claim data is stored from this step.

**Auth gates share one frame.** `AuthScaffold` centers a 400-point column on phone and wide web. Color, inputs, and buttons come from `appTheme()`. The logo and a short description in the wide-web side space wait for the brand package. The signed-in shell still waits for build step 6.

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
| 2026-09-29 | Owner ran `firebase init` for Firestore, Functions, and Storage against dev. Prod is an alias of the same config, not a second init. Functions runtime pinned to Node 22 in `us-central1`. |
| 2026-09-29 | Phase 3 bootstrap and DEV banner landed. Owner confirmed both flavor diagnostics. Next gate is Identity Platform in dev and prod. |
| 2026-09-29 | Owner enabled Identity Platform in dev and prod. Next gates are email/password, SMS MFA, dev test numbers, and SMS region policy. |
| 2026-09-29 | Owner enabled email/password and SMS MFA in both projects, added dev test numbers, and set the SMS region policy. Email/password gates are in the app. Next owner step is the dev Android SHA fingerprint. |
| 2026-09-29 | Owner registered the dev Android SHA-256. iOS push and remote-notification background mode are in the Xcode project. Next owner step is the dev APNs key. |
| 2026-09-29 | Owner uploaded the APNs key to both slots on the dev Firebase project. Production Firebase APNs stays closed until a production release. |
| 2026-09-29 | App enrolls an SMS second factor and challenges it on the next sign-in. Web SMS and the server enrollment marker are still open. |
| 2026-09-30 | Dev flavor skips the live reCAPTCHA for fictional numbers only. DEV SMS allowlist already includes the United States. The saved test number's area code is not a real U.S. area code, so send-code still fails until that number is replaced. |
| 2026-09-30 | Auth gates use one centered frame and the shared dark theme. The signed-in shell is still build step 6. |
| 2026-09-30 | Orange DEV banner removed. Debug runs keep Flutter's Debug ribbon. |
| 2026-09-30 | Brand package now includes the wide auth layout: logo and a short app description beside the form. Phone stays one column. Not started. |

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
- [x] **3C** Bootstrap Firebase by flavor in `app/lib/app/app_bootstrap.dart`. Dev loads only the dev options. Prod loads only the prod options. A release build with no flavor fails.
- [x] **3D** Dev-only DEV banner confirmed the flavor diagnostic on 2026-09-29. Removed 2026-09-30. Debug runs already show Flutter's Debug ribbon.
- [x] **Definition of done.** Owner confirmed `--flavor dev` and `--flavor prod` on 2026-09-29. Each screen showed the matching project id, flavor, and application id.

## Phase 4 — Initialize Firebase backend resources

- [x] **4A** Firestore is Standard edition, Native mode, location `nam5`, in dev and prod.
- [x] **4B** Storage is `us-central1` in dev and prod. No public read.
- [x] **4C** Owner ran `firebase init` for Firestore, JavaScript Functions, and Storage against `veteran-claims-buddy-dev`. Rules files are locked (`if false`).
- [x] **4D** `functions/region.js` sets `PRIMARY_REGION` to `us-central1`. `functions/package.json` engines is Node 22. `.firebaserc` aliases: `default` and `dev` are the dev project, `prod` is `veteran-claims-buddy-prod`. Same source deploys to both. Secrets stay per project.

Hosting targets (`marketing` and `app`) are initialized after the Firebase projects exist. Custom domain connection is a separate owner gate and does not block claim-domain work.

## Phase 5 — Authentication and required SMS MFA

- [x] **5A** DEV Authentication upgraded to Identity Platform. Confirmed 2026-09-29.
- [x] **5B** PROD Authentication upgraded to Identity Platform. Confirmed 2026-09-29. No production test users.
- [x] **5C** Email/Password enabled in DEV and PROD. Confirmed 2026-09-29. Anonymous auth and phone-as-primary stay off.
- [x] **5D** SMS multi-factor authentication enabled in DEV and PROD. Confirmed 2026-09-29. The console still asks for platform setup; that is 5H, 5I, and 5J.
- [x] **5E** DEV fictional test phone numbers configured. Values stay in the owner's password manager, not in the repo. The saved number uses area code 123, which is not a real U.S. area code, so the SMS region check rejects it. Replace it with a real area code and a 555 exchange, such as `+1 650-555-3434`.
- [x] **5F** SMS region policy reviewed in DEV and PROD. U.S. numbers are allowed.
- [x] **5G** Email/password create, sign-in, forgot password, reset-password handler, verify-email, and sign-out. Unverified users cannot leave `/verify-email`. Verified users without a factor land on `/mfa/enroll`, which does not send SMS yet.
- [x] **5H** Debug signing fingerprints captured from `./gradlew :app:signingReport` on 2026-09-29. Dev and prod variants currently share the debug keystore. SHA-1 `1D:5B:2C:AF:3C:1D:A5:FC:AA:6C:F2:10:58:7D:D5:B2:D8:A2:64:C7`. SHA-256 `9E:2C:28:0E:A2:04:DC:CB:A1:4B:F5:EC:C6:B0:A4:C4:BB:37:ED:E8:F9:8E:74:98:AB:64:5C:62:64:F5:AF:CB`.
- [x] **5H.1** Owner registered the Android DEV SHA-256 on 2026-09-29. Production Android app was not changed.
- [x] **5I** iOS Runner has Push Notifications and Background Modes → Remote notifications. `app/ios/Runner/Debug.entitlements` is `development`. `Release.entitlements` is `production`. Flavor builds copy `app/ios/config/<flavor>/GoogleService-Info.plist`.
- [x] **5I.1** Owner uploaded the APNs `.p8` to both the development and production slots on DEV Firebase on 2026-09-29. Production Firebase was left empty.
- [ ] **5J** DEV web domain for SMS MFA. Deferred. Web MFA is not verified.
- [x] **5K** SMS enrollment. The user agrees before a code is sent. Firebase stores the number. The app shows only a masked label. The website uses the same screen.
- [x] **5L** Sign-in catches the multi-factor exception, lists each enrolled phone factor, and completes with the text-message code.
- [ ] **5M** Centralized authentication/access state machine. Client redirects cover sign-out, email verification, enrollment, the sign-in challenge, and deletion. Deletion scheduling is not wired yet. Shell routes stay closed until email is verified and SMS MFA is enrolled.
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

- [ ] **Brand package.** `/brand` with a generated logo, mark, wordmark, and tokens. Does not block Phase 5. Do it before polishing the marketing site. After the assets exist, wide auth screens put the logo and a short description of the app beside the form. Phone stays the single column.
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
