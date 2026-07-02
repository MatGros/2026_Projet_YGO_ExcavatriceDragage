(* ═══════════════════════════════════════════════════════════════
   🎯 FB_Encoder_Homing — Référencement codeur, flux NOMINAL uniquement
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie10_Fonction_Encoder_Homing_v1.5.md §1/§5/§7bis
   ⚠️ PÉRIMÈTRE DE CE LOT : flux **nominal** uniquement (capteur haut +
      bouton IHM, référencement à `TopSensorPositionM`, 1 instance par
      treuil, câblées sur le MÊME bouton IHM côté PRG_MAIN). Le flux
      **unitaire** (`WinchSelect`, cible libre `HomingTargetM`,
      `MAINT_N2`) n'est **pas** codé ici — dépend de `E_WinchSelect`/
      `FB_Modes`, pas encore construits.
   🔌 PAS un FB de mouvement (Partie3 §1bis) : il n'écrit qu'une valeur
      de calibration, le treuil étant déjà à l'arrêt confirmé. Pas de
      `StartStop`/`SafeStop`.
   🧮 Calcul (généralise le cas historique cible=0.00, Partie10 §3.2/§3.3) :
      - `PresetValue` = `HomingRefTargetNominal` = (PointsPerRev × MultiTurnRevsMax) / 2
        (constante, TOUJOURS la même — centre exact de la plage, marge anti-débordement)
      - `HomingRefRaw` = `PresetValue` − round(`TopSensorPositionM` × PointsPerRev / CableM_PerRev)
        (ainsi `CablePosM` = `TopSensorPositionM` exactement au moment du homing)
      ⚠️ ÉVOLUTION vs interface §5 d'origine : `HomingRefRaw` est ajouté en sortie explicite
      (le document original supposait implicitement `HomingRefRaw := PresetValue`, valable
      uniquement pour une cible à 0.00 — ne fonctionne plus avec une cible non nulle ≈12.50 m).
   🧊 `ST_EncoderCalib` géré en interne (`VAR RETAIN`) — expose `Homed`/`HomingSuspect`/
      `HomingRefRaw` en sortie pour les consommateurs (`FB_Encoder_Scale`).
   🔴 SIMPLIFICATIONS assumées pour ce lot (à documenter/lever plus tard si besoin) :
      - Les 2 instances (M1/M2) sont autonomes : le même bouton IHM pilote les deux `Home`
        simultanément (câblage PRG_MAIN), mais chacune valide/rejette SES PROPRES conditions
        indépendamment (pas d'attente mutuelle ni de synchro de déclenchement).
      - `ConfirmCoherence`/§3.7 (incohérence redémarrage) : implémenté a minima (bit9), mais
        non testé en conditions réelles de coupure secteur — à revalider.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Encoder_Homing) ===

FUNCTION_BLOCK PUBLIC FB_Encoder_Homing
VAR_INPUT
    Enable               : BOOL;        // Standard
    Reset                : BOOL;        // Acquittement défaut (front) — bits 0/2/3/4/5 (voir §ErrorId)
    EmergencyStopOk      : BOOL;        // Standard
    Mode                 : E_Mode;      // MAINT_N1 requis pour le flux nominal
    Home                 : BOOL;        // Demande de référencement (front, bouton IHM UNIQUE)
    ConfirmCoherence     : BOOL;        // Front — lève le doute §3.7 (bit9), sans réhoming complet
    TopPositionSensor    : BOOL;        // 🔧 2026-07-02 : capteur position haute UNIQUE, COMMUN aux 2 treuils
                                         // (les 2 câbles hissent ensemble le même ensemble mécanique) — câblé
                                         // IDENTIQUEMENT sur les instances M1 ET M2 (PAS un capteur par treuil),
                                         // voir PRG_MAIN.st
    TopSensorPositionM   : REAL := 12.5;  // Cible homing nominal (RETAIN site, voir Partie10 §7bis)
    ContactorFeedbackFwd : BOOL;        // Retour contacteur sens avant CE TREUIL — arrêt confirmé
    ContactorFeedbackRev : BOOL;        // Retour contacteur sens arrière CE TREUIL — arrêt confirmé
    BrakeFeedback        : BOOL;        // Retour contacteur frein CE TREUIL (TRUE = relâché, FALSE = collé)
    RawPos               : UDINT;       // Sortie FB_Encoder_Abs (déjà gelée sur doute)
    EncoderAvailable     : BOOL;        // Sortie FB_Encoder_Abs
    PresetAck            : BOOL;        // Pulse — sortie FB_Encoder_Abs (écriture confirmée)
    PresetNak            : BOOL;        // Pulse — sortie FB_Encoder_Abs (écriture refusée/timeout)
    PointsPerRev         : UDINT := 8192;   // Confirmé fiche technique (Partie10 §3.3)
    MultiTurnRevsMax     : UDINT := 4096;   // Confirmé fiche technique (Partie10 §3.3)
    CableM_PerRev        : REAL := 2.0;     // Confirmé terrain 2026-07-02 (Partie10 §2)
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
VAR RETAIN
    Calib                : ST_EncoderCalib;   // État persistant (Homed/HomingRefRaw/LastKnownRawPos...)
END_VAR
VAR
    ResetEdge            : R_TRIG;
    ErrorEdge            : R_TRIG;
    HomeEdge             : R_TRIG;
    ConfirmCoherenceEdge : R_TRIG;
    InitDone             : BOOL;        // Contrôle cohérence §3.7 fait une fois par session Enable
    ArretConfirme        : BOOL;
    PresetValueCalc      : UDINT;       // = HomingRefTargetNominal (constant tant que PointsPerRev/MultiTurnRevsMax fixes)
    TargetPoints         : DINT;        // Écart signé TopSensorPositionM → points, figé pendant la séquence
    RawDiffRestart       : DINT;        // Écart |RawPos - LastKnownRawPos| au redémarrage (§3.7)
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Encoder_Homing) ===

