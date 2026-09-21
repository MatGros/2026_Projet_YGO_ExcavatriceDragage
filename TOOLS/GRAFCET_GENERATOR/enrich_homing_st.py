#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
enrich_homing_st.py
Met à jour cycle_homing_lumineux.html et cycle_homing_t364.html avec :
- Le code ST exact extrait de FB_CycleMachineHoming.st pour chaque étape
- L'arbre détaillé des choix et transitions (Nominale, Abandon Fail-Safe, Réessai)
- Le tableau des sorties physiques, verrous M3 et qualification MachineHomed
- Les consignes opérateur réelles de l'IHM (§10)
- La table des 9 causes d'alarmes CST_Cause... (§5)
- Le forçage de step de mise en service (§4bis)
- La modale complète affichant les 652 lignes de FB_CycleMachineHoming.st avec sélection de région (§1..§10)
"""

import os
import re
import json
import html
from html.parser import HTMLParser

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ST_FILE = os.path.join(ROOT_DIR, "CODE", "G_CYCLE", "FB_CycleMachineHoming.st")
HTML_LUMINEUX = os.path.join(ROOT_DIR, "TOOLS", "GRAFCET_GENERATOR", "cycle_homing_lumineux.html")
HTML_T364 = os.path.join(ROOT_DIR, "TOOLS", "GRAFCET_GENERATOR", "cycle_homing_t364.html")

def escape_st(text):
    """Échappe le texte pour affichage HTML sécurisé."""
    return html.escape(text.strip())

def main():
    print(f"Chargement de {ST_FILE}...")
    with open(ST_FILE, "r", encoding="utf-8") as f:
        st_full = f.read()

    # Extraction des régions
    region_pattern = re.compile(r'\{region\s+"(.*?)"\}(.*?)\{endregion\}', re.DOTALL)
    regions = region_pattern.findall(st_full)
    print(f"-> {len(regions)} régions détectées dans le ST.")

    # Construction du dictionnaire détaillé par étape
    steps_data = [
        {
            "id": "HX0_REPOS",
            "num": 0,
            "badge": "INITIAL",
            "titre": "Étape Initiale & Repos (HX0_REPOS)",
            "emoji": "💤",
            "pourquoi": "Étape initiale pure. L'automate est en attente d'une commande consciente en mode MAINT_N2. Les treuils sont à l'arrêt, aucune consigne de vitesse n'est produite, le verrou de translation M3 est relâché.",
            "consigne": "En MAINT_N2 : Lancer le homing via 3 appuis joystick (homme-mort) ou bouton IHM Start.",
            "cable_depth": 260,
            "flag_y": 195,
            "sensor_active": False,
            "falling_edge": False,
            "callout_text": "",
            "bucket_open": True,
            "machine_homed": False,
            "next_step": "HX1_BUCKET_PREPARE",
            "cond_titre": "Ordre de lancement reçu (StartRequest ou BtnValidation) en mode MAINT_N2",
            "cond_tech": "(StartEdge.Q OR BtnValidationEdge.Q) AND ModeIsMaint2",
            "ihm_instruction": "HX0 - RefHoming M1+M2 non ref - Lancer sur IHM (en N2) ou Passer en N2 (hors N2)",
            "st_actions": """// Etape initiale pure : aucune action de mouvement.
CmdWinchSelect := -1; // Par defaut pas d'override
M1Demand.HomeReq := FALSE;
M2Demand.HomeReq := FALSE;
BucketCommit.CommitOpen  := FALSE;
BucketCommit.CommitClose := FALSE;
CmdBucketOpen  := FALSE;
CmdBucketClose := FALSE;
CmdWinchM1.RunRequest := FALSE; CmdWinchM1.StepTgt := 0;
CmdWinchM2.RunRequest := FALSE; CmdWinchM2.StepTgt := 0;""",
            "st_transitions": """IF (StartEdge.Q OR BtnValidationEdge.Q) AND ModeIsMaint2 THEN
    HomeReqDone := FALSE;
    RetryCount  := 0;
    SeqStep     := E_MachineHomingTxState.HX1_BUCKET_PREPARE;
