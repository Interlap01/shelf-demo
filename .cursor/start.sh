#!/usr/bin/env bash
# Reconnect the tailnet and serve the local MobAI API. Safe to run again.
set -euo pipefail
exec "$HOME/.mobai/bin/mobai-up"
