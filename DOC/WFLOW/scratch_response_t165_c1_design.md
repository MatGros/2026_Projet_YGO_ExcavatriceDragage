## Audit T165-C1 — Verdict formel

**⚠️ MAJOR détecté → BLOCK (conditionnel)** — voir §2.

---

### ✅ Points conformes

| Point | Vérification | Statut |
|---|---|---|
| Nommage DUTs | `E_ProgramSequence`, `ST_*` — conformes NC-050/060/070 (préfixes E_/ST_, PascalCase) | ✅ |
| `ST_ModesCycleInterPrg` | Abréviation `InterPrg` non standard (NC-100) — mais contractuelle (voir contrat inter-PRG) → tolérée | ✅ sous réserve |
| Absence Safety | `ReqProgram` ne contient **aucun** champ Safety/PowerCutOff/Permit — uniquement demandes de mouvement (winch, translation, bucket) | ✅ |
| Encapsulation | `instCycleSemiAuto` non exposée — publication via `Data` uniquement | ✅ |
| Neutralisation hors SEMI_AUTO | ELSE met tout à FALSE/0/NONE — cohérent, pas de fuite d'état | ✅ |
| Publication `Auth` | `Data.Auth := instModes.Auth` — sortie existante de FB_Modes, conforme | ✅ |

---

### ⚠️ Points bloquants / à corriger

1. **`SequenceId := MAIN_CYCLE` forcé** (ligne IF SEMI_AUTO)  
   → **MAJOR** : la séquence réelle peut être `DIVE_SEARCH` ou `EXTRACTION`. Forcer `MAIN_CYCLE` publie un **état faux** → fausse les consommateurs (PRG_04/05).  
   → **Correction** : publier `instCycleSemiAuto.SequenceId` s'il existe, sinon ajouter une sortie dédiée. **Ne pas inventer de valeur**.

2. **Ordre d'évaluation non vérifié**  
   Le bloc de publication doit être **après** l'appel de `instCycleSemiAuto` dans le même POU. Sans le code réel, je ne peux pas valider.  
   → **Vérification obligatoire** : localiser l'appel de `instCycleSemiAuto` et le bloc de publication — l'ordre ST est séquentiel, le bloc doit être en fin de POU.

3. **Types supposés non confirmés**  
   `E_OperatorAxis`, `E_CycleStep`, `ST_Lifecycle`, `ST_Fault`, `ST_fbModes_Autorisations` — existence non prouvée dans le référentiel.  
   → **Action** : `grep` dans `CODE/` avant création. Si manquant → BLOCK, ne pas créer.

4. **Copie inconditionnelle de `Lifecycle`/`Fault`**  
   En mode MANUEL, `instCycleSemiAuto` peut être en état résiduel. La publication devrait être conditionnée à `Auth.Mode = SEMI_AUTO` pour ces champs, sinon risque d'état fantôme.  
   → **Correction suggérée** : déplacer la copie `Lifecycle`/`Fault`/etc. dans le bloc IF, ou initialiser à neutre en ELSE.

---

### 📌 Recommandations

- **Corriger le forçage `MAIN_CYCLE`** → publier la valeur réelle.
- **Déplacer la copie `SequenceState.*` dans le IF SEMI_AUTO** (cohérent avec la neutralisation ELSE).
- **Vérifier les types** avant écriture (grep).
- **Confirmer l'ordre d'appel** dans le POU (lecture du fichier réel).

---

### Verdict formel

> **BLOCK** — 1 MAJOR (SequenceId forcé) + 2 à vérifier (ordre, types).  
> Après correction, re-audit rapide pour PASS.  
> Aucun commit — validation humaine obligatoire.

**Prochaine étape** : je peux auditer le code réel de `PRG_03_Modes_Cycle.st` si tu me le fournis, pour lever les points 2 et 3.