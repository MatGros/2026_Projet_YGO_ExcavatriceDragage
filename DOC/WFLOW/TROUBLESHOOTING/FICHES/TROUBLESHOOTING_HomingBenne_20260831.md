# 🕵️ Session de Troubleshooting — Homing benne

> 📅 Date : 2026-08-31 · 🧪 Situation : [SIMULATION BANC] · 📄 Statut : EN COURS

## 1. 🧊 Contexte figé

- Symptôme : la confirmation de position ouverte ou fermée de la benne ne
  déclenche pas le référencement machine.
- Mode rapporté : `MAINT_N2`.
- Observation antérieure : `MachineHomingStep = 30` (`NEED_TOP_POSITION`).
- Diagnostic antérieur : `ErrorId = 18` = codeurs non référencés (16) + écart
  M1/M2 hors plage (2).
- Acquisition disponible : snapshot du 2026-08-31 08:49, intégrité 495/495.
- Changement depuis cette acquisition : simulation du capteur haut désormais
  calculée depuis le seuil M1 configuré.
- Acquisitions post-correctif : `085916` et `085942`, identiques sur les
  variables de décision.

## 2. 🎯 Symptôme

État bloqué : le cycle reste avant la fenêtre de confirmation de référencement
benne malgré l'action utilisateur.

## 3. 🌳 Arbre des causes

| # | Hypothèse | Variable de décision (snapshot) | Attendu | Verdict |
|---|---|---|---|---|
| 1 | Capteur haut non actif | `HomingM1.TopPositionSensorActive` | `TRUE` | `FALSE` — cause prouvée |
| 2 | Treuils non arrêtés mécaniquement | `HomingM1/2.Step4_ContactorsReleased`, `Step5_BrakeApplied` | tous `TRUE` | tous `TRUE` — écartée |
| 3 | Axes non référencés | `HomingM1/2.HomingHomed`, `HomingSuspect` | homed `TRUE`, suspect `FALSE` | conforme — écartée |
| 4 | Offset benne inconnu | `BenneOuvertureFermeture.Idx118_BucketOffsetUnknown` | `TRUE` avant confirmation, puis `FALSE` | `TRUE` — normal avant confirmation |
| 5 | Front IHM non consommé | `Idx114_MachineHomingStep`, `Idx119_ReferenceTransaction` | étape 45 puis transaction active | étape 30, transaction `FALSE` — conséquence de 1 |
| 6 | Défaut benne actif | `Idx302_BucketFaultActive`, `Idx306_ErrorIdRaw` | pas de défaut bloquant après référencement | `FALSE`, `WORD#0` — écartée |

## 4. 📊 Arbre vertical

```text
Confirmation IHM
└─ fenêtre de référencement
   ├─ capteur haut actif ?                         → HomingM1.TopPositionSensorActive
   ├─ M1/M2 arrêtés et freins appliqués ?          → HomingM1/2.Step4, Step5
   ├─ M1/M2 qualifiés ?                            → HomingM1/2.HomingHomed, HomingSuspect
   └─ cycle à l'étape 45, puis transaction active? → Idx114, Idx119
```

## 5. 📝 Journal

- 2026-08-31 08:59:16 et 08:59:42 : `Mode=MAINT_N2`, simulation active,
  M1/M2 homed, contacteurs relâchés et freins appliqués. Le capteur haut reste
  libre : `Inputs.Winch.M1M2_TopPositionFree_DI=TRUE`, donc
  `TopPositionSensorActive=FALSE`.
- Position M1 observée : `5.11181641 m` (`982066` points). Seuil haut M1
  configuré : `7.5 m`. La position n'a pas atteint le seuil ; le modèle de
  simulation produit donc correctement un capteur haut inactif.
- Le cycle reste logiquement à l'étape 30 (`NEED_TOP_POSITION`). La fenêtre de
  confirmation (étape 45) ne peut pas s'ouvrir avant l'atteinte du capteur.
- Analyse statique : les boutons `BtnConfirmOpenPos` / `BtnConfirmClosePos`
  sont bien raccordés de `PRG_02_Acquisition` vers
  `FB_MachineHomingCycle.ConfirmOpenPosition/ConfirmClosePosition`.
  Le nouveau cycle ne consomme toutefois leur front qu'avec
  `WindowSafe = MAINT_N2 AND TopPositionActive AND WinchesMechanicallyStopped`.
- Régression fonctionnelle identifiée : dans `FB_Bucket`, les entrées de
  confirmation sont désormais explicitement marquées *legacy, ignorées* ; seul
  le commit issu du cycle peut écrire l'état ouvert/fermé. Hors fenêtre, le
  front bouton est volontairement perdu sans transaction ni retour IHM dédié.

## 6. 🏁 Conclusion

- **Cause racine prouvée** : le nouveau cycle de référencement a déplacé la
  prise en compte des boutons vers une fenêtre préalable capteur haut + arrêt,
  tandis que `FB_Bucket` les déclarait explicitement *legacy, ignorés*.
  L'appui ne pouvait donc plus qualifier l'état benne directement.
- **Ce n'est pas un défaut de homing codeur** : M1 et M2 sont homed et fiables.
- **Correction appliquée** : les fronts `ConfirmOpenPosition` et
  `ConfirmClosePosition` requalifient directement l'état benne dans
  `FB_Bucket` en `MAINT_N1` ou `MAINT_N2`, seulement hors mouvement. Le cycle
  de référencement conserve son rôle indépendant de qualification globale.

## 7. ✅ Vérification de la correction

- Test STruCpp `FB_Bucket` : **24/24 PASS**.
- `TC-P10-030` prouve les deux confirmations directes :
  `ConfirmOpenPosition` → `IsOpen=TRUE` et `ConfirmClosePosition` →
  `IsClosed=TRUE` en maintenance ; une confirmation en `SEMI_AUTO` ne modifie
  pas l'état qualifié.
- Validation CODESYS humaine requise : compiler puis actionner les deux boutons
  avec les treuils immobiles en maintenance.
