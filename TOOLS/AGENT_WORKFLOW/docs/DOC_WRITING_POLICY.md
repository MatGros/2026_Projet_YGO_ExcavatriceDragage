# Politique de rédaction documentaire

## 1. But

Fournir à l'agent les règles de construction des documents `DOC/` sans lui imposer de relire toute la documentation. Le document cible, sa classe et les sections impactées restent le contexte minimal.

## 2. Classes de documents

| Classe | Fichiers | Priorité rédaction |
|---|---|---|
| Spécification fonctionnelle | `AF_Partie-*.md` | précision technique complète |
| Pilotage | `PLAN_TASK`, `VERSION_HISTORY`, audit | concis, direct, tableaux |
| Validation | `CHECKLIST_*.md`, tests | procédure et critères vérifiables |
| Interface IHM | `AF_Partie-07`, structures HMI | contrat, mapping, états, diagnostics |
| Outil | `TOOLS/*/README.md`, `TOOLS/*/docs/` | rôle, usage, architecture, tests, limites |

## 3. Règles communes

La structure, le nommage des fichiers et le nettoyage sont définis dans
`STRUCTURE_AND_CLEANUP.md`. Aucun agent ne crée de dossier ou de fichier temporaire hors des
emplacements autorisés.

- 🇫🇷 Écrire en français sauf terme technique, nom de variable ou citation.
- 🎯 Utiliser des titres explicites et des listes/tableaux courts.
- 🏷️ Respecter le nom de fichier et la version active `vX.Y`.
- 📅 Tracer date, source, auteur/décideur et raison du changement.
- 🔗 Référencer les fichiers `CODE/`, `DOC/` et tests concernés.
- 🚫 Ne jamais recopier le corps ST dans `DOC/`.
- ⚠️ Séparer clairement : fait, hypothèse, décision, TBD, action restante.
- 🗃️ Ne jamais utiliser `ARCHIVES/Doc/` comme référence active.
- 🧹 Ne jamais supprimer directement une version documentaire utile ; archiver puis versionner.
- 🔒 Une modification safety/norme exige une validation humaine.

## 4. Spécifications fonctionnelles `AF_Partie-*`

Structure recommandée :

```text
Titre + version
Historique des versions récentes
Dépendances / documents liés
Objectif et périmètre
Architecture / pipeline
Interface et données
Sécurité et interlocks
Mapping E/S ou IHM
Implémentation : référence CODE uniquement
Note d'application CODESYS si nécessaire
État / REX / suivi
Documents liés
```

Style : technique, complet, sans supprimer une information métier utile pour raccourcir.
Les emojis servent de repères visuels, pas de décoration.

## 5. Documents de pilotage

`PLAN_TASK`, `VERSION_HISTORY` et les audits utilisent :

- lignes courtes ;
- tableaux ;
- statuts `✅`, `🟠`, `❌`, `TBD` ;
- une action et un responsable quand connus ;
- aucun corps de spécification dupliqué.

## 6. Checklists

Une checklist contient au minimum :

```text
Rôle / objectif
Date et version
Périmètre
Hors périmètre
Sources auditées
Prérequis
Table des vérifications
Valeur attendue / critère Pass-Fail
Résultat / commentaire / signature
```

## 7. Nouvelle information utilisateur

Une information orale ou terrain n'est jamais transformée directement en exigence ou en code.
L'agent doit d'abord produire :

```text
Information brute
Questions de clarification
Réponses connues
Inconnues / TBD
Impact DOC/CODE/IHM/tests
Décision attendue
Action restante
```

## 8. Processus d'édition

```text
Classer → cibler → poser les questions → proposer → valider → versionner → référencer
```

L'agent peut détecter et proposer une mise à jour. Il ne modifie pas silencieusement une
spécification validée.
