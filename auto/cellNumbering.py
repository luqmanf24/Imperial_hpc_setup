#!/usr/bin/env python3
"""Prepend '% Cell<n>' markers to every code cell in a Jupyter notebook.

Usage:
    python3 cellNumbering.py <jupyter_path>
"""
import json
import re
import sys

START_MARKER_RE = re.compile(r'^[%#] Start Cell\d+\n$')
END_MARKER_RE = re.compile(r'^[%#] End Cell\d+\n$')


def comment_char(nb):
    lang = nb.get('metadata', {}).get('language_info', {}).get('name', '') \
        or nb.get('metadata', {}).get('kernelspec', {}).get('language', '')
    return '#' if lang.lower() == 'python' else '%'


def number_cells(path):
    with open(path, 'r') as f:
        nb = json.load(f)

    c = comment_char(nb)
    n = 0
    for cell in nb['cells']:
        if cell['cell_type'] != 'code':
            continue
        n += 1
        source = cell['source']

        if source and START_MARKER_RE.match(source[0]):
            source[0] = f'{c} Start Cell{n}\n'
        else:
            source.insert(0, f'{c} Start Cell{n}\n')

        if source and END_MARKER_RE.match(source[-1]):
            source[-1] = f'{c} End Cell{n}\n'
        else:
            source.append(f'{c} End Cell{n}\n')

    with open(path, 'w') as f:
        json.dump(nb, f, indent=1)

    return n


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(f'Usage: python3 {sys.argv[0]} <jupyter_path>')
        sys.exit(1)

    count = number_cells(sys.argv[1])
    print(f'Numbered {count} code cells in {sys.argv[1]}')
