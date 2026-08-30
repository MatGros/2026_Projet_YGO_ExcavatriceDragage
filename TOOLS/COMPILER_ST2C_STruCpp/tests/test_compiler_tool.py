"""Tests Pytest pour le moteur TOOLS/COMPILER_ST2C_STruCpp."""

from pathlib import Path
import sys
import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
COMPILER_DIR = REPO_ROOT / "TOOLS" / "COMPILER_ST2C_STruCpp"
CONVERTER_PY = COMPILER_DIR / "convert_codesys_to_iec.py"
STRUCPP_EXE = COMPILER_DIR / "bin" / "win32-x64" / "strucpp.exe"

sys.path.insert(0, str(COMPILER_DIR))
from convert_codesys_to_iec import _convert_comma_multi_dim_to_nested


def test_compiler_binary_and_converter_present():
    """Vérifie que convert_codesys_to_iec.py et strucpp.exe sont présents."""
    assert CONVERTER_PY.exists(), f"convert_codesys_to_iec.py introuvable dans {COMPILER_DIR}"
    assert STRUCPP_EXE.exists(), f"strucpp.exe introuvable dans {STRUCPP_EXE}"


def test_comma_index_2d_remains_single_runtime_access():
    source = "Value := LoadTable[StepIndex, SpeedBand];"

    assert _convert_comma_multi_dim_to_nested(source) == source


def test_comma_index_3d_becomes_nested_access():
    source = "Value := LearnTable[AxisIndex, DirectionIndex, LoadIndex];"

    assert _convert_comma_multi_dim_to_nested(source) == (
        "Value := LearnTable[AxisIndex][DirectionIndex][LoadIndex];"
    )


def test_comma_index_4d_becomes_nested_access():
    source = "Value := LearnTable[AxisIndex, DirectionIndex, LoadIndex, StepIndex];"

    assert _convert_comma_multi_dim_to_nested(source) == (
        "Value := LearnTable[AxisIndex][DirectionIndex][LoadIndex][StepIndex];"
    )
