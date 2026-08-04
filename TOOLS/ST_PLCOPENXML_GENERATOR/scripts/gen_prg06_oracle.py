#!/usr/bin/env python3
"""Génère le POU PRG_06_Outputs_LD complet en LD XML, basé sur l'oracle CODESYS
PRG_06_Outputs_LD.xml (samples_reference_codesys). Contourne les bugs de ld_builder.py.

Structure conforme à l'oracle CODESYS :
- TRUE -> contact <variable>TRUE</variable> (PAS inVariable expr=1)
- Variables qualifiées -> contact (PAS inVariable avec expression)
- Inputs non connectés -> inVariable expression vide
- Outputs assignés -> <expression>target</expression> dans outputVariables
- Premier output -> <connectionPointOut/> (câblée, pas d'expression)
- Coil après bloc -> <connection refLocalId=block formalParameter=State />
"""
from __future__ import annotations
import xml.etree.ElementTree as ET
import uuid

NS = "http://www.plcopen.org/xml/tc6_0200"
ET.register_namespace('', NS)

# Les 15 réseaux FB_Output: (instance, command_var, coil_var, comment)
FB_OUTPUT_NETWORKS = [
    # (inst_name, cmd_var, coil_var, comment) — REX 2026-08-04 : coil_var = variable
    # LOCALE du POU (comme l oracle), PAS la sortie Device _DQ (absente du bundle →
    # ArgumentNullException GetOperandDeclarationInfo a l ouverture).
    ("instM1RelayFwd",          "M1RelayFwd",          "M1RelayFwd",          "Relais M1 Marche Avant (Montée)"),
    ("instM1RelayRev",          "M1RelayRev",          "M1RelayRev",          "Relais M1 Marche Arrière (Descente)"),
    ("instM1SpeedContactor1",   "M1SpeedContactor1",  "M1SpeedContactor1",  "Contacteur Vitesse M1-1"),
    ("instM1SpeedContactor2",   "M1SpeedContactor2",  "M1SpeedContactor2",  "Contacteur Vitesse M1-2"),
    ("instM1SpeedContactor3",   "M1SpeedContactor3",  "M1SpeedContactor3",  "Contacteur Vitesse M1-3"),
    ("instM1SpeedContactor4",   "M1SpeedContactor4",  "M1SpeedContactor4",  "Contacteur Vitesse M1-4"),
    ("instM1BrakeCmd",          "M1BrakeCmd",         "M1BrakeCmd",         "Frein M1"),
    ("instM2RelayFwd",          "M2RelayFwd",         "M2RelayFwd",         "Relais M2 Marche Avant (Fermeture)"),
    ("instM2RelayRev",          "M2RelayRev",         "M2RelayRev",         "Relais M2 Marche Arrière (Ouverture)"),
    ("instM2SpeedContactor1",   "M2SpeedContactor1", "M2SpeedContactor1", "Contacteur Vitesse M2-1"),
    ("instM2SpeedContactor2",   "M2SpeedContactor2", "M2SpeedContactor2", "Contacteur Vitesse M2-2"),
    ("instM2SpeedContactor3",   "M2SpeedContactor3", "M2SpeedContactor3", "Contacteur Vitesse M2-3"),
    ("instM2SpeedContactor4",   "M2SpeedContactor4", "M2SpeedContactor4", "Contacteur Vitesse M2-4"),
    ("instM2BrakeCmd",          "M2BrakeCmd",         "M2BrakeCmd",         "Frein M2"),
    ("instTranslationBrakeCmd", "TranslationBrakeCmd", "TranslationBrakeCmd", "Frein Translation M3"),
]

# Inputs de FB_Output (ordre de déclaration) — REX 2026-08-04 : réduit,
# partie feedback retirée (validé utilisateur)
FB_OUTPUT_INPUTS = ["Command", "InvertLogic"]
FB_OUTPUT_OUTPUTS = ["State"]

# Inputs de FB_Safety (ordre de déclaration)
FB_SAFETY_INPUTS = ["Enable", "Reset", "ArmRequest", "EmergencyChainClosed", "PowerContactorEngaged", "PowerCutOffRequest", "BtnEmergencyCutOff"]
FB_SAFETY_OUTPUTS = ["Ready", "Busy", "Done", "Error", "ErrorId", "MaintainA_RQ", "MaintainB_RQ", "ArmPulse_RQ", "State", "Diag", "ArmingSeqStep", "RedundancyTestFailed", "EmergencyArmingFailed", "EmergencyArmingLockoutActive"]

