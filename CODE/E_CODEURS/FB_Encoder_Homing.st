(* =======================================================================
   ⚙️ FB_Encoder_Homing — Référencement codeur nominal ou unitaire
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Séquence de référencement nominal (capteur haut) ou unitaire (MAINT_N2)
   🔒 Polarité : Homed=TRUE dès qu'un référencement valide est enregistré
   🔌 Architecture : Expose ST_Encoder_Calib en VAR_IN_OUT
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.1.md
   ======================================================================= *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Encoder_Homing) ===

FUNCTION_BLOCK PUBLIC FB_Encoder_Homing
VAR_INPUT
    // === COMMANDES & AUTORISATIONS ===
    Enable                 : BOOL;        // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset                  : BOOL;        // --> [CMD] Acquittement defaut (front montant)
    Home                   : BOOL;        // --> [CMD] Demande de referencement (front)
    HomingPermit           : BOOL;        // --> [CMD] Autorisation de homer (calculee par le caller)
    BtnConfirmCoherence    : BOOL;        // --> [CMD] Levee de doute d'incoherence au boot (front)

    // === CIBLES & CONFIGURATION HOMING ===
    CfgHomingTargetM       : REAL;        // --> [CFG] Cible libre homing unitaire (m)
    UseDynamicTarget       : BOOL := FALSE; // --> [CFG] Activation cible dynamique
    DynamicHomingTargetM   : REAL := 0.0; // --> [CFG] Cible dynamique de referencement (m)
    CfgTopSensorPosM       : REAL := 8.5; // --> [CFG] Cible homing nominal capteur haut (m)

    // === RETOURS HW & CAPTEURS ===
    TopPositionSensor      : BOOL;        // --> [HW]  Capteur physique position haute unique
    FwdRevSpeedFeedbackOff : BOOL;        // --> [HW]  Contacteurs sens et vitesse retombes
    BrakeFeedback          : BOOL;        // --> [HW]  Contacteur frein ouvert/desserre

    // === MESURES & RETOURS FB CODEUR ABSOLU ===
    RawPos                 : UDINT;       // --> [HW]  Position brute codeur (sortie FB_Encoder_Abs)
    EncoderAvailable       : BOOL;        // --> [HW]  Codeur absolu disponible et valide
    PresetAck              : BOOL;        // --> [HW]  Pulse confirmation ecriture preset reussie
    PresetNak              : BOOL;        // --> [HW]  Pulse echec / timeout ecriture preset

    // === CARACTERISTIQUES MECANIQUES & BUS ===
    PointsPerRev           : UDINT := 8192; // --> [CFG] Resolution codeur (pts/tour)
    MultiTurnRevsMax       : UDINT := 4096; // --> [CFG] Capacite multitour max codeur (tours)
    CableM_PerRev          : REAL := 2.0;   // --> [CFG] Perimetre tambour / developpement cable (m/tour)

    // === TESTS & BYPASS ===
    BypassGlobal           : BOOL := FALSE; // --> [TST] Neutralisation securites pour mise en service
END_VAR
VAR_OUTPUT
    // === ETATS IEC & SYNOPTIQUE ===
    Ready                  : BOOL;        // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible) — regroupe Busy/Done/Error/ErrorId/State/StateAtError.
    // ErrorId : masque de bits de défaut (bit0: mode, bit1: treuil, bit4: cible, bit5: preset, bit9: incoherence boot).
    Status                 : ST_FbStatus;

    // === COMMANDES VERS FB_ENCODER_ABS ===
    PresetRequest          : BOOL;        // <-- [ACT]  Pulse demande d'ecriture preset SDO
    PresetValue            : UDINT;       // <-- [ACT]  Valeur de cible brute pour preset SDO

    // === RESULTATS & MEMOIRE CALIBRATION ===
    Homed                  : BOOL;        // <-- [STAT] Codeur pagine et referencie
    HomingSuspect          : BOOL;        // <-- [DIAG] Incoherence redemarrage a lever
    HomingRefRaw           : UDINT;       // <-- [DIAG] Offset de reference brut calcule
END_VAR
VAR_IN_OUT
    // === STRUCTURE DE CALIBRATION PERSISTANTE ===
    Calib                  : ST_Encoder_Calib; // <-> [BUS] Structure de calibration RETAIN
