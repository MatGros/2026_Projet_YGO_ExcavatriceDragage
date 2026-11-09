# Arbitrage Final — Revue Contradictoire T429 (Reviewer B / Blue Team)

## Posture et statut épistémique

Revue **sur dossier**, en lecture seule. Aucune commande exécutée par mes soins ; les contre-exemples ci-dessous sont issus d'**analyse statique des extraits cités** dans le dossier (le regex de P1 est fourni verbatim et se prête à cette analyse). Tout verdict PASS terrain final relève du coordinateur : ré-exécution des lignes de commande et relecture du diff réel.

## 1. Matrice de satisfaction des exigences du Reviewer A

(extraits exacts / assertions citées / commandes réelles)

| Preuve | Extrait source exact | Assertion de test citée | Commande / sortie réelle |
|---|---|---|---|
| P1 — Anti-faux PASS | ✅ regex + code de test verbatim | ✅ verbatim | ✅ 43/43, 2.02 s, code 0 |
| P2 — Mémoire / drift (AC-F2.9) | ⚠️ noms de sections, sans fichier:ligne | ❌ | ⚠️ indirecte (via suite) |
| P3 — Matrice alarm (AC-F2.10) | ✅ `supervisor_service.py:325` | ❌ | ⚠️ indirecte |
| P4 — IHM déconnexion (AC-F3.10) | ⚠️ sélecteurs CSS + technique `vm.runInContext` | ⚠️ décrite, non citée | ✅ code 0 |
| P5 — Persistance | ⚠️ noms de fonctions uniquement | ❌ | ❌ |
| P6 — Suites globales | n/a | n/a | ⚠️ synthèse chiffrée, pas de transcript |

**Conclusion 1 : exigences satisfaites à ~2/3, non uniformément.** P1 et P4 atteignent le grade de preuve mécanique demandé. P3 est à moitié (extrait oui, test verrouillant manquant). P2 et P5 restent narratives.

## 2. Analyse point par point et **finding bloquant C1**

### P1 — La garde anti-faux PASS a un trou d'évasion démontrable

Le mécanisme et son principe sont corrects (négation d'abord, biais conservateur — le cas du dossier « NON PASS : contrôle en échec. » est bien bloqué via `\bnon\b`, et un run pytest réellement échoué du type `1 failed, 5 passed` est bloqué via `\bfailed\b`). **Mais** les ancres `\b...\b` singulières laissent passer les pluriels et accords :

| Entrée outil | Comportement de la garde | Résultat |
|---|---|---|
| `12 échecs, 0 passed` | `\béchec\b` ne matche pas « échec**s** » (frontière impossible avant « s ») ; négation inactive → `\d+\s+passed` capture **« 0 passed »** | **Faux PASS** sur un run 100 % échec |
| `118 passed, 2 errors` | `\berror\b` ne matche pas « error**s** » ; « errors » n'est pas dans la liste | **Faux PASS** (sortie pytest réaliste) |
| `Opération interrompue : 5 passed` | `\binterrompu\b` ne matche ni « interrompue » ni « interrompus » | **Faux PASS** |
| `échecs : 3, 12 passed` | `\béchec\b` et `\berreur\b` évités au pluriel | **Faux PASS** |

Cela n'est **pas détecté par les 43 tests verts** car le vocabulaire adversaire des tests est au singulier — c'est un trou de couverture, pas un bug de logique.

**Atténuation crédible à porter au dossier :** les preuves acquises sont réinjectées au juge (`PREUVES ACQUISES` + `AUDIT DE TRAJECTOIRE`) → défense en profondeur qui réduit la sévérité réelle. Mais la finalité même d'AC-F2.8 est d'empêcher la promotion d'un échec ; le trou la contourne sur des formulations plausibles. Correctif trivial (énumérer les formes fléchies : `erreurs?|échecs?|echecs?|errors?|fail(?:ures|ed)|interrompues?`) + 3 tests négatifs adversaires ci-dessus, coût < 1 h → **condition C1, bloquante avant signature**.

### P2 (AC-F2.9) — Crédible, non mécaniquement prouvé
Sections nommées, `validate_state_update` appelé avant persistance : cohérent. Cohérence croisée positive **P2↔P5** : `judge_turn_count` persisté → le modulo 8 survit au restart. Manque : citation d'un test négatif d'assertion (injection d'un `state_update` fabriqué → rejet). Non bloquant, à tracer.

### P3 (AC-F2.10) — Extrait à la ligne, verrou de test absent
Le ternaire à `:325` établit alarm→error inconditionnel. **Aucune assertion citée** prouvant alarm+category 'other'→error. Effet de bord non audité : l'élargissement peut accroître le volume d'alertes (bruit) — à surveiller en métriques, pas bloquant. Réserve C2 : citer le test verrouillant, ou le coordinateur le vérifie à la relecture du diff.

### P4 (AC-F3.10) — Au grade, avec frontière à documenter
`vm.runInContext` prouve la **logique JS** (assertion `hidden == false` pertinente), pas le rendu réel — atténué par `ui_layout_check.mjs` à 3 viewports. Micro-réserves : contraste WCAG du fond `#381d22` non évalué. Non bloquant.

### P5 — Persistance affirmée, pas démontrée
Fonctions et champs nommés sans excerpt ni test round-trip cité. Risque non traité : `_persist` sans écriture atomique → corruption du JSON en cas de crash en cours d'écriture, comportement de `_load` à la reprise inconnu. Réserve C3 : citer le test round-trip ou tracer la dette + note d'atomicité.

### P6 — Corroborant, cohérent en interne
43 ⊂ 171, 26 tests juge, findings 16+1=17 avec 0 open : chiffres mutuellement cohérents, mais sans transcript brut. Le PASS terrain se ferme par ré-exécution par le coordinateur.

## 3. Classement des risques résiduels

- **Bloquant avant signature (C1)** : évasion pluriel/accord de la garde anti-faux PASS — démontrée statiquement sur l'extrait fourni.
- **Réserves tracées (C2, C3)** : assertion manquante verrouillant AC-F2.10 ; round-trip persistance + atomicité d'écriture.
- **Micro (optionnel)** : entrée Unicode NFD évade « échec/erreur » (accent décomposé) ; contraste a11y du bandeau ; DOM simulé ≠ navigateur.

## 4. Verdict d'arbitrage

1. **Les exigences du Reviewer A sont-elles satisfaites ?** Oui dans leur objet (le matériel réclamé existe désormais et son noyau — P1, P4 — est au grade mécanique), non dans leur uniformité (P2/P5 narratives, P3 sans test cité).
2. **Faiblesse résiduelle bloquante ?** Une seule, C1, démontrée par contre-exemples statiques ; elle contredit la finalité d'AC-F2.8 mais est corrigible en < 1 h. Aucun autre risque bloquant identifié.
3. **Verdict : LEVÉE DU HOLD JUSTIFIÉE — qualification GO conditionnelle.**
   - Le HOLD (matériel manquant) est levé : le dossier y répond.
   - **Condition bloquante C1** avant signature de livraison : durcissement du regex + les 3 tests négatifs adversaires (`12 échecs, 0 passed`, `118 passed, 2 errors`, `interrompue : 5 passed`).
   - **C2/C3 en réserves tracées** (tickets), non bloquantes.
   - **PASS terrain final** = coordinateur : ré-exécution des deux lignes de commande (pytest, node), relecture du diff réel incluant le correctif C1, puis arbitrage.

Décision recommandée au coordinateur, qui reste seul décisionnaire. Ce reviewer n'a modifié aucun artefact.