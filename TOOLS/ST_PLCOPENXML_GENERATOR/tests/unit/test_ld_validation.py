import pytest
import xml.etree.ElementTree as ET
from generator.ld_builder import build_ld_body

def test_ld_body_instantiates_declared_fb_outputs():
    st_code = """
    // === [TREUIL M1] ===
    // Description du treuil

    // Commande M1
    instM1RelayFwd(Command := M1RelayFwd);
    M1_RelayFwd_Up_DQ := instM1RelayFwd.State;

    // Commande M2
    instM1RelayRev(Command := M1RelayRev);
    M1_RelayRev_Down_DQ := instM1RelayRev.State;
    """

    ld_xml = build_ld_body(
        st_code,
        instance_types={"instM1RelayFwd": "FB_Output", "instM1RelayRev": "FB_Output"},
    )

    blocks = {block.get("instanceName"): block.get("typeName") for block in ld_xml.findall(".//block")}
    assert blocks["instM1RelayFwd"] == "FB_Output"
    assert blocks["instM1RelayRev"] == "FB_Output"

    coils = ld_xml.findall(".//coil")
    coil_vars = [c.find("variable").text for c in coils if c.find("variable") is not None]
    assert "M1_RelayFwd_Up_DQ" in coil_vars
    assert "M1_RelayRev_Down_DQ" in coil_vars

def test_ld_body_uses_type_context_for_boolean_coil_and_typed_pdos():
    st_code = """
    M1_RelayFwd_Up_DQ := M1RelayFwd;
    M3_CommandWord := PRG_07_TranslationControl.instTranslationOutputInterlock_LD.DriveControlWord;
    M3_SetpointFrequencyHz := REAL_TO_UINT(PRG_07_TranslationControl.instTranslationOutputInterlock_LD.DriveFreqRefHz * 100.0);
    """

    ld_xml = build_ld_body(st_code, boolean_identifiers={"M1RelayFwd"})

    input_expressions = [element.text for element in ld_xml.findall(".//inVariable/expression")]
    output_expressions = [element.text for element in ld_xml.findall(".//outVariable/expression")]
    contact_variables = [element.text for element in ld_xml.findall(".//contact/variable")]
    coil_variables = [element.text for element in ld_xml.findall(".//coil/variable")]

    assert "M1RelayFwd" in contact_variables
    assert "M1_RelayFwd_Up_DQ" in coil_variables
    assert "M1_RelayFwd_Up_DQ" not in output_expressions
    assert "PRG_07_TranslationControl.instTranslationOutputInterlock_LD.DriveControlWord" in input_expressions
    assert "REAL_TO_UINT(PRG_07_TranslationControl.instTranslationOutputInterlock_LD.DriveFreqRefHz * 100.0)" in input_expressions
    assert "M3_CommandWord" in output_expressions
    assert "M3_SetpointFrequencyHz" in output_expressions
    assert "M3_CommandWord" not in contact_variables + coil_variables
    assert "M3_SetpointFrequencyHz" not in contact_variables + coil_variables


def test_ld_body_uses_declared_type_for_every_multi_parameter_fb_call():
    st_code = """
    instWinchOutputInterlockM1_LD(Enable := M1Enable, RequestedStep := M1Step);
    instWinchOutputInterlockM2_LD(Enable := M2Enable, RequestedStep := M2Step);
    instTranslationOutputInterlock_LD(Enable := M3Enable, RequestedDriveControlWord := M3Word);
    """

    ld_xml = build_ld_body(
        st_code,
        instance_types={
            "instWinchOutputInterlockM1_LD": "FB_WinchOutputInterlock",
            "instWinchOutputInterlockM2_LD": "FB_WinchOutputInterlock",
            "instTranslationOutputInterlock_LD": "FB_TranslationOutputInterlock",
        },
    )

    blocks = {block.get("instanceName"): block.get("typeName") for block in ld_xml.findall(".//block")}
    assert blocks == {
        "instWinchOutputInterlockM1_LD": "FB_WinchOutputInterlock",
        "instWinchOutputInterlockM2_LD": "FB_WinchOutputInterlock",
        "instTranslationOutputInterlock_LD": "FB_TranslationOutputInterlock",
    }


