(* ═══════════════════════════════════════════════════════════════
   ↔️ FB_TranslationRuntimeGate — Préconditions d'appel FB_Translation
   ───────────────────────────────────────────────────────────────
   📄 Migration M4 : extrait les expressions booléennes/SEL de la page
      historique pour conserver un CFC XML sans calcul inline.
   🔒 Le retour de desserrage est lu à N-1 via FB_TranslationFeedbackMemory,
      identique à l'auto-référence historique instTranslationM3.BrakeReleaseRequest.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_TranslationRuntimeGate
VAR_INPUT
    MachineEnable                 : BOOL;
    Mode                          : E_Mode;
    BypassContactorFeedback       : BOOL;
    BrakeFeedback                 : BOOL;
    PreviousBrakeReleaseRequest   : BOOL;
END_VAR
VAR_OUTPUT
    Enable                        : BOOL;
    BrakeFeedbackForTranslation   : BOOL;
END_VAR

Enable := MachineEnable AND (Mode <> E_Mode.DISABLE);

IF BypassContactorFeedback THEN
    BrakeFeedbackForTranslation := PreviousBrakeReleaseRequest;
ELSE
    BrakeFeedbackForTranslation := BrakeFeedback;
END_IF;
