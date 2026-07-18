# Workflow agents CODESYS

## Flux obligatoire

```text
Demande → criticité → scope → plan → validation → modification → gates → review → rapport
```

## Règles

- `TOOLS/` reste séparé de `DOC/` et `CODE/`.
- `ST_PLCOPENXML_GENERATOR` reste autonome ; le workflow peut l'appeler.
- Les scripts déterministes vérifient avant l'avis des modèles.
- Aucun commit automatique.
- Toute modification safety exige une validation humaine.
- Ponytail est interdit dès qu'un sujet safety, norme ou redondance est détecté.

## Criticité

| Niveau | Exemple | Traitement |
|---|---|---|
| C0 | format, typo | contrôle simple |
| C1 | documentation non-safety | modèle économique + review |
| C2 | code métier | modèle code + tests |
| C3 | mouvement/interlock | modèle fort + review read-only |
| C4 | AU, PowerCutOff, redondance | plan humain obligatoire, Ponytail interdit |
