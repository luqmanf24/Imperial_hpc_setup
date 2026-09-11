---
name: Tunnel_doctor
description: Diagnose a VS Code tunnel (stvsc / qvsc) that reports "TUNNEL IS UP" but local VS Code cannot connect, or that fails to start. Use whenever the user says the tunnel is down, VS Code hangs on "Connecting...", stvsc fails, or asks why they cannot connect to the compute node.
---

# Tunnel_doctor

Diagnose in **this order**. The shell config (ble.sh, starship, `~/.bashrc`) is
almost never the cause — do not start there.

## 1. Is the CLI logged in?

```
~/code tunnel user show
```

`not logged in` means the GitHub token is gone. **A CLI self-update silently
invalidates it.** The only fix is a one-time interactive login that only the
user can do (device code in a browser):

```
~/code tunnel user login --provider github
```

Tell the user exactly that and stop — nothing else will work until it is done.

## 2. Did the CLI self-update mid-session?

```
grep 'Updating CLI to' ~/tunnel.log
```

The CLI prints the `Open: ...vscode.dev/tunnel/` line *before* deciding to
update, so an old readiness check could report success while the tunnel was
respawning. `stvsc` now waits this out (its "settle" loop), but if the user is
on an older copy, the answer is `rvsc` then `stvsc` again. There is no
`--no-auto-update` flag on `code tunnel`.

## 3. Version mismatch

```
grep -l 'version mismatch' ~/.vscode/cli/servers/Stable-*/log.txt
```

`Client refused: version mismatch` means the user's **local** VS Code is older
than the server the CLI just installed. Fix is on the laptop: update VS Code.

## 4. Process state

```
~/code tunnel status          # {"tunnel":null} = nothing registered
ps -o pid,tty,stat,cmd -C code
```

- STAT containing `T` → suspended by SIGTTIN/SIGTTOU. The tunnel was launched
  with a controlling terminal (foreground, or under tmux/screen). `rvsc`, then
  `stvsc` — never `~/code tunnel` by hand.
- `Command-line options will not be applied` in the log → a previous tunnel is
  still registered. `rvsc` should clear it; if not, `~/code tunnel kill`.
- `~/code tunnel prune` removes unused server dirs under
  `~/.vscode/cli/servers/`. An empty one with no `log.txt`/`pid.txt` was staged
  but never started — harmless.

## Batch tunnel (qvsc) specifics

- `qvsc_status` shows the job and URL. No job → it hit walltime or was never
  submitted.
- Uses its own `--cli-data-dir ~/.vscode/cli-batch`, seeded with a **copy** of
  `~/.vscode/cli/token.json`. If step 1 failed on the main CLI, delete the
  stale copy after re-logging in: `rm ~/.vscode/cli-batch/token.json`.

## What NOT to do

- Do not blame ble.sh or starship. `bash -i -c` probes return clean; ble.sh
  refuses to attach when stdout is not a TTY, so it cannot interfere with the
  tunnel's child processes.
- Do not `pkill -f code` — that kills the Remote-SSH server backing the user's
  current terminal too. `rvsc` excludes `.vscode-server` and the shell's own
  ancestors on purpose.
- Do not launch `~/code tunnel` in the foreground or inside tmux to "see what
  happens". See STAT `T` above.
