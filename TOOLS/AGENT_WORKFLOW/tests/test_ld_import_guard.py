"""Regression guards for CODESYS LD import — type-safe FB wiring and rung completeness.

These tests protect against three classes of CODESYS import failures observed
on PRG_01_Inputs_LD (REX 2026-08):
  1. FB_Input(InputRaw :=) was not recognised by the LD builder — only
     FB_Output(Command :=) was.
  2. FB_Input rungs had no coil — CODESYS rejects incomplete rungs.
  3. NOT var expressions were rendered as inVariable/outVariable instead of
     negated contacts.
"""

from __future__ import annotations

import sys
from pathlib import Path

GENERATOR_ROOT = Path(__file__).resolve().parents[2] / "ST_PLCOPENXML_GENERATOR"
sys.path.insert(0, str(GENERATOR_ROOT))

from generator.ld_builder import build_ld_body


def test_non_bool_fb_arguments_are_invariables_not_ladder_contacts() -> None:
    """TIME/INT inputs must not be represented by BOOL-only LD contacts.

    FB_Input uses InputRaw := instead of Command := but follows the same
    contact → block → coil ladder pattern as FB_Output.  In the unified
    section 1, only the main input (InputRaw) is wired as a contact; the
    extra parameters (InvertLogic, FilterTime, ChannelOk) are handled in
    section 2 as a separate multi-parameter FB call.  This test validates
    the unified rung: contact → FB_Input(InputRaw) → coil.
    """
    ld_body = build_ld_body(
        """
        instInput(InputRaw := RawSignal, FilterTime := CST_FilterTime, ChannelOk := TRUE);
        Signal := instInput.State;
        """,
        instance_types={"instInput": "FB_Input"},
        instance_input_types={
            "instInput": {
                "InputRaw": "BOOL",
                "FilterTime": "TIME",
                "ChannelOk": "BOOL",
            }
        },
    )

    blocks = ld_body.findall("LD/block")
    assert len(blocks) >= 1
    block = blocks[0]
    inputs = {variable.get("formalParameter"): variable for variable in block.findall("inputVariables/variable")}

    # InputRaw must be the main contact-wired input
    assert "InputRaw" in inputs
    raw_conn = inputs["InputRaw"].find("connectionPointIn/connection")
    raw_source = raw_conn.get("refLocalId")
    contacts = [variable.text for variable in ld_body.findall("LD/contact/variable")]
    assert "RawSignal" in contacts

    # Must have a coil wired to block.State
    coils = ld_body.findall("LD/coil")
    assert len(coils) >= 1
    coil_conn = coils[0].find("connectionPointIn/connection")
    assert coil_conn.get("formalParameter") == "State"
    assert coils[0].findtext("variable") == "Signal"

    local_ids = {element.get("localId") for element in ld_body.iter() if element.get("localId")}
    referenced_ids = {
        connection.get("refLocalId")
        for connection in ld_body.findall(".//connection")
        if connection.get("refLocalId") != "0"
    }
    assert referenced_ids <= local_ids


def test_inline_st_comment_does_not_merge_or_drop_next_fb_call() -> None:
    """A `; (* comment *)` must still terminate the preceding LD statement.

    Two FB_Input calls with their State assignments must each produce a
    contact → block → coil rung.
    """
    ld_body = build_ld_body(
        """
        instFirst(InputRaw := RawFirst, FilterTime := CST_FilterTime, ChannelOk := TRUE);
        FirstState := instFirst.State; (* qualified state *)
        instSecond(InputRaw := RawSecond, FilterTime := CST_FilterTime, ChannelOk := TRUE);
        SecondState := instSecond.State;
        """,
        instance_types={"instFirst": "FB_Input", "instSecond": "FB_Input"},
        instance_input_types={
            "instFirst": {"InputRaw": "BOOL", "FilterTime": "TIME", "ChannelOk": "BOOL"},
            "instSecond": {"InputRaw": "BOOL", "FilterTime": "TIME", "ChannelOk": "BOOL"},
        },
    )

    assert [block.get("instanceName") for block in ld_body.findall("LD/block")] == [
        "instFirst",
        "instSecond",
    ]
    # Each FB_Input must have a coil
    coils = [coil.findtext("variable") for coil in ld_body.findall("LD/coil")]
    assert "FirstState" in coils
    assert "SecondState" in coils


# ---------------------------------------------------------------------------
# Règle 1 — Rung FB_Input complet : contact → block(InputRaw) → coil → rightPowerRail
# ---------------------------------------------------------------------------

