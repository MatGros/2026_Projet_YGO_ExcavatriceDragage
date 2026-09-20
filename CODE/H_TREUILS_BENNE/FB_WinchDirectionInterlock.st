(* =======================================================================
   🔀 FB_WinchDirectionInterlock — Interlock de changement de sens
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Temporise l'INVERSION de sens d'un treuil, en creditant le
             temps d'arret physique reel deja ecoule (dead time)
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Interface : Brique technique (contrat light, pas de defaut)
   🔒 Sécurité : D18 — au front montant Enable, n'adopte pas le sens
                 immediatement (temps mort) ; pas de redemarrage inrush.
                 Le sens IDENTIQUE au dernier sens adopte reste toujours
                 immediat depuis le neutre : seule l'INVERSION est temporisee.
                 Purge de DeadTimeArmed garantie des que le temps mort est
                 ecoule (T325 phase 1). Limite residuelle connue (T325
                 phase 2, non couverte ici) : si la demande redevient le
                 MEME sens que le dernier commande alors que DeadTimeArmed
                 vient d'etre arme, DirectionChanged reste FALSE et le
                 temps mort ne peut jamais etre mesure -- seule sortie
                 encore possible dans ce cas precis : retour au neutre ou
                 Reset.
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
    DirectionChangeDelay  : TON;      // . [LOC] Xa->Xb : compte le reliquat apres la nouvelle demande d'inversion
    StoppedTimer          : TON;      // . [LOC] Xc->Xd : accumule le temps d'arret physique reel (Enable, hors demande)
    CapturedStoppedTime   : TIME;     // . [LOC] Arret reel credite, fige au front RequestActive, purge une fois consomme
    RemainingDelay        : TIME;     // . [LOC] Reliquat a appliquer par DirectionChangeDelay (delai plein - arret credite)
    EffectiveDelay        : TIME;     // . [LOC] Delai plein selon sens demande
    MaxDirectionDelay     : TIME;     // . [LOC] MAX(ChangeDelayAscent, ChangeDelayDescent) : base d'accumulation StoppedTimer
    DeadTimeArmed         : BOOL;     // . [LOC] Temps mort D18 arme (front Enable)
    LastAscent            : BOOL;     // . [LOC] Dernier sens adopté : montée
    LastDescend           : BOOL;     // . [LOC] Dernier sens adopté : descente
    RequestActive         : BOOL;     // . [LOC] Une seule demande de sens active
    RequestActiveRising   : R_TRIG;   // . [LOC] Front nouvelle demande : capture le credit avant le rappel de StoppedTimer
    DirectionChanged      : BOOL;     // . [LOC] Demande différente du sens commandé
    ResetEdge             : R_TRIG;   // . [LOC] Front Reset : purge la memoire de direction
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
    CapturedStoppedTime := T#0ms;
END_IF;

RequestConflict := ReqAscent AND ReqDescend;
RequestActive := (ReqAscent OR ReqDescend) AND NOT RequestConflict;

// Xc->Xd : capture l'arret physique REEL deja ecoule (StoppedTimer.ET) AU FRONT de
// la nouvelle demande, AVANT le rappel de StoppedTimer plus bas dans ce scan (un TON
// dont IN retombe a FALSE remet son ET a 0 des cet appel — lire apres serait deja 0).
RequestActiveRising(CLK := RequestActive);
IF RequestActiveRising.Q THEN
    CapturedStoppedTime := StoppedTimer.ET;
END_IF;

// Délai plein selon le sens demandé, et base commune pour l'accumulation d'arret
// (le sens final n'est pas encore connu pendant le neutre).
IF ReqAscent AND NOT ReqDescend THEN
    EffectiveDelay := ChangeDelayAscent;
ELSE
    EffectiveDelay := ChangeDelayDescent;
END_IF;
MaxDirectionDelay := MAX(ChangeDelayAscent, ChangeDelayDescent);
RemainingDelay := MAX(EffectiveDelay - CapturedStoppedTime, T#0ms);

DirectionChanged := (ReqAscent AND NOT CommandedAscent)
                 OR (ReqDescend AND NOT CommandedDescend)
                 OR (CommandedAscent AND NOT ReqAscent)
                 OR (CommandedDescend AND NOT ReqDescend);

// D18 : au front montant Enable avec sens maintenu, armer le temps mort
// (ne pas re-adopter le sens immediatement — pas de redemarrage inrush).
IF EnableRising AND RequestActive THEN
    DeadTimeArmed := TRUE;
END_IF;

// Xc->Xd : StoppedTimer compte l'arret physique REEL (Enable = treuil arrete,
// contacteurs retombes, cf. FB_Winch) pendant TOUT le neutre, jamais reinitialise
// par le simple relachement du joystick — c'est ce cumul qui alimente la capture
// ci-dessus au scan suivant.
StoppedTimer(IN := Enable AND NOT RequestActive, PT := MaxDirectionDelay);

// Xa->Xb : compte le reliquat (delai plein - arret deja credite) apres la nouvelle
// demande d'inversion.
DirectionChangeDelay(
    IN := Enable AND RequestActive AND DirectionChanged,
    PT := RemainingDelay
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
ELSIF DirectionChangeDelay.Q THEN
    // Temps mort ecoule : adoption du sens, y compris si DeadTimeArmed etait pose
    // (purge desormais atteignable -- le temps mort minimal a ete respecte, il ne
    // doit pas rester arme indefiniment une fois le delai reellement ecoule).
    CommandedAscent := ReqAscent;
    CommandedDescend := ReqDescend;
    DirectionChangePending := FALSE;
    DeadTimeArmed := FALSE;
ELSIF DeadTimeArmed THEN
    // D18 : temps mort au front Enable — pas d'adoption immediate tant que le
    // delai (ci-dessus) n'est pas ecoule.
    DirectionChangePending := TRUE;
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

// Le sens adopte correspond desormais a la demande (aucune inversion en cours) :
// le credit d'arret est CONSOMME. Une inversion ULTERIEURE sans nouveau passage au
// neutre (RequestActive reste continuellement vrai) ne doit jamais reutiliser un
// arret perime — elle applique alors le delai plein (CapturedStoppedTime := 0).
IF NOT DirectionChangePending AND (CommandedAscent = ReqAscent) AND (CommandedDescend = ReqDescend) THEN
    CapturedStoppedTime := T#0ms;
END_IF;

END_FUNCTION_BLOCK
