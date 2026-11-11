"""T430: consumers survive moves without silently choosing or overwriting evidence."""
from __future__ import annotations

import importlib.util
import json
from datetime import date
from pathlib import Path

import pytest


SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"


def load(name: str):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


G525 = load("G525_inventaire_transitions_gel")
T356 = load("T356_scan_alarm_candidates")
GEL_NAME = "TXXX_GEL_GRAFCET_SEMIAUTO_20260903.md"


def write(root: Path, relative: str, text: str) -> Path:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def gel_fixture(root: Path) -> Path:
    path = write(root, f"DOC/WFLOW/TASKS/T_TEMP (A TRIIER)/AUDITS/{GEL_NAME}",
                 "| **AX1** (1) |\n| **AT1** | vers **AX2** |\n")
    write(root, G525.CODE,
          "E_AutoCycleStep.AX1:\n    State := E_AutoCycleStep.AX2;\n")
    return path


def test_g525_moved_gel_and_nonempty_inventory(tmp_path, capsys):
    expected = gel_fixture(tmp_path)
    assert G525.resolve_gel(tmp_path) == expected
    assert G525.main([str(tmp_path)]) == 0
    out = capsys.readouterr().out
    assert str(expected) in out
    assert "TRANSITIONS DECLAREES AU GEL : 1" in out
    assert "TRANSITIONS CODEES (State := AX...) : 1" in out
    assert "CONFORME AU GEL" in out


def test_g525_missing_source_is_error(tmp_path, capsys):
    assert G525.main([str(tmp_path)]) == 2
    assert "attendu unique, trouve 0" in capsys.readouterr().err


def test_g525_ambiguous_sources_are_error(tmp_path, capsys):
    gel_fixture(tmp_path)
    write(tmp_path, f"DOC/WFLOW/TASKS/T123_OTHER/{GEL_NAME}", "# other source\n")
    assert G525.main([str(tmp_path)]) == 2
    assert "attendu unique, trouve 2" in capsys.readouterr().err


def test_g525_ignores_example_archives_and_amendment(tmp_path):
    expected = gel_fixture(tmp_path)
    for relative in [f"DOC/WFLOW/TASKS/TXXX/{GEL_NAME}",
                     f"DOC/WFLOW/TASKS/T123_OTHER/ARCHIVES/{GEL_NAME}",
                     f"DOC/WFLOW/TASKS/T123_OTHER/archives/{GEL_NAME}",
                     "DOC/WFLOW/TASKS/T123_OTHER/T383_AMENDEMENT_GEL_GRAFCET_SEMIAUTO_20260922.md"]:
        write(tmp_path, relative, "# not the active GEL\n")
    assert G525.resolve_gel(tmp_path) == expected


def test_g525_explicit_gel_still_rejects_archives(tmp_path):
    archived = write(tmp_path, "ARCHIVES/GEL.md", "# archived\n")
    with pytest.raises(ValueError, match="non actif"):
        G525.resolve_gel(tmp_path, archived)


def test_g525_empty_inventory_is_error(tmp_path, capsys):
    path = gel_fixture(tmp_path)
    path.write_text("# no transition\n", encoding="utf-8")
    assert G525.main([str(tmp_path)]) == 2
    assert "Inventaire vide" in capsys.readouterr().err


def test_g525_inventory_success_is_not_transition_validation(tmp_path, capsys):
    gel_fixture(tmp_path)
    write(tmp_path, G525.CODE, "E_AutoCycleStep.AX2:\n State := E_AutoCycleStep.AX1;\n")
    assert G525.main([str(tmp_path)]) == 0
    out = capsys.readouterr().out
    assert "NON DECLAREE AU GEL" in out
    assert "SAUT ARRIERE" in out
    assert "pas une validation des transitions" in out


def scanner_fixture(root: Path) -> None:
    write(root, "CODE/FB_Probe.st",
          "FUNCTION_BLOCK FB_Probe\nVAR\n FaultSignal : BOOL;\nEND_VAR\nIF FaultSignal THEN\nEND_IF\n")


def test_t356_requires_explicit_destination(tmp_path, monkeypatch):
    scanner_fixture(tmp_path)
    monkeypatch.chdir(tmp_path)
    with pytest.raises(SystemExit) as exc:
        T356.main([])
    assert exc.value.code == 2
    assert not (tmp_path / "DOC").exists()


def test_t356_out_without_root_new_names_and_counts(tmp_path, monkeypatch):
    scanner_fixture(tmp_path)
    monkeypatch.chdir(tmp_path)
    out = tmp_path / "new run (1)"
    assert T356.main(["--out", str(out)]) == 0
    assert {p.name for p in out.iterdir()} == set(T356.output_names())
    assert len(list(out.glob("*.csv"))) == 7
    assert len(list(out.glob("*.json"))) == 1
    payload = json.loads(next(out.glob("*.json")).read_text(encoding="utf-8"))
    assert payload["fichiers_st"] == 1
    assert payload["candidats_declarations"] == 1
    assert payload["references_scannees"] >= 2
    assert payload["source_root"] == tmp_path.as_posix()
    assert payload["generated_at"]
    assert not (tmp_path / "DOC/WFLOW/AUDITS").exists()


@pytest.mark.parametrize("occupied", [False, True])
def test_t356_refuses_existing_destination_even_empty(tmp_path, occupied):
    scanner_fixture(tmp_path)
    out = tmp_path / "existing"
    out.mkdir()
    if occupied:
        (out / "historical.txt").write_bytes(b"keep this evidence")
    before = {p.name: p.read_bytes() for p in out.iterdir()}
    assert T356.main([str(tmp_path), "--out", str(out)]) == 2
    assert {p.name: p.read_bytes() for p in out.iterdir()} == before


def test_t356_preserves_all_nine_historical_annexes(tmp_path):
    scanner_fixture(tmp_path)
    history = tmp_path / "DOC/WFLOW/TASKS/T_TEMP (A TRIIER)/AUDITS"
    history.mkdir(parents=True)
    for i in range(9):
        (history / f"T356_HISTORICAL_{i}_20260921.csv").write_bytes(f"evidence {i}".encode())
    before = {p.name: p.read_bytes() for p in history.iterdir()}
    assert T356.main([str(tmp_path), "--out", str(tmp_path / "new")]) == 0
    assert {p.name: p.read_bytes() for p in history.iterdir()} == before
    assert not (tmp_path / "DOC/WFLOW/AUDITS").exists()


def test_t356_missing_code_does_not_create_output(tmp_path):
    out = tmp_path / "new"
    assert T356.main([str(tmp_path), "--out", str(out)]) == 2
    assert not out.exists()


def test_t356_output_names_use_run_date():
    names = T356.output_names(date(2026, 11, 11))
    assert len(names) == 8
    assert all(name.endswith(("_20261111.csv", "_20261111.json")) for name in names)
    assert names[-1] == "T356_SYNTHESE_ALARMES_SCAN_20261111.json"
