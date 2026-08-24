import os
import builtins
import types
import json
import pathlib
import sys
import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parents[3]
if str(TOOLS_DIR / 'core') not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR / 'core'))

import fb_gen


def test_changed_single_st_file_triggers_generation(tmp_path, monkeypatch):
    # Arrange: prepare a fake changed file list (relative paths as git would return)
    changed_files = ['CODE/fake_st_file.st']
    monkeypatch.setattr(fb_gen, 'git_changed_files', lambda ref: changed_files)

    # Mock extract_pou_from_st to return a known POU name when called with our path
    monkeypatch.setattr(fb_gen, 'extract_pou_from_st', lambda p: 'FB_Mock')

    # Mock canonicalize_pou_bytes to avoid reading real bundle
    monkeypatch.setattr(fb_gen, 'canonicalize_pou_bytes', lambda bundle, pou: b'fake-bytes')

    generated = {}

    def fake_generate_module_and_test(pou_name, out_dir):
        # create files to simulate generation
        out_dir = pathlib.Path(out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        module = out_dir / f"{pou_name}.py"
        tests_dir = out_dir / 'tests'
        tests_dir.mkdir(exist_ok=True)
        test_file = tests_dir / f"test_{pou_name}.py"
        module.write_text(f"# dummy module for {pou_name}\n")
        test_file.write_text(f"# dummy test for {pou_name}\n")
        generated['module'] = str(module)
        generated['test'] = str(test_file)
        return str(module), str(test_file), str(out_dir / f"{pou_name}.meta.json")

    monkeypatch.setattr(fb_gen, 'generate_module_and_test', fake_generate_module_and_test)

    # Use a temporary out dir
    out_dir = str(tmp_path / 'out')

    # Make sure cache operations don't write outside tmp
    tmp_cache = tmp_path / '.st2py_cache.json'
    monkeypatch.setattr(fb_gen, 'load_cache', lambda base: {})
    monkeypatch.setattr(fb_gen, 'save_cache', lambda base, cache: tmp_cache.write_text(json.dumps(cache)))

    # Run fb_gen in changed mode by setting argv
    argv = ['fb_gen.py', '--bundle', str(tmp_path / 'CODE_Bundle.xml'), '--out', out_dir, '--changed', '--ref', 'origin/main', '--force']
    monkeypatch.setattr(sys, 'argv', argv)

    # Act
    # main() calls sys.exit; capture SystemExit
    with pytest.raises(SystemExit) as exc:
        fb_gen.main()
    # Expect exit code 0 (normal)
    assert exc.value.code == 0

    # Assert that files were created
    assert 'module' in generated and pathlib.Path(generated['module']).exists()
    assert 'test' in generated and pathlib.Path(generated['test']).exists()


def test_changed_bundle_triggers_all_pous_generation(tmp_path, monkeypatch):
    # Arrange: simulate bundle changed
    changed_files = ['CODE/CODE_Bundle.xml']
    monkeypatch.setattr(fb_gen, 'git_changed_files', lambda ref: changed_files)

    # Mock list_pous_from_bundle to return multiple POUs
    monkeypatch.setattr(fb_gen, 'list_pous_from_bundle', lambda bundle: ['FB_A', 'FB_B'])

    # Mock canonicalize and generation
    monkeypatch.setattr(fb_gen, 'canonicalize_pou_bytes', lambda bundle, pou: b'bytes')

    generated = []
    def fake_generate(pou_name, out_dir):
        p = pathlib.Path(out_dir)
        p.mkdir(parents=True, exist_ok=True)
        (p / f"{pou_name}.py").write_text('#')
        (p / 'tests').mkdir(exist_ok=True)
        (p / 'tests' / f"test_{pou_name}.py").write_text('#')
        generated.append(pou_name)
        return str(p / f"{pou_name}.py"), str(p / 'tests' / f"test_{pou_name}.py"), str(p / f"{pou_name}.meta.json")

    monkeypatch.setattr(fb_gen, 'generate_module_and_test', fake_generate)
    monkeypatch.setattr(fb_gen, 'load_cache', lambda base: {})
    monkeypatch.setattr(fb_gen, 'save_cache', lambda base, cache: None)

    out_dir = str(tmp_path / 'out2')
    argv = ['fb_gen.py', '--bundle', str(tmp_path / 'CODE_Bundle.xml'), '--out', out_dir, '--changed', '--ref', 'origin/main']
    monkeypatch.setattr(sys, 'argv', argv)

    with pytest.raises(SystemExit) as exc:
        fb_gen.main()
    assert exc.value.code == 0
    assert set(generated) == {'FB_A', 'FB_B'}
