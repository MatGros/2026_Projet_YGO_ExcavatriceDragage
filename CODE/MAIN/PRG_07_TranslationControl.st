(* ═══════════════════════════════════════════════════════════════
   ↔️ PRG_07_TranslationControl — Pilotage de la Translation Translation M3
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 7.
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_05_Cycle).
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-12_Fonction_Translation_v2.0.md
*)

PROGRAM PRG_07_TranslationControl
VAR_OUTPUT
    // 🛡️ Demande brute explicite, consommée par PRG_10_Outputs_LD.
    // PRG_07 ne produit jamais un PDO/frein M3 autorisé.
    TranslationFinalInterlockRequest : ST_TranslationFinalInterlockRequest;
END_VAR
VAR
    instTranslationM3           : FB_Translation;

    // Commandes arbitrées après sélection Manuel/Auto
    M3_StartStop_Active     : BOOL;
    M3_Direction_Active     : INT;
    M3_SpeedRef_Active      : REAL;
    M3_PositioningActive    : BOOL;
    M3_PositionSensorTarget : BOOL;

    // Target active (HMI en manuel, instCycle en auto) — 0=Aucun, 1=Trémie, 2=P2, 3=P1,
    // 4=Maintenance. PV n'est JAMAIS une cible sélectionnable (point de ralentissement seul).
    SelTarget       : INT;

// 🆕 Commande maintenance depuis ST_TranslationHMI (GVL_IHM.TranslationM3).
// L'objet Translation ne dépend plus de IHM_MANU pour ses commandes M3.
    FreqPct                 : REAL; // Conversion SetFreqHz (Hz) → % pleine échelle pour SpeedRefPct
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_07_TranslationControl) ===

// ── 0. DÉCODAGE MOT CAPTEURS (exécuté en position 0 dans PRG_00_Inputs) ──────

// ── 1. ARBITRAGE DU SÉLECTEUR DE CIBLE ET DE LA DIRECTION ──────────────────
IF PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO THEN
    // Mode Auto/Semi-Auto : Consigne issue du séquenceur de cycle
    M3_PositioningActive  := TRUE;
    SelTarget    := PRG_05_Cycle.instCycle.CmdTranslationM3_Target;
    // 🛡️ SEMI_AUTO reste conditionné par l'homme-mort : relâchement = arrêt,
    // nouvelle sollicitation valide = reprise à l'étape courante.
    M3_StartStop_Active  := PRG_05_Cycle.instCycle.CmdTranslationM3_Start
                            AND PRG_01_Diagnostics.instJoystick.DeadmanArmed
                            AND PRG_01_Diagnostics.instJoystick.AxisCmdX.StartStop;
    M3_SpeedRef_Active   := MIN(_TranslationAutoSpeedCap_Pct,
                                ABS(PRG_01_Diagnostics.instJoystick.AxisCmdX.SpeedRef));

    // Détermination automatique du sens de marche selon la cible :
    // - Trémie (cible 1) = Marche Avant (Direction := 1)
    // - P2/P1/Maintenance (cibles 2/3/4) = Marche Arrière (Direction := -1)
    IF SelTarget = 1 THEN
        M3_Direction_Active := 1;
    ELSE
        M3_Direction_Active := -1;
    END_IF;
