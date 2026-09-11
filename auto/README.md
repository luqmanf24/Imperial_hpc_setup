# auto/ — notebook cell tooling

Five stdlib-only Python scripts (no pip installs) that make large Jupyter
notebooks addressable **one cell at a time**. The motivation is working with an
AI agent: a `.ipynb` is JSON with embedded outputs, often megabytes, and asking
an agent to "fix cell 14" should not require it to read the whole file.

## The marker convention

`cellNumbering.py` wraps every **code** cell:

```python
# Start Cell3
...your code...
# End Cell3
```

(`%` instead of `#` for MATLAB kernels.) Numbering counts code cells only and
is **idempotent** — re-running renumbers in place rather than stacking markers.
Insert or delete a cell, re-run, and numbers shift; that is why the
`Notebook_cells` skill always re-extracts instead of trusting a remembered N.

`mdNumbering.py` does the same for markdown cells with HTML comments
(`<!-- Start Md2 -->` … `<!-- End Md2 -->`), which are invisible when rendered.

## Scripts

| script | does | usage |
|---|---|---|
| `cellNumbering.py` | add/refresh code-cell markers | `ccNum nb.ipynb` |
| `mdNumbering.py` | add/refresh markdown-cell markers | `mdNum nb.ipynb [--dry-run]` |
| `extractCellCode.py` | print cell N's code to stdout | `python3 extractCellCode.py nb.ipynb N` |
| `editCellCode.py` | replace cell N's code from a file, keep markers | `python3 editCellCode.py nb.ipynb N edited.py` |
| `jupyterToMarkdown.py` | mirror every notebook under a folder to `code_only/*.md` (no outputs) | `nb2md folder/` |

`ccNum`, `mdNum`, `nb2md` are aliases defined by `shell/40-notebook.sh`.

## Two things to know

- `editCellCode.py` **deletes its input file** when the path contains a
  `.temp/` directory component. That is the intended workflow (extract to
  `.temp/`, edit, write back, gone) — do not keep anything you care about
  under a directory named `.temp`.
- `jupyterToMarkdown.py` is what lets you gitignore `*.ipynb` and track a
  readable `code_only/` mirror instead, so diffs show code changes and not
  base64 PNGs.
