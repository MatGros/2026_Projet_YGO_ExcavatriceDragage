(* =======================================================================
   🔌 FB_Encoder — Facade chaine de mesure codeur (1 par treuil M1/M2)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Composer la chaine de mesure pure d'un treuil derriere une
      interface unique : Abs → Scale → Safety → Reliability → Speed.
   🧬 Option B : SANS FB_Encoder_Homing — le referencement reste
      une conduite de treuil dans PRG_04_Treuils_Benne. La facade RECOIT les
      sorties homing (HomingRefRaw, Homed, HomingSuspect, HomingStatus) et
      relaie PresetRequest/PresetValue <-> Abs.
   🔒 Fiabilite : gate EncoderFault (sans Homed) calcule AVANT Speed — purge
      de vitesse au meme scan (D-A10 complement c). HomedAndReliable = gate
      strict reserve a l'interlock hauteur M3 (D-A11/C1).
   🧬 Pure composition : chaque sous-FB garde sa responsabilite et reste
      testable isolement. Aucune fusion de logique.
   📄 Doc : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.1.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Encoder
VAR_INPUT
    // === COMMANDES & AUTORISATIONS ===
    Enable                : BOOL;        // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset                 : BOOL;        // --> [CMD] Acquittement defaut (front montant)
    Mode                  : E_Mode;      // --> [CMD] Mode d'exploitation actif
    PowerContactorEngaged : BOOL;        // --> [HW]  Ligne puissance enclenchee

    // === BUS ETHERCAT & CAPTEUR HW ===
    RawPosIn              : UDINT;       // --> [HW]  Position brute EtherCAT
    AlarmsIn              : UINT;        // --> [HW]  Codes alarmes bruts EtherCAT
    WarningsIn            : UINT;        // --> [HW]  Codes avertissements bruts EtherCAT
    SlaveOperational      : BOOL;        // --> [HW]  Statut esclave EtherCAT operationnel

    // === SORTIES HOMING EXTERNE (PRG_04_Treuils_Bonne) ===
    HomingRefRaw          : UDINT;       // --> [CFG] Reference brute figee au dernier homing
    Homed                 : BOOL;        // --> [STAT] Codeur reference (FB_Encoder_Homing)
    HomingSuspect         : BOOL;        // --> [DIAG] Incoherence redemarrage a lever
    HomingStatus          : ST_FbStatus; // --> [STAT] Statut complet FB_Encoder_Homing

    // === RELAIS VERS HOMING ===
    PresetRequest         : BOOL;        // --> [CMD] Demande preset (front) -> relayee a Abs
    PresetValue           : UDINT;       // --> [CFG] Valeur de preset -> relayee a Abs

    // === PARAMETRES & REGLAGES ===
    PointsPerRev          : UDINT := 8192; // --> [CFG] Resolution codeur (pts/tour)
    CableM_PerRev         : REAL := 2.0;   // --> [CFG] Developpement cable par tour (m/tour)
    PositionMinM          : REAL := -99.0; // --> [CFG] Plafond bornage physique bas (m)
    PositionMaxM          : REAL := 99.0;  // --> [CFG] Plafond bornage physique haut (m)
    BypassGlobal          : BOOL := FALSE; // --> [TST] Neutralisation defauts pour mise en service
END_VAR
VAR_OUTPUT
    // === ETATS IEC & SYNOPTIQUE ===
    Ready                 : BOOL;        // <-- [STAT] FB pret a fonctionner
    Status                : ST_FbStatus; // <-- [STAT] Statut transverse facade (synthese)

    // === RELAIS VERS HOMING ===
    PresetAck             : BOOL;        // <-- [STAT] Pulse confirmation preset reussi
    PresetNak             : BOOL;        // <-- [STAT] Pulse echec / timeout preset

    // === MESURES CONDITIONNEES (struct frontiere) ===
    Measurement           : ST_EncoderMeasurement; // <-- [BUS] Mesures + statuts (interface)
END_VAR
VAR
    // === SOUS-INSTANCES FB (chaine de mesure) ===
    instAbs        : FB_Encoder_Abs;          // * [INST] Acquisition brute codeur EtherCAT
    instScale      : FB_Encoder_Scale;        // * [INST] Mise a l'echelle points -> metres
    instSafety     : FB_Encoder_Safety;       // * [INST] Bornage & coherence mesure
    instRel        : FB_EncoderReliability;   // * [INST] Gates de fiabilite
    instSpeed      : FB_Encoder_SpeedMeasure; // * [INST] Calcul vitesse cable
END_VAR

{region "§1 Gate neutralisation"}
// 🛑 1. GATE — neutralisation generale
IF NOT Enable THEN
    Ready := FALSE; Status.Busy := FALSE; Status.Done := FALSE; Status.Error := FALSE; Status.ErrorId := 16#0000;
    Status.State := E_State.DISABLED;
    PresetAck := FALSE; PresetNak := FALSE;
    Measurement.RawPos := 0; Measurement.EncoderAvailable := FALSE;
    Measurement.CablePosM := 0.0; Measurement.EncoderIncoherent := FALSE;
    Measurement.Speed_Mps := 0.0; Measurement.SignedSpeed_Mps := 0.0; Measurement.SpeedValid := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
Status.State := E_State.READY;
{endregion}

{region "§2 Abs"}
// 🔌 2. ACQUISITION BRUTE (Abs)
instAbs(
    Enable                := Enable,
    Reset                 := Reset,
    PowerContactorEngaged := PowerContactorEngaged,
    Mode                  := Mode,
    RawPosIn              := RawPosIn,
    AlarmsIn              := AlarmsIn,
    WarningsIn            := WarningsIn,
    SlaveOperational      := SlaveOperational,
    PresetRequest         := PresetRequest,
    PresetValue           := PresetValue,
    PointsPerRev          := PointsPerRev
);
PresetAck := instAbs.PresetAck;
PresetNak := instAbs.PresetNak;
{endregion}

{region "§3 Scale"}
// --- 3. MISE A L'ECHELLE POINTS -> METRES
instScale(
    RawPos        := instAbs.RawPos,
    HomingRefRaw  := HomingRefRaw,
    CableM_PerRev := CableM_PerRev,
    PointsPerRev  := PointsPerRev
);
{endregion}

{region "§4 Safety"}
// --- 4. BORNAGE & COHERENCE
instSafety(
    Enable                := Enable,
    Reset                 := Reset,
    PowerContactorEngaged := PowerContactorEngaged,
    Mode                  := Mode,
    CablePosM             := instScale.CablePosM,
    HomingSuspect         := HomingSuspect,
    PositionMinM          := PositionMinM,
    PositionMaxM          := PositionMaxM,
    BypassGlobal          := BypassGlobal
);
{endregion}

{region "§5 Fiabilite (gate avant Speed)"}
// --- 5. 🛡️ GATES DE FIABILITE — AVANT Speed (purge vitesse au meme scan)
instRel(
    EncoderAvailable  := instAbs.EncoderAvailable,
    Homed             := Homed,
    EncoderIncoherent := instSafety.EncoderIncoherent
);
{endregion}

{region "§6 Speed"}
// --- 6. ⚡ VITESSE — PositionValid := NOT EncoderFault (gate general, sans Homed)
instSpeed(
    Enable        := Enable,
    Reset         := Reset,
    Position_M    := instSafety.CablePosMSafe,
    PositionValid := NOT instRel.EncoderFault
);
{endregion}

{region "§7 Remplissage struct et synthese"}
// --- 7. 📦 REMPLISSAGE STRUCT FRONTIERE (interface de sortie)
Measurement.RawPos            := instAbs.RawPos;
Measurement.EncoderAvailable  := instAbs.EncoderAvailable;
Measurement.CablePosM         := instSafety.CablePosMSafe;
Measurement.EncoderIncoherent := instSafety.EncoderIncoherent;
Measurement.Speed_Mps         := instSpeed.Speed_Mps;
Measurement.SignedSpeed_Mps   := instSpeed.SignedSpeed_Mps;
Measurement.SpeedValid        := instSpeed.Valid;
Measurement.HomingStatus      := HomingStatus;
Measurement.AbsStatus         := instAbs.Status;
Measurement.HomingRefRaw      := HomingRefRaw;

// Synthese statut facade
Status.Busy := instAbs.Status.Busy;
Status.Done := instSpeed.Valid AND instAbs.Status.Ready;
Status.Error := instAbs.Status.Error OR instSafety.Status.Error;
Status.ErrorId := instAbs.Status.ErrorId OR instSafety.Status.ErrorId;
{endregion}
