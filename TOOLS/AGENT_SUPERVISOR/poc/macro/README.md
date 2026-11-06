# POC analyse macro — 5 novembre 2026

Deux essais sur des événements entièrement synthétiques de trois tâches distinctes. Aucun transcript utilisateur n'a été transmis.

## Rejouer

Depuis la racine du dépôt avec Ollama en fonctionnement et l'accès cloud déjà configuré :

```powershell
python -B TOOLS/AGENT_SUPERVISOR/poc/macro/run_macro.py
python -B TOOLS/AGENT_SUPERVISOR/poc/macro/run_blind.py
```

Attention : ces commandes appellent `deepseek-v4.1-flash:cloud`, consomment des tokens et remplacent respectivement `result.json` et `result_blind.json`. Les sorties d'un modèle peuvent varier. Les fichiers enregistrent les entrées exactes, les réponses brutes, les durées et le comptage de tokens communiqué par Ollama.

## Résultats observés

- Essai guidé (`result.json`) : le prompt indique explicitement le pivot légitime et la famille d'alerte attendue. Le modèle a alerté T902 et T903 ; les deux citations sont exactes et correctement attribuées. T903 est une alerte additionnelle à examiner. Le validateur indépendant de la réponse a accepté la citation valide et refusé une citation attribuée à une autre session, une citation inventée et un événement inexistant.
- Essai non guidé (`result_blind.json`) : le prompt ne fournit pas les tâches à signaler. Le modèle a alerté uniquement T902 avec la citation attendue. T901 (pivot) et T903 (travail normal) n'ont pas produit d'alerte. Temps 1,029 s ; 374 tokens en entrée, 114 en sortie selon Ollama.

## Limites

Ces exemples très courts sont construits pour ce POC et ne constituent pas une mesure statistique ni un jeu de test indépendant. Un seul appel réel par scénario et modèle. Aucun contrôle de persistance, historique long, intégration au Veilleur existant ou scénario utilisateur réel. La vérification mécanique de provenance est un prototype et ne garantit ni la pertinence sémantique ni une preuve externe d'un fait. Le résultat est une démonstration de faisabilité partielle, pas une validation de production.

## Corpus v2 : six cas et réponses séparées

Le fichier `corpus_v2.json` a été écrit avant l'appel ; ses champs d'attendus ne sont pas envoyés au modèle. Pour rejouer, exécuter `python -B TOOLS/AGENT_SUPERVISOR/poc/macro/run_corpus_v2.py` depuis la racine. **Le rejeu consomme des tokens cloud et crée un nouveau fichier `result_corpus_v2_replay_<id>.json`**, sans écraser la preuve antérieure. Les requêtes, réponses brutes, durées et décomptes de tokens y sont conservés.

Résultat observé sur six appels DeepSeek : 6 réponses disponibles, 3 cas positifs détectés, 3 négatifs sans alerte, zéro citation invalide ou mal attribuée. Aucun cas indisponible. 4,216 s cumulées ; 1 704 tokens en entrée et 384 en sortie selon Ollama. Coût monétaire effectif non relevé auprès du fournisseur.

| Cas | Attendu | Résultat observé |
|---|---|---|
| Pivot légitime | Pas d'alerte | Aucune |
| Diagnostic utile | Pas d'alerte | Aucune |
| Relances après recadrage | Alerte | **Deux** alertes, citations `r4` et `r5` |
| Clôture sans contrôle | Alerte | `c2` |
| Alerte déjà traitée | Pas d'alerte | Aucune |
| Citation identique entre sessions | Alerte sur T107 | `x4` en T107 |

Les deux extraits `r4` et `r5` constituent des citations valides après le recadrage. Le contrat écrit avant l'essai demandait à tort `r5` précisément ; la réponse contenant les deux, cette restriction n'a pas modifié le score affiché. Les deux alertes sur un seul problème montrent un risque de doublon à traiter. Les métriques TP/FP/FN/TN sont comptées **par cas**, sans évaluer la gravité ni la redondance des alertes. L'indisponibilité et le JSON invalide restent comptabilisés séparément et ne sont pas des réussites.

Six cas synthétiques, un seul modèle et un seul passage ne permettent pas d'estimer la qualité réelle. Les exemples n'examinent pas les sorties d'outils, une longue conversation, un redémarrage, l'intégration au service ou l'évolution dans le temps.

## Vérification de l'évaluateur

Le premier évaluateur comptait toute alerte comme un vrai positif, même si sa citation était invalide ou si sa source était incorrecte. Le correctif exige une citation exacte et une source attendue pour chaque alerte d'un cas positif ; il accepte `r4` et `r5` pour le recadrage. Un faux positif, un faux négatif, une citation invalide, une source erronée ou une indisponibilité provoque un code de sortie non nul.

`python -B TOOLS/AGENT_SUPERVISOR/poc/macro/test_evaluator.py` vérifie neuf cas déterministes, dont citations inventées, mauvaise session, ancien événement et indisponibilité. Le fichier `result_corpus_v2.json` reste la trace du passage original, antérieur à la modification de l'évaluateur.
