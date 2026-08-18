"""Tests de non-regression du gate de liaison.

Chaque test reproduit une classe de bug reellement vecue sur le projet.
Si un test devient rouge, c'est le gate qui est casse, pas le code ST.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "G200_check_linkage.py"

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
            "CODE_XML/CODE_Bundle.xml": """\
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


def test_aucun_controle_ne_lit_device_export(tmp_path: Path) -> None:
    """Garde-fou de decision (2026-07-29) : `Device.export` est hors workflow.

    Il est mis a jour au bon vouloir humain, donc un gate qui s'y appuie produit
    du bruit des que l'export a un jour de retard. L'ancien controle L6 faisait
    exactement ca. Ce test echoue si quelqu'un le reintroduit.
    """
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
            # Export volontairement perime : il ne connait que l'ancien nom.
            "PRJ_CODESYS/PROJ_Full_ImportExport/Device.export": (
                '<Single Name="Name" Type="string">PRG_10_Outputs</Single>'
            ),
        },
    )
    result = run(root)
    assert result.returncode == 0
    assert "[L6]" not in result.stdout + result.stderr
    assert "Device.export" not in result.stdout + result.stderr

    # Verification structurelle : aucune chaine EXECUTABLE ne doit designer
    # l'export. On passe par l'AST pour ne pas se faire piéger par les
    # commentaires et docstrings, qui eux ont le droit d'en parler.
    import ast

    source = (Path(__file__).resolve().parents[1] / "scripts" / "G200_check_linkage.py").read_text(
        encoding="utf-8"
    )
    tree = ast.parse(source)
    docstrings = {
        id(node.body[0].value)
        for node in ast.walk(tree)
        if isinstance(node, (ast.Module, ast.FunctionDef, ast.ClassDef))
        and node.body
        and isinstance(node.body[0], ast.Expr)
        and isinstance(node.body[0].value, ast.Constant)
        and isinstance(node.body[0].value.value, str)
    }
    literals = [
        node.value
        for node in ast.walk(tree)
        if isinstance(node, ast.Constant)
        and isinstance(node.value, str)
        and id(node) not in docstrings
    ]
    faulty = [lit for lit in literals if "Device.export" in lit or "PROJ_Full_ImportExport" in lit]
    assert not faulty, f"G200_check_linkage ne doit jamais lire Device.export : {faulty}"


def test_l13_fb_orphelin_jamais_instancie(tmp_path: Path) -> None:
    """REX exact LOT_A 2026-08-01 : `FB_Sim_AU_ChainFeedback` ecrit, bundle,
    jamais instancie nulle part. Reproduit tel quel (nom identique) pour
    prouver que ce gate l'aurait detecte AVANT sa suppression."""
    root = make_project(
        tmp_path,
        {
            "CODE/SIMULATION/FB_Sim_AU_ChainFeedback.st": """\
FUNCTION_BLOCK PUBLIC FB_Sim_AU_ChainFeedback
VAR_INPUT
    SimulationModeActive : BOOL;
END_VAR
VAR_OUTPUT
    ChainClosedRaw : BOOL;
END_VAR
ChainClosedRaw := SimulationModeActive;
""",
        },
    )
    result = run(root)
    assert result.returncode == 1
    assert "[L13-FB]" in result.stderr
    assert "FB_Sim_AU_ChainFeedback" in result.stderr


def test_l13_gvl_orpheline_jamais_referencee(tmp_path: Path) -> None:
    """REX exact LOT_A 2026-08-01 : `GVL_Simulation_AU` declaree, ses champs
    ne sont lus/ecrits par aucun autre POU (qualifie_only)."""
    root = make_project(
        tmp_path,
        {
            "CODE/SIMULATION/GVL_Simulation_AU.st": """\
{attribute 'qualified_only'}
VAR_GLOBAL
    SimulationModeActive : BOOL := TRUE;
    SimChainClosed       : BOOL := TRUE;
END_VAR
""",
        },
    )
    result = run(root)
    assert result.returncode == 1
    assert "[L13-GVL]" in result.stderr
    assert "GVL_Simulation_AU" in result.stderr


