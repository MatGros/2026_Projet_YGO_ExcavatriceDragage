"""Tests pour le script extract_functions_matrix.py."""

from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"))

from extract_functions_matrix import (  # noqa: E402
    build_matrix,
    extract_sections,
    is_variant_key,
    quality_report,
    tc_tokens,
)


def test_extract_sections_html_tables() -> None:
    """Garde-fou : les gabarits HTML migrés (AF P1) doivent être extraits, pas ignorés."""
    content = (
        "### 🎯 Table des fonctions\n"
        "\n"
        "<table style=\"width: 100%;\"><thead>\n"
        "<tr><th><b>ID</b></th><th>Fonction</th><th>Réalisée par</th>\n"
        "<th>Criticité</th><th>TC couvrants</th><th>Statut</th><th>État</th></tr>\n"
        "</thead><tbody>\n"
        "<tr><td>FNN.01</td><td>Test</td><td>FB_X</td><td>C2</td>\n"
        "<td>TC-PNN-001..002</td><td>✅</td><td>NV-I</td></tr>\n"
        "</tbody></table>\n"
        "\n"
        "## 2. Table des points de validation (non détaillé)\n"
        "\n"
        "<table style=\"width: 100%;\"><thead>\n"
        "<tr><th><b>ID</b></th><th>Intention</th><th>Type</th><th>Réf</th><th>État</th></tr>\n"
        "</thead><tbody>\n"
        "<tr><td>TC-PNN-001</td><td><b>Bloc</b></td><td>💻 AUTO</td><td>FB_X</td><td>NV-I</td></tr>\n"
        "</tbody></table>\n"
    )
    f_rows, v_rows = extract_sections(content)
    assert f_rows and f_rows[0]["ID"] == "FNN.01"
    assert f_rows[0]["TC couvrants"] == "TC-PNN-001..002"
    assert f_rows[0]["État"] == "NV-I"
    assert v_rows and v_rows[0]["ID"] == "TC-PNN-001"
    assert v_rows[0]["État"] == "NV-I"


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
    assert functions["F08.01"]["etat"] in {"V", "V-I", "NV", "NV-I", "R", "NA"}
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
    assert validation_points["TC-P08-010"]["etat"] in {"V", "V-I", "NV", "NV-I", "R", "NA"}

    # AF01 contient une table de types d'essai avant son catalogue : seul le
    # catalogue TC doit être extrait.
    af01 = data["domains"]["AF-01"]
    assert "TC-P01-001" in af01["validation_points"]
    assert af01["validation_points"]["TC-P01-001"]["etat"] in {"V", "V-I", "NV", "NV-I", "R", "NA"}


def test_tc_tokens_and_variants() -> None:
    """REX 2026-08-29 : canonisation des clés + familles volontaires .k."""
    assert tc_tokens("TC-P03-014.1") == ["TC-P03-014"]
    assert is_variant_key("TC-P03-014.1") is True
    assert is_variant_key("TC-P03-014") is False
    assert tc_tokens("TC-P01-001, TC-P01-008") == ["TC-P01-001", "TC-P01-008"]
    assert tc_tokens("Diagnostic charge 2D") == []
    assert tc_tokens("TC-P14-TSV-01") == []


def test_quality_report_overlap_detection() -> None:
    """Recouvrement composée+simple détecté ; famille .k et clés libres ignorés."""
    matrix = {
        "domains": {
            "AF-99": {
                "file": "x.md",
                "functions": {},
                "validation_points": {
                    "TC-P99-001": {"intention": "a"},
                    "TC-P99-001, TC-P99-002": {"intention": "b"},
                    "TC-P99-003.1": {"intention": "c"},
                    "Diagnostic libre": {"intention": "d"},
                },
            },
            "AF-98": {
                "file": "y.md",
                "functions": {},
                "validation_points": {"TC-P99-004": {"intention": "e"}},
            },
        }
    }
    rep = quality_report(matrix)
    assert rep["stats"]["unique_tc"] == 4  # 001, 002, 003, 004
    ov = {(o["domain"], o["tc"]) for o in rep["overlaps"]}
    assert ("AF-99", "TC-P99-001") in ov  # composée + simple = recouvrement
    assert ("AF-99", "TC-P99-002") not in ov  # une seule clé le déclare : légitime
    assert ("AF-99", "TC-P99-003") not in ov  # famille .k = non recouvrante
    assert rep["cross_domain"] == []
    assert {n["id"] for n in rep["non_canonical"]} == {"Diagnostic libre"}


def test_real_matrix_no_cross_domain_duplicate() -> None:
    """Sur le dépôt réel : aucun ID canonique partagé entre 2 domaines AF."""
    data = build_matrix(REPO_ROOT / "DOC" / "AF")
    rep = quality_report(data)
    assert rep["cross_domain"] == []
    assert rep["stats"]["domains"] == 14
    assert rep["stats"]["validation_points"] >= 200