END_VAR
VAR
    // === DETECTEURS DE FRONT ===
    ResetEdge              : R_TRIG;      // . [LOC] Detecteur front montant Reset
    ErrorEdge              : R_TRIG;      // . [LOC] Detecteur front montant Error
    HomeEdge               : R_TRIG;      // . [LOC] Detecteur front montant Home
    ConfirmCoherenceEdge   : R_TRIG;      // . [LOC] Detecteur front montant BtnConfirmCoherence
    TopSensorEdge          : R_TRIG;      // . [LOC] Detecteur front montant TopPositionSensor
    DynamicTargetEdge      : R_TRIG;      // . [LOC] Detecteur front montant UseDynamicTarget

    // === ETATS & DRAPEAUX INTERNES ===
    InitDone               : BOOL;        // . [LOC] Controle incoherence boot effectue
    ArretConfirme          : BOOL;        // . [LOC] Condition d'arret moteur confirmee
    HomingModeOk           : BOOL;        // . [LOC] Mode de fonctionnement valide pour homing
    NominalHomingTrigger   : BOOL;        // . [LOC] Condition de declenchement homing nominal
    UnitaryHomingTrigger   : BOOL;        // . [LOC] Condition de declenchement homing unitaire
    DynamicHomingTrigger   : BOOL;        // . [LOC] Condition de declenchement homing dynamique
    HomingTrigger          : BOOL;        // . [LOC] Synthese declenchement homing

    // === VARIABLES DE CALCUL ===
    PresetValueCalc        : UDINT;       // . [LOC] Valeur cible de preset (centre plage)
    TargetPoints           : DINT;        // . [LOC] Ecart cible converti en points
    TargetPositionM        : REAL;        // . [LOC] Cible retenue en metres
    RawDiffRestart         : DINT;        // . [LOC] Ecart brut de position au redemarrage
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Encoder_Homing) ===

{region "§1 Gate neutralisation"}
// 🛑 1. GATE — neutralisation ; on continue toutefois d'exposer le dernier état RETAIN connu
// (FB_Encoder_Scale a besoin de HomingRefRaw même si ce FB est désactivé)
// PowerContactorEngaged retiré du GATE (le codeur 24V / EtherCAT peut être homé disjoncteurs coupés)
IF NOT Enable THEN
    PresetRequest := FALSE;
    PresetValue := 0;
    Status.State := E_State.DISABLED;
    Ready := FALSE; Status.Busy := FALSE; Status.Done := FALSE;
    InitDone := FALSE;   // Force un nouveau contrôle §3.7 à la prochaine activation
    Homed := Calib.Homed;
    HomingSuspect := Calib.HomingSuspect;
    HomingRefRaw := Calib.HomingRefRaw;
    RETURN;
END_IF;

Ready := TRUE;

{endregion}

{region "§2 Fronts et coherence demarrage"}
// 🔑 2. FRONTS
ResetEdge(CLK := Reset);
HomeEdge(CLK := Home);
ConfirmCoherenceEdge(CLK := BtnConfirmCoherence);

// 🔍 3. COHÉRENCE AU REDÉMARRAGE (§3.7) — une fois par session Enable, dès que le codeur répond
IF NOT InitDone THEN
    Status.State := E_State.INIT;
    IF EncoderAvailable THEN
        RawDiffRestart := UDINT_TO_DINT(RawPos) - UDINT_TO_DINT(Calib.LastKnownRawPos);
        IF Calib.Homed AND (ABS(RawDiffRestart) > UDINT_TO_DINT(Calib.RestartCoherenceTolerancePts)) THEN
            Calib.HomingSuspect := TRUE;
            Status.ErrorId := Status.ErrorId OR 16#0200;   // bit9 : incohérence codeur au redémarrage
        END_IF;
        InitDone := TRUE;
    END_IF;
ELSE
    IF Status.State = E_State.INIT THEN Status.State := E_State.READY; END_IF;
END_IF;

{endregion}

{region "§3 Confirmation coherence et demande homing"}
// ✅ 4. LEVÉE DU DOUTE (BtnConfirmCoherence, §3.7) — indépendant du Reset générique
IF ConfirmCoherenceEdge.Q AND (Mode = E_Mode.MAINT_N1 OR Mode = E_Mode.MAINT_N2) THEN
    Calib.HomingSuspect := FALSE;
    Status.ErrorId := Status.ErrorId AND 16#FDFF;   // efface bit9
END_IF;

PresetRequest := FALSE;
TopSensorEdge(CLK := TopPositionSensor);
DynamicTargetEdge(CLK := UseDynamicTarget);

// Gates rejetées = Warning auto-effaçable (§9/TC-P03-007), pas un Fault : recalculées à
// chaque scan, jamais latchées, aucun Reset requis pour les effacer.
Status.ErrorId := Status.ErrorId AND 16#FFEC;   // efface bits 0/1/4 (garde bit5, bit9 — inchangés)

HomingModeOk := HomingPermit;

IF HomeEdge.Q AND NOT HomingModeOk THEN
    Status.ErrorId := Status.ErrorId OR 16#0001;   // bit0 : homing non autorise
END_IF;

