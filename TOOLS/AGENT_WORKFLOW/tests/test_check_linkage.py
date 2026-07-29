"""Tests de non-regression du gate de liaison.

Chaque test reproduit une classe de bug reellement vecue sur le projet.
Si un test devient rouge, c'est le gate qui est casse, pas le code ST.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "check_linkage.py"

FB_INTERLOCK = """\
FUNCTION_BLOCK PUBLIC FB_Interlock
VAR_INPUT
    Enable : BOOL;
END_VAR
VAR_OUTPUT
    RelayFwd : BOOL;
END_VAR
RelayFwd := Enable;
"""


def run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def make_project(tmp_path: Path, files: dict[str, str]) -> Path:
    for rel, content in files.items():
        target = tmp_path / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
    return tmp_path


def test_instance_declaree_et_appelee_passe(tmp_path: Path) -> None:
    root = make_project(
        tmp_path,
        {
            "CODE/TREUILS/FB_Interlock.st": FB_INTERLOCK,
            "CODE/MAIN/PRG_10_Outputs.st": """\
PROGRAM PRG_10_Outputs
VAR
    instInterlockM1 : FB_Interlock;
END_VAR
instInterlockM1(Enable := TRUE);
""",
        },
    )
    result = run(root)
    assert result.returncode == 0, result.stderr
    assert "PASS" in result.stdout


def test_l1_instance_declaree_jamais_appelee(tmp_path: Path) -> None:
    """REX PRG_10_Outputs_LD : le FB existe, il est bundle, mais jamais appele."""
    root = make_project(
        tmp_path,
        {
            "CODE/TREUILS/FB_Interlock.st": FB_INTERLOCK,
            "CODE/MAIN/PRG_10_Outputs.st": """\
PROGRAM PRG_10_Outputs
VAR
    instInterlockM1 : FB_Interlock;
END_VAR
Q1 := FALSE;
""",
        },
    )
    result = run(root)
    assert result.returncode == 1
    assert "[L1]" in result.stderr
    assert "instInterlockM1" in result.stderr


def test_l2_type_inconnu(tmp_path: Path) -> None:
    root = make_project(
        tmp_path,
        {
            "CODE/MAIN/PRG_10_Outputs.st": """\
PROGRAM PRG_10_Outputs
VAR
    instInterlockM1 : FB_TypoAbsent;
END_VAR
instInterlockM1(Enable := TRUE);
""",
        },
    )
    result = run(root)
    assert result.returncode == 1
    assert "[L2]" in result.stderr


def test_l3_appel_d_une_instance_declaree_ailleurs(tmp_path: Path) -> None:
    """L'instance vit dans PRG_10 mais un autre POU tente de l'appeler."""
    root = make_project(
        tmp_path,
        {
            "CODE/TREUILS/FB_Interlock.st": FB_INTERLOCK,
            "CODE/MAIN/PRG_10_Outputs.st": """\
PROGRAM PRG_10_Outputs
VAR
    instInterlockM1 : FB_Interlock;
END_VAR
instInterlockM1(Enable := TRUE);
""",
            "CODE/MAIN/PRG_06_Winch.st": """\
PROGRAM PRG_06_Winch
VAR
    Dummy : BOOL;
END_VAR
instInterlockM1(Enable := FALSE);
""",
        },
    )
    result = run(root)
    assert result.returncode == 1
    assert "[L3]" in result.stderr


def test_l4_reference_croisee_orpheline(tmp_path: Path) -> None:
    """PRG_09 lit PRG_10.instX.Y alors que PRG_10 ne declare pas instX."""
    root = make_project(
        tmp_path,
        {
            "CODE/TREUILS/FB_Interlock.st": FB_INTERLOCK,
            "CODE/MAIN/PRG_10_Outputs.st": """\
PROGRAM PRG_10_Outputs
VAR
    instInterlockM1 : FB_Interlock;
END_VAR
instInterlockM1(Enable := TRUE);
""",
            "CODE/MAIN/PRG_09_Supervision.st": """\
PROGRAM PRG_09_Supervision
VAR
    Dummy : BOOL;
END_VAR
Dummy := PRG_10_Outputs.instAbsente.RelayFwd;
""",
        },
    )
    result = run(root)
    assert result.returncode == 1
    assert "[L4]" in result.stderr
    assert "instAbsente" in result.stderr


def test_l5_typename_bundle_incoherent(tmp_path: Path) -> None:
    """REX exact : le bundle emet typeName=FB_Output au lieu du type declare."""
    root = make_project(
        tmp_path,
        {
            "CODE/TREUILS/FB_Interlock.st": FB_INTERLOCK,
            "CODE/MAIN/PRG_10_Outputs.st": """\
PROGRAM PRG_10_Outputs
VAR
    instInterlockM1 : FB_Interlock;
END_VAR
instInterlockM1(Enable := TRUE);
""",
            "CODE/CODE_Bundle.xml": """\
<project>
  <pou name="PRG_10_Outputs">
    <block localId="5" typeName="FB_Output" instanceName="instInterlockM1">
    </block>
  </pou>
</project>
""",
        },
    )
    result = run(root)
    assert result.returncode == 1
    assert "[L5]" in result.stderr


def test_l6_programme_absent_de_la_tache(tmp_path: Path) -> None:
    """Programme renomme : le fichier existe, la tache pointe encore l'ancien nom."""
    root = make_project(
        tmp_path,
        {
            "CODE/MAIN/PRG_10_Outputs_LD.st": """\
PROGRAM PRG_10_Outputs_LD
VAR
    Dummy : BOOL;
END_VAR
Dummy := TRUE;
""",
            "PRJ_CODESYS/PROJ_Full_ImportExport/Device.export": (
                '<Single Name="Name" Type="string">PRG_10_Outputs</Single>'
            ),
        },
    )
    result = run(root)
    assert result.returncode == 0  # avertissement, pas erreur (export souvent en retard)
    assert "[L6]" in result.stdout
    assert "PRG_10_Outputs_LD" in result.stdout


def test_composition_privee_de_meme_nom_non_signalee(tmp_path: Path) -> None:
    """Deux FB composant une brique `Brake` : encapsulation normale, pas un doublon."""
    root = make_project(
        tmp_path,
        {
            "CODE/COMMUN/FB_Brake.st": """\
FUNCTION_BLOCK FB_Brake
VAR_INPUT
    Enable : BOOL;
END_VAR
""",
            "CODE/TREUILS/FB_Winch.st": """\
FUNCTION_BLOCK PUBLIC FB_Winch
VAR
    Brake : FB_Brake;
END_VAR
Brake(Enable := TRUE);
""",
            "CODE/TRANSLATION/FB_Translation.st": """\
FUNCTION_BLOCK PUBLIC FB_Translation
VAR
    Brake : FB_Brake;
END_VAR
Brake(Enable := TRUE);
""",
        },
    )
    result = run(root)
    assert result.returncode == 0
    assert "[L7]" not in result.stdout
