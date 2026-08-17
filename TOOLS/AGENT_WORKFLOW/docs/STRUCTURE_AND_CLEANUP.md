# Structure, nommage et nettoyage

## 1. Dossiers projet autorisés

### `DOC/`

La documentation active de la machine reste à la racine de `DOC/`.

```text
DOC/
├─ AF_Partie-*.md
├─ PLAN_TASK_vX.Y.md
├─ VERSION_HISTORY.md
├─ AUDIT_*.md
├─ CHECKLIST_*.md
├─ NAMING_CONVENTION.md
└─ journaux métier validés
```

❌ Ne pas créer de sous-dossier dans `DOC/` sans décision explicite.

Les versions remplacées vont dans :

```text
ARCHIVES/Doc/
```

### `TOOLS/AGENT_WORKFLOW/`

```text
TOOLS/AGENT_WORKFLOW/
├─ README.md
├─ package.json
├─ docs/
├─ templates/
├─ skills/
├─ prompts/
├─ scripts/
├─ schemas/
├─ config/
├─ tasks/
└─ reports/
```

`reports/` contient uniquement les sorties temporaires du workflow — **dossier optionnel, non créé
tant qu'un script n'y écrit rien** ; ne pas le créer vide « au cas où ».

📌 `extensions/` retiré le 2026-08-17 : c'était le dossier des extensions Pi Coding Agent
(`.pi/agent/extensions/*.ts`, ex. `sound-notifier.ts`), workflow abandonné. Aucune extension
`.ts` n'a de rôle dans ce projet — ne pas recréer ce dossier.

### Outil existant

`TOOLS/ST_PLCOPENXML_GENERATOR/` est autonome et possède sa propre structure. Ne pas mélanger
ses modules dans `AGENT_WORKFLOW/`.

## 2. Nommage des fichiers

### Documentation machine

| Type | Format |
|---|---|
| Analyse fonctionnelle | `AF_Partie-XX_Nom_vX.Y.md` |
| Plan | `PLAN_TASK_vX.Y.md` |
| Historique | `VERSION_HISTORY.md` |
| Audit | `AUDIT_Nom_vX.Y.md` |
| Checklist | `CHECKLIST_MiseEnService_Nom_vX.Y.md` |
| Journal | `Nom_Journal_Modifications.md` |

- PascalCase ou nom métier explicite selon la convention existante.
- Version dans le nom pour les documents versionnés.
- Pas de noms vagues : `notes.md`, `final.md`, `new.md`, `temp.md`.

### Workflow

- Documentation : `UPPER_SNAKE_CASE.md`.
- Skills : dossier kebab-case + `SKILL.md`.
- Prompts : nom court kebab-case `.md`.
- Scripts : gates numérotés `GNNN_check_nom.py`, autres `snake_case.py`.
- Schémas : nom métier `.schema.json`.

## 3. Suppression et nettoyage

### Document actif

Ne jamais supprimer directement un document actif si son contenu a une valeur historique :

```text
ancienne version → ARCHIVES/Doc/ → nouvelle version dans DOC/
```

### Fichier obsolète

Avant suppression :

1. rechercher les références ;
2. vérifier qu'il n'est plus appelé ;
3. vérifier l'absence d'impact CODESYS ;
4. archiver si utile ;
5. documenter la raison ;
6. supprimer uniquement après validation.

### Fichier temporaire

- sortie générée : `AGENT_WORKFLOW/reports/` ou dossier temporaire explicite ;
- aucun fichier temporaire à la racine du projet ;
- supprimer les rapports après exploitation, sauf preuve utile ;
- ne jamais supprimer `CODE_Bundle.xml` ou export CODESYS sans validation.

### Dossier inattendu

Tout nouveau dossier doit avoir :

- une responsabilité unique ;
- un `README.md` si c'est un outil ;
- une entrée dans la documentation d'architecture ;
- une validation avant création.
