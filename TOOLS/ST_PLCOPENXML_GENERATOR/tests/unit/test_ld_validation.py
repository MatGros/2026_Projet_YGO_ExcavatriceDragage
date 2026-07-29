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
            "instWinchOutputInterlockM1_LD": "FB_WinchOutputInterlock_LD",
            "instWinchOutputInterlockM2_LD": "FB_WinchOutputInterlock_LD",
            "instTranslationOutputInterlock_LD": "FB_TranslationOutputInterlock_LD",
        },
    )

    blocks = {block.get("instanceName"): block.get("typeName") for block in ld_xml.findall(".//block")}
    assert blocks == {
        "instWinchOutputInterlockM1_LD": "FB_WinchOutputInterlock_LD",
        "instWinchOutputInterlockM2_LD": "FB_WinchOutputInterlock_LD",
        "instTranslationOutputInterlock_LD": "FB_TranslationOutputInterlock_LD",
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
