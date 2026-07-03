(* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   ðŸ§  PRG_MAIN â€” Orchestration sÃ©quentielle (diag â†’ sÃ©curitÃ© â†’ mÃ©tier)
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   ðŸ“„ Contient : Joystick (axe Y) â†’ FB_Safety_Winch (M1/M2) â†’ FB_Winch (M1+M2,
      consigne dupliquÃ©e sur le mÃªme axe) â†’ relais ; pipeline codeur M1/M2
      (FB_Encoder_Abs â†’ Scale â†’ Homing, flux nominal) ; Joystick (axe X) â†’
      FB_Safety_Chariot â†’ FB_Chariot (M3, mode DEGRADED_IO figÃ©, Partie11).
   ðŸ“¥/ðŸ“¤ I/O rÃ©el conditionnÃ© via `FB_InputsMachine`/`FB_OutputsMachine` (1
      instance chacun, appelÃ©es SANS PARAMÃˆTRE) â†” `GVL_IN`/`GVL_OUT`
      (accÃ¨s direct par tag global â€” Partie6 Â§5).
   ðŸŽ¯ HOMING : ordre par treuil Abs â†’ Scale â†’ Homing. `PresetRequest`/
      `PresetValue` et `HomingRefRaw` consommÃ©s avec **1 cycle de retard**
      (assumÃ©, sans consÃ©quence â€” Partie10 Â§9bis).
   âš ï¸ M2 dupliquÃ© sur le MÃŠME axe Y que M1, SANS `FB_WinchSync` rÃ©el (codeur
      pas encore exploitÃ© pour une synchro â€” Partie9 Â§9).
   ðŸ”´ Ã€ SUPPRIMER MANUELLEMENT dans CODESYS (orphelins, jamais appelÃ©s) :
      `PRG_COD1` (remplacÃ© par les instances ci-dessous, 1 seul POU â€” Partie2
      Â§0), `FB_Safety` (sorties jamais consommÃ©es).
   ðŸ”´ NO-GO ESSAIS RÃ‰ELS AVEC MOUVEMENT tant que : (1) diag EtherCAT/CAN rÃ©el
      pas activÃ© (`EnableDiagnosis=False` sur tous les devices â€” procÃ©dure
      d'activation CODESYS : AUDIT Â§16) ; (2) test terrain dÃ©branchement
      physique COD1/COD2 pas fait (xError/wState pas garantis fail-safe selon
      version stack) ; (3) CAN joystick en littÃ©raux TRUE (Â§0 â€” homme-mort
      aveugle Ã  la perte de liaison).
   ðŸ”´ NE COMPILE PAS TANT QUE `CtrlPhaseRotation_DI` N'EXISTE PAS EN I/O MAPPING
      (2026-07-03sexdecies/novodecies, AUDIT D67/D71) : crÃ©er ce DI dans CODESYS AVANT de
      coller ce fichier. `GVL_IN.PhaseRotationOk` cÃ¢blÃ© dans `FB_Safety_Winch`(M1/M2)/
      `FB_Safety_Chariot` (pas directement sur `EmergencyStopOk`, cf D71 â€” cohÃ©rent avec
      le principe Â« safety centralise les capteurs, le mÃ©tier consomme SafeStop Â»). Nom/
      polaritÃ© (TRUE=OK) ASSUMÃ‰S sans confirmation utilisateur â€” Ã  vÃ©rifier.
   ðŸ”§ CORRECTIF (2026-07-03unvicies, retour terrain, AUDIT D74 â€” SUPERSEDÃ‰ D75) : blocage
      `SafeStop` diagnostiquÃ© en direct (`GVL_IN.PhaseRotationOk` jamais Ã©crit tant que
      `CtrlPhaseRotation_DI` n'existe pas cÃ´tÃ© device â†’ dÃ©marrait `FALSE`, dÃ©faut IEC 61131-3).
      Fix final retenu : `GVL_DEBUG.DBG_CtrlPhaseRotation_Bypass_TEST` (crÃ©Ã© par l'utilisateur,
      OR'Ã© sur le signal brut dans `FB_InputsMachine`, mÃªme pattern qu'`EmergencyStopOk`/
      `TopPositionSensor`) â€” pas d'init `:= TRUE` sur `GVL_IN.PhaseRotationOk` (retirÃ©e, D75).
   ðŸ“š Historique complet des dÃ©cisions (D1-D75, dont renommage I/O `_DI`/`_DQ`/
      `_RQ`, retours frein rÃ©els, `GVL_IN`/`GVL_OUT`) :
      DOC/AUDIT_Coherence_Documentaire_v1.0.md
   â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• *)

// === DECLARATION (Ã  coller dans la partie dÃ©claration du POU PRG_MAIN) ===

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

    // ðŸ§° FB_INPUTSMACHINE/FB_OUTPUTSMACHINE â€” conditionnement I/O rÃ©el de toute la machine
    // (2026-07-03nonies, scinde l'ancien FB_IO_Machine â€” 1 instance chacun, APPELÃ‰E UNE
    // SEULE FOIS : entrÃ©es tÃ´t (avant Homing/Safety/Winch/Chariot), sorties tard (aprÃ¨s
    // FB_Winch/FB_Chariot). Voir en-tÃªtes FB_InputsMachine.st/FB_OutputsMachine.st.
    instInputsMachine  : FB_InputsMachine;
    instOutputsMachine : FB_OutputsMachine;

    // ðŸ•¹ï¸ Instance unique du traitement joystick (pipeline calib/filtre/rampe)
    FB_Joystick_0 : FB_Joystick;

    // ðŸŽšï¸ FB_MODES â€” arbitrage du mode machine, 1 SEULE instance (remplace E_Mode.MAINT_N1 codÃ©
    // en dur partout). Voir en-tÃªte FB_Modes.st.
    instModes : FB_Modes;
    EncoderFaultPresentM1 : BOOL;   // ðŸ“¤ instEncoderSafetyM1.EncoderIncoherent (calculÃ© plus bas, 1 cycle de retard)
    EncoderFaultPresentM2 : BOOL;   // ðŸ“¤ instEncoderSafetyM2.EncoderIncoherent (calculÃ© plus bas, 1 cycle de retard)
    EncoderFaultPresent   : BOOL;   // ðŸ“¤ OR des deux â€” entrÃ©e instModes (1 cycle de retard, cf en-tÃªte FB_Modes.st)

    // ðŸ§² CODEUR â€” acquisition + mise Ã  l'Ã©chelle + homing (flux nominal), 1 instance par treuil
    instEncoderAbsM1   : FB_Encoder_Abs;
    instEncoderScaleM1 : FB_Encoder_Scale;
    instHomingM1       : FB_Encoder_Homing;   // âœ… 2026-07-02 â€” possÃ¨de Calib (RETAIN) en interne
    instEncoderAbsM2   : FB_Encoder_Abs;
    instEncoderScaleM2 : FB_Encoder_Scale;
    instHomingM2       : FB_Encoder_Homing;

    // ðŸ›¡ï¸ FB_ENCODER_SAFETY â€” bornage Â±99m + relais HomingSuspect, 1 instance par treuil (rÃ©pond
    // Ã  l'incident CablePosMâ‰ˆ4096m). Voir en-tÃªte FB_Encoder_Safety.st.
    instEncoderSafetyM1 : FB_Encoder_Safety;
    instEncoderSafetyM2 : FB_Encoder_Safety;

    // ðŸ”Œ SAFETY â€” bloc safety mÃ©tier du domaine treuil, 1 instance par treuil
    // (mÃªme TYPE FB_Safety_Winch, 2 instances â€” Partie10 Â§7)
    instSafetyWinchM1 : FB_Safety_Winch;
    instSafetyWinchM2 : FB_Safety_Winch;

    // âš–ï¸ FB_WINCHSYNC â€” surveillance Ã©cart M1/M2, 1 SEULE instance (squelette de liaisons,
    // pas de correction â€” voir en-tÃªte FB_WinchSync.st et Partie9 Â§9).
    instWinchSync : FB_WinchSync;

    // ðŸª WINCH â€” M1 et M2 (consigne dupliquÃ©e sur l'axe Y, Maintenance N1, choix 2026-07-02)
    instWinchM1 : FB_Winch;
    instWinchM2 : FB_Winch;

    // â†”ï¸ CHARIOT â€” M3, axe X joystick (intÃ©grÃ© 2026-07-02, mode DEGRADED_IO figÃ© â€” Partie11 Â§7)
    instSafetyChariotM3 : FB_Safety_Chariot;
    instChariotM3       : FB_Chariot;

    // ðŸŽšï¸ Stub Maintenance N1 pour ce lot (Enable, PAS le Mode â€” voir instModes ci-dessus)
    // â€” Ã  remplacer par une vraie arbitrage FB_Modes quand FB_Cycle existera
    StubMachineEnableN1 : BOOL := TRUE;

    // ðŸª£ GRAPPIN
    instGrappin             : FB_Grappin;
    GrappinCmdOpen_IHM      : BOOL;             // ðŸ–¥ï¸ Commande d'ouverture IHM (bouton)
    GrappinCmdClose_IHM     : BOOL;             // ðŸ–¥ï¸ Commande de fermeture IHM (bouton)
    M2_StartStop_Active     : BOOL;             // Consigne StartStop arbitrÃ©e pour M2
    M2_Direction_Active     : INT;              // Consigne Direction arbitrÃ©e pour M2
    M2_SpeedRef_Active      : REAL;             // Consigne SpeedRef arbitrÃ©e pour M2
    M2_SpeedStepTableActive : ST_SpeedStepTable; // Table de paliers active de M2

    // ðŸ› ï¸ Variables de simulation pour banc de test (mouvement simulÃ© des treuils)
    SimulatedM1Raw          : UDINT := 1000000;
    SimulatedM2Raw          : UDINT := 1000000;
    M1_RawPosToUse          : UDINT;
    M2_RawPosToUse          : UDINT;
END_VAR

// âš ï¸ CORRECTIF (2026-07-02) : les tables paliers Ã©taient dÃ©clarÃ©es en VAR simple malgrÃ© le
// commentaire "RETAIN" â€” ne persistaient PAS rÃ©ellement entre coupures/tÃ©lÃ©chargements.
// CorrigÃ© : bloc VAR RETAIN dÃ©diÃ©, comme le nÃ©cessitent aussi les paramÃ¨tres de homing.
VAR RETAIN
    // ðŸªœ Table paliers M1 â€” rÃ©glable sans recompiler (Partie1 Â§Paliers)
    // âš ï¸ Valeurs par dÃ©faut indicatives (cumulatives P1â†’P5) : Ã€ AJUSTER un par un
    //    selon le cÃ¢blage rÃ©el des 4 contacteurs de vitesse M1 pendant la mise
    //    en service (chaque P<palier>R<relais> est modifiable en direct dans la
    //    vue instance CODESYS), et les seuils souhaitÃ©s (%).
    M1_SpeedStepTable : ST_SpeedStepTable := (
        P1R1 := TRUE,  P1R2 := FALSE, P1R3 := FALSE, P1R4 := FALSE,
        P2R1 := TRUE,  P2R2 := TRUE,  P2R3 := FALSE, P2R4 := FALSE,
        P3R1 := TRUE,  P3R2 := TRUE,  P3R3 := TRUE,  P3R4 := FALSE,
        P4R1 := TRUE,  P4R2 := TRUE,  P4R3 := TRUE,  P4R4 := TRUE,
        P5R1 := TRUE,  P5R2 := TRUE,  P5R3 := TRUE,  P5R4 := TRUE,
        StepThreshold_Pct := [20.0, 40.0, 60.0, 80.0, 100.0]
    );

    // ðŸªœ Table paliers M2 â€” INDÃ‰PENDANTE de M1 (Partie1 Â§Paliers : "table
    // indÃ©pendante par treuil"), mÃªmes valeurs par dÃ©faut indicatives Ã  ajuster.
    M2_SpeedStepTable : ST_SpeedStepTable := (
        P1R1 := TRUE,  P1R2 := FALSE, P1R3 := FALSE, P1R4 := FALSE,
        P2R1 := TRUE,  P2R2 := TRUE,  P2R3 := FALSE, P2R4 := FALSE,
        P3R1 := TRUE,  P3R2 := TRUE,  P3R3 := TRUE,  P3R4 := FALSE,
        P4R1 := TRUE,  P4R2 := TRUE,  P4R3 := TRUE,  P4R4 := TRUE,
        P5R1 := TRUE,  P5R2 := TRUE,  P5R3 := TRUE,  P5R4 := TRUE,
        StepThreshold_Pct := [20.0, 40.0, 60.0, 80.0, 100.0]
    );

    // âš–ï¸ TolÃ©rance Ã©cart M1/M2 (FB_WinchSync) â€” rÃ©glable sans recompiler, ajuster selon jeu
    // mÃ©canique rÃ©el observÃ© sur site (Partie9 Â§9).
    WinchSyncToleranceM : REAL := 0.10;

    // ðŸª£ Configuration persistante du grappin
    GrappinConfig : ST_GrappinConfig := (
        OffsetOpenM := 0.0,
        OffsetCloseM := -1.5,
        CoherenceLimitM := 0.05
    );

    // ðŸª£ Ã‰tat persistant mÃ©morisÃ© du grappin
    GrappinState : ST_GrappinState;
END_VAR

// === IMPLEMENTATION (Ã  coller dans le corps ST du POU PRG_MAIN) ===

// ðŸ–¥ï¸ 1. ACQUISITION DES COMMANDES IHM (Lot A, 2026-07-03)
GrappinCmdOpen_IHM                              := GVL_IHM.Grappin.CmdOpen;
GrappinCmdClose_IHM                             := GVL_IHM.Grappin.CmdClose;
GVL_Modes_Stub.OverrideSyncRequest_IHM          := GVL_IHM.Sync.OverrideSync;
GVL_Encoder_Stub.M1_Reset_IHM                   := GVL_IHM.WinchM1.CmdReset;
GVL_Encoder_Stub.M2_Reset_IHM                   := GVL_IHM.WinchM2.CmdReset;
GVL_Encoder_Stub.M1_ConfirmCoherence_IHM         := GVL_IHM.WinchM1.ConfirmCoherence;
GVL_Encoder_Stub.M2_ConfirmCoherence_IHM         := GVL_IHM.WinchM2.ConfirmCoherence;

// ðŸŽ›ï¸ Acquisition des commandes issues de l'IHM (Joystick, Modes, Chariot)
GVL_Modes_Stub.ModeRequest_IHM                  := GVL_IHM.Modes.ModeRequest;
GVL_Modes_Stub.PasswordOk_IHM                   := GVL_IHM.Modes.PasswordOk;
MachineReset_IHM                                := GVL_IHM.Modes.MachineReset OR GVL_IHM.WinchM1.CmdReset OR GVL_IHM.WinchM2.CmdReset OR GVL_IHM.Grappin.CmdReset;
StubChariotPositionSelect_IHM                   := GVL_IHM.Chariot.SelectedTargetNum;
FB_Joystick_0.Calibrate                         := GVL_IHM.Joystick.Calibrate;

// Gestion de la commande Home et du mode homing selon les boutons tactiles
IF GVL_IHM.WinchM1.CmdHome AND GVL_IHM.WinchM2.CmdHome THEN
    GVL_Encoder_Stub.HomingMode_IHM := 3;
    GVL_Encoder_Stub.StubHomeButton_IHM := TRUE;
ELSIF GVL_IHM.WinchM1.CmdHome THEN
    GVL_Encoder_Stub.HomingMode_IHM := 1;
    GVL_Encoder_Stub.StubHomeButton_IHM := TRUE;
ELSIF GVL_IHM.WinchM2.CmdHome THEN
    GVL_Encoder_Stub.HomingMode_IHM := 2;
    GVL_Encoder_Stub.StubHomeButton_IHM := TRUE;
ELSE
    GVL_Encoder_Stub.StubHomeButton_IHM := FALSE;
END_IF;

(* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   ðŸ“¡ 0. DIAGNOSTICS BUS RÃ‰ELS (Lot A mise en service, 2026-07-03sexies)
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   ðŸ”§ Remplace les littÃ©raux TRUE/8 (pertes bus INDÃ‰TECTABLES jusqu'ici â€” trou de
      sÃ©curitÃ© nÂ°1 identifiÃ© au plan mise en service) :
   - EtherCAT : instances esclaves IoDrvEtherCAT (COD1_CODEUR/COD2_CODEUR/
     AC600_ECAT_Drive, arbre devices). PropriÃ©tÃ© `wState` (ETC_SLAVE_STATE,
     16#8 = OPERATIONAL) + `xError` (TRUE = esclave en erreur â†’ utilisÃ© comme
     "WcState" au sens FB_DiagEthercat : Online := NOT WcState).
     âš ï¸ VÃ‰RIFIER Ã  la compilation : `wState`/`xError` doivent apparaÃ®tre dans
     l'assistant de saisie sur `COD1_CODEUR.` â€” si noms diffÃ©rents dans votre
     version IoDrvEtherCAT, adapter ces 6 lignes UNIQUEMENT (le FB ne change pas).
   - CAN joystick : ðŸ”´ TODO CONFIRMER â€” l'instance `JOY1_JOYSTICK_MCB560_CO4201A`
     (CANRemoteDevice) n'a pas de propriÃ©tÃ© d'Ã©tat confirmÃ©e dans cette version de
     stack. En attendant : littÃ©raux TRUE conservÃ©s (comportement inchangÃ©), Ã 
     remplacer dÃ¨s que la propriÃ©tÃ© exacte est identifiÃ©e dans CODESYS
     (taper `JOY1_JOYSTICK_MCB560_CO4201A.` et regarder l'autocomplÃ©tion).
   â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• *)

instDiagCanOpen(
    Enable := TRUE,
    Reset := MachineReset_IHM,
    CanOnline := TRUE,         // ðŸ”´ TODO CONFIRMER propriÃ©tÃ© device CAN (voir en-tÃªte section)
    CanOperational := TRUE     // ðŸ”´ TODO CONFIRMER propriÃ©tÃ© device CAN (voir en-tÃªte section)
);

// ðŸ”´ TODO CONFIRMER (2026-07-03octies) : `EnableDiagnosis=False` sur COD1_CODEUR/COD2_CODEUR/
// AC600_ECAT_Drive dans le projet CODESYS actuel (vÃ©rifiÃ© dans Device.export) â€” `.xError`/
// `.wState` PAS garantis fiables tant que le diagnostic device n'est pas activÃ©. LittÃ©raux
// TODO conservÃ©s (comportement inchangÃ©, SANS RISQUE) en attendant : voir note d'application
// DOC/AUDIT_Coherence_Documentaire_v1.0.md Â§16 pour la procÃ©dure d'activation CODESYS +
// remplacer VariateurWcState/SlaveState, EncoderM1/M2WcState/SlaveState par les VRAIS canaux
// de diagnostic une fois activÃ©s et leurs noms confirmÃ©s dans l'assistant de saisie.
instDiagEthercat(
    Enable := TRUE,
    Reset := MachineReset_IHM,          // ðŸ”‘ Bouton gÃ©nÃ©ral machine
    VariateurWcState := FALSE,          // ðŸ”´ TODO: activer Diagnosis sur AC600_ECAT_Drive (AUDIT Â§16)
    VariateurSlaveState := 8,           // ðŸ”´ TODO: idem
    EncoderM1WcState := FALSE,          // ðŸ”´ TODO: activer Diagnosis sur COD1_CODEUR (AUDIT Â§16)
    EncoderM1SlaveState := 8,           // ðŸ”´ TODO: idem
    EncoderM2WcState := FALSE,          // ðŸ”´ TODO: activer Diagnosis sur COD2_CODEUR (AUDIT Â§16)
    EncoderM2SlaveState := 8            // ðŸ”´ TODO: idem
);

(* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   ðŸ“¥ 1. FB_INPUTSMACHINE â€” conditionnement ENTRÃ‰ES rÃ©elles (appel unique, tÃ´t)
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   TOUT le conditionnement d'entrÃ©es rÃ©elles de la machine (Commun + Winch M1 + Winch M2
   + Chariot M3) en UN SEUL appel, AVANT tout FB mÃ©tier â€” clÃ´t Q11/D32 (AUDIT) et
   gÃ©nÃ©ralise le principe (anti-rebond forÃ§able en mise en service sans toucher au cÃ¢blage).
   ðŸ”§ RESTRUCTURATION (2026-07-03undecies/quindecies, demande utilisateur) : `FB_InputsMachine`
   rÃ©fÃ©rence DIRECTEMENT les I/O rÃ©els en interne ET Ã©crit ses sorties conditionnÃ©es
   directement dans `GVL_IN.Xxx` (pas de suffixe, ex. `GVL_IN.EmergencyStopOk`) â€”
   appel SANS PARAMÃˆTRE, rien Ã  rÃ©cupÃ©rer ici. Tous les consommateurs plus bas lisent
   `GVL_IN.Xxx` directement. Sorties (commandes) : voir Â§7 (FB_OutputsMachine, aprÃ¨s
   FB_Winch/FB_Chariot).
   â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• *)

instInputsMachine();

(* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   ðŸŽšï¸ 1bis2. FB_MODES â€” arbitrage du mode machine (remplace E_Mode.MAINT_N1 codÃ© en dur)
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   `EncoderFaultPresent` utilisÃ© ici est celui calculÃ© Ã  LA FIN du cycle PRÃ‰CÃ‰DENT
   (par instEncoderSafetyM1/M2, appelÃ©s plus bas â€” dÃ©pendent de CablePosM/Homing qui
   ne sont pas encore connus Ã  ce point du cycle). 1 cycle de retard assumÃ©, mÃªme
   principe que HomingRefRaw (Partie10 Â§9bis) â€” voir en-tÃªte FB_Modes.st.
   â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• *)

instModes(
    Enable              := TRUE,
    Reset               := MachineReset_IHM,

    EmergencyStopOk     := GVL_IN.EmergencyStopOk,
    ModeRequest         := GVL_Modes_Stub.ModeRequest_IHM,      // ðŸ–¥ï¸ SÃ©lecteur forceable
    PasswordOk          := GVL_Modes_Stub.PasswordOk_IHM,       // ðŸ–¥ï¸ Stub authentification MAINT_N2
    OverrideSyncRequest := GVL_Modes_Stub.OverrideSyncRequest_IHM,
    EncoderFaultPresent := EncoderFaultPresent                  // 1 cycle de retard (voir ci-dessus)
);

// 2. ACQUISITION DU GESTE OPÃ‰RATEUR SÃ‰CURISÃ‰

(* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   ðŸ•¹ï¸ Appel du traitement joystick (version ST)
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   CÃ¢ble les E/S physiques sur le FB, qui rÃ©alise en interne :
   calibration âžœ filtrage âžœ rampe âžœ % .
   ðŸ“¤ RÃ©sultat exploitable : FB_Joystick_0.AxisCmdX / .AxisCmdY
   ðŸ“„ Doc mÃ©tier : DOC/AF_Partie8_Fonction_Joystick_v1.1.md
   â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• *)

FB_Joystick_0(
    // ðŸŸ¢ --- Autorisations & sÃ©curitÃ© ---
    Enable          := GVL_DEBUG.DBG_True,      // âš ï¸ DEBUG : remplacer par autorisation rÃ©elle
    EmergencyStopOk := GVL_IN.EmergencyStopOk,
    Reset           := MachineReset_IHM,


    // ðŸ”Œ --- Ã‰tat du bus CANopen (joystick) ---
    BusCanOpenOP    := instDiagCanOpen.busCanOpen,        // ðŸ“¡ nÅ“ud CAN prÃ©sent
    JoystickOP      := instDiagCanOpen.Joystick,          // ðŸ“¡ esclave en mode opÃ©rationnel

    // ðŸ“¥ --- EntrÃ©es brutes joystick ---
    RawX            := JoyXRaw_ANA1,            // ðŸ•¹ï¸ axe X brut (0..10000)
    RawY            := JoyYRaw_ANA2,            // ðŸ•¹ï¸ axe Y brut (0..10000)
    RawButton       := JoyBtnRaw,               // ðŸ”˜ bouton brut

    // ðŸŽ¯ --- Calibration ---
    Calibrate       := GVL_IHM.Joystick.Calibrate,                   // ðŸŽ¯ Bouton recalage neutre IHM (front)

    // ðŸŽ›ï¸ --- ParamÃ¨tres de traitement ---
    InvertX         := FALSE,
    InvertY         := FALSE,
    Deadband        := 10.0,                    // ðŸ”§ 2026-07-02 (demande utilisateur) : 5.0 â†’ 10.0 %
    FilterTime      := TIME#100ms,
    AccelRate       := 50.0,
    DecelRate       := 150.0
);

(* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   ðŸ§² 3. CODEUR â€” Acquisition + mise Ã  l'Ã©chelle + homing (M1=COD1, M2=COD2)
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   âœ… Canaux COD1_* ET COD2_* cÃ¢blÃ©s en I/O Mapping (matÃ©riel rÃ©el,
      COD2 mappÃ© 2026-07-02 â€” plus de stub `GVL_Encoder_M2_Stub`, retirÃ©).
   ðŸŽ¯ Ordre d'appel PAR TREUIL : Abs â†’ Scale â†’ Homing (voir en-tÃªte
      fichier â€” dÃ©pendance croisÃ©e Absâ†”Homing assumÃ©e Ã  1 cycle prÃ¨s).
   â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• *)

// ðŸ› ï¸ --- SIMULATION SUR BANC DE TEST (Winches M1/M2) ---
// Actif uniquement si GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST est TRUE.
// Permet de simuler le mouvement des treuils et le homing sans matÃ©riel connectÃ©.
IF GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST THEN
    // Treuil M1
    IF COD1_PresettTrigCmd = 2 THEN
        SimulatedM1Raw := COD1_PresetValue; // Simule le recalage matÃ©riel lors de la commande de preset (homing)
    ELSIF GVL_OUT.M1RelayFwd THEN
        SimulatedM1Raw := SimulatedM1Raw + REAL_TO_UDINT(instWinchM1.SpeedRamp.Current * 0.1);
    ELSIF GVL_OUT.M1RelayRev THEN
        IF SimulatedM1Raw >= REAL_TO_UDINT(instWinchM1.SpeedRamp.Current * 0.1) THEN
            SimulatedM1Raw := SimulatedM1Raw - REAL_TO_UDINT(instWinchM1.SpeedRamp.Current * 0.1);
        ELSE
            SimulatedM1Raw := 0;
        END_IF;
    END_IF;

    // Treuil M2
    IF COD2_PresettTrigCmd = 2 THEN
        SimulatedM2Raw := COD2_PresetValue; // Simule le recalage matÃ©riel lors de la commande de preset (homing)
    ELSIF GVL_OUT.M2RelayFwd THEN
        SimulatedM2Raw := SimulatedM2Raw + REAL_TO_UDINT(instWinchM2.SpeedRamp.Current * 0.1);
    ELSIF GVL_OUT.M2RelayRev THEN
        IF SimulatedM2Raw >= REAL_TO_UDINT(instWinchM2.SpeedRamp.Current * 0.1) THEN
            SimulatedM2Raw := SimulatedM2Raw - REAL_TO_UDINT(instWinchM2.SpeedRamp.Current * 0.1);
        ELSE
            SimulatedM2Raw := 0;
        END_IF;
    END_IF;

    // Utilisation des positions simulÃ©es
    M1_RawPosToUse := SimulatedM1Raw;
    M2_RawPosToUse := SimulatedM2Raw;
ELSE
    // Utilisation des valeurs rÃ©elles
    M1_RawPosToUse := COD1_PosValue;
    M2_RawPosToUse := COD2_PosValue;
END_IF;

instEncoderAbsM1(
    Enable              := TRUE,
    Reset               := (M1_Reset_IHM OR MachineReset_IHM),

    EmergencyStopOk     := GVL_IN.EmergencyStopOk,
    Mode                := instModes.Mode,

    RawPosIn            := M1_RawPosToUse,                  // ðŸ“¡ SÃ©lecteur simulation/physique (banc de test)
    AlarmsIn            := COD1_Alarms,                     // ðŸ“¡ I/O Mapping dÃ©jÃ  existant
    WarningsIn          := COD1_Warnings,                   // ðŸ“¡ I/O Mapping dÃ©jÃ  existant
    SlaveOperational    := instDiagEthercat.EncoderM1.Operational,
    PresetRequest       := instHomingM1.PresetRequest,      // âœ… 2026-07-02 (1 cycle de retard, voir en-tÃªte)
    PresetValue         := instHomingM1.PresetValue         // âœ… 2026-07-02
);
// ðŸ“¤ Sorties preset â†’ RxPDO rÃ©els (I/O Mapping dÃ©jÃ  existant, canaux COD1)
COD1_PresettTrigCmd := instEncoderAbsM1.PresetTriggerCmd;
COD1_CodeSeqTrigCmd := instEncoderAbsM1.CodeSeqTriggerCmd;
COD1_PresetValue    := instEncoderAbsM1.PresetValueOut;

instEncoderScaleM1(
    RawPos          := instEncoderAbsM1.RawPos,
    HomingRefRaw    := instHomingM1.HomingRefRaw,           // âœ… 2026-07-02 (1 cycle de retard, voir en-tÃªte)
    CableM_PerRev   := 2.0,  // PÃ©rimÃ¨tre tambour confirmÃ© 2026-07-02 (Ã©tait 1.5 provisoire)
    PointsPerRev    := 8192
);

(* ðŸŽ¯ Homing M1 (flux nominal) â€” bouton IHM (stub) + capteur position haute (stub GVL_Homing_Stub, commun M1+M2) *)
instHomingM1(
    Enable               := TRUE,
    Reset                := (M1_Reset_IHM OR MachineReset_IHM),

    EmergencyStopOk      := GVL_IN.EmergencyStopOk,
    Mode                 := instModes.Mode,

    Home                 := (StubHomeButton_IHM AND ((HomingMode_IHM = 1) OR (HomingMode_IHM = 3))),  // ðŸ–¥ï¸ GVL_Encoder_Stub â€” mode homing (1=M1seul, 2=M2seul, 3=Both)
    ConfirmCoherence     := M1_ConfirmCoherence_IHM,          // ðŸ–¥ï¸ GVL_Encoder_Stub
    TopPositionSensor    := GVL_IN.TopPositionSensor,
    TopSensorPositionM   := M1_TopSensorPositionM,           // RETAIN, rÃ©glable (Â§ calibration Partie10 Â§7bis)
    ContactorFeedbackFwd := GVL_IN.M1ContactorFeedbackFwd,
    ContactorFeedbackRev := GVL_IN.M1ContactorFeedbackRev,
    BrakeFeedback        := GVL_IN.M1BrakeFeedback,
    RawPos               := instEncoderAbsM1.RawPos,
    EncoderAvailable     := instEncoderAbsM1.EncoderAvailable,
    PresetAck            := instEncoderAbsM1.PresetAck,
    PresetNak            := instEncoderAbsM1.PresetNak,
    PointsPerRev         := 8192,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := 2.0
);

instEncoderAbsM2(
    Enable              := TRUE,
    Reset               := (M2_Reset_IHM OR MachineReset_IHM),

    EmergencyStopOk     := GVL_IN.EmergencyStopOk,
    Mode                := instModes.Mode,

    RawPosIn            := M2_RawPosToUse,                  // ðŸ“¡ SÃ©lecteur simulation/physique (banc de test)
    AlarmsIn            := COD2_Alarms,                     // ðŸ“¡ I/O Mapping (mappÃ© 2026-07-02)
    WarningsIn          := COD2_Warnings,                   // ðŸ“¡ I/O Mapping (mappÃ© 2026-07-02)
    SlaveOperational    := instDiagEthercat.EncoderM2.Operational,
    PresetRequest       := instHomingM2.PresetRequest,      // âœ… 2026-07-02 (1 cycle de retard, voir en-tÃªte)
    PresetValue         := instHomingM2.PresetValue         // âœ… 2026-07-02
);
// ðŸ“¤ Sorties preset â†’ RxPDO rÃ©els (I/O Mapping mappÃ© 2026-07-02, comme COD1_PresettTrigCmd)
COD2_PresettTrigCmd := instEncoderAbsM2.PresetTriggerCmd;
COD2_CodeSeqTrigCmd := instEncoderAbsM2.CodeSeqTriggerCmd;
COD2_PresetValue    := instEncoderAbsM2.PresetValueOut;

instEncoderScaleM2(
    RawPos          := instEncoderAbsM2.RawPos,
    HomingRefRaw    := instHomingM2.HomingRefRaw,           // âœ… 2026-07-02 (1 cycle de retard, voir en-tÃªte)
    CableM_PerRev   := 2.0,  // PÃ©rimÃ¨tre tambour confirmÃ© 2026-07-02 (Ã©tait 1.5 provisoire)
    PointsPerRev    := 8192
);

(* ðŸŽ¯ Homing M2 (flux nominal) â€” MÃŠME bouton IHM que M1 (rÃ©fÃ©rencement simultanÃ©, Partie10 Â§1) *)
instHomingM2(
    Enable               := TRUE,
    Reset                := (M2_Reset_IHM OR MachineReset_IHM),

    EmergencyStopOk      := GVL_IN.EmergencyStopOk,
    Mode                 := instModes.Mode,

    Home                 := (StubHomeButton_IHM AND ((HomingMode_IHM = 2) OR (HomingMode_IHM = 3))),  // ðŸ–¥ï¸ GVL_Encoder_Stub â€” mode homing (1=M1seul, 2=M2seul, 3=Both)
    ConfirmCoherence     := M2_ConfirmCoherence_IHM,          // ðŸ–¥ï¸ GVL_Encoder_Stub
    TopPositionSensor    := GVL_IN.TopPositionSensor,
    TopSensorPositionM   := M2_TopSensorPositionM,           // RETAIN, rÃ©glable (Â§ calibration Partie10 Â§7bis)
    ContactorFeedbackFwd := GVL_IN.M2ContactorFeedbackFwd,
    ContactorFeedbackRev := GVL_IN.M2ContactorFeedbackRev,
    BrakeFeedback        := GVL_IN.M2BrakeFeedback,
    RawPos               := instEncoderAbsM2.RawPos,
    EncoderAvailable     := instEncoderAbsM2.EncoderAvailable,
    PresetAck            := instEncoderAbsM2.PresetAck,
    PresetNak            := instEncoderAbsM2.PresetNak,
    PointsPerRev         := 8192,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := 2.0
);

(* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   ðŸ›¡ï¸ 3bis. FB_ENCODER_SAFETY â€” bornage Â±99m + relais HomingSuspect (1 par treuil)
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   RÃ©pond Ã  l'incident CablePosMâ‰ˆ4096m (RETAIN Calib remis Ã  0 aprÃ¨s refactor).
   EncoderFaultPresent (OR M1/M2) alimente instModes AU CYCLE SUIVANT (voir Â§1bis2).
   â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• *)

instEncoderSafetyM1(
    Enable          := TRUE,
    Reset           := (M1_Reset_IHM OR MachineReset_IHM),

    EmergencyStopOk := GVL_IN.EmergencyStopOk,
    Mode            := instModes.Mode,
    CablePosM       := instEncoderScaleM1.CablePosM,
    HomingSuspect   := instHomingM1.HomingSuspect,
    PositionMinM    := -99.0,
    PositionMaxM    := 99.0
);
EncoderFaultPresentM1 := instEncoderSafetyM1.EncoderIncoherent;

instEncoderSafetyM2(
    Enable          := TRUE,
    Reset           := (M2_Reset_IHM OR MachineReset_IHM),

    EmergencyStopOk := GVL_IN.EmergencyStopOk,
    Mode            := instModes.Mode,
    CablePosM       := instEncoderScaleM2.CablePosM,
    HomingSuspect   := instHomingM2.HomingSuspect,
    PositionMinM    := -99.0,
    PositionMaxM    := 99.0
);
EncoderFaultPresentM2 := instEncoderSafetyM2.EncoderIncoherent;

EncoderFaultPresent := EncoderFaultPresentM1 OR EncoderFaultPresentM2;   // ðŸ“¤ ConsommÃ© par instModes AU CYCLE SUIVANT

(* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   âš–ï¸ 3ter. FB_WINCHSYNC â€” surveillance Ã©cart M1/M2 (squelette, PAS de correction)
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   Enable := NOT OverrideSync (Partie5 Â§2 "Logique d'override" â€” actionnable
   UNIQUEMENT en MAINT_N2 via GVL_Modes_Stub.OverrideSyncRequest_IHM).
   â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• *)

instWinchSync(
    Enable          := NOT instModes.OverrideSync AND NOT instGrappin.Busy,
    Reset           := MachineReset_IHM,

    EmergencyStopOk := GVL_IN.EmergencyStopOk,
    Mode            := instModes.Mode,
    CablePosM1      := instEncoderScaleM1.CablePosM,
    CablePosM2      := instEncoderScaleM2.CablePosM,
    HomedM1         := instHomingM1.Homed,
    HomedM2         := instHomingM2.Homed,
    OverrideSync    := instModes.OverrideSync,
    SyncToleranceM  := WinchSyncToleranceM,
    ActiveOffsetM   := instGrappin.ActiveOffsetM
);

(* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   ðŸ”Œ 4. SÃ‰CURITÃ‰ MÃ‰TIER TREUIL â€” FB_Safety_Winch (1 instance par treuil)
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   PÃ©rimÃ¨tre : perte joystick/CAN (partagÃ©e) + perte codeur DE CE
   TREUIL (cÃ¢blÃ©, lot Codeur). SafeStop consommÃ© par le FB_Winch du
   MÃŠME treuil (Partie10 Â§7 : split M1/M2 par composition, 2 instances).
   â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• *)

instSafetyWinchM1(
    Enable              := TRUE,
    Reset               := MachineReset_IHM,

    EmergencyStopOk     := GVL_IN.EmergencyStopOk,
    Mode                := instModes.Mode,

    JoystickOnline      := instDiagCanOpen.Joystick.Online,
    JoystickOperational := instDiagCanOpen.Joystick.Operational,
    EncoderAvailable    := instEncoderAbsM1.EncoderAvailable,
    ThermalFeedback     := NOT GVL_IN.M1ThermalFeedback,
    SlackCableDetected  := NOT GVL_IN.SlackCableSwitch,
    PhaseRotationOk     := GVL_IN.PhaseRotationOk
);

instSafetyWinchM2(
    Enable              := TRUE,
    Reset               := MachineReset_IHM,

    EmergencyStopOk     := GVL_IN.EmergencyStopOk,
    Mode                := instModes.Mode,

    JoystickOnline      := instDiagCanOpen.Joystick.Online,
    JoystickOperational := instDiagCanOpen.Joystick.Operational,
    EncoderAvailable    := instEncoderAbsM2.EncoderAvailable,
    ThermalFeedback     := NOT GVL_IN.M2ThermalFeedback,
    SlackCableDetected  := NOT GVL_IN.SlackCableSwitch,
    PhaseRotationOk     := GVL_IN.PhaseRotationOk
);

(* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   ðŸª 5. TREUILS M1 + M2 â€” FB_Winch (Maint N1, consigne dupliquÃ©e axe Y)
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   âš ï¸ M2 dupliquÃ© sur le MÃŠME axe Y que M1 (choix actÃ© 2026-07-02) :
      les deux treuils reÃ§oivent la mÃªme consigne, SANS FB_WinchSync
      rÃ©el (le codeur sert Ã  la mesure/sÃ©curitÃ© de ce lot, pas encore
      Ã  une rÃ©gulation d'Ã©cart M1/M2 â€” voir DOC/AF_Partie9 Â§9).
   âœ… SUPERSEDÃ‰ (2026-07-03quattuordecies) : `GVL_Winch_M1_Stub.st`/`GVL_Winch_M2_Stub.st`
      supprimÃ©s â€” tout le matÃ©riel M1/M2 (relais, contacteurs, retour frein) est
      dÃ©sormais rÃ©el, cÃ¢blÃ© en I/O Mapping (`_DI`/`_DQ`/`_RQ`, voir Â§0 et Â§7bis).
   â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• *)

// ðŸª£ Appel du bloc Grappin (entre l'acquisition codeurs/joystick et les winches)
instGrappin(
    Enable              := TRUE,
    Reset               := MachineReset_IHM,
    EmergencyStopOk     := GVL_IN.EmergencyStopOk,
    Mode                := instModes.Mode,
    CmdOpen_IHM         := GrappinCmdOpen_IHM,
    CmdClose_IHM        := GrappinCmdClose_IHM,
    JoystickY_StartStop := FB_Joystick_0.AxisCmdY.StartStop,
    JoystickY_Direction := FB_Joystick_0.AxisCmdY.Direction,
    CablePosM1          := instEncoderScaleM1.CablePosM,
    CablePosM2          := instEncoderScaleM2.CablePosM,
    Config              := GrappinConfig,
    TimeoutDuration     := GVL_IHM.Grappin.TimeoutDuration,  // ðŸ†• Configurable depuis IHM
    GrappinState        := GrappinState
);

// Arbitrage des consignes de M2 (Grappin vs Mouvement Synchrone)
IF instGrappin.Busy THEN
    M2_StartStop_Active := instGrappin.M2_StartStop;
    M2_Direction_Active := instGrappin.M2_Direction;
    M2_SpeedRef_Active  := 15.0; // Vitesse lente grappin
ELSE
    M2_StartStop_Active := FB_Joystick_0.AxisCmdY.StartStop;
    M2_Direction_Active := FB_Joystick_0.AxisCmdY.Direction;
    M2_SpeedRef_Active  := FB_Joystick_0.AxisCmdY.SpeedRef;
END_IF;

// Construction de la table de paliers active de M2 (force tous les contacteurs Ã  FALSE si ForceSlowSpeed)
IF instGrappin.M2_ForceSlowSpeed THEN
    M2_SpeedStepTableActive.P1R1 := FALSE; M2_SpeedStepTableActive.P1R2 := FALSE; M2_SpeedStepTableActive.P1R3 := FALSE; M2_SpeedStepTableActive.P1R4 := FALSE;
    M2_SpeedStepTableActive.P2R1 := FALSE; M2_SpeedStepTableActive.P2R2 := FALSE; M2_SpeedStepTableActive.P2R3 := FALSE; M2_SpeedStepTableActive.P2R4 := FALSE;
    M2_SpeedStepTableActive.P3R1 := FALSE; M2_SpeedStepTableActive.P3R2 := FALSE; M2_SpeedStepTableActive.P3R3 := FALSE; M2_SpeedStepTableActive.P3R4 := FALSE;
    M2_SpeedStepTableActive.P4R1 := FALSE; M2_SpeedStepTableActive.P4R2 := FALSE; M2_SpeedStepTableActive.P4R3 := FALSE; M2_SpeedStepTableActive.P4R4 := FALSE;
    M2_SpeedStepTableActive.P5R1 := FALSE; M2_SpeedStepTableActive.P5R2 := FALSE; M2_SpeedStepTableActive.P5R3 := FALSE; M2_SpeedStepTableActive.P5R4 := FALSE;
    M2_SpeedStepTableActive.StepThreshold_Pct := M2_SpeedStepTable.StepThreshold_Pct;
ELSE
    M2_SpeedStepTableActive := M2_SpeedStepTable;
END_IF;

instWinchM1(
    Enable                  := StubMachineEnableN1,           // âš ï¸ Stub Maint N1 â€” Ã  remplacer par FB_Modes
    Reset                   := MachineReset_IHM,

    EmergencyStopOk         := GVL_IN.EmergencyStopOk,
    Mode                    := instModes.Mode,

    StartStop               := FB_Joystick_0.AxisCmdY.StartStop AND NOT instGrappin.Busy, // BloquÃ© pendant le mouvement grappin
    SafeStop                := instSafetyWinchM1.SafeStop,
    ForbidDescent           := instSafetyWinchM1.ForbidDescent,  // ðŸ†• Mou de cÃ¢ble â€” masque UNIQUEMENT RelayRev
    Direction               := FB_Joystick_0.AxisCmdY.Direction,
    SpeedRefPct             := FB_Joystick_0.AxisCmdY.SpeedRef,
    SpeedStepTable          := M1_SpeedStepTable,
    MaxStepDescente         := GVL_IHM.WinchM1.MaxStepDescente,    // ðŸ†• Configurable depuis IHM
    ContactorFeedbackFwd    := GVL_IN.M1ContactorFeedbackFwd,
    ContactorFeedbackRev    := GVL_IN.M1ContactorFeedbackRev,
    BrakeFeedback           := GVL_IN.M1BrakeFeedback,
    RampAccelRate           := GVL_IHM.WinchM1.RampAccelRate,      // ðŸ†• Configurable depuis IHM
    RampDecelNormalRate     := GVL_IHM.WinchM1.RampDecelNormalRate, // ðŸ†• Configurable depuis IHM
    RampDecelFastRate       := GVL_IHM.WinchM1.RampDecelFastRate   // ðŸ†• Configurable depuis IHM
);

instWinchM2(
    Enable                  := StubMachineEnableN1,           // âš ï¸ MÃªme stub Maint N1 que M1 â€” Ã  remplacer par FB_Modes
    Reset                   := MachineReset_IHM,

    EmergencyStopOk         := GVL_IN.EmergencyStopOk,
    Mode                    := instModes.Mode,

    StartStop               := M2_StartStop_Active,           // ArbitrÃ© grappin
    SafeStop                := instSafetyWinchM2.SafeStop,
    ForbidDescent           := instSafetyWinchM2.ForbidDescent,  // ðŸ†• Mou de cÃ¢ble â€” masque UNIQUEMENT RelayRev
    Direction               := M2_Direction_Active,           // ArbitrÃ© grappin
    SpeedRefPct             := M2_SpeedRef_Active,            // ArbitrÃ© grappin
    SpeedStepTable          := M2_SpeedStepTableActive,       // ArbitrÃ©e grappin (sans contacteurs si vitesse lente forcÃ©e)
    MaxStepDescente         := GVL_IHM.WinchM2.MaxStepDescente,    // ðŸ†• Configurable depuis IHM
    ContactorFeedbackFwd    := GVL_IN.M2ContactorFeedbackFwd,
    ContactorFeedbackRev    := GVL_IN.M2ContactorFeedbackRev,
    BrakeFeedback           := GVL_IN.M2BrakeFeedback,
    RampAccelRate           := GVL_IHM.WinchM2.RampAccelRate,      // ðŸ†• Configurable depuis IHM
    RampDecelNormalRate     := GVL_IHM.WinchM2.RampDecelNormalRate, // ðŸ†• Configurable depuis IHM
    RampDecelFastRate       := GVL_IHM.WinchM2.RampDecelFastRate   // ðŸ†• Configurable depuis IHM
);

(* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   â†”ï¸ 6. CHARIOT M3 â€” FB_Chariot (axe X, mode DEGRADED_IO figÃ©)
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   IntÃ©grÃ© 2026-07-02 (Partie11 Â§7, recommandation "option 1") : mode
   ETHERCAT non cÃ¢blÃ© (TBD protocole AC600, voir Partie11 Â§4) â€” CommMode
   figÃ© DEGRADED_IO (relais sens + PV/GV), stubs neutres sur les entrÃ©es
   ETHERCAT (jamais utilisÃ©es tant que CommMode ne bascule pas).
   ðŸ”§ 2026-07-02 : renommage mÃ©tier Translationâ†’Chariot (prÃ©fixe I/O
   physique M3 inchangÃ©). `M3_BrakeCmd` dÃ©sormais cÃ¢blÃ© en I/O Mapping
   RÃ‰EL (retirÃ© de GVL_Chariot_M3_Stub, reste sinon STUB logiciel).
   âš ï¸ AVANT tout essai rÃ©el : Partie11 Â§4bis (paramÃ©trage AC600,
   verrouillage source de commande Terminal) impÃ©ratif.
   â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• *)

instSafetyChariotM3(
    Enable              := TRUE,
    Reset               := MachineReset_IHM,

    EmergencyStopOk     := GVL_IN.EmergencyStopOk,
    Mode                := instModes.Mode,

    JoystickOnline      := instDiagCanOpen.Joystick.Online,
    JoystickOperational := instDiagCanOpen.Joystick.Operational,
    PhaseRotationOk     := GVL_IN.PhaseRotationOk
);

// ðŸŽ¯ SÃ‰LECTEUR STUB MAINTENANCE (2026-07-02, demande utilisateur) â€” arbitre M3_PositionSensorTarget
// parmi les 4 capteurs position RÃ‰ELS du chariot, en attendant FB_Cycle (pas encore codÃ©, qui
// fera cette sÃ©lection en exploitation normale â€” Partie11 Â§9bis). PosFosse1/PosFosse2/
// PosMaintenance/PosTremie : noms exacts I/O Mapping (Device.export).
CASE StubChariotPositionSelect_IHM OF
    1: M3_PositionSensorTarget := GVL_IN.ChariotPosFosse1;
    2: M3_PositionSensorTarget := GVL_IN.ChariotPosFosse2;
    3: M3_PositionSensorTarget := GVL_IN.ChariotPosMaintenance;
    4: M3_PositionSensorTarget := GVL_IN.ChariotPosTremie;
ELSE
    M3_PositionSensorTarget := FALSE;   // 0 ou valeur hors plage = aucun capteur sÃ©lectionnÃ©
END_CASE;

instChariotM3(
    Enable                  := StubMachineEnableN1,           // âš ï¸ MÃªme stub Maint N1 que Winch â€” Ã  remplacer par FB_Modes
    Reset                   := MachineReset_IHM,

    EmergencyStopOk         := GVL_IN.EmergencyStopOk,
    Mode                    := instModes.Mode,

    StartStop               := FB_Joystick_0.AxisCmdX.StartStop,
    SafeStop                := instSafetyChariotM3.SafeStop,
    CommMode                := E_ChariotCommMode.DEGRADED_IO,  // âš ï¸ FigÃ© (EtherCAT AC600 TBD, Partie11 Â§4/Â§7)
    Direction               := FB_Joystick_0.AxisCmdX.Direction,
    SpeedRefPct             := FB_Joystick_0.AxisCmdX.SpeedRef,
    PositionSensorTarget    := M3_PositionSensorTarget,      // ðŸŽ¯ ArbitrÃ© par le sÃ©lecteur STUB ci-dessus
    DriveStatusWord         := 0,                            // ðŸ”´ TBD ETHERCAT (Partie11 Â§4) â€” inerte en DEGRADED_IO
    DriveActualFreqHz       := 0.0,                          // ðŸ”´ TBD ETHERCAT â€” inerte en DEGRADED_IO
    ContactorFeedbackFwd    := M3_ContactorFeedbackFwd,      // ðŸ§ª STUB GVL_Chariot_M3_Stub
    ContactorFeedbackRev    := M3_ContactorFeedbackRev,      // ðŸ§ª STUB GVL_Chariot_M3_Stub
    DriveFaultFeedback      := M3_DriveFaultFeedback,        // ðŸ§ª STUB GVL_Chariot_M3_Stub (toujours FALSE, non cÃ¢blÃ©)
    BrakeFeedback           := SEL(GVL_IHM.Chariot.BypassBrakeFeedback, GVL_IN.M3BrakeFeedback, instChariotM3.BrakeCmd)
);

// ðŸ“¤ Sorties chariot M3 STUB (GVL_Chariot_M3_Stub, pas de matÃ©riel rÃ©el â€” pas conditionnÃ©es,
// voir en-tÃªte FB_OutputsMachine.st) : RelayFwd/Rev/RelaySpeedGv
M3_RelayFwd     := instChariotM3.RelayFwd;
M3_RelayRev     := instChariotM3.RelayRev;
M3_RelaySpeedGv := instChariotM3.RelaySpeedGv;

// ðŸ§ª SIMULATION (stub GVL_Chariot_M3_Stub) â€” voir note Winch M1 ci-dessus.
M3_ContactorFeedbackFwd := M3_RelayFwd;
M3_ContactorFeedbackRev := M3_RelayRev;

(* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   ðŸ–¥ï¸ MAPPING IHM â†” PROCESSUS
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   Ce bloc assure la copie bidirectionnelle des consignes/paramÃ¨tres
   et des Ã©tats/diagnostics vers GVL_IHM pour affichage Ã©cran.
   â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• *)

// --- 1. INITIALISATION DES CONFIGURATIONS DEPUIS LES VALEURS PAR DÃ‰FAUT (SI VIDE) ---
IF GVL_IHM.WinchM1.TopSensorPositionM = 0.0 THEN
    GVL_IHM.WinchM1.TopSensorPositionM  := 12.5;
    GVL_IHM.WinchM1.MaxStepDescente     := 2;
    GVL_IHM.WinchM1.RampAccelRate       := 50.0;
    GVL_IHM.WinchM1.RampDecelNormalRate := 150.0;
    GVL_IHM.WinchM1.RampDecelFastRate   := 400.0;
END_IF;

IF GVL_IHM.WinchM2.TopSensorPositionM = 0.0 THEN
    GVL_IHM.WinchM2.TopSensorPositionM  := 12.5;
    GVL_IHM.WinchM2.MaxStepDescente     := 2;
    GVL_IHM.WinchM2.RampAccelRate       := 50.0;
    GVL_IHM.WinchM2.RampDecelNormalRate := 150.0;
    GVL_IHM.WinchM2.RampDecelFastRate   := 400.0;
END_IF;

IF GVL_IHM.Sync.SyncToleranceM = 0.0 THEN
    GVL_IHM.Sync.SyncToleranceM         := 0.10;
END_IF;

IF GVL_IHM.Grappin.Config.OffsetOpenM = 0.0 AND GVL_IHM.Grappin.Config.OffsetCloseM = 0.0 THEN
    GVL_IHM.Grappin.Config.OffsetOpenM     := 0.0;
    GVL_IHM.Grappin.Config.OffsetCloseM    := -1.5;
    GVL_IHM.Grappin.Config.CoherenceLimitM := 0.05;
    GVL_IHM.Grappin.TimeoutDuration        := T#30s;
END_IF;

// --- 2. PROPAGATION DES PARAMÃˆTRES ET CONFIGURATIONS DEPUIS L'IHM ---
GVL_Encoder_Stub.M1_TopSensorPositionM      := GVL_IHM.WinchM1.TopSensorPositionM;
GVL_Encoder_Stub.M2_TopSensorPositionM      := GVL_IHM.WinchM2.TopSensorPositionM;
WinchSyncToleranceM                         := GVL_IHM.Sync.SyncToleranceM;
GrappinConfig                               := GVL_IHM.Grappin.Config;

// --- 3. GESTION DES BYPASSES BANC DE TEST (DEUX VOIES) ---
GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST  := GVL_IHM.WinchM1.BypassContactorFeedback OR GVL_IHM.WinchM2.BypassContactorFeedback OR GVL_IHM.Chariot.BypassContactorFeedback;
GVL_DEBUG.DBG_SlackCableSwitch_TEST         := GVL_IHM.WinchM1.BypassSlackCable OR GVL_IHM.WinchM2.BypassSlackCable;
GVL_DEBUG.DBG_TopPositionSensorBypass_TEST   := GVL_IHM.WinchM1.BypassTopPositionSensor OR GVL_IHM.WinchM2.BypassTopPositionSensor;

GVL_IHM.WinchM1.BypassContactorFeedback     := GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST;
GVL_IHM.WinchM2.BypassContactorFeedback     := GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST;
GVL_IHM.Chariot.BypassContactorFeedback     := GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST;
GVL_IHM.WinchM1.BypassSlackCable            := GVL_DEBUG.DBG_SlackCableSwitch_TEST;
GVL_IHM.WinchM2.BypassSlackCable            := GVL_DEBUG.DBG_SlackCableSwitch_TEST;
GVL_IHM.WinchM1.BypassTopPositionSensor     := GVL_DEBUG.DBG_TopPositionSensorBypass_TEST;
GVL_IHM.WinchM2.BypassTopPositionSensor     := GVL_DEBUG.DBG_TopPositionSensorBypass_TEST;

// --- 4. COPIE DES STATUTS TREUIL M1 VERS GVL_IHM ---
GVL_IHM.WinchM1.PositionM                   := instEncoderScaleM1.CablePosM;
GVL_IHM.WinchM1.SpeedRefPct                 := instWinchM1.SpeedRamp.Current;
GVL_IHM.WinchM1.StepNumber                  := instWinchM1.StepNumber;
GVL_IHM.WinchM1.FBState                     := instWinchM1.State;
GVL_IHM.WinchM1.Ready                       := instWinchM1.Ready;
GVL_IHM.WinchM1.Busy                        := instWinchM1.Busy;
GVL_IHM.WinchM1.Done                        := instWinchM1.Done;
GVL_IHM.WinchM1.Error                       := instWinchM1.Error;
GVL_IHM.WinchM1.ErrorId                     := instWinchM1.ErrorId;
GVL_IHM.WinchM1.RelayFwd                    := instWinchM1.RelayFwd;
GVL_IHM.WinchM1.RelayRev                    := instWinchM1.RelayRev;
GVL_IHM.WinchM1.Contactor1                  := instWinchM1.Contactor1;
GVL_IHM.WinchM1.Contactor2                  := instWinchM1.Contactor2;
GVL_IHM.WinchM1.Contactor3                  := instWinchM1.Contactor3;
GVL_IHM.WinchM1.Contactor4                  := instWinchM1.Contactor4;
GVL_IHM.WinchM1.BrakeCmd                    := instWinchM1.BrakeCmd;
GVL_IHM.WinchM1.Homed                       := instHomingM1.Homed;
GVL_IHM.WinchM1.SafeStopActive              := instSafetyWinchM1.SafeStop;
GVL_IHM.WinchM1.ForbidDescentActive         := instSafetyWinchM1.ForbidDescent;
GVL_IHM.WinchM1.SlackCableDetected          := NOT GVL_IN.SlackCableSwitch;
GVL_IHM.WinchM1.ThermalFault                := GVL_IN.M1ThermalFeedback;
GVL_IHM.WinchM1.EncoderFault                := NOT instEncoderAbsM1.EncoderAvailable OR instEncoderSafetyM1.EncoderIncoherent;
GVL_IHM.WinchM1.Encoder.RawPos              := instEncoderAbsM1.RawPos;
GVL_IHM.WinchM1.Encoder.Alarms              := instEncoderAbsM1.AlarmsIn;
GVL_IHM.WinchM1.Encoder.Warnings            := instEncoderAbsM1.WarningsIn;
GVL_IHM.WinchM1.Encoder.SlaveOperational    := instEncoderAbsM1.SlaveOperational;
GVL_IHM.WinchM1.Encoder.PresetTriggerCmd    := instEncoderAbsM1.PresetTriggerCmd;
GVL_IHM.WinchM1.Encoder.PresetValueOut      := instEncoderAbsM1.PresetValueOut;
GVL_IHM.WinchM1.FwdContactorCheck           := instWinchM1.FwdContactorCheck;
GVL_IHM.WinchM1.RevContactorCheck           := instWinchM1.RevContactorCheck;
GVL_IHM.WinchM1.BrakeContactorCheck         := instWinchM1.BrakeContactorCheck;

// --- 5. COPIE DES STATUTS TREUIL M2 VERS GVL_IHM ---
GVL_IHM.WinchM2.PositionM                   := instEncoderScaleM2.CablePosM;
GVL_IHM.WinchM2.SpeedRefPct                 := instWinchM2.SpeedRamp.Current;
GVL_IHM.WinchM2.StepNumber                  := instWinchM2.StepNumber;
GVL_IHM.WinchM2.FBState                     := instWinchM2.State;
GVL_IHM.WinchM2.Ready                       := instWinchM2.Ready;
GVL_IHM.WinchM2.Busy                        := instWinchM2.Busy;
GVL_IHM.WinchM2.Done                        := instWinchM2.Done;
GVL_IHM.WinchM2.Error                       := instWinchM2.Error;
GVL_IHM.WinchM2.ErrorId                     := instWinchM2.ErrorId;
GVL_IHM.WinchM2.RelayFwd                    := instWinchM2.RelayFwd;
GVL_IHM.WinchM2.RelayRev                    := instWinchM2.RelayRev;
GVL_IHM.WinchM2.Contactor1                  := instWinchM2.Contactor1;
GVL_IHM.WinchM2.Contactor2                  := instWinchM2.Contactor2;
GVL_IHM.WinchM2.Contactor3                  := instWinchM2.Contactor3;
GVL_IHM.WinchM2.Contactor4                  := instWinchM2.Contactor4;
GVL_IHM.WinchM2.BrakeCmd                    := instWinchM2.BrakeCmd;
GVL_IHM.WinchM2.Homed                       := instHomingM2.Homed;
GVL_IHM.WinchM2.SafeStopActive              := instSafetyWinchM2.SafeStop;
GVL_IHM.WinchM2.ForbidDescentActive         := instSafetyWinchM2.ForbidDescent;
GVL_IHM.WinchM2.SlackCableDetected          := NOT GVL_IN.SlackCableSwitch;
GVL_IHM.WinchM2.ThermalFault                := GVL_IN.M2ThermalFeedback;
GVL_IHM.WinchM2.EncoderFault                := NOT instEncoderAbsM2.EncoderAvailable OR instEncoderSafetyM2.EncoderIncoherent;
GVL_IHM.WinchM2.Encoder.RawPos              := instEncoderAbsM2.RawPos;
GVL_IHM.WinchM2.Encoder.Alarms              := instEncoderAbsM2.AlarmsIn;
GVL_IHM.WinchM2.Encoder.Warnings            := instEncoderAbsM2.WarningsIn;
GVL_IHM.WinchM2.Encoder.SlaveOperational    := instEncoderAbsM2.SlaveOperational;
GVL_IHM.WinchM2.Encoder.PresetTriggerCmd    := instEncoderAbsM2.PresetTriggerCmd;
GVL_IHM.WinchM2.Encoder.PresetValueOut      := instEncoderAbsM2.PresetValueOut;
GVL_IHM.WinchM2.FwdContactorCheck           := instWinchM2.FwdContactorCheck;
GVL_IHM.WinchM2.RevContactorCheck           := instWinchM2.RevContactorCheck;
GVL_IHM.WinchM2.BrakeContactorCheck         := instWinchM2.BrakeContactorCheck;

// --- 6. COPIE DES STATUTS GRAPPIN VERS GVL_IHM ---
GVL_IHM.Grappin.FBState                     := instGrappin.State;
GVL_IHM.Grappin.ActiveOffsetM               := instGrappin.ActiveOffsetM;
GVL_IHM.Grappin.M2StartStop                 := instGrappin.M2_StartStop;
GVL_IHM.Grappin.M2Direction                 := instGrappin.M2_Direction;
GVL_IHM.Grappin.M2ForceSlowSpeed            := instGrappin.M2_ForceSlowSpeed;
GVL_IHM.Grappin.Ready                       := instGrappin.Ready;
GVL_IHM.Grappin.Busy                        := instGrappin.Busy;
GVL_IHM.Grappin.Done                        := instGrappin.Done;
GVL_IHM.Grappin.Error                       := instGrappin.Error;
GVL_IHM.Grappin.ErrorId                     := instGrappin.ErrorId;
GVL_IHM.Grappin.State                       := GrappinState;

// --- 7. COPIE DES STATUTS SYNCHRO VERS GVL_IHM ---
GVL_IHM.Sync.DeltaPosM                      := instWinchSync.DeltaPosM;
GVL_IHM.Sync.SyncActive                     := instWinchSync.SyncActive;
GVL_IHM.Sync.SyncWarn                       := instWinchSync.SyncWarn;
GVL_IHM.Sync.Ready                          := instWinchSync.Ready;
GVL_IHM.Sync.Error                          := instWinchSync.Error;
GVL_IHM.Sync.ErrorId                        := instWinchSync.ErrorId;
GVL_IHM.Sync.State                          := instWinchSync.State;

// --- 8. COPIE DES STATUTS CHARIOT M3 VERS GVL_IHM ---
GVL_IHM.Chariot.FBState                     := instChariotM3.State;
GVL_IHM.Chariot.Ready                       := instChariotM3.Ready;
GVL_IHM.Chariot.Busy                        := instChariotM3.Busy;
GVL_IHM.Chariot.Done                        := instChariotM3.Done;
GVL_IHM.Chariot.Error                       := instChariotM3.Error;
GVL_IHM.Chariot.ErrorId                     := instChariotM3.ErrorId;
GVL_IHM.Chariot.RelayFwd                    := instChariotM3.RelayFwd;
GVL_IHM.Chariot.RelayRev                    := instChariotM3.RelayRev;
GVL_IHM.Chariot.RelaySpeedGv                := instChariotM3.RelaySpeedGv;
GVL_IHM.Chariot.BrakeCmd                    := instChariotM3.BrakeCmd;
GVL_IHM.Chariot.BrakeFeedback               := GVL_IN.M3BrakeFeedback;
GVL_IHM.Chariot.PositionSensorTarget        := M3_PositionSensorTarget;
GVL_IHM.Chariot.DriveStatusWord             := instChariotM3.DriveStatusWord;
GVL_IHM.Chariot.DriveActualFreqHz           := instChariotM3.DriveActualFreqHz;

// --- 9. COPIE DES STATUTS DU JOYSTICK VERS GVL_IHM ---
GVL_IHM.Joystick.RawX                       := JoyXRaw_ANA1;
GVL_IHM.Joystick.RawY                       := JoyYRaw_ANA2;
GVL_IHM.Joystick.RawButton                  := JoyBtnRaw;
GVL_IHM.Joystick.CmdX                       := FB_Joystick_0.AxisCmdX;
GVL_IHM.Joystick.CmdY                       := FB_Joystick_0.AxisCmdY;
GVL_IHM.Joystick.Online                     := instDiagCanOpen.Joystick.Online;
GVL_IHM.Joystick.Operational                 := instDiagCanOpen.Joystick.Operational;

// --- 10. COPIE DES STATUTS MODES DE MARCHE VERS GVL_IHM ---
GVL_IHM.Modes.CurrentMode                   := instModes.Mode;
GVL_IHM.Modes.EmergencyStopOk               := GVL_IN.EmergencyStopOk;

// --- 11. COPIE DES STATUTS DIAGNOSTICS RÃ‰SEAU VERS GVL_IHM ---
GVL_IHM.Network.BusCanOpen                  := instDiagCanOpen.busCanOpen;
GVL_IHM.Network.Joystick                    := instDiagCanOpen.Joystick;
GVL_IHM.Network.CanError                    := instDiagCanOpen.Error;
GVL_IHM.Network.CanErrorId                  := instDiagCanOpen.ErrorId;
GVL_IHM.Network.BusEthercat                 := instDiagEthercat.BusEthercat;
GVL_IHM.Network.EncoderM1                   := instDiagEthercat.EncoderM1;
GVL_IHM.Network.EncoderM2                   := instDiagEthercat.EncoderM2;
GVL_IHM.Network.VariateurM3                 := instDiagEthercat.Variateur;
GVL_IHM.Network.EcatError                   := instDiagEthercat.Error;
GVL_IHM.Network.EcatErrorId                 := instDiagEthercat.ErrorId;

(* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   ðŸ“¤ 7. GVL_OUTPUTS + FB_OUTPUTSMACHINE â€” conditionnement SORTIES rÃ©elles (tard)
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   Simples affectations vers `GVL_OUT` (naturel en LD : 1 rung = 1 bobine), puis
   `FB_OutputsMachine` appelÃ© SANS PARAMÃˆTRE â€” il lit `GVL_OUT.Xxx` en interne
   et Ã©crit DIRECTEMENT les I/O rÃ©els (`_DQ`/`_RQ`). Voir en-tÃªte FB_OutputsMachine.st.
   â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• *)

GVL_OUT.M1RelayFwd        := instWinchM1.RelayFwd;
GVL_OUT.M1RelayRev        := instWinchM1.RelayRev;
GVL_OUT.M1SpeedContactor1 := instWinchM1.Contactor1;
GVL_OUT.M1SpeedContactor2 := instWinchM1.Contactor2;
GVL_OUT.M1SpeedContactor3 := instWinchM1.Contactor3;
GVL_OUT.M1SpeedContactor4 := instWinchM1.Contactor4;
GVL_OUT.M1BrakeCmd        := instWinchM1.BrakeCmd;

GVL_OUT.M2RelayFwd        := instWinchM2.RelayFwd;
GVL_OUT.M2RelayRev        := instWinchM2.RelayRev;
GVL_OUT.M2SpeedContactor1 := instWinchM2.Contactor1;
GVL_OUT.M2SpeedContactor2 := instWinchM2.Contactor2;
GVL_OUT.M2SpeedContactor3 := instWinchM2.Contactor3;
GVL_OUT.M2SpeedContactor4 := instWinchM2.Contactor4;
GVL_OUT.M2BrakeCmd        := instWinchM2.BrakeCmd;

GVL_OUT.ChariotBrakeCmd   := instChariotM3.BrakeCmd;

instOutputsMachine();

(* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   ðŸ§¨ 8. POWERCUTOFF â€” agrÃ©gat coupure puissance amont (Lot A, 2026-07-03sexies)
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   OR des sorties PowerCutOff des blocs safety mÃ©tier (Partie2 Â§6 : coupure puissance
   amont si contacteur collÃ©). Aujourd'hui les 3 sorties sont TOUJOURS FALSE (pas de
   ST_ContactorCheck de puissance cÃ¢blÃ© dans les FB safety â€” TBD assumÃ©).
   ðŸ”§ CORRECTIF (2026-07-03quindecies) : relais rÃ©el cÃ¢blÃ© en I/O Mapping
   (`PowerCutOff_RQ`) â€” remplace le stub `GVL_Machine_Stub.PowerCutOffCmd`, retirÃ©.
   â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• *)

PowerCutOff_RQ := instSafetyWinchM1.PowerCutOff OR instSafetyWinchM2.PowerCutOff
                  OR instSafetyChariotM3.PowerCutOff;

