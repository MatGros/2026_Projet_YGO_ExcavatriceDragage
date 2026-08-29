"""Tests pour generate_af_viewer.py — section 4 (tracabilite Fonction -> TC -> Test CI)."""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"))

from generate_af_viewer import (  # noqa: E402
    MATRIX_PATH,
    _canonical_tc_ids,
    _traceability,
    _vp_lookup,
)


def _matrix() -> dict:
    return yaml.safe_load(MATRIX_PATH.read_text(encoding="utf-8")) or {}


def test_canonical_tc_ids_expands_compact_and_slash_forms() -> None:
    assert _canonical_tc_ids("TC-P01-004/009") == ["TC-P01-004", "TC-P01-009"]
    assert _canonical_tc_ids("TC-P10-011, 017-019") == ["TC-P10-011"]
    assert _canonical_tc_ids("aucun") == []


def test_vp_lookup_resolves_composite_keys() -> None:
    vp = {
        "TC-P01-001, TC-P01-008": {"intention": "combo", "type": "AUTO"},
        "TC-P01-003": {"intention": "solo", "type": "AUTO_PLC"},
    }
    table = _vp_lookup(vp)
    assert table["TC-P01-001"]["intention"] == "combo"
    assert table["TC-P01-008"]["intention"] == "combo"
    assert table["TC-P01-003"]["type"] == "AUTO_PLC"


def test_traceability_structure_on_real_repo() -> None:
    tr = _traceability(_matrix(), REPO_ROOT)

    # structure du dict
    for key in ("rows", "fn_no_tc", "tc_orphan", "tc_no_ci", "counts"):
        assert key in tr
    for key in ("functions", "functions_with_ci_pass", "functions_with_gap"):
        assert key in tr["counts"]
        assert isinstance(tr["counts"][key], int)

    rows = tr["rows"]
    assert rows, "au moins une fonction dans la matrice"
    assert tr["counts"]["functions"] == len(rows)
    assert 0 <= tr["counts"]["functions_with_ci_pass"] <= len(rows)
    assert 0 <= tr["counts"]["functions_with_gap"] <= len(rows)
    assert len(tr["fn_no_tc"]) <= len(rows)

    # chaque row a le contrat attendu
    for r in rows:
        assert set(r) == {"af", "fid", "fonction", "criticite", "realisee_par", "tcs", "ci"}
        assert r["ci"]["verdict"] in {"pass", "fail", "none"}
        for t in r["tcs"]:
            assert set(t) == {"id", "intention", "type", "in_ci_title"}
            assert isinstance(t["in_ci_title"], bool)


def test_traceability_links_safety_emergency_to_its_ci_report() -> None:
    """FB_Safety_EmergencyManagement est une cle du registry avec un rapport JSON present."""
    tr = _traceability(_matrix(), REPO_ROOT)
    safety = [
        r for r in tr["rows"]
        if r["af"] == "AF-01" and "FB_Safety_EmergencyManagement" in r["realisee_par"]
    ]
    assert safety, "les fonctions F01.* doivent etre presentes"
    with_ci = [r for r in safety if r["ci"]["verdict"] != "none"]
    assert with_ci, "au moins une F01.* doit resoudre un verdict CI"
    r = with_ci[0]
    assert r["ci"]["report_rel"].endswith("FB_Safety_EmergencyManagement.html")
    assert r["ci"]["total"] > 0


def test_at_least_one_report_rel_points_to_an_existing_html() -> None:
    tr = _traceability(_matrix(), REPO_ROOT)
    wflow = REPO_ROOT / "DOC" / "WFLOW"
    existing = [
        r for r in tr["rows"]
        if r["ci"]["report_rel"] and (wflow / r["ci"]["report_rel"]).resolve().is_file()
    ]
    assert existing, "au moins un rapport .html reference doit exister sur disque"
