#!/usr/bin/env python3
"""Petit harness pour tester l'entrée/sortie du FB_Translation_PositionDecoder."""
import argparse
import json
import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR / 'core'))
from results_layout import results_dir
OUT_DIR = results_dir('FB_Translation_PositionDecoder', 'modules')
if str(OUT_DIR) not in sys.path:
    sys.path.insert(0, str(OUT_DIR))

from FB_Translation_PositionDecoder import FB_Translation_PositionDecoder


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description='Simulate the translation position decoder from a bitmask.')
    parser.add_argument('--mask', type=int, default=0b11111, help='Bitmask of the 5 sensors (bit4=Trémie ... bit0=Maintenance).')
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if not 0 <= args.mask <= 0b11111:
        raise SystemExit('mask must be between 0 and 31')

    fb = FB_Translation_PositionDecoder()
    fb.set_inputs_from_mask(args.mask)
    fb.step()

    result = {
        'mask': args.mask,
        'SensorsWord': fb.SensorsWord,
        'Incoherent': fb.Incoherent,
        'LimitSwitchFwd': fb.LimitSwitchFwd,
        'LimitSwitchRev': fb.LimitSwitchRev,
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