# Assignations d'outputs FB_Safety (output -> target_var)
FB_SAFETY_OUTPUT_ASSIGNS = {
    "MaintainA_RQ": "PowerKeepAlive_A_RQ",
    "MaintainB_RQ": "PowerKeepAlive_B_RQ",
    "ArmPulse_RQ": "EmergencyArmingPulseActive",  # Target dans le bloc (oracle)
    "ArmingSeqStep": "ArmingSeqStep",
    "RedundancyTestFailed": "RedundancyTestFailed",
    "EmergencyArmingFailed": "EmergencyArmingFailed",
    # EmergencyArmingLockoutActive: VIDE dans l oracle (non assigne dans le bloc)
}
# Doublons (output -> target_var supplémentaire en coil)
FB_SAFETY_DUPLICATES = [
    ("ArmPulse_RQ", "EmergencyArming_RQ"),
]

# Inputs du bloc FB_Safety: (formalParameter, source_var, is_TRUE)
FB_SAFETY_INPUT_SOURCES = [
    ("Enable", "TRUE", True),
    ("Reset", "PRG_07_Supervision.FaultMachineReset_IHM", False),
    ("ArmRequest", "GVL_IHM.Modes.Cmd.BtnEmergencyArming", False),
    ("EmergencyChainClosed", "PRG_01_Inputs_LD.EmergencyChainClosed", False),
    ("PowerContactorEngaged", "PRG_01_Inputs_LD.PowerContactorEngaged", False),
    ("PowerCutOffRequest", "PowerCutOffReq", False),
    ("BtnEmergencyCutOff", "GVL_IHM.Modes.Cmd.BtnEmergencyCutOff", False),
]


def _pos(el):
    ET.SubElement(el, "position", x="0", y="0")


def _new_id(counter):
    """Génère un localId séquentiel (saute les IDs pour éviter les collisions)."""
    val = counter[0]
    counter[0] += 1
    return val


def _make_comment(ld, lid, text=""):
    c = ET.SubElement(ld, "comment")
    c.set("localId", str(lid))
    c.set("height", "0")
    c.set("width", "0")
    c.set("xmlns:html", "http://www.w3.org/1999/xhtml")
    _pos(c)
    content = ET.SubElement(c, "content")
    xhtml = ET.SubElement(content, "html:xhtml")
    # REX 2026-08-04 : le format PRG_01 (ld_builder) = html:xhtml avec texte
    # dedans, PAS <xhtml xmlns=...>. Les commentaires s ouvrent sans erreur.
    if text:
        xhtml.text = text
    return c


def _make_vendor_element(ld, lid):
    ve = ET.SubElement(ld, "vendorElement")
    ve.set("localId", str(lid))
    _pos(ve)
    at = ET.SubElement(ve, "alternativeText")
    xhtml = ET.SubElement(at, "xhtml")
    xhtml.set("xmlns", "http://www.w3.org/1999/xhtml")
    ad = ET.SubElement(ve, "addData")
    d = ET.SubElement(ad, "data")
    d.set("name", "http://www.3s-software.com/plcopenxml/fbdelementtype")
    d.set("handleUnknown", "implementation")
    et = ET.SubElement(d, "ElementType")
    et.set("xmlns", "")
    et.text = "networktitle"
    return ve


def _make_contact(ld, lid, var_text):
    """Crée un contact câblé au rail gauche (refLocalId=0)."""
    c = ET.SubElement(ld, "contact")
    c.set("localId", str(lid))
    c.set("negated", "false")
    c.set("storage", "none")
    c.set("edge", "none")
    _pos(c)
    cpi = ET.SubElement(c, "connectionPointIn")
    conn = ET.SubElement(cpi, "connection")
    conn.set("refLocalId", "0")
    ET.SubElement(c, "connectionPointOut")
    v = ET.SubElement(c, "variable")
    v.text = var_text
    return c


def _make_invariable_empty(ld, lid):
    """Crée un inVariable avec expression vide (input non connecté)."""
    iv = ET.SubElement(ld, "inVariable")
    iv.set("localId", str(lid))
    _pos(iv)
    ET.SubElement(iv, "connectionPointOut")
    ET.SubElement(iv, "expression")
    return iv


