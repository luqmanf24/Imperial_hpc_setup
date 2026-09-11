# Troubleshooting

Short version: the shell config is almost never the problem. Go down this list
in order. (The `Tunnel_doctor` Claude skill in `.claude/skills/` is the same
list, phrased for an agent.)

## "TUNNEL IS UP" but VS Code cannot connect

| # | check | means | fix |
|---|---|---|---|
| 1 | `~/code tunnel user show` | `not logged in` → token gone (a CLI self-update does this silently) | `~/code tunnel user login --provider github`, once, interactively |
| 2 | `grep 'Updating CLI to' ~/tunnel.log` | CLI updated mid-launch; old tunnel died | `rvsc; stvsc` |
| 3 | `grep 'version mismatch' ~/.vscode/cli/servers/Stable-*/log.txt` | your **laptop's** VS Code is older than the server | update VS Code locally |
| 4 | `ps -o pid,tty,stat,cmd -C code` — STAT has `T` | suspended by SIGTTIN (launched with a TTY) | `rvsc; stvsc` — never run `~/code tunnel` by hand or under tmux |
| 5 | `~/code tunnel status` → `{"tunnel":null}` | nothing registered | `stvsc` |

## `stvsc` fails immediately

- **NOT LOGGED IN** → step 1 above.
- **"Command-line options will not be applied"** → an old tunnel is still
  registered. `rvsc`; if that leaves survivors, `~/code tunnel kill`.
- **CLI download fails** → the node may not have outbound HTTPS. Download
  `cli-alpine-x64` on a login node instead and `tar -xf` it into `$HOME`.

## `qvsc` (batch tunnel)

- Job stays `Q` for ages → normal on a busy day; `qstat -f <id>` and read
  `comment`. `qvsc` returns after 20 min but the job keeps queueing;
  `qvsc_status` later.
- Job runs but no URL → `tail ~/tunnel_job.<id>.log`. A `no token` error means
  step 1 above was never done, or `~/.vscode/cli-batch/token.json` is a stale
  copy: delete it and resubmit.
- The batch tunnel's name is `<STVSC_TUNNEL_NAME>-batch`; pick that one in
  VS Code, not the Jupyter one.

## Shell

- **Aliases missing in the tunnel terminal** → they are in `~/.bash_profile`.
  Move them to `~/.bashrc` (see `docs/shell.md`).
- **Prompt hangs in a big repo** → `command_timeout` in
  `~/.config/starship.toml` is too high, or you are on a very slow filesystem.
- **Garbled characters in the prompt** → your terminal lacks a Nerd Font.
  Either install one locally or blank the `symbol`/`format` icons in
  `starship.toml`.
- **ble.sh does nothing** → `ENABLE_BLESH=0` in `hpc_setup.conf`, or it is not
  installed (`ls ~/.local/share/blesh/ble.sh`). Run `tools/install_blesh.sh`.

## Nuclear option

```
rvsc                        # kill tunnel processes
~/code tunnel kill          # unregister
~/code tunnel prune         # remove stale server dirs
stvsc
```
