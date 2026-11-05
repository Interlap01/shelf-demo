---
name: setting-up-mobile-apps
description: Set up a MobAI App Builder app for building, signing, TestFlight, Google Play and CI through MobAI's local HTTP API, one part at a time, without ever handling a key or password, and keep the build commands in mobai.json right. Covers reading what is not set up yet, the simulator and emulator build commands every build runs (mobai.json "build"), the GitHub repository, GitHub Actions iOS builds, local build tools, iOS signing (development for the user's iPhones, store for TestFlight), the Android upload keystore, the App Store Connect and Google Play keys, the CI tests workflow, MobAI's skills, a simulator on another Mac over SSH, plus passing on steps only the user can take. Use when asked to set up, configure, connect or prepare an app for builds, signing, TestFlight, App Store Connect, Google Play, CI or GitHub Actions, "set up everything", "why can't I build for iOS", "make TestFlight work", "add my iPhone to the profile", "run the simulator on my Mac mini", when creating the app's project or changing how it builds (scheme, target, flavor, folder, pods), or when another step fails because something is not set up.
---

# Setting up an App Builder app

App Builder, inside the MobAI desktop app, sets every part of an app up
itself: it writes workflows, saves repository secrets, makes keystores and
signing sets, creates the Testing project. It never commits or pushes for
you. When a call needs a file on GitHub (a workflow), MobAI writes it into
the folder and the call fails (422) naming it: commit it, push it to the
default branch, then call again. A change the call made in the folder and
went on without (mobai.json) is listed in its answer's `uncommitted` (after
the error sentence when it failed): commit and push it too. Ask the user in
the chat first when you want their yes. You call
one setup per part over MobAI's HTTP API and read what it did. App Builder
starts you with:

- `$MOBAI_API_URL`: MobAI's API, for example `http://127.0.0.1:8686`
- `$MOBAI_APP_ID`: the App you work on

```sh
API="${MOBAI_API_URL:-http://127.0.0.1:8686}/api/v1"
APP="$API/apps/$MOBAI_APP_ID"
```

## Rules

1. **Never ask for a key, token or password, and never handle one.** When a
   part needs the App Store Connect key, the Google Play key, a GitHub
   sign-in, a MobAI token or a new repository's name, its setup opens
   MobAI's own form in the user's window. You never see what they enter.
2. **Never write secrets to disk.** No keys, keystores or passwords in the
   repo, `.env` files, `gradle.properties`, `build.gradle` or Xcode
   settings. Signing reaches builds through MobAI and repository secrets.
3. **Read the `note`.** Every setup says what MobAI set up and what you may
   change. Keep what it says to keep: workflow file names, inputs, secret
   names, profile names.
4. **A call that opens a form answers at once** with status 202 and
   `{"waiting": "..."}`. When the user answers the form, a message says how
   they answered.
5. **Keep the build commands in mobai.json right. This is not optional.**
   Every build of the app runs them: App Builder's simulator, emulator,
   iPhone, TestFlight and Google Play builds, the user's other Macs, CI and
   GitHub iOS builds. Whenever you create the app's project, or change
   anything a build depends on (scheme, target, product name, flavor,
   folder layout, pods, a build step), set or update every entry for each
   platform (debug, device, release, simulatorRelease, releaseApk), run the
   debug one yourself and check the app
   it names exists. A wrong or missing entry breaks builds everywhere. See
   "Build commands" below.

## Build commands (mobai.json)

`mobai.json` sits at the app's folder (or a folder above it in the same
repository, for monorepos) and is committed. Its `build` says how the app
builds, per platform: `debug` for an iOS simulator and an Android emulator
or phone, `device` for a Debug build for iPhones (what Run on device installs
and hot reloads; a `.app` is packed into the IPA), `release` for the stores
(an IPA, also used for Release iPhone builds; an Android App Bundle),
`simulatorRelease` for a Release `.app` the iOS simulator runs and
`releaseApk` for a Release APK phones and emulators install. The last two
are what the CI tests and Run's Release mode run. Flutter has no
`simulatorRelease`: it builds only Debug for the simulator, so CI tests a
Flutter app's Debug build there.

