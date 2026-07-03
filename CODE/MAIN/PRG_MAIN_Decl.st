(* ═══════════════════════════════════════════════════════════════
   🧠 PRG_MAIN — Orchestration séquentielle (diag → sécurité → métier)
   ───────────────────────────────────────────────────────────────
   📄 Contient : Joystick (axe Y) → FB_Safety_Winch (M1/M2) → FB_Winch (M1+M2,
      consigne dupliquée sur le même axe) → relais ; pipeline codeur M1/M2
      (FB_Encoder_Abs → Scale → Homing, flux nominal) ; Joystick (axe X) →
      FB_Safety_Chariot → FB_Chariot (M3, mode DEGRADED_IO figé, Partie11).
   📥/📤 I/O réel conditionné via `FB_InputsMachine`/`FB_OutputsMachine` (1
      instance chacun, appelées SANS PARAMÈTRE) ↔ `GVL_IN`/`GVL_OUT`
      (accès direct par tag global — Partie6 §5).
   🎯 HOMING : ordre par treuil Abs → Scale → Homing. `PresetRequest`/
      `PresetValue` et `HomingRefRaw` consommés avec **1 cycle de retard**
      (assumé, sans conséquence — Partie10 §9bis).
   ⚠️ M2 dupliqué sur le MÊME axe Y que M1, SANS `FB_WinchSync` réel (codeur
      pas encore exploité pour une synchro — Partie9 §9).
   🔴 À SUPPRIMER MANUELLEMENT dans CODESYS (orphelins, jamais appelés) :
      `PRG_COD1` (remplacé par les instances ci-dessous, 1 seul POU — Partie2
      §0), `FB_Safety` (sorties jamais consommées).
   🔴 NO-GO ESSAIS RÉELS AVEC MOUVEMENT tant que : (1) diag EtherCAT/CAN réel
      pas activé (`EnableDiagnosis=False` sur tous les devices — procédure
      d'activation CODESYS : AUDIT §16) ; (2) test terrain débranchement
      physique COD1/COD2 pas fait (xError/wState pas garantis fail-safe selon
      version stack) ; (3) CAN joystick en littéraux TRUE (§0 — homme-mort
      aveugle à la perte de liaison).
   🔴 NE COMPILE PAS TANT QUE `CtrlPhaseRotation_DI` N'EXISTE PAS EN I/O MAPPING
      (2026-07-03sexdecies/novodecies, AUDIT D67/D71) : créer ce DI dans CODESYS AVANT de
      coller ce fichier. `GVL_IN.PhaseRotationOk` câblé dans `FB_Safety_Winch`(M1/M2)/
      `FB_Safety_Chariot` (pas directement sur `EmergencyStopOk`, cf D71 — cohérent avec
      le principe « safety centralise les capteurs, le métier consomme SafeStop »). Nom/
      polarité (TRUE=OK) ASSUMÉS sans confirmation utilisateur — à vérifier.
   🔧 CORRECTIF (2026-07-03unvicies, retour terrain, AUDIT D74 — SUPERSEDÉ D75) : blocage
      `SafeStop` diagnostiqué en direct (`GVL_IN.PhaseRotationOk` jamais écrit tant que
      `CtrlPhaseRotation_DI` n'existe pas côté device → démarrait `FALSE`, défaut IEC 61131-3).
      Fix final retenu : `GVL_DEBUG.DBG_CtrlPhaseRotation_Bypass_TEST` (créé par l'utilisateur,
      OR'é sur le signal brut dans `FB_InputsMachine`, même pattern qu'`EmergencyStopOk`/
      `TopPositionSensor`) — pas d'init `:= TRUE` sur `GVL_IN.PhaseRotationOk` (retirée, D75).
   📚 Historique complet des décisions (D1-D75, dont renommage I/O `_DI`/`_DQ`/
      `_RQ`, retours frein réels, `GVL_IN`/`GVL_OUT`) :
      DOC/AUDIT_Coherence_Documentaire_v1.0.md
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU PRG_MAIN) ===

PROGRAM PRG_MAIN
VAR_INPUT
END_VAR
VAR_OUTPUT
END_VAR

VAR_IN_OUT
END_VAR

VAR
    instDiagCanOpen  : FB_DiagCanOpen;       // Diagnostic CAN/Joystick
    instDiagEthercat : FB_DiagEthercat;      // Diagnostic EtherCAT (3 devices)

    // 🧰 FB_INPUTSMACHINE/FB_OUTPUTSMACHINE — conditionnement I/O réel de toute la machine
    // (2026-07-03nonies, scinde l'ancien FB_IO_Machine — 1 instance chacun, APPELÉE UNE
    // SEULE FOIS : entrées tôt (avant Homing/Safety/Winch/Chariot), sorties tard (après
    // FB_Winch/FB_Chariot). Voir en-têtes FB_InputsMachine.st/FB_OutputsMachine.st.
    instInputsMachine  : FB_InputsMachine;
    instOutputsMachine : FB_OutputsMachine;

    // 🕹️ Instance unique du traitement joystick (pipeline calib/filtre/rampe)
    FB_Joystick_0 : FB_Joystick;

    // 🎚️ FB_MODES — arbitrage du mode machine, 1 SEULE instance (remplace E_Mode.MAINT_N1 codé
    // en dur partout). Voir en-tête FB_Modes.st.
    instModes : FB_Modes;
    EncoderFaultPresentM1 : BOOL;   // 📤 instEncoderSafetyM1.EncoderIncoherent (calculé plus bas, 1 cycle de retard)
    EncoderFaultPresentM2 : BOOL;   // 📤 instEncoderSafetyM2.EncoderIncoherent (calculé plus bas, 1 cycle de retard)
    EncoderFaultPresent   : BOOL;   // 📤 OR des deux — entrée instModes (1 cycle de retard, cf en-tête FB_Modes.st)

    // 🧲 CODEUR — acquisition + mise à l'échelle + homing (flux nominal), 1 instance par treuil
    instEncoderAbsM1   : FB_Encoder_Abs;
    instEncoderScaleM1 : FB_Encoder_Scale;
    instHomingM1       : FB_Encoder_Homing;   // ✅ 2026-07-02 — possède Calib (RETAIN) en interne
    instEncoderAbsM2   : FB_Encoder_Abs;
    instEncoderScaleM2 : FB_Encoder_Scale;
    instHomingM2       : FB_Encoder_Homing;

    // 🛡️ FB_ENCODER_SAFETY — bornage ±99m + relais HomingSuspect, 1 instance par treuil (répond
    // à l'incident CablePosM≈4096m). Voir en-tête FB_Encoder_Safety.st.
    instEncoderSafetyM1 : FB_Encoder_Safety;
    instEncoderSafetyM2 : FB_Encoder_Safety;

    // 🔌 SAFETY — bloc safety métier du domaine treuil, 1 instance par treuil
    // (même TYPE FB_Safety_Winch, 2 instances — Partie10 §7)
    instSafetyWinchM1 : FB_Safety_Winch;
    instSafetyWinchM2 : FB_Safety_Winch;

    // ⚖️ FB_WINCHSYNC — surveillance écart M1/M2, 1 SEULE instance (squelette de liaisons,
    // pas de correction — voir en-tête FB_WinchSync.st et Partie9 §9).
    instWinchSync : FB_WinchSync;

    // 🪝 WINCH — M1 et M2 (consigne dupliquée sur l'axe Y, Maintenance N1, choix 2026-07-02)
    instWinchM1 : FB_Winch;
    instWinchM2 : FB_Winch;

    // ↔️ CHARIOT — M3, axe X joystick (intégré 2026-07-02, mode DEGRADED_IO figé — Partie11 §7)
    instSafetyChariotM3 : FB_Safety_Chariot;
    instChariotM3       : FB_Chariot;

    // 🎚️ Stub Maintenance N1 pour ce lot (Enable, PAS le Mode — voir instModes ci-dessus)
    // — à remplacer par une vraie arbitrage FB_Modes quand FB_Cycle existera
    StubMachineEnableN1 : BOOL := TRUE;

    // 🪣 GRAPPIN
    instGrappin             : FB_Grappin;
    GrappinCmdOpen_IHM      : BOOL;             // 🖥️ Commande d'ouverture IHM (bouton)
    GrappinCmdClose_IHM     : BOOL;             // 🖥️ Commande de fermeture IHM (bouton)
    M2_StartStop_Active     : BOOL;             // Consigne StartStop arbitrée pour M2
    M2_Direction_Active     : INT;              // Consigne Direction arbitrée pour M2
    M2_SpeedRef_Active      : REAL;             // Consigne SpeedRef arbitrée pour M2
    M2_SpeedStepTableActive : ST_SpeedStepTable; // Table de paliers active de M2

    // 🛠️ Variables de simulation pour banc de test (mouvement simulé des treuils)
    SimulatedM1Raw          : UDINT := 1000000;
    SimulatedM2Raw          : UDINT := 1000000;
    M1_RawPosToUse          : UDINT;
    M2_RawPosToUse          : UDINT;
    InitDone                : BOOL;             // 🧪 Initialisation unique au boot (simulation)
END_VAR

// 💾 Bloc VAR RETAIN SUPPRIMÉ (2026-07-03) : toutes les variables de calibration
// et réglage de mise en service sont désormais dans GVL_PERSISTENT (survivent aux
// téléchargements de programme). Voir CODE/SYSTEM/GVL_PERSISTENT.st.

