#!/usr/bin/env python3
"""Lance le banc FB_Brake avec registre temporaire et rapport local."""
from __future__ import annotations
import pathlib, sys, tempfile, webbrowser, yaml

HERE = pathlib.Path(__file__).resolve()
REPO_ROOT = next(p for p in HERE.parents if (p / 'TOOLS' / 'TEST_AUTO_CI').is_dir())
SCRIPTS = REPO_ROOT / 'TOOLS' / 'TEST_AUTO_CI' / 'scripts'
TEST_FILE = HERE.parent / 'test_fb_brake_baseline_exploratory.st'
sys.path.insert(0, str(SCRIPTS))
import run_tests  # noqa: E402

def main() -> int:
    entry = {'FB_Brake': {'domain': '_TROUBLESHOOTING/CODEX_FB_BRAKE_BASELINE', 'sources': [
        'CODE/A_COMMUN/_TYPES/E_State.st', 'CODE/A_COMMUN/_TYPES/ST_Fault.st',
        'CODE/A_COMMUN/_TYPES/ST_FaultCause.st', 'CODE/A_COMMUN/_TYPES/ST_ContactorCheck.st',
        'CODE/A_COMMUN/FB_FaultCore.st', 'CODE/A_COMMUN/FB_Brake.st'], 'test': str(TEST_FILE)}}
    _fd, name = tempfile.mkstemp(prefix='codex_fb_brake_registry_', suffix='.yaml')
    pathlib.Path(name).write_text(yaml.safe_dump(entry, sort_keys=False), encoding='utf-8')
    run_tests.REGISTRY = pathlib.Path(name)
    sys.argv = [str(SCRIPTS / 'run_tests.py'), '--fb', 'FB_Brake', *sys.argv[1:]]
    code = run_tests.main()
    report = HERE.parents[1] / 'reports' / 'FB_Brake.html'
    if report.is_file():
        print(f'\n📊 Rapport chronogramme : {report}')
        webbrowser.open(report.resolve().as_uri())
    return code

if __name__ == '__main__':
    raise SystemExit(main())
