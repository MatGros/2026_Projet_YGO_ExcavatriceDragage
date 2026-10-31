"""T417: run the actual ST at a stop/static-friction boundary, preserving failures."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'TOOLS/TEST_AUTO_CI/scripts'))
import run_tests


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to((ROOT / 'DOC/WFLOW').resolve()) or not output.parent.is_dir():
        parser.error('Existing directory under DOC/WFLOW required')
    if output.exists():
        parser.error('Evidence exists; choose a new name')
    entry = dict(run_tests.load_registry()['FB_Sim_Translation'])
    entry['test'] = 'TOOLS/TEST_AUTO_CI/RESULTS/L_SIMULATION/tests/test_fb_sim_translation_t417_boundary.st'
    paths = [*entry['sources'], entry['test'], 'TOOLS/TEST_AUTO_CI/scripts/run_tests.py',
             'TOOLS/AGENT_WORKFLOW/scripts/check_t417_model_boundary.py']
    hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
    run_tests._ensure_gpp_in_path()
    result = run_tests.run_one('FB_Sim_Translation', entry,
                               enable_chronogram=False, generate_reports=False)
    evidence = {'sources_sha256': hashes, 'ok': result['ok'], 'tests': result['tests'],
                'scratch': str(result.get('scratch', '')), 'scope': 'isolated actual ST, no PLC deployment'}
    with output.open('x', encoding='utf-8') as stream:
        json.dump(evidence, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    print(json.dumps(evidence['tests'], ensure_ascii=False, indent=2))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
