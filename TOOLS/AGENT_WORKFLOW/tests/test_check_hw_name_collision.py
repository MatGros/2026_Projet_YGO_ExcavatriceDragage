"""Tests de non-regression du gate collision noms HW (REX 2026-08-05, frein M3 jamais pilote)."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "check_hw_name_collision.py"
SPEC = importlib.util.spec_from_file_location("check_hw_name_collision", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
check_hw_name_collision = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = check_hw_name_collision
SPEC.loader.exec_module(check_hw_name_collision)

REPO_ROOT = Path(__file__).resolve().parents[3]


def test_csv_reel_contient_les_noms_connus_du_bug_frein_m3() -> None:
    csv_path = REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "config" / "Device_IO_20260729.csv"
    names = check_hw_name_collision.load_hw_names(csv_path)
    assert "M3_BrakeRelease_RQ" in names
    assert "M1_RelayFwd_Up_DQ" in names
    assert "M1_ThermalOk_DI" in names


def test_declared_names_extrait_var_output_et_var_input() -> None:
    text = """
PROGRAM PRG_TEST
VAR_OUTPUT
    M3_BrakeRelease_RQ : BOOL;
    SomeOtherOutput     : BOOL;
END_VAR
VAR
    LocalOnly : BOOL;
END_VAR
"""
    names = {name for name, _ in check_hw_name_collision.declared_names(text)}
    assert {"M3_BrakeRelease_RQ", "SomeOtherOutput", "LocalOnly"} <= names


def test_declaration_dans_prg_non_acquisition_est_une_erreur(tmp_path, monkeypatch) -> None:
    root = tmp_path
    main_dir = root / "CODE" / "MAIN"
    main_dir.mkdir(parents=True)
    (root / "TOOLS" / "AGENT_WORKFLOW" / "config").mkdir(parents=True)
    (root / "TOOLS" / "AGENT_WORKFLOW" / "config" / "Device_IO_20260729.csv").write_text(
        "//header\nM3_BrakeRelease_RQ;Bit;;desc;%QX0.0;Device\n", encoding="utf-8"
    )
    (main_dir / "PRG_06_Outputs_LD.st").write_text(
        "PROGRAM PRG_06_Outputs_LD\nVAR_OUTPUT\n    M3_BrakeRelease_RQ : BOOL;\nEND_VAR\n",
        encoding="utf-8",
    )

    monkeypatch.setattr(sys, "argv", ["check_hw_name_collision.py", str(root)])
    exit_code = check_hw_name_collision.main()
    assert exit_code == 1


def test_frontiere_acquisition_est_exemptee(tmp_path, monkeypatch) -> None:
    root = tmp_path
    main_dir = root / "CODE" / "MAIN"
    main_dir.mkdir(parents=True)
    (root / "TOOLS" / "AGENT_WORKFLOW" / "config").mkdir(parents=True)
    (root / "TOOLS" / "AGENT_WORKFLOW" / "config" / "Device_IO_20260729.csv").write_text(
        "//header\nM1_ThermalOk_DI;Bit;;desc;%IX0.1;Device\n", encoding="utf-8"
    )
    (main_dir / "PRG_02_Acquisition.st").write_text(
        "PROGRAM PRG_02_Acquisition\nVAR_INPUT\n    M1_ThermalOk_DI : BOOL;\nEND_VAR\n",
        encoding="utf-8",
    )

    monkeypatch.setattr(sys, "argv", ["check_hw_name_collision.py", str(root)])
    exit_code = check_hw_name_collision.main()
    assert exit_code == 0


def test_pending_field_verification_est_warn_pas_error(tmp_path, monkeypatch) -> None:
    """Mecanisme de pause WARN (voir docstring PENDING_FIELD_VERIFICATION) — vide en
    production depuis 2026-08-05, ici peuple artificiellement pour prouver qu'il
    fonctionne toujours si un futur cas non-verifie terrain doit y transiter."""
    monkeypatch.setattr(check_hw_name_collision, "PENDING_FIELD_VERIFICATION", {"TestPendingVar_RQ"})
    root = tmp_path
    main_dir = root / "CODE" / "MAIN"
    main_dir.mkdir(parents=True)
    (root / "TOOLS" / "AGENT_WORKFLOW" / "config").mkdir(parents=True)
    (root / "TOOLS" / "AGENT_WORKFLOW" / "config" / "Device_IO_20260729.csv").write_text(
        "//header\nTestPendingVar_RQ;Bit;;desc;%QX0.0;Device\n", encoding="utf-8"
    )
    (main_dir / "PRG_06_Outputs_LD.st").write_text(
        "PROGRAM PRG_06_Outputs_LD\nVAR_OUTPUT\n    TestPendingVar_RQ : BOOL;\nEND_VAR\n",
        encoding="utf-8",
    )

    monkeypatch.setattr(sys, "argv", ["check_hw_name_collision.py", str(root)])
    exit_code = check_hw_name_collision.main()
    assert exit_code == 0, "PENDING_FIELD_VERIFICATION doit rester non-bloquant (WARN)"


def test_codebase_reelle_ne_regresse_pas(monkeypatch) -> None:
    """Preuve de non-regression : le vrai depot, apres le fix M1/M2/M3, doit rester PASS."""
    monkeypatch.setattr(sys, "argv", ["check_hw_name_collision.py", str(REPO_ROOT)])
    exit_code = check_hw_name_collision.main()
    assert exit_code == 0
