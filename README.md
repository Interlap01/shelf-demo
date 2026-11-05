# Shelf

A small SwiftUI store app (sign in, products, cart) used as the demo project for
[MobAI](https://mobai.run): local device automation, tests, CI and cloud agents.

- `Sources/`: the app (iOS 18+). `project.yml` generates `Shelf.xcodeproj` with XcodeGen.
- `tests/`: `.mob` UI tests, run in CI by `.github/workflows/e2e.yml` with `mobai-ci test ./tests`.
- `workflows/`: a plain-text MobAI Workflow (`.mobflow`).
- `.cursor/environment.json`: installs mobai-dev in Cursor background agents.

Test account: any email works, for example `alice@example.com`.
