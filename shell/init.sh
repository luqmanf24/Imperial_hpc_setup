# =============================================================================
# Entry point sourced from ~/.bashrc by the guarded block install.sh writes.
#
# Load order is LOAD-BEARING, not cosmetic -- see shell/10-blesh.sh and
# shell/99-blesh-attach.sh. The numeric filename prefixes encode that constraint
# so it survives future edits. Do not reorder without reading both files.
# =============================================================================

# Resolve this repo's root from the location of this file, so the block in
# ~/.bashrc works even if the user cloned somewhere other than the default.
_hpc_setup_here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# User config first: everything below reads from it.
if [ -f "$_hpc_setup_here/hpc_setup.conf" ]; then
    . "$_hpc_setup_here/hpc_setup.conf"
fi

# HPC_SETUP_ROOT from the conf file is advisory; the resolved path always wins,
# because a stale conf value would silently break every alias below.
HPC_SETUP_ROOT="$_hpc_setup_here"
export HPC_SETUP_ROOT

: "${HPC_USER:=$USER}"
: "${STVSC_TUNNEL_NAME:=hpc-compute}"
: "${ENABLE_BLESH:=1}"
: "${ENABLE_STARSHIP:=1}"
export HPC_USER STVSC_TUNNEL_NAME

for _hpc_mod in "$HPC_SETUP_ROOT"/shell/[0-9][0-9]-*.sh; do
    [ -r "$_hpc_mod" ] && . "$_hpc_mod"
done
unset _hpc_mod

# Your own private aliases/functions, never tracked by git. Sourced last so it
# can override anything above.
[ -r "$HPC_SETUP_ROOT/shell/local.sh" ] && . "$HPC_SETUP_ROOT/shell/local.sh"

unset _hpc_setup_here
