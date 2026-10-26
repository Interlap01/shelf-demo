---
name: releasing-mobile-apps
description: Ship a MobAI App Builder app to TestFlight and Google Play through MobAI's local HTTP API, both platforms on the same version, and get it through review the first time. Covers reading what is set up, bumping version and build numbers, verifying a build on a device first, signed store builds and uploads for iOS and Android, following progress, what App Builder leaves to the user in App Store Connect and Play Console, the checklists both stores reject on, and reading a rejection. Use when asked to release, ship, publish, submit, upload to TestFlight, App Store Connect or Google Play, push to the internal, closed, open or production track, bump the version or build number, "send it to review", "why was the app rejected", "is it live", or anything about TestFlight, App Review, Play Console or store listings.
---

# Releasing to TestFlight and Google Play

App Builder, inside the MobAI desktop app, builds, signs and uploads. You
drive it over MobAI's HTTP API. App Builder starts you with two variables:

- `$MOBAI_API_URL`: MobAI's API, for example `http://127.0.0.1:8686`
- `$MOBAI_APP_ID`: the App you work on

```sh
API="${MOBAI_API_URL:-http://127.0.0.1:8686}/api/v1"
APP="$API/apps/$MOBAI_APP_ID"
```

Errors come back as `{"error": "..."}`, App Builder's own sentence, usually
with status 422. Read it and act on it; it says what to do.

Three rules before anything else:

1. **Never ask for credentials in chat.** The App Store Connect API key,
   the Google Play service account key and the Android upload keystore are
   added by the user in App Builder, and live in the OS keychain. Never
   write a password, key or keystore into the repo, `build.gradle`,
   `gradle.properties` or an env file.
2. **Confirm before anything leaves this machine.** An upload to TestFlight
   or Google Play, and above all the `production` track, needs the user's
   yes. A local iOS store build lets Xcode create profiles in the user's
   Apple account: ask before the first one.
3. **Read state, do not guess.** `GET $APP` says what is set up and what
   the last upload did. Store review outcomes are read from the stores'
   text, not predicted.

## Step 1: what is set up

```sh
curl -s "$APP"
```

| Field | Meaning |
|---|---|
| `ios.buildsOn` | `xcode` (this Mac builds) or `github` (GitHub Actions builds) |
| `ios.kinds`, `android.kinds` | build kinds `POST $APP/builds` accepts; `android.kinds` gains `release` once a keystore exists |
| `ios.ready`, `ios.message` | whether an iOS build can start, and what is missing |
| `testflight.step` | `signing`, `asc` or `ready`; `message` says the missing piece |
| `testflight.last` | last upload from here: `version`, `buildNumber`, `state`, `link`, `error` |
| `play.step` | `signing`, `key` or `ready` |
| `play.account` | the service account email the user invites in Play Console |
| `play.last` | last upload from here: `versionCode`, `track`, `status`, `error` |
| `activeBuild` | the build running now, or null |

A step that is not `ready` is the user's to finish in App Builder. Tell them
the `message` and where:

| Step | The user does |
|---|---|
| `testflight.step: signing` | sets up App Store signing (GitHub builds only; on a Mac with Xcode, Xcode signs with its own account) |
| `testflight.step: asc` | adds an App Store Connect API key in the TestFlight dialog: a team key, role App Manager or Admin |
| `play.step: signing` | makes or imports an upload keystore in the Google Play dialog |
| `play.step: key` | adds a Google Play service account JSON key, then invites `play.account` in Play Console, Users and permissions, with release rights for this app |

