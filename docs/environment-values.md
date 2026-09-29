# Environment values

Non-secret identifiers only. Do not put credentials, API keys, service-account JSON, or passwords in this file.

| Name | Value |
| --- | --- |
| Dev Firebase project id | `veteran-claims-buddy-dev` |
| Prod Firebase project id | `veteran-claims-buddy-prod` |
| Dev Android application id | `com.veteranclaimsbuddy.app.dev` |
| Prod Android application id | `com.veteranclaimsbuddy.app` |
| Dev iOS bundle id | `com.veteranclaimsbuddy.app.dev` |
| Prod iOS bundle id | `com.veteranclaimsbuddy.app` |
| Firestore location | `nam5` (United States multi-region). Same location in dev and prod. |
| Storage location | `us-central1`. Same location in dev and prod. No public read. |
| Cloud Functions region | `us-central1`. Functions cannot be deployed to `nam5`. This region is inside the Firestore multi-region and matches Storage. |
| Firestore edition | Standard edition, Native mode. Not Enterprise. Edition cannot be changed later. |

Phase 2 billing: both projects are on Blaze, and both have budget alerts. Confirmed by the owner on 2026-09-29.
