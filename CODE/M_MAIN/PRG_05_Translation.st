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
    instArbM3                   : FB_TranslationCmdArbitrationM3; // * [INST] Arbitrage commande translation M3
    ArbM3_IHM                   : ST_fbTranslationCmdArbitration_IHM;     // . [LOC] Entrées IHM FB d'arbitrage M3
    ArbM3_Context               : ST_fbTranslationCmdArbitration_Context; // . [LOC] Contexte gating FB d'arbitrage M3
    ArbM3_Cfg                   : ST_fbTranslationCmdArbitration_Cfg;     // . [LOC] Config FB d'arbitrage M3 (fréquence max)

    // 🔧 Config regroupée de FB_Translation (C3 — pattern NC-110/G380, source unique GVL_PERSISTENT)
    TranslationCfg              : ST_fbTranslation_Cfg;                     // . [LOC] Cfg FB_Translation, assemblée depuis GVL_PERSISTENT

    // === 📊 STRUCTS INTERNES (publiés via Data) ===
    TranslationFinalInterlockRequest : ST_TranslationFinalInterlockRequest; // . [LOC] Demande finale et interlocks translation M3
    TranslationState                 : ST_TranslationState;                 // . [LOC] Etat public translation M3
    TranslationSafety                : ST_SafetyTranslation;                // . [LOC] Diagnostic et securites translation M3

    M3_RunRequest_Active    : BOOL;
    M3_ReqTremie_Active     : BOOL;
    M3_ReqMaintenance_Active : BOOL;
    M3_CommandConflict      : BOOL;
    M3_SpeedCmd_Active      : REAL;
    M3_PositioningActive    : BOOL;
    M3_PositionSensorTarget : BOOL;
    SimBtnIHM_Active        : BOOL; // . [LOC] Stimuli boutons IHM M3 actifs (simulation ET JoyMaster inactif)

    SelTarget       : INT;

    M3_SafeStop_Active      : BOOL; // SafeStop sur défaut module d'entrée (InputModuleFault, AF06 §3bis)
    M3_SafeStop_Aggregate   : BOOL; // 🛡️ SafeStop réellement appliqué au mouvement = InputModuleFault OR safety M3 (8 mécanismes)

    // 🟢 Permis directionnels M3 EFFECTIFS (D1 — Phase 3) : information de POSSIBILITÉ de
    // mouvement dans une direction, donnée AVANT l'ordre. Reflète les conditions physiques/
    // logiques (fins de course, défauts, autorisation cible) — PAS la commande (homme-mort).
    // Pour M3, les conditions physiques sont calculées ici à partir des faits Safety ;
    // pas de permis secondaire (pas de benne/Kobold comme les treuils).
    EffectivePermitM3_Tremie    : BOOL; // 🟢 Permis effectif M3 vers Trémie (Safety)
    EffectivePermitM3_Maintenance : BOOL; // 🟢 Permis effectif M3 vers Maintenance (Safety)

    M3_HeightInterlockOk    : BOOL; // TRUE = M1 ET M2 au-dessus de la hauteur mini (ou bypass actif)
    M3_LimitSwitchMaintenanceEffective : BOOL; // Coupure dure §5bis — bascule sur P1 si Maintenance interdite (ex-M3_LimitSwitchRevEffective)
    M3_LimitSwitchTremieStable : BOOL; // Verrou bistable Fdc Trémie (mémorisé stable contre les rebonds) (ex-M3_LimitSwitchFwdStable)
    M3_LimitSwitchMaintenanceStable : BOOL; // Verrou bistable Fdc Maintenance/P1 (mémorisé stable contre les rebonds) (ex-M3_LimitSwitchRevStable)

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

    // FdC "soft" DIRECTIONNEL approche trémie : trémie pleine OU grille levée -> approche
    // trémie interdite, recul (Maintenance/P1) toujours libre. Distinct de la position
    // physique (M3_LimitSwitchTremieStable). PAS de latch sur recul (signal process :
    // dès qu'il retombe l'approche est re-permise). Débounce anti-parasite. Bypass N2.
    M3_TremieProcessBlock : BOOL;

    // T249-B : texte statut position M3 (lecture seule IHM) — jeton "at position" sur
    // front capteur (M3_AtXxxStable) sinon zone entre 2 capteurs (SensorsWord).
    M3_StatusText        : STRING(80);
    M3_SensorsWordPrev   : BYTE;   // detection franchissement (RAZ jeton sans dependance frequence)
    M3_SensorsWordChanged : BOOL;
    M3_AtWorkPositionStable : BOOL; // M3 arrete P1 ou Maintenance — lecture STATIQUE mot capteurs (vrai des le boot)
    TonTremieProcessBlock : TON;

    // 🕵️ Trace de blocage terrain (publiée via Data.TranslationTrace, consommée FB_TroubleshootingView)
    TranslationTrace           : ST_TraceTranslation;        // . [LOC] Trace blocage translation M3
    TraceTranslation_PrevReason : E_TranslationTraceBlockReason; // . [LOC] Cause précédente M3 (détection de changement)
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
Data.M3_SensorWordIncoherent := instPosDecoderM3.Incoherent;
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
                        OR (PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable
                            AND PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable
                            AND (PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM >= GVL_PERSISTENT._TranslationMinHeightM1M2_M)
                            AND (PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM >= GVL_PERSISTENT._TranslationMinHeightM1M2_M));
