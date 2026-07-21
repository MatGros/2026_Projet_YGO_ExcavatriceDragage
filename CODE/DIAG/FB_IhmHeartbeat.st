(* ═══════════════════════════════════════════════════════════════
   💓 FB_IhmHeartbeat — Surveillance bidirectionnelle IHM↔PLC
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-07_Interface_IHM_v1.5.md (mise à jour Heartbeat requise)
   🧩 Brique réduite : surveille le toggle IHM, génère le toggle PLC
      et expose un diagnostic. Ne produit ni SafeStop ni PowerCutOff.
   🛡️ Les FB_Safety_Winch / FB_Safety_Translation restent propriétaires
      de leurs réactions métier.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_IhmHeartbeat
VAR_INPUT
    Enable              : BOOL;              // Active la surveillance ; FALSE = IHM non valide
    HeartbeatIhmToggle  : BOOL;              // Toggle IHM, inversion attendue toutes les 500 ms
    IhmTimeout          : TIME := T#2s;     // Absence maximale de front IHM
    PlcTogglePeriod     : TIME := T#500ms;  // Période du clignotant PLC
END_VAR
VAR_OUTPUT
    HeartbeatIhmOk      : BOOL;              // TRUE après front IHM post-boot et avant timeout
    HeartbeatIhmTimeout : BOOL;              // TRUE = aucun front IHM depuis IhmTimeout
    HeartbeatPlcToggle  : BOOL;              // Clignotant PLC à superviser côté IHM
    TimeSinceIhmEdge    : TIME;              // Diagnostic : temps depuis le dernier front IHM
END_VAR
VAR
    LastIhmToggle       : BOOL;
    IhmEdgeSeen         : BOOL;              // Interdit de valider une valeur RETAIN au boot
    IhmEdgeDetected     : BOOL;
    IhmTimeoutTon       : TON;
    PlcToggleTon        : TON;
END_VAR

// === IMPLEMENTATION ===

// 🛑 Sans Enable, aucune valeur mémorisée ne peut déclarer l'IHM valide.
IF NOT Enable THEN
    HeartbeatIhmOk := FALSE;
    HeartbeatIhmTimeout := TRUE;
    HeartbeatPlcToggle := FALSE;
    TimeSinceIhmEdge := T#0s;
    LastIhmToggle := HeartbeatIhmToggle;
    IhmEdgeSeen := FALSE;
    IhmTimeoutTon(IN := FALSE, PT := IhmTimeout);
    PlcToggleTon(IN := FALSE, PT := PlcTogglePeriod);
    RETURN;
END_IF;

// 📥 Front par comparaison : l'IHM écrit un BOOL toggle, pas une impulsion courte.
IhmEdgeDetected := (HeartbeatIhmToggle <> LastIhmToggle);
LastIhmToggle := HeartbeatIhmToggle;
IF IhmEdgeDetected THEN
    IhmEdgeSeen := TRUE;
END_IF;

// ⏱️ Le timer repart à chaque front. Au boot, il atteint le timeout même sans front,
// mais HeartbeatIhmOk reste FALSE tant qu'un premier front post-boot n'est pas observé.
IhmTimeoutTon(IN := NOT IhmEdgeDetected, PT := IhmTimeout);
TimeSinceIhmEdge := IhmTimeoutTon.ET;
HeartbeatIhmTimeout := IhmTimeoutTon.Q;
HeartbeatIhmOk := IhmEdgeSeen AND NOT HeartbeatIhmTimeout;

// 💡 Clignotant PLC indépendant : information de vie pour l'IHM, jamais signal Safety autonome.
PlcToggleTon(IN := NOT PlcToggleTon.Q, PT := PlcTogglePeriod);
IF PlcToggleTon.Q THEN
    HeartbeatPlcToggle := NOT HeartbeatPlcToggle;
END_IF;
