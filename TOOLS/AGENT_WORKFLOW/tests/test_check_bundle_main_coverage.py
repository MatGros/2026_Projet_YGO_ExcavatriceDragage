"""Regression tests for the CODE/MAIN bundle coverage and identity guard."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "G320_check_bundle_main_coverage.py"
ROOT = Path(__file__).resolve().parents[3]


def program(name: str) -> str:
    return f"PROGRAM {name}\nVAR\n    Value : BOOL;\nEND_VAR\nValue := TRUE;\n"


def native_cfc(name: str) -> str:
    return f'<project><pou name="{name}" pouType="program"><body><CFC /></body></pou></project>'


def bundle(pous: list[tuple[str, str]]) -> str:
    body = "\n".join(
        f'<pou name="{name}" pouType="program"><body><{language} /></body></pou>'
        for name, language in pous
    )
    return f"<project>{body}</project>"


def make_project(
    tmp_path: Path, sources: dict[str, str], emitted: list[tuple[str, str]]
) -> Path:
    for relative, content in sources.items():
        source = tmp_path / "CODE" / "MAIN" / relative
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_text(content, encoding="utf-8")
    output = tmp_path / "CODE_XML" / "CODE_Bundle.xml"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(bundle(emitted), encoding="utf-8")
    return tmp_path


def run(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root), *args],
        capture_output=True,
        text=True,
    )


def test_all_main_source_languages_are_accepted(tmp_path: Path) -> None:
    root = make_project(
        tmp_path,
        {
            "PRG_01_Cycle.st": program("PRG_01_Cycle"),
            "PRG_03_Acquisition_CFC.xml": native_cfc("PRG_03_Acquisition_CFC"),
        },
        [
            ("PRG_01_Cycle", "ST"),
            ("PRG_03_Acquisition_CFC", "CFC"),
        ],
    )

    result = run(root)

    assert result.returncode == 0, result.stderr
    assert "Bundle MAIN coverage: PASS" in result.stdout
    assert "Bundle MAIN identity: PASS" in result.stdout


def test_missing_main_pou_is_rejected_with_its_name(tmp_path: Path) -> None:
    root = make_project(
        tmp_path,
        {"PRG_01_Cycle.st": program("PRG_01_Cycle")},
        [],
    )

    result = run(root)

    assert result.returncode == 1
    assert "[BMC2]" in result.stderr
    assert "PRG_01_Cycle" in result.stderr


def test_duplicate_main_pou_is_rejected_with_its_name(tmp_path: Path) -> None:
    root = make_project(
        tmp_path,
        {"PRG_01_Cycle.st": program("PRG_01_Cycle")},
        [("PRG_01_Cycle", "ST"), ("PRG_01_Cycle", "ST")],
    )

    result = run(root)

    assert result.returncode == 1
    assert "[BMC2]" in result.stderr
    assert "PRG_01_Cycle" in result.stderr


def test_wrong_main_pou_language_is_rejected_with_its_name(tmp_path: Path) -> None:
    root = make_project(
        tmp_path,
        {"PRG_03_Acquisition_CFC.xml": native_cfc("PRG_03_Acquisition_CFC")},
        [("PRG_03_Acquisition_CFC", "ST")],
    )

    result = run(root)

    assert result.returncode == 1
    assert "[BMC3]" in result.stderr
    assert "PRG_03_Acquisition_CFC" in result.stderr


def test_filename_and_declared_program_mismatch_is_identity_failure(tmp_path: Path) -> None:
    root = make_project(
        tmp_path,
        {"PRG_Outputs.st": program("PRG_10_Outputs")},
        [("PRG_10_Outputs", "ST")],
    )

    result = run(root)

    assert result.returncode == 1
    assert "[BMI1]" in result.stderr
    assert "basename `PRG_Outputs` != PROGRAM declare `PRG_10_Outputs`" in result.stderr
    assert "Bundle MAIN coverage: PASS" in result.stdout
    assert "Bundle MAIN identity: FAIL" in result.stdout


def test_xml_filename_and_declared_pou_mismatch_is_identity_failure(tmp_path: Path) -> None:
    root = make_project(
        tmp_path,
        {"PRG_03_Acquisition_CFC.xml": native_cfc("PRG_04_Acquisition_CFC")},
        [("PRG_04_Acquisition_CFC", "CFC")],
    )

    result = run(root)

    assert result.returncode == 1
    assert "[BMI1]" in result.stderr
    assert "XML pou/@name `PRG_04_Acquisition_CFC`" in result.stderr
    assert "Bundle MAIN coverage: PASS" in result.stdout


def test_xml_pou_and_bundle_name_mismatch_is_rejected(tmp_path: Path) -> None:
    root = make_project(
        tmp_path,
        {"PRG_03_Acquisition_CFC.xml": native_cfc("PRG_03_Acquisition_CFC")},
        [("PRG_04_Acquisition_CFC", "CFC")],
    )

    result = run(root)

    assert result.returncode == 1
    assert "[BMC2] PRG_03_Acquisition_CFC" in result.stderr
    assert "Bundle MAIN coverage: FAIL" in result.stdout
    assert "Bundle MAIN identity: PASS" in result.stdout


def test_wrong_or_missing_program_number_is_identity_failure(tmp_path: Path) -> None:
    root = make_project(
        tmp_path,
        {
            "PRG_1_Cycle.st": program("PRG_1_Cycle"),
            "PRG_Cycle.st": program("PRG_Cycle"),
        },
        [("PRG_1_Cycle", "ST"), ("PRG_Cycle", "ST")],
    )

    result = run(root)

    assert result.returncode == 1
    assert result.stderr.count("[BMI2]") == 2
    assert "PRG_1_Cycle" in result.stderr
    assert "PRG_Cycle" in result.stderr
    assert "Bundle MAIN coverage: PASS" in result.stdout


def test_report_separates_current_valid_coverage_from_legacy_identity_failures() -> None:
    result = run(ROOT, "--report")

    assert result.returncode == 0
    assert "Bundle MAIN coverage: PASS" in result.stdout
    assert "Bundle MAIN identity: PASS" in result.stdout
    assert "Rapport couverture MAIN / identite POU" in result.stdout
