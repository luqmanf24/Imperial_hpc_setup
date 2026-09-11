# ---- ble.sh tuning + attach (part 2/2) -------------------------------------
#
# PART 2 OF 2 -- see shell/10-blesh.sh. This MUST remain the last module: it
# attaches ble.sh to the finished prompt, so anything sourced after it (starship,
# another prompt tool) would not be wrapped. If you add a new module, give it a
# number below 99.

if [[ ${BLE_VERSION-} ]]; then
    bleopt complete_auto_delay=1       # near-instant grey suggestion
    bleopt complete_ambiguous=1        # fuzzy-ish completion
    bleopt exec_errexit_mark=          # no noisy exit-code marker
    ble-attach
fi
