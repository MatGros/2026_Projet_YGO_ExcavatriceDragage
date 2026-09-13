from __future__ import annotations

import importlib.util
from pathlib import Path
from unittest.mock import Mock


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "G345_check_workspace_hygiene.py"
SPEC = importlib.util.spec_from_file_location("g345", SCRIPT)
assert SPEC and SPEC.loader
G345 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(G345)


def root_with_dirs(*names: str) -> Mock:
    class Directory:
        def __init__(self, name: str) -> None:
            self.name = name

        def is_dir(self) -> bool:
            return True

    root = Mock()
    root.iterdir.return_value = [Directory(name) for name in names]
    return root


def test_clean_workspace_passes() -> None:
    errors, warnings = G345.find_violations(root_with_dirs(), set(), set())
    assert errors == []
    assert warnings == []


def test_new_root_scratch_fails() -> None:
    errors, _warnings = G345.find_violations(root_with_dirs(".tmp_new_run"), set(), set())
    assert errors == ["scratch interdit a la racine : .tmp_new_run"]


def test_known_legacy_scratch_warns_without_hiding_it() -> None:
    errors, warnings = G345.find_violations(root_with_dirs(".tmp_t257_winch"), {".tmp_t257_winch"}, {".tmp_t257_winch/result.txt"})
    assert errors == []
    assert "dette T279 presente a la racine : .tmp_t257_winch" in warnings
    assert "fichiers Git historiques en zone scratch : .tmp_t257_winch (1)" in warnings


def test_tracked_file_in_new_scratch_fails() -> None:
    errors, _warnings = G345.find_violations(root_with_dirs(), set(), {".dsh_tmp/new/source.st"})
    assert errors == ["fichier Git suivi en zone scratch interdite : .dsh_tmp/new/source.st"]


def test_baseline_requires_only_root_scratch_names() -> None:
    baseline = Mock()
    baseline.read_text.return_value = '{"legacy_root_scratch_dirs": ["DOC/WFLOW"]}'
    try:
        G345.load_baseline(baseline)
    except ValueError:
        return
    raise AssertionError("baseline invalide acceptee")
