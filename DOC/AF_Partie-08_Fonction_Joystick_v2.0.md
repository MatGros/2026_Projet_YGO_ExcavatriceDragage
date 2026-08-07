# Analyse Fonctionnelle — Partie 8 : Fonction Joystick (v2.0)

> Rôle : acquisition et conditionnement du geste opérateur (Hall CANopen → consignes d'axe).
> **Pas** un FB de mouvement : pas de `SafeStop` / pas de pilotage Q.
> Source code : `CODE/JOYSTICK/FB_Joystick.st` · instance `Acquisition (CFC).instJoystick`.
> Extraction : `DOC/CHECKLISTS/EXTRACTIONS/FB_Joystick_Extraction_Code_v1.0.md`.
> v1.3 archivée : `ARCHIVES/Doc/AF_Partie-08_Fonction_Joystick_v1.3.md`.

## 🧭 Sommaire

1. Rôle et périmètre
2. Pipeline et composition
3. Interface et contrats
4. Homme-mort
5. Calibration et défauts
6. Intégration programme
7. IHM
8. Alertes et écarts
8bis. TBD — Filtre par défaut et double rampe Joystick↔FB de mouvement
9. Documents liés

## 🧪 Points de validation

| ID | Intention | Preuve | Type | Réf |
|---|---|---|---|---|
| TC-P08-001 | Perte contacteur / CAN ➔ désarmer et annuler axes | `SpeedRef=0`, `DeadmanArmed=FALSE` | `⚡ SITE+AUTO` | §3 |
| TC-P08-002 | Armement homme-mort sur front au neutre uniquement | Armement ➔ `SpeedRef` actif | `⚡ SITE+AUTO` | §4 |
| TC-P08-003 | Bouton relâché en mouvement : **sans** reconfirmation (`DeadmanReconfEnable=FALSE`, défaut) armement conservé ; **avec** reconfirmation (TRUE) relâchement > 10 s ➔ désarmement | `DeadmanArmed` conservé / `DeadmanArmed=FALSE` | `⚡ SITE+AUTO` | §4 |
| TC-P08-004 | Neutre rapide (<100ms) conserve armement, prolongé désarme | Armement conservé / perdu | `💻 AUTO` | §4 |
| TC-P08-005 | Changement de mode ou fin benne désarme le joystick | `DeadmanArmed=FALSE` | `💻 AUTO` | §4, §6 |
| TC-P08-006 | Calibration hors [2000;8000] ➔ alarme `ErrorId` | Bit0 actif, `Reset` sur cause disparue | `💻 AUTO` | §5 |
| TC-P08-007 | Consigne `SpeedRef` signée [-100;+100] sur `ST_Joystick_AxisCmd` | Contrat FB respecté sans `SafeStop` | `💻 AUTO` | §1, §2 |
| TC-P08-008 | Winch, Translation et Cycle exigent `DeadmanArmed` | Linkage vérifié | `💻 AUTO` | §6 |

---

## 1. Rôle et périmètre

| Fait | Détail |
|---|---|
| Entrée | 2 axes bruts 0..10000 + 1 bouton, nœud CANopen (ou sim amont) |
| Sortie | `ST_Joystick_AxisCmd` X/Y + `DeadmanArmed` + miroirs maintenance |
| Fait | Producteur d'**intention** de conduite, pas d'actionneur |
| Ne fait pas | Arbitrage mode, limites machine, frein, PowerCutOff, Q physiques |

Profil AF03 : brique métier non-mouvement. Gate : `Enable`, `PowerContactorEngaged`, diag CAN/device.

---

## 2. Pipeline et composition

```text
Raw ─► FB_AxisScale ─► FB_Filter_PT1 ─► Homme-Mort (0 si non armé) ─► ST_Joystick_AxisCmd
         deadband raw       τ filtre
```

| Brique | Rôle |
|---|---|
| `FB_AxisScale` | Neutre + deadband (compte brut ADC, 🔧 2026-08-07 : remplace le %) → % signé, borné ±100 |
| `FB_Filter_PT1` | Lissage haute fréquence ; `CycleTimeS` via `FB_CycleTime` interne |
| Homme-mort | Force la consigne à 0.0 si non armé (`DeadmanArmed = FALSE`) |

> 📌 **Architecture des rampes** : `FB_Ramp` n'est pas instancié dans `FB_Joystick`.
> La gestion des rampes d'accélération et de décélération est confiée exclusivement aux FB
> de mouvement aval (`FB_Winch`, `FB_Translation`) pour éviter le double-lissage et préserver
> la maîtrise directe du gradient de décélération lors des arrêts de sécurité (`SafeStop`).

`ST_Joystick_AxisCmd` :

| Champ | Sens |
|---|---|
| `Enable` | TRUE quand pipeline actif |
| `StartStop` | TRUE si `ABS(SpeedRef) > 0.1` |
| `SpeedRef` | % **signé** −100..+100 |
| `Direction` | −1 / 0 / +1 (seuil ±0,1 sur rampe) |

Paramètres d'appel production (`Acquisition`) : deadband / filtre / rates depuis `GVL_PERSISTENT` ;
`DeadmanRearmTimeout=T#10s`, `NeutralHoldTime=T#100ms` (🔧 2026-08-07, réduit de 500ms), `DeadmanReconfEnable=FALSE` (figé, défaut cible).

---

## 3. Interface publique (code actuel)

### Entrées

| Port | Producteur actuel |
|---|---|
| `Enable` | `TRUE` fixe dans Acquisition |
| `Reset` | `FaultMachineReset_IHM` |
| `PowerContactorEngaged` | `Acquisition (CFC).PowerContactorEngaged` |
| `Mode` | `Modes (CFC).instModes.Mode` (scan N−1) |
| `BenneBusy` | `Treuils.instBucket.Busy` (scan N−1) |
| `PreserveArmingAfterBucket` | Extraction Busy **et** état `CLOSING_BUCKET` |
| `BusCanOpenOP` / `JoystickOP` | `FB_Diag_CanOpen` |
| `RawX/Y`, `RawButton` | `Acquisition.HwIn.Operator` |
| `BtnCalibrate` | `GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate` |
| `Invert*`, `DeadbandRaw`, `FilterTime`, `AccelRate`, `DecelRate` | PERSISTENT |
| `NeutralXMem/YMem` | `VAR_IN_OUT` persistants |
| `DeadmanRearmTimeout` | `T#10s` — reconfirmation (n'agit que si `DeadmanReconfEnable=TRUE`) |
| `NeutralHoldTime` | `T#100ms` (🔧 2026-08-07, réduit de 500ms) — neutre tenu avant désarmement |
| `DeadmanReconfEnable` | `FALSE` figé (Acquisition) — consentement au démarrage / reconfirmation |

### Sorties

| Port | Rôle |
|---|---|
| `AxisCmdX/Y` | Consignes normalisées |
| `Speed*Pct` / `Direction*` | Miroirs plats (maintenance) |
| `Button` | = `RawButton` (pas de filtre dédié) |
| `Neutral*Act` | Neutres actifs |
| `DeadmanArmed` | Geste armé |
| `Ready/Busy/Done/Error/ErrorId` | État FB |

**Gate** (`Enable` / `PowerContactorEngaged` / master CAN OP / device OP) :
sorties axes à 0, `DeadmanArmed=FALSE`, timers deadman reset, `RETURN`.

---

## 4. Homme-mort

> 🆕 **2026-08-03 — Décision utilisateur** : le bouton devient un **consentement au démarrage**.
> Défaut (`DeadmanReconfEnable := FALSE`, figé dans le câblage) : armement au neutre → mouvement
> libre **sans surveillance du bouton** → retour au neutre 500 ms désarme → rappuyer pour un nouveau
> mouvement. La reconfirmation périodique reste disponible en paramètre (`DeadmanReconfEnable := TRUE`,
> réactivation par recompilation uniquement).
>
> 🔧 **2026-08-06 — Décision utilisateur, ANNULE partiellement la grâce ci-dessus** : le "temps
> illimité pour démarrer après armement" (`LeftNeutralSinceArm`) créait un armement qui ne se
> désarmait JAMAIS si le joystick restait au neutre sans qu'aucun mouvement ne soit démarré —
> `DeadmanArmed` pouvait rester collé à `TRUE` d'une session à l'autre. Retour terrain : un
> bouton IHM (Mode Boutons) se déclenchait sans toucher le joystick à cause de cet armement
> résiduel. Décision : neutre tenu `NeutralHoldTime` désarme désormais **toujours**, qu'un
> mouvement ait été démarré depuis l'armement ou non. `LeftNeutralSinceArm` retiré du code.

### Paramètres

| Paramètre | Défaut | Rôle |
|---|---|---|
| `DeadmanReconfEnable` | `FALSE` | `FALSE` = consentement au démarrage (mouvement libre) ; `TRUE` = reconfirmation périodique en mouvement |
| `DeadmanRearmTimeout` | `T#10S` | Délai de reconfirmation (n'agit que si `DeadmanReconfEnable=TRUE`) |
| `NeutralHoldTime` | `T#100MS` (🔧 2026-08-07, réduit de 500ms) | Neutre tenu avant désarmement |
| `DeadmanArmHoldTime` | `T#100MS` (🆕 2026-08-07) | Appui bouton maintenu avant armement |
| `DeadmanArmGraceTime` | `T#3S` (🆕 2026-08-07) | Délai après armement avant que le désarmement neutre (`NeutralHoldTime`) puisse s'appliquer |

### Armement
🔧 2026-08-07 (retour terrain) : ancien armement "front bouton **et** axes strictement à 0.0 sur le
MÊME scan" retiré — trop contraignant (poussait le joystick quelques ms après l'appui = jamais armé).
Nouveau : front bouton démarre un maintien `DeadmanArmHoldTime` (100 ms) ; à l'issue du maintien,
armé — **indépendamment** de la position des axes pendant ce délai. Relâché avant la fin du
maintien = tentative annulée, nouvel appui (front) exigé. Sûr même si le joystick est déjà hors
zone morte à l'armement : les rampes accel/décel restent gérées par les FB aval (FB_Winch/FB_Translation).

### Désarmement
| Cause | Condition |
|---|---|
| Gate | Enable / AU / CAN / device |
| Neutre tenu | `NeutralHoldTime` (100 ms) au neutre, **que le geste ait démarré un mouvement ou non** (🔧 2026-08-06 — avant : uniquement après avoir quitté le neutre au moins une fois), **applicable seulement après `DeadmanArmGraceTime` (3s) écoulées depuis l'armement** (🆕 2026-08-07 : sans cette grâce, l'armement — qui se fait typiquement AU neutre — se désarmait ~100-200ms après lui-même) |
| Timeout présence | Uniquement si `DeadmanReconfEnable=TRUE` : armé + hors neutre + bouton **relâché** ≥ 10 s |
| Changement mode | `Mode <> LastMode` |
| Fin benne | Front descendant `BenneBusy` **si** `NOT PreserveArmingAfterBucket` |

Avec reconfirmation (`TRUE`) : maintenir le bouton **ou** le réappuyer en mouvement remet le timer
10 s (niveau, pas seulement front). Sans (`FALSE`, défaut) : aucun désarmement lié au bouton en mouvement.

### 4bis. Mode Boutons IHM : pas d'homme-mort joystick (🔧 2026-08-06)

`PRG_04_Treuils_Benne.st` (`M1_StartStop_Active`/`M2_StartStop_Active`) n'exige `DeadmanArmed`
que si `GVL_IHM.Modes.Cmd.TglJoystickMaster=TRUE` (Mode Joystick Maître) :
```
AND (NOT GVL_IHM.Modes.Cmd.TglJoystickMaster OR PRG_02_Acquisition.JoystickDeadmanArmed);
```
**Décision utilisateur** : en Mode Boutons IHM (`TglJoystickMaster=FALSE`), le consentement
continu est déjà assuré par le maintien du bouton IHM lui-même (`BtnUp`/`BtnDown` : appui
maintenu = mouvement, confirmé terrain) — pas besoin d'un second homme-mort physique sur le
joystick, qui n'est de toute façon pas utilisé pour piloter dans ce mode ("si pas joystick on
est en manu donc pas d'homme mort"). L'homme-mort du joystick physique reste exigé **uniquement**
en Mode Joystick Maître, où il a un sens (main sur le manche = présence confirmée).

### Exception Extraction (documentée)
`PreserveArmingAfterBucket` évite le désarmement en fin de fermeture auto pour enchaîner palier 1
sous interlocks Extraction. **Hors** cet état, toute fin benne désarme (pas de M1/M2 surprise).

⚠️ Désarmement ⇒ cibles rampe à 0 ⇒ **décélération normale**, pas coupure puissance.

---

## 5. Calibration et défauts

| Règle | Détail |
|---|---|
| Front `BtnCalibrate` | Si RawX/Y ∈ [2000 ; 8000] → écrit neutres mem |
| Sinon | `ErrorId` bit0 (`16#0001`) |
| Reset | Front + Raw encore dans plage → clear bit0 |
| Neutres | Persistants (`_JoystickNeutralX/Y`) |

### 5bis. Procédure calibration terrain (SITE)

| # | Étape | Attendu |
|---|---|---|
| 1 | Manche **relâché physiquement** (repos mécanique) | — |
| 2 | Front `BtnCalibrate` (IHM) | `NeutralXAct`/`NeutralYAct` ← `RawX`/`RawY` courants |
| 3 | Vérifier `NeutralXAct`/`NeutralYAct` proches de **5000** ±quelques centaines | Sinon jeu mécanique/capteur à investiguer |
| 4 | Débattement complet des 2 axes, les 4 directions | `SpeedRef` atteint ±100 % de façon symétrique |
| 5 | Redémarrage/download PLC | Neutre **conservé** (persistant) — pas de recalibration surprise |

⚠️ **Point ouvert** : présence confirmée d'un bouton `BtnCalibrate` sur l'écran HMI **non
vérifiée** dans ce lot (variable IHM existe côté PLC, `ST_JoystickCmd`, mais l'écran WebVisu/HMI
lui-même n'a pas été inspecté). À valider avant mise en service.

| TC | Attendu | Type |
|---|---|---|
| TC-P08-009 | Neutre persiste après download/redémarrage PLC | SITE |
| TC-P08-010 | Bouton calibration accessible et fonctionnel sur écran HMI réel | SITE |

---

## 6. Intégration programme

```text
Acquisition  HwIn.Operator (réel/sim)
Acquisition  Diag CAN + instJoystick          ← producteur unique consignes joy
Modes  Mode (lu N−1 par joy)
Cycle  CycleMotionPermit := DeadmanArmed AND AxisCmdY.StartStop
Treuils  Winch : joy + DeadmanArmed + sélecteur treuil
Translation  Translation : AxisCmdX + DeadmanArmed
Supervision  Mapping IHM JOY1Joystick.State
```

Consommateurs **doivent** combiner `AxisCmd*.StartStop` **et** `DeadmanArmed`
(déjà le cas Winch/Trans/Cycle — TC-P08-013).

Cible archi AF02 : Joystick reste dans le domaine **Acquisition** (page CFC acquisition),
pas une page mouvement.

---

## 7. IHM

| DUT | Contenu |
|---|---|
| `ST_JoystickCmd` | `BtnCalibrate` |
| `ST_JoystickState` | Raw, AxisCmd, neutres, DeadmanArmed, Online/OP, Error |

Réglages invert/deadband/rates : PERSISTENT (pas tous dans Cmd IHM — détail P07 / code).

---

## 8. Alertes et points ouverts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | info | Doc v1.3 disait encore debug/`SafeStop`/IsCentral | **Corrigé** par v2.0 |
| 2 | P1 métier | Exception `PreserveArmingAfterBucket` | Ne jamais élargir hors CLOSING Extraction |
| 3 | info | Retard 1 scan Mode/BenneBusy → deadman | Accepté ; ne pas « corriger » par GVL |
| 4 | info | `Enable` toujours TRUE | OK si aval Modes/Safety tiennent ; pas de gate Modes dans le joy |
| 5 | mineur | Miroirs Speed/Direction dupliquent AxisCmd | Garder pour MES ; pas de 3ᵉ copie |
| 6 | — | `IsCentralPositionX/Y` | **Absents du code** — neutre = deadband Scale / seuil 0,1 rampe |
| 7 | site | Checklist MES joy | Exécution terrain (ex-T17) hors cette AF |

Pas de surcharge identifiée justifiant un refactor immédiat du FB : composition claire,
une instance, gate fail-safe.

---

## 8bis. TBD — Filtre par défaut et double rampe Joystick↔FB de mouvement

> ⛔ **Non tranché, pas d'autorisation de coder.** Discussion utilisateur 2026-07-30 sur le
> risque d'interférence entre la rampe `FB_Joystick` et la rampe/tempo palier de `FB_Winch`/
> `FB_Translation`. Section de suivi ; décision et code dans un lot dédié, contrat de tâche requis
> (C3/C4 — accélération/décélération treuil = sécurité machine).

### 8bis.1 Filtre PT1 par défaut — supprimé (retour terrain 2026-08-07)

`_JoystickFilterTime` : `T#100ms` → `T#50ms` (2026-08-06) → **`T#0ms`** (2026-08-07, `GVL_PERSISTENT`
+ défaut `FB_Joystick.st`), décidé sur retour terrain répété : délai joystick→contacteur de sens
toujours perceptible même à 50ms. `T#0ms` = pass-through exact, documenté et supporté nativement
par `FB_Filter_PT1.st` ("Si TimeConst=0, sortie=entrée") — pas un contournement, un mode prévu.
Contrepartie assumée : plus aucun lissage du bruit capteur Hall — à surveiller de près (chatter
contacteur sur signal bruité, plus de marge comme avec 50ms). Pas de calcul théorique substitué
à l'essai terrain qui a validé chaque palier de réduction.

### 8bis.2 Double rampe en cascade — ⚠️ constat périmé (code déjà sans `FB_Ramp` côté joystick)

> Vérifié 2026-08-06 : `FB_Joystick.st` actuel n'instancie **aucun** `FB_Ramp` (pipeline réel :
> `FB_AxisScale` → `FB_Filter_PT1` → homme-mort, voir §2). `_JoystickAccelRate_Pct`/
> `_JoystickDecelRate_Pct` (`GVL_PERSISTENT`) sont **orphelins** — plus référencés nulle part
> dans `CODE/`. Le TBD ci-dessous décrivait un état du code antérieur à cette vérification ;
> conservé pour mémoire mais **la double rampe qu'il décrit n'existe plus**. Nettoyage des
> RETAIN orphelins non fait dans ce lot (hors périmètre demandé).

Constat historique (au moment de la rédaction initiale) :

```text
FB_Joystick : Scale → Filter PT1 → FB_Ramp (Accel 50%/s, Decel 150%/s, RETAIN _JoystickAccelRate_Pct/_JoystickDecelRate_Pct)
                                        ↓ SpeedRef déjà rampé
FB_Winch / FB_Translation : reçoit SpeedRef → sa PROPRE FB_Ramp (paramètres séparés)
```

Deux rampes indépendantes en série composent une décélération dont le comportement résultant
est difficile à prédire/régler — constat technique vérifié, pas une hypothèse.

**Proposition en discussion (non tranchée)** :

| Domaine | Aujourd'hui | Piste discutée |
|---|---|---|
| Translation (M3) | 2 rampes en cascade | Retirer `FB_Ramp` du Joystick ; garder l'unique rampe déjà présente dans `FB_Translation` (mapping continu %→Hz, une rampe a du sens) |
| Winch (M1/M2) | 2 rampes + hystérésis palier + tempo 1s500ms | Le joystick sort un **% brut filtré, sans rampe** ; toute la temporisation/lissage vit dans `FB_Winch`/`FB_SpeedStep` (paliers discrets, pas de vitesse continue) — voir AF10 §9bis |

**Effet de bord identifié** : la rampe joystick sert aussi à adoucir le désarmement homme-mort
(`RampX(Target := SEL(DeadmanArmed, 0.0, ...))`). Si retirée, ce lissage doit être repris par
la rampe du FB de mouvement aval (déjà présente dans les deux cas) — pas de perte de sécurité
identifiée, mais **à valider explicitement avant code**.

**TBD à trancher** :
- Confirmer le retrait de `FB_Ramp` dans `FB_Joystick` (impact : 3 FB, RETAIN orphelins
  `_JoystickAccelRate_Pct`/`_JoystickDecelRate_Pct` à traiter)
- Devenir de la rampe %/s dans `FB_Winch` une fois le double-lissage supprimé — lié à AF10 §9bis
  (T93 : tempo par palier plutôt que rampe continue)

---

## 9. Documents liés

| Doc | Lien |
|---|---|
| AF02 | Acquisition / pas page joy autonome |
| AF03 | Profil non-mouvement, Reset front |
| AF05 | Modes, sélecteur treuil, désarmement au change mode |
| AF06 | Raw Operator / sim |
| AF07 | `ST_JoystickHMI` |
| AF10 / AF11 | Consommateurs AxisCmd + DeadmanArmed (Treuils Benne incluse · Translation) ; exception Extraction |
| AF13 | `FB_Sim_Joystick` amont |
| Code | `CODE/JOYSTICK/FB_Joystick.st`, `FB_AxisScale.st`, `FB_Filter_PT1.st`, `ST_Joystick_AxisCmd.st` |
