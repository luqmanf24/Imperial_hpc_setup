# ---- notebook cell tooling (see auto/README.md) -----------------------------
# These add/refresh the Start/End cell markers that let you -- and an agent --
# address one notebook cell by number instead of parsing the whole .ipynb.

alias ccNum='python3 "$HPC_SETUP_ROOT/auto/cellNumbering.py"'
alias mdNum='python3 "$HPC_SETUP_ROOT/auto/mdNumbering.py"'
alias nb2md='python3 "$HPC_SETUP_ROOT/auto/jupyterToMarkdown.py"'
