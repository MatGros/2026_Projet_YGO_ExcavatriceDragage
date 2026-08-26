"""Tests pour le script extract_functions_matrix.py."""

from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"))

from extract_functions_matrix import build_matrix  # noqa: E402


def test_extract_functions_matrix_af08() -> None:
    data = build_matrix(REPO_ROOT / "DOC" / "AF")
    assert "AF-08" in data["domains"]
    af08 = data["domains"]["AF-08"]
    functions = af08["functions"]  # dict keyed par ID (filtrable directement par cle)
    assert set(functions.keys()) == {
        "F08.01", "F08.02", "F08.03", "F08.04",
        "F08.05", "F08.06", "F08.07", "F08.08",
    }

    # Vérifier que les TC couvrants et l'état sont renseignés.
    assert "TC-P08-010" in functions["F08.01"]["tc_couvrants"]
    assert "TC-P08-010" in functions["F08.02"]["tc_couvrants"]
    assert functions["F08.01"]["etat"] in {"NV", "NV-I"}
    assert "TC-P08-020" in functions["F08.03"]["tc_couvrants"]
    assert "TC-P08-020" in functions["F08.04"]["tc_couvrants"]
    assert "TC-P08-030" in functions["F08.05"]["tc_couvrants"]
    assert "TC-P08-040" in functions["F08.06"]["tc_couvrants"]
    assert "TC-P08-050" in functions["F08.07"]["tc_couvrants"]
    assert "TC-P08-060" in functions["F08.08"]["tc_couvrants"]

    # validation_points également filtrable par ID
    validation_points = af08["validation_points"]
    assert "TC-P08-010" in validation_points
    assert "TC-P08-020" in validation_points
    assert validation_points["TC-P08-010"]["etat"] in {"NV", "NV-I"}

    # AF01 contient une table de types d'essai avant son catalogue : seul le
    # catalogue TC doit être extrait.
    af01 = data["domains"]["AF-01"]
    assert "TC-P01-001" in af01["validation_points"]
    assert af01["validation_points"]["TC-P01-001"]["etat"] in {"NV", "NV-I"}
