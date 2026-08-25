(* =======================================================================
   📊 FB_Encoder_SpeedMonitor — Détection variation brusque vitesse câble
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Surveillance et détection de variation brusque de vitesse câble
   🔒 Polarité : SpeedVariationConfirmed=TRUE si variation > seuil pendant timeout
   📊 Diagnostic : Brique de surveillance diagnostic sans actionneur direct
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.1.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Encoder_SpeedMonitor
VAR_INPUT
    // === COMMANDES & AUTORISATIONS ===
    Enable                     : BOOL;        // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset                      : BOOL;        // --> [CMD] Acquittement defaut (front montant)

    // === CONTEXTE & ETAT PUISSANCE ===
    PowerContactorEngaged      : BOOL;        // --> [HW]  Ligne puissance enclenchee
    Mode                       : E_Mode;      // --> [CMD] Mode d'exploitation actif

    // === MESURES & CONSIGNES SURVEILLANCE ===
    SpeedMps                   : REAL;        // --> [HW]  Vitesse lineaire absolue mesuree (m/s)
    SpeedVariationThresholdMps : REAL;        // --> [CFG] Seuil de variation minimale a surveiller (m/s)
    SpeedVariationTimeout      : TIME;        // --> [CFG] Duree minimale de confirmation variation
    SpeedStabilityTimeout      : TIME;        // --> [CFG] Duree sans variation avant vitesse stable
END_VAR
VAR_OUTPUT
    // === ETATS IEC & SYNOPTIQUE ===
    Ready                  : BOOL;        // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible) — regroupe Busy/Done/Error/ErrorId/State/StateAtError.
    // ErrorId bit0: "variation vitesse confirmée".
    Status                 : ST_FbStatus;

    // === RESULTATS & MESURES DIAGNOSTIC ===
    SpeedDeltaMps          : REAL;        // <-- [DIAG] Ecart absolu entre deux mesures (m/s)
    SpeedVariationDetected : BOOL;        // <-- [DIAG] Seuil depasse sur le cycle courant
    SpeedVariationConfirmed: BOOL;        // <-- [DIAG] Seuil depasse pendant la duree requise
    SpeedStable            : BOOL;        // <-- [STAT] Vitesse stable pendant SpeedStabilityTimeout
END_VAR
VAR
    // === DETECTEURS DE FRONT ===
    ResetEdge              : R_TRIG;      // . [LOC] Detecteur front montant Reset
    ErrorEdge              : R_TRIG;      // . [LOC] Detecteur front montant Error

    // === TEMPORISATEURS INTERNES ===
    VariationTimer         : TON;         // . [LOC] Temporisateur de confirmation de variation
    StabilityTimer         : TON;         // . [LOC] Temporisateur de confirmation de stabilite

    // === VARIABLES ET MEMOIRES INTERNES ===
    PreviousSpeedMps       : REAL;        // . [LOC] Vitesse mesuree au cycle precedent (m/s)
    HasPreviousSpeed       : BOOL;        // . [LOC] Premiere mesure enregistree
    VariationActive        : BOOL;        // . [LOC] Condition de depassement de seuil active
END_VAR

{region "§1 Gate"}
// 🛑 1. GATE — désactivation ou AU non réarmé : aucune alarme persistante.
IF NOT Enable OR NOT PowerContactorEngaged THEN
    Ready := FALSE;
    Status.Busy := FALSE;
    Status.Done := FALSE;
    Status.Error := FALSE;
    Status.ErrorId := 16#0000;
    Status.State := E_State.DISABLED;
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
Status.Busy := FALSE;
Status.Done := FALSE;
Status.State := E_State.READY;
{endregion}

{region "§2 Reset front"}
// 🔑 2. RESET FRONT — l'acquittement n'efface le défaut que si la cause a disparu.
ResetEdge(CLK := Reset);
{endregion}

{region "§3 Calcul écart vitesse"}
// 📏 3. CALCUL DE L'ÉCART DE VITESSE — première mesure utilisée comme référence.
IF NOT HasPreviousSpeed THEN
    PreviousSpeedMps := SpeedMps;
    HasPreviousSpeed := TRUE;
    SpeedDeltaMps := 0.0;
ELSE
    SpeedDeltaMps := ABS(SpeedMps - PreviousSpeedMps);
    PreviousSpeedMps := SpeedMps;
END_IF;
{endregion}

{region "§4 Détection et filtre temporel"}
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
    Status.ErrorId := Status.ErrorId OR 16#0001;
ELSIF ResetEdge.Q AND NOT VariationActive THEN
    Status.ErrorId := Status.ErrorId AND 16#FFFE;
END_IF;
{endregion}

{region "§5 Sorties état"}
// 📤 5. SORTIES D'ÉTAT — diagnostic standard, aucune commande mouvement.
Status.Error := (Status.ErrorId <> 16#0000);
ErrorEdge(CLK := Status.Error);
IF ErrorEdge.Q THEN
    Status.StateAtError := Status.State;
END_IF;
{endregion}
