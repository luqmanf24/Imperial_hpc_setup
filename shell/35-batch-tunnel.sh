# =============================================================================
# qvsc -- stvsc's batch-job sibling. Submits pbs/tunnel_job.pbs, waits for the
# node to be allocated, then prints the vscode.dev URL.
#
#     qvsc                        # submit with QVSC_WALLTIME / QVSC_SELECT
#     qvsc -l walltime=72:00:00   # any extra args are passed through to qsub
#     qvsc_status                 # show the tunnel job + its URL
#     qvsc_stop                   # qdel the tunnel job
#
# Unlike stvsc this returns as soon as the URL is known; the tunnel is a PBS job,
# not a child of your shell, so closing this terminal does not touch it. That is
# the whole point -- your Jupyter session has a walltime, this outlives it.
# =============================================================================

# The name qstat shows. PBS truncates the `#PBS -N` value in the `qstat -u`
# listing, so derive the prefix from the .pbs file rather than hardcoding it --
# otherwise renaming the job silently breaks qvsc_status and qvsc_stop.
_qvsc_jobname() {
    local pbs n
    pbs="${HPC_SETUP_ROOT:-$HOME/Imperial_hpc_setup}/pbs/tunnel_job.pbs"
    n=$(awk '/^#PBS[[:space:]]+-N[[:space:]]/{print $3; exit}' "$pbs" 2>/dev/null)
    printf '%s' "${n:0:8}"
}

_qvsc_findjob() {
    local jn
    jn=$(_qvsc_jobname)
    [ -z "$jn" ] && return 1
    qstat -u "$USER" 2>/dev/null | awk -v n="$jn" '$0 ~ n {print $1}' | head -1
}

qvsc() {
    local pbs job log tries max line state name
    pbs="${HPC_SETUP_ROOT:-$HOME/Imperial_hpc_setup}/pbs/tunnel_job.pbs"
    [ -f "$pbs" ] || { echo "qvsc: ERROR - $pbs not found." >&2; return 1; }

    # The batch tunnel must register a DIFFERENT name from the stvsc one, or the
    # two collide in the tunnel registry.
    name="${STVSC_TUNNEL_NAME:-hpc-compute}-batch"

    job=$(qsub -v "TUNNEL_NAME=$name" \
               -l "walltime=${QVSC_WALLTIME:-24:00:00}" \
               -l "select=${QVSC_SELECT:-1:ncpus=8:mem=64gb}" \
               "$@" "$pbs") \
        || { echo "qvsc: ERROR - qsub failed." >&2; return 1; }
    job="${job%%.*}"
    log="$HOME/tunnel_job.${job}.log"
    echo "==> submitted job $job as '$name'; waiting for a node"
    echo "    (Ctrl-C is safe, the job keeps queueing)"

    max=1200; tries=0                       # up to ~20 min of waiting
    while [ "$tries" -lt "$max" ]; do
        state=$(qstat -f "$job" 2>/dev/null | awk -F'= ' '/job_state/{print $2}')
        case "$state" in
            "")   echo "qvsc: job $job left the queue before starting; see $log" >&2; return 1 ;;
            R)    ;;
            *)    printf '\r    queued (state %s), %ds elapsed ' "$state" "$tries"
                  sleep 5; tries=$((tries+5)); continue ;;
        esac
        if [ -f "$log" ] && grep -qE 'Open:.*vscode\.dev/tunnel/' "$log" 2>/dev/null; then
            line=$(grep -E 'Open:.*vscode\.dev/tunnel/' "$log" | tail -1 | sed 's/^[[:space:]]*//')
            echo; echo
            echo "========================================================================"
            echo "  TUNNEL IS UP  --  job $job on $(qstat -f "$job" 2>/dev/null | awk -F'/' '/exec_host/{print $1}' | awk '{print $NF}')"
            echo "========================================================================"
            echo "  name : $name"
            echo "  url  : $line"
            echo "  log  : $log"
            echo
            echo "  NEXT (local VS Code):"
            echo "     Cmd/Ctrl+Shift+P -> \"Remote Tunnels: Connect to Tunnel\""
            echo "     -> pick '$name'"
            echo "  stop : qvsc_stop"
            echo "========================================================================"
            return 0
        fi
        printf '\r    running, waiting for the tunnel URL, %ds elapsed ' "$tries"
        sleep 5; tries=$((tries+5))
    done

    echo; echo "qvsc: timed out waiting. The job may still be queued -- check:"
    echo "    qstat -u $USER ; tail -f $log"
    return 1
}

qvsc_status() {
    local job log
    job=$(_qvsc_findjob)
    [ -z "$job" ] && { echo "No tunnel job running."; return 1; }
    qstat -u "$USER" | awk -v n="$(_qvsc_jobname)" 'NR<=5 || $0 ~ n'
    log="$HOME/tunnel_job.${job%%.*}.log"
    [ -f "$log" ] && grep -E 'Open:.*vscode\.dev/tunnel/' "$log" | tail -1 | sed 's/^[[:space:]]*/  url: /'
}

qvsc_stop() {
    local job
    job=$(_qvsc_findjob)
    [ -z "$job" ] && { echo "No tunnel job to stop."; return 1; }
    echo "Deleting tunnel job $job"
    qdel "${job%%.*}"
}
