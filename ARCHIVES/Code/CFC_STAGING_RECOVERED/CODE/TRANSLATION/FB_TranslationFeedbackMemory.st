(* ═══════════════════════════════════════════════════════════════
   ↔️ FB_TranslationFeedbackMemory — Mémoire N-1 desserrage frein M3
   ───────────────────────────────────────────────────────────────
   📄 Migration M4 : rend explicite la lecture historique du propre
      BrakeReleaseRequest de instTranslationM3 avant son appel du scan.
   🔒 Cette mémoire ne prouve pas la position mécanique du frein. Le retour
      physique reste BrakeFeedback; la dette BrakeCmd A-07 reste inchangée.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_TranslationFeedbackMemory
VAR_INPUT
    BrakeReleaseRequest : BOOL;
END_VAR
VAR_OUTPUT
    PreviousBrakeReleaseRequest : BOOL;
END_VAR
VAR
    StoredBrakeReleaseRequest : BOOL := FALSE;
END_VAR

PreviousBrakeReleaseRequest := StoredBrakeReleaseRequest;
StoredBrakeReleaseRequest := BrakeReleaseRequest;
