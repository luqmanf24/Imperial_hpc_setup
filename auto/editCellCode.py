#!/usr/bin/env python3
"""Replace the code inside '% Start Cell<N>' / '% End Cell<N>' with a temp file's contents.

Usage:
    python3 editCellCode.py <jupyter_path> <N> <temp_code_file>

The markers themselves are preserved; only the body between them is replaced.
"""
import json
import os
import sys


def comment_char(nb):
    lang = nb.get('metadata', {}).get('language_info', {}).get('name', '') \
        or nb.get('metadata', {}).get('kernelspec', {}).get('language', '')
    return '#' if lang.lower() == 'python' else '%'


def edit_cell_code(path, n, temp_file):
    with open(path, 'r') as f:
        nb = json.load(f)

    c = comment_char(nb)
    start_marker = f'{c} Start Cell{n}\n'
    end_marker = f'{c} End Cell{n}\n'

    with open(temp_file, 'r') as f:
        new_lines = f.readlines()
    if new_lines and not new_lines[-1].endswith('\n'):
        new_lines[-1] += '\n'

    for cell in nb['cells']:
        if cell['cell_type'] != 'code':
            continue
        source = cell['source']
        if source and source[0] == start_marker and source[-1] == end_marker:
            cell['source'] = [start_marker] + new_lines + [end_marker]
            with open(path, 'w') as f:
                json.dump(nb, f, indent=1)
            if os.sep + '.temp' + os.sep in os.path.abspath(temp_file):
                os.remove(temp_file)
            return True

    return False


if __name__ == '__main__':
    if len(sys.argv) != 4:
        print(f'Usage: python3 {sys.argv[0]} <jupyter_path> <N> <temp_code_file>')
        sys.exit(1)

    ok = edit_cell_code(sys.argv[1], int(sys.argv[2]), sys.argv[3])
    if not ok:
        print(f'Cell {sys.argv[2]} not found in {sys.argv[1]}', file=sys.stderr)
        sys.exit(1)

    print(f'Updated Cell{sys.argv[2]} in {sys.argv[1]}')
