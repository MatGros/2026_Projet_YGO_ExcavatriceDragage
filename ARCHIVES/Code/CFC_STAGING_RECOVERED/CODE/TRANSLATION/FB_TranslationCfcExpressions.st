(* ═══════════════════════════════════════════════════════════════
   ↔️ FB_TranslationCfcExpressions — Expressions extraites du CFC
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : porter les trois expressions booléennes du câblage
      historique dans un FB ST, afin que la page CFC XML ne comporte
      que des blocs et des fils.

   🔒 Conservation : chaque sortie est l'expression legacy à l'identique.
   Aucun accès sortie physique, aucune décision de sécurité nouvelle.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_TranslationCfcExpressions
VAR_INPUT
    BrakeThermalFeedback       : BOOL;
    BypassContactorFeedback    : BOOL;
    BypassGlobal               : BOOL;
    BypassLimitSwitch          : BOOL;
END_VAR
VAR_OUTPUT
    BrakeThermalOk                 : BOOL;
    BypassContactorFeedbackEffective : BOOL;
    BypassLimitSwitchEffective       : BOOL;
END_VAR

BrakeThermalOk := NOT BrakeThermalFeedback;
BypassContactorFeedbackEffective := BypassContactorFeedback OR BypassGlobal;
BypassLimitSwitchEffective := BypassGlobal OR BypassLimitSwitch;
