# =============================================================================
# rvsc / stvsc -- the VS Code tunnel on the node you are already sitting on.
#
# The comments in here are the point. Each defensive check exists because a
# specific failure was diagnosed the hard way; see docs/tunnel.md for the full
# write-up. Do not "simplify" them away.
# =============================================================================

# Kill the vscode *tunnel* (~/code + ~/.vscode/cli servers), leaving the
# Remote-SSH server (~/.vscode-server) that backs this terminal untouched.
rvsc() {
    local match ancestors p matched

    # ancestors of this shell -- never kill the terminal we are running in
    ancestors=" "
    p=$$
    while [ -n "$p" ] && [ "$p" != "1" ] && [ "$p" != "0" ]; do
        ancestors="${ancestors}${p} "
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
    done

    match=$(ps -u "$USER" -o pid=,cmd= \
        | grep -F -e "$HOME/code" -e "$HOME/.vscode/cli" -e "code tunnel" -e "vscode-tunnel" \
        | grep -F -v ".vscode-server" \
        | grep -v -e ' grep ' -e 'rvsc')

    matched=""
    while read -r pid rest; do
        [ -z "$pid" ] && continue
        case "$ancestors" in *" $pid "*) continue ;; esac
        matched="${matched}${pid} "
        printf '  %s  %s\n' "$pid" "$rest"
    done <<< "$match"

    if [ -z "$matched" ]; then
        echo "No stale vscode tunnel processes found."
        cd ~
        return 0
    fi

    echo "Killing stale vscode tunnel processes (above)."
    kill -9 $matched 2>/dev/null
    sleep 1

    local left
    left=$(ps -u "$USER" -o pid=,cmd= \
        | grep -F -e "$HOME/code" -e "$HOME/.vscode/cli" -e "code tunnel" -e "vscode-tunnel" \
        | grep -F -v ".vscode-server" \
        | grep -v -e ' grep ' -e 'rvsc')
    if [ -n "$left" ]; then
        echo "Still alive:"
        echo "$left"
    else
        echo "All vscode tunnel processes gone."
    fi
    cd ~
}

