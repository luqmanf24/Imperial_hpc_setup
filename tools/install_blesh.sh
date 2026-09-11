#!/usr/bin/env bash
# Build ble.sh from source into ~/.local -- no root, no package manager.
#
# ble.sh gives bash the inline grey history suggestions (accept with the right
# arrow), syntax highlighting and menu completion that zsh users get from
# zsh-autosuggestions. On a cluster image with no zsh and no conda/spack, this
# is the only route to that.
set -euo pipefail

DEST="$HOME/.local/share/blesh/ble.sh"
SRC="${TMPDIR:-/tmp}/blesh-build-$$"

if [ -f "$DEST" ]; then
    echo "ble.sh already installed at $DEST"
    exit 0
fi

command -v git  >/dev/null || { echo "ERROR: git not found." >&2; exit 1; }
command -v make >/dev/null || { echo "ERROR: make not found." >&2; exit 1; }

echo "==> cloning ble.sh..."
# --recursive is required: the contrib submodule is not optional for the build.
git clone --recursive --depth 1 --shallow-submodules \
    https://github.com/akinomyoga/ble.sh.git "$SRC"

echo "==> building into ~/.local ..."
make -C "$SRC" install PREFIX="$HOME/.local"

rm -rf "$SRC"

[ -f "$DEST" ] || { echo "ERROR: build finished but $DEST is missing." >&2; exit 1; }
echo "==> installed $DEST"
