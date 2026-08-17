(* ═══════════════════════════════════════════════════════════════
   📐 FB_Encoder_SpeedMeasure — Mesure de vitesse câble horodatée
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.1.md §3.8
   🛡️ Sécurité : mesure propriétaire de la chaîne codeur ; aucune réaction machine
   🧩 Dépendances : position sûre fournie par FB_Encoder_Safety
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK PUBLIC FB_Encoder_SpeedMeasure
VAR_INPUT
    Enable        : BOOL; // Autorise l'acquisition
    Reset         : BOOL; // Purge immédiate de l'historique
    Position_M    : REAL; // Position câble sûre en mètres
    PositionValid : BOOL; // TRUE si la chaîne codeur garantit la position
END_VAR
VAR_OUTPUT
    Speed_Mps       : REAL; // Vitesse absolue sur la fenêtre horodatée
    SignedSpeed_Mps : REAL; // Vitesse signée : positive montée, négative descente
    Valid           : BOOL; // TRUE après 6 positions couvrant au moins 50 ms
END_VAR
VAR CONSTANT
    WindowTime   : TIME := T#50MS;
    SamplePeriod : TIME := T#10MS;
    SampleCount  : INT := 6;
END_VAR
VAR
    Positions_M : ARRAY[0..5] OF REAL;
    Timestamps  : ARRAY[0..5] OF TIME;
    CurrentTimestamp : TIME;
    LastTimestamp    : TIME;
    ElapsedSinceSample : TIME;
    WindowElapsed      : TIME;
    CollectedSamples   : INT;
    Index              : INT;
    TimestampInitialized : BOOL;
END_VAR

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

// 🛡️ Rebouclage de TIME détecté localement : purge sans réutiliser le delta aberrant (indépendant de T88).
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