def test_ld_body_creates_standalone_banner_networks():
    st_code = """
    // === [TREUIL M1] ===
    // Description générale M1
    
    instM1RelayFwd(Command := M1RelayFwd);
    M1_RelayFwd_Up_DQ := instM1RelayFwd.State;
    """
    
    ld_xml = build_ld_body(st_code, instance_types={"instM1RelayFwd": "FB_Output"})
    
    comments = ld_xml.findall(".//comment")
    assert len(comments) >= 2
    
    banner_comment = comments[0].find(".//xhtml").text
    assert "// === [TREUIL M1] ===" in banner_comment
    assert "// Description générale M1" in banner_comment


def test_ld_body_skips_multiline_block_comments():
    """Garde anti-régression REX 2026-08-13 : un bloc commenté `(* ... *)`
    multi-lignes dans le corps ne doit PAS être traité comme du code actif.
    Sans ce garde, une instance déclarée uniquement dans la section commentée
    (ex. instFilterPowerContactor) provoquait
    "LD block instance without declared type" à la génération."""
    st_code = """
    // === [SECTION ACTIVE] ===
    instM1RelayFwd(Command := M1RelayFwd);
    M1_RelayFwd_Up_DQ := instM1RelayFwd.State;

    (* 🚧 COMMENTE POUR TEST : section isolée
    instFilterPowerContactor(InputRaw := HwReal.Machine.PowerContactorEngaged_DI, FilterTime := T#20MS);
    HwRealQualified.Machine.PowerContactorEngaged_DI := instFilterPowerContactor.State;
    *)

    instM1RelayRev(Command := M1RelayRev);
    M1_RelayRev_Down_DQ := instM1RelayRev.State;
    """

    ld_xml = build_ld_body(
        st_code,
        instance_types={"instM1RelayFwd": "FB_Output", "instM1RelayRev": "FB_Output"},
    )

    blocks = {block.get("instanceName"): block.get("typeName") for block in ld_xml.findall(".//block")}
    assert blocks == {"instM1RelayFwd": "FB_Output", "instM1RelayRev": "FB_Output"}

    coils = ld_xml.findall(".//coil")
    coil_vars = [c.find("variable").text for c in coils if c.find("variable") is not None]
    assert "M1_RelayFwd_Up_DQ" in coil_vars
    assert "M1_RelayRev_Down_DQ" in coil_vars


@pytest.mark.parametrize(
    "st_code",
    [
        # Contrôle de flux : IF/ELSE → coil au nom absurde (REX 2026-08-13)
        """
        IF NOT Initialized THEN
            Previous := Simulated;
        ELSE
            Changed := (Simulated <> Previous);
        END_IF;
        """,
        # Fonction standard non supportée en LD : SEL sur struct
        """
        HwIn.Winch := SEL(WinchInputSourceSimulated, HwReal.Winch, instSimBench.Winch);
        """,
    ],
)
def test_ld_body_refuses_non_convertible_constructs(st_code):
    """Garde anti-régression REX 2026-08-13 (PRG_02_Acquisition_LD scratch) :
    un POU `_LD` ne peut porter QUE des réseaux Ladder. Les constructions ST
    non convertibles (contrôle de flux, SEL sur struct) doivent être REFUSÉES
    net par le générateur — un XML bien formé ne prouve jamais l'import CODESYS
    (REX 2026-08-04). Avant le fix, elles produisaient silencieusement une coil
    `'IF NOT ... THEN Previous...'` et des outVariable → IndexOutOfRangeException."""
    with pytest.raises(ValueError, match="LD non convertible"):
        build_ld_body(st_code)


