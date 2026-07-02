(* ═══════════════════════════════════════════════════════════════
   📤 FB_Output_Relay — Sortie relais + feedback (brique réduite)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie6_IO_Conditioning_v1.1.md §2
   🧭 Interface RÉDUITE (Partie3 §1bis) — relais de commande BAS NIVEAU :
      transmet fidèlement `Command` (déjà résolu/rampé par le FB métier
      appelant), ne décide JAMAIS lui-même d'un arrêt de mouvement.
   🔁 Rôle : inversion NO/NC, option blink 1Hz, double vérification
      commande/retour (contacteur collé/absent), diagnostic voie/carte.
   🔴 INTÉGRATION dans Winch/Translation/etc. : PAS encore décidée (choix
      d'architecture en attente — composition interne, remplacerait la
      logique actuelle TonFwdFeedback/ST_ContactorCheck manuelle dans
      FB_Winch/FB_Translation — vs FB_IO générique séparé). Ce fichier
      ne fait QUE créer la brique elle-même.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Output_Relay) ===

FUNCTION_BLOCK PUBLIC FB_Output_Relay
VAR_INPUT
    Command         : BOOL;         // Ordre logique, déjà résolu/rampé par le FB métier appelant
    InvertLogic     : BOOL;         // TRUE = NC
    FeedbackRaw     : BOOL;         // Retour d'état actionneur (optionnel)
    UseFeedback     : BOOL;         // Activer le contrôle de rétroaction
    Blink1Hz        : BOOL;         // Option : clignotement 1 Hz (diagnostic/visu)
    FeedbackTimeout : TIME := T#500ms; // Délai max cohérence cmd/retour
    ChannelOk       : BOOL := TRUE;    // Diag voie/carte sortie OK — TRUE par défaut si pas de diag dispo
END_VAR
VAR_OUTPUT
    OutputCmd       : BOOL;         // Vers la carte de sortie
    FeedbackOk      : BOOL;         // Retour cohérent avec la commande
    Error           : BOOL;
    ErrorId         : WORD;         // bit0 : feedback incohérent ; bit1 : voie/carte HS
END_VAR
VAR
    BlinkTimer      : TON;
    BlinkState      : BOOL;
    FeedbackTon     : TON;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Output_Relay) ===

// 1. Inversion NO/NC
OutputCmd := Command XOR InvertLogic;

// 2. Option blink 1 Hz (diagnostic/visualisation) — modulation à 500ms ON/500ms OFF
IF Blink1Hz AND OutputCmd THEN
    BlinkTimer(IN := NOT BlinkTimer.Q, PT := T#500ms);
    IF BlinkTimer.Q THEN
        BlinkState := NOT BlinkState;
    END_IF;
    OutputCmd := BlinkState;
ELSE
    BlinkTimer(IN := FALSE, PT := T#500ms);
    BlinkState := FALSE;
END_IF;

// 3. Double vérification commande/retour (contacteur collé/ne colle pas)
IF UseFeedback THEN
    FeedbackTon(IN := (OutputCmd <> FeedbackRaw), PT := FeedbackTimeout);
    IF FeedbackTon.Q THEN
        ErrorId := ErrorId OR 16#0001;
        FeedbackOk := FALSE;
    ELSE
        ErrorId := ErrorId AND 16#FFFE;
        FeedbackOk := TRUE;
    END_IF;
ELSE
    FeedbackTon(IN := FALSE, PT := FeedbackTimeout);
    FeedbackOk := TRUE;   // Pas de contrôle demandé — pas d'incohérence à signaler
END_IF;

// 4. Diagnostic voie/carte
IF NOT ChannelOk THEN
    ErrorId := ErrorId OR 16#0002;
ELSE
    ErrorId := ErrorId AND 16#FFFD;
END_IF;

Error := (ErrorId <> 16#0000);
