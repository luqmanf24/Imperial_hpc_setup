---
name: Notebook_cells
description: Fast lookup and editing of a specific Jupyter notebook cell by cell number, using auto/extractCellCode.py and auto/editCellCode.py instead of reading/searching the whole notebook. Use whenever the user refers to a notebook by path plus a cell number (e.g. "edit cell 2 in analysis.ipynb", "what is in cell 14 of plots.ipynb").
---

# Notebook_cells

Notebooks that have been run through `auto/cellNumbering.py` have their
code cells numbered with `# Start Cell<N>` / `# End Cell<N>` markers (`%` for MATLAB kernels) via
`auto/cellNumbering.py`. Never read the whole `.ipynb` file or grep through it
to find a specific cell — notebooks are large JSON and burn tokens fast.
Instead, always extract just that cell first, and edit through a scoped temp
file rather than the notebook JSON directly.

## Trigger

The user names a notebook path together with a cell number, in any phrasing:
"cell 2", "cell number 14", "the 3rd code cell", etc. — whether they want to
view, explain, debug, or edit it.

`$HPC_SETUP_ROOT` is exported by `shell/init.sh`; if it is unset in your shell,
it is the directory containing this repo's `auto/`. `.temp/` below means a
`.temp/` directory in the notebook's project root (add it to that project's
`.gitignore`).

## Read-only lookup

Run the extractor to get exactly that cell's code:

```
python3 $HPC_SETUP_ROOT/auto/extractCellCode.py <jupyter_path> <N>
```

Always run this first, even if the notebook was inspected earlier in the
conversation — the user may have inserted/deleted cells and rerun
`cellNumbering.py`, which shifts numbering. Do not rely on stale assumptions
about what cell N contains.

If it errors with "Cell N not found", the numbering markers are probably
missing or stale. Tell the user and suggest running:

```
python3 $HPC_SETUP_ROOT/auto/cellNumbering.py <jupyter_path>
```

to (re)apply markers before retrying.

## Editing a cell

Don't touch the `.ipynb` JSON directly (via NotebookEdit/Edit) — round-tripping
the whole notebook through context is exactly the token cost this skill avoids.
Instead:

1. Extract the cell's code into a scoped temp file under `.temp/` (already
   gitignored), named `cell<N>_<notebook_basename>.<ext>`, where `<ext>` matches
   the kernel language (`.py` for Python, `.m` for MATLAB, `.jl` for Julia)
   so your editor gets the right syntax highlighting:

   ```
   mkdir -p .temp
   python3 $HPC_SETUP_ROOT/auto/extractCellCode.py <jupyter_path> <N> \
     > .temp/cell<N>_<notebook_basename>.<ext>
   ```

2. Edit that small temp file with the normal Edit tool — reasoning stays
   scoped to just this cell's code, not the surrounding notebook.

3. Write the edited temp file back into the notebook, preserving the
   `# Start Cell<N>` / `# End Cell<N>` markers (`%` for MATLAB kernels) automatically:

   ```
   python3 $HPC_SETUP_ROOT/auto/editCellCode.py <jupyter_path> <N> \
     .temp/cell<N>_<notebook_basename>.<ext>
   ```

4. `editCellCode.py` deletes the temp file itself once the write-back
   succeeds — do not `rm` it yourself.

5. Stop there. Do **not** run/execute the cell yourself (no `jupyter nbconvert
   --execute`, no kernel calls) — leave running it to the user. This also means
   no post-edit verification pass on your end (no re-extracting the cell to
   grep it, no re-reading it back, no tracing call sites "just to check") —
   the user runs it in Jupyter and will report back if something's off. Once
   the write-back in step 3 succeeds, tell the user the edit is done and that
   it's ready for them to run.
