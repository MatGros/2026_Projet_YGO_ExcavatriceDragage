# 🕵️ Session de Troubleshooting — Recherche de Blocage et de Panne — Bandeau alarme cycle absent (palier 5)

> 📌 Emplacement : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_BandeauAlarmeCyclePalier5_20260919.md`
> 📅 Date : 2026-09-19 · 🧊 Situation : [SITE] (rapporté par l'utilisateur, machine réelle) · 📄 Statut : [EN COURS — cause racine identifiée, correction non appliquée]

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte
Cycle SEMI_AUTO (`FB_CycleSemiAuto`, plongée AX4..AX7). L'utilisateur signale un blocage suspecté au
passage étape 6 (AX6_SEARCH_IMMERSION) → étape 7 (AX7_SEARCH_BOTTOM) lorsque le treuil M2 atteint le
palier 5 (vs palier 4 qui fonctionne). Le comportement palier 4/5 est piloté par le toggle non-persistant
`GVL_IHM.CycleSemiAuto.Cmd.TglAutoDiveM2Step5Trial` (essai T291-A), latché en AX3→AX4
(`AutoDiveM2Step5TrialLatched`).

En creusant le symptôme, l'utilisateur constate que les `instCauses` ont des **latches actifs** mais que
**le bandeau alarme IHM (message alarme banner) n'affiche rien** — ce point est devenu prioritaire :
sans remontée d'alarme lisible, impossible de confirmer si le blocage palier 5 est le défaut
`instCauses[8]` (comportement voulu si toggle OFF) ou un vrai bug de séquencement.

### Variables & valeurs
| Élément | Variable complète | Valeur | Horodatage |
|---|---|---|---|
| Toggle essai palier 5 | `GVL_IHM.CycleSemiAuto.Cmd.TglAutoDiveM2Step5Trial` | à vérifier (non persistant) | — |
| Latch défaut cycle | `PRG_03_Modes_Cycle.Data.SequenceState.Fault.Latched` | rapporté actif (par l'utilisateur) | 2026-09-19 |
| Bandeau alarme IHM | `AlarmArray` (`FB_Hmi_BannerFormatter`) | rapporté vide | 2026-09-19 |

## 2. 🎯 Symptôme

Le bandeau d'alarme IHM n'affiche aucun message alors que des causes de défaut cycle sont latchées ;
symptôme constant, pas intermittent (structurel, voir §7).

## 3. 🧩 Indices / historique

- Derniers changements : ajout du toggle essai T291-A (palier 5 M2 en plongée), modifications SimBench.
- Déjà essayé : observation IHM (bandeau alarme + affichage instCauses).
- Conditions d'apparition : constant, dès qu'une cause parmi `instCauses[2,7,8,9,11]` est latchée.
- Alarmes : aucune remontée visible au bandeau défilant.

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | `instCauses[8]` (palier 5 interdit) ne se déclenche pas | `M2_SpeedStepApplied > DiveM2StepTgt` | Devrait armer le latch si toggle OFF et M2 atteint palier 5 (`FB_CycleSemiAuto.st:473-479`) | logique cohérente à la lecture | ✅ (code correct) |
| 2 | Le latch `Fault.Latched`/`LatchedId` ne se propage pas vers l'IHM | `GVL_IHM.CycleSemiAuto.State.ErrorId` | `SEL(Fault.Latched, Fault.ErrorId, Fault.LatchedId)` — bascule vers vue latchée si `Latched=TRUE` (`PRG_07_Supervision.st:610-612`) | logique cohérente à la lecture | ✅ (code correct) |
| 3 | Le bandeau défilant (`AlarmArray`) ne collecte pas tous les bits `CycleErrorId` | `FB_Hmi_BannerFormatter.st` §5h (lignes 918-936) | Devrait couvrir `instCauses[0..11]` actives/latchées (12 causes définies) | Seuls les bits `0x0001,0x0002,0x0008,0x0010,0x0020,0x0040` (index 0,1,3,4,5,6) sont poussés dans `AlarmArray` | ❌ **CONFIRMÉ — trou de câblage** |

## 5. 📊 Arbre vertical des hypothèses (flux de données) — OBLIGATOIRE

```text
instCauses[8].Active (M2 palier5, toggle OFF)
  └─▶ FB_FaultCore.Latch[8] := TRUE (armement, §3 FB_FaultCore.st) ✅
        └─▶ Fault.Latched=TRUE, Fault.LatchedId bit8=1 ✅
              └─▶ GVL_IHM.CycleSemiAuto.State.ErrorId := LatchedId (SEL bascule OK, PRG_07:610) ✅
                    └─▶ FB_Hmi_BannerFormatter.CycleErrorId = bit8 (0x0100) présent en entrée ✅
                          ├─▶ CycleFaultCauseStr (mono-valeur, ligne 625) : décode bit 0x0100 ✅ visible qqpart
                          └─▶ AlarmArray[] (§5h, lignes 918-936) : boucle IF ne teste QUE
                              0x0001/0x0002/0x0008/0x0010/0x0020/0x0040
                              → bit 0x0100 (index8) JAMAIS testé
                              → RIEN poussé dans AlarmArray ❌ BLOCAGE