TranslationState.HeightInterlockBlocking := NOT M3_HeightInterlockOk;

{endregion}

{region "§0bis Coupure dure limite translation"}
// === 🚧 §0bis COUPURE DURE (LimitSwitchMaintenance) — bascule sur P1 si Maintenance interdite ===
// LimitSwitchTremie/Maintenance protègent nativement Trémie/Maintenance
// (§5bis FB_Translation : coupure immédiate, sans rampe, dès que CommandedDirection insiste
// dans l'extrémité). P1/P2 n'ont aucune protection dure équivalente — seul le verrou souple
// (arrival-lock) les couvre. Quand Maintenance est interdite, la coupure dure doit protéger
// P1 comme si c'était l'extrémité réelle : mot 00001 (P1=0 ET Maintenance=1), UN CRAN AVANT
// la vraie extrémité Maintenance (00000) — backup si le verrou souple a déjà échoué à arrêter
// avant P1, garde la machine hors de la zone interdite plutôt que d'attendre le vrai fond.
M3_LimitSwitchMaintenanceEffective := SEL(PRG_03_Modes_Cycle.Data.Auth.MaintenanceM3TargetEnable,
                                   NOT instPosDecoderM3.TranslationPosP1 AND instPosDecoderM3.TranslationPosMaintenance,
                                   instPosDecoderM3.LimitSwitchMaintenance);

// 🔒 §0ter STABILISATION BISTABLE FINS DE COURSE EXTRÊMES (Trémie & Maintenance/P1)
// Maintient la détection stable à 1 même si le capteur physique vibre ou saute brièvement.
// Se libère uniquement sur un mouvement effectif dans le SENS INVERSE (dégagement).
// FdC LATCHE : un rebond capteur ne libere RIEN. On ne perd l'extreme Tremie qu'en
// commandant le SENS INVERSE (M3_ReqMaintenance_Active). (Ne pas rajouter de liberation
// sur mot capteurs : rebond 11111<->01111 -> flicker autorisation translation, REX MES.)
IF instPosDecoderM3.LimitSwitchTremie THEN
    M3_LimitSwitchTremieStable := TRUE;
ELSIF M3_ReqMaintenance_Active THEN
    M3_LimitSwitchTremieStable := FALSE;
END_IF;