The store records are the user's too: an app in App Store Connect with the
project's bundle ID, an app in Play Console with its package name. Google
takes a new app's first bundle only through Play Console: the user uploads
that one by hand (App Builder's Builds tab shows the file), and every later
one goes through `POST $APP/play`.

Releases need MobAI Pro. An error that says so is for the user to act on.

## Step 2: version and build numbers, both platforms

Neither store takes a build number it already has, and App Builder does not
bump them. Before every store build, raise them in the project:

| Framework | Version | Build number |
|---|---|---|
| Flutter | `pubspec.yaml` `version: 1.4.0+27` (before the `+`) | after the `+`; both platforms read it |
| Expo | `app.json` `expo.version` | `expo.ios.buildNumber`, `expo.android.versionCode` |
| React Native | iOS `MARKETING_VERSION`, Android `versionName` | iOS `CURRENT_PROJECT_VERSION`, Android `versionCode` |
| Native iOS | `MARKETING_VERSION` | `CURRENT_PROJECT_VERSION` |
| Native Android | `versionName` in `app/build.gradle(.kts)` | `versionCode` |

React Native and native iOS projects may hard-code `CFBundleShortVersionString`
and `CFBundleVersion` in `Info.plist` instead of using the build settings;
change whichever the project uses.

The rule that keeps both stores happy: one build number for both platforms,
one above the highest of `testflight.last.buildNumber` and
`play.last.versionCode`. If a store still says the number is taken (an
upload from another machine), go higher. `versionCode` is an integer that
only grows. Keep the marketing version the same on both platforms.

## Step 3: check the build on a device first

A store build cannot be installed (an App Store IPA, a release App Bundle),
so prove the same commit on a simulator or emulator first:

```sh
curl -s -X POST "$APP/builds" -d '{"platform":"ios","kind":"simulator"}'   # or "development" on a phone
curl -s -X POST "$APP/builds" -d '{"platform":"android","kind":"debug"}'
curl -s "$APP/builds/active"                    # poll until phase is done or failed
curl -s "$APP/builds"                           # the finished build's id
```

Install it on a device you claimed (the `controlling-mobile-devices` skill
covers driving it):

```sh
curl -s -X POST "$API/devices/claim" -d "{\"device\":\"<device id>\",\"owner\":\"$MOBAI_CLAIM_OWNER\"}"
# answers {"deviceId": ..., "leaseToken": ...}; send the token on device calls
curl -s -X POST "$APP/builds/<build id>/install" -H "X-Lease-Token: <leaseToken>" \
  -d '{"device_id":"<device id>"}'
```

On GitHub-built iOS, `ios.kinds` lists `unsigned` and the signing profiles
that are set up; an unsigned build does not install anywhere.

## Step 4: build and upload

Only one build of an App runs on this machine at a time, so the platforms go
one after the other.

```sh
curl -s -X POST "$APP/testflight"                          # iOS: store build, then the upload
curl -s -X POST "$APP/play" -d '{"track":"internal"}'      # Android: signed App Bundle, then the upload
```

Play tracks: `internal` (the default, up to 100 testers, out in minutes),
`alpha` (closed testing), `beta` (open testing), `production`. A
`production` upload goes to every user once Google approves it; never pick
it without the user saying so.

Follow progress, every 20 to 30 seconds:

```sh
curl -s "$APP/builds/active"
```

`active.phase` is `starting`, `running`, `downloading` (GitHub builds),
`uploading`, then `done` or `failed`, with `message`. A store build takes
several minutes; App Store Connect processing adds more. Then read the
result:

```sh
curl -s "$APP/testflight"     # last: state, link, error
curl -s "$APP/play"           # last: versionCode, track, status, error
```

## Both platforms ship together

When the App targets iOS and Android, a release means both stores:

- [ ] Version and build number raised once, the same on both
- [ ] Both checked on a device (Step 3)
- [ ] TestFlight upload `done`, `last.error` empty
- [ ] Play upload `done`, `last.error` empty
- [ ] Both store checklists walked before the first public release

If one platform fails, stop and report it with its error. Do not ship one
platform quietly; the user decides whether one platform goes out alone.

## What App Builder does not do

It uploads. The rest is the user's, in the stores' consoles:

- **App Store Connect**: TestFlight groups and testers, export compliance
  if Info.plist does not answer it, the version's listing, submitting for
  App Review, pressing Release.
- **Play Console**: the store listing, Data safety, content rating, target
  audience, app access for reviewers, promoting a release between tracks,
  staged rollout percentages.

Offer to draft listing text, Notes for Review and Data safety answers from
the code; the user pastes them.

## Before the first public release: the checklists

Both stores reject on a short list of the same things. Walk the checklist
with the user before the first App Review or production release:

- iOS: `./app-store-checklist.md`
- Android: `./google-play-checklist.md`

The short version, both stores: a demo account in the review notes if there
is a login; in-app account deletion if there are accounts; digital unlocks
through the store's billing; a privacy policy linked in the listing and in
the app; permission prompts that name the feature; the privacy answers
(App Privacy, Data safety) matching the code and every SDK; no placeholder
screens or dead links.

A rejection: `./reading-a-rejection.md`.

## Failures

| App Builder says | Do |
|---|---|
| a build of this app is already running | wait for `builds/active` to reach `done` or `failed` |
| choose where this app lives on this machine | the user picks the folder in App Builder |
| this machine has no Xcode; iOS builds run on GitHub here | use the GitHub kinds in `ios.kinds` |
| Xcode could not sign the app | the user signs into Xcode (Settings, Accounts) and picks a team under Signing & Capabilities |
| this app has no upload keystore yet | the user makes or imports one in the Google Play dialog |
| Google Play has no app ... for this account | the user creates the app in Play Console and uploads its first bundle by hand |
| the service account cannot release ... | the user invites `play.account` in Play Console with release rights |
| Play: version code already used, Apple: bundle version must be higher | raise the build number (Step 2) and upload again |
| needs MobAI Pro | the user upgrades; nothing to work around |

A build that failed on this machine has `build.logPath`, in the `failed`
event and in `GET $APP/builds`: a file with the log's last lines. Read it
before changing anything. A GitHub build has `runUrl` instead.

## Do not

- Do not write signing passwords or a `signingConfigs` block with secrets
  into the project. App Builder injects signing at build time.
- Do not commit the keystore. Remind the user to back it up: a lost upload
  key is a reset request to Google, which takes days.
- Do not upload to `production` or ask the user to submit for App Review
  before the checklist is walked and they say the listing is complete.
- Do not resubmit a rejected build unchanged. Read the rejection first.
