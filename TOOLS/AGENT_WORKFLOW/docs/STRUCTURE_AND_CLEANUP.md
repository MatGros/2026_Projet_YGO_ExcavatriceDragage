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

📌 `extensions/` retiré le 2026-08-17 : c'était le dossier des extensions de l'ancien
environnement de sous-agents (`.pi/agent/extensions/*.ts`, ex. `sound-notifier.ts`), workflow
abandonné. Aucune extension
`.ts` n'a de rôle dans ce projet — ne pas recréer ce dossier.

### Outil existant

`TOOLS/CONVERTER_ST2XML_PLCopenXML/` est autonome et possède sa propre structure. Ne pas mélanger
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

> Norme T279 : **classer toute sortie avant de l'écrire**. Un chemin non prévu
> par cette table est interdit, il ne doit jamais être masqué par `.gitignore`.

| Catégorie | Emplacement obligatoire | Git | Durée de vie |
|---|---|---|---|
| Bundle PLCopenXML | `CODE_XML/CODE_Bundle.xml` | versionné | livrable durable |
| Contrat, audit, REX, diagnostic, rapport d'orchestration | sous-dossier métier de `DOC/WFLOW/` | versionné | preuve durable |
| Résultat CI publiable | `TOOLS/TEST_AUTO_CI/RESULTS/<DOMAINE>/reports/` | selon politique CI | régénérable / preuve |
| État de session agent | `TOOLS/AGENT_WORKFLOW/status/` | local, ignoré pour les nouvelles sorties | session ; historique régularisé en phase 4 T279 |
| Scratch CI | `TOOLS/TEST_AUTO_CI/.tmp_<run>/` | ignoré | fin du run |
| Scratch gate | `TOOLS/AGENT_WORKFLOW/.tmp/<run>/` | ignoré | fin du gate |
| Scratch racine | interdit | **non ignoré, visible** | n/a |

- Il est interdit de créer, déplacer ou rediriger un scratch agent, CI ou gate vers la racine du dépôt.
- `TEMP` et `TMP` peuvent être redéfinis seulement par un runner, vers son scratch autorisé ou vers le temp système hors dépôt ; jamais vers la racine.
- Avant et après tout test ou gate, exécuter `git status --short`, signaler tout chemin nouveau hors table et ne pas l'ignorer pour masquer l'écart.
- `G390_check_bundle_freshness.py` conserve son scratch sous `TOOLS/AGENT_WORKFLOW/.tmp/g390_freshness_<id>/` ; il n'existe plus d'exemption `CODE_XML.freshness/` à la racine.
- **Aucune suppression automatique** par script, agent, gate ou runner : un outil détecte, localise et informe ; seul l'humain décide et réalise le nettoyage. Les rapports et scratchs restent donc présents dans leur emplacement autorisé jusqu'à intervention humaine.
- Aucun fichier temporaire à la racine du projet ; ne jamais supprimer `CODE_Bundle.xml` ou export CODESYS sans validation.

### Dossier inattendu

Tout nouveau dossier doit avoir :

- une responsabilité unique ;
- un `README.md` si c'est un outil ;
- une entrée dans la documentation d'architecture ;
- une validation avant création.
