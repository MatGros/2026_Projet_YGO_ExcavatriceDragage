# 🔬 REX — Choix du modèle pour l’orchestration projet

**Date** : 2026-09-22  
**Auteur / Réf** : Retour exploitant · orchestration projet  
**Statut** : 🟠 En cours d’analyse  
**Criticité** : C1 (pilotage, qualité et délai)

## 1. Problème & symptômes observés

Retour explicite de l’exploitant : l’utilisation d’un agent **GPT‑5.6 Luna / Terra / Sol** comme orchestrateur a fait perdre beaucoup de temps et d’argent.

Symptômes constatés :

- suivi des tâches insuffisant ou non maintenu ;
- difficulté à piloter deux sujets en parallèle sans mélange ni perte d’état ;
- dérive documentaire et reprises inutiles ;
- absence de restitution courte et fiable de l’état des tâches ;
- besoin de répéter plusieurs fois les décisions déjà données.

## 2. Décision d’orchestration

Pour les prochaines tâches de pilotage, privilégier un agent **Claude Sonnet 5** comme orchestrateur principal, sous réserve de disponibilité et de validation humaine.

Le rôle de l’orchestrateur reste obligatoire : registre des tâches, propriétaire, priorité, dépendances, état et prochaine action.

## 3. Action à réaliser

Tester **DeepSeek V4.1** comme agent spécialisé, séparément de l’orchestrateur, sur une tâche bornée et réversible :

1. fournir un contrat court et un contexte projet minimal ;
2. lui faire produire un audit ou un second avis, sans écriture directe dans `CODE/` ;
3. mesurer fidélité au contexte, respect des consignes, suivi des décisions et qualité du rapport ;
4. comparer le résultat à Claude Sonnet 5 ;
5. décider si DeepSeek est adapté au diagnostic, à la revue ou à une autre fonction limitée.

## 4. Garde-fous obligatoires

- un seul orchestrateur identifié par session ;
- une tâche = un propriétaire = un état dans `TASKS.yaml` ;
- aucun agent spécialisé ne modifie le code sans contrat et validation ;
- restitution courte à chaque changement d’état ;
- séparation stricte entre sujets parallèles ;
- revue humaine avant toute décision de production.

## 5. Statut

⚠️ Ce REX documente un retour d’expérience et une préférence de pilotage. Il ne constitue pas encore une validation comparative des modèles. Le test DeepSeek V4.1 reste ouvert.
