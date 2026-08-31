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

## 8. ⚠️ Défaut distinct — boutons de homing codeur

- `BtnHome` pouvait atteindre le chemin unitaire et sélectionner
  `CfgHomingTarget_M` (0 m par défaut) lorsque le capteur haut n'était pas
  actif.
- `BtnHomingAtZero` sélectionnait 0 m, mais n'était pas raccordé à la demande
  de homing : seul, il ne pouvait pas créer de front.
- Correctif T198 : dans `PRG_02_Acquisition`, les deux boutons déclenchent le
  homing. La cible libre transmise est 8,5 m (cote capteur configurée) pour
  `BtnHome`, et 0 m uniquement pour `BtnHomingAtZero`.
- Preuve hors CODESYS : `FB_Encoder` **40/40 PASS**, dont `T198-001` (8,5 m)
  et `T198-002` (0 m).

## 9. 🚨 Audit de régression systémique T184/T185

L'analyse Git a comparé le comportement historique de `7f2c12af` au
remaniement `d94c2c58` / `10cbc399`.

| Route IHM historique | Régression introduite | Fait vérifié |
|---|---|---|
| `BtnConfirmOpenPos/ClosePos` | Détournés vers `FB_MachineHomingCycle` | le commit `d94c2c58` remplace le recalage dynamique M2 par un homing conjoint M1+M2, conditionné par capteur haut et arrêt |
| Même boutons benne | `FB_Bucket` les marque « legacy ignorés » | les fronts locaux `R_TRIG` sont retirés dans `d94c2c58` |
| `BtnHomingAtZero` | N'est plus relié à `HomingAtTargetM` | `10cbc399` retire le `OR BtnHomingAtZero`; le bit ne sélectionne qu'une cible, sans déclenchement |
| `BtnHome` au capteur physique | Peut prendre la cible unitaire | `FB_Encoder_Homing` attend `TopPositionSensor=TRUE`, mais PRG_02 lui transmet `TopPositionFree_DI` sans inversion |

Le contrat historique explicite de `7f2c12af` est : les boutons benne
confirment l'état visuel **et** recalibrent uniquement M2 à partir de M1
(ouvert : M1 ; fermé : M1 + offset fermé). Ils ne doivent pas lancer un
référencement global M1/M2.

Les correctifs T196/T198 actuellement dans le répertoire de travail sont
**suspendus, non compilés pour ce diagnostic**. Ils réparent des symptômes
isolés mais ne constituent pas encore le retour complet au contrat historique.

## 10. 🔎 Audit étendu des routes IHM

- Les diffs `d94c2c58`, `10cbc399` et `c006b68f` ne montrent aucun autre
  bouton IHM retiré ou redirigé dans les PRG métier, hors les routes
  M1/M2/benne listées en §9.
- `BtnHome` M1/M2 est aussi lu par `PRG_03 → FB_Cycle.HomingRequest` depuis le
  2026-08-15, donc antérieur à T184/T185 : double consommateur à documenter,
  mais pas une régression introduite par ces commits.
- Le sous-agent Ollama a été challengé : sa première réponse a inventé un
  paramètre absent, sa seconde n'a produit qu'un plan. Aucun de ses verdicts
  non recoupés n'a été retenu.
- Validation bloquée : un autre agent a ajouté `ST_fbMachineHomingCycle_Cfg`
  à `FB_MachineHomingCycle` sans fournir le type au runner STruCpp. Le test du
  cycle ne compile donc plus, indépendamment des routes IHM corrigées ici.
