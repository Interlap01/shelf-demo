---
name: slimming-simulators
description: Boot, shut down, create, clone, erase, delete and slim iOS simulators through MobAI's local HTTP API on a Mac, so automation and parallel runs fit in memory. Slimming turns off background daemons (Siri, Spotlight, photo analysis, iCloud, widgets) a simulator does not need, cutting its memory about 4x, and is opt-in per simulator; boots are always stock. Use when asked to boot or start a simulator, make a fresh or clean simulator, clone one for parallel runs, reset or erase one, delete old ones, run many simulators at once, or when simulators use too much memory, the Mac swaps, "slim a simulator", "disable simulator background daemons", "simulator RAM". Also covers slimming the simulator in a CI workflow (the MobAI-App/mobai-ci action or mobai-ci sim boot), e.g. "slim the simulator in CI", "iOS CI is slow to start". macOS only.
---

# Managing and slimming iOS simulators

MobAI manages simulators on this Mac over its HTTP API. Boot and shutdown
wait for the simulator to settle; clones are repaired and checked. macOS
only, with Xcode and an iOS Simulator runtime installed.

```sh
API="${MOBAI_API_URL:-http://127.0.0.1:8686}/api/v1"
```

Errors come back as `{"error": "..."}`.

## Lifecycle

```sh
curl -s "$API/simulators"                                   # [{udid, name, state, runtime, osVersion}]
curl -s -X POST "$API/simulators/<udid>/boot"               # 204 once booted (up to 2 min on a first boot)
curl -s -X POST "$API/simulators/<udid>/shutdown"           # 204
curl -s -X POST "$API/simulators" -d '{"deviceType":"iPhone 16 Pro","name":"Checkout run"}'
                                                            # 201 {udid, runtime}; the newest iOS runtime that supports the
                                                            # device type, unless "runtime" names one
curl -s -X POST "$API/simulators/<udid>/clone" -d '{"name":"Worker 2"}'   # 201 {udid}
curl -s -X POST "$API/simulators/<udid>/erase"              # 204; apps, data and settings gone
curl -s -X DELETE "$API/simulators/<udid>"                  # 204; the simulator is gone
```

`xcrun simctl list devicetypes` names the device types `deviceType`
accepts. After a boot, MobAI picks the simulator up as a device within a
few seconds; claim it before driving it (`controlling-mobile-devices`).

Erase and delete cannot be undone. Only erase or delete simulators you
created in this task, or ones the user names; never "clean up" others.

## Slimming

A booted simulator runs about 180 background daemons that development and
testing never need. Slimming disables the ones in simslim's allowlist:
roughly 4.0 GB stock against 0.9 GB slim, so several times as many
simulators fit on one Mac. It is opt-in, persistent and reversible:

```sh
curl -s "$API/simulators/<udid>/slim"           # booted simulators only; 422 when shut down
# {slim, managedDisabled, managedTotal, booted, persistent}
curl -s -X POST "$API/simulators/<udid>/slim" -d '{"enabled":true}'
curl -s -X POST "$API/simulators/<udid>/slim" -d '{"enabled":false}'      # back to stock
```

Turning it on or off reboots the simulator, which takes seconds. The
setting lives in the simulator's own launchd database, so later boots come
up slim in one boot. `changed: false` means it was already in that state.

Suggest slimming when the user runs several simulators or the Mac is short
on memory. Do not slim a simulator the user did not ask about, and do not
slim by default: the user decides.

### Keeping what a workload needs

Slimming turns features off. Keep whole categories with `except`, or single
daemons with `keep`:

```sh
curl -s -X POST "$API/simulators/<udid>/slim" -d '{"enabled":true,"except":"store,web"}'
curl -s -X POST "$API/simulators/<udid>/slim" -d '{"enabled":true,"keep":"com.apple.apsd"}'
```

| Category | Keep it when the app needs |
|---|---|
| `store` | push notifications, StoreKit testing, App Store, media |
| `web` | universal links, associated domains, web push |
| `search` | Spotlight or in-Settings search |
| `pim` | Contacts, Calendar, Reminders, Mail pickers |
| `photos` | the photo library or photo picker with real content |
| `icloud` | iCloud sync, the Apple Account, iCloud Keychain |
| `health` | HealthKit, HomeKit, Fitness |
| `siri` | Siri, speech, on-device ML services |
| `widgets` | widgets, Live Activities, wallpaper |
| `messaging` | iMessage, FaceTime, calls |
| `connectivity` | AirDrop, Continuity, CarPlay, Watch, Find My |
| `family` | Family Sharing, Screen Time |
| `apps` | News, Weather, Maps, Tips, Game Center |
| `telemetry` | DeviceCheck, ad attribution, diagnostics and feedback |
| `other` | Wallet and passes, other background services |

Daemons that wedge a simulator when disabled are never touched, even with
`keep` or `except`.

## Slimming in CI

CI simulators boot stock too, from the `MobAI-App/mobai-ci` action's
`boot-sim` or from `mobai-ci sim boot`. Add slimming to a workflow only when
the user asks for it. Suggest it, without adding it, when iOS runs are slow
to start, for example when the test runner waits minutes on a freshly booted
simulator, or when several simulators share one runner.

To turn off only some services, use `sim-slim-only` with category ids from
the table above, or launchd labels, comma-separated. `widgets` is the usual
choice: on a small runner, a fresh simulator's widget and wallpaper
extensions are what keep the runner waiting.

```yaml
- uses: MobAI-App/mobai-ci@v1
  with:
    boot-sim: true
    sim-slim-only: widgets
```

To slim everything except what the tests use, commit a simslim profile and
point `sim-slim` at it. `except` and `keep` work like the HTTP API's:

```json
{ "name": "ci", "except": ["store", "web"] }
```

```yaml
- uses: actions/checkout@v7          # the path is relative to the checkout
- uses: MobAI-App/mobai-ci@v1
  with:
    boot-sim: true
    sim-slim: ci/slim.json
```

- A workflow that runs mobai-ci directly passes the same values as
  `mobai-ci sim boot --slim-only widgets` or `--slim ci/slim.json`.
- `sim-slim` and `sim-slim-only` cannot be combined.
- Editing the profile keeps the simulator cache, and the next run applies
  the new profile.
- Android emulators have nothing to slim; leave Android jobs as they are.

## Typical flows

**A clean simulator for a test run:** create it, boot it, run, then delete
it when the run is done.

**Parallel workers:** boot and slim one simulator, install the app, then
clone it once per worker; clones keep the slim setting and the installed
app.

**Back to stock** before testing anything that touches a slimmed feature:
`{"enabled":false}`, or erase the simulator.

## Do not

- Do not disable daemons by hand with `xcrun simctl spawn launchctl`; the
  allowlist exists to avoid the ones that wedge a simulator.
- Do not boot many simulators at once on a small Mac without asking; each
  stock simulator takes about 4 GB.
- Do not delete or erase a simulator you did not create unless the user
  names it.
