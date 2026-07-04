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
    
    // 📐 Limites basses actives et blocages de descente calculés (légal + longueur câble)
    BottomLimitM1_Active    : REAL;
    BottomLimitM2_Active    : REAL;
    ForbidDescentM1_Active  : BOOL;
    ForbidDescentM2_Active  : BOOL;
END_VAR

// 💾 Bloc VAR RETAIN SUPPRIMÉ (2026-07-03) : toutes les variables de calibration
// et réglage de mise en service sont désormais dans GVL_PERSISTENT (survivent aux
// téléchargements de programme). Voir CODE/SYSTEM/GVL_PERSISTENT.st.

// === IMPLEMENTATION (à coller dans le corps ST du POU PRG_MAIN) ===

// 🧪 LOGIQUE D'INITIALISATION AU BOOT SUR BANC (Simulation)
IF NOT InitDone THEN
    InitDone := TRUE;
    IF GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST THEN
        GVL_IHM.Modes.ModeRequest := E_Mode.MAINT_N2;
        GVL_IHM.Modes.PasswordOk := TRUE;
        
        // 💾 Initialisation des positions simulées à partir de la calibration persistante (si référencée)
        // Permet d'éviter le problème de valeur absurde (-3800m) après un redémarrage à chaud (Hot Restart)
        IF GVL_PERSISTENT.CalibM1.Homed THEN
            SimulatedM1Raw := GVL_PERSISTENT.CalibM1.HomingRefRaw + REAL_TO_UDINT(GVL_PERSISTENT.HomingTargetM1_M * 4096.0);
        ELSE
            SimulatedM1Raw := 1000000;
        END_IF;
        
        IF GVL_PERSISTENT.CalibM2.Homed THEN
            SimulatedM2Raw := GVL_PERSISTENT.CalibM2.HomingRefRaw + REAL_TO_UDINT(GVL_PERSISTENT.HomingTargetM2_M * 4096.0);
        ELSE
            SimulatedM2Raw := 1000000;
        END_IF;
    END_IF;
END_IF;

// 🖥️ 1. ACQUISITION DES COMMANDES IHM (Lot A, 2026-07-03)
GrappinCmdOpen_IHM                              := GVL_IHM.Grappin.CmdOpen;
GrappinCmdClose_IHM                             := GVL_IHM.Grappin.CmdClose;
GVL_Modes_Stub.OverrideSyncRequest_IHM          := GVL_IHM.Sync.OverrideSync;
GVL_Encoder_Stub.M1_Reset_IHM                   := GVL_IHM.WinchM1.CmdReset;
GVL_Encoder_Stub.M2_Reset_IHM                   := GVL_IHM.WinchM2.CmdReset;
GVL_Encoder_Stub.M1_ConfirmCoherence_IHM         := GVL_IHM.WinchM1.ConfirmCoherence;
GVL_Encoder_Stub.M2_ConfirmCoherence_IHM         := GVL_IHM.WinchM2.ConfirmCoherence;

// 🎛️ Acquisition des commandes issues de l'IHM (Joystick, Modes, Chariot)
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

(* ═══════════════════════════════════════════════════════════════
   📡 0. DIAGNOSTICS BUS RÉELS (Lot A mise en service, 2026-07-03sexies)
   ───────────────────────────────────────────────────────────────
   🔧 Remplace les littéraux TRUE/8 (pertes bus INDÉTECTABLES jusqu'ici — trou de
      sécurité n°1 identifié au plan mise en service) :
   - EtherCAT : instances esclaves IoDrvEtherCAT (COD1_CODEUR/COD2_CODEUR/
     AC600_ECAT_Drive, arbre devices). Propriété `wState` (ETC_SLAVE_STATE,
     16#8 = OPERATIONAL) + `xError` (TRUE = esclave en erreur → utilisé comme
     "WcState" au sens FB_DiagEthercat : Online := NOT WcState).
     ⚠️ VÉRIFIER à la compilation : `wState`/`xError` doivent apparaître dans
     l'assistant de saisie sur `COD1_CODEUR.` — si noms différents dans votre
     version IoDrvEtherCAT, adapter ces 6 lignes UNIQUEMENT (le FB ne change pas).
   - CAN joystick : 🔴 TODO CONFIRMER — l'instance `JOY1_JOYSTICK_MCB560_CO4201A`
     (CANRemoteDevice) n'a pas de propriété d'état confirmée dans cette version de
     stack. En attendant : littéraux TRUE conservés (comportement inchangé), à
     remplacer dès que la propriété exacte est identifiée dans CODESYS
     (taper `JOY1_JOYSTICK_MCB560_CO4201A.` et regarder l'autocomplétion).
   ═══════════════════════════════════════════════════════════════ *)

instDiagCanOpen(
    Enable := TRUE,
    Reset := MachineReset_IHM,
    CanOnline := (CANbus.GetBusState() = 1) OR GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST, // 1 = ACTIVE (ou bypass test banc)
    CanOperational := (JOY1_JOYSTICK_MCB560_CO4201A.GetDeviceState() = DEVICE_STATE.RUNNING) OR GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST
);

// 🔴 NOTE (2026-07-04) : Les esclaves EtherCAT et CANopen implémentent l'interface IDevice.
// Nous interrogeons donc leur état de fonctionnement réel via la méthode standard .GetDeviceState()
// (DEVICE_STATE.RUNNING = état sain / actif).
instDiagEthercat(
    Enable := TRUE,
    Reset := MachineReset_IHM,          // 🔑 Bouton général machine
    VariateurWcState := (AC600_ECAT_Drive.GetDeviceState() <> DEVICE_STATE.RUNNING) AND NOT GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST,
    VariateurSlaveState := SEL(GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST OR (AC600_ECAT_Drive.GetDeviceState() = DEVICE_STATE.RUNNING), 0, 8),
    EncoderM1WcState := (COD1_CODEUR.GetDeviceState() <> DEVICE_STATE.RUNNING) AND NOT GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST,
    EncoderM1SlaveState := SEL(GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST OR (COD1_CODEUR.GetDeviceState() = DEVICE_STATE.RUNNING), 0, 8),
    EncoderM2WcState := (COD2_CODEUR.GetDeviceState() <> DEVICE_STATE.RUNNING) AND NOT GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST,
    EncoderM2SlaveState := SEL(GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST OR (COD2_CODEUR.GetDeviceState() = DEVICE_STATE.RUNNING), 0, 8)
);

(* ═══════════════════════════════════════════════════════════════
   📥 1. FB_INPUTSMACHINE — conditionnement ENTRÉES réelles (appel unique, tôt)
   ───────────────────────────────────────────────────────────────
   TOUT le conditionnement d'entrées réelles de la machine (Commun + Winch M1 + Winch M2
   + Chariot M3) en UN SEUL appel, AVANT tout FB métier — clôt Q11/D32 (AUDIT) et
   généralise le principe (anti-rebond forçable en mise en service sans toucher au câblage).
   🔧 RESTRUCTURATION (2026-07-03undecies/quindecies, demande utilisateur) : `FB_InputsMachine`
   référence DIRECTEMENT les I/O réels en interne ET écrit ses sorties conditionnées
   directement dans `GVL_IN.Xxx` (pas de suffixe, ex. `GVL_IN.EmergencyStopOk`) —
   appel SANS PARAMÈTRE, rien à récupérer ici. Tous les consommateurs plus bas lisent
   `GVL_IN.Xxx` directement. Sorties (commandes) : voir §7 (FB_OutputsMachine, après
   FB_Winch/FB_Chariot).
   ═══════════════════════════════════════════════════════════════ *)

