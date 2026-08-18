(* ═══════════════════════════════════════════════════════════════
   🎛️ GVL_IHM — Variables globales d'échange pour l'IHM
   ───────────────────────────────────────────────────────────────
   📄 Lot A : Mise en service et calibration de la machine de dragage.
   💾 Déclaré en RETAIN pour la persistance des configurations opérateur.
   ═══════════════════════════════════════════════════════════════ *)
VAR_GLOBAL RETAIN
    M1TreuilRetenue : ST_WinchHMI;  (* 🛗 Variables d'échange IHM Treuil Retenue (M1) *)
    M2TreuilBenne : ST_WinchBenneHMI;  (* 🛞️ Variables d'échange IHM Treuil Benne (M2) — type dédié avec Bucket (2026-08) *)
    M1M2Sync : ST_SyncHMI;  (* ⚖️ Variables d'échange IHM Surveillance de synchro *)
    JOY1Joystick : ST_JoystickHMI; (* 🕹️ Variables d'échange IHM Joystick (noeud CANopen JOY1) *)
    Modes   : ST_ModesHMI;  (* 🎚️ Variables d'échange IHM Modes de marche *)
    TranslationM3 : ST_TranslationHMI;(* ↔️ Variables d'échange IHM Translation M3 *)
    Cycle   : ST_CycleHMI;    (* 🔄 Commandes, états et diagnostic cycle semi-automatique *)
    DredgingAssist : ST_DredgingAssistHMI; (* 🪨 Assistance plongée/extraction MAINT_N1/N2 *)
    Banner  : ST_HmiBanner; (* 🖥️ Bandeau d'information et messages opérateur à 4 champs (AF-07 §4) *)
    OperatorAction : ST_OperatorAction; (* 🎮 Unique consigne conduite, arbitré en supervision *)
    Network : ST_NetworkDiagHMI;(* 📡 Variables d'échange IHM Diagnostics réseau *)
    Commun  : ST_CommunHMI; (* 🌐 Signaux communs, pas propres à un axe (TopPositionSensorActive, BrakeThermalFault, LimitLegal) *)
    // IHM_MANU (ST_IHM_MANU) supprimé définitivement — dispositif dérogatoire de mise en service
    // urgence, remplacé par MAINT_N1/MAINT_N2 + joystick homme-mort.
    // Historique complet : ARCHIVES/Doc/IHM_MANU_Journal_Modifications.md.
    HmiInitDone : BOOL;               (* 🚩 Indicateur d'initialisation IHM depuis PERSISTENT *)
END_VAR

(* ═══════════════════════════════════════════════════════════════
   📝 NOTE — l'ancienne procédure de test sur banc (60 lignes) est RETIRÉE d'ici. Elle décrivait
   un dispositif qui n'existe plus après le débranchement de la simulation (lots L2→L4d) :
   `instSimJoystick`, `instSimEncoderM1/M2`, `SimulationModeActive` par défaut TRUE, flags
   `*IsReal`, forçage du capteur haut. Laisser une procédure périmée dans le code est plus
   dangereux que pas de procédure.

   👉 Simulation en cours de refonte (frontière unique `HwIn`, lots L5→L8) :
      voir ARCHIVES/Doc/AUDITS/PreLivraison/PLAN_Rationalisation_Simulation_v1.0.md
   👉 Procédure de banc à jour : sera republiée dans AF_Partie-13 v2.0 (lot L8).
   ═══════════════════════════════════════════════════════════════ *)