```json
{
  "project": "<Testing project id>",
  "build": {
    "ios": {
      "debug": {"command": "xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Debug -sdk iphonesimulator -derivedDataPath build build", "app": "build/Build/Products/Debug-iphonesimulator/*.app"},
      "device": {"command": "xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Debug -destination generic/platform=iOS -derivedDataPath build -allowProvisioningUpdates build", "app": "build/Build/Products/Debug-iphoneos/*.app"},
      "release": {"command": "xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Release -destination generic/platform=iOS -archivePath build/App.xcarchive -allowProvisioningUpdates archive && xcodebuild -exportArchive -archivePath build/App.xcarchive -exportOptionsPlist \"$MOBAI_EXPORT_OPTIONS\" -exportPath build/ipa -allowProvisioningUpdates", "app": "build/ipa/*.ipa"},
      "simulatorRelease": {"command": "xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Release -sdk iphonesimulator -derivedDataPath build build", "app": "build/Build/Products/Release-iphonesimulator/*.app"}
    },
    "android": {
      "debug": {"command": "./gradlew assembleDebug", "app": "app/build/outputs/apk/debug/*.apk"},
      "release": {"command": "./gradlew bundleRelease", "app": "app/build/outputs/bundle/release/*.aab"},
      "releaseApk": {"command": "./gradlew assembleRelease", "app": "app/build/outputs/apk/release/*.apk"}
    }
  }
}
```

- `command` runs with bash in the folder holding mobai.json. Keep it one
  short line (`cd apps/mobile && ...` for a project below that folder).
- `app` is the built `.app`, `.apk`, `.ipa` or `.aab`, relative to the same
  folder; `*` matches any name and the newest match wins.
- **Signing never goes in the file or the project.** MobAI passes it in: an
  iOS release command exports with `-exportOptionsPlist "$MOBAI_EXPORT_OPTIONS"`
  (Flutter: `flutter build ipa --export-options-plist "$MOBAI_EXPORT_OPTIONS"`),
  which MobAI writes for the build (development or App Store); on GitHub
  the signing also arrives through `XCODE_XCCONFIG_FILE`. An Android
  release command is any Gradle release task: MobAI hands Gradle the upload
  keystore through its injected signing properties (the CI workflow, a
  throwaway key it makes on each run).
- React Native and Expo debug builds use the Debug configuration, so
  MobAI's hot reload works. The app loads its JavaScript from Metro, which
  MobAI runs for hot reload sessions. Release builds carry their
  JavaScript, so the CI tests run without Metro.
- Keep every other field (`project`, `name`, anything unknown) as it is.

