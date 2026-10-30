#!/usr/bin/env python3
"""Execute le scénario composite M3 SimBench sans lancer le test M2 historique bloquant.

La preuve contient les empreintes des sources et ne remplace pas un essai CODESYS.
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

    entry = dict(run_tests.load_registry()['FB_SimBench'])
    entry['test'] = 'TOOLS/TEST_AUTO_CI/RESULTS/L_SIMULATION/tests/test_fb_simbench_m3_dynamics.st'
    paths = [*entry['sources'], entry['test'], 'TOOLS/TEST_AUTO_CI/scripts/run_tests.py']
    hashes = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in paths}
    run_tests._ensure_gpp_in_path()
    result = run_tests.run_one('FB_SimBench', entry, enable_chronogram=False, generate_reports=False)
    evidence = {'sources_sha256': hashes, 'ok': result['ok'],
                'tests': result['tests'], 'scratch': str(result.get('scratch', ''))}
    output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for case in result['tests']:
        print(('PASS' if case['passed'] else 'FAIL') + ' ' + case['name'])
        if case.get('detail'):
            print('  ' + case['detail'])
    print('Preuve : ' + str(output))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
