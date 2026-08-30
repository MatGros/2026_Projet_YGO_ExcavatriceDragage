(* =======================================================================
   ⚙️ FB_Encoder_SpeedMeasure — Mesure de vitesse câble horodatée
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Calcul de la vitesse absolue et signée sur fenêtre glissante horodatée
   🔒 Polarité : Valid=TRUE après 6 échantillons couvrant au moins 50ms
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Encoder_SpeedMeasure
VAR_INPUT
    // === COMMANDES & AUTORISATIONS ===
    Enable              : BOOL;        // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset               : BOOL;        // --> [CMD] Purge immediate de l'historique (front montant)

    // === MESURE SURES EN ENTREE ===
    Position_M          : REAL;        // --> [HW]  Position cable sure en metres (FB_Encoder_Safety)
    PositionValid       : BOOL;        // --> [SAFE] Validite de la chaine codeur
END_VAR
VAR_OUTPUT
    // === VITESSE CALCULÉE & VALIDITE ===
    Speed_Mps           : REAL;        // <-- [DIAG] Vitesse absolue sur la fenetre glissante (m/s)
    SignedSpeed_Mps     : REAL;        // <-- [DIAG] Vitesse signee (+ montee, - descente) (m/s)
    Valid               : BOOL;        // <-- [STAT] Vitesse valide (6 ech. sur 50 ms)
END_VAR
VAR
    // === HISTORIQUE & ECHANTILLONS ===
    Positions_M         : ARRAY[0..5] OF REAL; // . [LOC] Tableau des 6 positions enregistrees
    Timestamps          : ARRAY[0..5] OF TIME; // . [LOC] Horodatage associe aux 6 positions

    // === HORODATAGE & TEMPORISATION ===
    CurrentTimestamp    : TIME;        // . [LOC] Horodatage courant du cycle
    LastTimestamp       : TIME;        // . [LOC] Horodatage de l'echantillon precedent
    ElapsedSinceSample  : TIME;        // . [LOC] Temps ecoule depuis le dernier echantillon
    WindowElapsed       : TIME;        // . [LOC] Temps total ecoule sur la fenetre de mesure

    // === COMPTEURS & ETATS INTERNES ===
    CollectedSamples    : INT;         // . [LOC] Nombre d'echantillons collectes dans la fenetre
    Index               : INT;         // . [LOC] Index de boucle de decalage
    TimestampInitialized: BOOL;        // . [LOC] Indicateur d'initialisation du premier horodatage
END_VAR
VAR CONSTANT
    // === PARAMETRES DE LA FENETRE GLISSANTE ===
    WindowTime          : TIME := T#50MS; // Fenetre glissante de mesure
    SamplePeriod        : TIME := T#10MS; // Periode minimale entre deux echantillons
    SampleCount         : INT := 6;       // Nombre total d'echantillons requis
END_VAR

{region "§1 Horodatage et purge"}
// ⏱️ Horodatage natif : le calcul utilise le temps réellement écoulé, jamais un cycle supposé.
CurrentTimestamp := TIME();

// Purge des six positions sur rupture de confiance : aucune source antérieure ne peut contaminer la mesure.
IF NOT Enable OR Reset OR NOT PositionValid THEN
    Speed_Mps := 0.0;
    SignedSpeed_Mps := 0.0;
    Valid := FALSE;
    CollectedSamples := 0;
    TimestampInitialized := FALSE;
    RETURN;
END_IF;
{endregion}

{region "§2 Première position"}
// 🕒 Première position de la nouvelle fenêtre.
IF NOT TimestampInitialized THEN
    Positions_M[0] := Position_M;
    Timestamps[0] := CurrentTimestamp;
    LastTimestamp := CurrentTimestamp;
    CollectedSamples := 1;
    TimestampInitialized := TRUE;
    Speed_Mps := 0.0;
    SignedSpeed_Mps := 0.0;
    Valid := FALSE;
    RETURN;
END_IF;
{endregion}

{region "§3 Rebouclage TIME"}
// 🛡️ Rebouclage de TIME détecté localement : purge sans réutiliser le delta aberrant.
IF CurrentTimestamp < LastTimestamp THEN
    Positions_M[0] := Position_M;
    Timestamps[0] := CurrentTimestamp;
    LastTimestamp := CurrentTimestamp;
    CollectedSamples := 1;
    Speed_Mps := 0.0;
    SignedSpeed_Mps := 0.0;
    Valid := FALSE;
    RETURN;
END_IF;

ElapsedSinceSample := CurrentTimestamp - LastTimestamp;

// 🛡️ Delta nul : aucune division et aucun doublon d'échantillon.
IF ElapsedSinceSample <= T#0MS THEN
    RETURN;
END_IF;
{endregion}

{region "§4 Collecte échantillons"}
// 📥 Six positions espacées d'au moins 10 ms donnent cinq intervalles sur la fenêtre interne de 50 ms.
IF ElapsedSinceSample >= SamplePeriod THEN
    LastTimestamp := CurrentTimestamp;

    IF CollectedSamples < SampleCount THEN
        Positions_M[CollectedSamples] := Position_M;
        Timestamps[CollectedSamples] := CurrentTimestamp;
        CollectedSamples := CollectedSamples + 1;
    ELSE
        FOR Index := 0 TO 4 DO
            Positions_M[Index] := Positions_M[Index + 1];
            Timestamps[Index] := Timestamps[Index + 1];
        END_FOR;
        Positions_M[5] := Position_M;
        Timestamps[5] := CurrentTimestamp;
    END_IF;
{endregion}

{region "§5 Calcul vitesse"}
    IF CollectedSamples = SampleCount THEN
        // 🛡️ Ordre temporel et durée minimale contrôlés avant toute conversion/division.
        IF Timestamps[5] >= Timestamps[0] THEN
            WindowElapsed := Timestamps[5] - Timestamps[0];
            IF WindowElapsed >= WindowTime THEN
                SignedSpeed_Mps := (Positions_M[5] - Positions_M[0])
                                   / (UDINT_TO_REAL(TIME_TO_UDINT(WindowElapsed)) / 1000.0);
                Speed_Mps := ABS(SignedSpeed_Mps);
                Valid := TRUE;
            ELSE
                Speed_Mps := 0.0;
                SignedSpeed_Mps := 0.0;
                Valid := FALSE;
            END_IF;
        ELSE
            Speed_Mps := 0.0;
            SignedSpeed_Mps := 0.0;
            Valid := FALSE;
            CollectedSamples := 0;
            TimestampInitialized := FALSE;
        END_IF;
    END_IF;
END_IF;
{endregion}
