import json
import pathlib
import sys
import tempfile

TOOLS_DIR = pathlib.Path(__file__).resolve().parents[3]
if str(TOOLS_DIR / 'core') not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR / 'core'))

import fb_gen
import simulation_bench


REPO_ROOT = pathlib.Path(__file__).resolve().parents[6]
BUNDLE_PATH = REPO_ROOT / 'CODE_XML' / 'CODE_Bundle.xml'


def test_safety_translation_bench_reports_fault_then_reset():
    # Dossier temp systeme (jamais dans out/) : cf. REX 2026-08, out/ reserve aux artefacts persistants.
    with tempfile.TemporaryDirectory(prefix='st2py-test-') as tmp_dir:
        module_path, _, _ = fb_gen.generate_module_and_test('FB_Safety_Translation', tmp_dir, bundle_path=str(BUNDLE_PATH))
        result = simulation_bench.run_safety_translation_bench(
            pou_name='FB_Safety_Translation',
            module_path=str(pathlib.Path(tmp_dir) / 'FB_Safety_Translation.py'),
            time_ms=10.0,
        )

    assert result['pou'] == 'FB_Safety_Translation'
    assert len(result['timeline']) == 4
    fault_snapshot = result['timeline'][1]['snapshot']
    assert fault_snapshot['Error'] is True
    assert fault_snapshot['ErrorOperatorComm'] is True
    reset_snapshot = result['timeline'][2]['snapshot']
    assert reset_snapshot['Error'] is False
    assert reset_snapshot['ErrorId'] == 0
    recover_snapshot = result['timeline'][3]['snapshot']
    assert recover_snapshot['Error'] is False


def test_export_bench_writes_semicolon_separated_csv():
    with tempfile.TemporaryDirectory(prefix='st2py-test-') as tmp_dir:
        module_path, _, _ = fb_gen.generate_module_and_test('FB_Safety_Translation', tmp_dir, bundle_path=str(BUNDLE_PATH))
        result = simulation_bench.run_safety_translation_bench(
            pou_name='FB_Safety_Translation',
            module_path=str(pathlib.Path(tmp_dir) / 'FB_Safety_Translation.py'),
            time_ms=10.0,
        )
        csv_path = pathlib.Path(tmp_dir) / 'bench.csv'
        simulation_bench.export_bench(result, csv_path)
        contents = csv_path.read_text(encoding='utf-8')

    assert ';' in contents.splitlines()[0]
    assert 'step' in contents.splitlines()[0]
