#!/usr/bin/env python3
"""Wrap every markdown cell in a Jupyter notebook with unique Md<n> markers.

Each markdown cell becomes:

    <!-- Start Md3 -->
    ...the markdown note lives here...
    <!-- End Md3 -->

HTML comments are used (not '# Start Md3') because '#' is a section heading in
markdown -- the old form rendered as a giant H1 in every cell.  HTML comments
are invisible in the rendered notebook and in PDF exports, but plainly visible
while editing the cell, so an agent can be told "write this in Md3".

Numbering counts markdown cells only, independently of code-cell numbering
(see cellNumbering.py, which handles '# Start Cell<n>' for code cells).

Re-running is safe: existing markers are replaced, never stacked.  Markers left
by the older '# Start Md<n>' format are migrated, including the case where the
end marker was welded onto the last line of prose (e.g. "2. # End Md1").

Usage:
    python3 mdNumbering.py <jupyter_path> [--dry-run]
"""
import json
import re
import sys

# Marker lines to recognise and strip before re-wrapping.
NEW_MARKER_RE = re.compile(r'^<!--\s*(?:Start|End)\s+Md\d+\s*-->\s*$')
OLD_MARKER_RE = re.compile(r'^#\s*(?:Start|End)\s+Md\d+\s*$')

# The old script appended '# End Md<n>' without checking that the previous line
# ended in a newline, welding it onto the last line of text.  Strip that, but
# only from the final line -- that is the only place the bug could put it.
GLUED_END_RE = re.compile(r'\s*#\s*End\s+Md\d+\s*$')


def is_marker(line):
    return bool(NEW_MARKER_RE.match(line) or OLD_MARKER_RE.match(line))


def strip_markers(text):
    """Remove any existing Md markers, returning the cell's real content."""
    lines = text.split('\n')

    # Only peel markers off the top and bottom.  Stripping them anywhere would
    # eat a legitimate '# Start Md7' sitting inside a fenced code block.
    while lines and is_marker(lines[0]):
        lines.pop(0)
    while lines and is_marker(lines[-1]):
        lines.pop()

    # repair a welded end marker on the last non-blank line
    for i in range(len(lines) - 1, -1, -1):
        if lines[i].strip():
            lines[i] = GLUED_END_RE.sub('', lines[i])
            break

    # trim leading/trailing blank lines
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return lines


def wrap(body_lines, n):
    """Build the nbformat source list for one wrapped markdown cell."""
    if not body_lines:
        body_lines = ['']          # leave a blank line to write into
    out = [f'<!-- Start Md{n} -->'] + body_lines + [f'<!-- End Md{n} -->']
    # nbformat convention: every line ends with '\n' except the last
    return [ln + '\n' for ln in out[:-1]] + [out[-1]]


def number_md_cells(path, dry_run=False):
    with open(path, 'r') as f:
        nb = json.load(f)

    n = 0
    changed = 0
    for cell in nb['cells']:
        if cell['cell_type'] != 'markdown':
            continue
        n += 1
        before = list(cell['source'])
        after = wrap(strip_markers(''.join(before)), n)
        if after != before:
            changed += 1
        cell['source'] = after

    if not dry_run:
        with open(path, 'w') as f:
            json.dump(nb, f, indent=1)

    return n, changed


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if a != '--dry-run']
    dry = '--dry-run' in sys.argv[1:]

    if len(args) != 1:
        print(f'Usage: python3 {sys.argv[0]} <jupyter_path> [--dry-run]')
        sys.exit(1)

    total, changed = number_md_cells(args[0], dry_run=dry)
    verb = 'Would number' if dry else 'Numbered'
    print(f'{verb} {total} markdown cells in {args[0]} ({changed} changed)')
