# Veteran Claims Buddy

Flutter on iOS, Android, and web. Firebase Auth, Firestore, Storage, and Cloud Functions. Two projects: `veteran-claims-buddy-dev` and `veteran-claims-buddy-prod`. Nothing here files a claim with the VA.

`docs/build-progress.md` is the checklist. `docs/page-navigation.md` wins for screens and routes. `Veteran_Claims_Buddy_Engineering_Handoff.md` is the spec. Section 2A wins when the handoff disagrees with itself.

The assistant inside the product is Vet Buddy. It explains saved records and does not change them. `/plans` is the only Premium versus per-Case sales page. Buying is not open.

Flutter is `fvm flutter` from `app/`, pinned to 3.47.5. Cloud Functions are JavaScript on Node 22. Do not deploy production from an agent turn. Stop when a step needs an Apple, Google, domain, or legal action from the owner.

When a pull request opens a web preview, end the turn after the PR is open. When the Preview action comments the URL, paste that URL in Slack and stop. Do not open the URL. Do not screenshot the page. Do not keep the turn open to check the deploy.