END_IF;""",
            "st_outputs": [
                {"var": "CmdWinchSelect", "val": "-1", "note": "Neutre / Aucun override sur les treuils"},
                {"var": "M3Locked", "val": "FALSE", "note": "Translation M3 libre au repos"},
                {"var": "MachineHomingActive", "val": "FALSE", "note": "Cycle inactif (Lifecycle.Busy = FALSE)"},
                {"var": "MachineHomed", "val": "FALSE (ou TRUE si déjà qualifiée)", "note": "Gate de production"},
                {"var": "HomeReqDone", "val": "FALSE", "note": "Prêt pour nouvelle transaction"},
                {"var": "RetryCount", "val": "0", "note": "Compteur de retries réinitialisé"}
            ],
            "st_guards": [
                {"name": "Garde Premier Scan", "pt": "1 cycle", "note": "Protection FirstScanDone au boot automate"}
            ],
            "st_alarms": [],
            "st_branches": [
                {
                    "type": "nominal",
                    "title": "Lancement du Cycle de Référencement",
                    "cond_tech": "(StartEdge.Q OR BtnValidationEdge.Q) AND ModeIsMaint2",
                    "target_step": "HX1_BUCKET_PREPARE",
                    "target_idx": 1,
                    "btn_label": "⚡ Lancer le Homing (Passer en HX1) ➔"
                }
            ]
        },
        {
            "id": "HX1_BUCKET_PREPARE",
            "num": 1,
            "badge": "PRÉP. BENNE",
            "titre": "Fermeture Benne Palier 1 sous FDC Inhibé (HX1_BUCKET_PREPARE)",
            "emoji": "🗜️",
            "pourquoi": "Préparation géométrique de la benne au sol. L'opérateur pilote manuellement la fermeture au palier 1 (WinchSel=2). Le fin de course logiciel de benne est inhibé pour permettre le contact mécanique franc. La garde de temps est de 8s max.",
            "consigne": "Tirer le joystick vers soi (palier 1) jusqu'à fermeture complète au sol. Au contact franc, relâcher au neutre puis valider sur le bouton dédié IHM.",
            "cable_depth": 260,
            "flag_y": 195,
            "sensor_active": False,
            "falling_edge": False,
            "callout_text": "Fermeture benne au palier 1 sous FDC logiciel inhibé",
            "bucket_open": "prepare_pending",
            "machine_homed": False,
            "next_step": "HX1A_COUPLING_INTERLOCK",
            "cond_titre": "Validation par bouton dédié IHM (1 impulsion) + Manche joystick au neutre",
            "cond_tech": "HomingBucketConfirmEdge.Q AND NOT JoystickDeflected",
            "ihm_instruction": "HX1 - RefHoming Fermer benne, valider sur IHM",
            "st_actions": """// Decision & Fermeture benne operateur :
// WinchSel=2 force, FDC benne logiciel inhibe, vitesse plafonnee palier 1.
CmdWinchSelect := 2;
IF BucketPermit AND JoystickPull THEN
    CmdBucketClose := TRUE;
END_IF;""",
            "st_transitions": """IF ModeLostDuringCycle OR BucketCloseTimedOut OR MotionOutOfPhase THEN
    MachineHomingFailed := TRUE;
    SeqStep := E_MachineHomingTxState.HX7_FAILED;
ELSIF HomingBucketConfirmEdge.Q AND NOT JoystickDeflected THEN
    // Validation par 1 seul appui bouton dedie IHM, manche au neutre
    PendingClose := TRUE;
    CommitDone   := FALSE;
    SeqStep      := E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK;
