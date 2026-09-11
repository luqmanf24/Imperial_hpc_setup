# ---- ble.sh: inline history autosuggestions + syntax highlighting (part 1/2) ----
#
# PART 1 OF 2. The other half is shell/99-blesh-attach.sh, and the split is
# deliberate: ble.sh must be SOURCED before anything touches the prompt, but
# ATTACHED after starship has installed its own prompt hooks. Sourcing with
# --noattach here and calling ble-attach at the very end is what lets the two
# coexist. Collapse them into one block and you get a broken or doubled prompt.
#
# Guarded on an interactive shell and on the file existing, so a machine without
# ble.sh degrades to plain bash instead of erroring on every new terminal.

if [ "${ENABLE_BLESH:-1}" = "1" ]; then
    [[ $- == *i* ]] && [[ -f "$HOME/.local/share/blesh/ble.sh" ]] \
        && source "$HOME/.local/share/blesh/ble.sh" --noattach
fi
