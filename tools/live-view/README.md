# Live View

Small local web app that periodically pulls screenshots from:

- **MobAI Preview** (`mobai-dev preview screenshot`)
- **Simulators / physical devices** (`mobai screenshot` via the MobAI CLI)

…and renders the latest frame in a phone bezel, with a side rail to pick the source.

## Run

```bash
# optional: start a preview or connect a simulator / phone first
mobai-dev preview run --detach          # preview
# or: mobai-dev sim start --json        # CI simulator
# or: ~/.mobai/bin/mobai-up             # physical iPhone

node tools/live-view/server.mjs
```

Open [http://127.0.0.1:4747](http://127.0.0.1:4747).

In Cursor Cloud Agents, use **Forwarded Ports → Open in internal browser** on port `4747` for a sidebar view.

## Config

| Env | Default | Meaning |
| --- | --- | --- |
| `LIVE_VIEW_PORT` | `4747` | Listen port |
| `LIVE_VIEW_HOST` | `127.0.0.1` | Bind address |
| `LIVE_VIEW_INTERVAL_MS` | `1500` | Poll interval |
| `LIVE_VIEW_PROJECT` | repo root | Project dir for `mobai-dev preview` |
| `MOBAI_BIN` | `~/.mobai/bin` | Where `mobai` / `mobai-dev` live |

## API

- `GET /api/status` — current source, errors, frame sequence
- `GET /api/sources` — refresh preview + `mobai devices list`
- `POST /api/select` — `{ "sourceId", "intervalMs" }`
- `POST /api/capture` — force one capture
- `GET /api/frame` — latest PNG
