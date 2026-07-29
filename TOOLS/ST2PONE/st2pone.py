#!/usr/bin/env python3
"""Compatibility wrapper that exposes the ST2PY generator through a dedicated ST2Pone entrypoint."""

import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
ST2PY_DIR = ROOT / 'OUTILS_ST2PY'
if str(ST2PY_DIR) not in sys.path:
    sys.path.insert(0, str(ST2PY_DIR))

import fb_gen


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description='Generate ST2PY artefacts from a PLCopen XML bundle')
    parser.add_argument('--bundle', default=str(ROOT / 'OUTILS_ST2PY' / 'CODE_Bundle_test.xml'))
    parser.add_argument('--pou', default=None)
    parser.add_argument('--out', default=str(ST2PY_DIR / 'out'))
    parser.add_argument('--changed', action='store_true')
    parser.add_argument('--ref', default='origin/main')
    parser.add_argument('--force', action='store_true')
    parser.add_argument('--allow-safety', action='store_true')
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    argv_list = [str(pathlib.Path(__file__).resolve())]
    if args.bundle:
        argv_list.extend(['--bundle', args.bundle])
    if args.pou:
        argv_list.extend(['--pou', args.pou])
    if args.out:
        argv_list.extend(['--out', args.out])
    if args.changed:
        argv_list.append('--changed')
    if args.ref:
        argv_list.extend(['--ref', args.ref])
    if args.force:
        argv_list.append('--force')
    if args.allow_safety:
        argv_list.append('--allow-safety')

    sys.argv = argv_list
    fb_gen.main()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
