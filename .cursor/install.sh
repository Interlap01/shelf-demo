#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for Shelf.
# mobai-dev previews the SwiftUI app on Linux. Swift 6.3.3 matches the
# preview engine's prebuilt modules. The engine download needs a MobAI login
# already stored on the machine (mobai-dev login) or MOBAI_API_KEY.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y libncurses6 g++ libstdc++-13-dev

if [ ! -e /usr/lib/x86_64-linux-gnu/libstdc++.so ]; then
  sudo ln -sfn /usr/lib/gcc/x86_64-linux-gnu/13/libstdc++.so /usr/lib/x86_64-linux-gnu/libstdc++.so
fi

curl -fsSL https://mobai.run/cloud/install.sh | sh

if ! /usr/local/bin/swift --version 2>/dev/null | head -1 | grep -q 'Swift version 6.3.3'; then
  tmp="$(mktemp -d)"
  (
    cd "$tmp"
    curl -fsSL -O "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz"
    tar zxf "swiftly-$(uname -m).tar.gz"
    ./swiftly init --assume-yes --skip-install --no-modify-profile --quiet-shell-followup
    # shellcheck disable=SC1091
    . "$HOME/.local/share/swiftly/env.sh"
    swiftly install 6.3.3 --use
  )
  rm -rf "$tmp"
fi

swift_bin="$(readlink -f "$HOME/.local/share/swiftly/bin/swift")"
sudo ln -sfn "$swift_bin" /usr/local/bin/swift
sudo ln -sfn "$(dirname "$swift_bin")/swiftc" /usr/local/bin/swiftc

"$HOME/.mobai/bin/mobai-dev" setup --framework swiftui

if "$HOME/.mobai/bin/mobai-dev" login >/dev/null 2>&1; then
  MOBAI_ACCEPT_APPLE_DESIGN_LICENSES=1 "$HOME/.mobai/bin/mobai-dev" engines install swiftui
else
  echo "mobai-dev is installed, but there is no MobAI login yet."
  echo "Sign in with: ~/.mobai/bin/mobai-dev login --email <email>"
  echo "Then re-run this script to install the SwiftUI preview engine."
fi
