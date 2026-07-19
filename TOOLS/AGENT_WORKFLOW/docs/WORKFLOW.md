# Workflow agents CODESYS

## Flux obligatoire

```text
Entrée (CODE_CHANGE ou NEW_INFORMATION)
→ criticité → refinement/scope → plan → validation
→ modification → gates → review → rapport → traçabilité
```

## Règles

- `TOOLS/` reste séparé de `DOC/` et `CODE/`.
- `ST_PLCOPENXML_GENERATOR` reste autonome ; le workflow peut l'appeler.
- Les scripts déterministes vérifient avant l'avis des modèles.
- Aucun commit automatique.
- Toute modification safety exige une validation humaine.
- Ponytail est interdit dès qu'un sujet safety, norme ou redondance est détecté.

## 🔄 Règle d'apprentissage continu (Double boucle)

Toute erreur détectée — **à n'importe quelle étape** (édition, gate, compilation, test, audit, terrain) — déclenche **deux actions** :

1. **`fix:`** — Correction locale de l'erreur (code, doc, config)
2. **`guard:`** — Garde-fou technique ajouté dans `TOOLS/AGENT_WORKFLOW/scripts/` ou templates pour que **cette classe d'erreur soit détectée automatiquement plus tôt** la prochaine fois

### Exemples de correspondance

| Origine erreur | Garde-fou ajouté |
|---|---|
| Compilation CODESYS C0037 | Règle `check_code_style` détection écriture VAR_OUTPUT |
| Oubli homme-mort boutons | Pattern `StartStop.*DeadmanArmed` obligatoire |
| FDC sans rampe | Template `motion_fb_header` section FDC_EXTRÊMES |
| Bit safety non classifié | Template `requirement_intake` champ `safetyClassification` |
| Struct IHM incomplète | Script `doc_sync` compare AF07 ↔ CODE/SUPERVISION |

### Processus

```text
Erreur détectée
    ↓
Analyse cause racine (5 pourquoi)
    ↓
fix: correction immédiate
guard: gate/template/script ajouté dans TOOLS/
    ↓
Validation : gate suivant attrape la régression
    ↓
Commit unique : fix + guard ensemble
```

## Entrées

- `CODE_CHANGE` : modification issue du programme ou d'un bug identifié.
- `NEW_INFORMATION` : donnée client, réunion, chantier, essai ou observation terrain.

`NEW_INFORMATION` passe obligatoirement par le refinement avant toute modification DOC/CODE.

## Criticité

| Niveau | Exemple | Traitement |
|---|---|---|
| C0 | format, typo | contrôle simple |
| C1 | documentation non-safety | modèle économique + review |
| C2 | code métier | modèle code + tests |
| C3 | mouvement/interlock | modèle fort + review read-only |
| C4 | AU, PowerCutOff, redondance | plan humain obligatoire, Ponytail interdit |
