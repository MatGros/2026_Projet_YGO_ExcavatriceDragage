// ═══════════════════════════════════════════════════════════════
// 🧪 E_TestCheckMode — Mode d'évaluation des checks
// ═══════════════════════════════════════════════════════════════

TYPE E_TestCheckMode :
(
    CHECK_INSTANT      := 0,  // Vérité exigée au 1er cycle d'évaluation de l'étape (fail sinon)
    CHECK_WAIT_UNTIL   := 1,  // Attendre que ça devienne vrai, tenu StablePT en continu (T#0s = immédiat), borné par TimeoutPT d'étape
    CHECK_INVARIANT    := 2,  // Doit rester vrai CHAQUE cycle de la fenêtre — fail immédiat à la 1re violation
    CHECK_NEVER_DURING := 3   // Ne doit JAMAIS devenir vrai — pass à l'expiration du TimeoutPT d'étape (= la fenêtre)
);
END_TYPE
