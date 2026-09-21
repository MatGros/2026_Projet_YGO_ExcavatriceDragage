=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===

## 1. Contexte

`CODE/L_SIMULATION/FB_Sim_Translation.st:229` calcule la vitesse simulée via
`FullTravelTimeS := 8.0` (30m/8s), indépendamment de
`GVL_PERSISTENT._TranslationGainMetersPerHzSec` (= `0.02` désormais) utilisé
par l'estimateur (`CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st`).
Résultat : gros sauts de recalage en simulation au passage capteur (2 vitesses
différentes qui se battent). Confirmé sur trace `Suivi_74_SIMU_MAINTN1_M3`.

## 2. Objectif (2 volets)

**VOLET A** : aligner `FullTravelTimeS` du simulateur pour qu'il corresponde
au ratio actuel (`0.02` = 1 m/s sur 30m = 30s). Simulation cohérente en
interne, testable.

**VOLET B — proposition utilisateur, à CHIFFRER avant de coder** : ne plus
forcer la position sur les 4 capteurs intermédiaires (PV/P2/P1/Maintenance),
garder le recalage forcé **uniquement au capteur Trémie**. Le reste du trajet
fait confiance au ratio odométrique pur.

Avant d'implémenter B : chiffrer la dérive max possible sans recalage
intermédiaire (jusqu'à 30m au lieu de 10m actuellement entre 2 capteurs,
cf. `AUDIT_T360_TRACE_RATIO_ESTIMATEUR_M3_20260921.md` point 5), comparer à
l'option actuelle (5 capteurs), proposer si pertinent une 3e option
(recalage sur les 5 mais seuil de tolérance avant saut brutal). Présenter les
options à l'utilisateur, ne pas trancher seul.

## 3. Livrables

- VOLET A : diff `FB_Sim_Translation.st`, test CI, preuve simu cohérente.
- VOLET B : tableau comparatif chiffré (pas de code avant validation de
  l'option retenue).
- Bundle + diff bundle + G200 --report + gates palier C (VOLET A seulement).
- Contrat `TASK_CONTRACT_T361_*.yaml` (C3).
- `TASKS.yaml` + `TASK_LOCKS.json` à jour.

## 4. Contraintes non négociables

- AUCUN COMMIT sans accord explicite distinct du GO.
- VOLET B : zéro code avant validation utilisateur de l'option.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