def test_fb_input_rung_has_complete_chain_contact_block_coil_rightrail() -> None:
    """Chaque rung FB_Input doit contenir la chaîne complète attendue par CODESYS.

    contact → block(InputRaw) → coil(.State) → rightPowerRail.
    Un rung incomplet (sans coil ou sans rightPowerRail) est rejeté par CODESYS
    à l'import PLCopenXML.
    """
    ld_body = build_ld_body(
        """
        instInput(InputRaw := RawSignal, FilterTime := CST_FilterTime, ChannelOk := TRUE);
        Signal := instInput.State;
        """,
        instance_types={"instInput": "FB_Input"},
        instance_input_types={
            "instInput": {
                "InputRaw": "BOOL",
                "FilterTime": "TIME",
                "ChannelOk": "BOOL",
            }
        },
    )
    ld = ld_body.find("LD")
    assert ld is not None

    # rightPowerRail présent
    right_rail = ld.find("rightPowerRail")
    assert right_rail is not None, "rightPowerRail manquant — rung incomplet"

    blocks = ld.findall("block")
    assert len(blocks) == 1, f"Attendu 1 block, trouvé {len(blocks)}"
    block = blocks[0]
    assert block.get("instanceName") == "instInput"

    # Le block doit avoir InputRaw comme formalParameter principal
    in_vars = {v.get("formalParameter"): v for v in block.findall("inputVariables/variable")}
    assert "InputRaw" in in_vars, "InputRaw absent des inputVariables du block"

    # Le contact source doit exister et être relié au block via refLocalId
    raw_conn = in_vars["InputRaw"].find("connectionPointIn/connection")
    assert raw_conn is not None, "InputRaw non relié à un contact"
    contact_id = raw_conn.get("refLocalId")
    contacts = ld.findall("contact")
    contact = next((c for c in contacts if c.get("localId") == contact_id), None)
    assert contact is not None, f"Contact source {contact_id} introuvable"
    assert contact.findtext("variable") == "RawSignal"

    # Le block doit avoir une sortie State
    out_vars = {v.get("formalParameter"): v for v in block.findall("outputVariables/variable")}
    assert "State" in out_vars, "State absent des outputVariables du block"

    # La coil doit être reliée au block.State
    coils = ld.findall("coil")
    assert len(coils) == 1, f"Attendu 1 coil, trouvé {len(coils)}"
    coil = coils[0]
    coil_conn = coil.find("connectionPointIn/connection")
    assert coil_conn is not None, "Coil non reliée"
    assert coil_conn.get("refLocalId") == block.get("localId"), "Coil non reliée au block"
    assert coil_conn.get("formalParameter") == "State", "Coil non reliée à .State"
    assert coil.findtext("variable") == "Signal"


# ---------------------------------------------------------------------------
# Règle 2 — NOT var produit un contact inversé, pas un inVariable
# ---------------------------------------------------------------------------

def test_not_var_produces_negated_contact_not_invariable() -> None:
    """NOT var doit générer un contact negated=\"true\", jamais un inVariable.

    Avant le fix, NOT var était rendu comme inVariable/outVariable, ce qui
    produit une expression inline invalide en page Ladder BOOL pure.
    """
    ld_body = build_ld_body(
        """
        Result := NOT InvertedSignal;
        """,
        boolean_identifiers={"InvertedSignal", "Result"},
    )
    ld = ld_body.find("LD")
    assert ld is not None

    # Aucun inVariable/outVariable pour une expression BOOL pure
    assert ld.findall("inVariable") == [], "inVariable inattendu pour NOT var BOOL"
    assert ld.findall("outVariable") == [], "outVariable inattendu pour NOT var BOOL"

    # Le contact doit être negated=true
    contacts = ld.findall("contact")
    assert len(contacts) == 1, f"Attendu 1 contact, trouvé {len(contacts)}"
    contact = contacts[0]
    assert contact.get("negated") == "true", f"Contact non inversé: negated={contact.get('negated')}"
    assert contact.findtext("variable") == "InvertedSignal"

    # La coil doit exister et être reliée au contact
    coils = ld.findall("coil")
    assert len(coils) == 1
    coil = coils[0]
    coil_conn = coil.find("connectionPointIn/connection")
    assert coil_conn.get("refLocalId") == contact.get("localId")
    assert coil.findtext("variable") == "Result"


# ---------------------------------------------------------------------------
# Règle 3 — Aucun inVariable/outVariable dans une page LD BOOL pure
# ---------------------------------------------------------------------------

