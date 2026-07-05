(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_Chariot — Simulation dynamique du trajet chariot M3 (temps de parcours)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie13_Fonction_Simulation_v1.0.md
   🧩 Brique réduite (Partie3 §1bis) : outil de banc, pas du métier machine.
   🎯 Rôle : remplace le forçage manuel du capteur de position cible en vue
      instance CODESYS (voir `GVL_Chariot_M3_Stub.st`, doc Partie11 §9bis) par
      une simulation par temps de parcours : le chariot "arrive" à la cible
      sélectionnée (`TargetNum`) après `TravelTimeS` secondes de commande
      continue dans le bon sens (`RelayFwd`/`RelayRev`). Non prioritaire
      (M3 translation) — treuils/grappin/codeurs sont la priorité de ce lot.
   📥 Enable      : simulation active (SimulationModeActive AND NOT ChariotPosition_IsReal)
   📥 TargetNum   : cible sélectionnée (0=Aucun, 1=Fosse1, 2=Fosse2, 3=Maintenance, 4=Trémie)
                    — réutilise `GVL_Chariot_M3_Stub.StubChariotPositionSelect_IHM`
   📥 RelayFwd/RelayRev : sens commandé (sorties du chariot, DEGRADED_IO)
   📥 TravelTimeS : temps de trajet simulé (s) — défaut 8.0 (fourchette 5-10s validée
                    utilisateur, pas de donnée réelle pour calibrer plus précisément)
   📤 PosFosse1/PosFosse2/PosMaintenance/PosTremie : TRUE quand la cible correspondante
      est atteinte — à OR'er sur le `InputRaw` du capteur réel correspondant (PRG_00_Inputs.st)
   ⏱️ Changement de cible (`TargetNum`) → trajet remis à zéro (redémarre du début).
      Relais retombés (ni Fwd ni Rev) → progression mise EN PAUSE (pas remise à zéro).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Sim_Chariot) ===

FUNCTION_BLOCK PUBLIC FB_Sim_Chariot
VAR_INPUT
    Enable      : BOOL;
    TargetNum   : INT;
    RelayFwd    : BOOL;
    RelayRev    : BOOL;
    TravelTimeS : REAL := 8.0;
END_VAR
VAR_OUTPUT
    PosFosse1      : BOOL;
    PosFosse2      : BOOL;
    PosMaintenance : BOOL;
    PosTremie      : BOOL;
END_VAR
VAR
    CycleTimeCalc   : FB_CycleTime;   // 📚 Réutilisation — pas de recalcul maison du temps de cycle
    ElapsedS        : REAL;
    LastTargetNum   : INT;
    TargetChanged   : BOOL;
    Reached         : BOOL;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Sim_Chariot) ===

IF NOT Enable THEN
    ElapsedS := 0.0;
    LastTargetNum := TargetNum;
    PosFosse1 := FALSE; PosFosse2 := FALSE; PosMaintenance := FALSE; PosTremie := FALSE;
    RETURN;
END_IF;

CycleTimeCalc(DefaultValueS := 0.010);

// 🔁 Changement de cible = nouveau trajet, on repart de zéro
TargetChanged := (TargetNum <> LastTargetNum);
LastTargetNum := TargetNum;
IF TargetChanged THEN
    ElapsedS := 0.0;
END_IF;

// ⏱️ Progression du trajet UNIQUEMENT si un relais de sens est actif (mouvement réel demandé) ;
// à l'arrêt, la progression reste EN PAUSE (pas remise à zéro).
IF (RelayFwd OR RelayRev) AND (ElapsedS < TravelTimeS) THEN
    ElapsedS := ElapsedS + CycleTimeCalc.CycleTimeS;
    IF ElapsedS > TravelTimeS THEN
        ElapsedS := TravelTimeS;
    END_IF;
END_IF;

Reached := (ElapsedS >= TravelTimeS);

PosFosse1      := Reached AND (TargetNum = 1);
PosFosse2      := Reached AND (TargetNum = 2);
PosMaintenance := Reached AND (TargetNum = 3);
PosTremie      := Reached AND (TargetNum = 4);
