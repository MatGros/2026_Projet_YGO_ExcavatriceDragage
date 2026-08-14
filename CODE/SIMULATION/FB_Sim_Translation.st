(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_Translation — Progression capteurs simulés M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Produit les cinq capteurs de position M3 par progression continue
      de Trémie vers Maintenance. Le modèle ne publie que les six mots valides
      de FB_Translation_PositionDecoder : 11111 → 01111 → 00111 → 00011 →
      00001 → 00000.
   🔒 Le modèle est une source d'entrée confinée derrière HwIn ; il ne pilote
      aucune sortie réelle. Un override manuel valide est appliqué par
      FB_SimBench, pas par ce FB.
   📄 Docs : DOC/AF/AF_Partie-13_Fonction_Simulation_v2.2.md
             DOC/AF/AF_Partie-11_Fonction_Translation_v2.2.md
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Sim_Translation
VAR_INPUT
    Enable          : BOOL;              // TRUE = modèle actif
    Direction       : INT;               // +1 = vers Trémie ; -1 = vers Maintenance ; 0 = maintien position
    SpeedRefPct     : REAL;              // Magnitude commande 0..100 %, bornée avant calcul
    FullTravelTimeS : REAL := 8.0;       // Temps complet Trémie→Maintenance à 100 %, simulation seulement
END_VAR
VAR_OUTPUT
    PosTremie      : BOOL;               // Bit4 du mot capteurs
    PosPV          : BOOL;               // Bit3 du mot capteurs
    PosP2          : BOOL;               // Bit2 du mot capteurs (point matériel PVP2)
    PosP1          : BOOL;               // Bit1 du mot capteurs
    PosMaintenance : BOOL;               // Bit0 du mot capteurs
END_VAR
VAR
    instCycleTime              : FB_CycleTime;
    PositionProgress           : REAL;   // 0=Trémie ... 5=Maintenance
    SpeedPctBounded            : REAL;
    PositionIncrement          : REAL;
    Initialized                : BOOL := FALSE;
END_VAR
VAR CONSTANT
    CST_PositionAtTremie       : REAL := 0.0;
    CST_PositionAtPV           : REAL := 1.0;
    CST_PositionAtP2           : REAL := 2.0;
    CST_PositionAtP1           : REAL := 3.0;
    CST_PositionAtMaintenance  : REAL := 5.0;
    CST_PositionSegmentCount   : REAL := 5.0;
    CST_MinFullTravelTimeS     : REAL := 0.1; // Protection division : modèle sans dynamique sous ce seuil
END_VAR

// === IMPLEMENTATION ===

IF NOT Enable THEN
    // Prochain démarrage déterministe sur P2, comme l'ancien modèle de banc.
    PositionProgress := CST_PositionAtP2;
    Initialized := FALSE;
    PosTremie := FALSE;
    PosPV := FALSE;
    PosP2 := FALSE;
    PosP1 := FALSE;
    PosMaintenance := FALSE;
    RETURN;
END_IF;

IF NOT Initialized THEN
    PositionProgress := CST_PositionAtP2;
    Initialized := TRUE;
END_IF;

instCycleTime(DefaultValueS := 0.010);
SpeedPctBounded := LIMIT(0.0, ABS(SpeedRefPct), 100.0);

// Une vitesse à 100 % parcourt les cinq segments uniformes pendant FullTravelTimeS.
// Direction sémantique : +1 réduit la progression vers Trémie ; -1 l'augmente vers Maintenance.
IF FullTravelTimeS >= CST_MinFullTravelTimeS THEN
    PositionIncrement := (SpeedPctBounded / 100.0)
                         * (CST_PositionSegmentCount / FullTravelTimeS)
                         * instCycleTime.CycleTimeS;
ELSE
    PositionIncrement := 0.0;
END_IF;

IF Direction = 1 THEN
    PositionProgress := MAX(CST_PositionAtTremie, PositionProgress - PositionIncrement);
ELSIF Direction = -1 THEN
    PositionProgress := MIN(CST_PositionAtMaintenance, PositionProgress + PositionIncrement);
END_IF;

// Réinitialisation explicite : aucune valeur transitoire héritée d'une zone précédente.
PosTremie := FALSE;
PosPV := FALSE;
PosP2 := FALSE;
PosP1 := FALSE;
PosMaintenance := FALSE;

// Chaque intervalle correspond à un seul mot thermomètre valide.
IF PositionProgress <= CST_PositionAtTremie THEN
    PosTremie := TRUE;
    PosPV := TRUE;
    PosP2 := TRUE;
    PosP1 := TRUE;
    PosMaintenance := TRUE;
ELSIF PositionProgress <= CST_PositionAtPV THEN
    PosPV := TRUE;
    PosP2 := TRUE;
    PosP1 := TRUE;
    PosMaintenance := TRUE;
ELSIF PositionProgress <= CST_PositionAtP2 THEN
    PosP2 := TRUE;
    PosP1 := TRUE;
    PosMaintenance := TRUE;
ELSIF PositionProgress <= CST_PositionAtP1 THEN
    PosP1 := TRUE;
    PosMaintenance := TRUE;
ELSIF PositionProgress < CST_PositionAtMaintenance THEN
    PosMaintenance := TRUE;
END_IF;
