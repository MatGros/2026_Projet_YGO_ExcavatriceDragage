(* =======================================================================
   📊 FB_Diag_IhmHeartbeat — Surveillance bidirectionnelle Heartbeat IHM/PLC
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Surveillance toggle IHM, generation toggle PLC et diagnostic timeout
   🛡️ Protection : FB de diagnostic autonome (sans action directe sur AU)
   📄 Doc métier : DOC/AF/AF_Partie-12_Fonction_Diagnostic_v1.0.md
   ======================================================================= *)
FUNCTION_BLOCK PUBLIC FB_Diag_IhmHeartbeat
VAR_INPUT
    // === COMMANDES & REGLAGES ===
    Enable                      : BOOL;         // --> [CMD] Active la surveillance (FALSE = IHM invalide)
    TglHeartbeatIhm             : BOOL;         // --> [HW]  Toggle IHM, inversion attendue toutes les 500 ms
    IhmTimeout                  : TIME := T#2s; // --> [CFG] Absence maximale de front IHM
    PlcTogglePeriod             : TIME := T#500ms; // --> [CFG] Periode du clignotant PLC
END_VAR
VAR_OUTPUT
    // === ETATS & DIAGNOSTICS IHM ===
    HeartbeatIhmOk              : BOOL;         // <-- [STAT] TRUE apres front IHM post-boot et avant timeout
    HeartbeatIhmTimeout         : BOOL;         // <-- [DIAG] TRUE = aucun front IHM depuis IhmTimeout
    TglHeartbeatPlc             : BOOL;         // <-- [STAT] Clignotant PLC a superviser cote IHM
    TimeSinceIhmEdge            : TIME;         // <-- [DIAG] Temps ecoule depuis le dernier front IHM
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    IhmTimeoutTon               : TON;          // * [INST] Timer de surveillance timeout IHM
    PlcToggleTon                : TON;          // * [INST] Timer clignotant heartbeat PLC

    // === CALCULS ET ETATS INTERNES ===
    LastIhmToggle               : BOOL;         // . [LOC]  Memoire du dernier etat toggle IHM
    IhmEdgeSeen                 : BOOL;         // . [LOC]  Verrou front vu (interdit RETAIN au boot)
    IhmEdgeDetected             : BOOL;         // . [LOC]  Front de changement toggle IHM detecte
END_VAR

// === IMPLEMENTATION ===

// 🛑 Sans Enable, aucune valeur mémorisée ne peut déclarer l'IHM valide.
IF NOT Enable THEN
    HeartbeatIhmOk := FALSE;
    HeartbeatIhmTimeout := TRUE;
    TglHeartbeatPlc := FALSE;
    TimeSinceIhmEdge := T#0s;
    LastIhmToggle := TglHeartbeatIhm;
    IhmEdgeSeen := FALSE;
    IhmTimeoutTon(IN := FALSE, PT := IhmTimeout);
    PlcToggleTon(IN := FALSE, PT := PlcTogglePeriod);
    RETURN;
END_IF;

// 📥 Front par comparaison : l'IHM écrit un BOOL toggle, pas une impulsion courte.
IhmEdgeDetected := (TglHeartbeatIhm <> LastIhmToggle);
LastIhmToggle := TglHeartbeatIhm;
IF IhmEdgeDetected THEN
    IhmEdgeSeen := TRUE;
END_IF;

// ⏱️ Le timer repart à chaque front. Au boot, il atteint le timeout au bout de IhmTimeout.
// HeartbeatIhmOk reste TRUE tant que le timeout n'est pas expiré (boot propre sans alarme au scan 1).
IhmTimeoutTon(IN := NOT IhmEdgeDetected, PT := IhmTimeout);
TimeSinceIhmEdge := IhmTimeoutTon.ET;
HeartbeatIhmTimeout := IhmTimeoutTon.Q;
HeartbeatIhmOk := NOT HeartbeatIhmTimeout;

// 💡 Clignotant PLC indépendant : information de vie pour l'IHM, jamais signal Signal Safety autonome.
PlcToggleTon(IN := NOT PlcToggleTon.Q, PT := PlcTogglePeriod);
IF PlcToggleTon.Q THEN
    TglHeartbeatPlc := NOT TglHeartbeatPlc;
END_IF;
