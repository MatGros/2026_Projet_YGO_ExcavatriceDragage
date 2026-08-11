(* ═══════════════════════════════════════════════════════════════
   🎯 FB_Encoder_Homing — Référencement codeur nominal ou unitaire MAINT_N2
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-09_Fonction_Encoder_v2.1.md §1/§5/§7bis
                   DOC/AF_Partie-03_Contrats_Composants_v2.1.md
   🎯 Rôle : Gestion du flux de homing nominal (capteur haut + cible paramétrable)
      ou unitaire (MAINT_N2, treuil sélectionné).
   🧮 Calcul du point de calage :
      - PresetValue = centre de la plage multi-tour (marge anti-débordement)
      - HomingRefRaw = PresetValue - round(CfgTopSensorPosM × PointsPerRev / CableM_PerRev)
   🧊 Expose ST_Encoder_Calib en VAR_IN_OUT (RETAIN).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Encoder_Homing) ===

FUNCTION_BLOCK PUBLIC FB_Encoder_Homing
VAR_INPUT
    Enable               : BOOL;        // Standard
    Reset                : BOOL;        // Acquittement défaut (front) — bits 0/2/3/4/5 (voir §ErrorId)
    PowerContactorEngaged      : BOOL;        // Standard
    Mode                 : E_Mode;      // MAINT_N1 requis pour le flux nominal
    Home                 : BOOL;        // Demande de référencement (front, bouton IHM UNIQUE)
    UnitaryMode          : BOOL;        // TRUE = flux unitaire à cible libre (MAINT_N2 uniquement)
    WinchSelected        : BOOL;        // TRUE = cette instance est le treuil sélectionné
    CfgHomingTargetM        : REAL;        // Cible libre unitaire, limitée à [-99.0 ; +99.0] m
    // 🆕 2026-08-07 (19) — retour terrain, demande client : BtnConfirmOpenPos/ClosePos (benne)
    // doivent aussi référencer le codeur M2 (comme BtnHome), pas seulement mémoriser un état
    // logique -- cible DYNAMIQUE (position réelle de M1, calculée côté appelant), pas une valeur
    // de config fixe comme CfgHomingTargetM. Si TRUE au front Home, DynamicHomingTargetM prime
    // sur UnitaryMode/CfgTopSensorPosM.
    UseDynamicTarget        : BOOL := FALSE;
    DynamicHomingTargetM    : REAL := 0.0;
    BtnConfirmCoherence     : BOOL;        // Front — lève le doute §3.7 (bit9), sans réhoming complet
    TopPositionSensor    : BOOL;        // 🔧 2026-07-02 : capteur position haute UNIQUE, COMMUN aux 2 treuils
                                         // (les 2 câbles hissent ensemble le même ensemble mécanique) — câblé
                                         // IDENTIQUEMENT sur les instances M1 ET M2 (PAS un capteur par treuil),
                                         // voir PRG_MAIN.st
    CfgTopSensorPosM   : REAL := 8.5;   // Cible homing nominal (RETAIN site, voir Partie10 §7bis)
    FwdRevSpeedFeedbackOff : BOOL;      // Retour unique "tous contacteurs sens+vitesse retombés" CE TREUIL — arrêt confirmé
    BrakeFeedback        : BOOL;        // Retour contacteur frein CE TREUIL (TRUE = ouvert/desserré — révocation 2026-08-03)
    RawPos               : UDINT;       // Sortie FB_Encoder_Abs (déjà gelée sur doute)
    EncoderAvailable     : BOOL;        // Sortie FB_Encoder_Abs
    PresetAck            : BOOL;        // Pulse — sortie FB_Encoder_Abs (écriture confirmée)
    PresetNak            : BOOL;        // Pulse — sortie FB_Encoder_Abs (écriture refusée/timeout)
    PointsPerRev         : UDINT := 8192;   // Confirmé fiche technique (Partie10 §3.3)
    MultiTurnRevsMax     : UDINT := 4096;   // Confirmé fiche technique (Partie10 §3.3)
    CableM_PerRev        : REAL := 2.0;     // Confirmé terrain 2026-07-02 (Partie10 §2)
    BypassGlobal         : BOOL := FALSE;   // 🌐 Ignore arrêt confirmé et capteur haut (mise en service)
END_VAR
VAR_OUTPUT
    Ready                : BOOL;
    Busy                 : BOOL;
    Done                 : BOOL;        // Pulse 1 cycle — référencement réussi (miroir PresetAck)
    Error                : BOOL;
    ErrorId              : WORD;        // Voir table de bits en en-tête de fichier / doc §5
    State                : E_State;
    StateAtError         : E_State;
    PresetRequest        : BOOL;        // Pulse → FB_Encoder_Abs.PresetRequest
    PresetValue          : UDINT;       // → FB_Encoder_Abs.PresetValue (= HomingRefTargetNominal)
    Homed                : BOOL;        // RETAIN interne, miroir Calib.Homed
    HomingSuspect        : BOOL;        // RETAIN interne, miroir Calib.HomingSuspect
    HomingRefRaw         : UDINT;       // RETAIN interne, miroir Calib.HomingRefRaw → FB_Encoder_Scale
END_VAR
VAR_IN_OUT
    Calib                : ST_Encoder_Calib;   // Référence vers l'état persistant global (survit aux téléchargements)
