(* ═══════════════════════════════════════════════════════════════
   🧪 FB_SimBench — Enveloppe unique de simulation pour banc d'essai
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   
   🎯 Rôle : Compose les 4 blocs de modèle de simulation existants :
      - FB_Sim_Encoder (instM1, instM2)
      - FB_Sim_Translation (instTranslation)
      - FB_Sim_Joystick (instJoystick)
      - FB_Sim_Safety (instSafety)
   
   🔒 Brique réduite : 0 lecture de variable globale en interne.
      Toutes les entrées (commandes, stimuli, HwReal) sont passées en paramètres.
   
   🔴 RÈGLES SÉCURITÉ ET POLARITÉ :
      - Modèle frein M1/M2/M3 : M1_BrakeIsOpen_DI := M1_BrakeCmd (1 = OUVERT).
        Ne JAMAIS faire NOT BrakeCmd !
      - Retours contacteurs M1/M2 : 1 = tous retombés (TRUE quand RelayFwd=0 et RelayRev=0).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_SimBench
VAR_INPUT
    Enable                     : BOOL;             (* --> [CMD] Activation globale (GVL_Simulation.SimulationModeActive) *)

    // ── Commandes issues de l'automate (Scan N-1 / PRG_07 / PRG_10) ──────────
    M1_RelayFwd                : BOOL;   (* --> [CMD] Sens avant M1 *)
    M1_RelayRev                : BOOL;   (* --> [CMD] Sens arrière M1 *)
    // Les 4 contacteurs de palier participent au retour unique
    // « tous contacteurs retombés » — sans eux, le modèle annonce l'arrêt alors qu'un
    // palier est encore engagé (fausse condition d'armement Méca A).
    M1_SpeedContactor_1        : BOOL;   (* --> [HW] Contacteur palier 1 M1 *)
    M1_SpeedContactor_2        : BOOL;   (* --> [HW] Contacteur palier 2 M1 *)
    M1_SpeedContactor_3        : BOOL;   (* --> [HW] Contacteur palier 3 M1 *)
    M1_SpeedContactor_4        : BOOL;   (* --> [HW] Contacteur palier 4 M1 *)
    M1_SpeedCmd_Pct            : REAL;   (* --> [CMD] Consigne vitesse M1 *)
    M1_StepNumber              : INT;    (* --> [CMD] Palier vitesse courant M1 (1..5) *)
    M1_PresetTriggerCmd        : WORD;   (* --> [CMD] Trigger preset M1 *)
    M1_PresetValueOut          : UDINT;   (* --> [CFG] Valeur preset M1 *)
    M1_BrakeCmd                : BOOL;             (* --> [CMD] TRUE = commande desserrage frein M1 *)

    M2_RelayFwd                : BOOL;   (* --> [CMD] Sens avant M2 *)
    M2_RelayRev                : BOOL;   (* --> [CMD] Sens arrière M2 *)
    M2_SpeedContactor_1        : BOOL;   (* --> [HW] Idem M1, voir ci-dessus *)
    M2_SpeedContactor_2        : BOOL;   (* --> [HW] Contacteur palier 2 M2 *)
    M2_SpeedContactor_3        : BOOL;   (* --> [HW] Contacteur palier 3 M2 *)
    M2_SpeedContactor_4        : BOOL;   (* --> [HW] Contacteur palier 4 M2 *)
    M2_SpeedCmd_Pct            : REAL;   (* --> [CMD] Consigne vitesse M2 *)
    M2_StepNumber              : INT;    (* --> [CMD] Palier vitesse courant M2 (1..5) *)
    M2_PresetTriggerCmd        : WORD;   (* --> [CMD] Trigger preset M2 *)
    M2_PresetValueOut          : UDINT;   (* --> [CFG] Valeur preset M2 *)
    M2_BrakeCmd                : BOOL;             (* --> [CMD] TRUE = commande desserrage frein M2 *)

    M3_ReqTremie               : BOOL;             (* --> [CMD] Demande explicite vers Trémie *)
    M3_ReqMaintenance          : BOOL;             (* --> [CMD] Demande explicite vers Maintenance *)
    M3_SpeedCmd_Pct            : REAL;   (* --> [CMD] Consigne vitesse M3 *)
    M3_BrakeCmd                : BOOL;             (* --> [CMD] TRUE = commande desserrage frein M3 *)

    PowerKeepAlive_A           : BOOL;             (* --> [SAFE] TRUE = relais A maintenu sagement par le PLC *)
    PowerKeepAlive_B           : BOOL;             (* --> [SAFE] TRUE = relais B maintenu sagement par le PLC *)
    EmergencyArming_RQ         : BOOL;             (* --> [CMD] Impulsion de réarmement puissance *)
    TestCutActive              : BOOL;             (* --> [SAFE] Test de redondance AU en cours (canal A ou B coupé) *)
    PowerCutOffRequest         : BOOL;             (* --> [SAFE] Requête coupure métier (TRUE = arrêt d'urgence) *)
    SimChainOkBit              : BOOL;             (* --> [TST] Bit opérateur : TRUE = simuler chaîne AU fermée *)

    // ── Stimuli & Paramètres de banc ─────────────────────────────────────────
    SimEncoderSpeedFactor      : REAL := 1.0;   (* --> [CFG] Facteur vitesse codeur *)
    SimWinchCoast_M            : REAL := 0.35;  (* --> [CFG] Roulis inertiel treuils simules apres coupure relais (m) — modelise l'anticipation d'arret meca (benne) ; ~0.35 = finit dans la bande ouvert/ferme malgre l'anticipation d'arret *)
    SimTopPositionActive       : BOOL := FALSE; (* --> [TST] Injection manuelle capteur haut actif (essai ciblé) *)
    SimSyncDeviationInjectM1   : BOOL := FALSE;   (* --> [TST] Injection écart synchro M1 *)
    SimSyncDeviationInjectM2   : BOOL := FALSE;   (* --> [TST] Injection écart synchro M2 *)
    SimSyncDeviationOffset_M   : REAL := 0.5;   (* --> [TST] Offset écart synchro *)

    SimM3SensorsWordOverrideActive : BOOL := FALSE;   (* --> [TST] Override mot capteurs M3 *)
    SimM3SensorsWord               : BYTE := 16#07;   (* --> [TST] Mot capteurs M3 forcé *)

    SimJoystickLeft_Rev_TREMIE_Active  : BOOL := FALSE;   (* --> [TST] Bouton joystick gauche *)
    SimJoystickRight_Fwd_MAINT_Active  : BOOL := FALSE;   (* --> [TST] Bouton joystick droite *)
    SimJoystickFwd_Up_Close_Active     : BOOL := FALSE;   (* --> [TST] Bouton joystick avant *)
    SimJoystickRev_Down_Open_Active    : BOOL := FALSE;   (* --> [TST] Bouton joystick arrière *)
    SimJoystickRawX                    : INT := 5000;   (* --> [TST] Valeur brute X *)
    SimJoystickRawY                    : INT := 5000;   (* --> [TST] Valeur brute Y *)
    SimJoystickRawButton               : BOOL := FALSE;   (* --> [TST] Bouton homme-mort *)
    SimJoystickOvershoot_Active        : BOOL := FALSE;   (* --> [TST] Dépassement de montée au-delà de 100% (défaut capteur hors plage) *)
    SimJoystickBagotement_Active       : BOOL := FALSE;   (* --> [TST] Bagotement au relâchement (petit balancement autour du neutre) *)

    SimKoboldContactValue      : BOOL := FALSE;   (* --> [TST] Contact fond Kobold *)
    BtnEmergencyStop           : BOOL := FALSE;    (* --> [TST] Simulation appui coup-de-poing AU *)

    // ── Image réelle fallback ────────────────────────────────────────────────
    HwReal                     : ST_HardwareImage;   (* --> [HW] Image réelle fallback *)
END_VAR

VAR_OUTPUT
    (* Sorties d'état du profil AF_Partie-03 §2.
       En LD, CODESYS réserve la PREMIÈRE broche de sortie au flux du rung :
       `Ready` n'y porte jamais d'expression, les broches suivantes oui. *)
    Ready                      : BOOL;             (* <-- [STAT] TRUE = banc prêt (Enable actif, modèles à jour) *)
    Busy                       : BOOL;             (* <-- [STAT] TRUE = cycle de simulation en cours *)
    Done                       : BOOL;             (* <-- [STAT] TRUE = images de simulation publiées ce scan *)

    Winch                      : ST_HwWinch;   (* <-- [DIAG] Image treuils simulée *)
    Translation                : ST_HwTranslation;   (* <-- [DIAG] Image translation simulée *)
    Operator                   : ST_HwOperator;   (* <-- [DIAG] Image opérateur simulée *)
    Machine                    : ST_HwMachine;   (* <-- [DIAG] Image machine simulée *)
END_VAR

VAR_IN_OUT
    RawPosM1                   : UDINT;            (* <-> [BUS] Mémoire _SimEncoderRawPosM1 dans GVL_PERSISTENT *)
    RawPosM2                   : UDINT;            (* <-> [BUS] Mémoire _SimEncoderRawPosM2 dans GVL_PERSISTENT *)
END_VAR

VAR CONSTANT
    CST_M3FullTravelTimeS       : REAL := 8.0; // Temps de Trémie à Maintenance à 100 %, modèle banc uniquement
END_VAR

VAR
    // Modèles sous-jacents
    instSimEncoderM1           : FB_Sim_Encoder;   (* * [INST] Modèle codeur M1 *)
    instSimEncoderM2           : FB_Sim_Encoder;   (* * [INST] Modèle codeur M2 *)
    instSimTranslation         : FB_Sim_Translation;   (* * [INST] Modèle translation M3 *)
    instSimJoystick            : FB_Sim_Joystick;   (* * [INST] Modèle joystick *)
    instSimSafety              : FB_Sim_Safety;   (* * [INST] Modèle sécurité *)

    // Calculs internes
    M1_PresetCmd               : BOOL;   (* . [LOC] Trigger preset M1 *)
    M2_PresetCmd               : BOOL;   (* . [LOC] Trigger preset M2 *)
    M1_OffsetPts               : DINT;   (* . [LOC] Offset synchro M1 *)
    M2_OffsetPts               : DINT;   (* . [LOC] Offset synchro M2 *)

    M3_RelayFwd                : BOOL;   (* . [LOC] Sens avant M3 *)
    M3_RelayRev                : BOOL;   (* . [LOC] Sens arrière M3 *)

    SimJoystickDirectionCount  : INT;   (* . [LOC] Nombre de directions actives *)

    M3_ActualFreqHz            : UINT;   (* . [LOC] Fréquence simulée M3 *)
    M3_StatusWordSim           : WORD;   (* . [LOC] StatusWord simulé M3 *)

    // Roulis dynamique avec dispersion pseudo-aléatoire (±0.1m autour de l'anticipation)
    M2_RelayFwdPrev            : BOOL;   (* . [LOC] Mémoire relais Fwd N-1 *)
    M2_RelayRevPrev            : BOOL;   (* . [LOC] Mémoire relais Rev N-1 *)
    RandomSeed                 : UDINT := 123456789; (* . [LOC] Générateur LCG pseudo-aléatoire *)
    M2_EffectiveCoastM         : REAL := 0.35;       (* . [LOC] Distance de roulis M2 courante *)
END_VAR

// === IMPLEMENTATION ===

{region "§1 Repli image reelle banc desactive"}
IF NOT Enable THEN
    // 🔌 Banc désactivé : repli sur l'image réelle, aucune simulation en cours
    Ready       := FALSE;
    Busy        := FALSE;
    Done        := FALSE;
    Winch       := HwReal.Winch;
    Translation := HwReal.Translation;
    Operator    := HwReal.Operator;
    Machine     := HwReal.Machine;
    RETURN;
END_IF;

// ▶️ Banc actif : le cycle de simulation démarre pour ce scan
Ready := TRUE;
Busy  := TRUE;
Done  := FALSE;


{endregion}

{region "§2 Simulation treuils M1/M2"}
// ── 1. MODÈLE TREUILS (M1 + M2) ─────────────────────────────────────────────
// Presets codeurs : déclenchés si PresetTriggerCmd = 2
M1_PresetCmd := (M1_PresetTriggerCmd = 2);
M2_PresetCmd := (M2_PresetTriggerCmd = 2);

// Conversions d'injection d'écart synchro (0.5m -> points codeur avec 8192 pts/tour, 2m/tour)
// 1m = 4096 points codeur.
M1_OffsetPts := REAL_TO_DINT(SimSyncDeviationOffset_M * 4096.0);
M2_OffsetPts := REAL_TO_DINT(SimSyncDeviationOffset_M * 4096.0);

// Instance modèle codeur M1
instSimEncoderM1(
    Enable           := TRUE,
    RelayFwd         := M1_RelayFwd,
    RelayRev         := M1_RelayRev,
    StepNumber       := M1_StepNumber,
    PresetCmd        := M1_PresetCmd,
    PresetValue      := M1_PresetValueOut,
    SpeedScaleFactor := SimEncoderSpeedFactor,
    CoastDistanceM   := SimWinchCoast_M,
    TestOffsetCmd    := SimSyncDeviationInjectM1,
    TestOffsetPts    := M1_OffsetPts,
    RawPos           := RawPosM1
);

// Détection coupure relais M2 pour renouveler la dispersion pseudo-aléatoire (±0.1m)
IF (M2_RelayFwdPrev AND NOT M2_RelayFwd) OR (M2_RelayRevPrev AND NOT M2_RelayRev) THEN
    // Générateur LCG 32-bit standard : X_{n+1} = (1103515245 * X_n + 12345) MOD 2^31
    RandomSeed := (RandomSeed * 1103515245 + 12345) AND 16#7FFFFFFF;
    // Dispersion pseudo-aléatoire entre -0.10 m et +0.10 m
    M2_EffectiveCoastM := SimWinchCoast_M + (UDINT_TO_REAL(RandomSeed MOD 2000) / 10000.0) - 0.10;
END_IF;
M2_RelayFwdPrev := M2_RelayFwd;
M2_RelayRevPrev := M2_RelayRev;

// Instance modèle codeur M2 (avec roulis et dispersion)
instSimEncoderM2(
    Enable           := TRUE,
    RelayFwd         := M2_RelayFwd,
    RelayRev         := M2_RelayRev,
    StepNumber       := M2_StepNumber,
    PresetCmd        := M2_PresetCmd,
    PresetValue      := M2_PresetValueOut,
    SpeedScaleFactor := SimEncoderSpeedFactor,
    CoastDistanceM   := M2_EffectiveCoastM,
    TestOffsetCmd    := SimSyncDeviationInjectM2,
    TestOffsetPts    := M2_OffsetPts,
    RawPos           := RawPosM2
);

// Recopie structures Winch simulées :
// 🛑 POLARITÉ DE FREIN SIMULÉ : 1 = contacteur commandé = frein OUVERT.
// Câblage réel : DI = 1 ⟺ frein OUVERT. Le modèle produit donc M1_BrakeIsOpen_DI := M1_BrakeCmd !
Winch.M1_BrakeIsOpen_DI        := M1_BrakeCmd;
// Retour UNIQUE « tous contacteurs retombés » = sens ET vitesse.
// Omettre les paliers ferait croire à l'arrêt pendant les transitoires → Méca A armée à tort.
Winch.M1_ContactorsReleased_DI := NOT (M1_RelayFwd OR M1_RelayRev
                                    OR M1_SpeedContactor_1 OR M1_SpeedContactor_2
                                    OR M1_SpeedContactor_3 OR M1_SpeedContactor_4);
Winch.M1_ThermalOk_DI          := TRUE; // Sauf panne simulée

Winch.M2_BrakeIsOpen_DI        := M2_BrakeCmd;
Winch.M2_ContactorsReleased_DI := NOT (M2_RelayFwd OR M2_RelayRev
                                    OR M2_SpeedContactor_1 OR M2_SpeedContactor_2
                                    OR M2_SpeedContactor_3 OR M2_SpeedContactor_4);
Winch.M2_ThermalOk_DI          := TRUE;

// Cohérent avec M2_TensionedCable_DI (sain par défaut) : capteur TOP libre en simu,
// sauf stimulus manuel SimTopPositionActive (injection de fait capteur au banc).
Winch.M1M2_TopPositionFree_DI  := NOT SimTopPositionActive;
Winch.M2_TensionedCable_DI     := TRUE; // Câble tendu en simu

Winch.COD1_PosValue            := instSimEncoderM1.RawPosOut;
Winch.COD1_Alarms              := 0;
Winch.COD1_Warnings            := 0;
Winch.COD1_DeviceState         := DEVICE_STATE.RUNNING; // État device RUNNING (bus OK)

Winch.COD2_PosValue            := instSimEncoderM2.RawPosOut;
Winch.COD2_Alarms              := 0;
Winch.COD2_Warnings            := 0;
Winch.COD2_DeviceState         := DEVICE_STATE.RUNNING; // État device RUNNING


{endregion}

{region "§3 Simulation translation M3"}
// ── 2. MODÈLE TRANSLATION M3 (AC600) ─────────────────────────────────────────
M3_RelayFwd := M3_ReqTremie AND NOT M3_ReqMaintenance;
M3_RelayRev := M3_ReqMaintenance AND NOT M3_ReqTremie;

instSimTranslation(
    Enable          := TRUE,
    ReqTremie       := M3_RelayFwd,
    ReqMaintenance  := M3_RelayRev,
    SpeedTgt_Pct    := M3_SpeedCmd_Pct,
    FullTravelTimeS := CST_M3FullTravelTimeS
);

// Remplissage capteurs de position M3 : l'override manuel conserve exactement le
// même ordre que FB_Translation_PositionDecoder (bit4=Trémie ... bit0=Maintenance).
IF SimM3SensorsWordOverrideActive THEN
    Translation.M3_PosTremie_DI      := SimM3SensorsWord.4;
    Translation.M3_PosPV_DI          := SimM3SensorsWord.3;
    Translation.M3_PosPVP2_DI        := SimM3SensorsWord.2;
    Translation.M3_PosP1_DI          := SimM3SensorsWord.1;
    Translation.M3_PosMaintenance_DI := SimM3SensorsWord.0;
ELSE
    Translation.M3_PosTremie_DI      := instSimTranslation.PosTremie;
    Translation.M3_PosPV_DI          := instSimTranslation.PosPV;
    Translation.M3_PosPVP2_DI        := instSimTranslation.PosP2;
    Translation.M3_PosP1_DI          := instSimTranslation.PosP1;
    Translation.M3_PosMaintenance_DI := instSimTranslation.PosMaintenance;
END_IF;

// Polarité frein M3 (1 = OUVERT)
Translation.M3_BrakeIsOpen_DI    := M3_BrakeCmd;

// Thermique moteur/variateur AC600 — pas de panne simulée, toujours OK (comme Winch.M1/M2_ThermalOk_DI)
Translation.M3_ThermalOK_DI      := TRUE;

// Simulation StatusWord AC600 : Bit 0 (Power Ready) = 1, Bit 7 (Comm Ready) = 1 -> 16#0087 en mouvement
// Bit0 retombe à l'arrêt, cohérent avec un variateur qui confirme l'arrêt sans rester "actif" —
// FB_Safety_Translation lit ce bit comme indicateur "mouvement non commandé" (Méca B, TonMecaB 3s) :
// un Bit0 forcé à 1 en continu à l'arrêt déclencherait un PowerCutOff simulé permanent après 3s.
// DrivePowerReady (diagnostic IHM seul, non consommé par un interlock) est le seul autre lecteur,
// aucune régression de mouvement possible.
IF M3_RelayFwd OR M3_RelayRev THEN
    M3_StatusWordSim := 16#0087; // + Operating/Running
    M3_ActualFreqHz  := REAL_TO_UINT(M3_SpeedCmd_Pct * 50.0); // 50.0 Hz à 100% (x100 -> 5000)
ELSE
    M3_StatusWordSim := 16#0080; // Comm Ready seul -- Bit0 retombé, arrêt confirmé
    M3_ActualFreqHz  := 0;
END_IF;

Translation.M3_StatusWord        := M3_StatusWordSim;
Translation.M3_ActualFrequencyHz := M3_ActualFreqHz;
Translation.AC600_DeviceState    := DEVICE_STATE.RUNNING; // État device RUNNING


{endregion}

{region "§4 Simulation operateur joystick"}
// ── 3. MODÈLE OPÉRATEUR / JOYSTICK ───────────────────────────────────────────
instSimJoystick(
    Enable              := TRUE,
    NeutralRaw          := 5000,
    MaxRaw              := 10000,
    BtnLeft_Rev_TREMIE  := SimJoystickLeft_Rev_TREMIE_Active,
    BtnRight_Fwd_MAINT  := SimJoystickRight_Fwd_MAINT_Active,
    BtnFwd_Up_Close     := SimJoystickFwd_Up_Close_Active,
    BtnRev_Down_Open    := SimJoystickRev_Down_Open_Active,
    OvershootActive     := SimJoystickOvershoot_Active,
    BagotementActive    := SimJoystickBagotement_Active,
    CycleTimeS          := 0.010
);

// Les boutons directionnels simplifient les essais : une commande unique impose
// une butée d'axe ; aucune commande ou une combinaison reste au neutre / stimulus avancé.
// Le modèle dynamique (montée/retombée/bagotement) pilote RawX/RawY dès qu'un bouton est actif.
SimJoystickDirectionCount := BOOL_TO_INT(SimJoystickLeft_Rev_TREMIE_Active)
                           + BOOL_TO_INT(SimJoystickRight_Fwd_MAINT_Active)
                           + BOOL_TO_INT(SimJoystickFwd_Up_Close_Active)
                           + BOOL_TO_INT(SimJoystickRev_Down_Open_Active);
IF (SimJoystickDirectionCount >= 1) OR instSimJoystick.ReturningActive THEN
    // Bouton(s) actif(s) OU retour dynamique en cours (retombée/bagotement) → sortie du modèle.
    // (≥2 boutons : le modèle gère lui-même le neutre — pas de diagonale implicite.)
    Operator.JoyXRaw_ANA1 := instSimJoystick.RawX;
    Operator.JoyYRaw_ANA2 := instSimJoystick.RawY;
ELSE
    // Modèle au repos → stimulus analogique avancé (mode « sans bouton »).
    Operator.JoyXRaw_ANA1 := SimJoystickRawX;
    Operator.JoyYRaw_ANA2 := SimJoystickRawY;
END_IF;

// Homme-mort : stimulus brut amont. En simulation avec boutons directionnels actifs,
// l'appui homme-mort est automatiquement inclus pour faciliter les essais sur banc.
Operator.JoyBtnRaw := SimJoystickRawButton OR (SimJoystickDirectionCount > 0);

Operator.CanBusState      := 2; // CANbusState 2 = ACTIVE
Operator.JOY1_DeviceState := DEVICE_STATE.RUNNING; // État device RUNNING


{endregion}

{region "§5 Simulation securite et image machine"}
// ── 4. MODÈLE SÉCURITÉ & COMMUNS MACHINE ─────────────────────────────────────
instSimSafety(
    Enable            := TRUE,
    SimChainOkBit     := SimChainOkBit,
    PowerCutOff_A     := PowerKeepAlive_A,
    PowerCutOff_B     := PowerKeepAlive_B,
    PowerCutOffRequest:= PowerCutOffRequest,
    EmergencyArming   := EmergencyArming_RQ,
    BtnEmergencyStop  := BtnEmergencyStop,
    TestCutActive     := TestCutActive
);

Machine.PowerContactorEngaged_DI   := instSimSafety.SimContactorOk;
Machine.EmergencyChainClosed_DI    := instSimSafety.SimChainOk;
Machine.PhaseRotationOk_DI             := TRUE;
Machine.M1_M2_M3_BrakeThermalOk_DI     := TRUE;
Machine.M1_M2_KoboldBottomTouch_DI     := SimKoboldContactValue;
Machine.HydraulicThermalOk_DI          := TRUE;
Machine.TremieFull_OR_GateRaised_DI    := FALSE; // Pas encore câblé, simulé inactif par défaut

// ✅ Cycle de simulation terminé : les 4 images sont publiées pour ce scan
Busy := FALSE;
Done := TRUE;

{endregion}

END_FUNCTION_BLOCK
