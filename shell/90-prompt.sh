# ---- starship prompt: cwd relative to ~, git branch/status -----------------
# Must come BEFORE ble-attach (99-) so ble.sh wraps the finished prompt.
if [ "${ENABLE_STARSHIP:-1}" = "1" ]; then
    if [[ $- == *i* ]] && command -v starship >/dev/null 2>&1; then
        eval "$(starship init bash)"
    fi
fi