instInputsMachine();

(* ═══════════════════════════════════════════════════════════════
   🎚️ 1bis2. FB_MODES — arbitrage du mode machine (remplace E_Mode.MAINT_N1 codé en dur)
   ───────────────────────────────────────────────────────────────
   `EncoderFaultPresent` utilisé ici est celui calculé à LA FIN du cycle PRÉCÉDENT
   (par instEncoderSafetyM1/M2, appelés plus bas — dépendent de CablePosM/Homing qui
   ne sont pas encore connus à ce point du cycle). 1 cycle de retard assumé, même
   principe que HomingRefRaw (Partie10 §9bis) — voir en-tête FB_Modes.st.
   ═══════════════════════════════════════════════════════════════ *)

instModes(
    Enable              := TRUE,
    Reset               := MachineReset_IHM,

    EmergencyStopOk     := GVL_IN.EmergencyStopOk,
    ModeRequest         := GVL_Modes_Stub.ModeRequest_IHM,      // 🖥️ Sélecteur forceable
    PasswordOk          := GVL_Modes_Stub.PasswordOk_IHM,       // 🖥️ Stub authentification MAINT_N2
    OverrideSyncRequest := GVL_Modes_Stub.OverrideSyncRequest_IHM,
    EncoderFaultPresent := EncoderFaultPresent                  // 1 cycle de retard (voir ci-dessus)
);

// 2. ACQUISITION DU GESTE OPÉRATEUR SÉCURISÉ

(* ═══════════════════════════════════════════════════════════════
   🕹️ Appel du traitement joystick (version ST)
   ───────────────────────────────────────────────────────────────
   Câble les E/S physiques sur le FB, qui réalise en interne :
   calibration ➜ filtrage ➜ rampe ➜ % .
   📤 Résultat exploitable : FB_Joystick_0.AxisCmdX / .AxisCmdY
   📄 Doc métier : DOC/AF_Partie8_Fonction_Joystick_v1.1.md
   ═══════════════════════════════════════════════════════════════ *)

FB_Joystick_0(
    // 🟢 --- Autorisations & sécurité ---
    Enable          := GVL_DEBUG.DBG_True,      // ⚠️ DEBUG : remplacer par autorisation réelle
    EmergencyStopOk := GVL_IN.EmergencyStopOk,
    Reset           := MachineReset_IHM,
    NeutralXMem     := GVL_PERSISTENT.JoystickNeutralX, // 🕹️ Point neutre X persistant global
    NeutralYMem     := GVL_PERSISTENT.JoystickNeutralY, // 🕹️ Point neutre Y persistant global


    // 🔌 --- État du bus CANopen (joystick) ---
    BusCanOpenOP    := instDiagCanOpen.busCanOpen,        // 📡 nœud CAN présent
    JoystickOP      := instDiagCanOpen.Joystick,          // 📡 esclave en mode opérationnel

    // 📥 --- Entrées brutes joystick ---
    RawX            := JoyXRaw_ANA1,            // 🕹️ axe X brut (0..10000)
    RawY            := JoyYRaw_ANA2,            // 🕹️ axe Y brut (0..10000)
    RawButton       := JoyBtnRaw,               // 🔘 bouton brut

    // 🎯 --- Calibration ---
    Calibrate       := GVL_IHM.Joystick.Calibrate,                   // 🎯 Bouton recalage neutre IHM (front)

    // 🎛️ --- Paramètres de traitement ---
    InvertX         := FALSE,
    InvertY         := FALSE,
    Deadband        := 10.0,                    // 🔧 2026-07-02 (demande utilisateur) : 5.0 → 10.0 %
    FilterTime      := TIME#100ms,
    AccelRate       := 50.0,
    DecelRate       := 150.0
);

(* ═══════════════════════════════════════════════════════════════
   🧲 3. CODEUR — Acquisition + mise à l'échelle + homing (M1=COD1, M2=COD2)
   ───────────────────────────────────────────────────────────────
   ✅ Canaux COD1_* ET COD2_* câblés en I/O Mapping (matériel réel,
      COD2 mappé 2026-07-02 — plus de stub `GVL_Encoder_M2_Stub`, retiré).
   🎯 Ordre d'appel PAR TREUIL : Abs → Scale → Homing (voir en-tête
      fichier — dépendance croisée Abs↔Homing assumée à 1 cycle près).
   ═══════════════════════════════════════════════════════════════ *)

// 🛠️ --- SIMULATION SUR BANC DE TEST (Winches M1/M2) ---
// Actif uniquement si GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST est TRUE.
// Permet de simuler le mouvement des treuils et le homing sans matériel connecté.
IF GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST THEN
    // Treuil M1
    IF COD1_PresettTrigCmd = 2 THEN
        SimulatedM1Raw := COD1_PresetValue; // Simule le recalage matériel lors de la commande de preset (homing)
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
        SimulatedM2Raw := COD2_PresetValue; // Simule le recalage matériel lors de la commande de preset (homing)
    ELSIF GVL_OUT.M2RelayFwd THEN
        SimulatedM2Raw := SimulatedM2Raw + REAL_TO_UDINT(instWinchM2.SpeedRamp.Current * 0.1);
    ELSIF GVL_OUT.M2RelayRev THEN
        IF SimulatedM2Raw >= REAL_TO_UDINT(instWinchM2.SpeedRamp.Current * 0.1) THEN
            SimulatedM2Raw := SimulatedM2Raw - REAL_TO_UDINT(instWinchM2.SpeedRamp.Current * 0.1);
        ELSE
            SimulatedM2Raw := 0;
        END_IF;
    END_IF;

    // Utilisation des positions simulées uniquement si le codeur physique n'est PAS opérationnel
    // (permet de tester le vrai codeur sur table même avec le bypass contacteurs actif).
    IF NOT instDiagEthercat.EncoderM1.Operational THEN
        M1_RawPosToUse := SimulatedM1Raw;
    ELSE
        M1_RawPosToUse := COD1_PosValue;
    END_IF;

    IF NOT instDiagEthercat.EncoderM2.Operational THEN
        M2_RawPosToUse := SimulatedM2Raw;
    ELSE
        M2_RawPosToUse := COD2_PosValue;
    END_IF;
