#!/usr/bin/env bash
# Fetch the standalone VS Code CLI into ~/code.
#
# Called both by install.sh and by stvsc when it finds the CLI missing, so the
# recovery path and the first-time install cannot drift apart.
set -euo pipefail

CLI="$HOME/code"
TARBALL="$HOME/vscode_cli.tar.gz"

# cli-alpine-x64 is statically linked, so it runs on old glibc cluster images
# (RHEL 8 and friends) where the glibc build refuses to start. Change this only
# if you are on arm64.
URL='https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64'

if [ -x "$CLI" ]; then
    echo "VS Code CLI already present: $("$CLI" --version 2>/dev/null | head -1)"
    exit 0
fi

echo "==> downloading the VS Code CLI..."
if ! curl -Lk "$URL" --output "$TARBALL"; then
    echo "ERROR: download failed." >&2
    echo "       retry: curl -Lk '$URL' --output $TARBALL" >&2
    exit 1
fi

if ! tar -xf "$TARBALL" -C "$HOME"; then
    echo "ERROR: extraction of $TARBALL failed." >&2
    exit 1
fi

if [ ! -x "$CLI" ]; then
    echo "ERROR: $CLI still missing or not executable after extraction." >&2
    echo "       inspect: ls -la $CLI $TARBALL" >&2
    exit 1
fi

rm -f "$TARBALL"
echo "==> installed: $("$CLI" --version 2>/dev/null | head -1)"
