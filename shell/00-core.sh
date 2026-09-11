# ---- PATH ------------------------------------------------------------------
# ~/.local/bin is where the no-root installs land (starship, and anything you
# `pip install --user`). Prepended so they beat the system copies.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# ---- persistent, shared shell history --------------------------------------
# The default bash behaviour -- last shell to exit wins, everything else's
# history discarded -- is miserable when you keep several tunnel terminals open.
export HISTFILE="$HOME/.bash_history"
export HISTSIZE=100000
export HISTFILESIZE=200000
export HISTCONTROL=ignoreboth        # no dups, no leading-space cmds
export HISTTIMEFORMAT='%F %T  '      # timestamp each entry
shopt -s histappend                  # append, don't overwrite, on exit
shopt -s cmdhist                     # multi-line cmds as one entry

if [[ ${BLE_VERSION-} ]]; then
    # ble.sh does history sharing itself; the PROMPT_COMMAND hack below fights
    # it and you get duplicated/reordered entries. Use ble.sh's own option.
    bleopt history_share=1
else
    # after every command: append this session's new lines, then reload the file
    PROMPT_COMMAND="history -a; history -n; ${PROMPT_COMMAND}"
fi