// ── 1bis. MAINT_N1/N2 — 2ᵉ source d'arbitrage (mirroir PRG_06_WinchControl §1/§2) ──
// 🔧 REX 2026-07-19 : ex-libellé "IHM_MANU" (bypass supprimé) — cette branche est désormais
// gatée par Mode (MAINT_N1/N2), pas par un flag ManuActive séparé.
// 🆕 REX 2026-07-16 : remplace l'ex-bypass direct M3_CommandWord dans PRG_10_Outputs_LD — M3 est
// désormais piloté par la MÊME instance instTranslationM3 (FB_Translation) qu'en Auto, avec la
// rampe accel/décel et l'interlock changement de sens natifs, sous surveillance réelle de
// FB_Safety_Translation (voir PRG_03_Safety, Enable désormais inconditionnel).
ELSIF (PRG_04_Modes.instModes.Mode = E_Mode.MAINT_N1)
   OR (PRG_04_Modes.instModes.Mode = E_Mode.MAINT_N2) THEN
    // 🛠️ Maintenance N1/N2 : sous-mode explicite IHM.
    // SelPositioning=FALSE : jog libre, aucun capteur n'arrête hors fins de course.
    // SelPositioning=TRUE : le capteur de SelTarget arrête le mouvement.
    M3_PositioningActive := GVL_IHM.TranslationM3.Cmd.SelPositioning;
    SelTarget := SEL(M3_PositioningActive,
                             0,
                             StubTranslationPositionSelect_IHM);

    IF NOT GVL_IHM.TranslationM3.Cmd.TglJoystickMaster AND GVL_IHM.TranslationM3.Cmd.BtnFwd THEN
        M3_Direction_Active := 1;   // → Trémie (+1)
    ELSIF NOT GVL_IHM.TranslationM3.Cmd.TglJoystickMaster AND GVL_IHM.TranslationM3.Cmd.BtnRev THEN
        M3_Direction_Active := -1;  // → Maintenance (-1)
    ELSIF GVL_IHM.TranslationM3.Cmd.TglJoystickMaster THEN
        M3_Direction_Active := PRG_01_Diagnostics.instJoystick.AxisCmdX.Direction;
    ELSE
        // Boutons sélectionnés sans BtnFwd/BtnRev : jamais de reprise joystick implicite.
        M3_Direction_Active := 0;
    END_IF;
    // 🛡️ REX 2026-07-19 (revue mission IHM_MANU) : DeadmanArmed exigé même en pilotage boutons
    // IHM (BtnFwd/BtnRev), pas seulement en pilotage joystick — sinon les boutons IHM
    // permettaient un mouvement M3 sans homme-mort (écart relevé par la revue de sécurité).
    // 🌐 Bypass.Global = TRUE → ignore la condition homme-mort (test/simulation)
    M3_StartStop_Active := (M3_Direction_Active <> 0)
                           AND (PRG_01_Diagnostics.instJoystick.DeadmanArmed
                                OR GVL_IHM.TranslationM3.Bypass.Global)
                           AND (NOT GVL_IHM.TranslationM3.Cmd.TglJoystickMaster
                                OR PRG_01_Diagnostics.instJoystick.AxisCmdX.StartStop);

    // 🎯 Vitesse : conserve GVL_IHM.TranslationM3.Cmd.SetFreq_Hz (consigne Hz réglable opérateur,
    // limitée par PRG_10_Outputs_LD à _TranslationMaxFreq_Hz) comme cible pleine échelle — identique
    // pour boutons HMI ET joystick (reproduit exactement l'ex-bypass PRG_10_Outputs_LD, ex-lignes
    // 250-251/271-272 : SetFreqHz = 100%, déflexion joystick = % de cette cible). Convertie en
    // pourcentage car SpeedRefPct (entrée FB_Translation) est une échelle 0-100%, pas des Hz.
    // 🔧 Si SetFreq_Hz = 0 (pas configuré), on utilise une vitesse par défaut de 30%.
    FreqPct := SEL(GVL_IHM.TranslationM3.Cmd.SetFreq_Hz > 0.0,
                  (GVL_IHM.TranslationM3.Cmd.SetFreq_Hz / _TranslationMaxFreq_Hz) * 100.0,
                  30.0); // défaut 30% si SetFreq_Hz non renseigné
    M3_SpeedRef_Active := SEL(GVL_IHM.TranslationM3.Cmd.TglJoystickMaster,
                              FreqPct,
                              (ABS(PRG_01_Diagnostics.instJoystick.AxisCmdX.SpeedRef) / 100.0) * FreqPct);
ELSE
    // Mode Manuel/Maintenance : Consignes issues du Joystick et sélecteur HMI
    M3_PositioningActive := FALSE;
    SelTarget    := StubTranslationPositionSelect_IHM;
    M3_StartStop_Active  := PRG_01_Diagnostics.instJoystick.AxisCmdX.StartStop;
    M3_Direction_Active  := PRG_01_Diagnostics.instJoystick.AxisCmdX.Direction;
    M3_SpeedRef_Active   := PRG_01_Diagnostics.instJoystick.AxisCmdX.SpeedRef;
END_IF;

// 🔄 Inversion de sens IHM (mise en service)
IF GVL_IHM.TranslationM3.Cmd.InvertDirection THEN
    M3_Direction_Active := M3_Direction_Active * (-1);
END_IF;

// 🛡️ Limitation finale M3 : toute source de commande (joystick, IHM ou cycle) arrive
// au variateur dans la plage physique autorisée 0..100 %. Ce garde-fou complète
// les limitations de FB_AxisScale/FB_Ramp et ne remplace pas la chaîne Safety.
M3_SpeedRef_Active := LIMIT(0.0, ABS(M3_SpeedRef_Active), 100.0);

// 🆕 REX 2026-07-18 : cible Maintenance (4) bloquée hors MAINT_N2 (AF_Partie-02 v2.12 §3bis) —
// arbitrage centralisé dans FB_Modes (aucun re-test de Mode ici), refuse toute cible si interdite.
IF (SelTarget = 4) AND NOT PRG_04_Modes.instModes.MaintenanceM3TargetEnable THEN
    SelTarget := 0;
