import sys
import pathlib
import json
import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parents[2]
if str(TOOLS_DIR / 'core') not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR / 'core'))

import fb_gen


def test_safety_blocks_generation_by_default(tmp_path, monkeypatch):
    # simulate git changed file
    monkeypatch.setattr(fb_gen, 'git_changed_files', lambda ref: ['CODE/fake.st'])
    monkeypatch.setattr(fb_gen, 'extract_pou_from_st', lambda p: 'FB_Safety')
    # make canonical bytes containing a safety token
    monkeypatch.setattr(fb_gen, 'canonicalize_pou_bytes', lambda bundle, pou: b'<pou>SafeStop</pou>')
    # stub generation
    monkeypatch.setattr(fb_gen, 'generate_module_and_test', lambda pou, out: ('m','t','meta'))
    monkeypatch.setattr(fb_gen, 'load_cache', lambda base: {})
    monkeypatch.setattr(fb_gen, 'save_cache', lambda base, cache: None)

    out_dir = str(tmp_path / 'out')
    argv = ['fb_gen.py', '--bundle', str(tmp_path / 'CODE_Bundle.xml'), '--out', out_dir, '--changed']
    monkeypatch.setattr(sys, 'argv', argv)

    # run
    with pytest.raises(SystemExit) as exc:
        fb_gen.main()
    assert exc.value.code == 0

    # safety report file should exist
    report = pathlib.Path(out_dir) / 'FB_Safety.safety_report.json'
    assert report.exists()
    data = json.loads(report.read_text())
    assert data['blocked'] is True
    assert 'SafeStop' in data['found_tokens']


def test_allow_safety_overrides_block(tmp_path, monkeypatch):
    monkeypatch.setattr(fb_gen, 'git_changed_files', lambda ref: ['CODE/fake.st'])
    monkeypatch.setattr(fb_gen, 'extract_pou_from_st', lambda p: 'FB_Safety2')
    monkeypatch.setattr(fb_gen, 'canonicalize_pou_bytes', lambda bundle, pou: b'<pou>EmergencyStop</pou>')

    generated = {}
    def fake_generate(pou, out):
        p = pathlib.Path(out)
        p.mkdir(parents=True, exist_ok=True)
        (p / f"{pou}.py").write_text('#')
        (p / 'tests').mkdir(exist_ok=True)
        (p / 'tests' / f"test_{pou}.py").write_text('#')
        generated['pou'] = pou
        return (str(p / f"{pou}.py"), str(p / 'tests' / f"test_{pou}.py"), str(p / f"{pou}.meta.json"))

    monkeypatch.setattr(fb_gen, 'generate_module_and_test', fake_generate)
    monkeypatch.setattr(fb_gen, 'load_cache', lambda base: {})
    monkeypatch.setattr(fb_gen, 'save_cache', lambda base, cache: None)

    out_dir = str(tmp_path / 'out2')
    argv = ['fb_gen.py', '--bundle', str(tmp_path / 'CODE_Bundle.xml'), '--out', out_dir, '--changed', '--allow-safety', '--force']
    monkeypatch.setattr(sys, 'argv', argv)

    with pytest.raises(SystemExit) as exc:
        fb_gen.main()
    assert exc.value.code == 0
    # generation should have happened
    assert generated.get('pou') == 'FB_Safety2'
