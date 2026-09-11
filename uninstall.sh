#!/usr/bin/env bash
# Remove the guarded block from ~/.bashrc. Leaves ble.sh, starship, ~/code and
# this repo in place -- delete those yourself if you want them gone.
set -euo pipefail
BASHRC="$HOME/.bashrc"
MARK_BEGIN="# >>> imperial-hpc-setup >>>"
MARK_END="# <<< imperial-hpc-setup <<<"
grep -qF "$MARK_BEGIN" "$BASHRC" || { echo "no imperial-hpc-setup block in $BASHRC"; exit 0; }
cp "$BASHRC" "$BASHRC.bak.hpc-uninstall.$(date +%Y%m%d-%H%M%S)"
awk -v b="$MARK_BEGIN" -v e="$MARK_END" '$0==b{skip=1;next} $0==e{skip=0;next} !skip' "$BASHRC" > "$BASHRC.tmp.$$"
mv "$BASHRC.tmp.$$" "$BASHRC"
echo "removed block from $BASHRC (backup written alongside)"
