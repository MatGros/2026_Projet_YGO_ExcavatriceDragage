"""Tests de non-regression du gate de structure des PROGRAM."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "G310_check_code_structure.py"


def program(name: str) -> str:
    return f"PROGRAM {name}\nVAR\n    Value : BOOL;\nEND_VAR\nValue := TRUE;\nEND_PROGRAM\n"


def function_block(name: str) -> str:
    return f"FUNCTION_BLOCK {name}\nVAR_INPUT\n    Enable : BOOL;\nEND_VAR\nQ := Enable;\nEND_FUNCTION_BLOCK\n"


def bundle(pous: dict[str, str]) -> str:
    body = "\n".join(
        f'<pou name="{name}"><body><{language}/></body></pou>'
        for name, language in pous.items()
    )
    return f"<project>{body}</project>"


def make_project(tmp_path: Path, sources: dict[str, str], emitted: dict[str, str]) -> Path:
    root = tmp_path
    for relative, content in sources.items():
        path = root / "CODE" / "MAIN" / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    bundle_path = root / "CODE_XML" / "CODE_Bundle.xml"
    bundle_path.parent.mkdir(parents=True, exist_ok=True)
    bundle_path.write_text(bundle(emitted), encoding="utf-8")
    return root


def run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def test_s1_fichier_different_du_nom_program(tmp_path: Path) -> None:
    root = make_project(
        tmp_path,
        {"PRG_Outputs.st": program("PRG_10_Outputs")},
        {"PRG_10_Outputs": "ST"},
    )

    result = run(root)

    assert result.returncode == 1
    assert "[S1]" in result.stderr
    assert "PRG_Outputs" in result.stderr
    assert "PRG_10_Outputs" in result.stderr


def test_s3_program_non_numerote_est_refuse(tmp_path: Path) -> None:
    root = make_project(
        tmp_path,
        {"PRG_Acquisition.st": program("PRG_Acquisition")},
        {"PRG_Acquisition": "ST"},
    )

    result = run(root)

    assert result.returncode == 1
    assert "[S3]" in result.stderr
    assert "PRG_XX_" in result.stderr


def test_cfc_xml_natif_est_accepte(tmp_path: Path) -> None:
    cfc_source = """<project><pou name=\"PRG_01_Acquisition_CFC\"><body><CFC/></body></pou></project>"""
    root = make_project(
        tmp_path,
        {"PRG_01_Acquisition_CFC.xml": cfc_source},
        {"PRG_01_Acquisition_CFC": "CFC"},
    )

    result = run(root)

    assert result.returncode == 0, result.stderr
    assert "PASS" in result.stdout


def test_bundle_absent_est_refuse(tmp_path: Path) -> None:
    root = tmp_path
    source = root / "CODE" / "MAIN" / "PRG_01_Cycle.st"
    source.parent.mkdir(parents=True)
    source.write_text(program("PRG_01_Cycle"), encoding="utf-8")

    result = run(root)

    assert result.returncode == 1
    assert "[S0]" in result.stderr
    assert "bundle introuvable" in result.stderr


# ---------------------------------------------------------------------------
# S4 — Epilogue END_PROGRAM / END_FUNCTION_BLOCK
# ---------------------------------------------------------------------------

def test_s4_program_un_end_program_accepte(tmp_path: Path) -> None:
    """Un PROGRAM avec exactement un END_PROGRAM est valide."""
    root = make_project(
        tmp_path,
        {"PRG_01_Cycle.st": program("PRG_01_Cycle")},
        {"PRG_01_Cycle": "ST"},
    )

    result = run(root)

    assert result.returncode == 0, result.stderr
    assert "PASS" in result.stdout


def test_s4_double_end_program_refuse(tmp_path: Path) -> None:
    """Deux END_PROGRAM dans un meme fichier — bug historique PRG_MODES_CFC.st."""
    source = (
        "PROGRAM PRG_01_Cycle\n"
        "VAR\n    V : BOOL;\nEND_VAR\n"
        "V := TRUE;\n"
        "END_PROGRAM\n"
        "END_PROGRAM\n"
    )
    root = make_project(
        tmp_path,
        {"PRG_01_Cycle.st": source},
        {"PRG_01_Cycle": "ST"},
    )

    result = run(root)

    assert result.returncode == 1
    assert "[S4]" in result.stderr
    assert "2 END_PROGRAM" in result.stderr


