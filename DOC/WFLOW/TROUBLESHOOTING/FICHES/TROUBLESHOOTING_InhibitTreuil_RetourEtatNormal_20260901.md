# 🕵️ Session de Troubleshooting — Inhibition treuil non réversible (retour état normal impossible)

> 📌 **Emplacement obligatoire** : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_InhibitTreuil_RetourEtatNormal_20260901.md`
> 📅 Date : 2026-09-01 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [RÉSOLUE]

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte
Mode joystick couplé = 0 (both). Test d'activation du bit d'inhibition M1 ou M2 : l'inhibition des treuils fonctionne. Mais une fois un treuil inhibé, rappuyer sur le même bouton ne ramène pas à l'état normal : `GVL_IHM.M2TreuilBenne.State.InhibitActive` reste à 1.

### Variables & valeurs
| Élément | Variable complète | Valeur | Horodatage |
|---|---|---|---|
| Inhibition M2 active | `GVL_IHM.M2TreuilBenne.State.InhibitActive` | 1 (reste à 1 après re-appui) | 2026-09-01 |

## 2. 🎯 Symptôme

Après inhibition d'un treuil (M1 ou M2), rappuyer sur le **même** bouton d'inhibition ne désactive pas l'inhibition : `InhibitActive` reste à 1, impossible de revenir à l'état normal par ce bouton. Permanent.

## 3. 🧩 Indices / historique

- Derniers changements : — (comportement de conception de `FB_Modes` §4bis)
- Déjà essayé : activation bit M1 / M2 (inhibition OK) ; re-appui même bouton (sans effet)
- Conditions d'apparition : mode MAINT_N2 (l'inhibition n'est effective qu'en N2)
- Alarmes : aucune

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | Le bouton d'inhibition est un **set-latch** (pas un toggle) : un front montant ne fait que **poser** l'inhibition, jamais la lever | `FB_Modes.st` §4bis (l.234-262) | Un re-appui du même bouton devrait lever l'inhibition (attente utilisateur) | Logique : re-appui → `Auth.InhibitM2 := TRUE` (re-posé) | ✅ cause racine |
| 2 | Le bouton IHM est un toggle qui reste à 1 | `GVL_IHM.*.Cmd.BtnInhibit` | — | — | ❌ (même avec toggle, la logique ne lève pas) |

## 5. 📊 Arbre vertical des hypothèses (flux de données)

```text
[BtnInhibit M2 (IHM)] → [InhibitM2Request] → [FB_Modes §4bis]
   front montant (InhibitM2Request AND NOT PrevInhibitM2)
      ├─ PrevInhibitM1=TRUE  → Auth.InhibitM2 := FALSE   (bascule vers M1)
      └─ PrevInhibitM1=FALSE → Auth.InhibitM2 := TRUE    (POSE, jamais lève) ❌
   re-appui M2 (PrevInhibitM2=FALSE après relâchement)
      → même branche → Auth.InhibitM2 := TRUE  (re-posé, pas de lever) ❌
```

**Résumé une ligne** : `[BtnInhibit M2 ↑] → [Auth.InhibitM2 := TRUE] ❌ (set-latch, pas de lever par re-appui)`

## 6. 📊 Données / interactions & chronogramme (🟡)

### Lectures & essais
- Lecture `FB_Modes.st` §4bis (l.234-262) : la logique ne contient **aucune** branche qui lève `Auth.InhibitM2` sur un re-appui du même bouton. 🟢 (preuve par code)
- Les seules voies de levée : appui de l'**autre** bouton (bascule), appui des **deux** simultanément (l.252-255), sortie de MAINT_N2 (l.278-284), `Enable=FALSE` (l.168-169). 🟢

### Chronogramme
| Événement | BtnInhibit M2 | PrevInhibitM2 | Auth.InhibitM2 |
|:---:|:---:|:---:|:---:|
| T1 appui | 1 | 0 | 1 |
| T2 relâche | 0 | 1 | 1 |
| T3 re-appui | 1 | 0 | 1 (re-posé, pas levé) ❌ |

## 7. 🏁 Conclusion

- **Cause racine** : dans `FB_Modes.st` §4bis (l.234-262), l'inhibition est un **set-latch à exclusion mutuelle**, **pas un toggle**. Un front montant du bouton ne fait que **poser** `Auth.InhibitM1/2` (et basculer vers l'autre treuil si l'autre était inhibé). Il n'existe **aucune** branche qui lève l'inhibition d'un treuil par un re-appui du **même** bouton. D'où `InhibitActive` qui reste à 1.
- **Statut** : à valider (cause racine prouvée par code, pas de snapshot nécessaire)

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : lever l'inhibition en appuyant sur les **deux** boutons M1+M2 simultanément, ou en sortant de MAINT_N2. — impact : contournement, pas de correction du comportement.
- **Option 2 (définitif)** : transformer le bouton en **toggle** dans `FB_Modes` §4bis — sur front montant du même bouton, si l'inhibition de ce treuil est déjà active, la **lever** (au lieu de la re-poser). Préserver l'exclusion mutuelle (lever M2 ⇒ ne pas toucher M1). — impact : comportement conforme à l'attente utilisateur.
- **⚠️ Validation requise** : [humaine] — ne pas modifier le code sans validation. Vérifier l'intention de conception (set-latch volontaire vs toggle) dans la spec `AF_Partie-05` §Inhibition (actuellement silencieuse sur la levée).

> ✅ **APPLIQUÉ (2026-09-01)** : Option 2 retenue (écran tactile simple, pas d'appui simultané possible). `FB_Modes.st` §4bis converti en **toggle** : front montant d'un bouton dont le treuil est déjà inhibé → lève l'inhibition ; sinon pose l'inhibition et lève l'autre (exclusion mutuelle). Tests `TC-P05-003bis`/`003ter` ajoutés. **13/13 PASS** (test CI `FB_Modes`).

## 9. ✅ Vérification de la correction / non-régression

- ✅ Test CI `FB_Modes` : **13/13 PASS** (dont 2 nouveaux tests toggle `TC-P05-003bis`/`003ter`).
- ✅ `TC-P05-003` (inhibition M1 seule) inchangé et PASS.
- ✅ `TC-P05-007` corrigé (setup : conditions d'arrêt mécanique sous AU) — préexistant, non lié au toggle.
- ⚠️ **Hand-off humain** : appliquer la modif dans CODESYS 3.5 (copie du ST de `FB_Modes.st` puis import PLCopenXML).

## 10. 📝 Journal (chronologique)

- 2026-09-01 : ouverture — cause racine identifiée par lecture `FB_Modes.st` §4bis (set-latch, pas de lever par re-appui).
- 2026-09-01 : validation humaine — toggle retenu (écran tactile simple). `FB_Modes.st` §4bis converti en toggle + tests `TC-P05-003bis`/`003ter` ajoutés. Test CI `FB_Modes` **13/13 PASS**.
