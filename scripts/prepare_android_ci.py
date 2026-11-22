#!/usr/bin/env python3
"""Apply upstream material_ui Android patches to the resolved CI package only."""
import json
from pathlib import Path
import subprocess
import tempfile
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
PATCHES = (
    'modal_barrier_material.patch', 'navigation_drawer.patch', 'popup_menu.patch',
    'fab.patch', 'text_field.patch', 'scaffold.patch', 'refresh_indicator.patch',
    'tabs.patch', 'bottom_sheet_android.patch',
)


def main():
    config = ROOT / '.dart_tool/package_config.json'
    packages = json.loads(config.read_text())['packages']
    package = next(item for item in packages if item['name'] == 'material_ui')
    uri = urlparse(package['rootUri'])
    if uri.scheme not in ('', 'file'):
        raise ValueError('material_ui must resolve to a local directory')
    directory = (config.parent / unquote(uri.path)).resolve()
    for name in PATCHES:
        patch = ROOT / 'lib/scripts/material' / name
        # Hosted archives can already contain some or all downstream changes.
        # Treat a patch as applied only when every added line is present in its
        # target file; otherwise require a clean applicability check before apply.
        lines = patch.read_text().splitlines(keepends=True)
        headers = []
        hunks = []
        current_file = None
        current_hunk = None
        for line in lines:
            if line.startswith('diff --git '):
                headers = [line]
                current_file = None
                current_hunk = None
            elif line.startswith('+++ b/'):
                headers.append(line)
                current_file = line[len('+++ b/'):].strip()
            elif line.startswith('@@ '):
                current_hunk = [line]
                hunks.append((headers.copy(), current_file, current_hunk))
            elif current_hunk is not None:
                current_hunk.append(line)
            elif line.startswith(('index ', '--- ')):
                headers.append(line)

        for hunk_headers, file, hunk in hunks:
            added_lines = [
                line[1:].rstrip('\n')
                for line in hunk
                if line.startswith('+') and not line.startswith('+++')
            ]
            target = directory / file
            existing = target.read_text().splitlines() if target.is_file() else []
            if added_lines and all(line in existing for line in added_lines):
                continue

            hunk_patch = ''.join(hunk_headers + hunk)
            with tempfile.NamedTemporaryFile(mode='w', suffix='.patch') as temp_patch:
                temp_patch.write(hunk_patch)
                temp_patch.flush()
                check = subprocess.run(
                    ['git', 'apply', '--check', temp_patch.name],
                    cwd=directory,
                    capture_output=True,
                    text=True,
                )
                if check.returncode:
                    raise RuntimeError(
                        f'{name} is incompatible with the resolved material_ui '
                        f'package at {file}:\n{check.stderr}'
                    )
                subprocess.run(
                    ['git', 'apply', temp_patch.name], cwd=directory, check=True
                )
    print('Applied upstream Android material_ui patches')


if __name__ == '__main__':
    main()