def _make_coil(ld, lid, ref_block_id, formal_param, var_text):
    """Crée une coil connectée à un bloc avec formalParameter."""
    coil = ET.SubElement(ld, "coil")
    coil.set("localId", str(lid))
    coil.set("negated", "false")
    coil.set("storage", "none")
    _pos(coil)
    cpi = ET.SubElement(coil, "connectionPointIn")
    conn = ET.SubElement(cpi, "connection")
    conn.set("refLocalId", str(ref_block_id))
    conn.set("formalParameter", formal_param)
    ET.SubElement(coil, "connectionPointOut")
    v = ET.SubElement(coil, "variable")
    v.text = var_text
    return coil


def _make_coil_from_contact(ld, lid, ref_contact_id, var_text):
    """Crée une coil connectée à un contact (sans formalParameter)."""
    coil = ET.SubElement(ld, "coil")
    coil.set("localId", str(lid))
    coil.set("negated", "false")
    coil.set("storage", "none")
    _pos(coil)
    cpi = ET.SubElement(coil, "connectionPointIn")
    conn = ET.SubElement(cpi, "connection")
    conn.set("refLocalId", str(ref_contact_id))
    ET.SubElement(coil, "connectionPointOut")
    v = ET.SubElement(coil, "variable")
    v.text = var_text
    return coil


def _make_fb_output_block(ld, lid, instance_name, input_source_ids):
    """Crée un bloc FB_Output avec tous ses inputs et outputs."""
    block = ET.SubElement(ld, "block")
    block.set("localId", str(lid))
    block.set("typeName", "FB_Output")
    block.set("instanceName", instance_name)
    _pos(block)

    # inputVariables : TOUS les inputs déclarés (7)
    in_vars = ET.SubElement(block, "inputVariables")
    for i, p_name in enumerate(FB_OUTPUT_INPUTS):
        v = ET.SubElement(in_vars, "variable")
        v.set("formalParameter", p_name)
        cpi = ET.SubElement(v, "connectionPointIn")
        conn = ET.SubElement(cpi, "connection")
        conn.set("refLocalId", str(input_source_ids[i]))

    ET.SubElement(block, "inOutVariables")

    # outputVariables : State câblée, autres expression vide
    out_vars = ET.SubElement(block, "outputVariables")
    for idx, out_p in enumerate(FB_OUTPUT_OUTPUTS):
        v = ET.SubElement(out_vars, "variable")
        v.set("formalParameter", out_p)
        cpo = ET.SubElement(v, "connectionPointOut")
        if idx > 0:
            ET.SubElement(cpo, "expression")

    # addData fbdcalltype
    ad = ET.SubElement(block, "addData")
    d = ET.SubElement(ad, "data")
    d.set("name", "http://www.3s-software.com/plcopenxml/fbdcalltype")
    d.set("handleUnknown", "implementation")
    ct = ET.SubElement(d, "CallType")
    ct.set("xmlns", "")
    ct.text = "functionblock"
    return block


def _make_fb_safety_block(ld, lid, instance_name, input_source_ids):
    """Crée un bloc FB_Safety_EmergencyManagement avec tous ses inputs et outputs."""
    block = ET.SubElement(ld, "block")
    block.set("localId", str(lid))
    block.set("typeName", "FB_Safety_EmergencyManagement")
    block.set("instanceName", instance_name)
    _pos(block)

    # inputVariables : 7 inputs
    in_vars = ET.SubElement(block, "inputVariables")
    for i, p_name in enumerate(FB_SAFETY_INPUTS):
        v = ET.SubElement(in_vars, "variable")
        v.set("formalParameter", p_name)
        cpi = ET.SubElement(v, "connectionPointIn")
        conn = ET.SubElement(cpi, "connection")
        conn.set("refLocalId", str(input_source_ids[i]))

    ET.SubElement(block, "inOutVariables")

    # outputVariables : Ready câblée, autres avec expression (assignée ou vide)
    out_vars = ET.SubElement(block, "outputVariables")
    for idx, out_p in enumerate(FB_SAFETY_OUTPUTS):
        v = ET.SubElement(out_vars, "variable")
        v.set("formalParameter", out_p)
        cpo = ET.SubElement(v, "connectionPointOut")
        if idx == 0:
            pass  # Premier output : câblée (pas d'expression)
        else:
            expr = ET.SubElement(cpo, "expression")
            if out_p in FB_SAFETY_OUTPUT_ASSIGNS:
                expr.text = FB_SAFETY_OUTPUT_ASSIGNS[out_p]

    # addData fbdcalltype
    ad = ET.SubElement(block, "addData")
    d = ET.SubElement(ad, "data")
    d.set("name", "http://www.3s-software.com/plcopenxml/fbdcalltype")
    d.set("handleUnknown", "implementation")
    ct = ET.SubElement(d, "CallType")
    ct.set("xmlns", "")
    ct.text = "functionblock"
    return block


