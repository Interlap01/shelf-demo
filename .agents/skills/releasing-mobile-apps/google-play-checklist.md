# Google Play checklist

Walk this with the user before the first `production` release, and before
the first closed or open test for a new developer account. Google's review
is mostly automated plus spot checks by people, and a policy finding can
suspend an app, not only reject an update. Policy names are from the
Developer Program Policy (https://play.google/developer-content-policy/).
What can only be done in Play Console is marked *user*.

## Account and track

- [ ] The app exists in Play Console with the project's package name (*user*)
- [ ] Its first App Bundle uploaded by hand in Play Console; later ones go through App Builder (*user*)
- [ ] Play App Signing on (the default for new apps): Google holds the app signing key, App Builder's keystore is the upload key
- [ ] The upload keystore file backed up somewhere other than this machine (*user*)
- [ ] A personal developer account created after November 2023 ran a closed test with at least 12 opted-in testers for 14 days in a row before it can apply for production (*user*)
- [ ] The release went to `internal` first and was installed from the Play Store link on a real phone

## Build quality

- [ ] `targetSdk` meets Play's current requirement: Play Console, Policy status names it (API 35 since August 2025, rising each August)
- [ ] Native libraries support 16 KB memory pages (required for apps targeting Android 15 and up): current NDK, current versions of native SDKs
- [ ] No crash on a clean install with every permission denied, offline, and after a process kill
- [ ] The pre-launch report on the internal or closed track read, its crashes fixed (*user* opens it)
- [ ] Release-only failures checked: R8 or ProGuard stripped classes the app reflects on (JSON models, native bridges)
- [ ] No placeholder text, test screens, debug menus or dead links

## Reviewer access (App access)

- [ ] App access in Play Console: instructions and a working demo account if anything is behind a login (*user* enters it)
- [ ] The account tested today, not expiring, not tied to a phone the reviewer does not have

## Money (Payments policy)

- [ ] Digital goods and subscriptions go through Google Play Billing, unless the app is enrolled in an alternative billing program for that region
- [ ] Physical goods and real-world services do **not** use Play Billing
- [ ] The paywall shows price, billing period, renewal, trial terms and how to cancel
- [ ] Purchases restore on a new install (Play Billing's purchase query)

## Accounts and data deletion (User Data policy)

- [ ] In-app account deletion if the app creates accounts
- [ ] A web link where users can ask for their account and data to be deleted without reinstalling, entered in Data safety (*user*)
- [ ] Social logins and tokens revocable

## Privacy (User Data policy)

- [ ] Privacy policy URL in Play Console **and** reachable inside the app
- [ ] Data safety form filled for **every** app, including one that collects nothing, and audited against the code and every SDK (analytics, ads, crash reporting) (*user* submits it)
- [ ] A prominent in-app disclosure before collecting personal or sensitive data that the user would not expect
- [ ] Only the permissions the features need; dropped permissions removed from the merged manifest, not only from `AndroidManifest.xml` (SDKs add their own)

## Sensitive permissions (Permissions policy)

Each of these needs a declaration in Play Console and a core-feature reason,
or the update is refused. Remove what the app does not truly need:

- [ ] `ACCESS_BACKGROUND_LOCATION`: declaration plus a video of the feature
- [ ] `READ_SMS`, `SEND_SMS`, `READ_CALL_LOG` and the rest of the SMS and Call Log group: only for default handlers
- [ ] `MANAGE_EXTERNAL_STORAGE` (All files access), `QUERY_ALL_PACKAGES`, `REQUEST_INSTALL_PACKAGES`
- [ ] `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO`: only when photos are core; otherwise the system photo picker
- [ ] `USE_EXACT_ALARM` or `SCHEDULE_EXACT_ALARM`: alarm and calendar apps only
- [ ] Foreground service types declared for each foreground service, with the declaration form
- [ ] The Accessibility API: only for real accessibility features, with the declaration and an in-app disclosure

## Content and audience

- [ ] Content rating questionnaire answered honestly (*user*)
- [ ] Target audience and content set; children in the audience brings the Families policy (certified ad SDKs only, no precise location, teacher-approved rules)
- [ ] "Contains ads" declared if any ad SDK is present (*user*)
- [ ] User-generated content: a filter, reporting, blocking, and terms users accept
- [ ] Generative AI content: a way for users to report offensive output

## Store listing (Metadata policy)

- [ ] Title 30 characters or fewer; no "best", "#1", "free", prices, emoji or ALL CAPS
- [ ] Short description 80 characters, full description 4,000; no keyword stuffing, no fake testimonials
- [ ] No other app's or brand's name used to rank
- [ ] Icon 512x512, feature graphic 1024x500, at least two phone screenshots of the real app
- [ ] Contact email in the listing; a website if there is one
- [ ] "What's new" describes the actual changes

## The last five minutes

- [ ] `GET $APP/play` shows `last.error` empty and the expected `versionCode`
- [ ] Play Console, Publishing overview: every section green, changes sent for review (*user*)
- [ ] Staged rollout chosen for `production` (a small percentage first) (*user*)
- [ ] The user has said yes to `production`

Sections follow Google's Developer Program Policy; Play Console's Policy
status page is the source of truth for dates and levels.
