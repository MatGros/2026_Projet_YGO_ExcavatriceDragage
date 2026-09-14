# 🔎 AUDIT T171-CR — Revue indépendante de l'animation (Ollama qwen3.8:27b)

**Date** : 2026-08-28 · **Auditeur** : sous-agent Ollama `qwen3.8:27b` (modèle distinct)
**Réf** : T171-CR · **Contrat** : `TASK_CONTRACT_T171-CR_REVUE_ANIMATION_COMPILED_CODE.yaml`
**Cible** : `TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/reports/FICHE_SEMI_AUTO_ANIMATION.html`

> ⚠️ **Note d'exécution** : l'audit a nécessité 3 itérations techniques avant d'être exploitable —
> timeout 180s du runner standard, `num_predict` par défaut (~128 tokens) et `num_ctx` par défaut
> (~4k tokens) tronquaient prompt/réponse. Résolu via `ollama_query_long.py` (timeout 1800s,
> num_predict 3072, num_ctx 12288). Détail : `DOC/WFLOW/REX/REX_Harnais_StruCpp_InOut_Trace_20260828.md`.

---

## Verdict : **CONFORME**

Le code est un **pur lecteur** de la trace scan-par-scan. Aucune machine d'état, aucune
simulation cinématique, aucune décision d'étape n'est implémentée en JS. Le seul « état »
maintenu est l'index de scan (`currentScan`) et les contrôles de lecture (`playing`, `speed`).

## Findings (aucun MAJOR / BLOCK)

| # | Élément | Gravité | Justification |
|---|---------|---------|---------------|
| 1 | `TRANSITIONS` (objet statique) | INFO | Table de texte descriptif pour affichage. Aucune condition évaluée en JS — le binaire décide. |
| 2 | `STEP_NAMES` | INFO | Lookup statique numéro→libellé. Aucune logique. |
| 3 | `bucketY = 250 - (m1*20)` | INFO | Transformation linéaire mètre→pixel. `m1` provient exclusivement de la trace. Pas de vitesse/accélération/trajectoire. |
| 4 | `bridgeX` (if/else capteurs) | INFO | Lookup discret capteur→px fixe. Aucune interpolation. |
| 5 | FDC `m1 >= limitHigh` | MINOR | Booléen dérivé de 2 champs trace (affichage, pas décision de sécurité). ⚠️ Fallbacks `|| 7.0` à surveiller si la trace évolue. |
| 6 | `slack = |m1-m2| > 0.05` | MINOR | Indicateur visuel dérivé. Seuil d'affichage, pas paramètre de contrôle. |
| 7 | `angle = open ? 52 : 0` | INFO | État discret lu de la trace → angle SVG binaire. |
| 8 | `play()` / `setInterval` | INFO | Avance l'index de +1 à intervalle fixe. Aucun calcul d'état. |
| 9 | `gotoScan(i)` | INFO | Clamp + assignation d'index + render. Pur pointeur. |

## Réponses aux 3 questions

**Q1 — Machine d'état / simulation / cinématique / décision d'étape en JS ?** → **NON.**
Pas de variable d'état machine (le step est LU via `field(scan,'CYCLESTEP')`, jamais calculé),
pas de `switch(step)`, pas de calcul de vitesse/accélération/interpolation, pas de
`Math.random`, pas de timer décisionnel. `STEP_NAMES`/`TRANSITIONS` = tables de texte statique.

**Q2 — Les positions affichées dérivent-elles EXCLUSIVEMENT des champs de la trace ?** → **OUI.**
`bucketY` ← `M1_CABLEPOSM` (mapping linéaire) · `bridgeX` ← capteurs translation (lookup discret)
· `angle` ← `BENNE_ISOPEN` (binaire) · `slack` ← écart M1/M2.

**Q3 — Le scrub/Play/Pause manipule-t-il seulement un index ?** → **OUI.** `currentScan` est
clampé et incrémenté ; `render()` lit le scan courant. Aucun recalcul d'état.

## Limites de l'audit
- Audit statique du code JS (pas d'exécution navigateur).
- Les fallbacks de valeur (`|| 7.0`) en FDC sont à surveiller si la trace évolue (MINOR).

---

## ✅ Conclusion T171-CR
Certification indépendante : **zéro logique métier en JS**, animation asservie à 100% sur la
trace du binaire compilé. AC1 du contrat satisfait. Visa P5 de l'orchestrateur requis pour clôture.
