# Imperial_hpc_setup

Type `stvsc` on a compute node. Connect from your laptop's VS Code. That's it.

A transferable setup for working on **Imperial College RCS** (CX3/HX1) through
VS Code tunnels, with a modern bash shell and Jupyter notebook tooling that an
AI agent (Claude Code) can drive. Written and tested on Imperial's cluster;
the tunnel and shell parts work on any PBS cluster with outbound HTTPS.

## What you get

| command | does |
|---|---|
| `stvsc` | start a VS Code tunnel on the node you are on, detached, with every known failure mode checked |
| `rvsc` | kill a stale tunnel without killing your own terminal |
| `qvsc` / `qvsc_status` / `qvsc_stop` | the same tunnel as a **24 h batch job**, outliving your Jupyter session |
| `qs` | `qstat -u $USER` |
| `ccNum` / `mdNum` / `nb2md` | number notebook cells so they can be addressed by number ([auto/](auto/README.md)) |

Plus, optionally: **ble.sh** (inline history suggestions, highlighting) and
**starship** (git-aware two-line prompt), both installed into `~/.local` with no
root — the compute nodes have no zsh, so this is the closest you get to
zsh + powerlevel10k.

And a `.claude/skills/` directory teaching Claude Code how to edit notebook
cells, diagnose a dead tunnel, and write PBS jobs.

## Quickstart

```sh
cd ~
git clone https://github.com/luqmanf24/Imperial_hpc_setup.git
cd Imperial_hpc_setup
bash install.sh          # ~2 min; prompts once for a GitHub device-code login
source ~/.bashrc         # or open a new terminal
stvsc
```

Then on your laptop, in VS Code: `Cmd/Ctrl+Shift+P` →
**Remote Tunnels: Connect to Tunnel** → pick your tunnel name.

`install.sh` is safe to re-run. Flags: `--skip-blesh`, `--skip-starship`,
`--skip-cli`, `--no-login`.

### Where to run `stvsc`

On the node you want VS Code on. The usual flow at Imperial:

1. Start a **Jupyter-on-demand** session from the RCS portal (this gives you a
   compute node with a walltime).
2. Open a terminal in JupyterLab.
3. `stvsc`.

For a tunnel that outlives the Jupyter session, `qvsc` submits one as a batch
job instead.

## Configure

`install.sh` creates `hpc_setup.conf` from the `.example`. Edit it:

```sh
STVSC_TUNNEL_NAME="hpc-compute"    # what you pick in VS Code; the batch one is <this>-batch
QVSC_WALLTIME="24:00:00"           # batch tunnel resources
QVSC_SELECT="1:ncpus=8:mem=64gb"
ENABLE_BLESH=1
ENABLE_STARSHIP=1
```

Your own aliases go in `shell/local.sh` (copy the `.example`). Both files are
gitignored, so fork freely.

## How it is wired

`install.sh` appends one guarded block to `~/.bashrc`:

```sh
# >>> imperial-hpc-setup >>>
[ -f "$HOME/Imperial_hpc_setup/shell/init.sh" ] && . "$HOME/Imperial_hpc_setup/shell/init.sh"
# <<< imperial-hpc-setup <<<
```

`shell/init.sh` reads `hpc_setup.conf`, then sources `shell/NN-*.sh` in order,
then `shell/local.sh`. The numbers matter — see [docs/shell.md](docs/shell.md).
`uninstall.sh` removes the block.

```
shell/      the bash modules (stvsc lives in 30-tunnel.sh)
tools/      installers for ble.sh, starship, the VS Code CLI
pbs/        tunnel_job.pbs, the batch tunnel
auto/       notebook cell scripts
config/     starship.toml
.claude/    Claude Code skills + narrow default permissions
docs/       the why
```

## Why is `stvsc` so long?

Because `~/code tunnel --name x &` fails in four distinct ways, each of which
took a session to diagnose: the process gets suspended by SIGTTIN when a child
touches the terminal; a CLI self-update silently invalidates the GitHub token;
the CLI prints its "ready" line and *then* restarts itself; and the obvious
cleanup (`pkill -f code`) kills the terminal you typed it in.
[docs/tunnel.md](docs/tunnel.md) explains each one. When something breaks,
[docs/troubleshooting.md](docs/troubleshooting.md) is the ordered checklist.

## Imperial-specific bits (change these elsewhere)

- Queue/core-count guidance in `.claude/skills/PBS_jobs/` refers to RCS queue
  classes.
- `pbs/tunnel_job.pbs` uses PBS Pro `select=` syntax. Slurm users: the tunnel
  body is the same, replace the header with `#SBATCH`.
- The VS Code CLI is the `cli-alpine-x64` build because RCS nodes run an older
  glibc. On a modern image the standard build also works.
- `/rds` is a network filesystem; the starship timeouts in
  `config/starship.toml` exist for that.

## Claude Code

Run `claude` inside this repo and the skills load automatically. To have them
everywhere:

```sh
mkdir -p ~/.claude/skills && ln -s ~/Imperial_hpc_setup/.claude/skills/* ~/.claude/skills/
```

`.claude/settings.json` ships a deliberately narrow allow-list (read-only
`qstat`, the notebook extractor). Add your own to `.claude/settings.local.json`,
which is gitignored.

## License

MIT.