ELSE
    // Utilisation inconditionnelle des valeurs réelles
    M1_RawPosToUse := COD1_PosValue;
    M2_RawPosToUse := COD2_PosValue;
END_IF;

instEncoderAbsM1(
    Enable              := TRUE,
    Reset               := (M1_Reset_IHM OR MachineReset_IHM),

    EmergencyStopOk     := GVL_IN.EmergencyStopOk,
    Mode                := instModes.Mode,

    RawPosIn            := M1_RawPosToUse,                  // 📡 Sélecteur simulation/physique (banc de test)
    AlarmsIn            := SEL(GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST, COD1_Alarms, 0), // 📡 Bypass alarmes sur banc
    WarningsIn          := SEL(GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST, COD1_Warnings, 0), // 📡 Bypass warnings sur banc
    SlaveOperational    := instDiagEthercat.EncoderM1.Operational OR GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST,
    PresetRequest       := instHomingM1.PresetRequest,      // ✅ 2026-07-02 (1 cycle de retard, voir en-tête)
    PresetValue         := instHomingM1.PresetValue         // ✅ 2026-07-02
);
// 📤 Sorties preset → RxPDO réels (I/O Mapping déjà existant, canaux COD1)
COD1_PresettTrigCmd := instEncoderAbsM1.PresetTriggerCmd;
COD1_CodeSeqTrigCmd := instEncoderAbsM1.CodeSeqTriggerCmd;
COD1_PresetValue    := instEncoderAbsM1.PresetValueOut;

instEncoderScaleM1(
    RawPos          := instEncoderAbsM1.RawPos,
    HomingRefRaw    := instHomingM1.HomingRefRaw,           // ✅ 2026-07-02 (1 cycle de retard, voir en-tête)
    CableM_PerRev   := 2.0,  // Périmètre tambour confirmé 2026-07-02 (était 1.5 provisoire)
    PointsPerRev    := 8192
);

(* 🎯 Homing M1 (flux nominal) — bouton IHM (stub) + capteur position haute (stub GVL_Homing_Stub, commun M1+M2) *)
instHomingM1(
    Enable               := TRUE,
    Calib                := GVL_PERSISTENT.CalibM1,          // 🧲 Données persistantes (survit aux téléchargements)
    Reset                := (M1_Reset_IHM OR MachineReset_IHM),

    EmergencyStopOk      := GVL_IN.EmergencyStopOk,
    Mode                 := instModes.Mode,

    Home                 := (StubHomeButton_IHM AND ((HomingMode_IHM = 1) OR (HomingMode_IHM = 3))),  // 🖥️ GVL_Encoder_Stub — mode homing (1=M1seul, 2=M2seul, 3=Both)
    ConfirmCoherence     := M1_ConfirmCoherence_IHM,          // 🖥️ GVL_Encoder_Stub
    TopPositionSensor    := GVL_IN.TopPositionSensor,
    TopSensorPositionM   := M1_TopSensorPositionM,           // RETAIN, réglable (§ calibration Partie10 §7bis)
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

    RawPosIn            := M2_RawPosToUse,                  // 📡 Sélecteur simulation/physique (banc de test)
    AlarmsIn            := SEL(GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST, COD2_Alarms, 0), // 📡 Bypass alarmes sur banc
    WarningsIn          := SEL(GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST, COD2_Warnings, 0), // 📡 Bypass warnings sur banc
    SlaveOperational    := instDiagEthercat.EncoderM2.Operational OR GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST,
    PresetRequest       := instHomingM2.PresetRequest,      // ✅ 2026-07-02 (1 cycle de retard, voir en-tête)
    PresetValue         := instHomingM2.PresetValue         // ✅ 2026-07-02
);
// 📤 Sorties preset → RxPDO réels (I/O Mapping mappé 2026-07-02, comme COD1_PresettTrigCmd)
COD2_PresettTrigCmd := instEncoderAbsM2.PresetTriggerCmd;
COD2_CodeSeqTrigCmd := instEncoderAbsM2.CodeSeqTriggerCmd;
COD2_PresetValue    := instEncoderAbsM2.PresetValueOut;

instEncoderScaleM2(
    RawPos          := instEncoderAbsM2.RawPos,
    HomingRefRaw    := instHomingM2.HomingRefRaw,           // ✅ 2026-07-02 (1 cycle de retard, voir en-tête)
    CableM_PerRev   := 2.0,  // Périmètre tambour confirmé 2026-07-02 (était 1.5 provisoire)
    PointsPerRev    := 8192
);