def test_s4_program_zero_end_program_ignorer(tmp_path: Path) -> None:
    """PROGRAM sans END_PROGRAM — fragment incomplet, ignore par S4."""
    source = "PROGRAM PRG_01_Cycle\nVAR\n    V : BOOL;\nEND_VAR\nV := TRUE;\n"
    root = make_project(
        tmp_path,
        {"PRG_01_Cycle.st": source},
        {"PRG_01_Cycle": "ST"},
    )

    result = run(root)

    # S4 ne signale pas les fragments sans epilogue. S3 peut signaler le
    # prefixe manquant mais ce test n'utilise pas de prefixe — on verifie juste
    # qu'aucune erreur S4 n'est remontee.
    assert "[S4]" not in result.stderr


def test_s4_program_avec_end_fb_refuse(tmp_path: Path) -> None:
    """PROGRAM avec END_FUNCTION_BLOCK au lieu de END_PROGRAM."""
    source = (
        "PROGRAM PRG_01_Cycle\n"
        "VAR\n    V : BOOL;\nEND_VAR\n"
        "V := TRUE;\n"
        "END_FUNCTION_BLOCK\n"
    )
    root = make_project(
        tmp_path,
        {"PRG_01_Cycle.st": source},
        {"PRG_01_Cycle": "ST"},
    )

    result = run(root)

    assert result.returncode == 1
    assert "[S4]" in result.stderr
    assert "END_FUNCTION_BLOCK" in result.stderr


def test_s4_fb_un_end_fb_accepte(tmp_path: Path) -> None:
    """Un FUNCTION_BLOCK avec exactement un END_FUNCTION_BLOCK est valide."""
    root = make_project(
        tmp_path,
        {"PRG_01_Cycle.st": program("PRG_01_Cycle"),
         "FB_Foo.st": function_block("FB_Foo")},
        {"PRG_01_Cycle": "ST"},
    )
    # Place FB outside MAIN to match real project layout
    fb_path = root / "CODE" / "COMMUN" / "FB_Foo.st"
    fb_path.parent.mkdir(parents=True, exist_ok=True)
    fb_path.write_text(function_block("FB_Foo"), encoding="utf-8")
    (root / "CODE" / "MAIN" / "FB_Foo.st").unlink()

    result = run(root)

    assert result.returncode == 0, result.stderr
    assert "PASS" in result.stdout


def test_s4_fb_double_end_fb_refuse(tmp_path: Path) -> None:
    """Deux END_FUNCTION_BLOCK dans un meme fichier."""
    source = function_block("FB_Foo") + "END_FUNCTION_BLOCK\n"
    root = make_project(
        tmp_path,
        {"PRG_01_Cycle.st": program("PRG_01_Cycle")},
        {"PRG_01_Cycle": "ST"},
    )
    fb_path = root / "CODE" / "COMMUN" / "FB_Foo.st"
    fb_path.parent.mkdir(parents=True, exist_ok=True)
    fb_path.write_text(source, encoding="utf-8")

    result = run(root)

    assert result.returncode == 1
    assert "[S4]" in result.stderr
    assert "2 END_FUNCTION_BLOCK" in result.stderr


def test_s4_fb_avec_end_program_refuse(tmp_path: Path) -> None:
    """FUNCTION_BLOCK avec END_PROGRAM au lieu de END_FUNCTION_BLOCK."""
    source = (
        "FUNCTION_BLOCK FB_Foo\n"
        "VAR_INPUT\n    Enable : BOOL;\nEND_VAR\n"
        "Q := Enable;\n"
        "END_PROGRAM\n"
    )
    root = make_project(
        tmp_path,
        {"PRG_01_Cycle.st": program("PRG_01_Cycle")},
        {"PRG_01_Cycle": "ST"},
    )
    fb_path = root / "CODE" / "COMMUN" / "FB_Foo.st"
    fb_path.parent.mkdir(parents=True, exist_ok=True)
    fb_path.write_text(source, encoding="utf-8")

    result = run(root)

    assert result.returncode == 1
    assert "[S4]" in result.stderr
    assert "END_PROGRAM" in result.stderr


def test_s4_fichier_non_pou_ignore(tmp_path: Path) -> None:
    """Un .st qui n'est ni PROGRAM ni FUNCTION_BLOCK (TYPE, GVL) est ignore."""
    source = "TYPE ST_Foo :\nSTRUCT\n    Val : BOOL;\nEND_STRUCT\nEND_TYPE\n"
    root = make_project(
        tmp_path,
        {"PRG_01_Cycle.st": program("PRG_01_Cycle")},
        {"PRG_01_Cycle": "ST"},
    )
    type_path = root / "CODE" / "COMMUN" / "ST_Foo.st"
    type_path.parent.mkdir(parents=True, exist_ok=True)
    type_path.write_text(source, encoding="utf-8")

    result = run(root)

    assert result.returncode == 0, result.stderr
    assert "PASS" in result.stdout
