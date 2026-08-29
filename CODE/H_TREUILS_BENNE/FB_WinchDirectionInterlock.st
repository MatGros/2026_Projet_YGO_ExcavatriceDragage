(* =======================================================================
   🔀 FB_WinchDirectionInterlock — Interlock de changement de sens
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Temporise le changement de sens d'un treuil (dead time)
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Interface : Brique technique (contrat light, pas de defaut)
   🔒 Sécurité : D18 — au front montant Enable, n'adopte pas le sens
                 immediatement (temps mort) ; pas de redemarrage inrush
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_WinchDirectionInterlock
VAR_INPUT
    Enable          : BOOL;   // --> [CMD] Gate TON (TRUE = treuil arrete, contacteurs retombes)
    EnableRising    : BOOL;   // --> [CMD] Front montant Enable du FB parent (D18)
    ReqDirection    : INT;    // --> [CMD] Sens demande (-1: Descente, 0: Stop, 1: Montee)
    ChangeDelayUp   : TIME;   // --> [CFG] Delai interlock changement de sens montee
    ChangeDelayDown : TIME;   // --> [CFG] Delai interlock changement de sens descente
END_VAR
VAR_OUTPUT
    CommandedDirection      : INT;   // <-- [DIAG] Sens interne memorise
    DirectionChangePending  : BOOL;  // <-- [DIAG] Changement de sens en attente
    DelayElapsed            : TIME;  // <-- [DIAG] Ecoule delai changement de sens
END_VAR
VAR
    DirectionChangeDelay : TON;      // . [LOC] Temporisation changement de sens
    EffectiveDelay       : TIME;     // . [LOC] Delai effectif selon sens
    DeadTimeArmed        : BOOL;     // . [LOC] Temps mort D18 arme (front Enable)
END_VAR

// === IMPLEMENTATION ===

// Delai effectif selon le sens demande
IF ReqDirection > 0 THEN
    EffectiveDelay := ChangeDelayUp;
ELSE
    EffectiveDelay := ChangeDelayDown;
END_IF;

// D18 : au front montant Enable avec sens maintenu, armer le temps mort
// (ne pas re-adopter le sens immediatement — pas de redemarrage inrush).
IF EnableRising AND (ReqDirection <> 0) THEN
    DeadTimeArmed := TRUE;
END_IF;

// Temporisation : compte quand un changement de sens est demande et treuil arrete
DirectionChangeDelay(
    IN := Enable AND (ReqDirection <> 0) AND (ReqDirection <> CommandedDirection),
    PT := EffectiveDelay
);
DelayElapsed := DirectionChangeDelay.ET;

IF (CommandedDirection = 0) AND (ReqDirection <> 0) AND NOT DeadTimeArmed THEN
    // Neutre -> sens : adoption immediate (hors temps mort D18)
    CommandedDirection := ReqDirection;
    DirectionChangePending := FALSE;
ELSIF DirectionChangeDelay.Q THEN
    // Temps mort ecoule : adoption du sens
    CommandedDirection := ReqDirection;
    DirectionChangePending := FALSE;
    DeadTimeArmed := FALSE;
ELSIF (ReqDirection <> 0) AND (ReqDirection <> CommandedDirection) THEN
    DirectionChangePending := TRUE;
ELSE
    DirectionChangePending := FALSE;
END_IF;

IF ReqDirection = 0 THEN
    CommandedDirection := 0;
    DirectionChangePending := FALSE;
    DeadTimeArmed := FALSE;
END_IF;

END_FUNCTION_BLOCK
