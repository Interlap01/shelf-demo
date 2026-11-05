---
name: fixing-ci-failures
description: Read, re-run and fix a MobAI App Builder app's CI runs on GitHub Actions through MobAI's local HTTP API, without the gh CLI or a GitHub token. Covers listing the latest runs and how each ended, reading a failed run's job logs, reproducing the failure on a local device with MobAI, starting CI on a branch after a fix is pushed, re-running only the failed jobs, and waiting for a run to finish. Use when asked to fix, debug or investigate a failing CI run, a red GitHub Actions check, "CI is failing", "why did the tests fail on GitHub", to re-run CI, or to check whether a fix passes on CI.
---

# Fixing CI failures in an App Builder app

App Builder, inside the MobAI desktop app, runs the app's tests on GitHub
Actions (the `mobai-tests.yml` workflow) and holds the GitHub sign-in. You
read and start runs through MobAI's HTTP API; you never need `gh` or a token.
App Builder starts you with:

- `$MOBAI_API_URL`: MobAI's API, for example `http://127.0.0.1:8686`
- `$MOBAI_APP_ID`: the App you work on

```sh
API="${MOBAI_API_URL:-http://127.0.0.1:8686}/api/v1"
APP="$API/apps/$MOBAI_APP_ID"
```

## Routes

| What | Call |
|---|---|
| Latest runs, newest first | `GET $APP/ci/runs` |
| A run's failed jobs' logs (plain text) | `GET $APP/ci/runs/<id>/log` |
| One job's log, failed or not | `GET $APP/ci/runs/<id>/log?job=ios` |
| Run CI on a branch now | `POST $APP/ci/runs` with `{"branch": "fix-checkout"}` (no body: the default branch) |
| Run a run's failed jobs again | `POST $APP/ci/runs/<id>/rerun` |
| Is CI set up | `GET $APP/ci` |

A run looks like this; `status` is `queued`, `waiting`, `in_progress` or
`completed`, and `conclusion` says how a completed one ended (`success`,
`failure`, `cancelled`, `timed_out`):

```json
{"id": 40292257032, "status": "completed", "conclusion": "failure",
 "branch": "main", "event": "push", "url": "https://github.com/acme/shelf/actions/runs/40292257032",
 "startedAt": "2026-10-26T08:26:20Z"}
```

## Fixing a failed run

1. **Read the log.** `curl -s "$APP/ci/runs/<id>/log" > /tmp/ci.log`, then
   search it: the test runner prints `FAIL <test>` with the failing line and
   step, and a summary like `0 passed, 2 failed`. Logs are long; grep them
   instead of reading them whole.
2. **Reproduce it on a device here.** Claim a simulator or emulator, run the
   failing test with MobAI and watch where it stops. A failure that does not
   happen here usually comes from CI's slower machines (a wait that is too
   short) or from code that is on the branch but not in this folder: compare
   with `git log` and `git status`.
3. **Fix the cause**, in the app or in the test, and run the test on the
   device until it passes. Never weaken an assertion just to make it pass.
4. **Hand it back.** Say what failed, why, and what you changed. Do not
   commit or push unless the user asked; App Builder offers them that.

## Checking a fix on CI

Only after the fix is pushed (CI runs what is on GitHub, not this folder):

```sh
curl -s -X POST "$APP/ci/runs" -H 'Content-Type: application/json' -d '{"branch": "fix-checkout"}'
```

The new run shows in `GET $APP/ci/runs` within seconds. A run takes several
minutes; check every 30 seconds or so until it is `completed`, then read its
`conclusion`, and its log if it failed.

For a failure that looks flaky (a timeout, a runner problem), run only the
failed jobs again instead of the whole workflow:

```sh
curl -s -X POST "$APP/ci/runs/<id>/rerun"
```

## Rules

- Never ask for a GitHub token and never use one; MobAI holds the sign-in.
- Do not edit `.github/workflows/mobai-tests.yml` to make a run pass. App
  Builder set it up; if the workflow itself is wrong, say so.
- An answer of 422 carries the reason in `error` (CI not set up, GitHub not
  connected, no failed job in the run); pass it on instead of retrying.
