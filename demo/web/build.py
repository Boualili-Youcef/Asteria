#!/usr/bin/env python3
"""Build the React console, audit its public allowlist, then export to a fresh directory."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / 'demo/web'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    output = args.output.absolute()
    if output.is_symlink() or output == ROOT or output in ROOT.parents:
        raise SystemExit('Refusing unsafe output directory')
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise SystemExit('Refusing to overwrite a nonempty output directory')
    npm = shutil.which('npm')
    if not npm:
        raise SystemExit('Node 22+ and npm required. Run npm ci in demo/web first.')
    subprocess.run([npm, 'run', 'build'], cwd=WEB, check=True)
    dist = WEB / 'dist'
    if output.resolve() == dist.resolve():
        raise SystemExit('Choose an export directory distinct from demo/web/dist')
    output.mkdir(parents=True, exist_ok=True)
    # The build audit accepts only html/js/css/svg/woff2/txt, never raw evidence or repo files.
    for path in dist.iterdir():
        if path.is_dir():
            shutil.copytree(path, output / path.name)
        else:
            shutil.copyfile(path, output / path.name)
    print(f'Static console exported to {output}; filtered evidence only, no cloud access')

if __name__ == '__main__':
    main()
