---
name: Rebase
description: Squash a contiguous range of git commits (from HEAD or a mid-branch range given start/end hashes) into one commit with a proper, diff-derived summary message. Always creates a backup branch first.
---

# Rebase Skill

## Trigger

Use this skill whenever the user asks to rebase, squash, or combine commits in
a PEPAPIC git branch — including squashing from HEAD down to a given commit,
or squashing a **contiguous middle range** identified by a start and end
commit hash that is not at HEAD.

## Core rule

The user specifies the range as two commit hashes: `<start>` (older) and
`<end>` (newer). The range **must be contiguous** — every commit from
`<start>` to `<end>` inclusive gets squashed into one commit. Commits before
`<start>` and after `<end>` are untouched in content (though commits after
`<end>` will get new hashes, since the tree underneath them changed).

If `<end>` is HEAD, this is a "squash from HEAD to `<start>`" case. If
`<end>` is not HEAD, this is a mid-branch squash and everything after `<end>`
gets replayed on top automatically by `git rebase`.

## Preconditions — always do first

1. `git status` — refuse to proceed if the working tree is not clean (respect
   uncommitted work; do not stash or discard without asking).
2. `git log --oneline <branch>` — confirm both `<start>` and `<end>` exist on
   the branch, and confirm they are contiguous (no merge commits in between —
   this skill assumes a linear history).
3. **Scan the actual changes before writing anything.** Do not draft the
   commit message from the original commit subjects (they're often
   low-effort, e.g. "update plot", "wip", "fix"). Instead:
   - `git diff --stat <start>^ <end>` for the full file list and scale of
     change.
   - `git diff <start>^ <end> -- <file>` on each file that isn't obviously
     trivial (config/plot tweaks) to see what actually changed — new
     parameters, renamed APIs, bug fixes, numerical/algorithmic changes.
   - Group files mentally by subsystem (e.g. `src/Particle/`, `src/Domain/`,
     `src/Poisson/`, `Post-process` plotting scripts) so the summary message
     can be organized by area rather than by commit order.
   - If the range is large, it is fine to skip deep-diffing files that are
     purely cosmetic (formatting, plot titles) as long as `--stat` confirms
     they're small and non-functional — but any file with double-digit+ line
     changes should get a real look.

## Backup branch

**Always create a backup branch before rewriting history**, even for local
rebases:

```sh
git branch backup-<branch>-<short-label> <branch>
```

A backup branch is just a ref (near-zero cost) and gives the user an
immediately-nameable recovery point without having to dig through
`git reflog`. Tell the user the backup branch name after creating it. It is
fine to leave multiple backup branches lying around from repeated rebases —
cleaning them up is the user's call, not something to do proactively.

If the branch has already been pushed/shared, also flag that rewriting it
will require a force-push to sync, and that this is riskier for anyone else
tracking the branch.

## Procedure — squashing a contiguous range `<start>..<end>`

### Case A: `<end>` is HEAD

```sh
git reset --soft <start>^
git commit -F - <<'EOF'
<combined message>
EOF
```

`git reset --soft` moves the branch pointer but keeps all changes staged;
nothing is lost even without a backup branch, since `<start>^` and every
original commit stay reachable via reflog until the reset is superseded.

### Case B: `<end>` is not HEAD (mid-branch squash)

Interactive rebase, but drive it non-interactively since there is no TTY —
use `GIT_SEQUENCE_EDITOR` to rewrite the todo list programmatically:

```sh
GIT_SEQUENCE_EDITOR='python3 -c "
import sys
path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()
start_i = end_i = None
for i, l in enumerate(lines):
    if l.startswith(\"pick <start>\"):
        start_i = i
    if l.startswith(\"pick <end>\"):
        end_i = i
for i in range(start_i + 1, end_i + 1):
    lines[i] = lines[i].replace(\"pick\", \"squash\", 1)
with open(path, \"w\") as f:
    f.writelines(lines)
"' git rebase -i <start>^
```

This keeps the first commit in the range (`<start>`) as `pick` and marks
every subsequent commit up to and including `<end>` as `squash`, leaving
everything outside the range as `pick` (untouched).

Git will auto-concatenate all the squashed commit messages into one — this
is almost never a "good" message, so always follow up with a reword pass:

```sh
GIT_SEQUENCE_EDITOR='sed -i "" "s/^pick <sha-of-squashed-commit>/edit <sha-of-squashed-commit>/"' git rebase -i <sha-of-squashed-commit>^
git commit --amend -F - <<'EOF'
<combined message>
EOF
git rebase --continue
```

Note: `reword` in the sequence editor does not work non-interactively (no
editor launches without a TTY) — use `edit` + `git commit --amend -F -` +
`git rebase --continue` instead, as shown above.

## Writing the combined commit message

Do not just concatenate the original "quick commit" messages. Read the real
diff (`git diff --stat` and targeted `git diff` on non-trivial files) and
write a message that describes what actually changed, grouped by area, e.g.:

```
<One-line summary of the overall change>

- <area/file>: <what changed and why, if inferable>
- <area/file>: <what changed and why>
...
```

Prefer grouping by subsystem (e.g. Particle_init.jl, Domain_decompose.jl,
Post-process plotting scripts) over listing every file. Skip pure
"update plot" noise commits from the summary unless they contain a
substantive change worth calling out.

## After rebasing

1. `git log --oneline <branch> | head -N` — show the user the resulting log
   around the squashed range so they can verify it looks right.
2. `git status` — confirm working tree is clean.
3. If the branch was already pushed (diverges from `origin/<branch>`), tell
   the user a `git push --force-with-lease origin <branch>` will be needed
   to sync, but **do not push it yourself** unless the user explicitly asks.