// 🔒 §0quater FdC SOFT DIRECTIONNEL — APPROCHE TRÉMIE INTERDITE (trémie pleine / grille)
// Bloque UNIQUEMENT le sens trémie via EffectivePermitM3_Tremie ; le recul vers
// Maintenance/P1 reste libre (EffectivePermitM3_Maintenance non touché). N'entre PAS
// dans M3_LimitSwitchTremieStable -> l'info position / le voyant IHM « pont au FdC
// trémie » restent fidèles à la position physique. Aucun latch sur recul : dès que
// TremieFull_OR_GateRaised_DI retombe, l'approche est re-permise. Débounce 200 ms.
// Bypass N2 : LimitSwitch ou Global.
// ⚠️ Signal PAS ENCORE CÂBLÉ (ST_HwMachine) : polarité TRUE = bloqué à CONFIRMER au câblage.
TonTremieProcessBlock(
    IN := PRG_02_Acquisition.HwIn.Machine.TremieFull_OR_GateRaised_DI
          AND NOT GVL_IHM.TranslationM3.Bypass.LimitSwitch
          AND NOT GVL_IHM.TranslationM3.Bypass.Global,
    PT := T#200ms);
M3_TremieProcessBlock := TonTremieProcessBlock.Q;

// FdC LATCHE (idem Tremie) : rebond capteur ne libere rien. Perte de l'extreme
// Maintenance uniquement sur commande sens inverse (Tremie) ou sortie de la zone
// Maintenance en positionnement cible.
IF M3_LimitSwitchMaintenanceEffective THEN
    M3_LimitSwitchMaintenanceStable := TRUE;
ELSIF M3_ReqTremie_Active OR (PRG_03_Modes_Cycle.Data.Auth.MaintenanceM3TargetEnable AND NOT instPosDecoderM3.LimitSwitchMaintenance) THEN
    M3_LimitSwitchMaintenanceStable := FALSE;
END_IF;

// 🔒 §0quater MÉMORISATION DU DERNIER POINT ATTEINT (front → jeton unique)
// PositionDecoder n'émet qu'un front transitoire (1 cycle) par capteur, montant OU descendant
// SELON LE SENS (voir FB_Translation_PositionDecoder.st) — mémorisé ici pour
// tenir le niveau nécessaire au débounce (100ms) + verrou anti-rebond (§4ter DirectionAtArrival)
// de FB_Translation, et pour l'affichage IHM. MUTUELLEMENT EXCLUSIFS : un nouveau front RAZ tous
// les autres (jeton "dernier point franchi" unique). Libéré
// (RAZ complet) UNIQUEMENT sur mouvement CONFIRMÉ (fréquence réelle mesurée, pas juste la consigne
// de sens) soutenu ≥1.5s — pas un rebond capteur ni un changement de sens instantané.
M3_ConfirmedMoving := (UINT_TO_REAL(PRG_02_Acquisition.Data.M3.ActualFrequencyHz) / 100.0) > 0.5;
TonM3ConfirmedMoving(IN := M3_ConfirmedMoving, PT := T#1s500ms);

// RAZ jeton "at position" = changement du mot capteurs (franchissement reel), SANS
// dependance a la frequence variateur (souvent 0 au banc -> l'ancien RAZ ne se
// declenchait jamais -> jeton colle). Un franchissement qui EST une arrivee re-arme
// le bon jeton via les branches TranslationAtXxx ci-dessous (priorite sur la RAZ).
M3_SensorsWordChanged := (instPosDecoderM3.SensorsWord <> M3_SensorsWordPrev);
M3_SensorsWordPrev := instPosDecoderM3.SensorsWord;

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
ELSIF M3_SensorsWordChanged THEN
    // Le mot capteurs a change sans que ce soit une arrivee -> on a quitte le dernier point.
    M3_AtTremieStable := FALSE; M3_AtPVStable := FALSE; M3_AtP2Stable := FALSE; M3_AtP1Stable := FALSE; M3_AtMaintenanceStable := FALSE;
END_IF;

// --- M3 a une position de travail : STATIQUE (mot capteurs), pas un jeton de franchissement ---
// Les jetons M3_AtXxxStable ne se posent que sur un FRONT capteur : au boot PLC, pont deja
// pose a P1 ou Maintenance sans mouvement -> jetons FALSE -> le verrou descente treuil
// (T249-A) resterait bloque jusqu'a devoir franchir un capteur. On complete donc par une
// lecture STATIQUE du mot : 00011 = zone P2->P1 (capteur P1 fait, P2 depasse) ; 00000 =
// extreme Maintenance.
// ATTENTION : 00011 couvre TOUTE la zone P2->P1 (15..20 m), pas le seul point P1. On
// n'autorise donc la lecture statique QUE si le pont est A L'ARRET et sans cible en cours,
// sinon la descente treuil serait permise pendant le transit P2->P1 (5 m). Le jeton
// M3_AtP1Stable (front) reste la voie normale quand le pont vient d'arriver.
M3_AtWorkPositionStable := (NOT instPosDecoderM3.Incoherent)
    AND ( M3_AtP1Stable OR M3_AtMaintenanceStable
          OR ( (instPosDecoderM3.SensorsWord = 2#00011 OR instPosDecoderM3.SensorsWord = 2#00000)
               AND NOT M3_ConfirmedMoving
               AND NOT M3_ReqTremie_Active
               AND NOT M3_ReqMaintenance_Active ) );

{endregion}

{region "§1 Arbitrage cible et direction"}
// === 🔀 §1 ARBITRAGE DU SÉLECTEUR DE CIBLE ET DE LA DIRECTION ===

// ── Arbitrage M3 (FB_TranslationCmdArbitrationM3) ──
// Remplissage des structs d'arbitrage (champ par champ, CODESYS 3.5 refuse l'init anonyme en appel)
// 🎛️ Stimuli boutons IHM M3 : en simulation ET JoyMaster inactif, les stimuli pilotent les
// boutons IHM (SEL) ; sinon la valeur IHM réelle est conservée (jamais écrasée, producteur unique).
SimBtnIHM_Active := GVL_Simulation.SimulationModeActive AND NOT GVL_IHM.Modes.Cmd.TglJoystickMaster;
ArbM3_IHM.BtnTremie         := SEL(SimBtnIHM_Active, GVL_IHM.TranslationM3.Cmd.BtnTremie, GVL_Simulation.SimBtnTremie);
ArbM3_IHM.BtnMaintenance    := SEL(SimBtnIHM_Active, GVL_IHM.TranslationM3.Cmd.BtnMaintenance, GVL_Simulation.SimBtnMaintenance);
ArbM3_IHM.SelPositioning    := GVL_IHM.TranslationM3.Cmd.SelPositioning;
ArbM3_IHM.SetFreq_Hz        := GVL_IHM.TranslationM3.Cmd.SetFreq_Hz;
ArbM3_IHM.BypassGlobal      := GVL_IHM.TranslationM3.Bypass.Global;

ArbM3_Context.HeightInterlockOk := M3_HeightInterlockOk;
ArbM3_Cfg.MaxFreq_Hz            := GVL_PERSISTENT._TranslationMaxFreq_Hz;

instArbM3(
    Enable         := TRUE,
    Joystick       := PRG_02_Acquisition.Data.Joystick,
    Auth           := PRG_03_Modes_Cycle.Data.Auth,
    ReqTranslation := PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation,
    IHM            := ArbM3_IHM,
    TglJoystickMaster := GVL_IHM.Modes.Cmd.TglJoystickMaster,
    Context        := ArbM3_Context,
    Cfg            := ArbM3_Cfg
);
M3_PositioningActive := instArbM3.PositioningActive;
SelTarget := instArbM3.SelTarget;
M3_RunRequest_Active := instArbM3.RunRequest;
M3_ReqTremie_Active := instArbM3.ReqTremie;
M3_ReqMaintenance_Active := instArbM3.ReqMaintenance;
M3_CommandConflict := instArbM3.CommandConflict;
M3_SpeedCmd_Active := instArbM3.SpeedPct;

// InvertDirection est appliqué dans FB_Translation (InvertDriveDirection), uniquement au mot
// de commande variateur en sortie — les bits ReqTremie/ReqMaintenance restent le sens sémantique réel.

// 🩺 InputModuleFault (AF06 §3bis) : un module DI TOR hors service rend indisponibles
// les retours frein/thermique/positions du VH_0808ETP/VH_0800END portant M3 — rampe rapide.
M3_SafeStop_Active := PRG_02_Acquisition.Data.InputModules.Fault;

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
    IF M3_ReqTremie_Active THEN
        // En Marche Avant (+1 vers Trémie) : seule Trémie est le point d'arrêt automatique
        M3_PositionSensorTarget := M3_AtTremieStable;
    ELSIF M3_ReqMaintenance_Active THEN
        // En Marche Arrière (-1 vers Maintenance) :
        // - Si Maintenance autorisée -> arrêt sur Maintenance
        // - Si Maintenance interdite -> arrêt sur P1
        IF PRG_03_Modes_Cycle.Data.Auth.MaintenanceM3TargetEnable THEN
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
    Enable                  := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE),
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Data.Auth.Mode,
    JoystickOnline          := PRG_02_Acquisition.Data.Network.Joystick.Online,
    JoystickOperational     := PRG_02_Acquisition.Data.Network.Joystick.Operational,
    HeartbeatIhmOk          := GVL_IHM.Commun.HeartbeatIhmOk,
    PhaseRotationOk         := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
    BrakeThermalFeedback    := NOT PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI,
    DriveOnline             := PRG_02_Acquisition.Data.Network.DriveM3.Online,
    DriveOperational        := PRG_02_Acquisition.Data.Network.DriveM3.Operational,
    DriveStatusWord         := PRG_02_Acquisition.Data.M3.StatusWord,
    DriveActualFreqHz       := UINT_TO_REAL(PRG_02_Acquisition.Data.M3.ActualFrequencyHz) / 100.0,
    BrakeFeedback           := SEL(GVL_IHM.TranslationM3.Bypass.ContactorFeedback OR GVL_IHM.TranslationM3.Bypass.Global, PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI, instTranslationM3.BrakeReleaseRequest),
    BrakeCmd                := instTranslationM3.BrakeReleaseRequest,
    RunRequest              := M3_RunRequest_Active,
    ReqTremie               := M3_ReqTremie_Active,
    ReqMaintenance          := M3_ReqMaintenance_Active,
    LimitSwitchTremie       := M3_LimitSwitchTremieStable,
    LimitSwitchMaintenance  := M3_LimitSwitchMaintenanceStable,
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
// + Verrou translation pendant le cycle de homing machine (HX2..HX6) : le chariot M3
//   ne doit pas bouger tant que M1/M2 se référencent (produit par FB_CycleMachineHoming,
//   publié PRG_02.Data.MachineHoming.M3Locked). Pas de bypass : conscient = quitter le cycle.
M3_SafeStop_Aggregate := M3_SafeStop_Active
                         OR instSafetyTranslationM3.SafeStop
                         OR PRG_02_Acquisition.Data.MachineHoming.M3Locked;

{endregion}

{region "§1ter Permis effectifs M3 (D1)"}
// === 🟢 §1ter PERMIS EFFECTIFS M3 (D1 — Phase 3) ===
// Niveau exposé à l'IHM = EFFECTIF, aligné sur les treuils M1/M2 (PRG_04 §5).
// ⚠️ Le permit est une INFORMATION DE POSSIBILITÉ de mouvement dans une direction,
// donnée AVANT l'ordre. Il reflète que l'axe est PRÊT À FONCTIONNER (pas de défaut,
// puissance, thermique) ET que la direction est physiquement possible (fins de course,
// autorisation cible). Il ne reflète PAS la commande (homme-mort) : l'homme-mort est une
// condition de COMMANDE (arbitrage FB_TranslationCmdArbitrationM3 / FB_CycleSemiAuto), pas de
// possibilité — il n'entre donc PAS dans le permit exposé.
// Pour M3, le Safety (FB_Safety_Translation) fournit les faits de sécurité :
//   - TremieLimitClear = NOT LimitSwitchTremie (direction possible vers Trémie)
//   - MaintenanceLimitClear = NOT LimitSwitchMaintenance (direction possible jusqu'à P1)
//   - SafeStop / PowerCutOff = défauts (thermique, Méca A/B, incohérence, comm, phases...)
// Le permis effectif = fait de limite libre AND NOT SafeStop AND NOT PowerCutOff
// (prêt à fonctionner), aligné sur le modèle treuils où le Safety produit déjà des
// permis gatés par les défauts. Pas de Process supplémentaire (pas de benne/Kobold).
// ⚠️ Le verrou « descente treuil interdite tant que M3 pas à P1 » (DumpAtTremieDescentLocked)
// est côté TREUIL (PRG_04 §5, lignes 802-805), pas dans le permit M3 : le permit M3 reste une
// information de possibilité de mouvement de la translation, indépendante de l'état de la trémie.
// ⚠️ Le permit M3 est un permit EFFECTIF « pouvoir bouger » (prêt à fonctionner), PAS un pur
// directionnel. Quand l'axe est en défaut (SafeStop/PowerCutOff), TOUS les sens sont bloqués ;
// au retour en condition, un sens peut être permis et pas l'autre. L'interdiction d'accès à la
// zone Maintenance ne retire PAS le permis de rejoindre P1 : elle agit sur la cible et la
// coupure dure M3_LimitSwitchMaintenanceEffective.
EffectivePermitM3_Tremie    := instSafetyTranslationM3.TremieLimitClear
                               AND NOT M3_SafeStop_Aggregate
                               AND NOT instSafetyTranslationM3.PowerCutOff
                               AND NOT M3_TremieProcessBlock;
EffectivePermitM3_Maintenance := instSafetyTranslationM3.MaintenanceLimitClear
                                  AND NOT M3_SafeStop_Aggregate
                                  AND NOT instSafetyTranslationM3.PowerCutOff;

{endregion}

{region "§2 Pilotage translation M3"}
// === ⚙️ §2 EXÉCUTION PILOTAGE TRANSLATION M3 ===

// 🔧 Assemblage de la config FB_Translation (C3) — SOURCE UNIQUE : GVL_PERSISTENT.
// Fini le double sourcing (rampes flat + vitesses d'approche via GVL_IHM.TranslationM3.Cfg).
// Les 3 vitesses d'approche sont lues dans _TranslationCfgPersist (miroir persistant de
// ST_TranslationCfg, synchronisé par FB_CfgPersistBridge_TranslationCfg dans PRG_07) — la
// valeur reflète toute modification IHM persistée. Les délais (DirectionInterlockDelay,
// CaptorDebounce, BrakeDelay*, BrakeFeedbackTimeout) restent aux valeurs défaut du struct
// (non réglés IHM) — même comportement qu'avant (non câblés, défauts FB).
TranslationCfg.CfgRampAccelRate           := _TranslationRampAccelRate_Pct;
TranslationCfg.CfgRampDecelNormalRate     := _TranslationRampDecelNormal_Pct;
TranslationCfg.CfgRampDecelFastRate       := _TranslationRampDecelFast_Pct;
TranslationCfg.DriveFreqScaleMaxHz        := _TranslationMaxFreq_Hz;
TranslationCfg.ApproachSpeedTremieHz      := _TranslationCfgPersist.CfgApproachSpeedTremie_Hz;
TranslationCfg.ApproachSpeedMaintenanceHz := _TranslationCfgPersist.CfgApproachSpeedMaintenance_Hz;
TranslationCfg.ApproachSpeedP1Hz          := _TranslationCfgPersist.CfgApproachSpeedP1_Hz;

instTranslationM3(
    Enable                  := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE),
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Data.Auth.Mode,
    RunRequest              := M3_RunRequest_Active,
    SafeStop                := M3_SafeStop_Aggregate,
    ReqTremie               := M3_ReqTremie_Active,
    ReqMaintenance          := M3_ReqMaintenance_Active,
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
                                   AND NOT PRG_03_Modes_Cycle.Data.Auth.MaintenanceM3TargetEnable,
    LimitSwitchTremie       := M3_LimitSwitchTremieStable,
    LimitSwitchMaintenance  := M3_LimitSwitchMaintenanceStable,
    // 🛡️ Permis directionnels SAFETY (source unique instSafetyTranslationM3) — gate de sens FB_Translation
    EffectivePermitM3_Tremie := EffectivePermitM3_Tremie,
    EffectivePermitM3_Maintenance := EffectivePermitM3_Maintenance,
    DriveStatusWord         := PRG_02_Acquisition.Data.M3.StatusWord,
    DriveActualFreqHz       := UINT_TO_REAL(PRG_02_Acquisition.Data.M3.ActualFrequencyHz) / 100.0,
    Cfg                     := TranslationCfg,
    BrakeFeedback           := SEL(GVL_IHM.TranslationM3.Bypass.ContactorFeedback OR GVL_IHM.TranslationM3.Bypass.Global, PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI, instTranslationM3.BrakeReleaseRequest),
    BypassContactorCheck    := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.ContactorFeedback,
    BypassLimitSwitch       := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.LimitSwitch
);

// 📐 Estimateur de position continue M3 (odométrie + recalage 5 capteurs)
instPosEstimatorM3(
    Enable               := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE),
    Reset                := PRG_07_Supervision.FaultMachineReset_IHM,
    DriveActualFreqHz    := TO_REAL(PRG_02_Acquisition.Data.M3.ActualFrequencyHz) / 100.0,
    ReqTremie            := M3_ReqTremie_Active,
    ReqMaintenance       := M3_ReqMaintenance_Active,
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

// === T249-B : TEXTE STATUT POSITION M3 (lecture seule IHM) ============================
// Source = jeton "at position" sur front capteur (M3_AtXxxStable, mecanisme d'origine,
// RAZ sur changement de mot capteurs). Sinon zone entre 2 capteurs via SensorsWord
// (code thermometre cumulatif). AUCUNE dependance a la frequence variateur.
IF M3_AtTremieStable THEN
    M3_StatusText := 'M3 a la Tremie';
ELSIF M3_AtMaintenanceStable THEN
    M3_StatusText := 'M3 a la Maintenance';
ELSIF M3_AtP1Stable THEN
    M3_StatusText := 'M3 a P1';
ELSIF M3_AtP2Stable THEN
    M3_StatusText := 'M3 a P2';
ELSIF M3_AtPVStable THEN
    M3_StatusText := 'M3 a PV';
ELSIF instPosDecoderM3.Incoherent THEN
    M3_StatusText := 'M3 capteurs INCOHERENTS';
ELSE
    CASE instPosDecoderM3.SensorsWord OF
        2#11111: M3_StatusText := 'M3 a la Tremie';
        2#01111: M3_StatusText := 'M3 entre Tremie et PV';
        2#00111: M3_StatusText := 'M3 entre PV et P2';
        2#00011: M3_StatusText := 'M3 entre P2 et P1';
        2#00001: M3_StatusText := 'M3 entre P1 et Maintenance';
        2#00000: M3_StatusText := 'M3 a la Maintenance';
    ELSE
        M3_StatusText := 'M3 position indeterminee';
    END_CASE;
END_IF;
// Suffixe sens de deplacement (commande active).
IF M3_ReqTremie_Active THEN
    M3_StatusText := CONCAT(M3_StatusText, ' -> Tremie');
ELSIF M3_ReqMaintenance_Active THEN
    M3_StatusText := CONCAT(M3_StatusText, ' -> Maintenance');
END_IF;

{endregion}

{region "§3 Publication demande translation"}
// === 📤 §3 PUBLICATION DEMANDE BRUTE TRANSLATION ===

TranslationFinalInterlockRequest.Enable := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE);
TranslationFinalInterlockRequest.Reset := PRG_07_Supervision.FaultMachineReset_IHM;
TranslationFinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
TranslationFinalInterlockRequest.SafeStop := M3_SafeStop_Aggregate;
TranslationFinalInterlockRequest.PowerCutOff := instSafetyTranslationM3.PowerCutOff;
TranslationFinalInterlockRequest.EffectivePermitM3_Tremie := EffectivePermitM3_Tremie;
TranslationFinalInterlockRequest.EffectivePermitM3_Maintenance := EffectivePermitM3_Maintenance;
TranslationFinalInterlockRequest.BrakeReleaseRequest := instTranslationM3.BrakeReleaseRequest;
TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed := instTranslationM3.BrakeCommandOpenConfirmed;
TranslationFinalInterlockRequest.RequestedDriveControlWord := instTranslationM3.RequestedDriveControlWord;
TranslationFinalInterlockRequest.RequestedDriveFreqHz := instTranslationM3.RequestedDriveFreqHz;

