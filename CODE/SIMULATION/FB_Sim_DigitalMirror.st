(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_DigitalMirror — Miroir commande→retour temporisé (contacteur simulé)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-13_Fonction_Simulation_v1.2.md
   🧩 Brique réduite (Partie3 §1bis), générique et réutilisable — outil de banc.
   🎯 Rôle : simule un retour de contacteur réaliste (délai mécanique de
      fermeture/ouverture), au lieu d'un miroir "idéal" instantané. Utilisée pour
      le retour contacteur M3 (`PRG_07_TranslationControl.st`), remplace le miroir
      inconditionnel actuel. Réutilise `TON` (Partie3 §0 — pas de temporisation
      réimplémentée), même principe que `ContactorFeedbackTimeout` déjà en place
      dans `FB_Winch.st`/`FB_Translation.st`.
   📥 Enable       : simulation active (ex. SimulationModeActive AND NOT ContactorFeedbackM3_IsReal)
   📥 Command      : ordre envoyé au contacteur (TRUE = fermé/actif)
   📥 MirrorDelay  : délai de fermeture/ouverture simulé — À FIXER nettement SOUS le
      `ContactorFeedbackTimeout` du FB consommateur (`FB_Winch`/`FB_Translation`), sinon le
      StuckClosed/StuckOpen se déclenche à tort pendant le délai simulé.
   📤 Feedback     : retour simulé (suit Command après MirrorDelay)
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Sim_DigitalMirror) ===

FUNCTION_BLOCK PUBLIC FB_Sim_DigitalMirror
VAR_INPUT
    Enable      : BOOL;
    Command     : BOOL;
    MirrorDelay : TIME := T#150ms;
END_VAR
VAR_OUTPUT
    Feedback    : BOOL;
END_VAR
VAR
    TonMirror   : TON;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Sim_DigitalMirror) ===

IF NOT Enable THEN
    TonMirror(IN := FALSE, PT := MirrorDelay);
    Feedback := Command;   // Hors simulation : miroir idéal (comportement précédent conservé)
    RETURN;
END_IF;

TonMirror(IN := (Command <> Feedback), PT := MirrorDelay);
IF TonMirror.Q THEN
    Feedback := Command;
END_IF;
