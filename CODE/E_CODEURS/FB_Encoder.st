(* =======================================================================
   🔌 FB_Encoder — Objet codeur complet (1 par treuil M1/M2)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regrouper toute la chaine codeur derriere une interface unique :
      Abs → Homing → Scale → Safety → Reliability → Speed.
   🔌 Frontiere hardware exposee en IN/OUT via le bus ST_EncoderHw (testable).
   🔒 Homing : autorise par HomingPermit (calcule par le caller), declenche
      par HomingAtTargetM (front). La cible est fournie par le caller.
   🔒 Fiabilite : gate EncoderFault (sans Homed) calcule AVANT Speed — purge
      de vitesse au meme scan. HomedAndReliable = gate strict interlock M3.
   📄 Doc : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.1.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Encoder
VAR_INPUT
    // === COMMANDES & AUTORISATIONS ===
    Enable                : BOOL;        // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset                 : BOOL;        // --> [CMD] Acquittement defaut (front montant)

    // === AUTORISATION HOMING (calculee par le caller PRG) ===
    HomingPermit          : BOOL;        // --> [CMD] TRUE = l'operateur a le droit de homer

    // === CONSIGNES HOMING ===
    HomingAtTargetM       : BOOL;        // --> [CMD] Demande homing vers cible (front montant)
    HomingAtZero          : BOOL;        // --> [CMD] Force homing a 0.0
    ConfirmCoherence      : BOOL;        // --> [CMD] Lever le doute d'incoherence boot
    CfgHomingTargetM      : REAL;        // --> [CFG] Cible libre homing unitaire (m)
    CfgTopSensorPosM      : REAL;        // --> [CFG] Cible homing nominal capteur haut (m)
    UseDynamicTarget      : BOOL;        // --> [CMD] Active cible dynamique
    DynamicHomingTargetM  : REAL;       // --> [CFG] Cible dynamique de referencement (m)

    // === CAPTEURS PHYSIQUES ===
    TopPositionSensor     : BOOL;        // --> [HW]  Capteur physique position haute unique

    // === BUS ETHERCAT & CAPTEUR HW (frontiere testable) ===
    Hw                    : ST_EncoderHw; // <-> [BUS] Entrees/sorties hardware codeur

    // === MECANIQUE (constantes) ===
    PointsPerRev          : UDINT := 8192; // --> [CFG] Resolution codeur (pts/tour)
    CableM_PerRev         : REAL := 2.0;   // --> [CFG] Developpement cable par tour (m/tour)

    // === REGLAGES (modifiables) ===
    PositionMinM          : REAL := -99.0; // --> [CFG] Plafond bornage physique bas (m)
    PositionMaxM          : REAL := 99.0;  // --> [CFG] Plafond bornage physique haut (m)
    BypassGlobal          : BOOL := FALSE; // --> [TST] Neutralisation defauts pour mise en service
END_VAR
VAR_OUTPUT
    // === ETATS IEC & SYNOPTIQUE ===
    Ready                 : BOOL;        // <-- [STAT] FB pret a fonctionner
    Status                : ST_FbStatus; // <-- [STAT] Statut transverse facade (synthese)

    // === FRONTIERE HW SORTIE (testable) ===
    HwOut                 : ST_EncoderHw; // <-- [BUS] Sorties hardware codeur (preset...)

    // === MESURES CONDITIONNEES (struct frontiere) ===
    Measurement           : ST_EncoderMeasurement; // <-- [BUS] Mesures + statuts (interface)

    // === ETATS CODEUR ===
    Homed                 : BOOL;        // <-- [STAT] Codeur reference (sortie homing)
    HomingSuspect         : BOOL;        // <-- [DIAG] Incoherence redemarrage a lever
    EncoderFault          : BOOL;        // <-- [SAFE] Gate general fiabilite (sans Homed)
    HomedAndReliable      : BOOL;        // <-- [STAT] Gate strict M3 : dispo ET ref ET pas incoherent
END_VAR
VAR
    // === SOUS-INSTANCES FB (chaine codeur complete) ===
    instAbs        : FB_Encoder_Abs;          // * [INST] Acquisition brute codeur EtherCAT
    instHoming     : FB_Encoder_Homing;       // * [INST] Referencement (homing) nominal/unitaire
    instScale      : FB_Encoder_Scale;        // * [INST] Mise a l'echelle points -> metres
    instSafety     : FB_Encoder_Safety;       // * [INST] Bornage & coherence mesure
    instRel        : FB_EncoderReliability;   // * [INST] Gates de fiabilite
    instSpeed      : FB_Encoder_SpeedMeasure; // * [INST] Calcul vitesse cable
END_VAR
VAR_IN_OUT
    // === CALIBRATION PERSISTANTE (externe RETAIN, jamais membre) ===
    Calib                  : ST_Encoder_Calib; // <-> [BUS] Calibration RETAIN du treuil
END_VAR

{region "§1 Gate neutralisation"}
IF NOT Enable THEN
    Ready := FALSE; Status.Busy := FALSE; Status.Done := FALSE; Status.Error := FALSE; Status.ErrorId := 16#0000;
    Status.State := E_State.DISABLED;
    Measurement.RawPos := 0; Measurement.EncoderAvailable := FALSE;
    Measurement.CablePosM := 0.0; Measurement.EncoderIncoherent := FALSE;
    Measurement.Speed_Mps := 0.0; Measurement.SignedSpeed_Mps := 0.0; Measurement.SpeedValid := FALSE;
    EncoderFault := TRUE;
    HomedAndReliable := FALSE;
    RETURN;
END_IF;
Ready := TRUE;
Status.State := E_State.READY;
{endregion}

{region "§2 Abs"}
instAbs(
    Enable              := Enable,
    Reset               := Reset,
    RawPosIn            := Hw.RawPosIn,
    AlarmsIn            := Hw.AlarmsIn,
    WarningsIn          := Hw.WarningsIn,
    SlaveOperational    := Hw.SlaveOperational,
    PresetRequest       := instHoming.PresetRequest,
    PresetValue         := instHoming.PresetValue,
    PointsPerRev        := PointsPerRev
);
{endregion}

{region "§3 Homing"}
instHoming(
    Enable               := Enable,
    Reset                := Reset,
    Home                 := HomingAtTargetM,
    HomingPermit         := HomingPermit,
    BtnConfirmCoherence  := ConfirmCoherence,
    UseDynamicTarget     := UseDynamicTarget,
    DynamicHomingTargetM := DynamicHomingTargetM,
    CfgHomingTargetM     := CfgHomingTargetM,
    CfgTopSensorPosM     := SEL(HomingAtZero, CfgTopSensorPosM, 0.0),
    TopPositionSensor    := TopPositionSensor,
    RawPos               := instAbs.RawPos,
    EncoderAvailable     := instAbs.EncoderAvailable,
    PresetAck            := instAbs.PresetAck,
    PresetNak            := instAbs.PresetNak,
    PointsPerRev         := PointsPerRev,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := CableM_PerRev,
    BypassGlobal         := BypassGlobal,
    Calib                := Calib
);
{endregion}

{region "§4 Scale"}
instScale(
    RawPos       := instAbs.RawPos,
    HomingRefRaw := instHoming.HomingRefRaw,
    CableM_PerRev := CableM_PerRev,
    PointsPerRev := PointsPerRev
);
{endregion}

{region "§5 Safety"}
instSafety(
    Enable             := Enable,
    Reset              := Reset,
    CablePosM          := instScale.CablePosM,
    HomingSuspect      := instHoming.HomingSuspect,
    PositionMinM       := PositionMinM,
    PositionMaxM       := PositionMaxM,
    BypassGlobal       := BypassGlobal
);
{endregion}

{region "§6 Reliability"}
instRel(
    EncoderAvailable  := instAbs.EncoderAvailable,
    Homed             := instHoming.Homed,
    EncoderIncoherent := instSafety.EncoderIncoherent
);
{endregion}

{region "§7 Speed"}
instSpeed(
    Enable        := Enable,
    Reset         := Reset,
    Position_M    := instSafety.CablePosMSafe,
    PositionValid := NOT instRel.EncoderFault
);
{endregion}

{region "§8 Remplissage struct et synthese"}
Measurement.RawPos            := instAbs.RawPos;
Measurement.EncoderAvailable  := instAbs.EncoderAvailable;
Measurement.CablePosM         := instSafety.CablePosMSafe;
Measurement.CablePosMSafe     := instSafety.CablePosMSafe;
Measurement.EncoderIncoherent := instSafety.EncoderIncoherent;
Measurement.Speed_Mps         := instSpeed.Speed_Mps;
Measurement.SignedSpeed_Mps   := instSpeed.SignedSpeed_Mps;
Measurement.SpeedValid        := instSpeed.Valid;
Measurement.HomingStatus      := instHoming.Status;
Measurement.AbsStatus         := instAbs.Status;
Measurement.HomingRefRaw      := instHoming.HomingRefRaw;

// Frontiere HW sortie (preset)
HwOut.PresetTriggerCmd := instAbs.PresetTriggerCmd;
HwOut.CodeSeqTriggerCmd := instAbs.CodeSeqTriggerCmd;
HwOut.PresetValueOut    := instAbs.PresetValueOut;

// Etats codeur
Homed            := instHoming.Homed;
HomingSuspect    := instHoming.HomingSuspect;
EncoderFault     := instRel.EncoderFault;
HomedAndReliable := instRel.HomedAndReliable;

// Synthese statut facade
Status.Busy := instAbs.Status.Busy;
Status.Done := instSpeed.Valid AND instAbs.Ready;
Status.Error := instAbs.Status.Error OR instSafety.Status.Error OR instHoming.Status.Error;
Status.ErrorId := instAbs.Status.ErrorId OR instSafety.Status.ErrorId OR instHoming.Status.ErrorId;
{endregion}
