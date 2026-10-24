# Shelf

A small SwiftUI store app (sign in, products, cart) used as the demo project for
[MobAI](https://mobai.run): local device automation, tests, CI and cloud agents.

- `Sources/`: the app (iOS 18+). `project.yml` generates `Shelf.xcodeproj` with XcodeGen.
- `tests/`: `.mob` UI tests, run in CI by `.github/workflows/e2e.yml` with `mobai-ci test ./tests`.
- `workflows/`: a plain-text MobAI Workflow (`.mobflow`).
- `tools/live-view/`: local web UI that polls MobAI preview / device screenshots for a browser sidebar.
- `.cursor/environment.json`: installs mobai-dev in Cursor background agents.

Test account: any email works, for example `alice@example.com`.

Live screenshot viewer:

```bash
node tools/live-view/server.mjs   # http://127.0.0.1:4747
```
