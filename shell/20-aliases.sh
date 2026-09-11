# ---- generic cluster aliases -----------------------------------------------
# Project-specific aliases do NOT belong here -- put those in shell/local.sh
# (see shell/local.sh.example), which is gitignored and sourced last.

alias qs="qstat -u ${HPC_USER:-$USER}"
alias jsl="jupyter server list"
alias cl="clear"