def test_l13_program_stub_vide(tmp_path: Path) -> None:
    """REX exact LOT_A 2026-08-01 : `PRG_NETWORK_CFC`, corps sans aucune
    instruction executable (uniquement declaration + commentaires)."""
    root = make_project(
        tmp_path,
        {
            "CODE/MAIN/PRG_NETWORK_CFC.st": """\
(* Stub jamais complete *)
PROGRAM PRG_NETWORK_CFC
VAR
    // SetNetworkConfig_0 : SetNetworkConfig; (* commente *)
END_VAR
// Pas d'implementation active.
""",
        },
    )
    result = run(root)
    assert result.returncode == 1
    assert "[L13-PRG]" in result.stderr
    assert "PRG_NETWORK_CFC" in result.stderr


def test_l13_fb_compose_dans_deux_pou_non_signale(tmp_path: Path) -> None:
    """Faux positif a eviter : un FB instancie ailleurs n'est pas orphelin."""
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
    assert "[L13-FB]" not in (result.stdout + result.stderr)


def test_l13_gvl_non_qualifiee_avec_acces_par_champ_nu_non_signalee(tmp_path: Path) -> None:
    """Faux positif reel constate (GVL_PERSISTENT/GVL_BypassRetain) : sans
    `qualified_only`, CODESYS autorise l'acces par nom de champ nu, sans le
    prefixe `NomGvl.`. Le gate ne doit pas signaler ces GVL comme orphelines
    des qu'au moins un champ est utilise quelque part, qualifie ou non."""
    root = make_project(
        tmp_path,
        {
            "CODE/L_SIMULATION/GVL_BypassRetain.st": """\
VAR_GLOBAL RETAIN
    BypassWinchM1Global : BOOL := FALSE;
END_VAR
""",
            "CODE/MAIN/PRG_10_Outputs.st": """\
PROGRAM PRG_10_Outputs
VAR
    Dummy : BOOL;
END_VAR
IF BypassWinchM1Global THEN
    Dummy := TRUE;
END_IF;
""",
        },
    )
    result = run(root)
    assert "[L13-GVL]" not in (result.stdout + result.stderr)


def test_l13_program_avec_logique_non_signale(tmp_path: Path) -> None:
    """Faux positif a eviter : un PROGRAM avec au moins une instruction
    executable n'est pas un stub, meme s'il n'est reference par aucun autre
    POU (normal : un PROGRAM est cable par la tache, pas par du code appelant)."""
    root = make_project(
        tmp_path,
        {
            "CODE/MAIN/PRG_AUXILIARY_CFC.st": """\
PROGRAM PRG_AUXILIARY_CFC
VAR_OUTPUT
    HydraulicFaultOk : BOOL;
END_VAR
HydraulicFaultOk := TRUE;
""",
        },
    )
    result = run(root)
    assert "[L13-PRG]" not in (result.stdout + result.stderr)


def test_l13_exemption_tracee_passe_en_warn_pas_en_erreur(tmp_path: Path) -> None:
    """`KNOWN_ORPHANS_PENDING_DECISION` (ex. `FB_Output`, brique en attente de
    decision d'architecture) doit degrader l'orphelin en WARN, jamais le
    faire disparaitre silencieusement."""
    root = make_project(
        tmp_path,
        {
            "CODE/COMMUN/FB_Output.st": """\
FUNCTION_BLOCK PUBLIC FB_Output
VAR_INPUT
    Command : BOOL;
END_VAR
VAR_OUTPUT
    State : BOOL;
END_VAR
State := Command;
""",
        },
    )
    result = run(root)
    assert result.returncode == 0
    assert "[L13-FB]" not in result.stderr  # pas en ERROR
    assert "EXEMPTE" in result.stdout  # mais visible en WARN


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
            # Instancie les deux FB (sinon L13 les signale comme orphelins :
            # ce n'est pas l'objet de ce test, qui porte sur L7 uniquement).
            "CODE/MAIN/PRG_10_Outputs.st": """\
PROGRAM PRG_10_Outputs
VAR
    instWinchM1 : FB_Winch;
    instTranslationM3 : FB_Translation;
END_VAR
instWinchM1();
instTranslationM3();
""",
        },
    )
    result = run(root)
    assert result.returncode == 0
    assert "[L7]" not in result.stdout