{endregion}

{region "§4 Publication etat IHM"}
// === 📤 PUBLICATION ÉTAT TRANSLATION IHM (lecture seule) ===
IF instTranslationM3.Fault.Error THEN
    TranslationState.FBState := E_State.ERROR;
ELSIF ABS(instTranslationM3.RequestedDriveFreqHz) > 0.1 THEN
    TranslationState.FBState := E_State.BUSY;
ELSE
    TranslationState.FBState := E_State.READY;
END_IF;
TranslationState.Ready := instTranslationM3.Ready;
TranslationState.Busy := (ABS(instTranslationM3.RequestedDriveFreqHz) > 0.1);
TranslationState.Done := instTranslationM3.TargetReached;
TranslationState.Error := instTranslationM3.Fault.Error;
TranslationState.ErrorId := instTranslationM3.Fault.ErrorId;
TranslationState.BrakeCmd := instTranslationM3.BrakeReleaseRequest;
TranslationState.BrakeCommandOpenConfirmed := instTranslationM3.BrakeCommandOpenConfirmed;
// 🔌 Retour physique direct frein M3 (même source que le SEL §1bis/§2) — consommé FB_TroubleshootingView Idx108
TranslationState.BrakeFeedback := PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI;
TranslationState.PositionReached := instTranslationM3.TargetReached;
TranslationState.DriveControlWord := instTranslationM3.RequestedDriveControlWord;
TranslationState.DriveFreqCmd_Hz := instTranslationM3.RequestedDriveFreqHz;
// 🎯 Cohérence sim : les bits actifs/SpeedCmd_Pct n'affichent la
// consigne QUE si la commande variateur est réellement émise (RequestedDriveControlWord <> 0).
// Sinon, un interlock bloquant (hauteur, SafeStop…) laisserait l'IHM suggérer un mouvement
// qui n'a pas lieu ("je bouge mais ça bouge pas"). Affiche 0 quand c'est bloqué.
TranslationState.ActiveTremie := instTranslationM3.RequestedDriveControlWord = 1;
TranslationState.ActiveMaintenance := instTranslationM3.RequestedDriveControlWord = 2;
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
// T249-B : "at position" par PLAGE (capteur ON + estime +/-0.5 m) — fiable sans
// dependance frequence variateur, contrairement a AtXxx (front/frequence). + texte statut.
TranslationState.M3StatusText      := M3_StatusText;
TranslationState.EstimatedPosM3_M := instPosEstimatorM3.PositionEstimatedM;
TranslationState.SensorsWord := instPosDecoderM3.SensorsWord;
TranslationState.SensorWordIncoherent := instPosDecoderM3.Incoherent;
TranslationState.LimitSwitchTremie := M3_LimitSwitchTremieStable;
TranslationState.LimitSwitchMaintenance := M3_LimitSwitchMaintenanceStable;
TranslationState.DriveActualFreq_Hz := TO_REAL(PRG_02_Acquisition.Data.M3.ActualFrequencyHz) / 100.0;
TranslationState.DriveThermalOk := PRG_02_Acquisition.HwIn.Translation.M3_ThermalOK_DI;
// 🛡️ Pas de sortie State sur FB_TranslationOutputInterlock : le "vrai état" de la
// barrière finale M3 est dérivé de son défaut (READY normal / ERROR sur défaut barrière).
IF PRG_06_Outputs.instTranslationOutputInterlockM3.Fault.Error THEN
    TranslationState.FinalInterlockState := E_State.ERROR;
