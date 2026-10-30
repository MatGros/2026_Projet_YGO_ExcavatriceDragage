#!/usr/bin/env python3
"""Rejoue le scénario ciblé T417 AX14--AX15 sans le rapport de câblage.

Le câblage production est volontairement exclu de cette exécution, car il est
déjà contrôlé par G200. Le JSON le déclare explicitement : ce runner prouve la
compilation et les assertions du cycle, jamais le câblage.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'TOOLS/TEST_AUTO_CI/scripts'))
import run_tests


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    evidence_root = (ROOT / 'DOC/WFLOW').resolve()
    if not output.is_relative_to(evidence_root):
        parser.error('La preuve durable doit rester sous DOC/WFLOW.')
    if output.exists():
        parser.error('La preuve existe deja ; choisir un nouveau nom.')
    if not output.parent.is_dir():
        parser.error('Le dossier de preuve doit deja exister.')

    entry = dict(run_tests.load_registry()['FB_CycleSemiAuto'])
    entry['test'] = 'TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_cyclesemiauto_t417_m3.st'
    paths = [*entry['sources'], entry['test'], 'TOOLS/TEST_AUTO_CI/scripts/run_tests.py']
    hashes = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in paths}
    run_tests._ensure_gpp_in_path()
    original_build_wiring = run_tests.prod_wiring.build_wiring
    try:
        run_tests.prod_wiring.build_wiring = lambda *args, **kwargs: None
        result = run_tests.run_one('FB_CycleSemiAuto', entry,
                                   enable_chronogram=False, generate_reports=False)
    finally:
        run_tests.prod_wiring.build_wiring = original_build_wiring
    evidence = {
        'sources_sha256': hashes,
        'ok': result['ok'],
        'tests': result['tests'],
        'scratch': str(result.get('scratch', '')),
        'excluded_check': 'production_wiring (run G200 separately for linkage)',
    }
    output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for case in result['tests']:
        print(('PASS' if case['passed'] else 'FAIL') + ' ' + case['name'])
        if case.get('detail'):
            print('  ' + case['detail'])
    print('Preuve : ' + str(output))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
