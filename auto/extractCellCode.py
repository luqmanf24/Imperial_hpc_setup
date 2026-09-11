#!/usr/bin/env python3
"""Print the code between '% Start Cell<N>' and '% End Cell<N>' markers.

Usage:
    python3 extractCellCode.py <jupyter_path> <N>
"""
import json
import sys


def comment_char(nb):
    lang = nb.get('metadata', {}).get('language_info', {}).get('name', '') \
        or nb.get('metadata', {}).get('kernelspec', {}).get('language', '')
    return '#' if lang.lower() == 'python' else '%'


def extract_cell_code(path, n):
    with open(path, 'r') as f:
        nb = json.load(f)

    c = comment_char(nb)
    start_marker = f'{c} Start Cell{n}\n'
    end_marker = f'{c} End Cell{n}\n'

    for cell in nb['cells']:
        if cell['cell_type'] != 'code':
            continue
        source = cell['source']
        if source and source[0] == start_marker and source[-1] == end_marker:
            return ''.join(source[1:-1])

    return None


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f'Usage: python3 {sys.argv[0]} <jupyter_path> <N>')
        sys.exit(1)

    code = extract_cell_code(sys.argv[1], int(sys.argv[2]))
    if code is None:
        print(f'Cell {sys.argv[2]} not found in {sys.argv[1]}', file=sys.stderr)
        sys.exit(1)

    print(code, end='')
