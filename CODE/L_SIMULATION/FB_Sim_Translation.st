(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_Translation — Progression capteurs simulés M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Produit les cinq capteurs de position M3 par progression continue
      de Trémie vers Maintenance. Le modèle ne publie que les six mots valides
      de FB_Translation_PositionDecoder : 11111 → 01111 → 00111 → 00011 →
      00001 → 00000.
   📏 Convention : PositionProgress en mètres, 0 m = Trémie … 30 m = Maintenance.
      Distances NON-linéaires : Trémie(0)→PV(5)=5 m, PV(5)→P2(15)=10 m,
      P2(15)→P1(20)=5 m, P1(20)→Maintenance(30)=10 m.
   🔒 Le modèle est une source d'entrée confinée derrière HwIn ; il ne pilote
      aucune sortie réelle. Un override manuel valide est appliqué par
      FB_SimBench, pas par ce FB.
   📄 Docs : DOC/AF/AF_Partie-13_Fonction_Simulation_v2.3.md
             DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Sim_Translation
VAR_INPUT
    Enable          : BOOL;              (* --> [CMD] TRUE = modèle actif *)
    Direction       : INT;               (* --> [CMD] +1 = vers Trémie ; -1 = vers Maintenance ; 0 = maintien position *)
    SpeedTgt_Pct    : REAL;              (* --> [CMD] Magnitude commande 0..100 %, bornée avant calcul *)
    FullTravelTimeS : REAL := 8.0;       (* --> [CFG] Temps complet Trémie→Maintenance à 100 %, simulation seulement *)
END_VAR
VAR_OUTPUT
    PosTremie      : BOOL;               (* <-- [STAT] Bit4 du mot capteurs *)
    PosPV          : BOOL;               (* <-- [STAT] Bit3 du mot capteurs *)
    PosP2          : BOOL;               (* <-- [STAT] Bit2 du mot capteurs (point matériel PVP2) *)
    PosP1          : BOOL;               (* <-- [STAT] Bit1 du mot capteurs *)
    PosMaintenance : BOOL;               (* <-- [STAT] Bit0 du mot capteurs *)
END_VAR
VAR
    instCycleTime              : FB_CycleTime;   (* * [INST] Mesure temps de cycle *)
    PositionProgress           : REAL;   (* . [LOC] 0 m=Trémie ... 30 m=Maintenance *)
    SpeedPctBounded            : REAL;   (* . [LOC] Vitesse bornée *)
    PositionIncrement          : REAL;   (* . [LOC] Incrément de progression *)
    Initialized                : BOOL := FALSE;   (* . [LOC] Initialisation *)
END_VAR
VAR CONSTANT
    // 📏 Positions réelles des 5 capteurs (mètres) — convention 0 m=Trémie, 30 m=Maintenance.
    // Distances NON-linéaires : 0→5 (PV), 5→15 (P2), 15→20 (P1), 20→30 (Maintenance).
    CST_PositionAtTremie       : REAL := 0.0;
    CST_PositionAtPV           : REAL := 5.0;
    CST_PositionAtP2           : REAL := 15.0;
    CST_PositionAtP1           : REAL := 20.0;
    CST_PositionAtMaintenance  : REAL := 30.0;
    CST_TotalDistanceM         : REAL := 30.0; // Distance totale Trémie→Maintenance (m)
    CST_MinFullTravelTimeS     : REAL := 0.1; // Protection division : modèle sans dynamique sous ce seuil
END_VAR

// === IMPLEMENTATION ===

{region "§1 Gate"}
IF NOT Enable THEN
    // Prochain démarrage déterministe sur la Trémie (0 m), pour un état de départ propre.
    PositionProgress := CST_PositionAtTremie;
    Initialized := FALSE;
    PosTremie := FALSE;
    PosPV := FALSE;
    PosP2 := FALSE;
    PosP1 := FALSE;
    PosMaintenance := FALSE;
    RETURN;
END_IF;
{endregion}

{region "§2 Initialisation"}
IF NOT Initialized THEN
    PositionProgress := CST_PositionAtTremie;
    Initialized := TRUE;
END_IF;
{endregion}

{region "§3 Progression"}
instCycleTime(DefaultValueS := 0.010);
SpeedPctBounded := LIMIT(0.0, ABS(SpeedTgt_Pct), 100.0);

// Une vitesse à 100 % parcourt les 30 m (Trémie→Maintenance) pendant FullTravelTimeS.
// Direction sémantique : +1 réduit la progression vers Trémie ; -1 l'augmente vers Maintenance.
IF FullTravelTimeS >= CST_MinFullTravelTimeS THEN
    PositionIncrement := (SpeedPctBounded / 100.0)
                         * (CST_TotalDistanceM / FullTravelTimeS)
                         * instCycleTime.CycleTimeS;
ELSE
    PositionIncrement := 0.0;
END_IF;

IF Direction = 1 THEN
    PositionProgress := MAX(CST_PositionAtTremie, PositionProgress - PositionIncrement);
ELSIF Direction = -1 THEN
    PositionProgress := MIN(CST_PositionAtMaintenance, PositionProgress + PositionIncrement);
END_IF;
{endregion}

{region "§4 Publication capteurs"}
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
{endregion}
