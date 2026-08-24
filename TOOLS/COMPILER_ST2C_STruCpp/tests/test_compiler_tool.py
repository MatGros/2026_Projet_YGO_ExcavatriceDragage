"""Tests Pytest pour le moteur TOOLS/COMPILER_ST2C_STruCpp."""

from pathlib import Path
import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
COMPILER_DIR = REPO_ROOT / "TOOLS" / "COMPILER_ST2C_STruCpp"
CONVERTER_PY = COMPILER_DIR / "convert_codesys_to_iec.py"
STRUCPP_EXE = COMPILER_DIR / "bin" / "win32-x64" / "strucpp.exe"


def test_compiler_binary_and_converter_present():
    """Vérifie que convert_codesys_to_iec.py et strucpp.exe sont présents."""
    assert CONVERTER_PY.exists(), f"convert_codesys_to_iec.py introuvable dans {COMPILER_DIR}"
    assert STRUCPP_EXE.exists(), f"strucpp.exe introuvable dans {STRUCPP_EXE}"
