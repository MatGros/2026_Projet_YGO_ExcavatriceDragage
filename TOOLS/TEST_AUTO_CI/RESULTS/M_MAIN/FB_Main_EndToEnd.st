(* =======================================================================
   🏰 FB_Main_EndToEnd : Mégabloc Machine d'Intégration Globale
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Instancie et chaîne en boucle fermée les 6 programmes de l'automate :
             PRG_02 (Acquisition) -> PRG_03 (Modes & Cycle) -> PRG_04 (Treuils/Benne)
             -> PRG_05 (Translation) -> PRG_06 (Outputs) -> PRG_07 (Supervision).
   🔄 Intègre également le rebouclage physique vers PRG_02 (SimBench).
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Main_EndToEnd
VAR_INPUT
    // === 🕹️ Entrées Physiques Opérateur & Machine ===
    JoyRawX                 : INT := 0;
    JoyRawY                 : INT := 0;
    JoyDeadmanBtn           : BOOL := FALSE;
    BtnResetMachine         : BOOL := FALSE;
    
    // Commandes Modes IHM
    CmdMode                 : E_Mode := E_Mode.MAINT_N1;
    CmdWinchSelect          : INT := 0; // 0=Couplé, 1=M1, 2=M2
    
    // Conditions de Sécurité Châssis / Puissance
    EmergencyChainClosed    : BOOL := TRUE;
    PowerContactorEngaged   : BOOL := TRUE;
    
    // Capteurs Machine Réels
    M1_CablePosM            : REAL := 5.0;
    M2_CablePosM            : REAL := 5.0;
    M1_EncoderFault         : BOOL := FALSE;
    M2_EncoderFault         : BOOL := FALSE;
    PhaseRotationOk         : BOOL := TRUE;
END_VAR

VAR_OUTPUT
    // === 🚌 Bus Publics Inter-PRG Produits ===
    BusAcq                  : ST_AcquisitionInterPrg;
    BusModes                : ST_fbModes_Autorisations;
    BusWinch                : ST_WinchInterPrg;
    BusTranslation          : ST_TranslationInterPrg;
    BusOutputs              : ST_OutputsInterPrg;
    BusBanner               : ST_HmiBanner;
END_VAR

VAR
    // Harnais des 6 sous-programmes
    prg02                   : FB_TestHarness_PRG_02;
    prg03                   : FB_TestHarness_PRG_03;
    prg04                   : FB_TestHarness_PRG_04;
    prg05                   : FB_TestHarness_PRG_05;
    prg06                   : FB_TestHarness_PRG_06;
    prg07                   : FB_TestHarness_PRG_07;
END_VAR

{region "Exécution séquentielle cyclique du Mégabloc Machine"}

// ── 1. PRG_02 : Acquisition des entrées et qualification joystick ──
prg02(
    JoyRawX                 := JoyRawX,
    JoyRawY                 := JoyRawY,
    JoyBtnRaw               := JoyDeadmanBtn,
    PowerContactorEngaged   := PowerContactorEngaged,
    EmergencyChainClosed    := EmergencyChainClosed
);
BusAcq := prg02.Data;


// ── 2. PRG_03 : Arbitrage des Modes et Séquenceur de Cycle ──
prg03(
    SelMode                 := CmdMode,
    SelJoystickWinch        := CmdWinchSelect,
    PowerContactorEngaged   := PowerContactorEngaged,
    DeadmanArmed            := BusAcq.JoystickDeadmanArmed,
    JoystickDeflected       := NOT BusAcq.JoystickYNeutral,
    BtnModeReset            := BtnResetMachine
);
BusModes := prg03.Auth;

// ── 3. PRG_04 : Contrôle Treuils M1 / M2 et Benne ──
prg04(
    AcqData                 := BusAcq,
    ModesAuth               := BusModes,
    PowerContactorEngaged   := PowerContactorEngaged,
    EmergencyChainClosed    := EmergencyChainClosed,
    M1_ContactorsReleased   := TRUE,
    M1_BrakeFeedbackOpen    := FALSE,
    M2_ContactorsReleased   := TRUE,
    M2_BrakeFeedbackOpen    := FALSE,
    BtnWinchM1Up            := FALSE,
    BtnWinchM1Down          := FALSE,
    BtnReset                := BtnResetMachine
);
BusWinch := prg04.Data;


// ── 4. PRG_05 : Contrôle Translation M3 ──
prg05(
    AcqData                 := BusAcq,
    ModesAuth               := BusModes,
    WinchM1CablePosM        := BusAcq.Encoders.M1.CablePosM,
    WinchM2CablePosM        := BusAcq.Encoders.M2.CablePosM,
    PowerContactorEngaged   := PowerContactorEngaged,
    EmergencyChainClosed    := EmergencyChainClosed,
    BrakeFeedbackOpen       := FALSE,
    DriveOnline             := TRUE,
    DriveOperational        := TRUE,
    BtnReset                := BtnResetMachine,
    BtnTranslationFwd       := FALSE,
    BtnTranslationRev       := FALSE
);
BusTranslation := prg05.Data;

// ── 5. PRG_06 : Barrières Finales et Génération des Sorties ──
prg06(
    WinchData               := BusWinch,
    TranslationData         := BusTranslation,
    FaultReset              := BtnResetMachine
);
BusOutputs := prg06.Data;

// ── 6. PRG_07 : Supervision et Formatage du Bandeau IHM ──
prg07(
    AcqData                 := BusAcq,
    ModesAuth               := BusModes,
    WinchData               := BusWinch,
    TranslationData         := BusTranslation,
    EmergencyChainClosed    := EmergencyChainClosed,
    PowerContactorEngaged   := PowerContactorEngaged,
    PowerCutOffActive       := FALSE,
    BtnResetMachine         := BtnResetMachine
);
BusBanner := prg07.Banner;

{endregion}
END_FUNCTION_BLOCK