# Start the vscode tunnel *detached from any controlling terminal*.
#
# The setsid form below is mandatory: if the tunnel keeps a controlling TTY,
# every child it spawns (vscode server, Claude Code extension helpers, node)
# inherits it. When one of those touches the terminal from a background
# process group the kernel sends SIGTTIN/SIGTTOU and suspends the *whole*
# process group -- "[1]+ Stopped", STAT shows T/Tl, and local VS Code hangs
# on "Connecting...". tmux/screen do NOT help: a pane is still a tty.
stvsc() {
    local name log cli tries max ready line psout
    name="${STVSC_TUNNEL_NAME:-hpc-compute}"
    log="$HOME/tunnel.log"
    cli="$HOME/code"

    cd ~ || return 1

    # 1. rvsc must exist -- it is the only sanctioned cleanup path.
    if ! declare -F rvsc > /dev/null; then
        echo "stvsc: ERROR - 'rvsc' is not defined in this shell." >&2
        echo "       source ~/.bashrc and try again." >&2
        return 1
    fi

    # 2. clear stale tunnel / agent host / code-server processes
    echo "==> Clearing stale tunnel processes (rvsc)..."
    rvsc
    cd ~ || return 1

    # 3. make sure the CLI is present
    if [ ! -x "$cli" ]; then
        echo "==> vscode CLI not found at $cli - downloading..."
        if ! bash "${HPC_SETUP_ROOT:-$HOME/Imperial_hpc_setup}/tools/install_vscode_cli.sh"; then
            echo "stvsc: ERROR - could not install the vscode CLI." >&2
            return 1
        fi
        if [ ! -x "$cli" ]; then
            echo "stvsc: ERROR - $cli still missing or not executable after extraction." >&2
            echo "       inspect: ls -la ~/code ~/vscode_cli.tar.gz" >&2
            return 1
        fi
    fi

    # 3b. PRE-FLIGHT AUTH CHECK.
    #     A CLI self-update can invalidate the cached GitHub token. Without
    #     this check stvsc launches, waits ~40 s, then dies on a device-code
    #     prompt it cannot answer. Fail fast with instructions instead.
    if ! "$cli" tunnel user show 2>/dev/null | grep -qiv 'not logged in'; then
        echo
        echo "stvsc: NOT LOGGED IN - the tunnel CLI has no valid GitHub token."
        echo "       (A CLI self-update can silently invalidate it.)"
        echo
        echo "  Run this ONCE, right here, and follow the device-code prompt:"
        echo
        echo "      ~/code tunnel user login"
        echo
        echo "  It prints a code and a URL (https://github.com/login/device)."
        echo "  Enter the code there in any browser, then re-run:  stvsc"
        echo
        return 1
    fi

    # 4. truncate the log so readiness checks cannot match stale output
    : > "$log"

    # 5. launch with NO controlling terminal (see comment above)
    echo "==> Launching tunnel '$name' (setsid, no controlling tty)..."
    setsid nohup "$cli" tunnel --accept-server-license-terms --name "$name" < /dev/null > "$log" 2>&1 &
    disown

    # 6. poll for readiness / known failure modes (~40 s)
    max=80
    tries=0
    ready=""
    while [ "$tries" -lt "$max" ]; do
        if grep -qE 'Open:.*vscode\.dev/tunnel/' "$log" 2>/dev/null; then
            ready="yes"
            break
        fi
        if grep -qE 'use code|device login|To grant access' "$log" 2>/dev/null; then
            echo
            echo "stvsc: FAILED - device-code login is required."
            echo "----- ~/tunnel.log -----"
            tail -n 20 "$log"
            echo "------------------------"
            echo "stdin is /dev/null, so stvsc cannot answer an interactive login."
            echo "Run this ONCE, interactively, then re-run stvsc:"
            echo "    ~/code tunnel user login"
            rvsc > /dev/null 2>&1
            return 1
        fi
        if grep -qF 'Command-line options will not be applied' "$log" 2>/dev/null; then
            echo
            echo "stvsc: FAILED - a previously registered tunnel is still running;"
            echo "       rvsc did not fully clear it."
            echo "----- still alive -----"
            ps -u "$USER" -o pid=,tty=,stat=,cmd= \
                | grep -F -e "$HOME/code" -e "$HOME/.vscode/cli" \
                | grep -F -v ".vscode-server" | grep -v ' grep '
            echo "-----------------------"
            echo "Next: rvsc ; ps -u $USER -o pid,tty,stat,cmd | grep -F ~/code"
            rvsc > /dev/null 2>&1
            return 1
        fi
        sleep 0.5
        tries=$((tries + 1))
    done

    # 6b. SETTLE. The CLI can decide to self-update *after* printing the
    #     "Open:" line; it then respawns the tunnel, and for a while there is
    #     nothing a client can attach to. Reporting success here is what made
    #     stvsc claim "TUNNEL IS UP" while the tunnel was dying.
    #     So: wait out any update, then require the process to still be alive.
    if [ -n "$ready" ]; then
        local settle upd_seen
        settle=0
        upd_seen=""
        while [ "$settle" -lt 240 ]; do
            if grep -qF 'Updating CLI to' "$log" 2>/dev/null; then
                if [ -z "$upd_seen" ]; then
                    upd_seen="yes"
                    echo "==> CLI is self-updating; waiting for the tunnel to respawn"
                    echo "    (this is normal after a VS Code release; ~1 min)."
                fi
                if [ "$settle" -ge 30 ] \
                   && ps -o cmd= -C code 2>/dev/null | grep -qF "tunnel" \
                   && grep -qE 'Open:.*vscode\.dev/tunnel/' "$log" 2>/dev/null; then
                    break
                fi
            else
                [ "$settle" -ge 8 ] && break
            fi
            sleep 0.5
            settle=$((settle + 1))
        done
        if [ -n "$upd_seen" ]; then
            echo "==> CLI update settled; now $("$cli" --version 2>/dev/null | head -1)"
            echo "    NOTE: your LOCAL VS Code must be at least this version,"
            echo "          otherwise it is refused with 'version mismatch'."
        fi
    fi

    psout=$(ps -o pid,tty,stat,cmd -C code 2>/dev/null)

    # 7a. process vanished
    if ! printf '%s\n' "$psout" | grep -q "$cli"; then
        echo
        echo "stvsc: FAILED - no '$cli' process is running after launch."
        echo "----- ~/tunnel.log (last 20) -----"
        tail -n 20 "$log"
        echo "----------------------------------"
        echo "Next: tail -f ~/tunnel.log"
        rvsc > /dev/null 2>&1
        return 1
    fi

    # 7b. suspended by SIGTTIN/SIGTTOU
    if printf '%s\n' "$psout" | grep -F "$cli" | awk '{print $3}' | grep -q 'T'; then
        echo
        echo "stvsc: FAILED - the tunnel process is SUSPENDED (STAT contains 'T')."
        echo "$psout"
        echo "This is the SIGTTIN/SIGTTOU trap: the process group touched a"
        echo "controlling terminal from the background and the kernel stopped it."
        echo "Next: rvsc ; then re-run stvsc (never launch ~/code tunnel in the foreground or under tmux)."
        rvsc > /dev/null 2>&1
        return 1
    fi

    # 7c. timed out with no ready line
    if [ -z "$ready" ]; then
        echo
        echo "stvsc: FAILED - timed out after ~40 s with no 'Open: ...vscode.dev/tunnel/' line."
        echo "----- ~/tunnel.log (last 20) -----"
        tail -n 20 "$log"
        echo "----------------------------------"
        echo "Next: tail -f ~/tunnel.log"
        rvsc > /dev/null 2>&1
        return 1
    fi

    line=$(grep -E 'Open:.*vscode\.dev/tunnel/' "$log" | tail -n 1 | sed 's/^[[:space:]]*//')

    echo
    echo "========================================================================"
    echo "  TUNNEL IS UP  --  node side is DONE"
    echo "========================================================================"
    echo "  tunnel name : $name"
    echo "  url         : $line"
    echo "  detached    : yes - setsid, no controlling TTY (TT is '?')"
    echo
    echo "$psout"
    echo
    echo "  NEXT STEP (local VS Code):"
    echo "     Cmd/Ctrl+Shift+P  ->  \"Remote Tunnels: Connect to Tunnel\""
    echo "     ->  pick  '$name'"
    echo
    echo "  watch : tail -f ~/tunnel.log"
    echo "  reset : rvsc"
    echo "========================================================================"
    return 0
}