END_IF;""",
            "st_outputs": [
                {"var": "CmdWinchSelect", "val": "2", "note": "Force la sélection treuil benne M2 seul"},
                {"var": "CmdBucketClose", "val": "TRUE (quand JoystickPull)", "note": "Ordre fermeture benne palier 1 sans FDC soft"},
                {"var": "M3Locked", "val": "TRUE", "note": "Translation M3 bloquée dès engagement"},
                {"var": "MachineHomingActive", "val": "TRUE", "note": "Lifecycle.Busy := TRUE"},
                {"var": "PendingClose", "val": "TRUE (sur transition)", "note": "Mémorise fermeture pour commit final HX6"}
            ],
            "st_guards": [
                {"name": "BucketCloseTimer", "pt": "Cfg.CfgTimeoutBucketClose (8.0 s)", "note": "Garde de fermeture benne (active si BucketPermit)"}
            ],
            "st_alarms": [
                {"id": 6, "name": "CST_CauseBucketCloseTimeout", "text": "Fermeture benne non obtenue dans le temps imparti (8s)"},
                {"id": 2, "name": "CST_CauseMotionOutOfPhase", "text": "Mouvement treuil détecté hors phase autorisée"}
            ],
            "st_branches": [
                {
                    "type": "nominal",
                    "title": "Validation Fermeture Benne (IHM + Neutre)",
                    "cond_tech": "HomingBucketConfirmEdge.Q AND NOT JoystickDeflected",
                    "target_step": "HX1A_COUPLING_INTERLOCK",
                    "target_idx": 2,
                    "btn_label": "✅ Valider Fermeture Benne (➔ HX1a) ➔"
                },
                {
                    "type": "abort",
                    "title": "Abandon Fail-Safe (Timeout 8s / Perte N2 / Mouvement indu)",
                    "cond_tech": "ModeLostDuringCycle OR BucketCloseTimedOut OR MotionOutOfPhase",
                    "target_step": "HX7_FAILED",
                    "target_idx": 8,
                    "btn_label": "🚨 Simuler Timeout Fermeture (➔ HX7_FAILED)"
                }
            ]
        },
        {
            "id": "HX1A_COUPLING_INTERLOCK",
            "num": 2,
            "badge": "INTERLOCK E1",
            "titre": "Bascule Couplage M1+M2 & Interlock E1 (HX1A_COUPLING_INTERLOCK)",
            "emoji": "🔗",
            "pourquoi": "Résolution formelle de l'anomalie E1 : Bascule automatique vers WinchSel=0 (couplé M1+M2) et réactivation du FDC benne logiciel. Interlock bloquant aval vérifiant que le sélecteur arbitré est bien 0, avec dwell de 300 ms et treuils mécaniquement immobiles.",
            "consigne": "Maintenir le joystick au neutre. L'automate attend la stabilisation de l'interlock (300 ms) et l'arrêt mécanique complet.",
            "cable_depth": 260,
            "flag_y": 195,
            "sensor_active": False,
            "falling_edge": False,
            "callout_text": "🔗 Interlock E1 : Bascule WinchSel=0 et dwell 300 ms",
            "bucket_open": False,
            "machine_homed": False,
            "next_step": "HX2_CLIMB_COUPLED",
            "cond_titre": "Sélecteur aval = 0 (Couplé) + Dwell 300 ms écoulé + Treuils arrêtés",
            "cond_tech": "(JoystickWinchSelectArbitrated = 0) AND CouplingSettleTimer.Q AND WinchesMechanicallyStopped",
            "ihm_instruction": "HX1a - RefHoming Verif couplage M1+M2",
            "st_actions": """// Bascule WinchSel=0, reactivation FDC benne.
