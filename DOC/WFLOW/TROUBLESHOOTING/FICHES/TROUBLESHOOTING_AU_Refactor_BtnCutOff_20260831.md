# 🕵️ Session de Troubleshooting — Recherche de Blocage et de Panne — AU Refactor BtnEmergencyCutOff

> 📌 **Emplacement obligatoire** : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_AU_Refactor_BtnCutOff_20260831.md`
> 📅 Date : 2026-08-31 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [RÉSOLUE — comportement attendu]

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte
Refactor de la réd'urgence AU (fusion 3 FB → 1 `FB_Safety_EmergencyManagement`). Après test,
l'utilisateur observe que `Modes.State.EmergencyArmingFailed` et `Modes.State.PowerCutOffActive`
ne passent pas à 1, même quand `Modes.Cmd.BtnEmergencyCutOff = 1`. Diagnostic **statique** (lecture
de code, méthode [3] analyse statique déléguée) — pas d'acquisition live.

### Variables & valeurs
| <nobr>Élément</nobr> | <nobr>Variable complète</nobr> | Valeur | <nobr>Horodatage</nobr> |
|---|---|---|---|
| Commande IHM | `GVL_IHM.Modes.Cmd.BtnEmergencyCutOff` | 1 (appui) | 2026-08-31 |
| État IHM | `GVL_IHM.Modes.State.EmergencyArmingFailed` | 0 (symptôme) | 2026-08-31 |
| État IHM | `GVL_IHM.Modes.State.PowerCutOffActive` | 0 (symptôme) | 2026-08-31 |

## 2. 🎯 Symptôme

Après le refactor AU (3 FB → 1), `EmergencyArmingFailed` et `PowerCutOffActive` ne passent pas à 1
quand `BtnEmergencyCutOff = 1`. Permanent, reproductible.

## 3. 🧩 Indices / historique

- Dernier changement : refactor fusion `FB_Safety_EmergencyManagement` (Composite + Logic + Output → 1 FB).
- `PRG_06_Outputs.st` migré (scalaires → State/Diag, `_RQ` → `_Cmd`).
- Attente utilisateur : `BtnEmergencyCutOff` (coupure volontaire) → `EmergencyArmingFailed`/`PowerCutOffActive` à 1.

## 4. 🌳 Arbre des causes & hypothèses

| # | <nobr>Hypothèse</nobr> | <nobr>Variable de décision</nobr> | <nobr>Valeur attendue (source)</nobr> | <nobr>Valeur lue</nobr> | Verdict |
|---|---|---|---|---|---|
| 1 | Régression : mapping FB→PRG_06 perdu | `PRG_06_Outputs.st` L307-330 | Mapping complet (code) | Mapping complet | ❌ |
| 2 | Régression : `BtnEmergencyCutOff` ne coupe plus la puissance | `FB_Safety_EmergencyManagement.st` L368/370 | MaintainA/B_Cmd=FALSE (code) | FALSE | ❌ (pas de régression) |
| 3 | `EmergencyArmingFailed` doit passer à 1 sur coupure volontaire | `FB_Safety_EmergencyManagement.st` L170-174, L334 | Reste 0 (D2 option c) | 0 | ✅ attendu |
| 4 | `PowerCutOffActive` doit refléter `BtnEmergencyCutOff` | `PRG_06_Outputs.st` L331, L292-294 | = OR M1/M2/M3 (code) | 0 | ✅ attendu |

## 5. 📊 Arbre vertical des hypothèses (flux de données) — OBLIGATOIRE

```text
BtnEmergencyCutOff (GVL_IHM.Modes.Cmd)
  ├─→ PRG_06 L303 → FB_Safety_EmergencyManagement.BtnEmergencyCutOff
  │     ├─→ L170-174 : abort séquence, LastAbortCause:=16#0001, PAS EmergencyArmingFailedCause
  │     ├─→ L368/370 : MaintainA/B_Cmd := FALSE  (coupure physique réelle)
  │     └─→ L334 : EmergencyArmingFailed := TonArmingFailedDisplay.Q OR NOT Ack  (reste 0)
  │           └─→ L384 Status.Diag.ArmFailed → PRG_06 L328 → PRG_07 L410 → Modes.State.EmergencyArmingFailed = 0 ✅
  └─→ PowerCutOffActive (PRG_06 L331) := PowerCutOffReq (L292-294) = OR M1/M2/M3 PowerCutOff
        └─→ PRG_07 L417 → Modes.State.PowerCutOffActive = 0 (BtnEmergencyCutOff NON inclus) ✅
```

**Résumé une ligne** : `BtnEmergencyCutOff=1 → [FB: MaintainA/B=FALSE, ArmFailed=0] → EmergencyArmingFailed=0 ✅ · PowerCutOffActive=OR(M1/M2/M3)=0 ✅`

## 6. 📊 Données / interactions & chronogramme (🟡)

### Lectures & essais
- Lecture statique `FB_Safety_EmergencyManagement.st` (refactoré) : gestion `BtnEmergencyCutOff` correcte.
- Lecture statique `PRG_06_Outputs.st` (refactoré + backup pré-refactor) : `PowerCutOffActive := PowerCutOffReq` **identique** avant/après.
- Lecture statique `FB_Safety_EmergencyManagementLogic.st` (pré-refactor) : `BtnEmergencyCutOff` ne posait **pas** `EmergencyArmingFailed` non plus.

## 7. 🏁 Conclusion

- **Cause racine** : **Aucune régression.** Les deux symptômes sont **comportements attendus**, identiques avant et après le refactor.
  - `EmergencyArmingFailed` : une coupure volontaire (`BtnEmergencyCutOff`) n'est **pas** un échec d'armement (D2 option c). Le FB ne pose `EmergencyArmingFailedCause` que sur chute de boucle (L186) ou timeout contacteur (L283).
  - `PowerCutOffActive` : défini (ST_ModesState L12-16) comme l'agrégation des demandes de coupure **process** (M1/M2/M3), pas le bouton manuel. `PRG_06` L331 = `PowerCutOffReq` (OR M1/M2/M3), identique pré/post refactor.
- **Statut** : RÉSOLUE (comportement attendu, pas de correctif).

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : Aucun correctif nécessaire. Documenter l'attente : `PowerCutOffActive` = coupure process, pas bouton manuel.
- **Option 2 (définitif, si l'IHM doit refléter le bouton)** : Nouvelle fonctionnalité (hors bug) : inclure `BtnEmergencyCutOff` dans `PowerCutOffActive` OU exposer `Status.OperatorMessage` (L410 « AU: coupure urgence IHM active ») vers l'IHM — actuellement non consommé.
- **⚠️ Validation requise** : [humaine] — ne pas modifier le code sans validation.

## 9. ✅ Vérification de la correction / non-régression

- Non applicable (pas de correction). Vérification : le refactor n'a **pas** cassé le mapping (tous les champs `Status`/`Cmd` lus par PRG_06 existent et sont corrects).

## 10. 📝 Journal (chronologique)

- 2026-08-31 : Diagnostic statique. Verdict : comportement attendu, pas de régression. Fiche créée.
