#!/usr/bin/env python3
"""Génère le POU PRG_06_Outputs_LD complet en LD XML, basé sur l'oracle CODESYS
PRG_06_Outputs_LD.xml (samples_reference_codesys). Contourne les bugs de ld_builder.py.

🛡️ LOT_STRUCTURE_INTERLOCKS_LD (2026-08) : réécriture structurelle.
- Barrières finales M1/M2/M3 rendues visibles : FB_WinchOutputInterlock_LD (×2)
  et FB_TranslationOutputInterlock_LD (×1) câblés en réseaux dédiés, avec
  chaque input nommé sur la variable qualifiée réelle (demande brute publique
  ST_WinchFinalInterlockRequest / ST_TranslationFinalInterlockRequest) — la
  maintenance voit directement quel interlock/safety bloque quel actionneur.
- SafetyStructureNotValidated (TRUE par défaut) gate M1/M2/M3InterlockEnable :
  AUCUNE sortie physique n'est autorisée tant que ce garde-fou n'est pas retiré
  dans un lot safety validé séparément.
- FB_Output retiré (inverseur pur, jamais utilisé avec InvertLogic<>FALSE,
  REX 2026-08-04) : coils Q câblées directement sur la sortie des interlocks.

Structure conforme à l'oracle CODESYS (contraintes structurelles découvertes
par REX, voir check_ld_invariants.py) :
- TRUE -> contact <variable>TRUE</variable> (PAS inVariable expr=1)
- Variables qualifiées BOOL -> contact (PAS inVariable avec expression)
- Variables qualifiées non-BOOL (INT/WORD/REAL) -> inVariable avec expression
- Inputs non connectés -> inVariable expression vide
- Outputs assignés -> <expression>target</expression> dans outputVariables
- Premier output d'un bloc -> <connectionPointOut/> (câblable, pas d'expression)
- localId du bloc < localId de ses sources (réserver le block_id AVANT ses sources)
- Coil après bloc -> <connection refLocalId=block formalParameter=Output />
"""
from __future__ import annotations
import xml.etree.ElementTree as ET
import uuid

NS = "http://www.plcopen.org/xml/tc6_0200"
ET.register_namespace('', NS)

# ═══════════════════════════════════════════════════════════════════════
# Données des 3 barrières finales (M1, M2 Winch + M3 Translation)
# ═══════════════════════════════════════════════════════════════════════

# Champs de ST_WinchFinalInterlockRequest consommés par FB_WinchOutputInterlock_LD
# (formalParameter du bloc, champ de la demande brute publique — BOOL sauf RequestedStep)
WINCH_INTERLOCK_INPUT_FIELDS = [
    ("Reset_EXTERNAL", None),  # placeholder non utilisé, retiré ci-dessous
]

WINCH_REQUEST_BOOL_FIELDS = [
    "PowerContactorEngaged", "SafeStop", "BrakeReleaseRequest",
    "BrakeCommandOpenConfirmed", "FwdRevSpeedFeedbackOff",
    "RequestedRelayFwd", "RequestedRelayRev",
    "RequestedContactor1", "RequestedContactor2", "RequestedContactor3", "RequestedContactor4",
]
WINCH_REQUEST_INT_FIELDS = ["RequestedStep"]

# Sorties FB_WinchOutputInterlock_LD (ordre de déclaration) — Ready = 1er (bare, wireable)
WINCH_INTERLOCK_OUTPUTS = [
    "Ready", "Busy", "Done", "Error", "ErrorId", "State", "StateAtError", "Reason",
    "AuthorizedStep", "RelayFwd", "RelayRev", "Contactor1", "Contactor2", "Contactor3",
    "Contactor4", "BrakeCmd", "BrakeTimeoutElapsed", "RestartInhibit",
    "RestartDelayElapsed", "StepDelayElapsed",
]

TRANSLATION_REQUEST_BOOL_FIELDS = [
    "PowerContactorEngaged", "SafeStop", "BrakeReleaseRequest", "BrakeCommandOpenConfirmed",
]
TRANSLATION_REQUEST_WORD_REAL_FIELDS = ["RequestedDriveControlWord", "RequestedDriveFreqHz"]

TRANSLATION_INTERLOCK_OUTPUTS = [
    "Ready", "Busy", "Done", "Error", "ErrorId", "State", "StateAtError", "Reason",
    "BrakeTimeoutElapsed", "RestartInhibit", "DriveControlWord", "DriveFreqRefHz", "BrakeCmd",
]

