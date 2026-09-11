#!/usr/bin/env bash
# Install the starship prompt binary into ~/.local/bin and seed its config.
set -euo pipefail

BIN="$HOME/.local/bin/starship"
CFG="$HOME/.config/starship.toml"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$HOME/.local/bin" "$HOME/.config"

if [ -x "$BIN" ]; then
    echo "starship already installed: $("$BIN" --version | head -1)"
else
    echo "==> installing starship into ~/.local/bin ..."
    # Official installer; -b picks the destination, -y skips the confirm prompt.
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
    [ -x "$BIN" ] || { echo "ERROR: $BIN missing after install." >&2; exit 1; }
fi

# Never clobber an existing prompt config -- the user may have tuned it.
if [ -f "$CFG" ]; then
    echo "keeping existing $CFG (repo copy is at config/starship.toml)"
else
    cp "$HERE/config/starship.toml" "$CFG"
    echo "==> wrote $CFG"
fi
