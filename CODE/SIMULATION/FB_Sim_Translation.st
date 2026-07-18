(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_Translation — Simulation dynamique du trajet translation M3 (temps de parcours)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-13_Fonction_Simulation_v1.2.md
   🧩 Brique réduite (Partie3 §1bis) : outil de banc, pas du métier machine.
   🎯 Rôle : remplace le forçage manuel du capteur de position cible en vue
      instance CODESYS (voir `GVL_Translation_M3_Stub.st`, doc Partie11 §9bis) par
      une simulation par temps de parcours : le translation "arrive" à la cible
      sélectionnée (`TargetNum`) après `TravelTimeS` secondes de commande
      continue dans le bon sens (`RelayFwd`/`RelayRev`). Non prioritaire
      (M3 translation) — treuils/benne/codeurs sont la priorité de ce lot.
   📥 Enable      : simulation active (SimulationModeActive AND NOT TranslationPosition_IsReal)
   📥 TargetNum   : cible sélectionnée (0=Aucun, 1=Trémie, 2=P2, 3=P1, 4=Maintenance)
                    — réutilise `GVL_Translation_M3_Stub.StubTranslationPositionSelect_IHM`
                    — 🆕 REX 2026-07-18 : PV n'est JAMAIS une cible sélectionnable (point de
                    ralentissement uniquement, pas d'arrêt), voir AF_Partie-02 v2.12 §3bis
   📥 RelayFwd/RelayRev : sens déduit du mot de commande EtherCAT M3
   📥 TravelTimeS : temps de trajet simulé (s) — défaut 8.0 (fourchette 5-10s validée
                    utilisateur, pas de donnée réelle pour calibrer plus précisément)
   📥 PVLeadTimeS : durée (s) avant la fin du trajet Trémie où PV s'active (approche)
   📤 PosTremie/PosPV/PosP2/PosP1/PosMaintenance : TRUE quand la cible (ou le point de
      ralentissement PV) correspondante est atteinte — à OR'er sur le `InputRaw` du capteur
      réel correspondant (PRG_00_Inputs.st)
   ⏱️ Changement de cible (`TargetNum`) → trajet remis à zéro (redémarre du début).
      Relais retombés (ni Fwd ni Rev) → progression mise EN PAUSE (pas remise à zéro).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Sim_Translation) ===

FUNCTION_BLOCK PUBLIC FB_Sim_Translation
VAR_INPUT
    Enable      : BOOL;
    TargetNum   : INT;
    RelayFwd    : BOOL;
    RelayRev    : BOOL;
    TravelTimeS : REAL := 8.0;
    PVLeadTimeS : REAL := 2.0;
END_VAR
VAR_OUTPUT
    PosTremie      : BOOL;
    PosPV          : BOOL;
    PosP2          : BOOL;
    PosP1          : BOOL;
    PosMaintenance : BOOL;
END_VAR
VAR
    CycleTimeCalc   : FB_CycleTime;   // 📚 Réutilisation — pas de recalcul maison du temps de cycle
    ElapsedS        : REAL;
    LastTargetNum   : INT;
    TargetChanged   : BOOL;
    Reached         : BOOL;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Sim_Translation) ===

IF NOT Enable THEN
    ElapsedS := 0.0;
    LastTargetNum := TargetNum;
    PosTremie := FALSE; PosPV := FALSE; PosP2 := FALSE; PosP1 := FALSE; PosMaintenance := FALSE;
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

// 🆕 REX 2026-07-18 : les capteurs sont codés par progression monotone.
// La simulation doit donc produire un mot valide à chaque instant, et non
// uniquement activer le capteur de la cible. Le mot est :
//   11111 Trémie | 01111 PV | 00111 P2 | 00011 P1 | 00001 approche Maintenance | 00000 Maintenance.
// Tant qu'une cible n'est pas atteinte, la position virtuelle reste à droite (00000),
// sauf lors de l'approche Trémie où le PV (01111) est activé.
PosTremie := FALSE;
PosPV := FALSE;
PosP2 := FALSE;
PosP1 := FALSE;
PosMaintenance := FALSE; // état de repos simulé : mot valide 00000

IF TargetNum = 1 THEN
    // Trajet vers Trémie : PV puis Trémie, avec les trois capteurs de droite actifs.
    IF ElapsedS >= (TravelTimeS - PVLeadTimeS) THEN
        PosPV := TRUE;
        PosP2 := TRUE;
        PosP1 := TRUE;
        PosMaintenance := TRUE;
    END_IF;
    IF Reached THEN
        PosTremie := TRUE;
    END_IF;
ELSIF TargetNum = 2 AND Reached THEN
    // P2 = 00111
    PosP2 := TRUE;
    PosP1 := TRUE;
    PosMaintenance := TRUE;
ELSIF TargetNum = 3 AND Reached THEN
    // P1 = 00011
    PosP1 := TRUE;
    PosMaintenance := TRUE;
ELSIF TargetNum = 4 AND Reached THEN
    // Maintenance = 00000 : PosMaintenance reste FALSE pour respecter le codage.
    PosMaintenance := FALSE;
END_IF;