// 🛑 1. GATE — neutralisation ; on continue toutefois d'exposer le dernier état RETAIN connu
// (FB_Encoder_Scale a besoin de HomingRefRaw même si ce FB est désactivé)
IF NOT Enable OR NOT EmergencyStopOk THEN
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
ConfirmCoherenceEdge(CLK := ConfirmCoherence);

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

// ✅ 4. LEVÉE DU DOUTE (ConfirmCoherence, §3.7) — indépendant du Reset générique
IF ConfirmCoherenceEdge.Q AND (Mode = E_Mode.MAINT_N1 OR Mode = E_Mode.MAINT_N2) THEN
    Calib.HomingSuspect := FALSE;
    ErrorId := ErrorId AND 16#FDFF;   // efface bit9
END_IF;

// 🎯 5. DEMANDE DE RÉFÉRENCEMENT (flux nominal)
// ⚠️ `TopSensorPositionM` n'est PAS revalidée contre le bornage [-99.00;+99.00] m (§3.6) dans ce
// lot : c'est un paramètre RETAIN de mise en service (comme CableM_PerRev/PointsPerRev), pas une
// saisie opérateur par requête — valeur indicative ≈12.50 m largement dans la plage.
ArretConfirme := (NOT ContactorFeedbackFwd) AND (NOT ContactorFeedbackRev) AND (NOT BrakeFeedback);

PresetRequest := FALSE;   // Défaut chaque cycle — repose uniquement sur le front HomeEdge ci-dessous
IF HomeEdge.Q AND (State <> E_State.BUSY) THEN
    IF Mode <> E_Mode.MAINT_N1 THEN
        ErrorId := ErrorId OR 16#0001;        // bit0 : mode non autorisé pour le flux nominal
    ELSIF NOT EncoderAvailable THEN
        ErrorId := ErrorId OR 16#0008;        // bit3 : codeur indisponible
    ELSIF NOT ArretConfirme THEN
        ErrorId := ErrorId OR 16#0004;        // bit2 : arrêt non confirmé (contacteurs/frein)
    ELSIF NOT TopPositionSensor THEN
        ErrorId := ErrorId OR 16#0010;        // bit4 : capteur position haute non confirmé
    ELSE
        // ✅ Toutes conditions réunies : calcul de la cible brute et déclenchement
        PresetValueCalc := (PointsPerRev * MultiTurnRevsMax) / 2;               // Centre exact (§3.3)
        TargetPoints := REAL_TO_DINT(TopSensorPositionM * UDINT_TO_REAL(PointsPerRev) / CableM_PerRev);
        PresetValue := PresetValueCalc;
        PresetRequest := TRUE;                // Pulse 1 cycle — FB_Encoder_Abs détecte le front lui-même
        State := E_State.BUSY;
    END_IF;
END_IF;

// ⏳ 6. SUIVI DE LA SÉQUENCE (BUSY → confirmation)
Done := FALSE;
IF State = E_State.BUSY THEN
    IF PresetAck THEN
        Calib.HomingRefRaw := DINT_TO_UDINT(UDINT_TO_DINT(PresetValueCalc) - TargetPoints);
        Calib.Homed := TRUE;
        Calib.HomingSuspect := FALSE;
        Calib.LastKnownRawPos := PresetValueCalc;
        Done := TRUE;
        State := E_State.READY;
    ELSIF PresetNak THEN
        ErrorId := ErrorId OR 16#0020;        // bit5 : preset refusé/timeout (voir FB_Encoder_Abs)
        State := E_State.READY;
    END_IF;
END_IF;

// 🧾 7. RESET (front) — efface les bits « dernière tentative rejetée » (pas de cause persistante
// à revérifier ici : le prochain Home réévalue toutes les conditions de zéro, voir §5)
IF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFC2;   // efface bits 0,2,3,4,5 (garde bit9, levé seulement par ConfirmCoherence/Home)
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
Homed := Calib.Homed;
HomingSuspect := Calib.HomingSuspect;
HomingRefRaw := Calib.HomingRefRaw;