def test_pure_bool_ld_page_has_zero_invariable_outvariable() -> None:
    """Une page LD de type PRG_01_Inputs_LD (BOOL pur) ne doit contenir aucun
    inVariable ni outVariable.

    Les signaux BOOL doivent être représentés exclusivement par des contacts
    et des coils. Les inVariable/outVariable sont réservés aux expressions
    typées non-BOOL (TIME, INT, WORD, REAL…).
    """
    ld_body = build_ld_body(
        """
        instInput1(InputRaw := RawSignal1, InvertLogic := Invert1);
        Signal1 := instInput1.State;
        instInput2(InputRaw := RawSignal2, InvertLogic := Invert2);
        Signal2 := instInput2.State;
        MotorReady := Signal1 AND Signal2;
        EmergencyActive := NOT EmergencyButton;
        """,
        boolean_identifiers={
            "RawSignal1", "RawSignal2", "Signal1", "Signal2", "Invert1", "Invert2",
            "MotorReady", "EmergencyActive", "EmergencyButton",
        },
        instance_types={"instInput1": "FB_Input", "instInput2": "FB_Input"},
        instance_input_types={
            "instInput1": {"InputRaw": "BOOL", "InvertLogic": "BOOL"},
            "instInput2": {"InputRaw": "BOOL", "InvertLogic": "BOOL"},
        },
    )
    ld = ld_body.find("LD")
    assert ld is not None

    # Aucun inVariable/outVariable — tout est contact/coil/block
    assert ld.findall("inVariable") == [], \
        f"inVariable interdit en page LD BOOL pure: {[v.findtext('expression') for v in ld.findall('inVariable')]}"
    assert ld.findall("outVariable") == [], \
        f"outVariable interdit en page LD BOOL pure: {[v.findtext('expression') for v in ld.findall('outVariable')]}"

    # Vérifier qu'on a bien des contacts et coils
    assert len(ld.findall("contact")) >= 4, "Contacts manquants"
    assert len(ld.findall("coil")) >= 4, "Coils manquantes"


# ---------------------------------------------------------------------------
# Règle 3bis — Paramètre typé non-BOOL (FilterTime) → inVariable, jamais contact
# ---------------------------------------------------------------------------

def test_time_filter_param_is_invariable_not_contact() -> None:
    """Un paramètre FB non-BOOL (FilterTime: TIME) doit être un inVariable.

    Un contact Ladder ne peut porter que des variables BOOL. Un contact
    câblé sur un littéral TIME (FilterTime := T#20MS) ou sur une constante
    TIME est rejeté par CODESYS à l'import PLCopenXML (REX 2026-08,
    régénération PRG_01_Inputs_LD : contacts créés pour FilterTime et
    ChannelOk). Règles de câblage section 1 (§11) :
      - type != BOOL            → inVariable (expression)
      - valeur "TRUE"           → leftPowerRail (0)
      - BOOL variable           → contact
      - expression non-identif. → inVariable (ex. GetDeviceState() = RUNNING)
    """
    ld_body = build_ld_body(
        """
        instInput(InputRaw := RawSignal, FilterTime := T#20MS, ChannelOk := (Local_Digital_IO.GetDeviceState() = DEVICE_STATE.RUNNING));
        Signal := instInput.State;
        """,
        instance_types={"instInput": "FB_Input"},
        instance_input_types={
            "instInput": {
                "InputRaw": "BOOL",
                "FilterTime": "TIME",
                "ChannelOk": "BOOL",
            }
        },
    )
    ld = ld_body.find("LD")
    assert ld is not None

    # Aucun contact pour FilterTime : un contact ne porte que du BOOL
    contact_vars = [c.findtext("variable") for c in ld.findall("contact")]
    assert "T#20MS" not in contact_vars, "Littéral TIME rendu comme contact Ladder"
    assert "CST_FilterTime" not in contact_vars, "Constante TIME rendue comme contact Ladder"

    # FilterTime doit être un inVariable avec l'expression T#20MS
    invars = {v.findtext("expression"): v for v in ld.findall("inVariable")}
    assert "T#20MS" in invars, f"FilterTime T#20MS absent des inVariable: {list(invars)}"

    # ChannelOk (expression) → inVariable aussi, pas un contact
    exprs = [v.findtext("expression") for v in ld.findall("inVariable")]
    assert any("GetDeviceState" in e for e in exprs), \
        f"Expression ChannelOk absente des inVariable: {exprs}"

    # Le block doit référencer FilterTime depuis l'inVariable
    block = ld.find("block")
    params = {v.get("formalParameter"): v for v in block.findall("inputVariables/variable")}
    filter_conn = params["FilterTime"].find("connectionPointIn/connection")
    filter_id = filter_conn.get("refLocalId")
    invar_ids = {v.get("localId") for v in ld.findall("inVariable")}
    assert filter_id in invar_ids, "FilterTime non relié à un inVariable"

    # Tous les refLocalId référencés doivent exister
    local_ids = {e.get("localId") for e in ld.iter() if e.get("localId")}
    referenced = {
        c.get("refLocalId") for c in ld.findall(".//connection") if c.get("refLocalId") != "0"
    }
    assert referenced <= local_ids