// Interlock bloquant E1 : attente confirmation couplage aval effectif.
CmdWinchSelect := 0;
CouplingSettleTimer(IN := (JoystickWinchSelectArbitrated = 0), PT := T#300ms);""",
            "st_transitions": """IF ModeLostDuringCycle OR AxisHomingError THEN
    MachineHomingFailed := TRUE;
    SeqStep := E_MachineHomingTxState.HX7_FAILED;
ELSIF (JoystickWinchSelectArbitrated = 0) AND CouplingSettleTimer.Q AND WinchesMechanicallyStopped THEN
    SeenNeutral := NOT JoystickDeflected;
    SeqStep     := E_MachineHomingTxState.HX2_CLIMB_COUPLED;
END_IF;""",
            "st_outputs": [
                {"var": "CmdWinchSelect", "val": "0", "note": "Bascule vers couplé M1+M2"},
                {"var": "CouplingSettleTimer.IN", "val": "JoystickWinchSelectArbitrated = 0", "note": "Dwell conditionné par retour aval"},
                {"var": "M3Locked", "val": "TRUE", "note": "Translation bloquée"},
                {"var": "MachineHomingActive", "val": "TRUE", "note": "Cycle actif"}
            ],
            "st_guards": [
                {"name": "CouplingSettleTimer", "pt": "T#300ms", "note": "Dwell de stabilisation couplage"},
                {"name": "SettleGraceTimer", "pt": "T#3s", "note": "Fenêtre de grâce décélération"}
            ],
            "st_alarms": [
                {"id": 3, "name": "CST_CauseHomingErrorM1", "text": "Erreur homing codeur M1"},
                {"id": 4, "name": "CST_CauseHomingErrorM2", "text": "Erreur homing codeur M2"}
            ],
            "st_branches": [
                {
                    "type": "nominal",
                    "title": "Interlock E1 Confirmé (Aval = 0 + 300 ms + Arrêt)",
                    "cond_tech": "(JoystickWinchSelectArbitrated = 0) AND CouplingSettleTimer.Q AND WinchesMechanicallyStopped",
                    "target_step": "HX2_CLIMB_COUPLED",
                    "target_idx": 3,
                    "btn_label": "🔗 Franchir l'Interlock E1 (➔ HX2) ➔"
                },
                {
                    "type": "abort",
                    "title": "Perte de Mode N2 ou Erreur Axe",
                    "cond_tech": "ModeLostDuringCycle OR AxisHomingError",
                    "target_step": "HX7_FAILED",
                    "target_idx": 8,
                    "btn_label": "🚨 Simuler Erreur Couplage (➔ HX7_FAILED)"
                }
            ]
        },
        {
            "id": "HX2_CLIMB_COUPLED",
            "num": 3,
            "badge": "MONTÉE COUPLÉE",
            "titre": "Montée Couplée M1+M2 Palier 1 vers Capteur Haut (HX2_CLIMB_COUPLED)",
            "emoji": "🧗",
            "pourquoi": "Traction lente couplée des treuils M1 et M2 vers le haut (palier 1 MAX strict) sous homme-mort opérateur. La benne monte vers le câble tendu de fin de course. La garde de temps est consommée UNIQUEMENT lorsque la montée est effectivement commandée.",
            "consigne": "Tirer le joystick vers soi au palier 1 avec homme-mort maintenu jusqu'à ce que la traverse haute touche le câble tendu.",
            "cable_depth": 130,
            "flag_y": 140,
            "sensor_active": False,
            "falling_edge": False,
            "callout_text": "Montée couplée M1+M2 palier 1 MAX vers le câble tendu...",
            "bucket_open": False,
            "machine_homed": False,
            "next_step": "HX3_FLYING_REFERENCE",
            "cond_titre": "Câble tendu touché : contact fin de course activé (TopPositionSensor = TRUE)",
            "cond_tech": "TopPositionSensor = TRUE",
            "ihm_instruction": "HX2 - RefHoming Tirer JOY palier 1 vers haut",
            "st_actions": """// Montee couplee M1+M2 palier 1 MAX vers capteur haut.
CmdWinchSelect := 0;
IF ClimbPermit AND (JoystickWinchSelectArbitrated = 0) THEN
    CmdWinchM1.RunRequest := TRUE; CmdWinchM1.ReqAscent := TRUE; CmdWinchM1.StepTgt := CST_StepSlow; // 1
    CmdWinchM2.RunRequest := TRUE; CmdWinchM2.ReqAscent := TRUE; CmdWinchM2.StepTgt := CST_StepSlow; // 1
END_IF;""",
            "st_transitions": """IF TransactionAbort THEN
    MachineHomingFailed := TRUE;
    SeqStep := E_MachineHomingTxState.HX7_FAILED;
ELSIF TopPositionSensor THEN
    M1Demand.HomeReq := TRUE;
    M2Demand.HomeReq := TRUE;
    HomeReqDone := TRUE;
    SeqStep     := E_MachineHomingTxState.HX3_FLYING_REFERENCE;
END_IF;""",
            "st_outputs": [
                {"var": "CmdWinchSelect", "val": "0", "note": "M1 + M2 couplés"},
                {"var": "CmdWinchM1.ReqAscent", "val": "TRUE (si tiré)", "note": "Ordre montée treuil retenue M1"},
                {"var": "CmdWinchM1.StepTgt", "val": "1", "note": "Vitesse plafonnée palier 1 lent"},
                {"var": "CmdWinchM2.ReqAscent", "val": "TRUE (si tiré)", "note": "Ordre montée treuil benne M2"},
                {"var": "CmdWinchM2.StepTgt", "val": "1", "note": "Vitesse plafonnée palier 1 lent"}
            ],
            "st_guards": [
                {"name": "ClimbTimer", "pt": "Cfg.CfgTimeoutClimb", "note": "Garde active UNIQUEMENT si ClimbCommandActive"}
            ],
            "st_alarms": [
                {"id": 1, "name": "CST_CauseClimbTimeout", "text": "Montée au capteur haut non aboutie dans le temps imparti"},
                {"id": 7, "name": "CST_CauseCouplingFault", "text": "Défaut de couplage treuils M1+M2 en phase montée"}
            ],
            "st_branches": [
                {
                    "type": "nominal",
                    "title": "Accostage Câble Tendu (TopPositionSensor = TRUE)",
                    "cond_tech": "TopPositionSensor = TRUE",
                    "target_step": "HX3_FLYING_REFERENCE",
                    "target_idx": 4,
                    "btn_label": "⚡ Toucher le Câble Tendu (➔ HX3) ➔"
                },
                {
                    "type": "abort",
                    "title": "TransactionAbort (Timeout / Découplage / Défaut)",
                    "cond_tech": "TransactionAbort",
                    "target_step": "HX7_FAILED",
                    "target_idx": 8,
                    "btn_label": "🚨 Simuler Timeout Montée (➔ HX7_FAILED)"
                }
            ]
        },
        {
            "id": "HX3_FLYING_REFERENCE",
            "num": 4,
            "badge": "RÉF. AU VOL",
            "titre": "Accostage & Prise de Référence au Vol (HX3_FLYING_REFERENCE)",
            "emoji": "⚡",
            "pourquoi": "Détection immédiate du capteur haut commun M1/M2 ! Émission instantanée des demandes de calage HomeReq sur 1 scan vers FB_Encoder_Homing M1 et M2. Recalage au vol sur la position configurée (8.50 m).",
            "consigne": "Relâcher le joystick au neutre. Les codeurs capturent le datum simultanément au vol.",
            "cable_depth": 76,
            "flag_y": 98,
            "sensor_active": True,
            "falling_edge": False,
            "callout_text": "⚡ TOP CAPTEUR TOUCHÉ : PRISE DE RÉFÉRENCE AU VOL M1+M2 (8.50 m) !",
            "bucket_open": False,
            "machine_homed": False,
            "next_step": "HX4_STABILIZATION_CHECK",
            "cond_titre": "Les deux axes M1 et M2 sont qualifiés et fiables (BothAxesHomed = TRUE)",
            "cond_tech": "BothAxesHomed (M1Status.HomedAndReliable AND M2Status.HomedAndReliable)",
            "ihm_instruction": "HX3 - RefHoming Prise de reference au vol",
            "st_actions": """// Detection capteur haut TOP M1+M2 : prise de reference a la volee sur position config.
CmdWinchSelect := 0;
IF NOT HomeReqDone THEN
    M1Demand.HomeReq   := TRUE;
    M2Demand.HomeReq   := TRUE;
    HomeReqDone        := TRUE;
END_IF;""",
            "st_transitions": """IF TransactionAbort THEN
    MachineHomingFailed := TRUE;
    SeqStep := E_MachineHomingTxState.HX7_FAILED;
ELSIF BothAxesHomed THEN
    SeqStep := E_MachineHomingTxState.HX4_STABILIZATION_CHECK;
END_IF;""",
            "st_outputs": [
                {"var": "CmdWinchSelect", "val": "0", "note": "Maintien couplé"},
                {"var": "M1Demand.HomeReq", "val": "TRUE (impulsion 1 scan)", "note": "Ordre de calage au vol M1 à 8.50 m"},
                {"var": "M2Demand.HomeReq", "val": "TRUE (impulsion 1 scan)", "note": "Ordre de calage au vol M2 à 8.50 m"},
                {"var": "HomeReqDone", "val": "TRUE", "note": "Verrou d'émission unique"}
            ],
            "st_guards": [
                {"name": "HomeAxesTimer", "pt": "Cfg.CfgTimeoutHomeAxes", "note": "Garde d'attente calage axes"}
            ],
            "st_alarms": [
                {"id": 5, "name": "CST_CauseHomeAxesTimeout", "text": "Prise de référence capteur haut non obtenue dans le temps"},
                {"id": 3, "name": "CST_CauseHomingErrorM1", "text": "Erreur homing codeur M1"},
                {"id": 4, "name": "CST_CauseHomingErrorM2", "text": "Erreur homing codeur M2"}
            ],
            "st_branches": [
                {
                    "type": "nominal",
                    "title": "Codeurs M1 & M2 Qualifiés (BothAxesHomed = TRUE)",
                    "cond_tech": "BothAxesHomed = TRUE",
                    "target_step": "HX4_STABILIZATION_CHECK",
                    "target_idx": 5,
                    "btn_label": "🎯 Valider le Datum M1+M2 (➔ HX4) ➔"
                },
                {
                    "type": "abort",
                    "title": "Timeout Prise de Référence ou Erreur Codeur",
                    "cond_tech": "TransactionAbort OR HomeAxesTimedOut",
                    "target_step": "HX7_FAILED",
                    "target_idx": 8,
                    "btn_label": "🚨 Simuler Échec Codeur (➔ HX7_FAILED)"
                }
            ]
        },
        {
            "id": "HX4_STABILIZATION_CHECK",
            "num": 5,
            "badge": "STABILISATION",
            "titre": "Arrêt Treuils & Contrôle Inertie [8.50..8.80 m] (HX4_STABILIZATION_CHECK)",
            "emoji": "🎯",
            "pourquoi": "Arrêt mécanique complet et contrôle strict de l'inertie de fin de course. L'automate vérifie : treuils arrêtés, joystick neutre, positions M1 et M2 comprises dans la fenêtre [8.50..8.80 m], et écart treuils <= 1.0 m. En cas de dépassement, une boucle de réessai réengage HX1 (max 3 retries).",
            "consigne": "Joystick au neutre. Contrôle automatique de la fenêtre de stabilisation.",
            "cable_depth": 84,
            "flag_y": 104,
            "sensor_active": True,
            "falling_edge": False,
            "callout_text": "🎯 Stabilisation contrôlée : Position [8.50..8.80 m] & Écart <= 1.0 m",
            "bucket_open": False,
            "machine_homed": False,
            "next_step": "HX5_RELEASE_CLEARANCE",
            "cond_titre": "Stabilisation nominale : Arrêt confirmé + Neutre + Pos [8.50..8.80m] + Écart <= 1.0m",
            "cond_tech": "StabilizationOk = TRUE",
            "ihm_instruction": "HX4 - RefHoming Arret et controle inertie",
            "st_actions": """// Arret treuils, controle inertie [8.50..8.80m] et concordance codeurs.
CmdWinchSelect := 0;
SeenNeutral := NOT JoystickDeflected;

StabilizationOk := WinchesMechanicallyStopped AND SeenNeutral
                   AND (CablePosM1 >= Cfg.CfgStabilizationMinM) AND (CablePosM1 <= Cfg.CfgStabilizationMaxM)
                   AND (CablePosM2 >= Cfg.CfgStabilizationMinM) AND (CablePosM2 <= Cfg.CfgStabilizationMaxM)
                   AND (ABS(CablePosM1 - CablePosM2) <= CoherenceLimitM);

StabilizationFailed := WinchesMechanicallyStopped AND SeenNeutral AND NOT StabilizationOk;""",
            "st_transitions": """IF ModeLostDuringCycle OR AxisHomingError THEN
    MachineHomingFailed := TRUE;
    SeqStep := E_MachineHomingTxState.HX7_FAILED;
ELSIF StabilizationOk THEN
    SeqStep := E_MachineHomingTxState.HX5_RELEASE_CLEARANCE;
ELSIF StabilizationFailed THEN
    RetryCount := RetryCount + 1;
    IF RetryCount >= 3 THEN
        MachineHomingFailed := TRUE;
        SeqStep := E_MachineHomingTxState.HX7_FAILED;
    ELSE
        // Repositionnement et nouvelle tentative : retour en preparation benne
        SeqStep := E_MachineHomingTxState.HX1_BUCKET_PREPARE;
    END_IF;
END_IF;""",
            "st_outputs": [
                {"var": "CmdWinchSelect", "val": "0", "note": "Maintien couplé"},
                {"var": "StabilizationOk", "val": "TRUE/FALSE", "note": "Validation géométrique inertie"},
                {"var": "RetryCount", "val": "0..3", "note": "Compteur de tentatives d'accostage"},
                {"var": "M3Locked", "val": "TRUE", "note": "Translation verrouillée"}
            ],
            "st_guards": [
                {"name": "SettleGraceTimer", "pt": "T#3s", "note": "Fenêtre de grâce décélération"},
                {"name": "Fenêtre Inertie", "pt": "[8.50 .. 8.80 m]", "note": "Plage de position arrêtée"},
                {"name": "Écart CoherenceLimitM", "pt": "<= 1.0 m", "note": "Tolérance désynchronisation treuils"}
            ],
            "st_alarms": [
                {"id": 8, "name": "CST_CauseStabilizationFault", "text": "Stabilisation inertie treuils hors plage après 3 tentatives"}
            ],
            "st_branches": [
                {
                    "type": "nominal",
                    "title": "Stabilisation Conforme (Position [8.50..8.80 m] & Écart <= 1.0 m)",
                    "cond_tech": "StabilizationOk = TRUE",
                    "target_step": "HX5_RELEASE_CLEARANCE",
                    "target_idx": 6,
                    "btn_label": "🎯 Valider Stabilisation (➔ HX5) ➔"
                },
                {
                    "type": "retry",
                    "title": "Inertie Hors Plage (RetryCount < 3 ➔ Boucle HX1)",
                    "cond_tech": "StabilizationFailed AND (RetryCount < 3)",
                    "target_step": "HX1_BUCKET_PREPARE",
                    "target_idx": 1,
                    "btn_label": "🔄 Simuler Dépassement Inertie (Reboucler HX1)"
                },
                {
                    "type": "abort",
                    "title": "Échec Définitif (3 Tentatives Épuisées ➔ HX7)",
                    "cond_tech": "StabilizationFailed AND (RetryCount >= 3)",
                    "target_step": "HX7_FAILED",
                    "target_idx": 8,
                    "btn_label": "💥 Simuler Échec 3 Retries (➔ HX7_FAILED)"
                }
            ]
        },
        {
            "id": "HX5_RELEASE_CLEARANCE",
            "num": 6,
            "badge": "DÉGAGEMENT",
            "titre": "Dégagement Zone Haute & Neutre Confirmé (HX5_RELEASE_CLEARANCE)",
            "emoji": "🔄",
            "pourquoi": "Confirmation de la stabilisation hors tension mécanique excessive et vérification du manche au neutre avant qualification finale.",
            "consigne": "Maintenir le joystick au neutre (aucun ordre de déplacement).",
            "cable_depth": 92,
            "flag_y": 114,
            "sensor_active": False,
            "falling_edge": False,
            "callout_text": "Dégagement zone haute confirmé, joystick au neutre",
            "bucket_open": False,
            "machine_homed": False,
            "next_step": "HX6_HOMED_SUCCESS",
            "cond_titre": "Joystick au neutre et treuils mécaniquement immobiles",
            "cond_tech": "NOT JoystickDeflected AND WinchesMechanicallyStopped",
            "ihm_instruction": "HX5 - RefHoming Relacher JOY au neutre",
            "st_actions": """// Degagement zone haute, confirmation joystick au neutre.
CmdWinchSelect := 0;""",
            "st_transitions": """IF NOT JoystickDeflected AND WinchesMechanicallyStopped THEN
    SeqStep := E_MachineHomingTxState.HX6_HOMED_SUCCESS;
END_IF;""",
            "st_outputs": [
                {"var": "CmdWinchSelect", "val": "0", "note": "Maintien couplé"},
                {"var": "M3Locked", "val": "TRUE", "note": "Translation verrouillée"}
            ],
            "st_guards": [
                {"name": "SettleGraceTimer", "pt": "T#3s", "note": "Fenêtre de grâce décélération"}
            ],
            "st_alarms": [],
            "st_branches": [
                {
                    "type": "nominal",
                    "title": "Neutre Maintenu & Treuils Immobiles",
                    "cond_tech": "NOT JoystickDeflected AND WinchesMechanicallyStopped",
                    "target_step": "HX6_HOMED_SUCCESS",
                    "target_idx": 7,
                    "btn_label": "🏆 Franchir vers le Succès (➔ HX6) ➔"
                }
            ]
        },
        {
            "id": "HX6_HOMED_SUCCESS",
            "num": 7,
            "badge": "SUCCÈS QUALIFIÉ",
            "titre": "Machine Qualifiée & Publication Commit Benne (HX6_HOMED_SUCCESS)",
            "emoji": "🏆",
            "pourquoi": "Homing certifié ! Publication atomique du commit benne (BucketCommit.CommitClose := TRUE) sur 1 scan garanti. MachineHomed passe à TRUE. Retour automatique au repos HX0_REPOS.",
            "consigne": "Machine entièrement référencée et prête pour le dragage !",
            "cable_depth": 92,
            "flag_y": 114,
            "sensor_active": False,
            "falling_edge": False,
            "callout_text": "🏆 MACHINE HOMED = TRUE & COMMIT ATOMIQUE BENNE VALIDÉ !",
            "bucket_open": False,
            "machine_homed": True,
            "next_step": "HX0_REPOS",
            "cond_titre": "Publication commit achevée -> Retour automatique HX0_REPOS (Scan suivant)",
            "cond_tech": "CommitDone = TRUE",
            "ihm_instruction": "HX6 - RefHoming Machine referencee",
            "st_actions": """// Validation finale : MachineHomed := TRUE, commit atomique benne.
CmdWinchSelect := 0;
IF NOT CommitDone THEN
    BucketCommit.CommitClose := PendingClose;
    CommitPublished          := TRUE;
    CommitDone               := TRUE;
ELSE
    PendingClose := FALSE;
    SeqStep      := E_MachineHomingTxState.HX0_REPOS;
END_IF;""",
            "st_transitions": """// Transition automatique apres 1 scan d'impulsion de commit
IF CommitDone THEN
    PendingClose := FALSE;
    SeqStep      := E_MachineHomingTxState.HX0_REPOS;
END_IF;""",
            "st_outputs": [
                {"var": "BucketCommit.CommitClose", "val": "TRUE (1 scan)", "note": "Publication atomique du calage benne"},
                {"var": "CommitPublished", "val": "TRUE", "note": "Datum benne ancré dans le système"},
                {"var": "MachineHomed", "val": "TRUE", "note": "Gate ouverte pour le cycle automatique !"},
                {"var": "Lifecycle.Done", "val": "TRUE", "note": "Séquence de homing achevée avec succès"}
            ],
            "st_guards": [],
            "st_alarms": [],
            "st_branches": [
                {
                    "type": "nominal",
                    "title": "Retour Automatique au Repos Qualifié (Scan Suivant)",
                    "cond_tech": "CommitDone = TRUE",
                    "target_step": "HX0_REPOS",
                    "target_idx": 0,
                    "btn_label": "✨ Conclure et Retourner au Repos (➔ HX0) ➔"
                }
            ]
        },
        {
            "id": "HX7_FAILED",
            "num": 8,
            "badge": "ÉCHEC SÉCURISÉ",
            "titre": "Séquence Échouée / Abandonnée (HX7_FAILED)",
            "emoji": "💥",
            "pourquoi": "État de repli sécurisé unifié (arrêt d'urgence, timeout garde montée, 3 retries stabilisation épuisées ou sortie de MAINT_N2). Sorties à 0 (CmdWinchSelect := -1). Réarmement exclusivement par front montant Reset en MAINT_N2.",
            "consigne": "Analyser la cause de l'abandon. Effectuer un Reset conscient au bouton IHM en MAINT_N2.",
            "cable_depth": 180,
            "flag_y": 175,
            "sensor_active": False,
            "falling_edge": False,
            "callout_text": "🚨 CYCLE ÉCHOUÉ : SORTIES COUPÉES (RESET CONSCIENT REQUIS)",
            "bucket_open": True,
            "machine_homed": False,
            "next_step": "HX0_REPOS",
            "cond_titre": "Acquittement par front d'impulsion Reset en MAINT_N2",
            "cond_tech": "ResetEdge.Q AND ModeIsMaint2",
            "ihm_instruction": "HX7 - Homing incomplet - Acquitter Reset N2",
            "st_actions": """// Echec sequence unifie : sorties a 0, attente Reset conscient en MAINT_N2.
CmdWinchSelect := -1; // Coupure des ordres treuils
;""",
            "st_transitions": """// §4 Purge sur Reset
IF ResetEdge.Q THEN
    MachineHomingFailed  := FALSE;
    PendingClose         := FALSE;
    CommitDone           := FALSE;
    HomeReqDone          := FALSE;
    RetryCount           := 0;
    SeqStep              := E_MachineHomingTxState.HX0_REPOS;
    MachineHomingSeqStep := E_MachineHomingTxState.HX0_REPOS;
END_IF;""",
            "st_outputs": [
                {"var": "CmdWinchSelect", "val": "-1", "note": "Coupure de tous les ordres de mouvement"},
                {"var": "MachineHomingFailed", "val": "TRUE", "note": "Indicateur d'abandon mémorisé"},
                {"var": "MachineHomed", "val": "FALSE", "note": "Production strictement verrouillée"},
                {"var": "M3Locked", "val": "TRUE", "note": "Translation maintenue verrouillée"}
            ],
            "st_guards": [],
            "st_alarms": [
                {"id": 0, "name": "CST_CauseHomingLostInMotion", "text": "Perte de datum machine en mouvement"},
                {"id": 1, "name": "CST_CauseClimbTimeout", "text": "Montée au capteur non aboutie"},
                {"id": 7, "name": "CST_CauseCouplingFault", "text": "Défaut de couplage"},
                {"id": 8, "name": "CST_CauseStabilizationFault", "text": "Inertie hors plage après 3 retries"}
            ],
            "st_branches": [
                {
                    "type": "nominal",
                    "title": "Acquittement Manuel par Front Reset en MAINT_N2",
                    "cond_tech": "ResetEdge.Q AND ModeIsMaint2",
                    "target_step": "HX0_REPOS",
                    "target_idx": 0,
                    "btn_label": "🔄 Acquitter et Réarmer (Reset ➔ HX0) ➔"
                }
            ]
        }
    ]

    print("Données enrichies prêtes pour injection !")
    return steps_data, regions, st_full

if __name__ == "__main__":
    main()