ELSE
    TranslationState.FinalInterlockState := E_State.READY;
END_IF;
TranslationState.FinalInterlockReason := PRG_06_Outputs.instTranslationOutputInterlockM3.Reason;
TranslationState.FinalInterlockError := PRG_06_Outputs.instTranslationOutputInterlockM3.Fault.Error;
TranslationState.FinalInterlockErrorId := PRG_06_Outputs.instTranslationOutputInterlockM3.Fault.ErrorId;
TranslationState.FinalBrakeTimeoutElapsed := PRG_06_Outputs.instTranslationOutputInterlockM3.BrakeTimeoutElapsed;
TranslationState.DriveCommReady := (PRG_02_Acquisition.Data.M3.StatusWord AND 16#0080) <> 0;
TranslationState.DrivePowerReady := (PRG_02_Acquisition.Data.M3.StatusWord AND 16#0001) <> 0;
TranslationState.MaintenanceTargetEnable := PRG_03_Modes_Cycle.Data.Auth.MaintenanceM3TargetEnable;
TranslationState.SimulationModeActive := GVL_Simulation.SimulationModeActive;

// 🛡️ Producteur unique (CODE_QUALITY_STANDARDS §5) : la safety M3 (instSafetyTranslationM3)
// est la source de tous les diagnostics de sécurité (ErrorLimitSwitch/ErrorSensorIncoherent).
// Les erreurs propres au mouvement (frein, variateur AC600) restent sur TranslationState.ErrorId
// ci-dessus, bitfield différent, jamais mélangé.
TranslationSafety.SafeStop := M3_SafeStop_Aggregate;
TranslationSafety.PowerCutOff := instSafetyTranslationM3.PowerCutOff;
TranslationSafety.Error := instSafetyTranslationM3.Fault.Error;
TranslationSafety.ErrorId := instSafetyTranslationM3.Fault.ErrorId;
TranslationSafety.LatchedId := instSafetyTranslationM3.Fault.LatchedId;
TranslationSafety.ErrorOperatorComm := instSafetyTranslationM3.ErrorOperatorComm;
TranslationSafety.ErrorDriveComm := instSafetyTranslationM3.ErrorDriveComm;
TranslationSafety.ErrorPhaseRotation := instSafetyTranslationM3.ErrorPhaseRotation;
TranslationSafety.ErrorBrakeThermal := instSafetyTranslationM3.ErrorBrakeThermal;
TranslationSafety.ErrorMecaB := instSafetyTranslationM3.ErrorMecaB;
TranslationSafety.ErrorMecaA := instSafetyTranslationM3.ErrorMecaA;
TranslationSafety.ErrorLimitSwitch := instSafetyTranslationM3.ErrorLimitSwitch;
TranslationSafety.ErrorSensorIncoherent := instSafetyTranslationM3.ErrorSensorIncoherent;
// 🟢 Permis directionnels M3 EFFECTIFS (D1 — Safety AND Process, §1ter) — projetés vers l'IHM
// (source safety : FB_Safety_Translation ; fusion Process en local, modèle treuils PRG_04 §5)
TranslationSafety.EffectivePermitM3_Tremie := EffectivePermitM3_Tremie;
TranslationSafety.EffectivePermitM3_Maintenance := EffectivePermitM3_Maintenance;
TranslationSafety.PowerCutOffSafety := PRG_06_Outputs.M3PowerCutOffSafetyInfo;
TranslationSafety.SafeStopSafety := PRG_06_Outputs.M3SafeStopSafetyInfo;
TranslationSafety.BlockedBySafety := PRG_06_Outputs.M3BlockedBySafetyInfo;

{region "§4bis Trace de blocage terrain M3 (ST_TraceTranslation)"}
// === ↔️ §4bis TRACE DE BLOCAGE TERRAIN M3 (cause priorisée + horodatage) ===
// Diagnostic lecture seule, publié via Data.TranslationTrace et consommé par FB_TroubleshootingView.
// L'ordre IF/ELSIF EST l'ordre de priorité (cf. E_TranslationTraceBlockReason) : la cause la plus
// grave gagne. BlockReasonTimestamp est latched au premier scan du changement (1 scan, mémoire).
// Aucune action de conduite ne dépend de ces champs.
TranslationTrace.SafeStopActive           := M3_SafeStop_Aggregate;
TranslationTrace.SafeStopSourceInput      := M3_SafeStop_Active;
TranslationTrace.SafeStopSourceSafety     := instSafetyTranslationM3.SafeStop;
TranslationTrace.PowerCutOffActive        := instSafetyTranslationM3.PowerCutOff;
TranslationTrace.HeightInterlockBlocking  := NOT M3_HeightInterlockOk;
TranslationTrace.DriveOperational         := PRG_02_Acquisition.Data.Network.DriveM3.Operational;
TranslationTrace.FinalInterlockError      := TranslationState.FinalInterlockError;
// 🟢 Permis directionnels par sens EFFECTIFS (D1 — Safety AND Process, §1ter) — reflet exact des permis appliqués
TranslationTrace.EffectivePermitM3_Tremie      := EffectivePermitM3_Tremie;
TranslationTrace.TremieProcessBlockActive      := M3_TremieProcessBlock;
TranslationTrace.EffectivePermitM3_Maintenance := EffectivePermitM3_Maintenance;

// Permis de mouvement effectif = toutes les barrières levées (agrégat diagnostic)
TranslationTrace.MotionPermitEffective := NOT M3_SafeStop_Aggregate
    AND NOT instSafetyTranslationM3.PowerCutOff
    AND M3_HeightInterlockOk
    AND PRG_02_Acquisition.Data.Network.DriveM3.Operational
    AND NOT TranslationState.FinalInterlockError
    AND NOT instTranslationM3.Fault.Error;

IF instSafetyTranslationM3.PowerCutOff THEN
    TranslationTrace.BlockReason := E_TranslationTraceBlockReason.POWER_CUTOFF;
ELSIF M3_SafeStop_Aggregate THEN
    TranslationTrace.BlockReason := E_TranslationTraceBlockReason.SAFESTOP;
ELSIF instSafetyTranslationM3.Fault.Error THEN
    TranslationTrace.BlockReason := E_TranslationTraceBlockReason.SAFETY_FAULT;
ELSIF NOT M3_HeightInterlockOk THEN
    TranslationTrace.BlockReason := E_TranslationTraceBlockReason.HEIGHT_INTERLOCK;
ELSIF NOT PRG_02_Acquisition.Data.Network.DriveM3.Operational THEN
    TranslationTrace.BlockReason := E_TranslationTraceBlockReason.DRIVE_UNAVAILABLE;
ELSIF TranslationState.FinalInterlockError THEN
    TranslationTrace.BlockReason := E_TranslationTraceBlockReason.FINAL_INTERLOCK;
ELSIF instTranslationM3.Fault.Error THEN
    TranslationTrace.BlockReason := E_TranslationTraceBlockReason.FAULT;
ELSE
    TranslationTrace.BlockReason := E_TranslationTraceBlockReason.NONE;
END_IF;
IF TranslationTrace.BlockReason <> TraceTranslation_PrevReason THEN
    TranslationTrace.BlockReasonTimestamp := TIME_TO_UDINT(TIME());
END_IF;
TraceTranslation_PrevReason := TranslationTrace.BlockReason;
{endregion}

// 🧩 Cause de blocage priorisée sur l'état public IHM (miroir de la trace terrain §4bis)
TranslationState.AxisBlockReason := TranslationTrace.BlockReason;

// === 🔌 PUBLICATION BUS INTER-PRG (Data : ST_TranslationInterPrg) ===
// Copie des structs internes vers le bus de sortie (producteur unique).
Data.TranslationFinalInterlockRequest := TranslationFinalInterlockRequest;
Data.TranslationState                 := TranslationState;
Data.TranslationSafety                := TranslationSafety;
// Arret confirme sur retour reel variateur : la consigne peut deja etre nulle
// pendant la deceleration, elle ne prouve donc pas l'arret physique de M3.
Data.TranslationBusy                  := (ABS(UINT_TO_REAL(PRG_02_Acquisition.Data.M3.ActualFrequencyHz) / 100.0) > 0.5);
Data.TranslationDone                  := instTranslationM3.TargetReached;
Data.M3_AtTremieStable                := M3_AtTremieStable;
Data.M3_AtP1Stable                    := M3_AtP1Stable;
Data.M3_AtMaintenanceStable           := M3_AtMaintenanceStable;
Data.M3_AtWorkPositionStable          := M3_AtWorkPositionStable;
// 🕵️ Trace de blocage terrain (consommée FB_TroubleshootingView)
Data.TranslationTrace                 := TranslationTrace;

{endregion}
END_PROGRAM