// Nominal : capture AU FRONT du capteur haut, pas après arrêt confirmé — AscentPermit
// (FB_Safety_Winch) coupe déjà la montée indépendamment dès que TopPositionSensor est actif ;
// attendre l'arrêt casserait la répétabilité recherchée à vitesse d'accostage constante.
// Couvre les deux cas : Home déjà maintenu quand le capteur déclenche, ou capteur déjà actif
// quand Home est pressé.
NominalHomingTrigger := HomingModeOk AND NOT UseDynamicTarget
                         AND ((Home AND TopSensorEdge.Q) OR (HomeEdge.Q AND TopPositionSensor));

// Unitaire : cible libre (CfgHomingTargetM), déclenchée par la demande (front).
UnitaryHomingTrigger := HomingModeOk AND NOT UseDynamicTarget AND HomeEdge.Q;

// Dynamique (benne) : HomingModeOk vérifié ici en défense.
DynamicHomingTrigger := HomingModeOk AND (DynamicTargetEdge.Q OR (UseDynamicTarget AND HomeEdge.Q));

HomingTrigger := NominalHomingTrigger OR UnitaryHomingTrigger OR DynamicHomingTrigger;

IF HomingTrigger THEN
    IF UseDynamicTarget THEN
        TargetPositionM := DynamicHomingTargetM;
    ELSIF HomeEdge.Q THEN
        TargetPositionM := CfgHomingTargetM;
    ELSE
        TargetPositionM := CfgTopSensorPosM;
    END_IF;

    // Bornage obligatoire avant écriture (CODE_QUALITY_STANDARDS §6) — toute cible, quelle
    // que soit son origine (config, calcul benne, capteur haut), est vérifiée dans la plage
    // physique documentée [-99;+99] m avant d'être gravée dans la référence codeur.
    IF (TargetPositionM < -99.0) OR (TargetPositionM > 99.0) THEN
        Status.ErrorId := Status.ErrorId OR 16#0010;   // bit4 : cible hors plage, homing refusé
    ELSE
        TargetPoints := REAL_TO_DINT(TargetPositionM * UDINT_TO_REAL(PointsPerRev) / CableM_PerRev);
        Calib.HomingRefRaw := DINT_TO_UDINT(UDINT_TO_DINT(RawPos) - TargetPoints);
        Calib.Homed := TRUE;
        Calib.HomingSuspect := FALSE;
        Calib.LastKnownRawPos := RawPos;
        HomingRefRaw := Calib.HomingRefRaw;
        Homed := TRUE;
        HomingSuspect := FALSE;
        Status.Done := TRUE;
        Status.ErrorId := 16#0000;
        Status.State := E_State.READY;

        // Envoi parallèle de la demande de Preset SDO au matériel s'il est disponible
        PresetValueCalc := (PointsPerRev * MultiTurnRevsMax) / 2;
        PresetValue := PresetValueCalc;
        PresetRequest := TRUE;
    END_IF;
END_IF;

{endregion}

{region "§4 Suivi SDO reset et sorties etat"}
// ⏳ 6. SUIVI DE LA SÉQUENCE SDO OPTIONNELLE
IF Status.State = E_State.BUSY THEN
    IF PresetAck THEN
        Status.Done := TRUE;
        Status.State := E_State.READY;
        // Un homing réussi efface l'intégralité de ErrorId
        Status.ErrorId := 16#0000;
    ELSIF PresetNak THEN
        Status.ErrorId := Status.ErrorId OR 16#0020;        // bit5 : preset refusé/timeout (voir FB_Encoder_Abs)
        Status.State := E_State.READY;
    END_IF;
END_IF;

// 🧾 7. RESET (front) — efface les bits « dernière tentative rejetée » (pas de cause persistante
// à revérifier ici : le prochain Home réévalue toutes les conditions de zéro, voir §5)
IF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FFC0;   // efface bits 0..5 (garde bit9, levé seulement par BtnConfirmCoherence/Home)
END_IF;

// 📤 8. SORTIES ÉTAT
Status.Error := (Status.ErrorId <> 16#0000);
ErrorEdge(CLK := Status.Error);
IF ErrorEdge.Q THEN
    Status.StateAtError := Status.State;
END_IF;

// Mise à jour continue du point brut valide connu (hors séquence de homing elle-même)
IF EncoderAvailable AND (Status.State <> E_State.BUSY) THEN
    Calib.LastKnownRawPos := RawPos;
END_IF;

Status.Busy := (Status.State = E_State.BUSY);
Homed := Calib.Homed AND NOT Calib.HomingSuspect; // Perd l'état homed si suspect (démarrage ou fonctionnement), restauré après BtnConfirmCoherence
HomingSuspect := Calib.HomingSuspect;
HomingRefRaw := Calib.HomingRefRaw;

{endregion}