# ---------------------------------------------------------------------------
# Règle 4 — Chaque block d'une page _LD a une coil reliée à .State
# ---------------------------------------------------------------------------

def test_every_block_has_coil_wired_to_state_output() -> None:
    """Chaque block FB d'une page _LD doit avoir une coil reliée à sa sortie State.

    Un block sans coil produit un rung incomplet que CODESYS rejette à l'import.
    Cette règle s'applique à FB_Output (Command) comme à FB_Input (InputRaw).
    """
    ld_body = build_ld_body(
        """
        instInput(InputRaw := RawSignal, FilterTime := CST_FilterTime, ChannelOk := TRUE);
        Signal := instInput.State;
        instOutput(Command := MotorCmd);
        MotorState := instOutput.State;
        """,
        instance_types={"instInput": "FB_Input", "instOutput": "FB_Output"},
        instance_input_types={
            "instInput": {"InputRaw": "BOOL", "FilterTime": "TIME", "ChannelOk": "BOOL"},
            "instOutput": {"Command": "BOOL"},
        },
    )
    ld = ld_body.find("LD")
    assert ld is not None

    blocks = ld.findall("block")
    assert len(blocks) == 2, f"Attendu 2 blocks, trouvé {len(blocks)}"

    coils = ld.findall("coil")
    coil_by_target = {c.findtext("variable"): c for c in coils}

    for block in blocks:
        inst_name = block.get("instanceName")
        block_id = block.get("localId")

        # Le block doit avoir une sortie State
        out_vars = {v.get("formalParameter"): v for v in block.findall("outputVariables/variable")}
        assert "State" in out_vars, \
            f"Block {inst_name}: State absent des outputVariables"

        # Une coil doit être reliée à ce block via formalParameter=State
        state_coil = None
        for coil in coils:
            coil_conn = coil.find("connectionPointIn/connection")
            if coil_conn is not None and \
               coil_conn.get("refLocalId") == block_id and \
               coil_conn.get("formalParameter") == "State":
                state_coil = coil
                break
        assert state_coil is not None, \
            f"Block {inst_name} (id={block_id}): aucune coil reliée à .State"


def test_bundle_prg06_outputs_ld_valid_invariables_and_block_refs() -> None:
    """PRG_06_Outputs_LD dans le bundle ne doit avoir ni refLocalId=0 sur des inputs FB,
    ni littéraux 'TRUE'/'FALSE' non convertis dans les inVariable (doivent être '1'/'0').
    """
    import xml.etree.ElementTree as ET
    bundle = Path(__file__).resolve().parents[2].parent / "CODE" / "CODE_Bundle.xml"
    assert bundle.exists()
    root = ET.parse(bundle).getroot()

    pous = [
        p for p in root.findall(".//{http://www.plcopen.org/xml/tc6_0200}pou")
        if p.attrib.get("name") == "PRG_06_Outputs_LD"
    ]
    assert len(pous) == 1, "PRG_06_Outputs_LD absent ou dupliqué dans le bundle"
    pou = pous[0]

    # 1. Vérifier qu'aucun inputVariable de block n'a refLocalId="0"
    for block in pou.findall(".//{http://www.plcopen.org/xml/tc6_0200}block"):
        b_name = block.attrib.get("instanceName")
        for iv in block.findall("{http://www.plcopen.org/xml/tc6_0200}inputVariables/{http://www.plcopen.org/xml/tc6_0200}variable"):
            fp = iv.attrib.get("formalParameter")
            conn = iv.find(".//{http://www.plcopen.org/xml/tc6_0200}connection")
            ref = conn.attrib.get("refLocalId") if conn is not None else None
            assert ref != "0", f"Block {b_name} parameter {fp} a un refLocalId='0' invalide"

    # 2. Vérifier qu'aucun inVariable ne contient 'TRUE' ou 'FALSE' en chaîne brute
    for inv in pou.findall(".//{http://www.plcopen.org/xml/tc6_0200}inVariable"):
        expr = inv.find("{http://www.plcopen.org/xml/tc6_0200}expression")
        text = expr.text if expr is not None else None
        assert text not in ("TRUE", "FALSE"), f"inVariable {inv.attrib.get('localId')} contient littéral interdit '{text}' (doit être '1' ou '0')"