Check the debug entry before you commit it (a release build needs MobAI's
signing; build it from MobAI's header or `POST $APP/builds`):

```sh
cd "<folder holding mobai.json>"
bash -c "$(jq -r .build.ios.debug.command mobai.json)" && ls -d $(jq -r .build.ios.debug.app mobai.json)
```

Commit mobai.json with your change. The user can also edit the commands in
MobAI (App menu, Build commands).

## Step 1: what is not set up

```sh
curl -s "$APP"
```

Its `setup` field lists every part that applies to the app:

```json
[
  {"area": "repo", "ready": true, "message": "On GitHub as acme/shelf."},
  {"area": "release", "target": "testflight", "ready": false, "message": "Add an App Store Connect API key to upload."},
  {"area": "ci", "ready": false, "message": "MobAI will create a Testing project for Shelf. ..."}
]
```

Set up the parts that are not `ready` and that the user asked for. "Set up
everything" means every part in the list.

## Step 2: set up a part

Each part has a state and a setup:

```sh
curl -s "$APP/release/testflight"                       # state
curl -s -m 600 -X POST "$APP/release/testflight/setup"  # setup
```

| Part | State | Setup does | May ask the user for |
|---|---|---|---|
| Repository | `GET $APP/repo` | makes a GitHub repository and pushes the folder | GitHub sign-in, the repository's owner, name and visibility |
| GitHub iOS builds | `GET $APP/build/github` | adds or updates the iOS build workflow on the default branch | GitHub sign-in, a repository |
| Local builds | `GET $APP/build/local` | checks this machine's build tools | nothing: missing tools come back as a `userAction` |
| iOS signing | `GET $APP/signing/ios?type=development` | `{"type": "development"}` (the user's connected iPhones) or `{"type": "store"}`, with `"method"`: `"key"` (the ASC Key: certificate, profile, repository secrets, mobai.json), `"files"` (the user's own files saved in App Builder) or `"appleid"` (development only, signed on this computer at install); without `method`, the one the user picked (`details.method`) | App Store Connect key |
| Android signing | `GET $APP/signing/android` | makes the upload keystore | nothing |
| TestFlight | `GET $APP/release/testflight` | checks the key with Apple, sets up store signing and the workflow (GitHub builds), checks the app record | App Store Connect key |
| Google Play | `GET $APP/release/play` | makes the keystore if missing, checks with Google that the key may release the app | Google Play key |
| CI | `GET $APP/ci` | Testing project, `MOBAI_API_KEY` secret, `.github/workflows/mobai-tests.yml` | GitHub sign-in, a repository |
| Skills | `GET $APP/skills` | adds MobAI's skills to the app's folder | nothing |

Setup takes options as a JSON body; only iOS signing has one (`type`). Every
setup is safe to call again: what is already there is kept, an expired
certificate or profile is replaced, and a newly connected iPhone is added to
the development profile.

## Step 3: read the answer

```json
{
  "area": "build", "target": "github", "ready": true,
  "message": ".github/workflows/ios-build.yml is on main in acme/shelf.",
  "details": {"workflow": ".github/workflows/ios-build.yml", "branch": "main"},
  "note": "MobAI added .github/workflows/ios-build.yml on main in acme/shelf. ... keep its file name, its inputs and the secret names."
}
```

| Field | What to do |
|---|---|
| `ready: true` + `note` | done; tell the user the note in a sentence, follow its "keep" list if you edit files |
| `userAction` | a step only the user can take (create the app in App Store Connect, invite the service account in Play Console, merge a pull request, install a tool). Give them `userAction.text` and `userAction.link`, then call the setup again when they say it is done |
| `cancelled: true` | the user closed MobAI's form; stop and ask them whether to go on |
| `{"error": "..."}` (422) | App Builder's own sentence; act on it or tell the user |

## Order

Parts depend on each other; each setup takes the steps before it on its own
(a CI setup on a folder without a repository asks for one first), so this
order only avoids surprises:

1. `skills`
2. `repo`, when the user wants GitHub builds, CI or iOS builds without Xcode
3. `build/local`, or `build/github` for iOS on a machine without Xcode
   (`GET $APP` shows `ios.buildsOn`)
4. `signing/ios` with `development` to run builds on the user's iPhones
   (GitHub builds), `signing/android`
5. `release/testflight`, `release/play`
6. `ci`

On a Mac with Xcode, local iOS builds sign with Xcode's own account: skip
`build/github` and `signing/ios` unless the user wants GitHub builds or CI
to sign.

## A simulator on another Mac

Any Mac with Xcode (a Mac mini, a rented one) can run the app's simulator
for MobAI with `mobai-ci share`. MobAI's "Use another Mac" (the device menu
of an agent session) shows the commands with the user's API key; the
simulator then shows up in MobAI's devices, and rebuilds from MobAI send the
folder as it is and build it there with the mobai.json command.

When the user asks you to start it on a Mac you can reach over SSH, never
put the API key in a command you run or a file you write: ask the user to
save it on that Mac once, as `~/.config/mobai/api-key` (the key is in Use
another Mac). Then:

```sh
HOST=mac-mini.local                        # what the user named
REPO=https://github.com/acme/shelf.git     # git remote get-url origin
ssh "$HOST" 'command -v mobai-ci || brew install mobai-app/tap/mobai-ci'
ssh "$HOST" "test -d shelf || git clone $REPO shelf"
ssh "$HOST" 'cd shelf && nohup env MOBAI_API_KEY="$(cat ~/.config/mobai/api-key)" mobai-ci share --keep > ~/mobai-share.log 2>&1 &'
ssh "$HOST" 'grep -m1 "device shared\|error" ~/mobai-share.log'   # repeat until it prints
```

- A simulator must be running there first: if the log says "no running
  device found", ask the user to open Simulator on that Mac, or boot one
  with `xcrun simctl boot "<name>"` over SSH.
- `--keep` keeps it shared until stopped: `ssh "$HOST" 'pkill -INT -f "mobai-ci share"'`.
- The device appears in `GET $API/devices` with its Mac's name.

## Do NOT

- Do NOT leave mobai.json's build commands out of date after changing how
  the app builds, and do NOT replace one the user set with your own guess
  without checking it builds.

- Do NOT ask the user to paste a key, a token, a password or a keystore
  into chat, a file or a terminal.
- Do NOT create workflows, secrets, keystores or profiles by hand while a
  setup exists for them; call the setup and edit what it made if needed.
- Do NOT rename what a note says to keep.
- Do NOT upload or release from this skill. Uploading to TestFlight or
  Google Play is the releasing-mobile-apps skill's job, with the user's yes.