# Actionneurs Q physiques : (source_var_locale, dq_var_device, gvl_global_field, commentaire)
ACTUATOR_NETWORKS = [
    ("M1RelayFwd",        "M1_RelayFwd_Up_DQ",        "M1RelayFwd",        "Relais M1 Marche Avant (Montée)"),
    ("M1RelayRev",        "M1_RelayRev_Down_DQ",      "M1RelayRev",        "Relais M1 Marche Arrière (Descente)"),
    ("M1SpeedContactor1", "M1_SpeedContactor_1_DQ",   "M1SpeedContactor1", "Contacteur Vitesse M1-1"),
    ("M1SpeedContactor2", "M1_SpeedContactor_2_DQ",   "M1SpeedContactor2", "Contacteur Vitesse M1-2"),
    ("M1SpeedContactor3", "M1_SpeedContactor_3_DQ",   "M1SpeedContactor3", "Contacteur Vitesse M1-3"),
    ("M1SpeedContactor4", "M1_SpeedContactor_4_DQ",   "M1SpeedContactor4", "Contacteur Vitesse M1-4"),
    ("M1BrakeCmd",        "M1_BrakeRelease_RQ",       "M1BrakeCmd",        "Frein M1"),
    ("M2RelayFwd",        "M2_RelayFwd_Up_Close_DQ",  "M2RelayFwd",        "Relais M2 Marche Avant (Fermeture)"),
    ("M2RelayRev",        "M2_RelayRev_Down_Open_DQ", "M2RelayRev",        "Relais M2 Marche Arrière (Ouverture)"),
    ("M2SpeedContactor1", "M2_SpeedContactor_1_DQ",   "M2SpeedContactor1", "Contacteur Vitesse M2-1"),
    ("M2SpeedContactor2", "M2_SpeedContactor_2_DQ",   "M2SpeedContactor2", "Contacteur Vitesse M2-2"),
    ("M2SpeedContactor3", "M2_SpeedContactor_3_DQ",   "M2SpeedContactor3", "Contacteur Vitesse M2-3"),
    ("M2SpeedContactor4", "M2_SpeedContactor_4_DQ",   "M2SpeedContactor4", "Contacteur Vitesse M2-4"),
    ("M2BrakeCmd",        "M2_BrakeRelease_RQ",       "M2BrakeCmd",        "Frein M2"),
    ("TranslationBrakeCmd", "M3_BrakeRelease_RQ",     "TranslationBrakeCmd", "Frein Translation M3"),
]

# Inputs de FB_Safety (ordre de déclaration) — inchangé (AC5 : ne pas modifier)
FB_SAFETY_INPUTS = ["Enable", "Reset", "ArmRequest", "EmergencyChainClosed", "PowerContactorEngaged", "PowerCutOffRequest", "BtnEmergencyCutOff"]
FB_SAFETY_OUTPUTS = ["Ready", "Busy", "Done", "Error", "ErrorId", "MaintainA_RQ", "MaintainB_RQ", "ArmPulse_RQ", "State", "Diag", "ArmingSeqStep", "RedundancyTestFailed", "EmergencyArmingFailed", "EmergencyArmingLockoutActive"]

FB_SAFETY_OUTPUT_ASSIGNS = {
    "MaintainA_RQ": "PowerKeepAlive_A_RQ",
    "MaintainB_RQ": "PowerKeepAlive_B_RQ",
    "ArmPulse_RQ": "EmergencyArmingPulseActive",
    "ArmingSeqStep": "ArmingSeqStep",
    "RedundancyTestFailed": "RedundancyTestFailed",
    "EmergencyArmingFailed": "EmergencyArmingFailed",
}

FB_SAFETY_INPUT_SOURCES = [
    ("Enable", "TRUE", True),
    ("Reset", "PRG_07_Supervision.FaultMachineReset_IHM", False),
    ("ArmRequest", "GVL_IHM.Modes.Cmd.BtnEmergencyArming", False),
    ("EmergencyChainClosed", "PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI", False),
    ("PowerContactorEngaged", "PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI", False),
    ("PowerCutOffRequest", "PowerCutOffReq", False),
    ("BtnEmergencyCutOff", "GVL_IHM.Modes.Cmd.BtnEmergencyCutOff", False),
]


def _pos(el):
    ET.SubElement(el, "position", x="0", y="0")


def _new_id(counter):
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