(* 🎯 Homing M2 (flux nominal) — MÊME bouton IHM que M1 (référencement simultané, Partie10 §1) *)
instHomingM2(
    Enable               := TRUE,
    Calib                := GVL_PERSISTENT.CalibM2,          // 🧲 Données persistantes (survit aux téléchargements)
    Reset                := (M2_Reset_IHM OR MachineReset_IHM),

    EmergencyStopOk      := GVL_IN.EmergencyStopOk,
    Mode                 := instModes.Mode,

    Home                 := (StubHomeButton_IHM AND ((HomingMode_IHM = 2) OR (HomingMode_IHM = 3))),  // 🖥️ GVL_Encoder_Stub — mode homing (1=M1seul, 2=M2seul, 3=Both)
    ConfirmCoherence     := M2_ConfirmCoherence_IHM,          // 🖥️ GVL_Encoder_Stub
    TopPositionSensor    := GVL_IN.TopPositionSensor,
    TopSensorPositionM   := M2_TopSensorPositionM,           // RETAIN, réglable (§ calibration Partie10 §7bis)
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

(* ═══════════════════════════════════════════════════════════════
   🛡️ 3bis. FB_ENCODER_SAFETY — bornage ±99m + relais HomingSuspect (1 par treuil)
   ───────────────────────────────────────────────────────────────
   Répond à l'incident CablePosM≈4096m (RETAIN Calib remis à 0 après refactor).
   EncoderFaultPresent (OR M1/M2) alimente instModes AU CYCLE SUIVANT (voir §1bis2).
   ═══════════════════════════════════════════════════════════════ *)

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

EncoderFaultPresent := EncoderFaultPresentM1 OR EncoderFaultPresentM2;   // 📤 Consommé par instModes AU CYCLE SUIVANT

(* ═══════════════════════════════════════════════════════════════
   ⚖️ 3ter. FB_WINCHSYNC — surveillance écart M1/M2 (squelette, PAS de correction)
   ───────────────────────────────────────────────────────────────
   Enable := NOT OverrideSync (Partie5 §2 "Logique d'override" — actionnable
   UNIQUEMENT en MAINT_N2 via GVL_Modes_Stub.OverrideSyncRequest_IHM).
   ═══════════════════════════════════════════════════════════════ *)

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
    SyncToleranceM  := GVL_PERSISTENT.WinchSyncTolerance_M,
    ActiveOffsetM   := instGrappin.ActiveOffsetM,
    
    // Command mapping for command coherence check
    RelayFwdM1      := instWinchM1.RelayFwd,
    RelayFwdM2      := instWinchM2.RelayFwd,
    RelayRevM1      := instWinchM1.RelayRev,
    RelayRevM2      := instWinchM2.RelayRev,
    Contactor1_M1   := instWinchM1.Contactor1,
    Contactor1_M2   := instWinchM2.Contactor1,
    Contactor2_M1   := instWinchM1.Contactor2,
    Contactor2_M2   := instWinchM2.Contactor2,
    Contactor3_M1   := instWinchM1.Contactor3,
    Contactor3_M2   := instWinchM2.Contactor3,
    Contactor4_M1   := instWinchM1.Contactor4,
    Contactor4_M2   := instWinchM2.Contactor4
);

(* ═══════════════════════════════════════════════════════════════
   🔌 4. SÉCURITÉ MÉTIER TREUIL — FB_Safety_Winch (1 instance par treuil)
   ───────────────────────────────────────────────────────────────
   Périmètre : perte joystick/CAN (partagée) + perte codeur DE CE
   TREUIL (câblé, lot Codeur). SafeStop consommé par le FB_Winch du
   MÊME treuil (Partie10 §7 : split M1/M2 par composition, 2 instances).
   ═══════════════════════════════════════════════════════════════ *)

instSafetyWinchM1(
    Enable              := TRUE,
    Reset               := MachineReset_IHM,

    EmergencyStopOk     := GVL_IN.EmergencyStopOk,
    Mode                := instModes.Mode,
    OverrideSync        := instModes.OverrideSync,   // 🆕 Procédure récupération mou câble

    JoystickOnline      := instDiagCanOpen.Joystick.Online,
    JoystickOperational := instDiagCanOpen.Joystick.Operational,
    EncoderAvailable    := instEncoderAbsM1.EncoderAvailable,
    ThermalFeedback     := NOT GVL_IN.M1ThermalFeedback,
    SlackCableDetected  := NOT GVL_IN.SlackCableSwitch,
    PhaseRotationOk     := GVL_IN.PhaseRotationOk,
    TopPositionSensor   := GVL_IN.TopPositionSensor,
    InReferencingMode   := instHomingM1.Busy,
    CablePosM           := instEncoderScaleM1.CablePosM,
    CableLimitDescentM  := GVL_PERSISTENT.CableLimitDescent_M
);

instSafetyWinchM2(
    Enable              := TRUE,
    Reset               := MachineReset_IHM,

    EmergencyStopOk     := GVL_IN.EmergencyStopOk,
    Mode                := instModes.Mode,
    OverrideSync        := instModes.OverrideSync,   // 🆕 Même OverrideSync que M1 (procédure récupération)

    JoystickOnline      := instDiagCanOpen.Joystick.Online,
    JoystickOperational := instDiagCanOpen.Joystick.Operational,
    EncoderAvailable    := instEncoderAbsM2.EncoderAvailable,
    ThermalFeedback     := NOT GVL_IN.M2ThermalFeedback,
    SlackCableDetected  := NOT GVL_IN.SlackCableSwitch,
    PhaseRotationOk     := GVL_IN.PhaseRotationOk,
    TopPositionSensor   := GVL_IN.TopPositionSensor,
    InReferencingMode   := instHomingM2.Busy,
    CablePosM           := instEncoderScaleM2.CablePosM,
    CableLimitDescentM  := GVL_PERSISTENT.CableLimitDescent_M
);

