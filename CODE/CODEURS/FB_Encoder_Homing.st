(* ═══════════════════════════════════════════════════════════════
   🎯 FB_Encoder_Homing — Référencement codeur nominal ou unitaire MAINT_N2
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.1.md §1/§5/§7bis
                   DOC/AF/AF_Partie-03_Contrats_Composants_v2.1.md
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
    // 🆕 REX audit 2026-08-14 : le homing s'exécutait sans AUCUNE condition (Mode, treuil
    // sélectionné, capteur haut, bornage cible déclarés en interface mais jamais lus). Gate
    // différencié par chemin, validé avec l'utilisateur : le nominal capture AU FRONT du
    // capteur haut (répétable à vitesse d'accostage constante — AscentPermit de FB_Safety_Winch
    // coupe déjà la montée indépendamment, pas d'attente d'arrêt confirmé) ; l'unitaire exige
    // le bon treuil sélectionné ; le dynamique (benne) est déjà gardé Mode+arrêt à l'appel
    // (PRG_02_Acquisition.st, M2BucketRefRequested) — rien à ajouter ici pour ce chemin.
    TopSensorEdge         : R_TRIG;      // Front montant TopPositionSensor — déclenche le nominal
    DynamicTargetEdge     : R_TRIG;      // Front montant UseDynamicTarget — déclenche le homing dynamique
    HomingModeOk          : BOOL;        // Mode MAINT_N1/N2 requis, tous chemins
    NominalHomingTrigger  : BOOL;
    UnitaryHomingTrigger  : BOOL;
    DynamicHomingTrigger  : BOOL;
    HomingTrigger         : BOOL;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Encoder_Homing) ===

{region "§1 Gate neutralisation"}
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

{endregion}

{region "§2 Fronts et coherence demarrage"}
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

{endregion}

{region "§3 Confirmation coherence et demande homing"}
// ✅ 4. LEVÉE DU DOUTE (BtnConfirmCoherence, §3.7) — indépendant du Reset générique
IF ConfirmCoherenceEdge.Q AND (Mode = E_Mode.MAINT_N1 OR Mode = E_Mode.MAINT_N2) THEN
    Calib.HomingSuspect := FALSE;
    ErrorId := ErrorId AND 16#FDFF;   // efface bit9
END_IF;

PresetRequest := FALSE;
TopSensorEdge(CLK := TopPositionSensor);
DynamicTargetEdge(CLK := UseDynamicTarget);

// 🆕 Gates rejetées = Warning auto-effaçable (§9/TC-P03-007), pas un Fault : recalculées à
// chaque scan, jamais latchées, aucun Reset requis pour les effacer.
ErrorId := ErrorId AND 16#FFEC;   // efface bits 0/1/4 (garde bit5, bit9 — inchangés)

HomingModeOk := (Mode = E_Mode.MAINT_N1) OR (Mode = E_Mode.MAINT_N2);

IF HomeEdge.Q AND NOT HomingModeOk THEN
    ErrorId := ErrorId OR 16#0001;   // bit0 : Mode non autorisé (hors MAINT_N1/N2)
END_IF;
IF HomeEdge.Q AND UnitaryMode AND NOT WinchSelected THEN
    ErrorId := ErrorId OR 16#0002;   // bit1 : mauvais treuil sélectionné (flux unitaire)
END_IF;

// Nominal : capture AU FRONT du capteur haut, pas après arrêt confirmé — AscentPermit
// (FB_Safety_Winch) coupe déjà la montée indépendamment dès que TopPositionSensor est actif ;
// attendre l'arrêt casserait la répétabilité recherchée à vitesse d'accostage constante.
// Couvre les deux cas : Home déjà maintenu quand le capteur déclenche, ou capteur déjà actif
// quand Home est pressé.
NominalHomingTrigger := HomingModeOk AND NOT UseDynamicTarget AND NOT UnitaryMode
                         AND ((Home AND TopSensorEdge.Q) OR (HomeEdge.Q AND TopPositionSensor));

// Unitaire (MAINT_N2 déjà garanti par UnitaryMode en amont, PRG_02_Acquisition) : bon treuil.
UnitaryHomingTrigger := HomingModeOk AND UnitaryMode AND WinchSelected AND HomeEdge.Q;

// Dynamique (benne) : Mode + arrêt confirmé (M1/M2 non Busy) déjà gardés à l'appel via
// M2BucketRefRequested (PRG_02_Acquisition.st) — HomingModeOk reste vérifié ici en défense.
DynamicHomingTrigger := HomingModeOk AND (DynamicTargetEdge.Q OR (UseDynamicTarget AND HomeEdge.Q));

HomingTrigger := NominalHomingTrigger OR UnitaryHomingTrigger OR DynamicHomingTrigger;

IF HomingTrigger THEN
    IF UseDynamicTarget THEN
        TargetPositionM := DynamicHomingTargetM;
    ELSIF UnitaryMode THEN
        TargetPositionM := CfgHomingTargetM;
    ELSE
        TargetPositionM := CfgTopSensorPosM;
    END_IF;

    // 🆕 Bornage obligatoire avant écriture (CODE_QUALITY_STANDARDS §6) — toute cible, quelle
    // que soit son origine (config, calcul benne, capteur haut), est vérifiée dans la plage
    // physique documentée [-99;+99] m avant d'être gravée dans la référence codeur.
    IF (TargetPositionM < -99.0) OR (TargetPositionM > 99.0) THEN
        ErrorId := ErrorId OR 16#0010;   // bit4 : cible hors plage, homing refusé
    ELSE
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
END_IF;

{endregion}

{region "§4 Suivi SDO reset et sorties etat"}
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

{endregion}
