#!/usr/bin/env python3
"""Convert every Jupyter notebook in a folder to a plain-markdown, output-free mirror.

Markdown cells are copied verbatim (so any #/##/### headings the author wrote
become the document's section structure). Code cells are copied without their
outputs, each in its own fenced code block labeled with its cell number and
without the '% Start Cell<N>' / '% End Cell<N>' markers added by
cellNumbering.py.

Usage:
    python3 jupyterToMarkdown.py <folder_path>

Notebooks are found recursively under <folder_path>; each notebook's markdown
mirror is written to <folder_path>/code_only/<same relative path>.md
('code_only/' itself is skipped when scanning, so re-running is safe).
"""
import json
import os
import re
import sys

START_MARKER_RE = re.compile(r'^\s*[%#]\s*Start Cell\d+\s*$')
END_MARKER_RE = re.compile(r'^\s*[%#]\s*End Cell\d+\s*$')

# Fenced-code-block language tag, keyed by notebook language_info/kernelspec name.
LANG_MAP = {
    'matlab': 'matlab',
    'python': 'python',
    'python3': 'python',
}


def notebook_language(nb):
    meta = nb.get('metadata', {})
    lang = meta.get('language_info', {}).get('name')
    if not lang:
        lang = meta.get('kernelspec', {}).get('language')
    return LANG_MAP.get(lang, lang or '')


def strip_cell_markers(lines):
    lines = list(lines)
    if lines and START_MARKER_RE.match(lines[0]):
        lines = lines[1:]
    if lines and END_MARKER_RE.match(lines[-1]):
        lines = lines[:-1]
    return lines


def notebook_to_markdown(path):
    with open(path, 'r') as f:
        nb = json.load(f)

    lang = notebook_language(nb)
    title = os.path.splitext(os.path.basename(path))[0]

    out = [f'# {title}\n']
    code_n = 0

    for cell in nb['cells']:
        source = cell.get('source', [])
        if not source:
            continue

        if cell['cell_type'] == 'markdown':
            out.append(''.join(source).rstrip('\n') + '\n')

        elif cell['cell_type'] == 'code':
            code_n += 1
            code_lines = strip_cell_markers(source)
            code = ''.join(code_lines).rstrip('\n')
            if not code.strip():
                continue
            out.append(f'#### Cell {code_n}\n')
            out.append(f'```{lang}\n{code}\n```\n')

    return '\n'.join(out) + '\n'


def find_notebooks(folder_path):
    for root, dirs, files in os.walk(folder_path):
        dirs[:] = [d for d in dirs if d != 'code_only' and not d.startswith('.')]
        for name in files:
            if name.endswith('.ipynb'):
                yield os.path.join(root, name)


def convert_folder(folder_path):
    out_root = os.path.join(folder_path, 'code_only')
    count = 0
    for nb_path in find_notebooks(folder_path):
        rel = os.path.relpath(nb_path, folder_path)
        md_rel = os.path.splitext(rel)[0] + '.md'
        md_path = os.path.join(out_root, md_rel)
        os.makedirs(os.path.dirname(md_path), exist_ok=True)

        md_text = notebook_to_markdown(nb_path)
        with open(md_path, 'w') as f:
            f.write(md_text)

        print(f'{rel} -> code_only/{md_rel}')
        count += 1

    return count


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(f'Usage: python3 {sys.argv[0]} <folder_path>')
        sys.exit(1)

    n = convert_folder(sys.argv[1])
    print(f'Converted {n} notebook(s).')
