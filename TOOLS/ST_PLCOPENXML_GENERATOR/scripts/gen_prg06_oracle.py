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

🆕 LOT2 (2026-08-05) : DriveControlWord et DriveFreqRefWord (sorties WORD de
FB_TranslationOutputInterlock_LD) capturés en variables locales M3_DriveControlWord /
M3_DriveFreqRefWord (même pattern <expression> interne au bloc que TranslationBrakeCmd).
Échelle DriveFreqRefWord confirmée terrain (utilisateur) : WORD=5000 -> 50,00 Hz sur le
registre PDO 0x3100. Le mapping E/S CODESYS (Device.export, jamais modifié ici) reste à
faire manuellement par l'utilisateur : M3_CommandWord (0x3101, %QW6) <- M3_DriveControlWord,
M3_SetpointFrequencyHz (0x3100, %QW7) <- M3_DriveFreqRefWord.

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
    # 🆕 2026-08-06 (retrait FB_Brake, demande client) : BrakeReleaseRequest/
    # BrakeCommandOpenConfirmed remplaces par BrakeFeedback (retour physique brut) --
    # FB_WinchOutputInterlock_LD calcule desormais BrakeCmd := RelayFwd OR RelayRev.
    "PowerContactorEngaged", "SafeStop", "BrakeFeedback", "FwdRevSpeedFeedbackOff",
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
    "BrakeTimeoutElapsed", "RestartInhibit", "DriveControlWord", "DriveFreqRefHz",
    "DriveFreqRefWord", "BrakeCmd",
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

# 🧪 Coils DIRECTES sur noms HW bruts (Device_IO CSV) — décision explicite utilisateur
# 2026-08-06, malgré le risque documenté dans _build_actuator_network ci-dessous.
# Nuance importante : le crash REX 2026-08-04 (ArgumentNullException) visait un nom
# totalement ABSENT du bundle (aucune déclaration, ni locale ni GVL). Ici la SOURCE
# (contact) est une variable locale déjà déclarée dans ce POU ; seule la CIBLE de la
# coil (M3_BrakeRelease_RQ) reste externe au bundle (Device I/O mapping CODESYS).
# Non vérifié par cet outil : reproduit potentiellement le même crash si l'import
# CODESYS résout aussi le TYPE de la cible d'une coil contre le bundle importé (ce
# que ce POU seul ne peut pas prouver — seul un import réel CODESYS le confirme).
# ⚠️ SCOPE MINIMAL DÉLIBÉRÉ (frein M3 uniquement) — ne pas généraliser aux autres
# canaux (M1/M2, chaîne AU) avant validation de CE réseau précis à l'import CODESYS.
DIRECT_HW_COILS = [
    ("M1RelayFwd", "M1_RelayFwd_Up_DQ", "Relais Montée M1"),
    ("M1RelayRev", "M1_RelayRev_Down_DQ", "Relais Descente M1"),
    ("M1SpeedContactor1", "M1_SpeedContactor_1_DQ", "Contacteur Vitesse M1-1"),
    ("M1SpeedContactor2", "M1_SpeedContactor_2_DQ", "Contacteur Vitesse M1-2"),
    ("M1SpeedContactor3", "M1_SpeedContactor_3_DQ", "Contacteur Vitesse M1-3"),
    ("M1SpeedContactor4", "M1_SpeedContactor_4_DQ", "Contacteur Vitesse M1-4"),
    ("M1BrakeCmd", "M1_BrakeRelease_RQ", "Frein M1"),
    ("M2RelayFwd", "M2_RelayFwd_Up_Close_DQ", "Relais Fermeture/Montée M2"),
    ("M2RelayRev", "M2_RelayRev_Down_Open_DQ", "Relais Ouverture/Descente M2"),
    ("M2SpeedContactor1", "M2_SpeedContactor_1_DQ", "Contacteur Vitesse M2-1"),
    ("M2SpeedContactor2", "M2_SpeedContactor_2_DQ", "Contacteur Vitesse M2-2"),
    ("M2SpeedContactor3", "M2_SpeedContactor_3_DQ", "Contacteur Vitesse M2-3"),
    ("M2SpeedContactor4", "M2_SpeedContactor_4_DQ", "Contacteur Vitesse M2-4"),
    ("M2BrakeCmd", "M2_BrakeRelease_RQ", "Frein M2"),
    ("TranslationBrakeCmd", "M3_BrakeRelease_RQ", "Frein Translation M3"),
    ("KoboldContactorCmd", "M1_M2_KoboldMeasureEnable_DQ", "Contacteur Mesure Kobold"), # 🆕 2026-08-07 (12bis), urgence terrain
    ("PowerKeepAliveACmd", "PowerKeepAlive_A_RQ", "Maintien Puissance Voie A"),
    ("PowerKeepAliveBCmd", "PowerKeepAlive_B_RQ", "Maintien Puissance Voie B"),
    ("EmergencyArmingCmd", "EmergencyArming_RQ", "Impulsion Réarmement AU"),
]

