# The shell: ble.sh, starship, and the `.bashrc` rule

## The rule that costs people hours

**VS Code tunnel terminals are non-login shells.** They read `~/.bashrc` and
never `~/.bash_profile`. An `ssh` session is a login shell: it reads
`~/.bash_profile` and, by default, *not* `~/.bashrc`.

So if your aliases live in `~/.bash_profile`, they vanish inside the tunnel and
you end up typing `source ~/.bash_profile` in every new terminal. If they live
in `~/.bashrc`, `ssh` sessions miss them.

The fix is the standard one and `install.sh` enforces it: everything goes in
`~/.bashrc`; `~/.bash_profile` contains only

```sh
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
```

Tools that append to `~/.bashrc` themselves (juliaup, conda) are fine. Tools
that append to `~/.bash_profile` need their block moved — `shell/local.sh` is
the place.

## Why ble.sh and starship, not zsh + powerlevel10k

The compute node has **no zsh** — not in `/usr/bin`, not as a module — and no
conda/spack/pixi to install one, and no root. What *is* available is bash 4.4,
`git`, `make`, and a writable `~/.local`.

- **[ble.sh](https://github.com/akinomyoga/ble.sh)** is a line editor written
  in pure bash. It gives inline grey history suggestions (→ to accept), syntax
  highlighting and menu completion. Built from source with
  `make install PREFIX=~/.local`.
- **[starship](https://starship.rs)** is a single static binary. Two-line
  prompt, git branch/status, command duration.

## The two-part ble.sh load

ble.sh must be **sourced** before anything touches the prompt and **attached**
after starship has installed its hooks. That is why there are two modules:

- `shell/10-blesh.sh` — `source ble.sh --noattach`
- `shell/90-prompt.sh` — `eval "$(starship init bash)"`
- `shell/99-blesh-attach.sh` — `bleopt ...; ble-attach`

`init.sh` sources modules in numeric order. Add new ones below 99.

## History sharing

With ble.sh: `bleopt history_share=1`. Without it: the classic
`PROMPT_COMMAND="history -a; history -n"`. **Not both** — they fight and you
get duplicated, reordered history. `shell/00-core.sh` picks one based on
whether `$BLE_VERSION` is set.

## Starship on a network filesystem

`~/.config/starship.toml` sets `scan_timeout = 50` and
`command_timeout = 1000`. RDS is a network filesystem; an unbounded
`git status` in the prompt can hang the shell for seconds in a large repo.
These caps make the prompt give up and render rather than block. Measured
~90 ms per render in a mid-size repo.

## Testing a shell config without breaking your session

`bash -i -c '...'` is a **false negative**: ble.sh refuses to attach without a
TTY, so the config "works" trivially. Use a pseudo-terminal:

```
script -qec 'bash --rcfile /path/to/test.bashrc -i' /dev/null
```
