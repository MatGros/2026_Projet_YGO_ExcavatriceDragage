(* ═══════════════════════════════════════════════════════════════════════════════
   🔍 FB_Encoder_SpeedMonitor — Détection de variation brusque de vitesse câble
   ═══════════════════════════════════════════════════════════════════════════════
   📄 Brique standard de diagnostic — aucun pilotage moteur, aucun SafeStop.
   🎯 Compare deux mesures successives de vitesse linéaire câble en m/s.
   🧩 Le seuil et la durée de confirmation sont fournis par l'appelant :
      aucun réglage métier n'est figé dans cette brique.
   🛡️ Une variation confirmée pose ErrorId bit0. Le défaut reste mémorisé
      jusqu'à disparition de la cause et acquittement par front Reset.
   ═══════════════════════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Encoder_SpeedMonitor
VAR_INPUT
    Enable                     : BOOL;        // Autorise la surveillance
    Reset                      : BOOL;        // Acquittement par front
    EmergencyStopOk            : BOOL;        // Contexte sécurité global valide
    Mode                       : E_Mode;      // Contexte de fonctionnement
    SpeedMps                   : REAL;        // Vitesse linéaire absolue mesurée (m/s)
    SpeedVariationThresholdMps : REAL;        // Variation minimale à surveiller (m/s)
    SpeedVariationTimeout      : TIME;        // Durée minimale de confirmation
    SpeedStabilityTimeout      : TIME;        // Durée sans variation avant vitesse stable
END_VAR
VAR_OUTPUT
    Ready                  : BOOL;
    Busy                   : BOOL;
    Done                   : BOOL;
    Error                  : BOOL;
    ErrorId                : WORD;        // bit0 : variation vitesse confirmée
    State                  : E_State;
    StateAtError           : E_State;
    SpeedDeltaMps          : REAL;        // Écart absolu entre deux mesures (m/s)
    SpeedVariationDetected : BOOL;        // Seuil dépassé sur le cycle courant
    SpeedVariationConfirmed: BOOL;        // Seuil dépassé pendant la durée requise
    SpeedStable            : BOOL;        // Vitesse stable pendant SpeedStabilityTimeout
END_VAR
VAR
    ResetEdge          : R_TRIG;
    ErrorEdge          : R_TRIG;
    VariationTimer     : TON;
    StabilityTimer     : TON;
    PreviousSpeedMps   : REAL;
    HasPreviousSpeed   : BOOL;
    VariationActive    : BOOL;
END_VAR

// 🛑 1. GATE — désactivation ou AU non réarmé : aucune alarme persistante.
IF NOT Enable OR NOT EmergencyStopOk THEN
    Ready := FALSE;
    Busy := FALSE;
    Done := FALSE;
    Error := FALSE;
    ErrorId := 16#0000;
    State := E_State.DISABLED;
    SpeedDeltaMps := 0.0;
    SpeedVariationDetected := FALSE;
    SpeedVariationConfirmed := FALSE;
    SpeedStable := FALSE;
    VariationActive := FALSE;
    HasPreviousSpeed := FALSE;
    VariationTimer(IN := FALSE, PT := SpeedVariationTimeout);
    StabilityTimer(IN := FALSE, PT := SpeedStabilityTimeout);
    RETURN;
END_IF;

Ready := TRUE;
Busy := FALSE;
Done := FALSE;
State := E_State.READY;

// 🔑 2. RESET FRONT — l'acquittement n'efface le défaut que si la cause a disparu.
ResetEdge(CLK := Reset);

// 📏 3. CALCUL DE L'ÉCART DE VITESSE — première mesure utilisée comme référence.
IF NOT HasPreviousSpeed THEN
    PreviousSpeedMps := SpeedMps;
    HasPreviousSpeed := TRUE;
    SpeedDeltaMps := 0.0;
ELSE
    SpeedDeltaMps := ABS(SpeedMps - PreviousSpeedMps);
    PreviousSpeedMps := SpeedMps;
END_IF;

// 🔍 4. DÉTECTION BRUTE + FILTRE TEMPOREL — pas de déclenchement si la durée vaut zéro.
VariationActive := HasPreviousSpeed
                   AND (SpeedVariationThresholdMps >= 0.0)
                   AND (SpeedVariationTimeout > T#0ms)
                   AND (SpeedDeltaMps > SpeedVariationThresholdMps);
SpeedVariationDetected := VariationActive;

VariationTimer(IN := VariationActive, PT := SpeedVariationTimeout);
SpeedVariationConfirmed := VariationTimer.Q;
StabilityTimer(IN := HasPreviousSpeed AND NOT VariationActive AND (SpeedStabilityTimeout > T#0ms), PT := SpeedStabilityTimeout);
SpeedStable := StabilityTimer.Q;

IF SpeedVariationConfirmed THEN
    ErrorId := ErrorId OR 16#0001;
ELSIF ResetEdge.Q AND NOT VariationActive THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 📤 5. SORTIES D'ÉTAT — diagnostic standard, aucune commande mouvement.
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;
