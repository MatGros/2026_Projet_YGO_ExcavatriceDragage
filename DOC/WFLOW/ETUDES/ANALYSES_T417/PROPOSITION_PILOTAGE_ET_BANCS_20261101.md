# T417 — proposition de pilotage et de comparaison des bancs

Statut : proposition, 2026-11-01. Étude A/B indépendante demandée par l'utilisateur. Aucun essai runtime lancé pour cette étude. Pas de modification automate ou de hook actif.

## Objectif conservé

Obtenir une simulation exploitable du parcours P1 → AX14 → AX15A → AX15B ↔ AX15C → AX18 → AX2 → P1, commandée depuis les entrées opérateur, avec observation des actionneurs et positions. Les dépassements déjà connus ne constituent plus une investigation prioritaire.

## Constats contrôlés

- `runtime.py` R42, lignes 130–148 : 14 POU injectées puis rebuild. PRG05/06, DUT et GVL ne sont pas synchronisés par cette liste. Rebuild réussi ne prouve pas l'identité complète avec CODE actuel.
- R42 : latence preset forcée, heartbeat forcé, bypass hauteur et essai verrou descente désactivé. Ces substitutions limitent la validation nominale.
- `run_t417_m3_integrated.py:19` compose des FB réels, mais ne compile pas l'assemblage réel des PRG02–07. Les faits M1/M2, benne et autorisations pilotés par le banc limitent la couverture.
- R43 préparé mais non exécuté : réussite signalée par exception et variable `input_button` locale à `probe_button`. Revue nécessaire avant utilisation. La vérification syntaxique seule était insuffisante.
- TASKS.yaml décrit encore un checkpoint du 30/10 ; contrat principal COMPLETED et investigation AWAITING_D_APPROVAL coexistent. Le pilotage ne présente pas un état courant univoque.

## Décision proposée

Deux agents plateforme, A et B, ont travaillé avec un contexte neuf et le même contrat, sans accès aux conclusions de l'autre. Ils convergent sur la synchronisation partielle des 14 POU, les substitutions R42 et l'absence des vraies PRG dans le harnais CI actuel. Ce sont des lectures de sources, pas des benchmarks exécutés. A privilégie d'abord l'identité IDE ; B ajoute un test de sensibilité par rupture temporaire d'un lien pour vérifier que le banc détecte effectivement une erreur d'assemblage. L'orchestrateur a contrôlé la liste d'injection et les substitutions du runner ainsi que la liste des composants CI. Aucun agent Claude/AGY n'a été lancé pour cette étude.

Conserver CODESYS comme référence d'intégration après preuve d'identité ; utiliser la CI ST pour itération rapide seulement sur couverture déclarée. Tester la faisabilité d'un assemblage des vraies PRG sans annoncer par avance son équivalence. Aucun chiffre de gain de temps n'est établi.

## Trois travaux parallèles, un seul propriétaire du runtime

| Travail | Résultat attendu | Critère vérifiable |
|---|---|---|
| Identité IDE | Inventaire sources/projet, ordre de tâches, substitutions | Toute source exécutée identifiée ; écart ou source inconnue signalés avant verdict |
| Faisabilité CI des PRG | Compilation des vraies PRG et dépendances, inventaire frontières non portables | Aucun recodage métier caché ; chaque remplacement déclaré ; échec localisé |
| Scénario commun | Entrées opérateur et sorties normalisées identiques sur les deux bancs | Même état initial/configuration, mêmes événements ; transitions, défauts, autorisations et sorties comparés |

Mesurer séparément temps humain de préparation, compilation, exécution, analyse et nettoyage. Ne pas convertir une estimation en benchmark. Commencer par autorisation/refus de départ et arrêt au relâchement ; étendre ensuite au parcours et à AX15C après clarification métier.

## Amélioration ciblée du workflow existant

1. Une fiche active au début du plan existant : besoin utilisateur, périmètre, acquis, inconnues bloquantes, trois prochaines décisions. Les journaux historiques restent en dessous.
2. Chaque expérience indique avant lancement : question nouvelle, prédiction, observation discriminante, décision selon résultat, coût borné, sources/configuration, substitutions, nettoyage.
3. Un résultat déjà connu n'est rejoué que pour une source/configuration modifiée, une preuve manquante ou une régression finale. Raison explicite requise.
4. Après deux expériences non discriminantes : challenger indépendant sur la question et la mesure avant nouvel essai équivalent.
5. Chaque délégation reçoit besoin utilisateur, historique utile, sources exactes, contrat de sortie, limites et inconnues. L'agent reformule le but et signale les données manquantes avant une action qui en dépend.
6. Clarification utilisateur seulement pour une donnée métier réellement manquante après consultation des sources ; pas d'exigence de certitude absolue sur toute tâche.

## Garde-fous proposés, non installés

- Contrôle du contrat d'expérience avant lancement d'un banc long : champs vérifiables, identifiant unique, manifeste sources, nettoyage obligatoire.
- Échec build ou identité inconnue : aucune qualification de résultat comme validation des sources courantes.
- Résultat immuable par run ; aucune copie d'anciens journaux présentée comme nouvelle preuve.
- Avertissement sur répétition sans nouveau discriminant ; revue obligatoire après deux essais équivalents non informatifs.
- Contrôle de livraison : un verdict par critère, lien vers preuve, exclusions explicites. Un hook ne peut pas certifier la pertinence technique d'une lecture ou remplacer la revue humaine/agent.

Adapter les skills canoniques orchestrator/troubleshooting et le runner commun, sans créer une méthode parallèle ni imposer tous ces contrôles aux tâches documentaires ordinaires. Mesures de succès : zéro relance sans décision nouvelle ; zéro succès attribué à des sources inconnues ; chaque critère ouvert possède prochaine action et preuve attendue.