(* ═══════════════════════════════════════════════════════════════
   🪝 5. TREUILS M1 + M2 — FB_Winch (Maint N1, consigne dupliquée axe Y)
   ───────────────────────────────────────────────────────────────
   ⚠️ M2 dupliqué sur le MÊME axe Y que M1 (choix acté 2026-07-02) :
      les deux treuils reçoivent la même consigne, SANS FB_WinchSync
      réel (le codeur sert à la mesure/sécurité de ce lot, pas encore
      à une régulation d'écart M1/M2 — voir DOC/AF_Partie9 §9).
   ✅ SUPERSEDÉ (2026-07-03quattuordecies) : `GVL_Winch_M1_Stub.st`/`GVL_Winch_M2_Stub.st`
      supprimés — tout le matériel M1/M2 (relais, contacteurs, retour frein) est
      désormais réel, câblé en I/O Mapping (`_DI`/`_DQ`/`_RQ`, voir §0 et §7bis).
   ═══════════════════════════════════════════════════════════════ *)

// 🪣 Appel du bloc Grappin (entre l'acquisition codeurs/joystick et les winches)
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
    Config              := GVL_PERSISTENT.GrappinConfig,
    TimeoutDuration     := GVL_IHM.Grappin.TimeoutDuration,  // 🆕 Configurable depuis IHM
    GrappinState        := GVL_PERSISTENT.GrappinState
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

// Construction de la table de paliers active de M2 (force tous les contacteurs à FALSE si ForceSlowSpeed)
IF instGrappin.M2_ForceSlowSpeed THEN
    M2_SpeedStepTableActive.P1R1 := FALSE; M2_SpeedStepTableActive.P1R2 := FALSE; M2_SpeedStepTableActive.P1R3 := FALSE; M2_SpeedStepTableActive.P1R4 := FALSE;
    M2_SpeedStepTableActive.P2R1 := FALSE; M2_SpeedStepTableActive.P2R2 := FALSE; M2_SpeedStepTableActive.P2R3 := FALSE; M2_SpeedStepTableActive.P2R4 := FALSE;
    M2_SpeedStepTableActive.P3R1 := FALSE; M2_SpeedStepTableActive.P3R2 := FALSE; M2_SpeedStepTableActive.P3R3 := FALSE; M2_SpeedStepTableActive.P3R4 := FALSE;
    M2_SpeedStepTableActive.P4R1 := FALSE; M2_SpeedStepTableActive.P4R2 := FALSE; M2_SpeedStepTableActive.P4R3 := FALSE; M2_SpeedStepTableActive.P4R4 := FALSE;
    M2_SpeedStepTableActive.P5R1 := FALSE; M2_SpeedStepTableActive.P5R2 := FALSE; M2_SpeedStepTableActive.P5R3 := FALSE; M2_SpeedStepTableActive.P5R4 := FALSE;
    M2_SpeedStepTableActive.StepThreshold_Pct := GVL_PERSISTENT.WinchM2SpeedStepTable.StepThreshold_Pct;
ELSE
    M2_SpeedStepTableActive := GVL_PERSISTENT.WinchM2SpeedStepTable;
END_IF;

// --- CALCUL DES LIMITES BASSES ACTIVES ET DU BLOCAGE DE DESCENTE ---
// 1. Limite basse active M1 (le maximum entre la longueur de câble max et la limite légale en SEMI_AUTO)
BottomLimitM1_Active := GVL_PERSISTENT.CableLimitDescent_M;
IF (instModes.Mode = E_Mode.SEMI_AUTO) AND GVL_PERSISTENT.LimitLegalEnabled THEN
    BottomLimitM1_Active := MAX(BottomLimitM1_Active, GVL_PERSISTENT.LimitLegalDepthMinAllowed);
END_IF;

// 2. Limite basse active M2
BottomLimitM2_Active := GVL_PERSISTENT.CableLimitDescent_M;
IF (instModes.Mode = E_Mode.SEMI_AUTO) AND GVL_PERSISTENT.LimitLegalEnabled THEN
    BottomLimitM2_Active := MAX(BottomLimitM2_Active, GVL_PERSISTENT.LimitLegalDepthMinAllowed);
END_IF;

// 3. ForbidDescent M1 : Défaut safety (mou de câble / max câble) OR Limite légale en SEMI_AUTO
ForbidDescentM1_Active := instSafetyWinchM1.ForbidDescent
                          OR ((instModes.Mode = E_Mode.SEMI_AUTO)
                              AND GVL_PERSISTENT.LimitLegalEnabled
                              AND (instEncoderScaleM1.CablePosM <= GVL_PERSISTENT.LimitLegalDepthMinAllowed));

// 4. ForbidDescent M2
ForbidDescentM2_Active := instSafetyWinchM2.ForbidDescent
                          OR ((instModes.Mode = E_Mode.SEMI_AUTO)
                              AND GVL_PERSISTENT.LimitLegalEnabled
                              AND (instEncoderScaleM2.CablePosM <= GVL_PERSISTENT.LimitLegalDepthMinAllowed));


instWinchM1(
    Enable                  := StubMachineEnableN1,           // ⚠️ Stub Maint N1 — à remplacer par FB_Modes
    Reset                   := MachineReset_IHM,

    EmergencyStopOk         := GVL_IN.EmergencyStopOk,
    Mode                    := instModes.Mode,

    StartStop               := FB_Joystick_0.AxisCmdY.StartStop AND NOT instGrappin.Busy, // Bloqué pendant le mouvement grappin
    SafeStop                := instSafetyWinchM1.SafeStop OR ((instWinchSync.ErrorId AND 16#0002) <> 16#0000),
    ForbidDescent           := ForbidDescentM1_Active,           // 🆕 Mou de câble / longueur max / limite légale
    ForbidAscent            := instSafetyWinchM1.ForbidAscent,   // 🆕 Fin de course haut
    Direction               := FB_Joystick_0.AxisCmdY.Direction,
    SpeedRefPct             := FB_Joystick_0.AxisCmdY.SpeedRef,
    SpeedStepTable          := GVL_PERSISTENT.WinchM1SpeedStepTable,
    MaxStepDescente         := GVL_PERSISTENT.WinchM1MaxStepDescente,    // 💾 Persistant
    ContactorFeedbackFwd    := GVL_IN.M1ContactorFeedbackFwd,
    ContactorFeedbackRev    := GVL_IN.M1ContactorFeedbackRev,
    BrakeFeedback           := GVL_IN.M1BrakeFeedback,
    RampAccelRate           := GVL_PERSISTENT.WinchM1RampAccelRate_Pct,      // 💾 Persistant
    RampDecelNormalRate     := GVL_PERSISTENT.WinchM1RampDecelNormal_Pct, // 💾 Persistant
    RampDecelFastRate       := GVL_PERSISTENT.WinchM1RampDecelFast_Pct,   // 💾 Persistant — CRITIQUE
    Homed                   := instHomingM1.Homed,
    CablePosM               := instEncoderScaleM1.CablePosM,
    TopLimitM               := GVL_PERSISTENT.HomingTargetM1_M,
    BottomLimitM            := BottomLimitM1_Active,
    SlowdownDistanceM       := GVL_PERSISTENT.WinchSlowdownDistance_M,
    SlowSpeedPct            := GVL_PERSISTENT.WinchSlowSpeedPct
);

instWinchM2(
    Enable                  := StubMachineEnableN1,           // ⚠️ Même stub Maint N1 que M1 — à remplacer par FB_Modes
    Reset                   := MachineReset_IHM,

    EmergencyStopOk         := GVL_IN.EmergencyStopOk,
    Mode                    := instModes.Mode,

    StartStop               := M2_StartStop_Active,           // Arbitré grappin
    SafeStop                := instSafetyWinchM2.SafeStop OR ((instWinchSync.ErrorId AND 16#0002) <> 16#0000),
    ForbidDescent           := ForbidDescentM2_Active,           // 🆕 Mou de câble / longueur max / limite légale
    ForbidAscent            := instSafetyWinchM2.ForbidAscent,   // 🆕 Fin de course haut
    Direction               := M2_Direction_Active,           // Arbitré grappin
    SpeedRefPct             := M2_SpeedRef_Active,            // Arbitré grappin
    SpeedStepTable          := M2_SpeedStepTableActive,       // Arbitrée grappin (sans contacteurs si vitesse lente forcée)
    MaxStepDescente         := GVL_PERSISTENT.WinchM2MaxStepDescente,    // 💾 Persistant
    ContactorFeedbackFwd    := GVL_IN.M2ContactorFeedbackFwd,
    ContactorFeedbackRev    := GVL_IN.M2ContactorFeedbackRev,
    BrakeFeedback           := GVL_IN.M2BrakeFeedback,
    RampAccelRate           := GVL_PERSISTENT.WinchM2RampAccelRate_Pct,      // 💾 Persistant
    RampDecelNormalRate     := GVL_PERSISTENT.WinchM2RampDecelNormal_Pct, // 💾 Persistant
    RampDecelFastRate       := GVL_PERSISTENT.WinchM2RampDecelFast_Pct,   // 💾 Persistant — CRITIQUE
    Homed                   := instHomingM2.Homed,
    CablePosM               := instEncoderScaleM2.CablePosM,
    TopLimitM               := GVL_PERSISTENT.HomingTargetM2_M,
    BottomLimitM            := BottomLimitM2_Active,
    SlowdownDistanceM       := GVL_PERSISTENT.WinchSlowdownDistance_M,
    SlowSpeedPct            := GVL_PERSISTENT.WinchSlowSpeedPct
);

(* ═══════════════════════════════════════════════════════════════
   ↔️ 6. CHARIOT M3 — FB_Chariot (axe X, mode DEGRADED_IO figé)
   ───────────────────────────────────────────────────────────────
   Intégré 2026-07-02 (Partie11 §7, recommandation "option 1") : mode
   ETHERCAT non câblé (TBD protocole AC600, voir Partie11 §4) — CommMode
   figé DEGRADED_IO (relais sens + PV/GV), stubs neutres sur les entrées
   ETHERCAT (jamais utilisées tant que CommMode ne bascule pas).
   🔧 2026-07-02 : renommage métier Translation→Chariot (préfixe I/O
   physique M3 inchangé). `M3_BrakeCmd` désormais câblé en I/O Mapping
   RÉEL (retiré de GVL_Chariot_M3_Stub, reste sinon STUB logiciel).
   ⚠️ AVANT tout essai réel : Partie11 §4bis (paramétrage AC600,
   verrouillage source de commande Terminal) impératif.
   ═══════════════════════════════════════════════════════════════ *)

instSafetyChariotM3(
    Enable              := TRUE,
    Reset               := MachineReset_IHM,

    EmergencyStopOk     := GVL_IN.EmergencyStopOk,
    Mode                := instModes.Mode,

    JoystickOnline      := instDiagCanOpen.Joystick.Online,
    JoystickOperational := instDiagCanOpen.Joystick.Operational,
    PhaseRotationOk     := GVL_IN.PhaseRotationOk
);

// 🎯 SÉLECTEUR STUB MAINTENANCE (2026-07-02, demande utilisateur) — arbitre M3_PositionSensorTarget
// parmi les 4 capteurs position RÉELS du chariot, en attendant FB_Cycle (pas encore codé, qui
// fera cette sélection en exploitation normale — Partie11 §9bis). PosFosse1/PosFosse2/
// PosMaintenance/PosTremie : noms exacts I/O Mapping (Device.export).
CASE StubChariotPositionSelect_IHM OF
    1: M3_PositionSensorTarget := GVL_IN.ChariotPosFosse1;
    2: M3_PositionSensorTarget := GVL_IN.ChariotPosFosse2;
    3: M3_PositionSensorTarget := GVL_IN.ChariotPosMaintenance;
    4: M3_PositionSensorTarget := GVL_IN.ChariotPosTremie;
ELSE
    M3_PositionSensorTarget := FALSE;   // 0 ou valeur hors plage = aucun capteur sélectionné
END_CASE;

instChariotM3(
    Enable                  := StubMachineEnableN1,           // ⚠️ Même stub Maint N1 que Winch — à remplacer par FB_Modes
    Reset                   := MachineReset_IHM,

    EmergencyStopOk         := GVL_IN.EmergencyStopOk,
    Mode                    := instModes.Mode,

    StartStop               := FB_Joystick_0.AxisCmdX.StartStop,
    SafeStop                := instSafetyChariotM3.SafeStop,
    CommMode                := E_ChariotCommMode.DEGRADED_IO,  // ⚠️ Figé (EtherCAT AC600 TBD, Partie11 §4/§7)
    Direction               := FB_Joystick_0.AxisCmdX.Direction,
    SpeedRefPct             := FB_Joystick_0.AxisCmdX.SpeedRef,
    PositionSensorTarget    := M3_PositionSensorTarget,      // 🎯 Arbitré par le sélecteur STUB ci-dessus
    DriveStatusWord         := 0,                            // 🔴 TBD ETHERCAT (Partie11 §4) — inerte en DEGRADED_IO
    DriveActualFreqHz       := 0.0,                          // 🔴 TBD ETHERCAT — inerte en DEGRADED_IO
    ContactorFeedbackFwd    := M3_ContactorFeedbackFwd,      // 🧪 STUB GVL_Chariot_M3_Stub
    ContactorFeedbackRev    := M3_ContactorFeedbackRev,      // 🧪 STUB GVL_Chariot_M3_Stub
    DriveFaultFeedback      := M3_DriveFaultFeedback,        // 🧪 STUB GVL_Chariot_M3_Stub (toujours FALSE, non câblé)
    BrakeFeedback           := SEL(GVL_IHM.Chariot.BypassBrakeFeedback, GVL_IN.M3BrakeFeedback, instChariotM3.BrakeCmd)
);

// 📤 Sorties chariot M3 STUB (GVL_Chariot_M3_Stub, pas de matériel réel — pas conditionnées,
// voir en-tête FB_OutputsMachine.st) : RelayFwd/Rev/RelaySpeedGv
M3_RelayFwd     := instChariotM3.RelayFwd;
M3_RelayRev     := instChariotM3.RelayRev;
M3_RelaySpeedGv := instChariotM3.RelaySpeedGv;

// 🧪 SIMULATION (stub GVL_Chariot_M3_Stub) — voir note Winch M1 ci-dessus.
M3_ContactorFeedbackFwd := M3_RelayFwd;
M3_ContactorFeedbackRev := M3_RelayRev;

(* ═══════════════════════════════════════════════════════════════
   🖥️ MAPPING IHM ↔ PROCESSUS
   ───────────────────────────────────────────────────────────────
   Ce bloc assure la copie bidirectionnelle des consignes/paramètres
   et des états/diagnostics vers GVL_IHM pour affichage écran.
   ═══════════════════════════════════════════════════════════════ *)

// --- 1. INITIALISATION IHM DEPUIS GVL_PERSISTENT (si valeur IHM encore à zéro au boot)
// Les paramètres IHM sont affichés depuis GVL_PERSISTENT, ré-écrits à chaque cycle
// vers GVL_PERSISTENT pour sauvegarder les réglages opérateur.
IF GVL_IHM.WinchM1.TopSensorPositionM = 0.0 THEN
    GVL_IHM.WinchM1.TopSensorPositionM  := GVL_PERSISTENT.HomingTargetM1_M;
    GVL_IHM.WinchM1.MaxStepDescente     := GVL_PERSISTENT.WinchM1MaxStepDescente;
    GVL_IHM.WinchM1.RampAccelRate       := GVL_PERSISTENT.WinchM1RampAccelRate_Pct;
    GVL_IHM.WinchM1.RampDecelNormalRate := GVL_PERSISTENT.WinchM1RampDecelNormal_Pct;
    GVL_IHM.WinchM1.RampDecelFastRate   := GVL_PERSISTENT.WinchM1RampDecelFast_Pct;
    GVL_IHM.WinchM1.CableLimitDescentM  := GVL_PERSISTENT.CableLimitDescent_M;
    GVL_IHM.WinchM1.SlowdownDistanceM   := GVL_PERSISTENT.WinchSlowdownDistance_M;
    GVL_IHM.WinchM1.SlowSpeedPct        := GVL_PERSISTENT.WinchSlowSpeedPct;
END_IF;

IF GVL_IHM.WinchM2.TopSensorPositionM = 0.0 THEN
    GVL_IHM.WinchM2.TopSensorPositionM  := GVL_PERSISTENT.HomingTargetM2_M;
    GVL_IHM.WinchM2.MaxStepDescente     := GVL_PERSISTENT.WinchM2MaxStepDescente;
    GVL_IHM.WinchM2.RampAccelRate       := GVL_PERSISTENT.WinchM2RampAccelRate_Pct;
    GVL_IHM.WinchM2.RampDecelNormalRate := GVL_PERSISTENT.WinchM2RampDecelNormal_Pct;
    GVL_IHM.WinchM2.RampDecelFastRate   := GVL_PERSISTENT.WinchM2RampDecelFast_Pct;
    GVL_IHM.WinchM2.CableLimitDescentM  := GVL_PERSISTENT.CableLimitDescent_M;
    GVL_IHM.WinchM2.SlowdownDistanceM   := GVL_PERSISTENT.WinchSlowdownDistance_M;
    GVL_IHM.WinchM2.SlowSpeedPct        := GVL_PERSISTENT.WinchSlowSpeedPct;
END_IF;

IF GVL_IHM.Sync.SyncToleranceM = 0.0 THEN
    GVL_IHM.Sync.SyncToleranceM         := GVL_PERSISTENT.WinchSyncTolerance_M;
END_IF;

IF GVL_IHM.Grappin.Config.OffsetOpenM = 0.0 AND GVL_IHM.Grappin.Config.OffsetCloseM = 0.0 THEN
    GVL_IHM.Grappin.Config := GVL_PERSISTENT.GrappinConfig;
    GVL_IHM.Grappin.TimeoutDuration := T#30s;
END_IF;

IF GVL_IHM.LimitLegalDepthMinAllowed = 0.0 THEN
    GVL_IHM.LimitLegalDepthMinAllowed := GVL_PERSISTENT.LimitLegalDepthMinAllowed;
    GVL_IHM.LimitLegalEnabled         := GVL_PERSISTENT.LimitLegalEnabled;
END_IF;

IF GVL_IHM.Modes.ModeRequest = E_Mode.DISABLE THEN
    GVL_IHM.Modes.ModeRequest := E_Mode.MAINT_N1;
END_IF;

// --- 2. PROPAGATION DES PARAMÈTRES IHM → GVL_PERSISTENT (sauvegarde des réglages opérateur)
GVL_PERSISTENT.HomingTargetM1_M          := GVL_IHM.WinchM1.TopSensorPositionM;
GVL_PERSISTENT.HomingTargetM2_M          := GVL_IHM.WinchM2.TopSensorPositionM;
GVL_PERSISTENT.WinchM1MaxStepDescente    := GVL_IHM.WinchM1.MaxStepDescente;
GVL_PERSISTENT.WinchM2MaxStepDescente    := GVL_IHM.WinchM2.MaxStepDescente;
GVL_PERSISTENT.WinchM1RampAccelRate_Pct  := GVL_IHM.WinchM1.RampAccelRate;
GVL_PERSISTENT.WinchM1RampDecelNormal_Pct := GVL_IHM.WinchM1.RampDecelNormalRate;
GVL_PERSISTENT.WinchM1RampDecelFast_Pct  := GVL_IHM.WinchM1.RampDecelFastRate;
GVL_PERSISTENT.WinchM2RampAccelRate_Pct  := GVL_IHM.WinchM2.RampAccelRate;
GVL_PERSISTENT.WinchM2RampDecelNormal_Pct := GVL_IHM.WinchM2.RampDecelNormalRate;
GVL_PERSISTENT.WinchM2RampDecelFast_Pct  := GVL_IHM.WinchM2.RampDecelFastRate;
GVL_PERSISTENT.WinchSyncTolerance_M      := GVL_IHM.Sync.SyncToleranceM;
GVL_PERSISTENT.GrappinConfig             := GVL_IHM.Grappin.Config;
// Propagation synchrone bidirectionnelle de la limite de câble
IF GVL_IHM.WinchM1.CableLimitDescentM <> GVL_PERSISTENT.CableLimitDescent_M THEN
    GVL_PERSISTENT.CableLimitDescent_M := GVL_IHM.WinchM1.CableLimitDescentM;
ELSIF GVL_IHM.WinchM2.CableLimitDescentM <> GVL_PERSISTENT.CableLimitDescent_M THEN
    GVL_PERSISTENT.CableLimitDescent_M := GVL_IHM.WinchM2.CableLimitDescentM;
END_IF;
GVL_IHM.WinchM1.CableLimitDescentM := GVL_PERSISTENT.CableLimitDescent_M;
GVL_IHM.WinchM2.CableLimitDescentM := GVL_PERSISTENT.CableLimitDescent_M;

// Propagation synchrone bidirectionnelle de la distance de ralentissement
IF GVL_IHM.WinchM1.SlowdownDistanceM <> GVL_PERSISTENT.WinchSlowdownDistance_M THEN
    GVL_PERSISTENT.WinchSlowdownDistance_M := GVL_IHM.WinchM1.SlowdownDistanceM;
ELSIF GVL_IHM.WinchM2.SlowdownDistanceM <> GVL_PERSISTENT.WinchSlowdownDistance_M THEN
    GVL_PERSISTENT.WinchSlowdownDistance_M := GVL_IHM.WinchM2.SlowdownDistanceM;
END_IF;
GVL_IHM.WinchM1.SlowdownDistanceM := GVL_PERSISTENT.WinchSlowdownDistance_M;
GVL_IHM.WinchM2.SlowdownDistanceM := GVL_PERSISTENT.WinchSlowdownDistance_M;

// Propagation synchrone bidirectionnelle de la vitesse de ralentissement
IF GVL_IHM.WinchM1.SlowSpeedPct <> GVL_PERSISTENT.WinchSlowSpeedPct THEN
    GVL_PERSISTENT.WinchSlowSpeedPct := GVL_IHM.WinchM1.SlowSpeedPct;
ELSIF GVL_IHM.WinchM2.SlowSpeedPct <> GVL_PERSISTENT.WinchSlowSpeedPct THEN
    GVL_PERSISTENT.WinchSlowSpeedPct := GVL_IHM.WinchM2.SlowSpeedPct;
END_IF;
GVL_IHM.WinchM1.SlowSpeedPct := GVL_PERSISTENT.WinchSlowSpeedPct;
GVL_IHM.WinchM2.SlowSpeedPct := GVL_PERSISTENT.WinchSlowSpeedPct;
GVL_PERSISTENT.LimitLegalDepthMinAllowed  := GVL_IHM.LimitLegalDepthMinAllowed;
GVL_PERSISTENT.LimitLegalEnabled          := GVL_IHM.LimitLegalEnabled;
GVL_IHM.LimitLegalReached                 := (instModes.Mode = E_Mode.SEMI_AUTO) AND GVL_PERSISTENT.LimitLegalEnabled AND ((instEncoderScaleM1.CablePosM <= GVL_PERSISTENT.LimitLegalDepthMinAllowed) OR (instEncoderScaleM2.CablePosM <= GVL_PERSISTENT.LimitLegalDepthMinAllowed));
GVL_IHM.TopPositionSensorActive           := NOT GVL_IN.TopPositionSensor;   // 🔧 CORRIGÉ 2026-07-04 : TRUE=sain/non atteint côté GVL_IN, "Active" doit être l'inverse
GVL_Encoder_Stub.M1_TopSensorPositionM   := GVL_PERSISTENT.HomingTargetM1_M;
GVL_Encoder_Stub.M2_TopSensorPositionM   := GVL_PERSISTENT.HomingTargetM2_M;

// --- 3. GESTION DES BYPASSES BANC DE TEST ---
// ⚠️ SENS UNIQUE : GVL_DEBUG est le MAÎTRE (valeurs := TRUE au boot depuis GVL_DEBUG.st).
// GVL_IHM.Bypass* sont des MIROIRS pour affichage IHM uniquement.
// Ne PAS écrire GVL_DEBUG depuis GVL_IHM (écraserait l'initialisation := TRUE).
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
GVL_IHM.WinchM1.ForbidDescentActive         := ForbidDescentM1_Active;
GVL_IHM.WinchM1.ForbidAscentActive          := instSafetyWinchM1.ForbidAscent;
GVL_IHM.WinchM1.SlackCableDetected          := NOT GVL_IN.SlackCableSwitch;
GVL_IHM.WinchM1.ThermalFault                := NOT GVL_IN.M1ThermalFeedback;
GVL_IHM.WinchM1.EncoderFault                := NOT instEncoderAbsM1.EncoderAvailable OR instEncoderSafetyM1.EncoderIncoherent;
GVL_IHM.WinchM1.CableLimitDescentReached    := (instSafetyWinchM1.ErrorId AND 16#0040) <> 16#0000;
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
GVL_IHM.WinchM2.ForbidDescentActive         := ForbidDescentM2_Active;
GVL_IHM.WinchM2.ForbidAscentActive          := instSafetyWinchM2.ForbidAscent;
GVL_IHM.WinchM2.SlackCableDetected          := NOT GVL_IN.SlackCableSwitch;
GVL_IHM.WinchM2.ThermalFault                := NOT GVL_IN.M2ThermalFeedback;
GVL_IHM.WinchM2.EncoderFault                := NOT instEncoderAbsM2.EncoderAvailable OR instEncoderSafetyM2.EncoderIncoherent;
GVL_IHM.WinchM2.CableLimitDescentReached    := (instSafetyWinchM2.ErrorId AND 16#0040) <> 16#0000;
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
GVL_IHM.Grappin.State                       := GVL_PERSISTENT.GrappinState;

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

// --- 11. COPIE DES STATUTS DIAGNOSTICS RÉSEAU VERS GVL_IHM ---
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

(* ═══════════════════════════════════════════════════════════════
   📤 7. GVL_OUTPUTS + FB_OUTPUTSMACHINE — conditionnement SORTIES réelles (tard)
   ───────────────────────────────────────────────────────────────
   Simples affectations vers `GVL_OUT` (naturel en LD : 1 rung = 1 bobine), puis
   `FB_OutputsMachine` appelé SANS PARAMÈTRE — il lit `GVL_OUT.Xxx` en interne
   et écrit DIRECTEMENT les I/O réels (`_DQ`/`_RQ`). Voir en-tête FB_OutputsMachine.st.
   ═══════════════════════════════════════════════════════════════ *)

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

(* ═══════════════════════════════════════════════════════════════
   🧨 8. POWERCUTOFF — Coupure puissance amont REDONDANTE (2026-07-04)
   ───────────────────────────────────────────────────────────────
   Deux relais (A et B) commandés SIMULTANÉMENT par le même signal.
   Contacts câblés EN SÉRIE côté puissance : si un relais colle (contact soudé),
   l'autre assure quand même la coupure. Diversité matérielle : 2 cartes I/O différentes.
   Aujourd'hui PowerCutOff = FALSE sur tous les FB Safety (TBD — logique à définir).
   ═══════════════════════════════════════════════════════════════ *)

PowerCutOff_A_RQ := instSafetyWinchM1.PowerCutOff OR instSafetyWinchM2.PowerCutOff
                    OR instSafetyChariotM3.PowerCutOff;
PowerCutOff_B_RQ := PowerCutOff_A_RQ;  // 🧨 Canal B = même signal — redondance matérielle par 2 cartes distinctes