```

**Résumé une ligne** : `[instCauses[8].Latch=1] → [CycleErrorId bit8=1] → [AlarmArray: bit8 non testé] ❌`

## 6. 📊 Données / interactions & chronogramme (🟡)

### Lectures & essais
- Lecture statique `FB_CycleSemiAuto.st` : logique palier 4/5 (toggle, latch, garde `instCauses[8]`) cohérente,
  pas de bug de câblage AX6/AX7.
- Lecture statique `PRG_07_Supervision.st:601-619` : propagation `Fault` → `GVL_IHM.CycleSemiAuto.State`
  correcte, bascule live/latched déjà gérée intentionnellement (commentaire ligne 605-607).
- Lecture statique `FB_Hmi_BannerFormatter.st:918-936` (§5h "Collecte — cycle semi-auto") : seuls
  **6 des 12 causes cycle** (`instCauses[0..11]`) sont câblées dans la boucle de collecte du bandeau
  défilant `AlarmArray`. Manquants : index 2 (écart codeurs montée controlée), 7 (FDC translation),
  **8 (palier 5 interdit)**, 9 (palier 4 non confirmé), 10 (réserve, Active=FALSE donc sans impact),
  11 (consigne profondeur invalide).

### Chronogramme
Non applicable — cause structurelle (code), pas temporelle.

## 7. 🏁 Conclusion

- **Cause racine** : `FB_Hmi_BannerFormatter.st` §5h (lignes 918-936) — la boucle de collecte du bandeau
  d'alarme défilant `AlarmArray` ne teste que 6 des 12 bits `CycleErrorId` possibles. Les causes cycle
  index 2, 7, 8, 9, 11 (dont `instCauses[8]` "Palier vitesse > 4 (palier 5) pendant la plongée - interdit",
  exactement la cause déclenchée par le scénario palier 5 rapporté) ne remontent jamais au bandeau,
  même latchées. C'est un **trou de câblage dans le formatter IHM**, pas un bug de séquencement cycle
  ni de logique palier 4/5 (celle-ci est cohérente, cf. arbre §4-5).
- **Statut** : cause racine identifiée par lecture de code (analyse statique), **non confirmée par snapshot
  live** (pas encore demandé — voir §8 pour la suite). Reste à vérifier en situation réelle si
  `instCauses[8]` est bien la cause qui s'arme au moment du blocage rapporté (dépend de l'état du toggle
  `TglAutoDiveM2Step5Trial` au moment de l'entrée en AX4).

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : en attendant la correction, lire `CycleFaultCauseStr` (mono-valeur,
  déjà câblée pour toutes les causes 0x0001..0x0400) via un snapshot `GVL_Troubleshooting` ou l'IHM de
  diagnostic technique, pour confirmer/infirmer que `instCauses[8]` est bien la cause active — sans
  attendre la correction du bandeau. Risque : nul (lecture seule).
- **Option 2 (définitif)** : compléter la boucle de collecte §5h de `FB_Hmi_BannerFormatter.st` pour
  couvrir les bits manquants (index 2, 7, 8, 9, 11 — exclure 10 qui est `Active:=FALSE`/réservé), avec un
  libellé cohérent avec `instCauses[i].Texte` (ex. `'[CYCLE] ErrorID:09 - palier vitesse > 4 interdit'`
  pour bit 0x0100). Risque : faible (ajout de branches IF supplémentaires, pas de modification de la
  logique existante) — respecter `guard:` (T150/AGENTS.md règle `fix:`+`guard:`) : ajouter un test CI qui
  vérifie que chaque bit actif de `CycleErrorId` produit une entrée dans `AlarmArray`, pour éviter une
  régression future si une 13e cause est ajoutée sans mise à jour du formatter.
- **⚠️ Validation requise** : [humaine] — ne pas modifier `FB_Hmi_BannerFormatter.st` sans ton accord
  explicite sur le libellé des causes 2/7/8/9/11 et sur l'approche du garde-fou CI.

## 9. ✅ Vérification de la correction / non-régression

> À remplir après application + validation de la correction (§8).

## 10. 📝 Journal (chronologique)

- 2026-09-19 : Ouverture — signalement blocage suspecté étape 6→7 en palier 5. Analyse statique
  `FB_CycleSemiAuto.st` : logique palier 4/5 (toggle T291-A) cohérente. Réorientation par l'utilisateur
  vers le vrai symptôme bloquant : bandeau alarme IHM vide malgré latches actifs. Analyse statique
  `PRG_07_Supervision.st` + `FB_Hmi_BannerFormatter.st` : cause racine trouvée — boucle §5h ne collecte
  que 6/12 causes cycle, dont `instCauses[8]` (palier 5) absente. Fiche mise à jour, correction proposée,
  en attente de validation humaine.

---

📖 **Documentation complète** : `GUIDE_Troubleshooting.md` (même dossier).
