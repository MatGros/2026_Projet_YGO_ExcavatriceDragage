# 🕵️ Session de Troubleshooting — Recherche de Blocage et de Panne — <Sujet>

> 📅 Date : <AAAA-MM-JJ> · 🧊 Situation : [SIMULATION BANC] / [SITE] · 📄 Statut : [OUVERTE] / [EN COURS] / [RÉSOLUE]

## 1. 🧊 Contexte figé (horodaté)

> Snapshot horodaté. **Re-figer** si > X min ou événement (redémarrage, changement de mode) avant de conclure.
> Toute valeur non listée = **à vérifier** (ne pas supposer).

### Texte de contexte
<...>

### Variables & valeurs
| <nobr>Élément</nobr> | <nobr>Variable complète</nobr> | Valeur | <nobr>Horodatage</nobr> |
|---|---|---|---|
| ... | ... | ... | ... |

## 2. 🎯 Symptôme

<1 phrase : quoi, où, depuis quand, permanent/intermittent>

## 3. 🧩 Indices / historique

- Derniers changements : ...
- Déjà essayé : ...
- Conditions d'apparition : ...
- Alarmes : ...

## 4. 🌳 Arbre des causes & hypothèses

> Liste **EXHAUSTIVE** (ne rien oublier). Chaque « valeur attendue » doit avoir une **SOURCE** (spec `AF_Partie-XX`, code `.st`, logique) — sinon « attente non justifiée ».

| # | <nobr>Hypothèse</nobr> | <nobr>Variable de décision</nobr> | <nobr>Valeur attendue (source)</nobr> | <nobr>Valeur lue</nobr> | Verdict |
|---|---|---|---|---|---|
| 1 | ... | ... | ... (AF_Partie-XX §Y) | ... | ❌ / ✅ |

## 5. 📊 Arbre vertical des hypothèses (flux de données) — OBLIGATOIRE

> Chaque branche = hypothèse, parcourue verticalement. Nœud = signal + type + valeur.
> Émojis : ✅ attendu · ❌ blocage · ❓ ambigu (investigation obligatoire).
> **+ résumé compact une ligne** en bas.

```text
<arbre vertical>
```

**Résumé une ligne** : `[A:BOOL=1] → [B:INT=0] → [C:BOOL=1] ❌`

## 6. 📊 Données / interactions & chronogramme (🟡)

> Lectures, essais, résultats. Chronogramme = séquences **observées/rapportées** (🟡), jamais présenté comme acquisition.

### Lectures & essais
- <lecture/essai> : <résultat>

### Chronogramme (tableau vertical — événements × signaux)
| <nobr>Événement</nobr> | <nobr>Signal 1</nobr> | <nobr>Signal 2</nobr> | <nobr>Signal 3</nobr> |
|:---:|:---:|:---:|:---:|
| T1 | █ | █ | 12.5 |
| → <tempo> | | | |
| T2 | █ |   | 12.0 |

## 7. 🏁 Conclusion

- **Cause racine** : ...
- **Statut** : RÉSOLUE / à valider

## 8. 🛠️ Proposition de correction

> À remplir **plus tard**, une fois la cause racine confirmée.

- **Option 1 (immédiat, sans code)** : <action> — <impact/risque>
- **Option 2 (définitif)** : <action> — <impact/risque>
- **⚠️ Validation requise** : [humaine] — ne pas modifier le code / forcer une variable sans validation

## 9. ✅ Vérification de la correction / non-régression

- <test de non-régression après correction : le symptôme est-il résolu ? rien d'autre cassé ?>

## 10. 📝 Journal (chronologique)

- <AAAA-MM-JJ> : <action / observation>

---

📖 **Documentation complète** (comment remplir chaque section, exemples) : `GUIDE_Troubleshooting.md` (même dossier).
