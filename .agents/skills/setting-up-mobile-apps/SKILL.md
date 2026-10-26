---
name: setting-up-mobile-apps
description: Set up a MobAI App Builder app for building, signing, TestFlight, Google Play and CI through MobAI's local HTTP API, one part at a time, without ever handling a key or password. Covers reading what is not set up yet, the GitHub repository, GitHub Actions iOS builds, local build tools, iOS signing (development for the user's iPhones, store for TestFlight), the Android upload keystore, the App Store Connect and Google Play keys, the CI tests workflow and MobAI's skills, plus passing on steps only the user can take. Use when asked to set up, configure, connect or prepare an app for builds, signing, TestFlight, App Store Connect, Google Play, CI or GitHub Actions, "set up everything", "why can't I build for iOS", "make TestFlight work", "add my iPhone to the profile", or when another step fails because something is not set up.
---

# Setting up an App Builder app

App Builder, inside the MobAI desktop app, sets every part of an app up
itself: it commits workflows, saves repository secrets, makes keystores and
signing sets, creates the Testing project. You call one setup per part over
MobAI's HTTP API and read what it did. App Builder starts you with:

- `$MOBAI_API_URL`: MobAI's API, for example `http://127.0.0.1:8686`
- `$MOBAI_APP_ID`: the App you work on

```sh
API="${MOBAI_API_URL:-http://127.0.0.1:8686}/api/v1"
APP="$API/apps/$MOBAI_APP_ID"
```

## Rules

1. **Never ask for a key, token or password, and never handle one.** When a
   part needs the App Store Connect key, the Google Play key, a GitHub
   sign-in or a new repository's name, its setup opens MobAI's own form in
   the user's window and waits. Tell the user to look at MobAI. You only
   hear whether they finished it.
2. **Never write secrets to disk.** No keys, keystores or passwords in the
   repo, `.env` files, `gradle.properties`, `build.gradle` or Xcode
   settings. Signing reaches builds through MobAI and repository secrets.
3. **Read the `note`.** Every setup says what MobAI set up and what you may
   change. Keep what it says to keep: workflow file names, inputs, secret
   names, profile names.
4. **A setup can wait minutes** while the user fills a form. Give curl a
   long timeout (`-m 600`) and do not retry while it waits.

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
| iOS signing | `GET $APP/signing/ios?type=development` | `{"type": "development"}` (the user's connected iPhones) or `{"type": "store"}`: certificate, profile, repository secrets, builder.json | App Store Connect key |
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

## Do NOT

- Do NOT ask the user to paste a key, a token, a password or a keystore
  into chat, a file or a terminal.
- Do NOT create workflows, secrets, keystores or profiles by hand while a
  setup exists for them; call the setup and edit what it made if needed.
- Do NOT rename what a note says to keep.
- Do NOT upload or release from this skill. Uploading to TestFlight or
  Google Play is the releasing-mobile-apps skill's job, with the user's yes.