END_IF;

// Câblage du capteur de butée de la cible sélectionnée (PV exclu : jamais une cible d'arrêt)
CASE SelTarget OF
    1: M3_PositionSensorTarget := PRG_00_Inputs.TranslationPosTremie;
    2: M3_PositionSensorTarget := PRG_00_Inputs.TranslationPosP2;
    3: M3_PositionSensorTarget := PRG_00_Inputs.TranslationPosP1;
    4: M3_PositionSensorTarget := PRG_00_Inputs.TranslationPosMaintenance;
ELSE
    M3_PositionSensorTarget := FALSE;   // Aucun capteur visé
END_CASE;

// ── 2. EXÉCUTION DU PILOTAGE DU TRANSLATION M3 ──────────────────────────────
instTranslationM3(
    Enable                  := PRG_06_WinchControl.StubMachineEnableN1
                               AND (PRG_04_Modes.instModes.Mode <> E_Mode.DISABLE), // 🔧 WINCH-CORE-01 : DISABLE neutralise M3
    Reset                   := PRG_09_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged         := PRG_01_INPUTS_LD.PowerContactorEngaged,
    Mode                    := PRG_04_Modes.instModes.Mode,
    StartStop               := M3_StartStop_Active,
    SafeStop                := PRG_03_Safety.instSafetyTranslationM3.SafeStop,
    Direction               := M3_Direction_Active,
    SpeedRefPct             := M3_SpeedRef_Active,
    PositionSensorTarget    := M3_PositionSensorTarget,
    SlowdownSensor          := PRG_00_Inputs.TranslationPosPV, // 🆕 remplace ApproachTime (timer) — ralentissement avant Trémie uniquement
    LimitSwitchFwd          := PRG_00_ACQUISITION_CFC.instPosDecoderM3.LimitSwitchFwd, // 🆕 dérivé du mot capteurs (extrême Trémie, mot=11111)
    LimitSwitchRev          := PRG_00_ACQUISITION_CFC.instPosDecoderM3.LimitSwitchRev, // 🆕 dérivé du mot capteurs (extrême Maintenance, mot=00000)
    DriveStatusWord         := PRG_00_Inputs.M3_StatusWord_Filtered,
    DriveActualFreqHz       := UINT_TO_REAL(PRG_00_Inputs.M3_ActualFrequencyHz_Filtered) / 100.0,
    CfgRampAccelRate           := _TranslationRampAccelRate_Pct,      // 🔧 PERSISTENT depuis GVL_PERSISTENT
    CfgRampDecelNormalRate     := _TranslationRampDecelNormal_Pct,    // 🔧 idem
    CfgRampDecelFastRate       := _TranslationRampDecelFast_Pct,      // 🔧 idem
    DriveFreqScaleMaxHz     := _TranslationMaxFreq_Hz,             // 🔧 source unique depuis PERSISTENT
    BrakeFeedback           := SEL(GVL_IHM.TranslationM3.Bypass.ContactorFeedback OR GVL_IHM.TranslationM3.Bypass.Global, PRG_01_INPUTS_LD.M3BrakeFeedback, instTranslationM3.BrakeReleaseRequest),
    BypassContactorCheck    := GVL_IHM.TranslationM3.Bypass.Global,
    BypassLimitSwitch       := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.LimitSwitch
);

// 🛡️ Publication demande brute M3 vers PRG_10_Outputs_LD.
// Ordre MainTask requis : PRG_07 avant PRG_10. SafeStop reste traité par
// FB_Translation (rampe rapide) et n'est jamais une coupure sèche ici.
TranslationFinalInterlockRequest.Enable := PRG_06_WinchControl.StubMachineEnableN1;
TranslationFinalInterlockRequest.Reset := PRG_09_Supervision.FaultMachineReset_IHM;
TranslationFinalInterlockRequest.PowerContactorEngaged := PRG_01_INPUTS_LD.PowerContactorEngaged;
TranslationFinalInterlockRequest.SafeStop := PRG_03_Safety.instSafetyTranslationM3.SafeStop;
TranslationFinalInterlockRequest.BrakeReleaseRequest := instTranslationM3.BrakeReleaseRequest;
TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed := PRG_00_Inputs.M3BrakeCommandOpenConfirmed;
TranslationFinalInterlockRequest.RequestedDriveControlWord := instTranslationM3.RequestedDriveControlWord;
TranslationFinalInterlockRequest.RequestedDriveFreqHz := instTranslationM3.RequestedDriveFreqHz;
