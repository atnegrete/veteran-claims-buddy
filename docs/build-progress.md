# Build progress

**Spec:** `Veteran_Claims_Buddy_Engineering_Handoff.md`  
**Routes:** `docs/page-navigation.md` wins if a screen or route disagrees with the handoff.  
**Updated:** 2026-10-04

This file is the implementation checklist. The handoff stays the spec. Update this file in the same change that finishes, blocks, or expands a step. Do not mark a phase complete while any item in it is open. Stop at owner gates.

`docs/backlog.md` tracks deferred features and open product decisions (for example Vet Buddy write-back, HEIC reading, the not-open prepare forms, and the admin area). When a backlog item is decided, expand it back into this file and build it here.

Status values: `done`, `in progress`, `blocked`, `not started`.

Do not start a later build-sequence step until its checklist has been expanded in this file from the handoff.

## Manual steps for the end

These do not block the next code. They are the actions only the owner can take: a deploy, a console setting, a store account, a domain, a certificate, or a legal review. Each one below is a self-contained set of steps. Do them when a dev deploy or a launch is actually wanted. Nothing here runs against production without the explicit prod step.

Check the box when the task is finished.

Each gate is broken into a single discrete task with exact steps. They fall into two groups.

**Do now (to make the dev app fully real):**
- **M1** — Deploy the dev backend (Functions, Firestore rules, indexes, Storage). This is the one that matters most; until it runs, the backend is only code in the repo.
- **M2** — Register dev App Check debug tokens. Optional; only needed if you want App Check attesting on dev. Enforcement is off, so nothing breaks without it.
- **M4** — Initialize and deploy dev Hosting. Optional; only if you want the web build and marketing site on a Firebase URL.
- **M5** — Dev web SMS sign-in check. Optional; needs M4.
- **M12** — Seed a dev test account. Optional test data.

**Do later (launch, store, certificate, domain, legal, commerce):**
- **M3** — App Check real providers (Play Integrity, App Attest, reCAPTCHA).
- **M6a/M6b/M6c** — Production APNs key, Android upload key, Web Push certificate.
- **M7** — Store icons.
- **M8a/M8b/M8c** — iOS TestFlight, Play internal testing, prod web deploy.
- **M9** — Connect the custom domain.
- **M10** — Legal review.
- **M11a–M11e** — Apple commerce, Google Play commerce, RevenueCat, Stripe, print-and-mail.

**Important:** the per-step notes elsewhere in this file that say a rule or job is "on the dev project" mean it is *written and targeted at dev*, not that it is already live. The code is in the repo but **not deployed** until you run M1.

### M1. Deploy the dev backend (Functions, Firestore rules, indexes, Storage rules)
- [x] Done 2026-10-04. Full deploy returned `Deploy complete!`: all Cloud Functions created/updated (`confirmAuthState`, `clearAuthState`, `startCase`, `setWorkingCase`, `ensureWorkingCase`, `scheduleAccountDeletion`, `cancelAccountDeletion`, `purgeDueAccounts`, `remindOpenTasks`, `remindUpcomingExams`, `syncExamStart`, `askVetBuddy`, `countDocumentPages`), Storage rules released, Firestore rules released, indexes deployed. `publish-questionnaire:dev` published `condition-discovery-v2` (601 questions) and `publish-knowledge:dev` published `va-rules`. The "on the dev project" notes elsewhere in this file are now actually live. The non-blocking rules lint warning at `firestore.rules:1194` (`Invalid variable name: uid`) was cleaned up by extracting a `caseDocPath` helper; it clears on the next deploy and does not change behavior.
1. Open a terminal at the repo root: `/Users/alann/repos/veteran-claims-buddy`.
2. If you have never signed in on this machine, run `npx -y firebase-tools@latest login` first.
3. Install the Functions dependencies: from `/Users/alann/repos/veteran-claims-buddy/functions`, run `npm install`.
4. Deploy everything to dev in one command, from the repo root: `npx -y firebase-tools@latest deploy --only functions,firestore:rules,firestore:indexes,storage --project dev`.
5. If you prefer to go piece by piece, run these from the repo root, each with `--project dev`: `deploy --only firestore:rules`, then `deploy --only firestore:indexes`, then `deploy --only storage`, then `deploy --only functions`.
6. Success: the command ends with `Deploy complete!`, every Cloud Function (for example `confirmAuthState`, `askVetBuddy`, `countDocumentPages`, `remindUpcomingExams`, `purgeDueAccounts`, `remindOpenTasks`) shows as deployed, and there is no `Invalid variable name: uid` warning on the rules.
7. Note: the questionnaire catalog and VA rules are published by separate scripts, not by this deploy. If they were not already published, run `npm run publish-questionnaire:dev` and `npm run publish-knowledge:dev` from the repo root (both use your active gcloud account).

### M2. Deploy the dev App Check debug token (do this with M9 and after the app is integrated)
- [x] Done 2026-10-04. iOS registered via its debug token. Android showed unregistered until the owner accepted the Play Integrity terms for the Android app, which registered it. Enforcement stays off. (Accepting Play Integrity also covers the Android half of M3.)
1. Run the dev app once on each platform you test: `fvm flutter run --flavor dev` from `/Users/alann/repos/veteran-claims-buddy/app`.
2. In the run console, find the line that prints an App Check debug token. On Android it is in logcat as `DebugAppCheckProvider` with a UUID. On iOS it is in the Xcode console as `App Check debug token: <UUID>`.
3. Open the Firebase console for `veteran-claims-buddy-dev` → Build → App Check → Apps.
4. Pick the dev Android app, open its menu, choose **Manage debug tokens**, click **Add debug token**, paste the UUID, name it (for example "Alan dev phone"), and save. Repeat for the dev iOS app with its own token.
5. Success: each debug token appears in that app's debug-token list. Leave enforcement OFF (that is M-none; see step 6E in Phase 6).

### M3. Register App Check providers for real builds (owner gate 6C)
- [ ] Not done.
1. In the Firebase console for `veteran-claims-buddy-dev` → Build → App Check → Apps, open the Android app and set its provider to **Play Integrity**. This needs the app linked in the Google Play Console, so it waits until there is a Play app (M6/M8).
2. Open the iOS app and set its provider to **App Attest** (or DeviceCheck). This uses the Apple bundle id `com.veteranclaimsbuddy.app.dev` and the APNs/App Store Connect setup.
3. For the web app, create a **reCAPTCHA v3** site key (Google reCAPTCHA admin) for the dev Hosting domain, register it under the web app's App Check provider, and give me the site key so I pass it to the web build with `--dart-define=APP_CHECK_WEB_KEY=<key>`.
4. Repeat all three for `veteran-claims-buddy-prod` only when a production release is being prepared.
5. Success: each app in App Check shows a configured provider, not "unregistered".