def build_prg06_ld():
    """Génère le body LD complet de PRG_06_Outputs_LD."""
    body = ET.Element("body")
    ld = ET.SubElement(body, "LD")

    counter = [1]  # localId counter (0 = leftPowerRail)

    # Rail de puissance gauche
    lpr = ET.SubElement(ld, "leftPowerRail")
    lpr.set("localId", "0")
    _pos(lpr)
    cpo = ET.SubElement(lpr, "connectionPointOut")
    cpo.set("formalParameter", "none")

    # ═══════════════════════════════════════════════════════════
    # Section 1 : Écriture sorties physiques Q (M1/M2/M3 via FB_Output)
    # ═══════════════════════════════════════════════════════════
    # REX 2026-08-04 : pas de comment+vendor pour la section, seulement
    # un comment+vendor par reseau (oracle CODESYS PRG_06_Outputs_LD.xml).

    for inst_name, cmd_var, coil_var, comment_text in FB_OUTPUT_NETWORKS:
        # En-tête du réseau (1 comment + 1 vendorElement par réseau)
        _make_comment(ld, _new_id(counter), comment_text)
        _make_vendor_element(ld, _new_id(counter))

        # REX 2026-08-04 (oracle CODESYS) : le localId du bloc doit être PLUS PETIT
        # que ses sources. On réserve le block_id AVANT de créer les sources.
        block_id = _new_id(counter)

        # Sources : 1 contact (Command) + inVariable pour les inputs non connectés
        input_source_ids = []
        # Contact pour Command
        cmd_contact_id = _new_id(counter)
        _make_contact(ld, cmd_contact_id, cmd_var)
        input_source_ids.append(cmd_contact_id)
        # inVariable vides pour les autres inputs
        for _ in range(len(FB_OUTPUT_INPUTS) - 1):
            iv_id = _new_id(counter)
            _make_invariable_empty(ld, iv_id)
            input_source_ids.append(iv_id)

        # Bloc FB_Output (localId réservé avant les sources)
        _make_fb_output_block(ld, block_id, inst_name, input_source_ids)

        # Coil (State -> output var)
        coil_id = _new_id(counter)
        _make_coil(ld, coil_id, block_id, "State", coil_var)

    # ═══════════════════════════════════════════════════════════
    # Section 3 : Sécurité & Coupure Puissance Amont (FB_Safety)
    # ═══════════════════════════════════════════════════════════
    # REX 2026-08-04 : pas de comment+vendor pour la section (oracle CODESYS)
    _make_comment(ld, _new_id(counter), "🛡️ Sécurité & Coupure Puissance Amont")
    _make_vendor_element(ld, _new_id(counter))

    # REX 2026-08-04 : réserver le block_id AVANT les sources (oracle CODESYS)
    safety_block_id = _new_id(counter)

    # Sources : 7 contacts (tous connectés)
    safety_input_ids = []
    for fp, var_text, is_true in FB_SAFETY_INPUT_SOURCES:
        cid = _new_id(counter)
        _make_contact(ld, cid, var_text)
        safety_input_ids.append(cid)

    # Bloc FB_Safety (localId réservé avant les sources)
    _make_fb_safety_block(ld, safety_block_id, "instSafetyEmergencyManagement", safety_input_ids)

    # REX 2026-08-04 : PAS de coil doublon (ArmPulse_RQ -> EmergencyArming_RQ).
    # Un output déjà assigné par expression dans le bloc + coil externe =
    # double assignement -> ArgumentNullException (GetOperandDeclarationInfo)
    # à l'ouverture. L'oracle n'a AUCUN coil après FB_Safety.

    # Rail de puissance droit
    rpr = ET.SubElement(ld, "rightPowerRail")
    rpr.set("localId", "2147483646")
    _pos(rpr)
    ET.SubElement(rpr, "connectionPointIn")

    return body


