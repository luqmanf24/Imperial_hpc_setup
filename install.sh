#!/usr/bin/env bash
# =============================================================================
# install.sh -- one command to get the whole workflow on a fresh HPC account.
#
#   bash install.sh                 # everything
#   bash install.sh --skip-blesh    # plain bash line editing
#   bash install.sh --skip-starship # default prompt
#   bash install.sh --skip-cli      # don't fetch the VS Code CLI
#   bash install.sh --no-login      # don't run the interactive GitHub login
#
# Safe to re-run: it never duplicates the ~/.bashrc block, never overwrites
# hpc_setup.conf, and backs up ~/.bashrc before touching it.
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHRC="$HOME/.bashrc"
PROFILE="$HOME/.bash_profile"
MARK_BEGIN="# >>> imperial-hpc-setup >>>"
MARK_END="# <<< imperial-hpc-setup <<<"

SKIP_BLESH=0; SKIP_STARSHIP=0; SKIP_CLI=0; NO_LOGIN=0
for a in "$@"; do
    case "$a" in
        --skip-blesh)    SKIP_BLESH=1 ;;
        --skip-starship) SKIP_STARSHIP=1 ;;
        --skip-cli)      SKIP_CLI=1 ;;
        --no-login)      NO_LOGIN=1 ;;
        -h|--help)       sed -n '2,13p' "$0"; exit 0 ;;
        *) echo "unknown option: $a" >&2; exit 2 ;;
    esac
done

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# ---- 1. user config ---------------------------------------------------------
step "config"
if [ -f "$HERE/hpc_setup.conf" ]; then
    echo "keeping existing hpc_setup.conf"
else
    cp "$HERE/hpc_setup.conf.example" "$HERE/hpc_setup.conf"
    echo "created hpc_setup.conf -- edit STVSC_TUNNEL_NAME there if you want a custom tunnel name"
fi
[ -f "$HERE/shell/local.sh" ] || echo "(optional) cp shell/local.sh.example shell/local.sh for private aliases"

# ---- 2. ~/.bashrc guarded block --------------------------------------------
step "~/.bashrc"
stamp=$(date +%Y%m%d-%H%M%S)
touch "$BASHRC"
cp "$BASHRC" "$BASHRC.bak.hpc-setup.$stamp"
echo "backup: $BASHRC.bak.hpc-setup.$stamp"

block="$MARK_BEGIN
[ -f \"$HERE/shell/init.sh\" ] && . \"$HERE/shell/init.sh\"
$MARK_END"

if grep -qF "$MARK_BEGIN" "$BASHRC"; then
    # replace the existing block in place (path may have changed)
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" -v new="$block" '
        $0==b {print new; skip=1; next}
        $0==e {skip=0; next}
        !skip {print}
    ' "$BASHRC" > "$BASHRC.tmp.$$" && mv "$BASHRC.tmp.$$" "$BASHRC"
    echo "updated existing block"
else
    printf '\n%s\n' "$block" >> "$BASHRC"
    echo "appended block"
fi

# VS Code tunnel terminals are NON-login shells: they read ~/.bashrc and never
# ~/.bash_profile. A login shell (ssh) reads only ~/.bash_profile if it exists.
# So ~/.bash_profile must delegate, or ssh sessions silently miss everything.
if [ -f "$PROFILE" ] && ! grep -qE '(\.|source) +["$]*(HOME|~)?/?\.bashrc' "$PROFILE"; then
    cp "$PROFILE" "$PROFILE.bak.hpc-setup.$stamp"
    printf '\n# added by imperial-hpc-setup: login shells must see ~/.bashrc too\n[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"\n' >> "$PROFILE"
    echo "~/.bash_profile now sources ~/.bashrc (backup: $PROFILE.bak.hpc-setup.$stamp)"
elif [ ! -f "$PROFILE" ]; then
    printf '# Login shells: delegate everything to ~/.bashrc (the single source of truth).\n[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"\n' > "$PROFILE"
    echo "created ~/.bash_profile"
fi

# ---- 3. tools -----------------------------------------------------------------
step "ble.sh";   [ "$SKIP_BLESH"    = 1 ] && echo "skipped" || bash "$HERE/tools/install_blesh.sh"
step "starship"; [ "$SKIP_STARSHIP" = 1 ] && echo "skipped" || bash "$HERE/tools/install_starship.sh"
step "VS Code CLI"
if [ "$SKIP_CLI" = 1 ]; then
    echo "skipped"
else
    bash "$HERE/tools/install_vscode_cli.sh"
    # ---- 4. first-time GitHub login (device code; needs a human at a browser) ----
    if [ "$NO_LOGIN" = 1 ]; then
        echo "login skipped -- run '~/code tunnel user login' once before stvsc"
    elif "$HOME/code" tunnel user show 2>/dev/null | grep -qiv 'not logged in'; then
        echo "tunnel CLI already logged in"
    elif [ -t 0 ]; then
        echo "The tunnel needs a one-time GitHub login. A code and a URL will be printed;"
        echo "open the URL in ANY browser (your laptop is fine) and enter the code."
        "$HOME/code" tunnel user login --provider github || \
            echo "login did not complete -- run '~/code tunnel user login' later"
    else
        echo "no TTY: run '~/code tunnel user login' once before stvsc"
    fi
fi

# ---- 5. Claude Code skills (optional) ---------------------------------------
step "Claude Code"
if command -v claude >/dev/null 2>&1; then
    echo "claude found. Skills load automatically when you run claude inside this repo;"
    echo "to use them from any project, symlink them:"
    echo "    mkdir -p ~/.claude/skills && ln -s $HERE/.claude/skills/* ~/.claude/skills/"
else
    echo "claude not installed -- skills in .claude/skills/ will work once it is"
fi

cat <<DONE

========================================================================
  DONE.  Open a NEW terminal (or: source ~/.bashrc), then:

     stvsc          start the VS Code tunnel on this node
     qvsc           start a 24 h tunnel as a batch job
     rvsc           kill a stale tunnel
     qs             qstat -u $USER

  Then locally: Cmd/Ctrl+Shift+P -> "Remote Tunnels: Connect to Tunnel"
========================================================================
DONE
