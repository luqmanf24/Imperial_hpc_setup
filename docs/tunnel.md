# How the tunnel works, and why `stvsc` is 200 lines instead of 1

The one-liner everyone starts with is:

```
~/code tunnel --name my-node &
```

It works — the first time. `stvsc` is what that line became after each of the
ways it fails was diagnosed. This page records *why* each piece exists, so
nobody "simplifies" it back into the broken version.

## The shape of the problem

You are on a compute node you reached through **Jupyter-on-demand** (itself a
PBS job with a walltime). You want your laptop's VS Code — with its extensions,
Claude Code, and a real terminal — on that node. SSH cannot reach a compute
node directly; a VS Code *tunnel* can, because the node dials out to GitHub's
relay and your laptop dials in.

So the node side is: run the CLI, keep it alive, and get its `Open:
https://vscode.dev/tunnel/...` line.

## 1. `setsid nohup ... < /dev/null` — no controlling terminal

**Symptom:** `[1]+ Stopped`, `ps` shows STAT `T` or `Tl`, VS Code hangs on
"Connecting...". Sometimes not immediately — minutes later, when an extension
starts a helper process.

**Cause:** if the tunnel keeps a controlling TTY, every child it spawns (the
VS Code server, extension hosts, node, Claude Code helpers) inherits it. When
any one of those touches the terminal from a *background* process group, the
kernel sends SIGTTIN/SIGTTOU and suspends the **whole process group**.

**Why tmux/screen do not help:** a pane is still a TTY.

**Fix:** `setsid` puts the tunnel in a new session with no controlling
terminal at all. `< /dev/null` closes stdin so nothing can even try. `stvsc`
checks for STAT `T` after launch (step 7b) and refuses to report success if it
sees one.

## 2. `rvsc` — kill the right things and nothing else

The obvious `pkill -f code` kills the **Remote-SSH server** (`~/.vscode-server`)
that is backing the terminal you typed it in. Your terminal dies and you get to
log in again.

`rvsc` walks the current shell's ancestor PIDs and never kills any of them,
and it excludes `.vscode-server` from the match. It matches on `~/code`,
`~/.vscode/cli`, `code tunnel` and `vscode-tunnel` — the tunnel and the servers
it installed, nothing else.

## 3. Pre-flight auth check (`tunnel user show`)

**Symptom:** `stvsc` launches, waits ~40 s, then reports a device-code login
prompt in the log. Everything looked fine yesterday.

**Cause:** the CLI **self-updates**, and an update can silently invalidate the
cached GitHub token in `~/.vscode/cli/token.json`. Nothing tells you.

**Fix:** check `~/code tunnel user show` *before* launching. If it says
`not logged in`, fail immediately with the exact command to run. The login is
a device-code flow (code + URL, enter it in any browser) — it needs a human
and cannot be scripted, which is why `stvsc` cannot just do it for you.

## 4. The "settle" loop

**Symptom:** `stvsc` prints `TUNNEL IS UP`. VS Code cannot connect. Log shows
the tunnel restarting.

**Cause:** the CLI prints the `Open:` line, *then* decides to self-update,
kills itself, and respawns. For ~1 minute there is nothing to connect to. A
readiness check that greps for `Open:` sees success at the exact moment the
tunnel is dying.

**Fix:** after `Open:` appears, keep watching the log for `Updating CLI to`.
If it shows up, wait (up to 2 min) until a `code tunnel` process is alive
*and* a fresh `Open:` line has been printed. Then warn the user that their
**local** VS Code must be at least the new server version or they will get
`version mismatch`. There is no `--no-auto-update` flag.

## 5. `--accept-server-license-terms`

Without it, a fresh server install stops at an interactive prompt that a
`setsid`'d process with stdin on `/dev/null` can never answer. It hangs
silently.

## 6. Truncate the log first

`: > "$log"` before launch. Otherwise the readiness grep can match
*yesterday's* `Open:` line and report a tunnel that does not exist.

## The batch variant (`qvsc`)

Jupyter-on-demand has a walltime. When it ends, so does your tunnel and every
terminal in it. `pbs/tunnel_job.pbs` runs the tunnel as the **main process of
a batch job** — PBS keeps it alive for the job's walltime and reaps it after.

Two design points that are not obvious:

- **Not `qsub -I`.** An interactive job dies with the terminal that launched
  it — and that terminal is inside the *other* tunnel. Chaining them means one
  dropped connection takes out both.
- **A separate `--cli-data-dir`.** `~/.vscode/cli` holds ONE registered tunnel
  identity. Two tunnels sharing it collide ("Command-line options will not be
  applied"). The batch job gets `~/.vscode/cli-batch`, seeded with a *copy* of
  the token only, so it registers its own name (`<yours>-batch`) rather than
  stealing the Jupyter one.
- **No `setsid`** — a batch job has no controlling TTY, so the SIGTTIN problem
  cannot occur, and foreground is what ties the job's lifetime to the tunnel.