def build_prg06_pou():
    """Génère le POU PRG_06_Outputs_LD complet."""
    pou = ET.Element("pou")
    pou.set("name", "PRG_06_Outputs_LD")
    pou.set("pouType", "program")

    # Interface
    iface = ET.SubElement(pou, "interface")

    # outputVars
    out_vars = ET.SubElement(iface, "outputVars")
    for name, typ in [
        ("PowerKeepAlive_A_RQ", "BOOL"),
        ("PowerKeepAlive_B_RQ", "BOOL"),
        ("EmergencyArming_RQ", "BOOL"),
        ("EmergencyArmingPulseActive", "BOOL"),
        ("EmergencyArmingLockoutActive", "BOOL"),
        ("ArmingSeqStep", "INT"),
        ("RedundancyTestFailed", "BOOL"),
        ("EmergencyArmingFailed", "BOOL"),
    ]:
        v = ET.SubElement(out_vars, "variable")
        v.set("name", name)
        t = ET.SubElement(v, "type")
        ET.SubElement(t, typ)

    # localVars
    local_vars = ET.SubElement(iface, "localVars")
    for name, typ in [
        ("M1RelayFwd", "BOOL"), ("M1RelayRev", "BOOL"),
        ("M1SpeedContactor1", "BOOL"), ("M1SpeedContactor2", "BOOL"),
        ("M1SpeedContactor3", "BOOL"), ("M1SpeedContactor4", "BOOL"),
        ("M1BrakeCmd", "BOOL"),
        ("M2RelayFwd", "BOOL"), ("M2RelayRev", "BOOL"),
        ("M2SpeedContactor1", "BOOL"), ("M2SpeedContactor2", "BOOL"),
        ("M2SpeedContactor3", "BOOL"), ("M2SpeedContactor4", "BOOL"),
        ("M2BrakeCmd", "BOOL"),
        ("TranslationBrakeCmd", "BOOL"),
        ("KoboldContactorCmd", "BOOL"),
        ("PowerCutOffReq", "BOOL"),
    ]:
        v = ET.SubElement(local_vars, "variable")
        v.set("name", name)
        t = ET.SubElement(v, "type")
        ET.SubElement(t, typ)

    # Instances FB
    for name, fb_type in [
        ("instM1RelayFwd", "FB_Output"), ("instM1RelayRev", "FB_Output"),
        ("instM1SpeedContactor1", "FB_Output"), ("instM1SpeedContactor2", "FB_Output"),
        ("instM1SpeedContactor3", "FB_Output"), ("instM1SpeedContactor4", "FB_Output"),
        ("instM1BrakeCmd", "FB_Output"),
        ("instM2RelayFwd", "FB_Output"), ("instM2RelayRev", "FB_Output"),
        ("instM2SpeedContactor1", "FB_Output"), ("instM2SpeedContactor2", "FB_Output"),
        ("instM2SpeedContactor3", "FB_Output"), ("instM2SpeedContactor4", "FB_Output"),
        ("instM2BrakeCmd", "FB_Output"),
        ("instTranslationBrakeCmd", "FB_Output"),
        ("instSafetyEmergencyManagement", "FB_Safety_EmergencyManagement"),
    ]:
        v = ET.SubElement(local_vars, "variable")
        v.set("name", name)
        t = ET.SubElement(v, "type")
        d = ET.SubElement(t, "derived")
        d.set("name", fb_type)

    # Body LD
    body = build_prg06_ld()
    pou.append(body)

    # addData ObjectId
    ad = ET.SubElement(pou, "addData")
    d = ET.SubElement(ad, "data")
    d.set("name", "http://www.3s-software.com/plcopenxml/objectid")
    d.set("handleUnknown", "discard")
    oid = ET.SubElement(d, "ObjectId")
    oid.text = str(uuid.uuid5(uuid.NAMESPACE_DNS, "PRG_06_Outputs_LD"))

    return pou


def main():
    pou = build_prg06_pou()
    xml_str = ET.tostring(pou, encoding="unicode")
    print(xml_str[:500])
    print("...")
    print(f"Total chars: {len(xml_str)}")

    # Sauvegarder
    out_path = "TOOLS/ST_PLCOPENXML_GENERATOR/samples_reference_codesys/PRG_06_Outputs_LD_full.xml"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(xml_str)
    print(f"Écrit: {out_path}")


if __name__ == "__main__":
    main()