### M4. Initialize and deploy dev Hosting
- [x] Done 2026-10-04. Deployed both sites to dev: `veteran-claims-buddy-dev` (marketing, 21 files) at `https://veteran-claims-buddy-dev.web.app` and `veteran-claims-buddy-dev-app` (app, 40 files) at `https://veteran-claims-buddy-dev-app.web.app`. Hosting is wired in the repo (`firebase.json` has `marketing` + `app` targets, `.firebaserc` maps them to the dev/prod site ids). See `docs/hosting.md`. No `firebase init hosting` was needed. Web uses `--dart-define=APP_ENV=dev` instead of `--flavor`.
1. One-time: create the dev app site (the marketing site already exists as the default site): `npx -y firebase-tools@latest hosting:sites:create veteran-claims-buddy-dev-app --project dev`.
2. Build the marketing pages with dev URLs, from the repo root: `npm run build:marketing:dev`.
3. Build the Flutter web app: from `/Users/alann/repos/veteran-claims-buddy/app`, run `fvm flutter build web --dart-define=APP_ENV=dev` (web has no `--flavor`; the environment comes from `APP_ENV`).
4. From the repo root, deploy both sites: `npx -y firebase-tools@latest deploy --only hosting --project dev`.
5. Success: the command prints a `Hosting URL` for `veteran-claims-buddy-dev` (marketing) and `veteran-claims-buddy-dev-app` (app). Leave `veteranclaimsbuddy.com` unconnected (that is M9).

### M5. Dev web SMS sign-in check (needs M4 first)
- [ ] Not done.
1. Open the dev Hosting `app` URL from M4 in a browser.
2. Register a new account, verify the email, and enroll a text-message factor using a real phone you control (the web build uses the live reCAPTCHA, not the dev test numbers).
3. Sign out, sign back in, and confirm the sign-in stops on the SMS challenge and completes with the texted code.
4. Success: the full web auth flow reaches the claim with no stuck redirect. Tell me if any step fails.

### M6a. Production APNs key (Apple push)
- [ ] Not done.
1. In the Apple developer portal (Certificates, Identifiers & Profiles → Keys), confirm or create an APNs Auth Key (`.p8`). Keep the `.p8` out of the repo.
2. In the Firebase console for `veteran-claims-buddy-prod` → Project settings → Cloud Messaging → Apple app configuration, upload that `.p8` (with its Key ID and your Team ID) to both the development and production slots for `com.veteranclaimsbuddy.app`.
3. Success: both APNs slots on the prod Apple app show the uploaded key.

### M6b. Production Android upload key
- [ ] Not done.
1. Generate a production upload keystore with `keytool` (for example `keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`). Store it and its passwords in your password manager, not the repo.
2. Print its SHA-256 with `keytool -list -v -keystore upload.jks -alias upload` and copy the SHA-256 line.
3. In the Firebase console for `veteran-claims-buddy-prod` → Project settings → Your apps → the Android app, add that SHA-256 fingerprint.
4. Give me the SHA-256 so I can record it in the checklist.
5. Success: the prod Android app lists the upload SHA-256.

### M6c. Website Web Push certificate
- [ ] Not done.
1. In the Firebase console for `veteran-claims-buddy-prod` → Project settings → Cloud Messaging → Web configuration, click **Generate key pair** to create a Web Push certificate (VAPID).
2. Copy the public key and give it to me so web and the exam/task reminders can register for push.
3. Success: a Web Push certificate (key pair) exists on the prod project.

### M7. Install store icons from `/brand`
- [ ] Not done.
1. Do this only when a store build is being prepared.
2. From `/Users/alann/repos/veteran-claims-buddy/app`, run the icon/splash generator the owner uses (for example `fvm flutter pub run flutter_launcher_icons`) against the sources in `/brand`.
3. Success: the generated iOS and Android icon sets are updated and the app builds with the new mark.

### M8a. iOS TestFlight build
- [ ] Not done.
1. From `/Users/alann/repos/veteran-claims-buddy/app`, build a prod release: `fvm flutter build ipa --flavor prod`.
2. Upload the `.ipa` to App Store Connect (Transporter or Xcode Organizer) and distribute it to TestFlight.
3. Success: a TestFlight build is available to internal testers.

