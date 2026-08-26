(* ═══════════════════════════════════════════════════════════════
   ↔️ PRG_05_Translation — Pilotage de la Translation M3
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 5 (après PRG_04_Treuils_Benne).
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_03_Modes_Cycle).
   📄 Docs : DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md
   🛡️ Sécurité : instSafetyTranslationM3 (FB_Safety_Translation) câblée en parallèle
      de instTranslationM3 — SafeStop/PowerCutOff réels.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_05_Translation

VAR_INPUT
    // === 📥 ENTRÉES PROGRAMME (AUCUNE - PILOTÉ VIA PRG_02, PRG_03 & PRG_04) ===
END_VAR

VAR_OUTPUT
    // === 🚌 BUS INTER-PRG (producteur unique) ===
    Data : ST_TranslationInterPrg; // <-- [BUS] Demande finale, état public, sécurité translation M3
END_VAR

VAR
    instTranslationM3           : FB_Translation;
    instSafetyTranslationM3     : FB_Safety_Translation;
    instPosEstimatorM3          : FB_Translation_PositionEstimator;
    instPosDecoderM3            : FB_Translation_PositionDecoder; // 🧩 Decodage position M3 (migre de PRG_02, AF-02 TBD §8 #5)

    // === 📊 STRUCTS INTERNES (publiés via Data) ===
    TranslationFinalInterlockRequest : ST_TranslationFinalInterlockRequest; // . [LOC] Demande finale et interlocks translation M3
    TranslationState                 : ST_TranslationState;                 // . [LOC] Etat public translation M3
    TranslationSafety                : ST_SafetyTranslation;                // . [LOC] Diagnostic et securites translation M3

    M3_StartStop_Active     : BOOL;
    M3_Direction_Active     : INT;
    M3_SpeedCmd_Active      : REAL;
    M3_PositioningActive    : BOOL;
    M3_PositionSensorTarget : BOOL;

    SelTarget       : INT;
    FreqPct                 : REAL;

    M3_SafeStop_Active      : BOOL; // SafeStop sur défaut module d'entrée (InputModuleFault, AF06 §3bis)
    M3_SafeStop_Aggregate   : BOOL; // 🛡️ SafeStop réellement appliqué au mouvement = InputModuleFault OR safety M3 (8 mécanismes)

    M3_HeightInterlockOk    : BOOL; // TRUE = M1 ET M2 au-dessus de la hauteur mini (ou bypass actif)
    M3_LimitSwitchRevEffective : BOOL; // Coupure dure §5bis — bascule sur P1 si Maintenance interdite
    M3_LimitSwitchFwdStable : BOOL; // Verrou bistable Fdc Trémie (mémorisé stable contre les rebonds)
    M3_LimitSwitchRevStable : BOOL; // Verrou bistable Fdc Maintenance/P1 (mémorisé stable contre les rebonds)

    // Verrous bistables des positions cibles (§0quater) — PositionDecoder n'émet
    // plus qu'un front transitoire par capteur, mémorisé ici jusqu'à dégagement.
    M3_AtTremieStable      : BOOL;
    M3_AtPVStable          : BOOL;
    M3_AtP2Stable          : BOOL;
    M3_AtP1Stable          : BOOL;
    M3_AtMaintenanceStable : BOOL;

    // Libération du verrou §0quater sur MOUVEMENT CONFIRMÉ soutenu (fréquence réelle mesurée,
    // pas juste une consigne de sens), pendant une durée mini avant de considérer qu'on a
    // vraiment quitté le point — pas un changement de sens instantané ni un timer fixe
    // indépendant du mouvement réel (rebond capteur mal filtré).
    TonM3ConfirmedMoving : TON;
    M3_ConfirmedMoving   : BOOL;
END_VAR

{region "§0 Decodage position M3"}
// === 🧩 §0 DÉCODAGE POSITION M3 (migré de PRG_02, AF-02 TBD §8 #5) ===
// PRG_02_Acquisition s'exécute avant ce POU (rang 01 < 05) : HwIn.Translation est
// disponible au même scan. Le décodage des capteurs M3 est propriété de PRG_05.
instPosDecoderM3(
    SensorTremie      := PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI,
    SensorPV          := PRG_02_Acquisition.HwIn.Translation.M3_PosPV_DI,
    SensorP2          := PRG_02_Acquisition.HwIn.Translation.M3_PosPVP2_DI,
    SensorP1          := PRG_02_Acquisition.HwIn.Translation.M3_PosP1_DI,
    SensorMaintenance := PRG_02_Acquisition.HwIn.Translation.M3_PosMaintenance_DI
);

