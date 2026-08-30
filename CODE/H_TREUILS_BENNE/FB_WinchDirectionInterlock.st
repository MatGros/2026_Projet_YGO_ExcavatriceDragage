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
    Reset           : BOOL;   // --> [CMD] Acquittement defaut (front) : purge la memoire de direction
    ReqDirection    : INT;    // --> [CMD] Sens demande (-1: Descending, 0: Stop, 1: Ascending)
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
    LastDirection        : INT;      // . [LOC] Dernier sens non nul memorise (interlock apres neutre)
    ResetEdge            : R_TRIG;   // . [LOC] Front Reset : purge la memoire de direction
END_VAR

// === IMPLEMENTATION ===

// Front Reset : purge la memoire de direction (un acquittement conscient reinitialise
// l'historique, une reprise apres Reset est un depart propre, pas une inversion).
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    LastDirection := 0;
    CommandedDirection := 0;
    DeadTimeArmed := FALSE;
    DirectionChangePending := FALSE;
END_IF;

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

// Adoption du sens
IF ReqDirection = 0 THEN
    // Neutre : CommandedDirection := 0 (relais/diagnostic neutres). La memoire du
    // dernier sens non nul (LastDirection) est conservee pour l'interlock de reprise.
    CommandedDirection := 0;
    DirectionChangePending := FALSE;
    DeadTimeArmed := FALSE;
ELSIF DeadTimeArmed THEN
    // D18 : temps mort au front Enable — pas d'adoption immediate
    DirectionChangePending := TRUE;
ELSIF DirectionChangeDelay.Q THEN
    // Temps mort ecoule : adoption du sens
    CommandedDirection := ReqDirection;
    DirectionChangePending := FALSE;
    DeadTimeArmed := FALSE;
ELSIF (CommandedDirection = 0) AND (ReqDirection <> 0) THEN
    // Depuis le neutre : depart immediat si reprise du MEME sens (ou premier sens),
    // sinon (sens oppose) pending + delai dedie obligatoire.
    IF (LastDirection = 0) OR (ReqDirection = LastDirection) THEN
        CommandedDirection := ReqDirection;
        DirectionChangePending := FALSE;
    ELSE
        DirectionChangePending := TRUE;
    END_IF;
ELSIF (ReqDirection <> 0) AND (ReqDirection <> CommandedDirection) THEN
    // Inversion directe (sans passage au neutre) : pending + delai
    DirectionChangePending := TRUE;
ELSE
    DirectionChangePending := FALSE;
END_IF;

// Memorise le dernier sens non nul ADOPTE (pas la simple demande) : c'est ce sens qui
// sert de reference pour detecter une reprise opposee apres passage au neutre.
IF CommandedDirection <> 0 THEN
    LastDirection := CommandedDirection;
END_IF;

END_FUNCTION_BLOCK
