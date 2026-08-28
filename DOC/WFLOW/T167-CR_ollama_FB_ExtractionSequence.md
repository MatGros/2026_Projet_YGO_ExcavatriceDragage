# T167-CR — Rapport brut Ollama deepseek-v4-flash : FB_ExtractionSequence

> Revue READ-ONLY sur extrait ST §1-§3 (2026-08-28). Analyse orchestrateur : voir T167-CR_REVUE_INDEPENDANTE_CYCLES.md §2.

---

**MAJEUR :**
- Reset → `WAIT_BOTTOM_CONFIRMATION` sans exigence de confirmation basse **fraîche** : après défaut en `CONTROL_ASCENT`, si `BottomPositionConfirmed` reste TRUE (capteur collé/portée), reprise fermeture benne mi-course → état sûr non prouvé (ISO 13849).

**Mineur :**
- Division par zéro si `CST_MinSpeed_Mps = 0` dans `CalculatedControlAscentTimeout` (`REAL_TO_UDINT(∞)` → indéfini).
- `MotionDirection = 1` littéral : vérifier sémantique pour `CLOSING_BUCKET` (si fermeture = descente, accumulateur jamais incrémenté → backstop inopérant).

**Info :**
- `PrevState` non visible dans l'extrait : vérifier MAJ en fin de scan pour `StepAtFault` correct.
- Gate ne coupe que 3 sorties : vérifier coupure de **toutes** sorties physiques (treuils, freins).

**VERDICT : MAJEUR** — corriger le point 1 (exiger confirmation basse fraîche au reset) avant mise en service.