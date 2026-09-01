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
    ReqAscent       : BOOL;   // --> [CMD] Demande montée
    ReqDescend      : BOOL;   // --> [CMD] Demande descente
    ChangeDelayAscent   : TIME;   // --> [CFG] Delai interlock changement de sens montee
    ChangeDelayDescent : TIME;   // --> [CFG] Delai interlock changement de sens descente
END_VAR
VAR_OUTPUT
    CommandedAscent         : BOOL;  // <-- [DIAG] Sens interne mémorisé : montée
    CommandedDescend        : BOOL;  // <-- [DIAG] Sens interne mémorisé : descente
    RequestConflict         : BOOL;  // <-- [DIAG] Double demande refusée
    DirectionChangePending  : BOOL;  // <-- [DIAG] Changement de sens en attente
    DelayElapsed            : TIME;  // <-- [DIAG] Ecoule delai changement de sens
END_VAR
VAR
    DirectionChangeDelay : TON;      // . [LOC] Temporisation changement de sens
    EffectiveDelay       : TIME;     // . [LOC] Delai effectif selon sens
    DeadTimeArmed        : BOOL;     // . [LOC] Temps mort D18 arme (front Enable)
    LastAscent           : BOOL;     // . [LOC] Dernier sens adopté : montée
    LastDescend          : BOOL;     // . [LOC] Dernier sens adopté : descente
    RequestActive        : BOOL;     // . [LOC] Une seule demande de sens active
    DirectionChanged     : BOOL;     // . [LOC] Demande différente du sens commandé
    ResetEdge            : R_TRIG;   // . [LOC] Front Reset : purge la memoire de direction
END_VAR

// === IMPLEMENTATION ===

// Front Reset : purge la memoire de direction (un acquittement conscient reinitialise
// l'historique, une reprise apres Reset est un depart propre, pas une inversion).
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    LastAscent := FALSE;
    LastDescend := FALSE;
    CommandedAscent := FALSE;
    CommandedDescend := FALSE;
    DeadTimeArmed := FALSE;
    DirectionChangePending := FALSE;
END_IF;

RequestConflict := ReqAscent AND ReqDescend;
RequestActive := (ReqAscent OR ReqDescend) AND NOT RequestConflict;

// Délai effectif selon le sens demandé
IF ReqAscent AND NOT ReqDescend THEN
    EffectiveDelay := ChangeDelayAscent;
ELSE
    EffectiveDelay := ChangeDelayDescent;
END_IF;

DirectionChanged := (ReqAscent AND NOT CommandedAscent)
                 OR (ReqDescend AND NOT CommandedDescend)
                 OR (CommandedAscent AND NOT ReqAscent)
                 OR (CommandedDescend AND NOT ReqDescend);

// D18 : au front montant Enable avec sens maintenu, armer le temps mort
// (ne pas re-adopter le sens immediatement — pas de redemarrage inrush).
IF EnableRising AND RequestActive THEN
    DeadTimeArmed := TRUE;
END_IF;

// Temporisation : compte quand un changement de sens est demande et treuil arrete
DirectionChangeDelay(
    IN := Enable AND RequestActive AND DirectionChanged,
    PT := EffectiveDelay
);
DelayElapsed := DirectionChangeDelay.ET;

// Adoption du sens
IF NOT RequestActive THEN
    // Neutre ou double demande : aucun sens commandé. Une double demande est
    // explicitement refusée, sans priorité implicite.
    CommandedAscent := FALSE;
    CommandedDescend := FALSE;
    DirectionChangePending := FALSE;
    DeadTimeArmed := FALSE;
ELSIF DeadTimeArmed THEN
    // D18 : temps mort au front Enable — pas d'adoption immediate
    DirectionChangePending := TRUE;
ELSIF DirectionChangeDelay.Q THEN
    // Temps mort ecoule : adoption du sens
    CommandedAscent := ReqAscent;
    CommandedDescend := ReqDescend;
    DirectionChangePending := FALSE;
    DeadTimeArmed := FALSE;
ELSIF NOT (CommandedAscent OR CommandedDescend) THEN
    // Depuis le neutre : depart immediat si reprise du MEME sens (ou premier sens),
    // sinon (sens oppose) pending + delai dedie obligatoire.
    IF (NOT (LastAscent OR LastDescend))
       OR (ReqAscent AND LastAscent)
       OR (ReqDescend AND LastDescend) THEN
        CommandedAscent := ReqAscent;
        CommandedDescend := ReqDescend;
        DirectionChangePending := FALSE;
    ELSE
        DirectionChangePending := TRUE;
    END_IF;
ELSIF DirectionChanged THEN
    // Inversion directe (sans passage au neutre) : pending + delai
    DirectionChangePending := TRUE;
ELSE
    DirectionChangePending := FALSE;
END_IF;

// Memorise le dernier sens non nul ADOPTE (pas la simple demande) : c'est ce sens qui
// sert de reference pour detecter une reprise opposee apres passage au neutre.
IF CommandedAscent OR CommandedDescend THEN
    LastAscent := CommandedAscent;
    LastDescend := CommandedDescend;
END_IF;

END_FUNCTION_BLOCK
