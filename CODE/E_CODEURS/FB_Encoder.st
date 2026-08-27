(* =======================================================================
   🔌 FB_Encoder — Objet codeur complet (1 par treuil M1/M2)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regrouper toute la chaine codeur derriere une interface unique :
      Abs → Homing → Scale → Safety → Reliability → Speed.
   🔌 Frontiere hardware separee HwIn/HwOut (testable).
   🔒 Homing : autorise par HomingPermit (calcule par le caller), declenche
      par HomingAtTargetM (front). La cible est fournie par le caller.
   🔒 Fiabilite : gate EncoderFault (sans Homed) calcule AVANT Speed — purge
      de vitesse au meme scan. HomedAndReliable = gate strict interlock M3.
   🧩 Defaut : Fault:ST_Fault rempli par FB_FaultCore (instFault) depuis une liste
      de causes en clair (instCauses) — pattern FB_Joystick. Ready = Enable ET pas de
      defaut late. Interlocks machine sur les faits bruts, jamais sur Fault.Latched.
   📄 Doc : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.3.md
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
    HwIn                  : ST_fbEncoder_HwIn; // --> [HW] Retours hardware codeur

    // === MECANIQUE (constantes) ===
    PointsPerRev          : UDINT := 8192; // --> [CFG] Resolution codeur (pts/tour)
    CableM_PerRev         : REAL := 2.0;   // --> [CFG] Developpement cable par tour (m/tour)

    // === REGLAGES & CONFIGURATION ===
    Cfg                   : ST_fbEncoder_Cfg; // --> [CFG] Mode de confirmation preset
    PositionMinM          : REAL := -99.0; // --> [CFG] Plafond bornage physique bas (m)
    PositionMaxM          : REAL := 99.0;  // --> [CFG] Plafond bornage physique haut (m)
    BypassGlobal          : BOOL := FALSE; // --> [TST] Neutralisation defauts pour mise en service
END_VAR
VAR_OUTPUT
    // === ETATS IEC & SYNOPTIQUE ===
    Ready                 : BOOL;        // <-- [STAT] FB pret a fonctionner (Enable ET pas de defaut late)
    Fault                 : ST_Fault;    // <-- [DIAG] Brique defaut socle (live + latchee), remplie par FB_FaultCore

    // === FRONTIERE HW SORTIE (testable) ===
    HwOut                 : ST_fbEncoder_HwOut; // <-- [ACT] Ordres hardware codeur (preset)

    // === MESURES CONDITIONNEES (struct frontiere) ===
    Measurement           : ST_EncoderMeasurement; // <-- [BUS] Mesures + statuts (interface)

    // === ETATS CODEUR ===
    Homed                 : BOOL;        // <-- [STAT] Codeur reference (sortie homing)
    HomingSuspect         : BOOL;        // <-- [DIAG] Incoherence redemarrage a lever
    EncoderFault          : BOOL;        // <-- [SAFE] Gate general fiabilite (sans Homed)
    HomedAndReliable      : BOOL;        // <-- [STAT] Gate strict M3 : dispo ET ref ET pas incoherent
    PresetConfirmationFailed : BOOL;     // <-- [DIAG] Latch derniere verification preset echouee
END_VAR
VAR
    // === SOUS-INSTANCES FB (chaine codeur complete) ===
    instAbs        : FB_Encoder_Abs;          // * [INST] Acquisition brute codeur EtherCAT
    instHoming     : FB_Encoder_Homing;       // * [INST] Referencement (homing) nominal/unitaire
    instScale      : FB_Encoder_Scale;        // * [INST] Mise a l'echelle points -> metres
    instSafety     : FB_Encoder_Safety;       // * [INST] Bornage & coherence mesure
    instRel        : FB_EncoderReliability;   // * [INST] Gates de fiabilite
    instSpeed      : FB_Encoder_SpeedMeasure; // * [INST] Calcul vitesse cable
    instFault      : FB_FaultCore;            // * [INST] Socle de defaut (liste de causes -> ST_Fault)
    instCauses     : ARRAY[0..15] OF ST_FaultCause; // . [LOC] Liste des causes pour le socle FB_FaultCore
END_VAR
VAR_IN_OUT
    // === CALIBRATION PERSISTANTE (externe RETAIN, jamais membre) ===
    Calib                  : ST_Encoder_Calib; // <-> [BUS] Calibration RETAIN du treuil
END_VAR

{region "§1 Gate neutralisation"}
IF NOT Enable THEN
    Ready := FALSE;
    Measurement.RawPos := 0; Measurement.EncoderAvailable := FALSE;
    Measurement.CablePosM := 0.0; Measurement.CablePosMSafe := 0.0; Measurement.EncoderIncoherent := FALSE;
    Measurement.Speed_Mps := 0.0; Measurement.SignedSpeed_Mps := 0.0; Measurement.SpeedValid := FALSE;
    Measurement.HomingFault.Error := FALSE; Measurement.HomingFault.ErrorId := 16#0000;
    Measurement.HomingLifecycle.Busy := FALSE; Measurement.HomingLifecycle.Done := FALSE;
    Measurement.AbsFault.Error := FALSE;    Measurement.AbsFault.ErrorId := 16#0000;
    EncoderFault := TRUE;
    HomedAndReliable := FALSE;
    // Frontiere HW sortie : aucun ordre preset publie hors autorisation
    // (sinon PRG_02_Acquisition relaie une valeur perimee au codeur absolu -> preset parasite, reference corrompue)
    HwOut.PresetTriggerCmd := 0; HwOut.CodeSeqTriggerCmd := 0; HwOut.PresetValueOut := 0;
    // Reference connue MAINTENUE depuis Calib (RETAIN) meme FB desactive (AF09 §4) :
    // un FB desactive ne doit pas faire perdre la reference aux consommateurs aval (PRG_04, FB_Encoder_Scale).
    Homed := Calib.Homed;
    HomingSuspect := Calib.HomingSuspect;
    Measurement.HomingRefRaw := Calib.HomingRefRaw;
    // PresetConfirmationFailed est un diagnostic latch : il reste gele hors Enable
    // et ne doit pas etre efface par ce gate (AC3).
    // Socle appele meme Enable=FALSE : maintient le latch non acquitte et traite le Reset
    // hors autorisation (AC4). Les causes ne sont pas evaluees (Enable=FALSE -> vue live a 0),
    // les latches sont preserves.
    instFault(Enable := FALSE, Reset := Reset, Causes := instCauses);
    Fault := instFault.Fault;
    RETURN;
END_IF;
Ready := TRUE;
{endregion}

{region "§2 Abs"}
    instAbs(
    Enable              := Enable,
    Reset               := Reset,
    RawPosIn            := HwIn.RawPosIn,
    AlarmsIn            := HwIn.AlarmsIn,
    WarningsIn          := HwIn.WarningsIn,
    SlaveOperational    := HwIn.SlaveOperational,
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
    PresetStatusBit      := HwIn.PresetStatusBit,
    Cfg                  := Cfg,
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
Measurement.HomingFault        := instHoming.Fault;
Measurement.HomingLifecycle    := instHoming.Lifecycle;
Measurement.AbsFault           := instAbs.Fault;
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
PresetConfirmationFailed := instHoming.PresetConfirmationFailed;

// Synthese statut facade : brique defaut socle (Fault:ST_Fault), pattern FB_Joystick.
// Causes exprimees en CLAIR (ST_FaultCause), alimentees UNIQUEMENT depuis les sorties
// publiques des sous-FB (encapsulation stricte, jamais de lecture VAR interne).
//   - Cause 0/1 : LIVE (Latching=FALSE) -> Fault.Error, retombe seule.
//   - Cause 2   : LATCHED (Latching=TRUE) -> arme Fault.Latched, acquittee au Reset front.
// Interlock machine toujours sur les faits bruts (EncoderFault, HomedAndReliable,
// EncoderIncoherent), jamais sur Fault.Latched (conservation).
instCauses[0].Active := NOT instAbs.EncoderAvailable; instCauses[0].Latching := FALSE;
instCauses[0].Texte := 'Perte materiel / communication codeur EtherCAT';
instCauses[1].Active := instSafety.EncoderIncoherent; instCauses[1].Latching := FALSE;
instCauses[1].Texte := 'Incoherence mesure / saut de position codeur';
instCauses[2].Active := instHoming.PresetConfirmationFailed; instCauses[2].Latching := TRUE;
instCauses[2].Texte := 'Echec confirmation transaction preset codeur';

// Socle appele APRES le pipeline : causes du scan courant, aucun scan de retard (AC4).
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;     // source de verite = socle
Ready := Enable AND NOT Fault.Latched;
{endregion}
