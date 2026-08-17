(* ═══════════════════════════════════════════════════════════════
   📤 FB_Output — Sortie relais (brique réduite, REX 2026-08-04)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-03_Contrats_Composants_v2.1.md §Câblage
   🧭 Interface RÉDUITE (validée utilisateur 2026-08-04) : relais de
      commande BAS NIVEAU — transmet fidèlement `Command` (déjà
      résolu/rampé par le FB métier appelant), ne décide JAMAIS lui-même
      d'un arrêt de mouvement.
   🔁 Rôle : inversion NO/NC uniquement.
   🗑️ REX 2026-08-04 : partie FEEDBACK retirée (FeedbackRaw, UseFeedback,
      Blink1Hz, FeedbackTimeout, ChannelOk, FeedbackOk, Error, ErrorId) —
      jamais câblée (0 usage dans PRG_06, 15 instances Command→State).
      Diagnostic contacteur déjà couvert au niveau métier par
      FB_Safety_Winch (FwdRevSpeedFeedbackOff, BrakeFeedback).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Output
VAR_INPUT
    Command     : BOOL;   // Ordre logique, déjà résolu/rampé par le FB métier appelant
    InvertLogic : BOOL;   // TRUE = câblage NC (inversion de la sortie)
END_VAR
VAR_OUTPUT
    State       : BOOL;   // Vers la carte de sortie
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Output) ===

State := Command XOR InvertLogic;