END_VAR
VAR
    ResetEdge            : R_TRIG;
    ErrorEdge            : R_TRIG;
    HomeEdge             : R_TRIG;
    ConfirmCoherenceEdge : R_TRIG;
    InitDone             : BOOL;        // Contrôle cohérence §3.7 fait une fois par session Enable
    ArretConfirme        : BOOL;
    PresetValueCalc      : UDINT;       // = HomingRefTargetNominal (constant tant que PointsPerRev/MultiTurnRevsMax fixes)
    TargetPoints         : DINT;        // Écart signé CfgTopSensorPosM → points, figé pendant la séquence
    TargetPositionM      : REAL;        // Cible retenue : nominale ou unitaire
    RawDiffRestart       : DINT;        // Écart |RawPos - LastKnownRawPos| au redémarrage (§3.7)
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Encoder_Homing) ===

// 🛑 1. GATE — neutralisation ; on continue toutefois d'exposer le dernier état RETAIN connu
// (FB_Encoder_Scale a besoin de HomingRefRaw même si ce FB est désactivé)
// 🆕 2026-08-06 : PowerContactorEngaged retiré du GATE (le codeur 24V / EtherCAT peut être homé disjoncteurs coupés)
IF NOT Enable THEN
    PresetRequest := FALSE;
    PresetValue := 0;
    State := E_State.DISABLED;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    InitDone := FALSE;   // Force un nouveau contrôle §3.7 à la prochaine activation
    Homed := Calib.Homed;
    HomingSuspect := Calib.HomingSuspect;
    HomingRefRaw := Calib.HomingRefRaw;
    RETURN;
END_IF;

Ready := TRUE;

// 🔑 2. FRONTS
ResetEdge(CLK := Reset);
HomeEdge(CLK := Home);
ConfirmCoherenceEdge(CLK := BtnConfirmCoherence);

// 🔍 3. COHÉRENCE AU REDÉMARRAGE (§3.7) — une fois par session Enable, dès que le codeur répond
IF NOT InitDone THEN
    State := E_State.INIT;
    IF EncoderAvailable THEN
        RawDiffRestart := UDINT_TO_DINT(RawPos) - UDINT_TO_DINT(Calib.LastKnownRawPos);
        IF Calib.Homed AND (ABS(RawDiffRestart) > UDINT_TO_DINT(Calib.RestartCoherenceTolerancePts)) THEN
            Calib.HomingSuspect := TRUE;
            ErrorId := ErrorId OR 16#0200;   // bit9 : incohérence codeur au redémarrage
        END_IF;
        InitDone := TRUE;
    END_IF;
ELSE
    IF State = E_State.INIT THEN State := E_State.READY; END_IF;
END_IF;

// ✅ 4. LEVÉE DU DOUTE (BtnConfirmCoherence, §3.7) — indépendant du Reset générique
IF ConfirmCoherenceEdge.Q AND (Mode = E_Mode.MAINT_N1 OR Mode = E_Mode.MAINT_N2) THEN
    Calib.HomingSuspect := FALSE;
    ErrorId := ErrorId AND 16#FDFF;   // efface bit9
END_IF;

PresetRequest := FALSE;
IF HomeEdge.Q THEN
    IF UseDynamicTarget THEN
        TargetPositionM := DynamicHomingTargetM;
    ELSIF UnitaryMode THEN
        TargetPositionM := CfgHomingTargetM;
    ELSE
        TargetPositionM := CfgTopSensorPosM;
    END_IF;

    // 🎯 Homing logiciel immédiat sans condition : mise à jour instantanée de HomingRefRaw
    // (garantit que CablePosM passe à 0.0m ou TopSensorPosM immédiatement à l'écran IHM)
    TargetPoints := REAL_TO_DINT(TargetPositionM * UDINT_TO_REAL(PointsPerRev) / CableM_PerRev);
    Calib.HomingRefRaw := DINT_TO_UDINT(UDINT_TO_DINT(RawPos) - TargetPoints);
    Calib.Homed := TRUE;
    Calib.HomingSuspect := FALSE;
    Calib.LastKnownRawPos := RawPos;
    HomingRefRaw := Calib.HomingRefRaw;
    Homed := TRUE;
    HomingSuspect := FALSE;
    Done := TRUE;
    ErrorId := 16#0000;
    State := E_State.READY;

    // Envoi parallèle de la demande de Preset SDO au matériel s'il est disponible
    PresetValueCalc := (PointsPerRev * MultiTurnRevsMax) / 2;
    PresetValue := PresetValueCalc;
    PresetRequest := TRUE;
END_IF;

// ⏳ 6. SUIVI DE LA SÉQUENCE SDO OPTIONNELLE
IF State = E_State.BUSY THEN
    IF PresetAck THEN
        Done := TRUE;
        State := E_State.READY;
        // Un homing réussi efface l'intégralité de ErrorId
        ErrorId := 16#0000;
    ELSIF PresetNak THEN
        ErrorId := ErrorId OR 16#0020;        // bit5 : preset refusé/timeout (voir FB_Encoder_Abs)
        State := E_State.READY;
    END_IF;
END_IF;

// 🧾 7. RESET (front) — efface les bits « dernière tentative rejetée » (pas de cause persistante
// à revérifier ici : le prochain Home réévalue toutes les conditions de zéro, voir §5)
IF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFC0;   // efface bits 0..5 (garde bit9, levé seulement par BtnConfirmCoherence/Home)
END_IF;

// 📤 8. SORTIES ÉTAT
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

// Mise à jour continue du point brut valide connu (hors séquence de homing elle-même)
IF EncoderAvailable AND (State <> E_State.BUSY) THEN
    Calib.LastKnownRawPos := RawPos;
END_IF;

Busy := (State = E_State.BUSY);
Homed := Calib.Homed AND NOT Calib.HomingSuspect; // 🆕 REX 2026-07-08 : Perd l'état homed si suspect (démarrage ou fonctionnement), restauré après BtnConfirmCoherence
HomingSuspect := Calib.HomingSuspect;
HomingRefRaw := Calib.HomingRefRaw;