def test_ld_body_refuses_struct_to_struct_copy():
    """Garde anti-régression REX 2026-08-13 : une copie struct→struct
    (`HwSim.Winch := instSimBench.Winch`, source = output STRUCT d'un FB)
    est refusée, car le fallback inVariable→outVariable provoque une
    IndexOutOfRangeException à l'import CODESYS."""
    with pytest.raises(ValueError, match="copie struct"):
        build_ld_body(
            "HwSim.Winch := instSimBench.Winch;",
            instance_types={"instSimBench": "FB_SimBench"},
            instance_output_type_map={"instSimBench": {"Winch": "ST_HwWinch"}},
        )


def test_ld_multi_param_fb_emits_all_declared_outputs():
    """Garde anti-régression : un FB multi-params composite (ex. FB_Safety)
    doit émettre TOUS ses outputs déclarés dans <outputVariables>. Une balise
    <outputVariables/> vide provoque une IndexOutOfRangeException à l'import
    CODESYS (REX 2026-08-04, régression commit af5566a)."""
    st_code = """
    instSafety(Enable := TRUE, Reset := Reset, ArmRequest := Arm);
    Out := instSafety.State;
    """
    ld_xml = build_ld_body(
        st_code,
        instance_types={"instSafety": "FB_Safety_EmergencyManagement"},
        instance_input_types={"instSafety": {"Enable": "BOOL", "Reset": "BOOL", "ArmRequest": "BOOL"}},
        instance_output_types={"instSafety": ["Ready", "Busy", "Done", "Error", "ErrorId", "MaintainA_RQ", "MaintainB_RQ", "ArmPulse_RQ", "State", "Diag", "ArmingSeqStep", "RedundancyTestFailed", "EmergencyArmingFailed", "EmergencyArmingLockoutActive"]},
    )
    blocks = [b for b in ld_xml.findall(".//block") if b.get("instanceName") == "instSafety"]
    assert len(blocks) == 1
    out_vars = blocks[0].find("outputVariables")
    out_fps = [v.get("formalParameter") for v in out_vars.findall("variable")]
    assert out_fps == ["Ready", "Busy", "Done", "Error", "ErrorId", "MaintainA_RQ", "MaintainB_RQ", "ArmPulse_RQ", "State", "Diag", "ArmingSeqStep", "RedundancyTestFailed", "EmergencyArmingFailed", "EmergencyArmingLockoutActive"]


def test_ld_multi_param_fb_first_output_cabled_form():
    """Garde anti-régression REX 2026-08-04 (PRG_06_Outputs) :
    Dans le chemin multi-params (instSafety(...)), le **premier output** DOIT
    être en forme 'câblée' <connectionPointOut/> (SANS <expression/>), même si
    aucune coil n'est connectée. C'est la convention CODESYS pour le 'principal'
    output du bloc (oracle PRG_TestSafety_LD.xml).
    
    Si TOUS les outputs sont en forme non-câblée <connectionPointOut><expression/>,
    CODESYS lève IndexOutOfRangeException à l'import (REX 2026-08-04, bundles D/E/F/G/H)."""
    st_code = """
    instSafety(Enable := TRUE, Reset := Reset, ArmRequest := Arm);
    Out := instSafety.State;
    """
    ld_xml = build_ld_body(
        st_code,
        instance_types={"instSafety": "FB_Safety_EmergencyManagement"},
        instance_input_types={"instSafety": {"Enable": "BOOL", "Reset": "BOOL", "ArmRequest": "BOOL"}},
        instance_output_types={"instSafety": ["Ready", "State", "Error"]},
    )
    blk = [b for b in ld_xml.findall(".//block") if b.get("instanceName") == "instSafety"][0]
    out_vars = blk.find("outputVariables").findall("variable")
    
    # Premier output : forme câblée (SANS <expression/>)
    first_var = out_vars[0]
    assert first_var.get("formalParameter") == "Ready"
    first_cpo = first_var.find("connectionPointOut")
    assert first_cpo.find("expression") is None, "Le premier output doit être en forme câblée (sans expression)"
    
    # Autres outputs : forme non-câblée (AVEC <expression/>)
    for var in out_vars[1:]:
        cpo = var.find("connectionPointOut")
        assert cpo.find("expression") is not None, f"{var.get('formalParameter')} doit être en forme non-câblée (avec expression)"