def _network_header(ld, counter, text):
    """En-tête standard (1 comment + 1 vendorElement) pour un réseau."""
    _make_comment(ld, _new_id(counter), text)
    _make_vendor_element(ld, _new_id(counter))


def _make_contact(ld, lid, var_text, negated=False, source_local_id=0):
    """Crée un contact câblé sur une source (rail gauche par défaut)."""
    c = ET.SubElement(ld, "contact")
    c.set("localId", str(lid))
    c.set("negated", "true" if negated else "false")
    c.set("storage", "none")
    c.set("edge", "none")
    _pos(c)
    cpi = ET.SubElement(c, "connectionPointIn")
    conn = ET.SubElement(cpi, "connection")
    conn.set("refLocalId", str(source_local_id))
    ET.SubElement(c, "connectionPointOut")
    v = ET.SubElement(c, "variable")
    v.text = var_text
    return c


def _make_invariable_empty(ld, lid):
    iv = ET.SubElement(ld, "inVariable")
    iv.set("localId", str(lid))
    _pos(iv)
    ET.SubElement(iv, "connectionPointOut")
    ET.SubElement(iv, "expression")
    return iv


def _make_invariable_expr(ld, lid, expr_text):
    """inVariable câblé sur une variable qualifiée non-BOOL (INT/WORD/REAL)."""
    iv = ET.SubElement(ld, "inVariable")
    iv.set("localId", str(lid))
    _pos(iv)
    ET.SubElement(iv, "connectionPointOut")
    e = ET.SubElement(iv, "expression")
    e.text = expr_text
    return iv


def _make_coil(ld, lid, ref_local_id, var_text, formal_param=None):
    """Crée une coil connectée à un bloc (formalParameter) ou un contact (sans)."""
    coil = ET.SubElement(ld, "coil")
    coil.set("localId", str(lid))
    coil.set("negated", "false")
    coil.set("storage", "none")
    _pos(coil)
    cpi = ET.SubElement(coil, "connectionPointIn")
    conn = ET.SubElement(cpi, "connection")
    conn.set("refLocalId", str(ref_local_id))
    if formal_param:
        conn.set("formalParameter", formal_param)
    ET.SubElement(coil, "connectionPointOut")
    v = ET.SubElement(coil, "variable")
    v.text = var_text
    return coil


def _make_block(ld, lid, type_name, instance_name, input_specs, output_specs):
    """Bloc FB générique.

    input_specs  : liste ordonnée (formalParameter, source_local_id)
    output_specs : liste ordonnée (formalParameter, target_var_or_None) —
                   1er élément toujours bare (connectionPointOut sans expression,
                   câblable graphiquement) ; les suivants portent toujours une
                   <expression> (vide si target_var_or_None est None).
    """
    block = ET.SubElement(ld, "block")
    block.set("localId", str(lid))
    block.set("typeName", type_name)
    block.set("instanceName", instance_name)
    _pos(block)

    in_vars = ET.SubElement(block, "inputVariables")
    for p_name, src_id in input_specs:
        v = ET.SubElement(in_vars, "variable")
        v.set("formalParameter", p_name)
        cpi = ET.SubElement(v, "connectionPointIn")
        conn = ET.SubElement(cpi, "connection")
        conn.set("refLocalId", str(src_id))

    ET.SubElement(block, "inOutVariables")

    out_vars = ET.SubElement(block, "outputVariables")
    for idx, (out_p, target) in enumerate(output_specs):
        v = ET.SubElement(out_vars, "variable")
        v.set("formalParameter", out_p)
        cpo = ET.SubElement(v, "connectionPointOut")
        if idx > 0:
            expr = ET.SubElement(cpo, "expression")
            if target:
                expr.text = target

    ad = ET.SubElement(block, "addData")
    d = ET.SubElement(ad, "data")
    d.set("name", "http://www.3s-software.com/plcopenxml/fbdcalltype")
    d.set("handleUnknown", "implementation")
    ct = ET.SubElement(d, "CallType")
    ct.set("xmlns", "")
    ct.text = "functionblock"
    return block


def _build_interlock_gate_network(ld, counter, title, request_enable_var, coil_var):
    """Réseau AND(RequestEnable, NOT SafetyStructureNotValidated) -> coil InterlockEnable.

    Rend visible EN CLAIR le garde-fou structurel : tant que
    SafetyStructureNotValidated=TRUE, InterlockEnable reste FALSE quel que soit
    RequestEnable — AUCUNE sortie physique n'est autorisée.
    """
    _network_header(ld, counter, title)
    c1_id = _new_id(counter)
    _make_contact(ld, c1_id, request_enable_var, source_local_id=0)
    c2_id = _new_id(counter)
    _make_contact(ld, c2_id, "SafetyStructureNotValidated", negated=True, source_local_id=c1_id)
    coil_id = _new_id(counter)
    _make_coil(ld, coil_id, c2_id, coil_var)


