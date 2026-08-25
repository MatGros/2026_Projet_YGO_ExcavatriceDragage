"""Tests pour le script extract_functions_matrix.py."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    yaml = None  # type: ignore

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "extract_functions_matrix.py"
REPO_ROOT = Path(__file__).resolve().parents[3]


def test_extract_functions_matrix_af08(tmp_path: Path) -> None:
    out_yaml = tmp_path / "output_matrix.yaml"
    cmd = [sys.executable, str(SCRIPT), "--root", str(REPO_ROOT), "--output", str(out_yaml)]
    res = subprocess.run(cmd, capture_output=True, text=True)
    assert res.returncode == 0, f"Script failed with stderr: {res.stderr}"
    assert out_yaml.is_file(), "Output YAML file was not created"

    # Vérification du contenu
    content = out_yaml.read_text(encoding="utf-8")
    assert "domains:" in content

    if yaml is not None:
        data = yaml.safe_load(content)
        assert "domains" in data
        assert "AF-08" in data["domains"]
        af08 = data["domains"]["AF-08"]
        functions = af08["functions"]  # dict keyed par ID (filtrable directement par cle)
        assert set(functions.keys()) == {
            "F08.01",
            "F08.02",
            "F08.03",
            "F08.04",
            "F08.05",
            "F08.06",
            "F08.07",
            "F08.08",
        }

        # Vérifier que les TC couvrants sont bien renseignés
        assert "TC-P08-014" in functions["F08.02"]["tc_couvrants"]
        assert "TC-P08-002" in functions["F08.03"]["tc_couvrants"]
        assert "TC-P08-006" in functions["F08.07"]["tc_couvrants"]
        assert "TC-P08-009" in functions["F08.07"]["tc_couvrants"]
        assert "TC-P08-010" in functions["F08.07"]["tc_couvrants"]

        # validation_points egalement filtrable par ID
        validation_points = af08["validation_points"]
        assert "TC-P08-002" in validation_points
    else:
        # Fallback vérification textuelle
        for i in range(1, 9):
            assert f"F08.0{i}" in content
        assert "TC-P08-014" in content
        assert "TC-P08-002" in content