// 📤 Publication des faits M3 dans le bus PRG_05 (consommés par PRG_07)
Data.TranslationPosTremie      := instPosDecoderM3.TranslationPosTremie;
Data.TranslationPosPV          := instPosDecoderM3.TranslationPosPV;
Data.TranslationPosP2          := instPosDecoderM3.TranslationPosP2;
Data.TranslationPosP1          := instPosDecoderM3.TranslationPosP1;
Data.TranslationPosMaintenance := instPosDecoderM3.TranslationPosMaintenance;
Data.TranslationAtTremie      := instPosDecoderM3.TranslationAtTremie;
Data.TranslationAtPV          := instPosDecoderM3.TranslationAtPV;
Data.TranslationAtP2          := instPosDecoderM3.TranslationAtP2;
Data.TranslationAtP1          := instPosDecoderM3.TranslationAtP1;
Data.TranslationAtMaintenance := instPosDecoderM3.TranslationAtMaintenance;
Data.M3_LimitSwitchFwd       := instPosDecoderM3.LimitSwitchFwd;
Data.M3_LimitSwitchRev       := instPosDecoderM3.LimitSwitchRev;
Data.M3_SensorWordIncoherent := instPosDecoderM3.Incoherent;
Data.M3_SensorsWord            := instPosDecoderM3.SensorsWord;
{endregion}

{region "§0 Interlock hauteur M1/M2"}
// === 🚧 §0 INTERLOCK HAUTEUR M1/M2 (risque collision translation) ===
// PRG_02_Acquisition s'exécute avant ce POU dans la MainTask (rang 01 < 05) : lecture
// du même scan, aucun retard. Bypass = maintenance consciente, doctrine ST_BypassTranslation.
// ⚠️ Une position encodeur incohérente (hors plage OU homing suspect,
// FB_Encoder_Safety) ne doit PAS pouvoir se lire comme "≥ seuil" par accident — fail-safe :
// hauteur non confirmée = interlock actif (comme une hauteur insuffisante), sauf bypass.
// 🔒 Bypass.Global NE lève PLUS cet interlock (contrairement aux autres
// causes de l'axe M3) — risque de collision jugé trop grave pour être levé par un bypass
// générique. Seul Bypass.MinHeight (dédié, conscient) lève l'anti-collision hauteur.
M3_HeightInterlockOk := GVL_IHM.TranslationM3.Bypass.MinHeight
                        OR (PRG_02_Acquisition.Data.M1_HomedAndReliable
                            AND PRG_02_Acquisition.Data.M2_HomedAndReliable
                            AND (PRG_02_Acquisition.Data.Encoders.M1.CablePosM >= GVL_PERSISTENT._TranslationMinHeightM1M2_M)
                            AND (PRG_02_Acquisition.Data.Encoders.M2.CablePosM >= GVL_PERSISTENT._TranslationMinHeightM1M2_M));
TranslationState.HeightInterlockBlocking := NOT M3_HeightInterlockOk;

{endregion}

{region "§0bis Coupure dure limite translation"}
// === 🚧 §0bis COUPURE DURE (LimitSwitchRev) — bascule sur P1 si Maintenance interdite ===
// LimitSwitchFwd/Rev protègent nativement Trémie/Maintenance
// (§5bis FB_Translation : coupure immédiate, sans rampe, dès que CommandedDirection insiste
// dans l'extrémité). P1/P2 n'ont aucune protection dure équivalente — seul le verrou souple
// (arrival-lock) les couvre. Quand Maintenance est interdite, la coupure dure doit protéger
// P1 comme si c'était l'extrémité réelle : mot 00001 (P1=0 ET Maintenance=1), UN CRAN AVANT
// la vraie extrémité Maintenance (00000) — backup si le verrou souple a déjà échoué à arrêter
// avant P1, garde la machine hors de la zone interdite plutôt que d'attendre le vrai fond.
M3_LimitSwitchRevEffective := SEL(PRG_03_Modes_Cycle.Auth.MaintenanceM3TargetEnable,
                                   NOT instPosDecoderM3.TranslationPosP1 AND instPosDecoderM3.TranslationPosMaintenance,
                                   instPosDecoderM3.LimitSwitchRev);

// 🔒 §0ter STABILISATION BISTABLE FINS DE COURSE EXTRÊMES (Trémie & Maintenance/P1)
// Maintient la détection stable à 1 même si le capteur physique vibre ou saute brièvement.
// Se libère uniquement sur un mouvement effectif dans le SENS INVERSE (dégagement).
IF instPosDecoderM3.LimitSwitchFwd THEN
    M3_LimitSwitchFwdStable := TRUE;