def _build_winch_interlock_network(ld, counter, title, instance_name, enable_var,
                                    request_prefix, output_targets):
    """Réseau FB_WinchOutputInterlock_LD : demande brute PUBLIQUE nommée en clair
    (aucune variable interne de FB lue directement — AC2).

    🔌 REX (export manuel utilisateur PRG_06_Outputs_LD_interlock.xml, pattern
    validé) : les sorties physiques (RelayFwd, RelayRev, Contactor1..4, BrakeCmd)
    ne sont PAS assignées par <expression> DANS le bloc — elles restent vides ici.
    L'assignation se fait par un réseau EXTERNE VISIBLE juste après (contact
    sur la broche de sortie du bloc -> coil), voir _build_interlock_output_networks.
    Assigner les deux en même temps créerait un double assignement (coil externe
    + expression interne sur le même output) -> ArgumentNullException à
    l'ouverture CODESYS (check_ld_invariants.py règle 2).

    Retourne block_id (réutilisé par _build_interlock_output_networks).
    """
    _network_header(ld, counter, title)

    block_id = _new_id(counter)  # réservé AVANT ses sources (contrainte CODESYS)

    input_ids = []
    # Enable (local, post-gate) puis Reset (global)
    e_id = _new_id(counter)
    _make_contact(ld, e_id, enable_var)
    input_ids.append(("Enable", e_id))
    r_id = _new_id(counter)
    _make_contact(ld, r_id, "PRG_07_Supervision.FaultMachineReset_IHM")
    input_ids.append(("Reset", r_id))
    for field in WINCH_REQUEST_BOOL_FIELDS:
        cid = _new_id(counter)
        _make_contact(ld, cid, f"{request_prefix}.{field}")
        input_ids.append((field, cid))
    for field in WINCH_REQUEST_INT_FIELDS:
        vid = _new_id(counter)
        _make_invariable_expr(ld, vid, f"{request_prefix}.{field}")
        input_ids.append((field, vid))

    # 🔌 REX (incident réel 2026-08 : «référence de l'objet non définie» à l'import) :
    # un contact externe câblé sur la broche de sortie du bloc (formalParameter)
    # AVEC un libellé de variable qui n'est PAS exactement la référence source
    # (ex. contact affiché «M1RelayFwd» mais connecté à
    # instWinchOutputInterlockM1.RelayFwd) crée une incohérence de résolution
    # d'opérande que CODESYS refuse à l'ouverture. Pattern sûr retenu : assigner
    # directement par <expression> dans le bloc (sortie -> variable locale),
    # la variable locale reste ensuite visible individuellement via son propre
    # réseau de recopie GVL_Global (voir _build_actuator_network).
    output_specs = [(out, output_targets.get(out)) for out in WINCH_INTERLOCK_OUTPUTS]

    _make_block(ld, block_id, "FB_WinchOutputInterlock_LD", instance_name, input_ids, output_specs)
    return block_id


def _build_translation_interlock_network(ld, counter, title, instance_name, enable_var,
                                          request_prefix, output_targets):
    _network_header(ld, counter, title)

    block_id = _new_id(counter)

    input_ids = []
    e_id = _new_id(counter)
    _make_contact(ld, e_id, enable_var)
    input_ids.append(("Enable", e_id))
    r_id = _new_id(counter)
    _make_contact(ld, r_id, "PRG_07_Supervision.FaultMachineReset_IHM")
    input_ids.append(("Reset", r_id))
    for field in TRANSLATION_REQUEST_BOOL_FIELDS:
        cid = _new_id(counter)
        _make_contact(ld, cid, f"{request_prefix}.{field}")
        input_ids.append((field, cid))
    for field in TRANSLATION_REQUEST_WORD_REAL_FIELDS:
        vid = _new_id(counter)
        _make_invariable_expr(ld, vid, f"{request_prefix}.{field}")
        input_ids.append((field, vid))

    # Assignation directe par <expression> dans le bloc — voir REX ci-dessus
    # (_build_winch_interlock_network) : pas de contact externe sur broche de sortie.
    output_specs = [(out, output_targets.get(out)) for out in TRANSLATION_INTERLOCK_OUTPUTS]

    _make_block(ld, block_id, "FB_TranslationOutputInterlock_LD", instance_name, input_ids, output_specs)
    return block_id


