# 🧭 NAVBOARD — Mise en Service Joystick + Translation M3

> 🎯 **Rôle** : fiche mémo "comment je démarre chaque fonctionnalité", pas une checklist de
> validation exhaustive (voir `DOC/CHECKLISTS/CHECKLIST_MiseEnService_Joystick_v1.0.md` et
> `CHECKLIST_MiseEnService_Translation_v1.0.md` pour le protocole complet Pass/Fail).
> Post-renommage session Bypass/IHM-NAMING-01 — noms à jour (`Btn*`/`Sel*`/`Set*`/`Tgl*`/`Sensor*`/`Bus*`).

---

## 🔑 0. AVANT TOUT — bascule simulation → réel

| Étape | Variable | Valeur cible |
|---|---|---|
| 1 | `GVL_Simulation.SimulationModeActive` | Rester `TRUE` tant que le câblage réel n'est pas confirmé |
| 2 | `GVL_Simulation.BusJoystickSignalIsReal` | `TRUE` dès que RawX/RawY/RawButton sont câblés réels |
| 3 | `GVL_Simulation.BusJoystickIsReal` | `TRUE` dès que le bus/nœud CANopen JOY1 est monté (indépendant de l'étape 2) |
| 4 | `GVL_Simulation.BusVariateurM3IsReal` | `TRUE` dès que l'AC600 EtherCAT est raccordé |
| 5 | `GVL_Simulation.SensorTranslationPositionIsReal` | `TRUE` dès que les 5 capteurs position M3 sont câblés |
| 6 | `GVL_Simulation.SensorM3ContactorFeedbackIsReal` | `TRUE` dès que le retour contacteur/frein M3 est câblé |
| 7 | `GVL_Simulation.SensorPhaseRotationIsReal` | `TRUE` dès que le contrôle rotation phases est câblé |
| 8 | `GVL_Simulation.SensorBrakeThermalIsReal` | `TRUE` dès que le thermique frein commun est câblé |
| 9 | `SimulationModeActive := FALSE` | **Dernière étape**, une fois 2→8 tous `TRUE` — jamais avant |

⚠️ **Piège connu** : tant que `BusJoystickSignalIsReal=FALSE`, les temporisations homme-mort
tournent en mode confort (`DeadmanRearmTimeout=5min`, `NeutralHoldTime=1s`) au lieu des valeurs
production (`10s`/`500ms`) — **sans aucune alarme**. Vérifier explicitement, ne jamais supposer.

---

## 🕹️ 1. Démarrer le Joystick

**Fichiers** : `FB_Joystick` (instance `PRG_01_Diagnostics.FB_Joystick_0`) · `FB_AxisScale` · `FB_Ramp`
**IHM** : `GVL_IHM.JOY1Joystick` (`ST_JoystickHMI`)

### Étape 1 — Calibrer le neutre
```
Manche au repos physique
→ Front GVL_IHM.JOY1Joystick.BtnCalibrate (TRUE puis FALSE)
→ Vérifier FB_Joystick_0.NeutralXAct / NeutralYAct = RawX/RawY courant
```
❌ Si `RawX`/`RawY` hors plage `2000..8000` → calibration refusée, `ErrorId` bit0 → Reset après correction.

### Étape 2 — Armer le homme-mort
```
1. Manche AU NEUTRE (obligatoire)
2. Appuyer le bouton homme-mort
→ DeadmanArmed := TRUE
3. Dévier le manche au-delà du deadband (10%)
→ Mouvement démarre
```
⚠️ Appui **hors neutre** = armement refusé. Toujours repasser au neutre avant d'appuyer.

### Étape 3 — Reconfirmation en mouvement
- Bouton **maintenu** en continu → jamais de désarmement
- Bouton **relâché** → rampe décel normale démarre, désarmement après `DeadmanRearmTimeout` (10s prod) sans réappui
- Retour au neutre tenu **≥ 500ms** → désarmement propre (fin de geste)

---

## ↔️ 2. Démarrer la Translation M3

**Fichiers** : `PRG_07_TranslationControl` · `FB_Translation` · `FB_Safety_Translation`
**IHM** : `GVL_IHM.M3Translation` (`ST_TranslationHMI`)

### Pré-requis
```
1. Joystick armé et opérationnel (§1)
2. EmergencyStopOk = TRUE
3. Mode = MAINT_N1 (ou MAINT_N2 pour cible Maintenance)
```

### Choix de pilotage — 3 façons de démarrer

| Méthode | Réglage | Démarrage |
|---|---|---|
| **A. Boutons IHM** | `TglJoystickMaster := FALSE` | `BtnFwd` ou `BtnRev` maintenu + homme-mort armé en parallèle (obligatoire même en boutons !) |
| **B. Joystick** | `TglJoystickMaster := TRUE` | Déflexion axe X + homme-mort armé |
| **C. Positionneur (aller-à-cible)** | `SelPositioning := TRUE` + `SelTarget` (1=Trémie/2=P2/3=P1/4=Maintenance) | Sens calculé automatiquement, arrêt sur capteur cible |

⚠️ **Cible 4 (Maintenance)** refusée hors `MAINT_N2`.
⚠️ **Vitesse boutons IHM** : `SetFreqHz` = consigne directe en Hz (0..60Hz), pas en %.
⚠️ **Vitesse joystick** : `Hz = déflexion(%) × SetFreqHz/100` — dépend de `SetFreqHz` réglé.

### Démarrage rapide (le plus courant en mise en service)
```
1. Mode = MAINT_N1
2. TglJoystickMaster := FALSE (boutons IHM)
3. SetFreqHz := 20.0 (vitesse prudente pour premier essai)
4. Armer homme-mort joystick (§1 étape 2, même sans bouger le manche)
5. Appuyer BtnFwd (ou BtnRev) — maintenir
6. Relâcher → arrêt rampe normale
```

---

## 🪝 2bis. Démarrer les Treuils M1/M2 par boutons IHM (WINCH-BTN-01)

**Fichiers** : `PRG_06_WinchControl` §1/§2 · `FB_Winch` (inchangé)
**IHM** : `GVL_IHM.Modes.TglJoystickMaster` (source) + `GVL_IHM.Modes.SelJoystickWinch` (treuil ciblé) + `GVL_IHM.M1TreuilRetenue.BtnUp/BtnDown` · `M2TreuilBucket.BtnUp/BtnDown`
⚠️ **Réouverture documentée doctrine T40** — voir `DOC/AUDITS/WinchIhmButtons/REGISTRE_ACTIONS_WinchIhmButtons_v1.0.md`

### Pré-requis
```
1. Mode = MAINT_N1 (accessible, pas de mot de passe)
2. Joystick armé (homme-mort TOUJOURS requis, même en pilotage boutons)
3. SelJoystickWinch : 1=M1 seul / 2=M2 seul / 3=Couplé (même sélecteur que joystick)
```

### Démarrage
```
1. TglJoystickMaster := FALSE (source = boutons IHM)
2. Choisir SelJoystickWinch (1/2/3) selon le treuil visé
3. Armer homme-mort joystick (même sans bouger le manche — obligatoire)
4. Appuyer BtnUp (montée) ou BtnDown (descente) sur le/les treuil(s) sélectionné(s) — maintenir
5. Relâcher → arrêt rampe normale immédiat
```
⚠️ **IHM monotouche** : un seul mouvement actif à la fois.
⚠️ **Sans homme-mort joystick armé** : le bouton IHM n'a **aucun effet**, même maintenu (même leçon que Translation M3 §6bis).

---

## 🪣 3. Ouvrir/Fermer la Benne (rappel, déjà en place)

**Fichiers** : `FB_Bucket` (instance `PRG_06_WinchControl.instBucket`)
**IHM** : `GVL_IHM.Bucket` (`ST_BucketHMI`)

```
Pré-requis : Homed M1 ET M2 = TRUE (sinon ErrorId bit3)
1. Appuyer BtnOpen (ou BtnClose)
2. Pousser joystick Y dans le bon sens (fermeture=monter/+1, ouverture=descendre/-1)
   ET homme-mort armé
→ M2 se déplace en vitesse lente forcée jusqu'à la cible (offset 10m fermé / 0m ouvert)
→ Arrêt automatique à la cible, Done=TRUE
```

---

## 🎯 4. Homing (référencement codeurs) — MAINT_N2 uniquement

**Fichiers** : `FB_Encoder_Homing` (instances M1/M2)

```
1. Mode = MAINT_N2
2. Vérifier position physique connue (capteur haut atteint, ou position à blanc)
3. Front BtnHome (M1TreuilRetenue ou M2TreuilBucket)
→ Codeur calé sur CfgHomingTargetM / CfgTopSensorPosM (8.5m)
```

### Référencer la benne (position mémoire, sans mouvement)
```
Benne physiquement ouverte  → Front BtnConfirmOpenPos
Benne physiquement fermée   → Front BtnConfirmClosePos
```

---

## 📊 5. Lecture rapide — codeurs & diagnostics

| Donnée | Chemin |
|---|---|
| Position câble M1/M2 (m) | `GVL_IHM.M1TreuilRetenue.PositionM` / `M2TreuilBucket.PositionM` |
| Codeur brut M1/M2 | `GVL_IHM.M1TreuilRetenue.Encoder.RawPos` / idem M2 |
| Fréquence réelle M3 | `GVL_IHM.M3Translation.DriveActualFreqHz` |
| Mot 5 capteurs M3 | `GVL_IHM.M3Translation.SensorsWord` (bit4=Trémie...bit0=Maintenance) |
| Défaut Winch | `GVL_IHM.M1TreuilRetenue.ErrorId` / `SafetyErrorId` |
| Défaut Translation | `GVL_IHM.M3Translation.ErrorId` / `SafetyErrorId` |

---

## 🚨 6. Dépannage express

| Symptôme | Vérifier en premier |
|---|---|
| Rien ne bouge (joystick) | `DeadmanArmed`, `BusJoystickIsReal`/`Online`, `Mode≠DISABLE` |
| Rien ne bouge (Translation) | `TglJoystickMaster` cohérent avec méthode utilisée, `SafeStop`, `EmergencyStopOk` |
| Homme-mort désarme trop vite | `BusJoystickSignalIsReal` doit être `TRUE` (sinon délais confort 5min, pas un bug) |
| Bouton IHM Translation sans effet | Vérifier homme-mort joystick **quand même armé** — obligatoire même en pilotage boutons |
| Bloqué sur une cible M3 | `ArrivalLock` actif → repartir dans le sens opposé |
| Benne n'accepte pas la commande | `Homed` M1 ET M2 requis (`ErrorId` bit3 sinon) |
| Cible Maintenance (M3) refusée | Repasser en `MAINT_N2` |

---

## 📚 Sources
`CODE/JOYSTICK/FB_Joystick.st` · `CODE/MAIN/PRG_01_Diagnostics.st` · `CODE/MAIN/PRG_07_TranslationControl.st`
`CODE/TRANSLATION/FB_Translation.st` · `CODE/TREUILS/BENNE/FB_Bucket.st` · `CODE/CODEURS/FB_Encoder_Homing.st`
`DOC/NAVBOARD_TranslationM3.md` (référence détaillée Translation) · `DOC/AUDITS/Bypass/REGISTRE_ACTIONS_Bypass_v1.0.md` (mapping renommage)