ELSIF M3_Direction_Active = -1 THEN
    M3_LimitSwitchFwdStable := FALSE;
END_IF;

IF M3_LimitSwitchRevEffective THEN
    M3_LimitSwitchRevStable := TRUE;
ELSIF M3_Direction_Active = 1 OR (PRG_03_Modes_Cycle.Auth.MaintenanceM3TargetEnable AND NOT instPosDecoderM3.LimitSwitchRev) THEN
    M3_LimitSwitchRevStable := FALSE;
END_IF;

// 🔒 §0quater MÉMORISATION DU DERNIER POINT ATTEINT (front → jeton unique)
// PositionDecoder n'émet qu'un front transitoire (1 cycle) par capteur, montant OU descendant
// SELON LE SENS (voir FB_Translation_PositionDecoder.st) — mémorisé ici pour
// tenir le niveau nécessaire au débounce (100ms) + verrou anti-rebond (§4ter DirectionAtArrival)
// de FB_Translation, et pour l'affichage IHM. MUTUELLEMENT EXCLUSIFS : un nouveau front RAZ tous
// les autres (jeton "dernier point franchi" unique). Libéré
// (RAZ complet) UNIQUEMENT sur mouvement CONFIRMÉ (fréquence réelle mesurée, pas juste la consigne
// de sens) soutenu ≥1.5s — pas un rebond capteur ni un changement de sens instantané.
M3_ConfirmedMoving := (UINT_TO_REAL(PRG_02_Acquisition.Data.M3_ActualFrequencyHz_Filtered) / 100.0) > 0.5;
TonM3ConfirmedMoving(IN := M3_ConfirmedMoving, PT := T#1s500ms);

IF instPosDecoderM3.TranslationAtTremie THEN
    M3_AtTremieStable := TRUE; M3_AtPVStable := FALSE; M3_AtP2Stable := FALSE; M3_AtP1Stable := FALSE; M3_AtMaintenanceStable := FALSE;
ELSIF instPosDecoderM3.TranslationAtPV THEN
    M3_AtPVStable := TRUE; M3_AtTremieStable := FALSE; M3_AtP2Stable := FALSE; M3_AtP1Stable := FALSE; M3_AtMaintenanceStable := FALSE;
ELSIF instPosDecoderM3.TranslationAtP2 THEN
    M3_AtP2Stable := TRUE; M3_AtTremieStable := FALSE; M3_AtPVStable := FALSE; M3_AtP1Stable := FALSE; M3_AtMaintenanceStable := FALSE;
ELSIF instPosDecoderM3.TranslationAtP1 THEN
    M3_AtP1Stable := TRUE; M3_AtTremieStable := FALSE; M3_AtPVStable := FALSE; M3_AtP2Stable := FALSE; M3_AtMaintenanceStable := FALSE;
ELSIF instPosDecoderM3.TranslationAtMaintenance THEN
    M3_AtMaintenanceStable := TRUE; M3_AtTremieStable := FALSE; M3_AtPVStable := FALSE; M3_AtP2Stable := FALSE; M3_AtP1Stable := FALSE;
ELSIF TonM3ConfirmedMoving.Q THEN
    // Mouvement réel confirmé ≥1.5s sans nouveau front : on a vraiment quitté le dernier point.
    M3_AtTremieStable := FALSE; M3_AtPVStable := FALSE; M3_AtP2Stable := FALSE; M3_AtP1Stable := FALSE; M3_AtMaintenanceStable := FALSE;
END_IF;

{endregion}

{region "§1 Arbitrage cible et direction"}
// === 🔀 §1 ARBITRAGE DU SÉLECTEUR DE CIBLE ET DE LA DIRECTION ===

IF PRG_03_Modes_Cycle.Auth.Mode = E_Mode.SEMI_AUTO THEN
    // Pont SEMI_AUTO : consomme la demande du séquenceur de cycle.
    // FB_Cycle produit TranslationCmd.Start conditionné par CycleMotionPermit (homme-mort 3s, D2).
    M3_PositioningActive  := TRUE;
    SelTarget    := PRG_03_Modes_Cycle.instCycleSemiAuto.TranslationCmd.Target;
    M3_StartStop_Active  := PRG_03_Modes_Cycle.instCycleSemiAuto.TranslationCmd.Start;

    // 🔒 Direction/vitesse M3 uniquement si le cycle commande réellement le mouvement (Start).
    // Sans Start, M3 reste à l'arrêt (direction=0, vitesse=0) — aucun mouvement parasite.
    IF M3_StartStop_Active THEN
        M3_SpeedCmd_Active := 100.0;
        // Direction déduite de la cible (Trémie=1 → Fwd, sinon Rev)
        IF SelTarget = 1 THEN
            M3_Direction_Active := 1;
        ELSE
            M3_Direction_Active := -1;
        END_IF;
    ELSE
        M3_SpeedCmd_Active := 0.0;
        M3_Direction_Active := 0;
    END_IF;
ELSIF (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N1)
   OR (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2) THEN
    M3_PositioningActive := GVL_IHM.TranslationM3.Cmd.SelPositioning;
    SelTarget := 0;

    IF NOT GVL_IHM.Modes.Cmd.TglJoystickMaster AND GVL_IHM.TranslationM3.Cmd.BtnFwd THEN
        M3_Direction_Active := 1;
    ELSIF NOT GVL_IHM.Modes.Cmd.TglJoystickMaster AND GVL_IHM.TranslationM3.Cmd.BtnRev THEN
        M3_Direction_Active := -1;
    ELSIF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
        M3_Direction_Active := PRG_02_Acquisition.Data.JoystickDirectionX;
    ELSE
        M3_Direction_Active := 0;
    END_IF;

    // Homme-mort exigé même pour boutons IHM en MAINT_N1/N2
    // (AF_Partie-08 §6, AF_Partie-11 §4.2) — pas seulement pour un pilotage joystick réel.
    // TglJoystickMaster consolidé — un seul switch machine (GVL_IHM.Modes.Cmd).
    M3_StartStop_Active := (M3_Direction_Active <> 0)
                           AND (GVL_IHM.TranslationM3.Bypass.Global
                                OR NOT GVL_IHM.Modes.Cmd.TglJoystickMaster
                                OR GVL_IHM.Modes.Cmd.TglJoystickMaster)
                           AND PRG_02_Acquisition.Data.JoystickDeadmanArmed
                           AND M3_HeightInterlockOk; // Hauteur mini M1/M2 (risque collision)

    FreqPct := SEL(GVL_IHM.TranslationM3.Cmd.SetFreq_Hz > 0.0,
                  100.0,
                  (GVL_IHM.TranslationM3.Cmd.SetFreq_Hz / SEL(GVL_PERSISTENT._TranslationMaxFreq_Hz > 0.0, 50.0, GVL_PERSISTENT._TranslationMaxFreq_Hz)) * 100.0);
    // 🕹️ Si TglJoystickMaster (global) = TRUE, le manche (0..100%) est mis à l'échelle sur la consigne SetFreq_Hz (ou 100% si non renseignée).
    M3_SpeedCmd_Active := SEL(GVL_IHM.Modes.Cmd.TglJoystickMaster,
                              FreqPct,
                              (PRG_02_Acquisition.Data.JoystickSpeedPctX / 100.0) * FreqPct);
ELSE
    M3_PositioningActive := FALSE;
    SelTarget    := 0;
    M3_StartStop_Active  := FALSE;
    M3_Direction_Active  := 0;
    M3_SpeedCmd_Active   := 0.0;
END_IF;

// InvertDirection est appliqué dans FB_Translation (InvertDriveDirection), uniquement au mot
// de commande variateur en sortie — M3_Direction_Active reste partout le sens sémantique réel.

M3_SpeedCmd_Active := LIMIT(0.0, ABS(M3_SpeedCmd_Active), 100.0);

IF (SelTarget = 4) AND NOT PRG_03_Modes_Cycle.Auth.MaintenanceM3TargetEnable THEN
    SelTarget := 0;
END_IF;

// 🩺 InputModuleFault (AF06 §3bis) : un module DI TOR hors service rend indisponibles
// les retours frein/thermique/positions du VH_0808ETP/VH_0800END portant M3 — rampe rapide.
M3_SafeStop_Active := PRG_02_Acquisition.Data.InputModuleFault;

// En mode manuel (SelTarget=0), n'importe quel des 3 points d'arrêt (Trémie/P1/Maintenance)
// arme le verrou anti-rebond §4ter de FB_Translation (DirectionAtArrival). Mot EXACT
// (TranslationAtXxx), pas le cumulatif (TranslationPosXxx) — front franc à l'arrivée quel que
// soit le sens de venue (voir FB_Translation_PositionDecoder.st).
CASE SelTarget OF
    1: M3_PositionSensorTarget := M3_AtTremieStable;
    2: M3_PositionSensorTarget := M3_AtP2Stable;
    3: M3_PositionSensorTarget := M3_AtP1Stable;
    4: M3_PositionSensorTarget := M3_AtMaintenanceStable;
ELSE
    IF M3_Direction_Active = 1 THEN
        // En Marche Avant (+1 vers Trémie) : seule Trémie est le point d'arrêt automatique
        M3_PositionSensorTarget := M3_AtTremieStable;
    ELSIF M3_Direction_Active = -1 THEN
        // En Marche Arrière (-1 vers Maintenance) :
        // - Si Maintenance autorisée -> arrêt sur Maintenance
        // - Si Maintenance interdite -> arrêt sur P1
        IF PRG_03_Modes_Cycle.Auth.MaintenanceM3TargetEnable THEN
            M3_PositionSensorTarget := M3_AtMaintenanceStable;
        ELSE
            M3_PositionSensorTarget := M3_AtP1Stable;
        END_IF;
    ELSE
        M3_PositionSensorTarget := FALSE;
    END_IF;
END_CASE;


{endregion}

{region "§1bis Securite M3"}
// === 🛡️ §1bis SÉCURITÉ M3 (FB_Safety_Translation, câblée en parallèle visible) ===
// ⚠️ Ordre d'appel volontaire : la safety lit ici le BrakeReleaseRequest et le
// BrakeCmd du SCAN PRÉCÉDENT d'instTranslationM3 (elle est appelée avant), soit un retard
// d'un scan. Bénin : BrakeReleaseRequest ne change pas plus vite qu'un scan MainTask 10 ms
// sur une commande frein.
instSafetyTranslationM3(
    Enable                  := (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE),
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Auth.Mode,
    JoystickOnline          := PRG_02_Acquisition.instDiagCanOpen.DeviceJoystick.Online,
    JoystickOperational     := PRG_02_Acquisition.instDiagCanOpen.DeviceJoystick.Operational,
    HeartbeatIhmOk          := GVL_IHM.Commun.HeartbeatIhmOk,
    PhaseRotationOk         := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
    BrakeThermalFeedback    := NOT PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI,
    DriveOnline             := PRG_02_Acquisition.instDiagEthercat.DeviceVariateur.Online,
    DriveOperational        := PRG_02_Acquisition.instDiagEthercat.DeviceVariateur.Operational,
    DriveStatusWord         := PRG_02_Acquisition.Data.M3_StatusWord_Filtered,
    DriveActualFreqHz       := UINT_TO_REAL(PRG_02_Acquisition.Data.M3_ActualFrequencyHz_Filtered) / 100.0,
    BrakeFeedback           := SEL(GVL_IHM.TranslationM3.Bypass.ContactorFeedback OR GVL_IHM.TranslationM3.Bypass.Global, PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI, instTranslationM3.BrakeReleaseRequest),
    BrakeCmd                := instTranslationM3.BrakeReleaseRequest,
    Direction               := M3_Direction_Active,
    LimitSwitchFwd          := M3_LimitSwitchFwdStable,
    LimitSwitchRev          := M3_LimitSwitchRevStable,
    SensorWordIncoherent    := instPosDecoderM3.Incoherent,
    BypassGlobal            := GVL_IHM.TranslationM3.Bypass.Global,
    BypassOperatorComm      := GVL_IHM.TranslationM3.Bypass.OperatorComm,
    BypassDriveComm         := GVL_IHM.TranslationM3.Bypass.DriveComm,
    BypassPhaseRotation     := GVL_IHM.TranslationM3.Bypass.PhaseRotation,
    BypassBrakeThermal      := GVL_IHM.TranslationM3.Bypass.BrakeThermal,
    BypassMecaB             := GVL_IHM.TranslationM3.Bypass.MecaB,
    BypassMecaA             := GVL_IHM.TranslationM3.Bypass.MecaA,
    BypassLimitSwitch       := GVL_IHM.TranslationM3.Bypass.LimitSwitch,
    BypassSensorIncoherent  := GVL_IHM.TranslationM3.Bypass.SensorIncoherent,
    BypassSafety            := GVL_IHM.TranslationM3.Bypass.Safety,
    BypassProcess           := GVL_IHM.TranslationM3.Bypass.Process
);

// SafeStop réellement appliqué au mouvement = agrégat InputModuleFault OR safety M3
// (8 mécanismes) — aucune des deux causes ne doit être perdue.
M3_SafeStop_Aggregate := M3_SafeStop_Active OR instSafetyTranslationM3.SafeStop;

{endregion}

{region "§2 Pilotage translation M3"}
// === ⚙️ §2 EXÉCUTION PILOTAGE TRANSLATION M3 ===

instTranslationM3(
    Enable                  := (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE),
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Auth.Mode,
    StartStop               := M3_StartStop_Active,
    SafeStop                := M3_SafeStop_Aggregate,
    Direction               := M3_Direction_Active,
    InvertDriveDirection    := GVL_IHM.TranslationM3.Cmd.InvertDirection,
    SpeedTgt_Pct            := M3_SpeedCmd_Active,
    PositionSensorTarget    := M3_PositionSensorTarget,
    SlowdownSensorTremie       := instPosDecoderM3.TranslationPosPV,
    // Les 5 capteurs forment un code thermomètre cumulatif depuis la Trémie (voir
    // FB_Translation_PositionDecoder.st). Chaque zone est délimitée par "capteur PRÉCÉDENT retombé
    // à 0" ET "capteur de la zone encore à 1" — zone P2→P1 = NOT PosP2 AND PosP1 (mot 00011) ;
    // zone P1→Maintenance = NOT PosP1 AND PosMaintenance (mot 00001). Zones mutuellement exclusives,
    // chacune sa propre vitesse d'approche (CfgApproachSpeedP1_Hz / CfgApproachSpeedMaintenance_Hz).
    SlowdownSensorMaintenance  := (NOT instPosDecoderM3.TranslationPosP1) AND instPosDecoderM3.TranslationPosMaintenance,
    // Ralentissement P2→P1 UNIQUEMENT si P1 est un vrai point
    // d'arrêt (zone Maintenance NON autorisée). Zone Maintenance autorisée -> 100% vitesse jusqu'à
    // P1, ralentissement seulement après (zone P1→Maintenance, SlowdownSensorMaintenance ci-dessus).
    SlowdownSensorP1           := (NOT instPosDecoderM3.TranslationPosP2) AND instPosDecoderM3.TranslationPosP1
                                   AND NOT PRG_03_Modes_Cycle.Auth.MaintenanceM3TargetEnable,
    LimitSwitchFwd          := M3_LimitSwitchFwdStable,
    LimitSwitchRev          := M3_LimitSwitchRevStable,
    DriveStatusWord         := PRG_02_Acquisition.Data.M3_StatusWord_Filtered,
    DriveActualFreqHz       := UINT_TO_REAL(PRG_02_Acquisition.Data.M3_ActualFrequencyHz_Filtered) / 100.0,
    CfgRampAccelRate        := _TranslationRampAccelRate_Pct,
    CfgRampDecelNormalRate  := _TranslationRampDecelNormal_Pct,
    CfgRampDecelFastRate    := _TranslationRampDecelFast_Pct,
    ApproachSpeedTremieHz       := GVL_IHM.TranslationM3.Cfg.CfgApproachSpeedTremie_Hz,
    ApproachSpeedMaintenanceHz  := GVL_IHM.TranslationM3.Cfg.CfgApproachSpeedMaintenance_Hz,
    ApproachSpeedP1Hz           := GVL_IHM.TranslationM3.Cfg.CfgApproachSpeedP1_Hz,
    DriveFreqScaleMaxHz     := _TranslationMaxFreq_Hz,
    BrakeFeedback           := SEL(GVL_IHM.TranslationM3.Bypass.ContactorFeedback OR GVL_IHM.TranslationM3.Bypass.Global, PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI, instTranslationM3.BrakeReleaseRequest),
    BypassContactorCheck    := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.ContactorFeedback,
    BypassLimitSwitch       := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.LimitSwitch
);

// 📐 Estimateur de position continue M3 (odométrie + recalage 5 capteurs)
instPosEstimatorM3(
    Enable               := (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE),
    Reset                := PRG_07_Supervision.FaultMachineReset_IHM,
    DriveActualFreqHz    := TO_REAL(PRG_02_Acquisition.Data.M3_ActualFrequencyHz_Filtered) / 100.0,
    Direction            := M3_Direction_Active,
    SensorMaintenance    := instPosDecoderM3.TranslationPosMaintenance,
    SensorP1             := instPosDecoderM3.TranslationPosP1,
    SensorP2             := instPosDecoderM3.TranslationPosP2,
    SensorPV             := instPosDecoderM3.TranslationPosPV,
    SensorTremie         := instPosDecoderM3.TranslationPosTremie,
    PosMaintenanceM      := GVL_PERSISTENT._TranslationPosMaintenance_M,
    PosP1M               := GVL_PERSISTENT._TranslationPosP1_M,
    PosP2M               := GVL_PERSISTENT._TranslationPosP2_M,
    PosPVM               := GVL_PERSISTENT._TranslationPosPV_M,
    PosTremieM           := GVL_PERSISTENT._TranslationPosTremie_M,
    GainMetersPerHzSec   := GVL_PERSISTENT._TranslationGainMetersPerHzSec,
    PersistedPositionM   := GVL_PERSISTENT._TranslationPosEstimated_M,
    PersistedInitialized := GVL_PERSISTENT._TranslationPosEstimatedInitialized
);
// Recopie continue (reprise après reboot, doctrine _TranslationSetFreq_Hz) — pas de bridge dédié.
GVL_PERSISTENT._TranslationPosEstimated_M := instPosEstimatorM3.PositionEstimatedM;
GVL_PERSISTENT._TranslationPosEstimatedInitialized := instPosEstimatorM3.Initialized;


{endregion}

{region "§3 Publication demande translation"}
// === 📤 §3 PUBLICATION DEMANDE BRUTE TRANSLATION ===

TranslationFinalInterlockRequest.Enable := (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE);
TranslationFinalInterlockRequest.Reset := PRG_07_Supervision.FaultMachineReset_IHM;
TranslationFinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
TranslationFinalInterlockRequest.SafeStop := M3_SafeStop_Aggregate;
TranslationFinalInterlockRequest.PowerCutOff := instSafetyTranslationM3.PowerCutOff;
TranslationFinalInterlockRequest.BrakeReleaseRequest := instTranslationM3.BrakeReleaseRequest;
TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed := instTranslationM3.BrakeCommandOpenConfirmed;
TranslationFinalInterlockRequest.RequestedDriveControlWord := instTranslationM3.RequestedDriveControlWord;
TranslationFinalInterlockRequest.RequestedDriveFreqHz := instTranslationM3.RequestedDriveFreqHz;

{endregion}

{region "§4 Publication etat IHM"}
// === 📤 PUBLICATION ÉTAT TRANSLATION IHM (lecture seule) ===
TranslationState.FBState := instTranslationM3.Status.State;
TranslationState.Ready := instTranslationM3.Ready;
TranslationState.Busy := instTranslationM3.Status.Busy;
TranslationState.Done := instTranslationM3.Status.Done;
TranslationState.Error := instTranslationM3.Status.Error;
TranslationState.ErrorId := instTranslationM3.Status.ErrorId;
TranslationState.BrakeCmd := instTranslationM3.BrakeReleaseRequest;
TranslationState.BrakeCommandOpenConfirmed := instTranslationM3.BrakeCommandOpenConfirmed;
TranslationState.PositionReached := instTranslationM3.TargetReached;
TranslationState.DriveControlWord := instTranslationM3.RequestedDriveControlWord;
TranslationState.DriveFreqCmd_Hz := instTranslationM3.RequestedDriveFreqHz;
// 🎯 Cohérence sim : ActiveDirection/SpeedCmd_Pct n'affichent la
// consigne QUE si la commande variateur est réellement émise (RequestedDriveControlWord <> 0).
// Sinon, un interlock bloquant (hauteur, SafeStop…) laisserait l'IHM suggérer un mouvement
// qui n'a pas lieu ("je bouge mais ça bouge pas"). Affiche 0 quand c'est bloqué.
TranslationState.ActiveDirection := SEL(instTranslationM3.RequestedDriveControlWord <> 0, M3_Direction_Active, 0);
TranslationState.SpeedCmd_Pct := SEL(instTranslationM3.RequestedDriveControlWord <> 0, M3_SpeedCmd_Active, 0.0);
TranslationState.PositionTremie := instPosDecoderM3.TranslationPosTremie;
TranslationState.PositionPV := instPosDecoderM3.TranslationPosPV;
TranslationState.PositionP2 := instPosDecoderM3.TranslationPosP2;
TranslationState.PositionP1 := instPosDecoderM3.TranslationPosP1;
TranslationState.PositionMaintenance := instPosDecoderM3.TranslationPosMaintenance;
// Affichage IHM = M3_AtXxxStable (§0quater) — armé sur front
// (direction-dépendant), libéré sur mouvement réel confirmé ≥1.5s (pas juste un rebond capteur
// ni un changement de sens instantané). Même signal que celui consommé par M3_PositionSensorTarget.
TranslationState.AtTremie := M3_AtTremieStable;
TranslationState.AtPV := M3_AtPVStable;
TranslationState.AtP2 := M3_AtP2Stable;
TranslationState.AtP1 := M3_AtP1Stable;
TranslationState.AtMaintenance := M3_AtMaintenanceStable;
TranslationState.EstimatedPosM3_M := instPosEstimatorM3.PositionEstimatedM;
TranslationState.SensorsWord := instPosDecoderM3.SensorsWord;
TranslationState.SensorWordIncoherent := instPosDecoderM3.Incoherent;
TranslationState.LimitSwitchFwd := M3_LimitSwitchFwdStable;
TranslationState.LimitSwitchRev := M3_LimitSwitchRevStable;
TranslationState.DriveActualFreq_Hz := TO_REAL(PRG_02_Acquisition.Data.M3_ActualFrequencyHz_Filtered) / 100.0;
TranslationState.DriveThermalOk := PRG_02_Acquisition.HwIn.Translation.M3_ThermalOK_DI;
TranslationState.FinalInterlockState := PRG_06_Outputs.instTranslationOutputInterlockM3.Status.State;
TranslationState.FinalInterlockReason := PRG_06_Outputs.instTranslationOutputInterlockM3.Reason;
TranslationState.FinalInterlockError := PRG_06_Outputs.instTranslationOutputInterlockM3.Status.Error;
TranslationState.FinalInterlockErrorId := PRG_06_Outputs.instTranslationOutputInterlockM3.Status.ErrorId;
TranslationState.FinalBrakeTimeoutElapsed := PRG_06_Outputs.instTranslationOutputInterlockM3.BrakeTimeoutElapsed;
TranslationState.DriveCommReady := (PRG_02_Acquisition.Data.M3_StatusWord_Filtered AND 16#0080) <> 0;
TranslationState.DrivePowerReady := (PRG_02_Acquisition.Data.M3_StatusWord_Filtered AND 16#0001) <> 0;
TranslationState.MaintenanceTargetEnable := PRG_03_Modes_Cycle.Auth.MaintenanceM3TargetEnable;
TranslationState.SimulationModeActive := GVL_Simulation.SimulationModeActive;

// 🛡️ Producteur unique (CODE_QUALITY_STANDARDS §5) : la safety M3 (instSafetyTranslationM3)
// est la source de tous les diagnostics de sécurité (ErrorLimitSwitch/ErrorSensorIncoherent).
// Les erreurs propres au mouvement (frein, variateur AC600) restent sur TranslationState.ErrorId
// ci-dessus, bitfield différent, jamais mélangé.
TranslationSafety.SafeStop := M3_SafeStop_Aggregate;
TranslationSafety.PowerCutOff := instSafetyTranslationM3.PowerCutOff;
TranslationSafety.Error := instSafetyTranslationM3.Status.Error;
TranslationSafety.ErrorId := instSafetyTranslationM3.Status.ErrorId;
TranslationSafety.ErrorOperatorComm := instSafetyTranslationM3.ErrorOperatorComm;
TranslationSafety.ErrorDriveComm := instSafetyTranslationM3.ErrorDriveComm;
TranslationSafety.ErrorPhaseRotation := instSafetyTranslationM3.ErrorPhaseRotation;
TranslationSafety.ErrorBrakeThermal := instSafetyTranslationM3.ErrorBrakeThermal;
TranslationSafety.ErrorMecaB := instSafetyTranslationM3.ErrorMecaB;
TranslationSafety.ErrorMecaA := instSafetyTranslationM3.ErrorMecaA;
TranslationSafety.ErrorLimitSwitch := instSafetyTranslationM3.ErrorLimitSwitch;
TranslationSafety.ErrorSensorIncoherent := instSafetyTranslationM3.ErrorSensorIncoherent;
TranslationSafety.PowerCutOffSafety := PRG_06_Outputs.M3PowerCutOffSafetyInfo;
TranslationSafety.SafeStopSafety := PRG_06_Outputs.M3SafeStopSafetyInfo;
TranslationSafety.BlockedBySafety := PRG_06_Outputs.M3BlockedBySafetyInfo;

// === 🔌 PUBLICATION BUS INTER-PRG (Data : ST_TranslationInterPrg) ===
// Copie des structs internes vers le bus de sortie (producteur unique).
Data.TranslationFinalInterlockRequest := TranslationFinalInterlockRequest;
Data.TranslationState                 := TranslationState;
Data.TranslationSafety                := TranslationSafety;

{endregion}
END_PROGRAM