def _build_actuator_network(ld, counter, source_var, dq_var, gvl_field, comment_text):
    """Recopie GVL_Global (lecture publique diagnostic/simulation) uniquement.

    🚫 REX 2026-08-04 (hérité, validé — confirmé par l'export manuel utilisateur
    PRG_06_Outputs_LD_interlock.xml, qui s'arrête lui aussi à la variable locale) :
    un coil LD câblé directement sur le nom Device brut (ex. M1_RelayFwd_Up_DQ,
    créé implicitement par le mapping E/S de Device.export, absent du bundle
    isolé) fait planter l'import CODESYS (ArgumentNullException
    GetOperandDeclarationInfo). La sortie physique reste donc pilotée par le
    mapping E/S CODESYS (Device.export, hors périmètre de ce lot, jamais
    modifié ici) pointé sur la variable locale du POU (déjà assignée par
    l'expression de sortie du bloc d'interlock, voir
    _build_winch_interlock_network / _build_translation_interlock_network).
    Seule la recopie qualifiée GVL_Global.* (lecture publique diagnostic/
    simulation) est câblée ici en Ladder.
    """
    _make_comment(ld, _new_id(counter), comment_text)
    _make_vendor_element(ld, _new_id(counter))

    contact_id = _new_id(counter)
    _make_contact(ld, contact_id, source_var)

    gvl_coil_id = _new_id(counter)
    _make_coil(ld, gvl_coil_id, contact_id, f"GVL_Global.{gvl_field}")