# Inputs de FB_Safety (ordre de déclaration) — inchangé (AC5 : ne pas modifier)
FB_SAFETY_INPUTS = ["Enable", "Reset", "ArmRequest", "EmergencyChainClosed", "PowerContactorEngaged", "PowerCutOffRequest", "BtnEmergencyCutOff"]
FB_SAFETY_OUTPUTS = ["Ready", "Busy", "Done", "Error", "ErrorId", "MaintainA_RQ", "MaintainB_RQ", "ArmPulse_RQ", "State", "Diag", "ArmingSeqStep", "RedundancyTestFailed", "EmergencyArmingFailed", "EmergencyArmingLockoutActive"]

FB_SAFETY_OUTPUT_ASSIGNS = {
    # 🐛 FIX 2026-08-05 (confirmé câblé réel par l'utilisateur, même bug que M1/M2/M3) :
    # PowerKeepAlive_A_RQ/PowerKeepAlive_B_RQ/EmergencyArming_RQ sont des noms Device
    # bruts (Device_IO CSV) — un coil dessus crée une collision de portée avec la
    # globale homonyme créée par le mapping E/S CODESYS. Renommés en *Cmd (variables
    # locales, cf. local_vars ci-dessous) ; le mapping E/S doit cibler le chemin
    # qualifié PRG_06_Outputs_LD.PowerKeepAliveACmd / BCmd / EmergencyArmingCmd.
    "MaintainA_RQ": "PowerKeepAliveACmd",
    "MaintainB_RQ": "PowerKeepAliveBCmd",
    "ArmPulse_RQ": "EmergencyArmingPulseActive",
    "ArmingSeqStep": "ArmingSeqStep",
    "RedundancyTestFailed": "RedundancyTestFailed",
    "EmergencyArmingFailed": "EmergencyArmingFailed",
    # 🐛 FIX 2026-08-14 (REX troubleshooting AU, plusieurs heures de diagnostic) :
    # "State"/"Diag" absents de cette table -> pin de sortie du bloc généré avec une
    # <expression/> VIDE dans le Ladder réel (contrairement au .st source qui écrit
    # EmergencyState/EmergencyDiag par copie de struct, PRG_06_Outputs_LD.st:339-340).
    # PRG_06_Outputs_LD est TOUJOURS généré en Ladder par cet oracle, jamais compilé
    # depuis le .st littéralement -- ce bug rendait EmergencyState/EmergencyDiag figés
    # à leur valeur d'init (FALSE/0) en permanence sur le PLC réel, silencieusement :
    # aucune erreur d'import, aucun gate ne le détectait (G200 preuve la liaison
    # ST source, pas le contenu réel du <expression> Ladder généré). Tous les champs
    # Troubleshooting sourcés depuis State/Diag (Step3 ChainOk, Step4, Step5,
    # SafetyError, ArmingErrorId) restaient donc bloqués quoi qu'il arrive côté AU réel,
    # alors que les sorties individuellement mappées ci-dessus (ArmingSeqStep,
    # RedundancyTestFailed, EmergencyArmingFailed...) fonctionnaient normalement.
    "State": "EmergencyState",
    "Diag": "EmergencyDiag",
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


def _build_interlock_gate_network(ld, counter, title, request_enable_var, coil_var, safety_vars=None):
    """Réseau AND(RequestEnable, NOT safety_var1, NOT safety_var2, ...) -> coil InterlockEnable.

    Rend visible EN CLAIR le garde-fou structurel / sécurité machine.
    """
    _network_header(ld, counter, title)
    c1_id = _new_id(counter)
    _make_contact(ld, c1_id, request_enable_var, source_local_id=0)

    if safety_vars is None:
        safety_vars = ["SafetyStructureNotValidated"]
    elif isinstance(safety_vars, str):
        safety_vars = [safety_vars]

    prev_id = c1_id
    for var in safety_vars:
        c_id = _new_id(counter)
        _make_contact(ld, c_id, var, negated=True, source_local_id=prev_id)
        prev_id = c_id

    coil_id = _new_id(counter)
    _make_coil(ld, coil_id, prev_id, coil_var)


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

    # 🐛 FIX 2026-08-05 (audit terrain M3, contacteur frein jamais piloté) : un coil câblé
    # directement sur dq_var (ex. M3_BrakeRelease_RQ) ne plante plus l'import (dq_var est
    # déclaré en VAR_OUTPUT ci-dessous), mais CRÉE UNE COLLISION DE PORTÉE : CODESYS crée
    # aussi une variable GLOBALE de même nom lors du mapping E/S du device (Device.export).
    # Un identificateur local masque toujours un identificateur global de même nom (IEC
    # 61131-3) : toute écriture ICI dans PRG_06_Outputs_LD résout vers la sortie LOCALE du
    # POU, jamais vers la globale réellement mappée au matériel — la sortie physique ne
    # bouge donc jamais, sans aucune erreur d'import ni de compilation pour le signaler.
    # Confirmé en test terrain (2026-08-05) : écrire dq_var depuis un AUTRE POU pilote bien
    # le HW ; l'écrire depuis PRG_06_Outputs_LD ne pilote rien. Coil supprimé : le mapping
    # E/S CODESYS doit cibler le chemin qualifié PRG_06_Outputs_LD.<source_var> (variable
    # locale ci-dessus, ex. TranslationBrakeCmd), jamais le nom nu dq_var.


def _build_direct_hw_coil_network(ld, counter, source_var, hw_var, comment_text):
    """🧪 Réseau expérimental : contact sur variable locale (déjà déclarée dans ce
    POU) -> coil directement sur le nom HW brut (Device I/O mapping, non déclaré
    dans le bundle). Voir DIRECT_HW_COILS ci-dessus pour le risque documenté et le
    scope volontairement minimal.
    """
    _make_comment(ld, _new_id(counter), comment_text)
    _make_vendor_element(ld, _new_id(counter))

    contact_id = _new_id(counter)
    _make_contact(ld, contact_id, source_var)

    coil_id = _new_id(counter)
    _make_coil(ld, coil_id, contact_id, hw_var)


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
        [
            "PRG_04_Treuils_Benne.WinchM1SafetyHMI.SafeStop",
            "PRG_04_Treuils_Benne.WinchM1SafetyHMI.Error",
        ],
    )
    # 2026-08-06 (retrait FB_Brake, demande client) : BrakeCmd n'est plus capture ici --
    # M1BrakeCmd est recalcule independamment plus bas (OR M1RelayFwd/M1RelayRev, section 1bis),
    # visible directement dans ce reseau Ladder sans ouvrir FB_WinchOutputInterlock_LD.
    m1_targets = {
        "RelayFwd": "M1RelayFwd", "RelayRev": "M1RelayRev",
        "Contactor1": "M1SpeedContactor1", "Contactor2": "M1SpeedContactor2",
        "Contactor3": "M1SpeedContactor3", "Contactor4": "M1SpeedContactor4",
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
        [
            "PRG_04_Treuils_Benne.WinchM2SafetyHMI.SafeStop",
            "PRG_04_Treuils_Benne.WinchM2SafetyHMI.Error",
        ],
    )
    # 2026-08-06 (retrait FB_Brake) : BrakeCmd non capture ici -- voir M1 ci-dessus.
    m2_targets = {
        "RelayFwd": "M2RelayFwd", "RelayRev": "M2RelayRev",
        "Contactor1": "M2SpeedContactor1", "Contactor2": "M2SpeedContactor2",
        "Contactor3": "M2SpeedContactor3", "Contactor4": "M2SpeedContactor4",
    }
    m2_block_id = _build_winch_interlock_network(
        ld, counter,
        "🛡️ Barrière finale M2 (Treuil Benne) — FB_WinchOutputInterlock_LD",
        "instWinchOutputInterlockM2",
        "M2InterlockEnable",
        "PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest",
        m2_targets,
    )

    # ═══════════════════════════════════════════════════════════
    # Section 1bis : Frein M1/M2 -- couplage direct OR RelayFwd/RelayRev
    # (2026-08-06, retrait FB_Brake, demande client)
    # ═══════════════════════════════════════════════════════════
    # BrakeCmd n'est plus capture depuis la sortie du bloc FB_WinchOutputInterlock_LD --
    # recalcule INDEPENDAMMENT ici sur M1RelayFwd/M1RelayRev (deja assignes ci-dessus),
    # meme pattern OR-vers-coil que PowerCutOffReq (section 1ter). Visible directement
    # dans ce reseau Ladder, sans ouvrir FB_WinchOutputInterlock_LD -- aucun risque
    # d'ecart frein/mouvement, la coil recoit litteralement les memes signaux que les
    # relais de sens.
    _make_comment(ld, _new_id(counter), "🛑 M1BrakeCmd := M1RelayFwd OR M1RelayRev (couplage direct frein)")
    _make_vendor_element(ld, _new_id(counter))
    m1_brake_fwd_id = _new_id(counter)
    _make_contact(ld, m1_brake_fwd_id, "M1RelayFwd")
    m1_brake_rev_id = _new_id(counter)
    _make_contact(ld, m1_brake_rev_id, "M1RelayRev")
    m1_brake_coil_id = _new_id(counter)
    m1_brake_coil = ET.SubElement(ld, "coil")
    m1_brake_coil.set("localId", str(m1_brake_coil_id))
    m1_brake_coil.set("negated", "false")
    m1_brake_coil.set("storage", "none")
    _pos(m1_brake_coil)
    m1_brake_cpi = ET.SubElement(m1_brake_coil, "connectionPointIn")
    for src_id in (m1_brake_fwd_id, m1_brake_rev_id):
        conn = ET.SubElement(m1_brake_cpi, "connection")
        conn.set("refLocalId", str(src_id))
    ET.SubElement(m1_brake_coil, "connectionPointOut")
    m1_brake_var = ET.SubElement(m1_brake_coil, "variable")
    m1_brake_var.text = "M1BrakeCmd"

    _make_comment(ld, _new_id(counter), "🛑 M2BrakeCmd := M2RelayFwd OR M2RelayRev (couplage direct frein)")
    _make_vendor_element(ld, _new_id(counter))
    m2_brake_fwd_id = _new_id(counter)
    _make_contact(ld, m2_brake_fwd_id, "M2RelayFwd")
    m2_brake_rev_id = _new_id(counter)
    _make_contact(ld, m2_brake_rev_id, "M2RelayRev")
    m2_brake_coil_id = _new_id(counter)
    m2_brake_coil = ET.SubElement(ld, "coil")
    m2_brake_coil.set("localId", str(m2_brake_coil_id))
    m2_brake_coil.set("negated", "false")
    m2_brake_coil.set("storage", "none")
    _pos(m2_brake_coil)
    m2_brake_cpi = ET.SubElement(m2_brake_coil, "connectionPointIn")
    for src_id in (m2_brake_fwd_id, m2_brake_rev_id):
        conn = ET.SubElement(m2_brake_cpi, "connection")
        conn.set("refLocalId", str(src_id))
    ET.SubElement(m2_brake_coil, "connectionPointOut")
    m2_brake_var = ET.SubElement(m2_brake_coil, "variable")
    m2_brake_var.text = "M2BrakeCmd"

    # 🔴🔧 REX 2026-08-07 (12) — retour terrain, GAP CONFIRMÉ : KoboldContactorCmd était
    # déclaré (localVars ci-dessus) mais JAMAIS assigné -- ni ici, ni dans PRG_06_Outputs_LD.st
    # -- donc jamais câblé, quel que soit le mapping E/S CODESYS côté device. La chaîne
    # instDiveSearch.KoboldMeasureEnable -> PRG_04_Treuils_Benne.KoboldContactorCmdArbitrated
    # s'arrêtait net à la sortie de PRG_04 : le contacteur Kobold n'était physiquement JAMAIS
    # commandé, aucune erreur pour le signaler (même classe de bug que le fix M3 frein du
    # 2026-08-05, voir bandeau _build_actuator_network). Mapping E/S CODESYS à faire par
    # l'utilisateur : M1_M2_KoboldMeasureEnable_DQ <- PRG_06_Outputs_LD.KoboldContactorCmd.
    _make_comment(ld, _new_id(counter), "🔌 KoboldContactorCmd := PRG_04_Treuils_Benne.KoboldContactorCmdArbitrated")
    _make_vendor_element(ld, _new_id(counter))
    kobold_contact_id = _new_id(counter)
    _make_contact(ld, kobold_contact_id, "PRG_04_Treuils_Benne.KoboldContactorCmdArbitrated")
    kobold_coil_id = _new_id(counter)
    kobold_coil = ET.SubElement(ld, "coil")
    kobold_coil.set("localId", str(kobold_coil_id))
    kobold_coil.set("negated", "false")
    kobold_coil.set("storage", "none")
    _pos(kobold_coil)
    kobold_cpi = ET.SubElement(kobold_coil, "connectionPointIn")
    kobold_conn = ET.SubElement(kobold_cpi, "connection")
    kobold_conn.set("refLocalId", str(kobold_contact_id))
    ET.SubElement(kobold_coil, "connectionPointOut")
    kobold_var = ET.SubElement(kobold_coil, "variable")
    kobold_var.text = "KoboldContactorCmd"

    _build_interlock_gate_network(
        ld, counter,
        "🛡️ Interlock M3 — Autorisation (structure validée AND demande Enable)",
        "PRG_05_Translation.TranslationFinalInterlockRequest.Enable",
        "M3InterlockEnable",
        [
            "PRG_05_Translation.TranslationSafetyHMI.PowerCutOff",
            "PRG_05_Translation.TranslationSafetyHMI.SafeStop",
            "PRG_05_Translation.TranslationSafetyHMI.Error",
        ],
    )
    # 🆕 LOT2 2026-08-05 : DriveControlWord/DriveFreqRefWord (WORD) capturés en variables
    # locales par <expression> interne au bloc (même pattern sûr que BrakeCmd) — le
    # mapping E/S CODESYS (hors périmètre, jamais modifié ici) les pointe manuellement
    # sur M3_CommandWord (0x3101, %QW6) et M3_SetpointFrequencyHz (0x3100, %QW7).
    m3_targets = {
        "BrakeCmd": "TranslationBrakeCmd",
        "DriveControlWord": "M3_CommandWord",
        "DriveFreqRefWord": "M3_SetpointFrequencyHz",
    }
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
    # Section 2ter : 🧪 Coils directes sur noms HW bruts (essai scope minimal)
    # ═══════════════════════════════════════════════════════════
    for source_var, hw_var, comment_text in DIRECT_HW_COILS:
        _build_direct_hw_coil_network(ld, counter, source_var, hw_var, comment_text)

    # ═══════════════════════════════════════════════════════════
    # Section 2bis : Agrégation PowerCutOffReq (M5, A-04 — OU strict par procédé)
    # ═══════════════════════════════════════════════════════════
    # 🆕 REX 2026-08-05 (audit sécurité) : PowerCutOffReq était une variable locale jamais
    # écrite dans ce POU (ni en ST documentaire, ni dans le bundle réellement importé) —
    # instSafetyTranslationM3.PowerCutOff (lot M4) était donc calculé mais totalement inerte,
    # sans coupure amont réelle possible. Contact->coil direct depuis la demande publique M3
    # (jamais une lecture d'instance interne, AC3 du contrat M5). M1/M2 (FB_Safety_Winch, pas
    # encore instanciée) rejoindront ce OU par des contacts supplémentaires en parallèle dès
    # que leur safety publiera PowerCutOff — jamais une demande vraie masquée par l'absence
    # d'une autre source (M5, A-04).
    # 🆕 2026-08-05 : M1/M2 (FB_Safety_Winch) désormais câblés — OR à 3 contacts parallèles vers
    # une même coil, pattern confirmé par export CODESYS réel (samples_reference_codesys/
    # PRG_10_LD_Commentaires.xml, réseau instSafetyWinchM1/M2/instSafetyTranslationM3 -> PowerCutOffReq :
    # <connectionPointIn> d'une coil peut porter plusieurs <connection>, une par contact parallèle).
    _make_comment(ld, _new_id(counter), "🧨 PowerCutOffReq — agrégation OU strict M1/M2/M3 (M5, A-04)")
    _make_vendor_element(ld, _new_id(counter))
    pc_m1_id = _new_id(counter)
    _make_contact(ld, pc_m1_id, "PRG_04_Treuils_Benne.WinchM1FinalInterlockRequest.PowerCutOff")
    pc_m2_id = _new_id(counter)
    _make_contact(ld, pc_m2_id, "PRG_04_Treuils_Benne.WinchM2FinalInterlockRequest.PowerCutOff")
    pc_m3_id = _new_id(counter)
    _make_contact(ld, pc_m3_id, "PRG_05_Translation.TranslationFinalInterlockRequest.PowerCutOff")
    pc_coil_id = _new_id(counter)
    pc_coil = ET.SubElement(ld, "coil")
    pc_coil.set("localId", str(pc_coil_id))
    pc_coil.set("negated", "false")
    pc_coil.set("storage", "none")
    _pos(pc_coil)
    pc_cpi = ET.SubElement(pc_coil, "connectionPointIn")
    for src_id in (pc_m1_id, pc_m2_id, pc_m3_id):
        conn = ET.SubElement(pc_cpi, "connection")
        conn.set("refLocalId", str(src_id))
    ET.SubElement(pc_coil, "connectionPointOut")
    pc_var = ET.SubElement(pc_coil, "variable")
    pc_var.text = "PowerCutOffReq"

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

    # 🐛 FIX 2026-08-05 : EmergencyArmingCmd (cible réelle du mapping E/S, confirmée câblée
    # par l'utilisateur) n'était écrit nulle part dans le bundle — seul EmergencyArmingPulseActive
    # (miroir diagnostic) recevait ArmPulse_RQ via FB_SAFETY_OUTPUT_ASSIGNS. Recopie explicite.
    _make_comment(ld, _new_id(counter), "🔔 EmergencyArmingCmd — cible mapping E/S (miroir EmergencyArmingPulseActive)")
    _make_vendor_element(ld, _new_id(counter))
    arm_contact_id = _new_id(counter)
    _make_contact(ld, arm_contact_id, "EmergencyArmingPulseActive")
    arm_coil_id = _new_id(counter)
    arm_coil = ET.SubElement(ld, "coil")
    arm_coil.set("localId", str(arm_coil_id))
    arm_coil.set("negated", "false")
    arm_coil.set("storage", "none")
    _pos(arm_coil)
    arm_cpi = ET.SubElement(arm_coil, "connectionPointIn")
    arm_conn = ET.SubElement(arm_cpi, "connection")
    arm_conn.set("refLocalId", str(arm_contact_id))
    ET.SubElement(arm_coil, "connectionPointOut")
    arm_var = ET.SubElement(arm_coil, "variable")
    arm_var.text = "EmergencyArmingCmd"

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
        # 🐛 FIX 2026-08-05 : PowerKeepAlive_A_RQ/B_RQ/EmergencyArming_RQ retirés d'ici
        # (collision de portée, voir FB_SAFETY_OUTPUT_ASSIGNS) — remplacés par les VAR
        # locales PowerKeepAliveACmd/BCmd/EmergencyArmingCmd (voir local_vars).
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
            sv.set("value", "FALSE")

    # 🐛 FIX 2026-08-05 (audit terrain M3) : les VAR_OUTPUT dq_var (M1_RelayFwd_Up_DQ,
    # M3_BrakeRelease_RQ, ...) ne sont plus déclarées ici — plus aucun coil ne les cible
    # (voir _build_actuator_network), donc plus rien ne les référence dans le bundle.
    # Les déclarer créait une collision de portée avec la variable GLOBALE de même nom
    # créée par le mapping E/S CODESYS (Device.export) : un identificateur local masque
    # toujours un global homonyme (IEC 61131-3), donc toute écriture locale ne pilotait
    # jamais le matériel réel. Le mapping E/S doit désormais cibler le chemin qualifié
    # PRG_06_Outputs_LD.<source_var> (ex. TranslationBrakeCmd, M1RelayFwd — VAR locales
    # déclarées ci-dessous), jamais un nom nu dq_var.

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
        ("M3_DriveControlWord", "WORD"),
        ("M3_DriveFreqRefWord", "WORD"),
        ("KoboldContactorCmd", "BOOL"),
        ("PowerCutOffReq", "BOOL"),
        ("PowerKeepAliveACmd", "BOOL"),
        ("PowerKeepAliveBCmd", "BOOL"),
        ("EmergencyArmingCmd", "BOOL"),
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

    out_path = "TOOLS/SAMPLES_CODESYS/PRG_06_Outputs_LD_full.xml"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(xml_str)
    print(f"Écrit: {out_path}")


if __name__ == "__main__":
    main()