### M8b. Google Play internal testing build
- [ ] Not done.
1. From `/Users/alann/repos/veteran-claims-buddy/app`, build a prod app bundle: `fvm flutter build appbundle --flavor prod`.
2. Upload the `.aab` to the Google Play Console internal testing track (needs M6b's upload key).
3. Success: an internal-testing release is live in Play.

### M8c. Production web deploy
- [ ] Not done.
1. From `/Users/alann/repos/veteran-claims-buddy/app`, build web: `fvm flutter build web --dart-define=APP_ENV=prod` (web has no `--flavor`; the environment comes from `APP_ENV`).
2. From the repo root, deploy: `npx -y firebase-tools@latest deploy --only hosting --project prod`.
3. Success: the prod web URL loads.

### M9. Connect the custom domain
- [ ] Not done.
1. Do this only when the site should be public.
2. In the Firebase console for the prod project → Hosting → Add custom domain, add `veteranclaimsbuddy.com`, `www.veteranclaimsbuddy.com`, and `app.veteranclaimsbuddy.com`.
3. Read the exact DNS records Firebase shows on that screen and enter them at the domain registrar. Do not invent records.
4. Success: each domain shows "Connected" in the Hosting console and loads over HTTPS.

### M10. Legal review
- [ ] Not done.
1. Send `docs/legal/` (privacy, terms, subscription, refunds, print-and-mail, AI disclosure, support, account-deletion) to counsel.
2. After counsel signs off, tell me so the draft banner can be removed from the marketing site and app.
3. Success: counsel has reviewed the legal pages and approved removing the draft banner.

### M11a. Apple in-app commerce (handoff 38A)
- [ ] Not done.
1. In App Store Connect, accept the Paid Applications agreement and enter banking and tax details.
2. Create the in-app purchase products for Premium and the per-Case unlock (ids to match what we wire later).
3. Give me the product ids.
4. Success: the agreement is active and the products exist.

### M11b. Google Play commerce (handoff 38B)
- [ ] Not done.
1. In the Google Play Console, set up a merchant/payments profile.
2. Create the matching in-app products for Premium and the per-Case unlock.
3. Give me the product ids.
4. Success: the payments profile is active and the products exist.

### M11c. RevenueCat (handoff 38C)
- [ ] Not done.
1. Create a RevenueCat account and a project for the app.
2. Connect both the App Store and Play Store apps, and create the entitlements for Premium and the per-Case unlock.
3. Give me the RevenueCat public SDK key and the entitlement ids.
4. Success: RevenueCat shows both stores connected and the entitlements defined.

### M11d. Stripe (handoff 38D)
- [ ] Not done.
1. Create a Stripe account for web purchases and Print & Mail, and complete its business verification.
2. Give me the publishable key (and set the secret key as a Functions secret when we wire it).
3. Success: the Stripe account is active.

### M11e. Print-and-mail provider (handoff 38E)
- [ ] Not done.
1. Create an account with the print-and-mail provider.
2. Give me the API credentials so Print & Mail can be wired.
3. Success: the provider account exists and its credentials are recorded.

After M11a–M11e are done, tell me and I will expand handoff section 38 into the checklist and wire `/plans` and Print & Mail. Until then, `purchases_flutter` and `flutter_stripe` stay out of the app, and `/plans` stays a non-charging explainer.

### M12. Run a dev seed (optional test data)
- [ ] Optional. Run only when a test account should be filled.
1. From the repo root, run: `npm run dev:seed -- --uid <uid> --scenario a|b|c|d --confirm-dev-reset`.
2. Add `--replace` to clear that account first.
3. Success: one line names the scenario and the account. It does not touch production.

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

**SMS enrollment and the sign-in code step are in the app.** A verified account enters a phone number, agrees to the sign-in check, and confirms the 6-digit code. A later sign-in with an enrolled phone stops on `/mfa/challenge` and can choose among enrolled phone factors. The screen shows a masked label, not the raw number. The website uses the same enrollment screen. The dev flavor skips the live reCAPTCHA and accepts only a fictional number from the DEV console. Production keeps the live check. After the code succeeds, `confirmAuthState` records verified email and an enrolled factor at `users/{uid}/security/authState`. The client cannot write that document. Onboarding stays closed until that call succeeds.

**Auth gates share one frame.** `AuthScaffold` centers a 400-point column on phone and wide web. Color, inputs, and buttons come from `appTheme()`. The logo and a short description in the wide-web side space wait for the brand package.

**The signed-in app opens the claim.** There is no separate Home. The current step is that claim, labeled Open Case. Documents, forms, the package, and C&P Prep sit under it, in that order. C&P Prep is after the package is sent. The Symptoms Tracker and the VA Ratings Calculator are their own sections. A wide window shows that list on the left. A phone keeps it in the navigation drawer. A finished claim stays the one that opens until another claim is started. Earlier claims stay available from the account menu. Screens say "your claim." The stored record is still a Case, and `/plans` still sells the Case unlock.

**Vet Buddy is a chat bubble on the claim.** A session keeps the claim snapshot until it ends. The next message reads the claim again and does not include the earlier turns. A reply can open a claim screen. It does not change the claim. The safety footer is in the bubble.

**The claim screen is the current step.** That step is calculated from the claim: the first-claim question, earlier paperwork, the symptom questions, adding a condition, reviewing statements from a file, then a review for a denied, deferred, or reduced issue. If none of those are waiting, it stops because the other forms are not open yet. A model does not choose it. One system task stores that step. `/tasks` shows it and is not a claim section.

**C&P Prep is a manual exam.** The Veteran adds the date, time, time zone, type, provider, location, phone, and notes. Prep shows answers already given. Travel follows a VA facility or a contractor. About two hours before, a phone can get "Your exam starts in about 2 hours." The lock screen does not name a condition. The website does not register for that reminder until a Web Push certificate exists.

**A decision letter stays off the claim until it is confirmed.** Upload reads the letter into a draft. Confirm is what puts that reading on the claim. Nothing on that step is filed with the VA.

**A confirmed denial, deferral, or reduction can continue in the same claim.** Forms opens a Supplemental Claim, a Higher-Level Review, or a Board Appeal as a draft. The official form is not filled. Nothing is filed with the VA. Intent to file, the initial claim, and the other forms stay closed. The one-year review window is rule `va-rules`. A letter stamps that id on the deadline. The app does not download a newer VA form on its own.

**An account scheduled for deletion is removed after 30 days.** A daily job deletes that user's claim records, uploaded files, and sign-in. It does not delete the published VA rules or the questionnaire. That job is on the dev project.

**The package is not generated yet.** Package explains that generating it is a paid step, and how the Veteran submits on VA.gov or by mail. This app does not file and does not sign. A checklist is the Veteran's own mark. It is not a VA receipt.

**A task reminder stays generic.** Once a day, an open claim step can say "You have an upcoming Veteran Claims Buddy task." It does not name the step. Turning task reminders off skips it. Opening it goes to that claim's tasks. The website still does not register for push.

**A change is checked without a deploy.** GitHub Actions runs the Flutter checks on 3.47.5 and the Node tests on 22. It does not deploy. TestFlight, Play testing, and production launch stay with the owner.

**The mark is a white V on navy.** Wide sign-in shows it beside the form, with a short description. Phone stays one column. Store icons are not installed yet.

**The public site is static HTML in `/marketing-site`.** It describes the workspace, the $250 Case unlock, $30 Premium, and Print & Mail. The calculator uses the VA rate table effective December 1, 2025. Every page says a lawyer has not reviewed it. The domain is not connected.

**The Symptoms Tracker records a check-in or an event.** Severity, duration, and a few yes or no impacts. It is not the claim questionnaire and it is not a diagnosis. New entries need Premium. Saved entries stay readable. A monthly summary is not generated yet.

**Account pages stay in the account menu.** Support, billing, profile, security, notifications, legal, and delete account are not the front door. The Symptoms Tracker and the VA Ratings Calculator are their own sections. A list of claims appears only when more than one exists.

**You links to support, billing, profile, security, notifications, and legal.** Support shows the support email and tickets on the account. Profile stores a display name and a US time zone, not a legal name. Notification choices are saved for later exam and task reminders. Billing says Premium is not active and no case is unlocked. Legal names the marketing pages. Those public pages are not connected yet.

**Account deletion can be scheduled.** You → Delete account asks for the password and explains the 30-day wait. Until reactivation, sign-in opens only that page. Nothing is deleted until the later purge job.

**Onboarding is service history.** Welcome, service, deployments, reported exposures, and review. The old discovery hold is gone. After the first-claim question, the claim asks one symptom question at a time. A yes saves a possible condition. Nothing is filed. An earlier claim adds its paperwork in Documents. Reading that file is still later.

## Phase 2 — what the owner does next

Done on 2026-09-29. Ids are in `docs/environment-values.md`.

## Decisions already made

- Flutter is FVM **3.47.5** (Dart 3.13.4). There is no `flutter` binary on PATH. Run `fvm flutter` from `/app`.
- The FVM cache entry named `stable` is Flutter 3.0.5 and does not run on this Mac.
- This Mac is Intel, with Intel UHD Graphics 630 and a Radeon Pro 560X. Chrome on that GPU cannot compile Flutter's web shaders, then recreates WebGL contexts until the console fills with "Too many active WebGL contexts." `app/web/index.html` draws with the CPU on those Mac GPUs. Apple Silicon stays on the GPU.
- Flutter 3.47.5 printed a deprecation warning that a future Flutter release will require Apple Silicon. Not a blocker for 3.47.5.
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
- The app is one blue family, with red only for danger and errors. Tokens and button roles are in `docs/color-scheme.md` and `app/lib/app/app_theme.dart`.

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
| 2026-09-30 | `confirmAuthState` writes the server enrollment marker after a verified email and an enrolled factor. Clients cannot write it. |
| 2026-09-30 | Signed-in shell has Home, Case, Vet Buddy, and You. It stays closed until onboarding is finished. |
| 2026-09-30 | Onboarding collects service, deployments, and reported exposures, then opens Home. Dev Firestore rules allow those paths only after the server enrollment marker. Symptom discovery is still a later questionnaire. |
| 2026-09-30 | Chrome on this Mac's Intel and Radeon GPUs loops Flutter WebGL context warnings. The web app draws with the CPU on those GPUs. |
| 2026-09-30 | Deployment onboarding asks for a description and a best-guess month and year, instead of a country and a full date. |
| 2026-09-30 | Step forms use a shared stepper. Onboarding can go back to a step already reached. Later steps stay closed until Continue opens them. |
| 2026-09-30 | Security settings list enrolled phones, can add or remove one after the password is entered again, and send a lost phone to support. Removing the last phone closes the app until a new one is enrolled. |
| 2026-09-30 | Home shows the working case, next action, deadlines, quick links, and a Premium card. With no Case, those sections are empty. The calculator estimates a combined rating only. `/plans` explains the $250 Case unlock and $30 Premium and does not charge a card. |
| 2026-09-30 | The case list can start a case and choose the working case, up to 12. The Case tab opens that case. Nested issue, evidence, exam, and package pages stay closed. |
| 2026-09-30 | The first case is created when onboarding is finished and shown as Open Case. The name field and the 12-case explanation are removed from the list. Starting another case waits for a later workflow. |
| 2026-09-30 | Vet Buddy shows an empty chat list and the safety footer. You links to the calculator, symptoms, support email, billing, security, and legal. Assistant replies and the marketing-site legal URLs are still later. |
| 2026-09-30 | Delete account schedules a 30-day wait after the password is entered again. Sign-in during that wait opens only reactivation. The job that deletes the data after 30 days is still later. |
| 2026-09-30 | The dark theme is one blue family. Red is only for danger and errors. Delete account is centered danger text. Schedule deletion and the confirm-remove button are danger fill. |
| 2026-09-30 | Profile stores a display name and a US time zone. Notification choices are saved for exam and task reminders. Support tickets can be opened, answered, and closed from You. The symptom form and the Case workflow stay later. |
| 2026-09-30 | The signed-in app becomes one guided claim. The first step asks if this is their first VA disability claim. Vet Buddy becomes a chat bubble. The four-tab shell stays in the app until that replacement is built. |
| 2026-09-30 | The four tabs are gone. The claim opens on the first-claim question. Documents, exams, and the package can be opened from that step. Vet Buddy is a bubble and does not answer yet. |
| 2026-09-30 | The claim's sections are on the left again. There is no separate Home. A finished claim stays the one that opens until another claim is started. Earlier claims stay available to view. |
| 2026-09-30 | Documents, exams, and the package sit under Open Case. The Symptoms Tracker and the VA Ratings Calculator are their own sections, not account-menu items. |
| 2026-09-30 | The claim asks the broad symptom questions one at a time. A yes saves a possible condition. Back pain can ask about pain down a leg. Nothing is filed. Deeper body-system questions and earlier-claim uploads stay later. |
| 2026-09-30 | `dev:reset-user` refuses any project except the dev project. Running it waits on Application Default Credentials. |
| 2026-10-01 | `dev:reset-user` uses the active gcloud account. One dev test account was deleted: Auth, Firestore, and Storage. The other dev account was left in place. |
| 2026-10-01 | Service, deployments, and exposures show the form only until the first item is saved. Saved items are cards. Add Another opens the form again. |
| 2026-10-01 | Saved-item cards label each fact with the same words as the form. Labels sit beside the value on a wide card and above it on a narrow card. |
| 2026-10-01 | Onboarding Back and Continue sit apart, with a divider above the pair. Continue stays on the right, and it is full width only when it is the only button. |
| 2026-10-01 | A possible condition becomes an issue only when the Veteran adds it to the claim. The issue lists the evidence still needed. Nothing is filed, and there is no chance of approval. |
| 2026-10-01 | Condition discovery v2 is a versioned JSON catalog. `publish-questionnaire:dev` and `publish-questionnaire:prod` copy it into Firestore. The app still asks the short v1 list until it loads v2. |
| 2026-10-01 | New questionnaires load the published v2 catalog. The claim sidebar is the eight sections, with a muted check when a section is done. |
| 2026-10-01 | Symptom questions are one page per body system. The page saves on Continue, and again in the background, writing only answers that changed. |
| 2026-10-01 | Development does not keep an older questionnaire shape. Stored answers from the short list are deleted, and Questions uses the current catalog. |
| 2026-10-01 | The claim name opens and closes. The eight claim sections are indented under it. Symptoms Tracker and the calculator stay outside that group. |
| 2026-10-01 | The claim page fills the center. Question text scrolls inside the card, and Continue stays at the bottom. |
| 2026-10-02 | The opening question page stays the yes or no list. A Yes opens that topic on Continue, and a tap does not rebuild the catalog. |
| 2026-10-02 | Each topic name stays at the top of its question page. The scrollbar on that page stays visible. |
| 2026-10-02 | Bladder questions say urinate. On the head page they follow Parkinson's, multiple sclerosis, or ALS. Question text is larger than the choices, and the choices sit closer together. |
| 2026-10-02 | The topic name at the top of a question page is the heading. The note under it is secondary text. |
| 2026-10-02 | An issue opens its questions, evidence notes, connection notes, lay statement, doctor draft, and a decision already received. Nothing on those pages is filed. |
| 2026-10-02 | Documents can store a PDF, JPEG, or PNG for this claim. The file is not read yet. |
| 2026-10-02 | An issue keeps its parts on one screen. A wide pane opens the part beside the list. A narrow pane replaces the list, and Back closes it. A text note has Save and Back. |
| 2026-10-02 | Status and "Nothing is filed with the VA at this step." are badges. A finished part is a muted check. A count uses the blue wash. |
| 2026-10-02 | Badge, button, and sidebar labels are white or gray. Color sits on the fill. The filing badge has no icon. |
| 2026-10-02 | Choosing a document file opens the browser dialog. C&P Prep follows the package, because that exam is scheduled after the VA has the claim. |
| 2026-10-02 | An earlier claim adds its paperwork in Documents. A saved PDF gets a page count. The file is still not read. |
| 2026-10-02 | A saved PDF, JPEG, or PNG is read once. The Veteran confirms, corrects, or sets aside each statement. The original wording stays. |
| 2026-10-02 | Vet Buddy answers a question from the saved claim. It does not read the file, file a claim, or change the claim. |
| 2026-10-02 | A Vet Buddy session keeps that claim snapshot. After it ends, the next message reads the claim again and leaves the earlier turns out. A reply can open a claim screen. |
| 2026-10-03 | A document stays on the claim only after the file is stored. A failed upload removes the record and any partial file. |
| 2026-10-03 | Choosing a file starts the upload. A dialog shows progress. The claim lists the file after it finishes. |
| 2026-10-03 | The claim screen follows one calculated next step. Forms stay closed. The step is stored as a system task. |
| 2026-10-03 | C&P Prep stores an exam the Veteran adds. Prep reuses answers already given. A reminder about two hours before stays generic. |
| 2026-10-03 | A decision letter is read into a draft. The claim takes that reading only after it is confirmed. |
| 2026-10-03 | A denied, deferred, or reduced issue can continue as a Supplemental Claim, Higher-Level Review, or Board Appeal. The form is not filled, and nothing is filed. |
| 2026-10-04 | The one-year review window is a published rule, `va-rules`. A letter stamps that id on the deadline. The app does not fetch a newer VA form. |
| 2026-10-04 | After the 30-day wait, a scheduled job removes that account's claim records, files, and sign-in. Published VA rules stay. |
| 2026-10-04 | The package is not generated yet. The Veteran submits on VA.gov or by mail. This app does not file. |
| 2026-10-04 | An open claim step can send a generic task reminder once a day. The lock screen does not name the step. |
| 2026-10-04 | GitHub Actions checks Flutter 3.47.5 and the Node tests. It does not deploy. |
| 2026-10-04 | The brand mark is a white V on navy. Wide sign-in shows it beside the form. |
| 2026-10-04 | The public site is static HTML. Counsel has not reviewed it, and the domain is not connected. |
| 2026-10-04 | The Symptoms Tracker can save a check-in or an event. New entries need Premium. |
| 2026-10-04 | Dev seed can write one of four fake claims. It has not been run. |
| 2026-10-04 | A claim timeline lists exams, confirmed decisions, and review drafts. |
| 2026-10-04 | Owner ran the dev end-to-end auth flow and it passed: register, verify email, enroll SMS, pass the SMS challenge, finish onboarding, reach the claim. Step 5Q and Phase 5 are done on dev. Production auth is rechecked at the production release gate. App Check (Phase 6) is now unblocked. |
| 2026-10-04 | App Check is activated by flavor in bootstrap: debug providers on dev, Play Integrity and App Attest on prod, web off until a reCAPTCHA key exists. Enforcement stays off. The console registrations are owner steps. The Manual-steps section is rewritten as explicit per-task instructions (M1–M12). |
| 2026-10-04 | Step 6 is complete. 6F (the You section) is verified: support, billing, profile, security, notifications, legal, delete account, the conditional Claims link, the Symptoms Tracker, and the combined-rating calculator with its no-pay no-bilateral note. 12D is closed because reading is delivered in step 13. The agent-buildable MVP sequence (6–23) is done except owner gates and the deferred Vet Buddy write-back (14D). |
| 2026-10-04 | Added `docs/backlog.md` to track deferred features and open product decisions: Vet Buddy write-back (B1), monthly symptom summary (B2), starting another claim (B3), HEIC reading (B4), the not-open prepare forms (B5–B11), not-built package/processing screens (B12–B13), the admin area (B14), and commerce/Print & Mail (B15). 14D and 13D now point at it. |

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
- [x] **5E** DEV fictional test phone numbers configured. Values stay in the owner's password manager, not in the repo. The owner replaced the area-code 123 number on 2026-09-30.
- [x] **5F** SMS region policy reviewed in DEV and PROD. U.S. numbers are allowed.
- [x] **5G** Email/password create, sign-in, forgot password, reset-password handler, verify-email, and sign-out. Unverified users cannot leave `/verify-email`. Verified users without a factor land on `/mfa/enroll`, which does not send SMS yet.
- [x] **5H** Debug signing fingerprints captured from `./gradlew :app:signingReport` on 2026-09-29. Dev and prod variants currently share the debug keystore. SHA-1 `1D:5B:2C:AF:3C:1D:A5:FC:AA:6C:F2:10:58:7D:D5:B2:D8:A2:64:C7`. SHA-256 `9E:2C:28:0E:A2:04:DC:CB:A1:4B:F5:EC:C6:B0:A4:C4:BB:37:ED:E8:F9:8E:74:98:AB:64:5C:62:64:F5:AF:CB`.
- [x] **5H.1** Owner registered the Android DEV SHA-256 on 2026-09-29. Production Android app was not changed.
- [x] **5I** iOS Runner has Push Notifications and Background Modes → Remote notifications. `app/ios/Runner/Debug.entitlements` is `development`. `Release.entitlements` is `production`. Flavor builds copy `app/ios/config/<flavor>/GoogleService-Info.plist`.
- [x] **5I.1** Owner uploaded the APNs `.p8` to both the development and production slots on DEV Firebase on 2026-09-29. Production Firebase was left empty.
- [ ] **5J** DEV web domain for SMS MFA. Deferred. Web MFA is not verified.
- [x] **5K** SMS enrollment. The user agrees before a code is sent. Firebase stores the number. The app shows only a masked label. The website uses the same screen.
- [x] **5L** Sign-in catches the multi-factor exception, lists each enrolled phone factor, and completes with the text-message code.
- [x] **5M** Centralized authentication/access state machine. Client redirects cover sign-out, email verification, enrollment, the sign-in challenge, and deletion. Scheduling deletion asks for the password again, waits 30 days, and closes the app except for reactivation. The purge job that deletes the account after those 30 days is step 22.
- [x] **5N** `confirmAuthState` in `functions/index.js` reads the Auth user with the Admin SDK, requires a verified email and at least one enrolled factor, and writes `users/{uid}/security/authState`. The document stores no phone number. Firestore rules deny client reads and writes. Deployed to the dev project. Cloud Run invoker is `allUsers` so the callable can run; the function still rejects a caller who is not signed in.
- [x] **5O** Service history under `users/{uid}` can be read and written only by that verified user after `confirmAuthState`. Rules are released on dev. The auth marker document stays closed to clients. Other collections stay denied. Case files and Storage are still closed.
- [x] **5P** Security at `/you/settings/security` lists each enrolled phone as a masked label. Adding or removing a phone asks for the password again. Removing the only phone clears the server marker and returns the account to enrollment. Lost-phone help is support email only. Password reset is not described as a way around the text-message check. The audited recovery procedure for production is still the production auth release gate.
- [x] **5Q** Owner DEV end-to-end auth acceptance test passed on 2026-10-04. The owner ran `fvm flutter run --flavor dev` from `/app` and completed register, verify email, enroll SMS, pass the SMS challenge, finish onboarding, and reach the claim. This acceptance is dev only. Production is rechecked at the production auth release gate.
- [x] **Definition of done — Phase 5.** Complete on dev. Production Android fingerprints, production APNs, and the production auth release gate stay closed until a production release.

Production Android fingerprints, production APNs, and the production auth release gate stay closed until a production release is actually being prepared.

## Step 6 — Application shell

The four-tab frame below is what was built first. The open claim replaces that front door. Documents, exams, and the package sit under Open Case. The Symptoms Tracker and the VA Ratings Calculator are their own sections. Do not add a separate Home dashboard.

- [x] **6A** `AdaptiveScaffold` frame. A phone uses the bottom bar. A wide window uses the navigation rail. Destinations are Home, Case, Vet Buddy, and You. `/plans` is not a tab. Signed-in screens, including onboarding, share one app bar. Sign out is in that account menu.
- [x] **6B** Routes `/home`, `/cases`, `/buddy`, and `/you`. Incomplete onboarding stays on `/onboarding`. Finished onboarding opens `/home`.
- [x] **6C** Home content: working Case, next action, deadlines, quick links, and the Premium widget. With no Case, each of those is an empty state. The Premium card is omitted once Premium is active. Symptom entry opens `/plans?reason=symptoms` until then.
- [x] **6D** Case list. The first case is created at the end of onboarding and shown as Open Case. The Case tab opens `/cases/:caseId/overview`. Switching the working case stays available. Naming a case, starting another one, and explaining the cap of 12 wait for a later workflow. Issues, evidence, exams, forms, and the package stay closed.
- [x] **6E** Vet Buddy chat list. The page explains that Vet Buddy does not file a claim or decide one. There are no chats, and there is no message box, until the assistant in step 14 can reply. The safety footer is on the page.
- [x] **6F** You links to support, billing, profile, security, notifications, legal, and delete account, and a Claims link appears only when more than one claim exists. Support shows the support email and the account's tickets. Profile stores a display name and a US time zone. Notification choices are saved. Billing shows that Premium is not active and no case is unlocked. Legal names the marketing pages and says they are not connected yet. Delete account schedules the 30-day wait. The Symptoms Tracker can save a check-in or an event, and new entries need Premium. The public legal URLs are not connected. The VA Ratings Calculator estimates a combined rating and states it does not estimate pay or apply the bilateral factor. Verified 2026-10-04.
- [x] **6G** `/plans` explains the $250 Case unlock and $30 Premium, including what stops when Premium ends. Nothing on the page charges a card. No `purchases_flutter` until that owner gate.

## Guided claim

Expanded from `docs/page-navigation.md` and handoff section 2A.28. This replaces the four-tab front door. The symptom questionnaire itself stays step 10.

- [x] **G1** The open claim shows one step. `/home` only opens that claim. The first step asks whether this is their first VA disability claim. First claim skips prior-claim paperwork. A later claim asks for that paperwork and can add new conditions. Nothing is filed with the VA. The broad symptom questions follow that answer.
- [x] **G2** Documents, exams, and the package sit under Open Case. Later parts of the claim join that list. A wide window shows it on the left. A phone keeps the same list in the navigation drawer. Adding a file, an exam, or the package is still later. A finished claim stays open until another claim is started. Earlier claims open from the account menu and do not replace the open claim.
- [x] **G3** The Symptoms Tracker and the VA Ratings Calculator are their own sections. Account, billing, security, support, notifications, and legal stay in the account menu. A claim list appears only when more than one claim exists.
- [x] **G4** Vet Buddy is a chat bubble on the step. It does not invent a reply. The safety footer is in the bubble.

## Step 9 — Veteran onboarding

Order is fixed. Skipping ahead is not allowed. Back, and any step already reached, can be opened again to edit. Finishing review opens Home. Legal name, date of birth, SSN, and VA file number are not collected.

- [x] **9A** Welcome. One Veteran per account. Nothing on these screens is filed.
- [x] **9B** Service periods saved to `users/{uid}/servicePeriods`. At least one is required.
- [x] **9C** Deployments saved to `users/{uid}/deployments`. Optional. The Veteran describes the deployment in their own words. Start and end are a best-guess month and year, stored as the first day of that month.
- [x] **9D** Exposures the Veteran reports are saved as `reported`. A system suggestion cannot become confirmed just by being suggested. There is no suggestion engine yet.
- [x] **9E** The onboarding discovery hold is removed. The symptom questionnaire opens inside the claim after the first-claim question. The questionnaire itself is step 10.
- [x] **9F** Review. No potential conditions yet. Nothing is filed. Finish opens Home.

## Step 7 — Firestore domain model

Expanded from handoff sections 14–20 and 25. Only the discovery records are open. Issues, documents, exams, and the package stay closed.

- [x] **7A** `users/{uid}/conditions/{id}` can be created by that Veteran as `potential` from the symptom questions. A no dismisses it. The client cannot mark one diagnosed or file it.
- [x] **7B** `users/{uid}/questionnaires/condition-discovery` and its responses store those answers. Hidden follow-ups can be removed when an earlier answer changes.
- [ ] **7C** The rest of the hierarchy in handoff section 15 stays denied until that step starts.

## Step 10 — Condition discovery questionnaire

Expanded from handoff section 26 and 2A.28. One question at a time, on the open claim.

- [x] **10A** Broad questions cover the body systems in section 26. Yes and No are the choices. Nothing is filed with the VA.
- [x] **10B** Recurring back pain asks whether the pain travels down a leg, then which side. A yes saves a possible condition.
- [x] **10C** A questionnaire loads `condition-discovery-v2` from Firestore, one body system per page. A yes on a body system does not create a condition. Each checked diagnosis does. An older answer set is deleted in development instead of keeping a second list.
- [x] **10E** `questionnaires/condition-discovery-v2.json` is the catalog. `npm run publish-questionnaire:dev` and `npm run publish-questionnaire:prod` copy it into `questionnaireDefinitions`. Prod refuses without `--confirm-prod`. An id that is already `active` is not replaced. The owner runs the dev publish. Rules let a signed-in Veteran read the catalog and do not let the client write it.
- [x] **10D** An earlier claim adds its decision or claim paperwork in Documents. That section is done once a file is saved. New conditions still go through these questions.

## Step 11 — Claim issues

Expanded from handoff sections 19, 21, and 30, and from `/cases/:caseId/issues` in `docs/page-navigation.md`. A condition is not an issue until the Veteran adds it to this claim.

- [x] **11A** `users/{uid}/claimIssues/{conditionId}` is created only for a potential condition on a case this Veteran owns. Status stays `potential`. The client cannot set a rating, a submission, or a chance of approval.
- [x] **11B** After the symptom questions, each possible condition can be added to this claim. Nothing is filed with the VA.
- [x] **11C** Issues is a claim section and lists the issues on this claim.
- [x] **11D** An issue shows what a direct claim still needs. Pieces with no note are named in one line. Notes the Veteran adds are the cards. That list is completeness, not a predicted outcome.
- [x] **11E** An issue opens the questions for that condition, notes on the evidence pieces, how it may be connected, a lay statement, a doctor draft, and a decision the Veteran already received. On a wide pane the part opens beside the list. On a narrow pane it replaces the list, and Back closes it. A text note is saved or cleared with Save. A connection note is not a medical finding. The doctor draft is not a finished opinion. A recorded decision does not set a rating on the issue or predict an outcome. Nothing is filed. A file upload is still step 12.

## Step 12 — Documents

Expanded from handoff sections 27 and 2A.11, and from `/cases/:caseId/evidence` in `docs/page-navigation.md`. A file is stored for this claim. It is not read yet.

- [x] **12A** Documents lists the files on this claim. The section is in progress once a file exists.
- [x] **12B** A PDF, JPEG, or PNG up to 100 MB can be saved under `users/{uid}/documents/{id}/`. HEIC waits until a file can be read.
- [x] **12C** The kind of file and an optional date can be set or changed. The client cannot mark the file as read.
- [x] **12D** Reading the file and the extracted facts are done in step 13 (13A page count, 13B read, 13C review). HEIC stays rejected (13D, blocked by the `sharp` library).

## Step 8 — Dev reset

Expanded from handoff sections 2A.20 and 36. The command refuses any project that is not `veteran-claims-buddy-dev`.

- [x] **8A** `npm run dev:reset-user -- --uid <uid> --confirm-dev-reset` deletes that user's Auth account, Firestore tree, and Storage files. It keeps reference data. It uses the active `gcloud` account and still refuses any project other than `veteran-claims-buddy-dev`. One dev test account was reset on 2026-10-01.
- [x] **8B** `npm run dev:seed -- --uid <uid> --scenario a|b|c|d --confirm-dev-reset` writes one fake claim on the dev project. `--replace` clears that user first. It has not been run. A wipe of every dev user is still `dev:reset-user` for one account.

## Phase 6 — App Check

Expanded from handoff section 13. Phase 5 is done on dev (5Q passed 2026-10-04), so this is unblocked. App Check proves a request comes from the genuine app binary. Enforcement stays OFF until real traffic is confirmed in the console, so none of the client work below can break a build or a call.

- [x] **6A** `activateAppCheck` in `app/lib/app/app_bootstrap.dart` turns on App Check right after `Firebase.initializeApp`. Dev uses `AndroidProvider.debug` and `AppleProvider.debug`. Prod uses `AndroidProvider.playIntegrity` and `AppleProvider.appAttest`. `firebase_app_check` is already in `pubspec.yaml`.
- [x] **6B (code)** Dev debug providers make each build print an App Check debug token. Registering those tokens in the console is owner step **M2**. Release builds never use a debug provider, because the provider is chosen from the flavor.
- [x] **6D** The callables already accept an App Check token and do not require it. Firebase Functions v2 `onCall` attaches `request.app` when a token is present and does not enforce by default, so tokens flow into the console metrics without blocking a call. No code change was needed.
- [x] **Web** stays off until a reCAPTCHA site key exists. `activateAppCheck` skips web when `APP_CHECK_WEB_KEY` is empty, and uses `ReCaptchaV3Provider` when the owner passes the key with `--dart-define=APP_CHECK_WEB_KEY=...`. The key is owner step **M3**.
- [ ] **6C** Register the real providers in the Firebase console: Play Integrity (Android), App Attest (Apple), and a reCAPTCHA v3 site key (web). Owner gate. See **M3**.
- [ ] **6E** Enable enforcement in the console only after the App Check metrics show valid app traffic, and flip the callables' `enforceAppCheck` to `true` in the same change. This waits for a production release decision. Owner gate.

## Later build sequence

These follow handoff section 6. Expand each one into concrete tasks in this file before writing that code.

- [x] **6. Application shell and navigation.** The frame, Home, the case list, Vet Buddy's chat list, `/plans`, and the full You section (6A–6G) are done. The nested Case pages were delivered under the Guided claim and steps 11–21.
- [ ] **7. Firestore domain model and repositories.**
- [ ] **8. Dev reset and seed tooling.** Expanded below. Reset must refuse to run against production.
- [ ] **9. Veteran onboarding and service history.** Expanded in the step 9 section. Discovery's symptom questionnaire is still step 10.
- [ ] **10. Universal condition discovery and questionnaires.** New questionnaires use the published v2 catalog. An earlier claim can add its paperwork.
- [ ] **11. Claim Issue model and evidence matrices.** An issue keeps its questions, evidence notes, connection notes, statements, and recorded decisions. File upload is still step 12.
- [ ] **12. File and document management.** A claim can store a PDF, JPEG, or PNG. A PDF page count is stored after save. Reading the file is still step 13.
- [ ] **13. Document AI extraction and provenance.** Expanded below. A saved file is read once. HEIC is still rejected.
- [ ] **14. Assistant and agent tool framework.** Expanded below. Vet Buddy can explain the saved claim in a session. It does not change it.
- [ ] **15. Deterministic next-action and workflow engine.** Expanded below. The claim screen shows that step. A denied, deferred, or reduced issue can continue. The other forms stay closed.
- [ ] **16. C&P exam workflows.** Expanded below. A Veteran adds the exam. A reminder about two hours before stays generic. Website push still needs a certificate.
- [ ] **17. Decision-letter analysis.** Expanded below. A letter stays off the claim until the reading is confirmed.
- [ ] **18. Decision-review workflows.** Expanded below. Three review paths can be started as a draft. The official form is not filled. Nothing is filed.
- [ ] **19. VA knowledge synchronization.** Expanded below. The review window is a checked-in rule. Publishing it does not download a VA form.
- [ ] **20. VA API integrations.** Expanded below. No VA filing API. The Veteran submits on VA.gov or by mail.
- [ ] **21. Notifications.** Expanded below. A daily task reminder stays generic. Exam reminders stay in step 16. Website push still needs a certificate.
- [ ] **22. Security hardening and data lifecycle.** Expanded below. Includes the 30-day account deletion grace period and the purge job.
- [ ] **23. CI/CD, release, TestFlight, and Play testing.** Expanded below. Checks run on every change. TestFlight and Play stay with the owner.
- [ ] **24. Production launch readiness.** Expanded below. Production release stays with the owner.

## Step 15 — Next step

Expanded from handoff section 32 and from the current step in `docs/page-navigation.md`. The claim screen is that step. It is not a dashboard. The model does not choose it.

- [x] **15A** The next step is calculated from the claim: first-claim question, earlier paperwork, symptom questions, adding a condition, reviewing statements from a saved file.
- [x] **15B** The claim screen shows that step. First-claim and earlier paperwork stay as they are. Forms stay closed, with no button that opens them.
- [x] **15C** One system task, `users/{uid}/tasks/next-{caseId}`, stores that step. The client cannot file, rate, or mark a submission from it. Those rules are on the dev project.
- [x] **15D** `/cases/:caseId/tasks` shows that task. It is not a new section in the claim list.

## Step 16 — C&P exams

Expanded from handoff section 2A.13 and the exam routes in `docs/page-navigation.md`. The Veteran adds the exam. Nothing here schedules it with the VA, reads a letter, or writes it to the phone calendar.

- [x] **16A** The form stores the date, time, time zone, exam type or conditions (200), provider name (80), location (200), notes (2000), a VA, contractor, or unknown provider, a U.S. phone, and whether it is telehealth. It can be edited or removed later.
- [x] **16B** `/exams`, `/new`, `/:examId/details`, `/prep`, and `/travel` are open. Prep shows answers already given. Travel follows the provider. A VA exam links to current travel-pay guidance. A contractor exam says to contact that contractor if payment has not arrived within 14 days. No contractor phone number is hard-coded. The official claim-exam page is linked.
- [x] **16C** About two hours before, a saved phone token can receive "Your exam starts in about 2 hours." The message does not name a condition. Turning off exam reminders skips it. The start time is written by a function from the date, time, and time zone.
- [ ] **16D** The website does not register for that reminder. It needs a Web Push certificate from the Firebase console.

## Step 17 — Decision letters

Expanded from handoff section 24 and the decision routes in `docs/page-navigation.md`. The letter is read into a draft. The claim does not take that reading until the Veteran confirms it. Nothing is filed with the VA.

- [x] **17A** `/decisions/upload` stores a PDF, JPEG, or PNG as a decision letter.
- [x] **17B** A saved letter is read into a draft: date, summary (2000), conditions (120), outcomes, ratings, favorable findings (2000), and reasons (2000). A rating that is not written is left blank. The draft does not show on an issue.
- [x] **17C** `/decisions/:decisionId` is the check against the letter. Confirm puts that reading on the claim. Discard removes the reading and leaves the file in Documents. One year after the decision date is shown. The reader and letter rules are on the dev project.

## Step 18 — Decision-review workflows

Expanded from handoff section 6 item 18 and the prepare routes in `docs/page-navigation.md`. A confirmed denial, deferral, or reduction stays in the same claim. The official form is not filled. Nothing is filed with the VA.

- [x] **18A** `/prepare` opens a Supplemental Claim (20-0995), a Higher-Level Review (20-0996), or a Board Appeal (10182). Intent to file, the initial claim, and the other forms stay closed.
- [x] **18B** A draft stores one eligible issue. A Board path stores a docket. A Higher-Level Review stores whether an informal conference was requested. The claim issue is not changed.
- [x] **18C** After the earlier steps, the claim screen points at Forms when an eligible issue has no draft. The submission rules are on the dev project.

## Step 19 — VA knowledge

Expanded from handoff sections 1.11 and 6 item 19, and from the global collections in section 15. The one-year review window and the three review form numbers are a checked-in snapshot. The app binary stays on that snapshot. Nothing here calls the VA, downloads a form, or changes the calculator.

- [x] **19A** `knowledge/va-rules.json` is rule `va-rules`. It records a one-year review window, forms 20-0995, 20-0996, and 10182, and the VA decision-reviews page.
- [x] **19B** A decision letter stamps `deadlineRuleVersionId` with `va-rules`. Confirm cannot change that id. The review screen uses the same window.
- [x] **19C** `npm run publish-knowledge:dev` writes `vaRuleVersions/va-rules` and `vaKnowledgeSources/decision-reviews`. The client cannot write them. Dev may replace this id. Production refuses to replace an active rule. The dev snapshot was published on 2026-10-04.

## Step 20 — Self-submission

Expanded from handoff section 2A.4 and build-sequence item 20. There is no VA filing API. The digital package is not generated yet. That generation stays the paid step.

- [x] **20A** `/package` says the package is not generated yet and opens Plans for that case. Buying is not open.
- [x] **20B** `/package/submit` tells the Veteran to submit on VA.gov or by mail, names a draft review when one exists, and links to the current VA pages. It does not fill a form, sign it, or file it.
- [x] **20C** The Veteran can mark that they opened the VA instructions and saved the VA confirmation. That mark is not a VA receipt. The checklist rule receives the account id and is on the dev project.

## Step 21 — Task reminders

Expanded from handoff section 2A.14 and the notification note in `docs/page-navigation.md`. Exam reminders stay as they are. There is no inbox, no email, and no text message beyond sign-in.

- [x] **21A** Once a day, an open claim step can send "You have an upcoming Veteran Claims Buddy task." The lock screen does not include the step title.
- [x] **21B** Turning off task reminders skips it. A scheduled deletion skips it. Opening the notification goes to that claim's task page. The website still does not register for push.
- [x] **21C** The daily job is on the dev project.

## Step 23 — Checks

Expanded from handoff section 2A.22 and build-sequence item 23. A change is checked without deploying and without a store account.

- [x] **23A** GitHub Actions runs `flutter analyze` and `flutter test` with Flutter 3.47.5, the same version as the FVM pin.
- [x] **23B** The same workflow runs the Node script tests, `dev:verify`, and the Cloud Functions tests on Node 22. It does not deploy.
- [ ] **23C** TestFlight, Google Play internal testing, and a production web deploy stay with the owner. They are not started.

## Step 24 — Production launch

Expanded from handoff sections 2A.22 and 2A.25 and build-sequence item 24. These wait for the owner. None of them are required before the next code change.

- [ ] **24A** Production APNs, the production Android upload key, and the website push certificate stay closed.
- [ ] **24B** Domain connection for `veteranclaimsbuddy.com` stays closed.
- [ ] **24C** Legal review of `docs/legal/` stays closed. The drafts are not a public site yet.
- [ ] **24D** Commerce gates 38A through 38E stay closed. `/plans` remains the only sales page, and buying is not open.

## Step 22 — Account purge

Expanded from handoff section 2A.18. Scheduling deletion and the 30-day wait are already in the app. This step removes the account after that wait.

- [x] **22A** Once a day, accounts with `accountStatus` `deletionScheduled` and a `purgeAfter` time that has passed are removed.
- [x] **22B** The job deletes that user's Firestore records, files under `users/{uid}/`, and the Auth user. A future purge time is left alone. Reactivation clears the schedule, so that account is not deleted.
- [x] **22C** The job does not delete `vaRuleVersions`, `vaKnowledgeSources`, or questionnaire definitions. There is no billing collection yet. The job is on the dev project.

## Step 13 — Document reading

Expanded from handoff sections 27, 28, and 37.0. A file is stored first. Page count does not read the words. Facts wait until Vertex can be called. Google Document AI is not used. The client cannot mark a file as read.

- [x] **13A** A saved PDF at `users/{uid}/documents/{id}/original.pdf` gets `pageCount` from `pdf-lib` in Cloud Functions. JPEG and PNG are left alone. The count shows on the document card.
- [x] **13B** A saved PDF, JPEG, or PNG is read once by Gemini on Vertex. Statements are stored on the document. The derived text file holds those statements.
- [x] **13C** Each statement stays unreviewed until the Veteran confirms it, corrects it, or sets it aside. A correction keeps the original wording.
- [ ] **13D** HEIC stays rejected. The prebuilt `sharp` library decodes AVIF, not iPhone HEIC, so those photos cannot be read safely yet. Tracked as `docs/backlog.md` B4.

## Step 14 — Vet Buddy

Expanded from handoff sections 1.6, 2A.12, and 34. The bubble stays on the claim. The reply explains stored records. It does not read the file, file a claim, or write a fact. A Social Security number is refused before it is sent. The safety footer stays on the reply. A session stores the claim snapshot on the first message. `sessionMinutes` in `functions/vet_buddy_config.js` is how long that session stays open after the last message.

- [x] **14A** The bubble takes a question. A callable writes the reply. The client cannot write it.
- [x] **14B** The reply may use issue names, saved file names and kinds, and statements the Veteran confirmed or corrected. It cannot file, decide, or change the claim.
- [x] **14C** A Social Security number or a long account number is refused before it is sent.
- [ ] **14D** A proactive notice, and writing anything from the chat back onto the claim, waits until the Veteran confirms that change. Deferred pending a product decision on what Vet Buddy may propose. Tracked as `docs/backlog.md` B1.
- [x] **14E** A chat session stores the claim snapshot on the first message and reuses it until the session ends. The next message after that reads the claim again and does not include the earlier turns. A reply can open a claim screen. It cannot change the claim.

## Parallel tracks that are not the critical path

- [x] **Brand package.** `/brand` has the mark, wordmark, logo, and icon source. Wide sign-in shows the mark and a short description. Phone stays one column. Store icons are not installed yet.
- [x] **Marketing site.** Static HTML in `/marketing-site`. Home, how it works, pricing, the rating calculator, FAQ, support, and the draft legal pages. Sign-in and get started redirect to the app. The draft banner stays until counsel reviews it. The domain is not connected.
- [ ] **Domain connection.** Owner gate. Connect `veteranclaimsbuddy.com`, `www`, and `app.veteranclaimsbuddy.com` only when the owner is ready to expose production. The agent reads the DNS records Firebase shows at that time and does not invent them.
- [x] **AGENTS.md.** Short summary of handoff sections 1–4 and 2A, plus a pointer at this file and `docs/page-navigation.md`.

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