def _make_fb_safety_block(ld, lid, instance_name, input_source_ids):
    block = ET.SubElement(ld, "block")
    block.set("localId", str(lid))
    block.set("typeName", "FB_Safety_EmergencyManagement")
    block.set("instanceName", instance_name)
    _pos(block)

    in_vars = ET.SubElement(block, "inputVariables")
    for i, p_name in enumerate(FB_SAFETY_INPUTS):
        v = ET.SubElement(in_vars, "variable")
        v.set("formalParameter", p_name)
        cpi = ET.SubElement(v, "connectionPointIn")
        conn = ET.SubElement(cpi, "connection")
        conn.set("refLocalId", str(input_source_ids[i]))

    ET.SubElement(block, "inOutVariables")

    out_vars = ET.SubElement(block, "outputVariables")
    for idx, out_p in enumerate(FB_SAFETY_OUTPUTS):
        v = ET.SubElement(out_vars, "variable")
        v.set("formalParameter", out_p)
        cpo = ET.SubElement(v, "connectionPointOut")
        if idx == 0:
            pass
        else:
            expr = ET.SubElement(cpo, "expression")
            if out_p in FB_SAFETY_OUTPUT_ASSIGNS:
                expr.text = FB_SAFETY_OUTPUT_ASSIGNS[out_p]

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

    counter = [1]

    lpr = ET.SubElement(ld, "leftPowerRail")
    lpr.set("localId", "0")
    _pos(lpr)
    cpo = ET.SubElement(lpr, "connectionPointOut")
    cpo.set("formalParameter", "none")

    # ═══════════════════════════════════════════════════════════
    # Section 1 : Barrières finales M1 / M2 / M3 — interlocks visibles
    # ═══════════════════════════════════════════════════════════

    _build_interlock_gate_network(
        ld, counter,
        "🛡️ Interlock M1 — Autorisation (structure validée AND demande Enable)",
        "PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.Enable",
        "M1InterlockEnable",
    )
    m1_targets = {
        "RelayFwd": "M1RelayFwd", "RelayRev": "M1RelayRev",
        "Contactor1": "M1SpeedContactor1", "Contactor2": "M1SpeedContactor2",
        "Contactor3": "M1SpeedContactor3", "Contactor4": "M1SpeedContactor4",
        "BrakeCmd": "M1BrakeCmd",
    }
    m1_block_id = _build_winch_interlock_network(
        ld, counter,
        "🛡️ Barrière finale M1 (Treuil Retenue) — FB_WinchOutputInterlock_LD",
        "instWinchOutputInterlockM1",
        "M1InterlockEnable",
        "PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest",
        m1_targets,
    )

    _build_interlock_gate_network(
        ld, counter,
        "🛡️ Interlock M2 — Autorisation (structure validée AND demande Enable)",
        "PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.Enable",
        "M2InterlockEnable",
    )
    m2_targets = {
        "RelayFwd": "M2RelayFwd", "RelayRev": "M2RelayRev",
        "Contactor1": "M2SpeedContactor1", "Contactor2": "M2SpeedContactor2",
        "Contactor3": "M2SpeedContactor3", "Contactor4": "M2SpeedContactor4",
        "BrakeCmd": "M2BrakeCmd",
    }
    m2_block_id = _build_winch_interlock_network(
        ld, counter,
        "🛡️ Barrière finale M2 (Treuil Benne) — FB_WinchOutputInterlock_LD",
        "instWinchOutputInterlockM2",
        "M2InterlockEnable",
        "PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest",
        m2_targets,
    )

    _build_interlock_gate_network(
        ld, counter,
        "🛡️ Interlock M3 — Autorisation (structure validée AND demande Enable)",
        "PRG_05_Translation.TranslationFinalInterlockRequest.Enable",
        "M3InterlockEnable",
    )
    m3_targets = {"BrakeCmd": "TranslationBrakeCmd"}
    m3_block_id = _build_translation_interlock_network(
        ld, counter,
        "🛡️ Barrière finale M3 (Translation AC600) — FB_TranslationOutputInterlock_LD",
        "instTranslationOutputInterlockM3",
        "M3InterlockEnable",
        "PRG_05_Translation.TranslationFinalInterlockRequest",
        m3_targets,
    )

    # ═══════════════════════════════════════════════════════════
    # Section 2 : recopie GVL_Global (lecture publique diagnostic/simulation)
    # ═══════════════════════════════════════════════════════════
    for source_var, dq_var, gvl_field, comment_text in ACTUATOR_NETWORKS:
        _build_actuator_network(ld, counter, source_var, dq_var, gvl_field, comment_text)

    # ═══════════════════════════════════════════════════════════
    # Section 3 : Sécurité & Coupure Puissance Amont (FB_Safety) — inchangé (AC5)
    # ═══════════════════════════════════════════════════════════
    _make_comment(ld, _new_id(counter), "🛡️ Sécurité & Coupure Puissance Amont")
    _make_vendor_element(ld, _new_id(counter))

    safety_block_id = _new_id(counter)

    safety_input_ids = []
    for fp, var_text, is_true in FB_SAFETY_INPUT_SOURCES:
        cid = _new_id(counter)
        _make_contact(ld, cid, var_text)
        safety_input_ids.append(cid)

    _make_fb_safety_block(ld, safety_block_id, "instSafetyEmergencyManagement", safety_input_ids)

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

    iface = ET.SubElement(pou, "interface")

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
        ("EmergencyState", "ST_Safety_Emergency_State"),
        ("EmergencyDiag", "ST_Safety_Emergency_Diag"),
        ("PowerCutOffActive", "BOOL"),
        ("SafetyStructureNotValidated", "BOOL"),
        ("M1InterlockEnable", "BOOL"),
        ("M2InterlockEnable", "BOOL"),
        ("M3InterlockEnable", "BOOL"),
    ]:
        v = ET.SubElement(out_vars, "variable")
        v.set("name", name)
        t = ET.SubElement(v, "type")
        if typ.startswith("ST_"):
            d = ET.SubElement(t, "derived")
            d.set("name", typ)
        else:
            ET.SubElement(t, typ)
        if name == "SafetyStructureNotValidated":
            iv = ET.SubElement(v, "initialValue")
            sv = ET.SubElement(iv, "simpleValue")
            sv.set("value", "TRUE")

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

    for name, fb_type in [
        ("instWinchOutputInterlockM1", "FB_WinchOutputInterlock_LD"),
        ("instWinchOutputInterlockM2", "FB_WinchOutputInterlock_LD"),
        ("instTranslationOutputInterlockM3", "FB_TranslationOutputInterlock_LD"),
        ("instSafetyEmergencyManagement", "FB_Safety_EmergencyManagement"),
    ]:
        v = ET.SubElement(local_vars, "variable")
        v.set("name", name)
        t = ET.SubElement(v, "type")
        d = ET.SubElement(t, "derived")
        d.set("name", fb_type)

    body = build_prg06_ld()
    pou.append(body)

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

    out_path = "TOOLS/ST_PLCOPENXML_GENERATOR/samples_reference_codesys/PRG_06_Outputs_LD_full.xml"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(xml_str)
    print(f"Écrit: {out_path}")


if __name__ == "__main__":
    main()
