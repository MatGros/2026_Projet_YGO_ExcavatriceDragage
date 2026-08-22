# Analyse Fonctionnelle — Partie 8 : Fonction Joystick (v2.0)

> Rôle : acquisition et conditionnement du geste opérateur (Hall CANopen → consignes d'axe).
> **Pas** un FB de mouvement : pas de `SafeStop` / pas de pilotage Q.
> Source code : `CODE/D_JOYSTICK/FB_Joystick.st` · instance `Acquisition (CFC).instJoystick`.
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
| <nobr><code>TC-P08-001</code></nobr> | Perte contacteur / CAN ➔ désarmer, annuler axes, et lever `Error` (`ErrorId` bit2, auto-effacé au retour) | `SpeedRef=0`, `DeadmanArmed=FALSE`, `Error=TRUE` | `💻 AUTO` | <small>§3</small> |
| <nobr><code>TC-P08-002</code></nobr> | Armement homme-mort par maintien `DeadmanArmHoldTime` (100ms) ; relâchement **avant** la fin du maintien annule la tentative (pas d'armement différé) | Tenu 100ms ➔ armé / relâché avant ➔ `DeadmanArmed` reste `FALSE`, nouvel appui exigé | `⚡ SITE+AUTO` | <small>§4</small> |
| <nobr><code>TC-P08-003</code></nobr> | Bouton relâché en mouvement : **sans** reconfirmation (`DeadmanReconfEnable=FALSE`, défaut) armement conservé ; **avec** reconfirmation (TRUE) relâchement > 10 s ➔ désarmement | `DeadmanReconfEnable`/`DeadmanRearmTimeout` absents de `FB_Joystick.st` | `🔒 INTERFACE MANQUANTE` | <small>§4</small> |
| <nobr><code>TC-P08-004</code></nobr> | Neutre rapide (<100ms) conserve armement, prolongé désarme | Armement conservé / perdu | `💻 AUTO` | <small>§4</small> |
| <nobr><code>TC-P08-005</code></nobr> | Changement de mode ou fin benne désarme le joystick | `DeadmanArmed=FALSE` | `💻 AUTO` | <small>§4, §6</small> |
| <nobr><code>TC-P08-006</code></nobr> | Calibration hors [2000;8000] ➔ alarme `ErrorId` | Bit0 actif, `Reset` sur cause disparue | `💻 AUTO` | <small>§5</small> |
| <nobr><code>TC-P08-007</code></nobr> | `SpeedRef` signée [-100;+100] ; si `RawX`/`RawY` sort de la plage capteur (défaut/fil coupé) ⇒ arrêt (`SpeedRef=0`) + `ErrorId` bit1, pas de commande à pleine vitesse (voir exemple §5bis) | `SpeedRef=0`, `ErrorId` bit1 actif | `💻 AUTO` | <small>§1, §2, §5bis</small> |
| <nobr><code>TC-P08-008</code></nobr> | Winch, Translation et Cycle exigent `DeadmanArmed` | ⚠️ gate câblé dans le PRG de collage, pas dans un FB — vérifié par `G375` (note ↓), pas par `test_fb_joystick.st` | `🔒 GATE` | <small>§6</small> |
| <nobr><code>TC-P08-011</code></nobr> | Fin de cycle benne désarme par défaut (hors exception) | `DeadmanArmed=FALSE` | `💻 AUTO` | <small>§4, §6</small> |
| <nobr><code>TC-P08-012</code></nobr> | `PreserveArmingAfterBucket` conserve l'armement en fin de benne (exception CLOSING Extraction) | `DeadmanArmed` conservé | `💻 AUTO` | <small>§6, alerte P1</small> |
| <nobr><code>TC-P08-014</code></nobr> | Mise à l'échelle **proportionnelle** sur valeurs intermédiaires (`RawX=9000`→80%, `RawY=300`→-94%), pas seulement correcte aux bornes 0/10000/neutre | `SpeedRef` exact ±0.01%, `Direction` cohérent | `💻 AUTO` | <small>§1, §2</small> |

> ⚠️ **TC-P08-008 — pourquoi ce n'est PAS un test de FB**
>
> Le gate `AND (NOT TglJoystickMaster OR JoystickDeadmanArmed)` — celui qui interdit tout
> mouvement Winch tant que l'homme-mort du Joystick n'est pas armé — n'est écrit **dans
> aucun `.st` de FB**. Il est câblé directement dans le PRG qui fait communiquer les deux :
> `PRG_04_Treuils_Benne.st`. Ni `FB_Joystick` (qui ignore l'existence de Winch, responsabilité
> unique), ni un futur `FB_Winch` (le gate n'est pas dans son interface) ne peuvent donc le
> prouver par un test qui les instancie isolément — `TEST_AUTO_CI` teste des FB, pas des PRG.
>
> | | Ce que ça vérifie | Comment | Où |
> |---|---|---|---|
> | <nobr><code>TC-P08-002..005/011/012</code></nobr> | `FB_Joystick` *produit* bien `DeadmanArmed` | Test dynamique (compile + instancie + assert) | `TEST_AUTO_CI`, `test_fb_joystick.st` |
> | <nobr><code>TC-P08-008</code></nobr> (ce point) | Le PRG *consulte* bien `DeadmanArmed` avant d'autoriser un mouvement | Recherche textuelle dans le vrai code de production | `G375_check_deadman_arming_gate.py` (`TOOLS/AGENT_WORKFLOW/scripts/`), lancé par `run_all_gates.py` |
>
> D'où le type `🔒 GATE` (ni `AUTO` ni `SITE`) : un mécanisme automatisé existe bien et tourne
> à chaque lot de code — ce n'est juste pas un test de `FB_Joystick`.

---

## 1. Rôle et périmètre

| Fait | Détail |
|---|---|
| Entrée | 2 axes bruts 0..10000 + 1 bouton, nœud CANopen (ou sim amont) |
| Sortie | `ST_Joystick_AxisCmd` X/Y + `DeadmanArmed` + miroirs maintenance |
| Fait | Producteur d'**intention** de conduite, pas d'actionneur |
| Ne fait pas | Arbitrage mode, limites machine, frein, PowerCutOff, Q physiques |

Profil AF03 : contrat `light` (acquisition/conditionnement pur, aucun organe piloté). Gate :
`Enable`, diag CAN/device.

---

## 2. Pipeline et composition

```text
Raw ─► FB_AxisScale ─► Homme-Mort (0 si non armé) ─► ST_Joystick_AxisCmd
         deadband raw
```

| Brique | Rôle |
|---|---|
| `FB_AxisScale` | Neutre + deadband (compte brut ADC, 🔧 2026-08-07 : remplace le %) → % signé, borné ±100 |
| Homme-mort | Force la consigne à 0.0 si non armé (`DeadmanArmed = FALSE`) |

> 🔧 **2026-08-22 — `FB_Filter_PT1` retiré du pipeline** : le joystick est stable et ne doit
> **pas** être ralenti (aucun lissage). Décision : pas de filtre dans `FB_Joystick`.
> L'éventuel lissage de la consigne reste confié aux FB de mouvement aval si besoin.
> La fonction de filtrage PT1 est déplacée en généraliste `CODE/A_COMMUN/FB_Filter` (réutilisable).

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

Paramètres d'appel production (`Acquisition`) : deadband depuis `GVL_PERSISTENT` ;
`DeadmanRearmTimeout=T#10s`, `NeutralHoldTime=T#100ms` (🔧 2026-08-07, réduit de 500ms), `DeadmanReconfEnable=FALSE` (figé, défaut cible).

---

## 3. Interface publique (code actuel)

### Entrées

| Port | Producteur actuel |
|---|---|
| `Enable` | `TRUE` fixe dans Acquisition |
| `Reset` | `FaultMachineReset_IHM` |
| `Mode` | `Modes (CFC).instModes.Mode` (scan N−1) |
| `BenneBusy` | `Treuils.instBucket.Busy` (scan N−1) |
| `PreserveArmingAfterBucket` | Extraction Busy **et** état `CLOSING_BUCKET` |
| `BusCanOpenOP` / `JoystickOP` | `FB_Diag_CanOpen` |
| `RawX/Y`, `RawButton` | `Acquisition.HwIn.Operator` |
| `BtnCalibrate` | `GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate` |
| `Invert*`, `DeadbandRaw` | PERSISTENT |
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

**Gate** (`Enable` / master CAN OP / device OP) :
sorties axes à 0, `DeadmanArmed=FALSE`, timers deadman reset, `RETURN`.

La perte de `BusCanOpenOP.Operational` ou `JoystickOP.Operational` neutralise les sorties
(`Ready=FALSE`) et lève `ErrorId` bit2 (`16#0004`), auto-effacé dès le retour (catégorie
Info/Warning `CODE_QUALITY_STANDARDS.md §9` — pas un Fault à acquitter).

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

### 5bis. Surveillance capteur en fonctionnement (défaut hors plage ADC)

Distinct du §5 (calibration, front `BtnCalibrate` uniquement) : ici la surveillance est
**continue**, à chaque scan, pendant le fonctionnement normal.

| Règle | Détail |
|---|---|
| Détection | `RawX`/`RawY` hors `[0 - CST_RawOutOfRangeMargin ; 10000 + CST_RawOutOfRangeMargin]`, évalué en continu (pas seulement au front `BtnCalibrate`) |
| Marge de tolérance | `CST_RawOutOfRangeMargin := 500` — évite un faux défaut sur simple bruit ADC/léger dépassement près des bornes nominales |
| Effet immédiat | `AxisCmdX/Y.Enable := FALSE`, `SpeedRef := 0`, `StartStop := FALSE`, `Direction := 0` sur **les 2 axes** (confiance perdue dans tout le geste, pas seulement l'axe en défaut) — même traitement `Enable` que la perte bus (§3) : une donnée dont la validité n'est plus garantie ne doit jamais laisser un aval interpréter "commandé à 0" différemment de "non commandé" |
| Diagnostic | `ErrorId` bit1 (`16#0002`), pattern Cause/Ack (`CODE_QUALITY_STANDARDS.md §9`) : cause brute évaluée en continu, interlock (forçage neutre) toujours sur la cause brute, jamais sur l'acquittement |
| Reset | Toujours effectif (jamais conditionné) : acquitte l'affichage ; ré-alarme automatiquement si la cause est toujours/de nouveau présente |

**Exemples** (`Neutral = 5000`) :

| `RawX` | Zone | `SpeedRef` attendu |
|---|---|---|
| `10000` | Plage nominale (max) | `100` |
| `11000` | Hors plage + marge | `0` |
| `-1000` | Hors plage + marge (sens inverse) | `0` |

### 5ter. Procédure calibration terrain (SITE)

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
| <nobr><code>TC-P08-009</code></nobr> | Neutre persiste après download/redémarrage PLC | SITE |
| <nobr><code>TC-P08-010</code></nobr> | Bouton calibration accessible et fonctionnel sur écran HMI réel | SITE |

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
(déjà le cas Winch/Trans/Cycle — TC-P08-008).

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

### 8bis.1 Filtre PT1 — supprimé (décision 2026-08-22)

Historique du lissage joystick, désormais **caduc** :

`_JoystickFilterTime` : `T#100ms` → `T#50ms` (2026-08-06) → **`T#0ms`** (2026-08-07) sur retour
terrain (délai joystick→contacteur de sens toujours perceptible) — **puis `FB_Filter_PT1` retiré
du code et du pipeline (2026-08-22)** : le joystick est stable et ne doit **pas** être ralenti.
`_JoystickFilterTime` supprimé de `GVL_PERSISTENT`. La fonction de filtrage PT1 reste disponible
en généraliste dans `CODE/A_COMMUN/FB_Filter` si un besoin de lissage apparaît ailleurs
(le lissage éventuel de la consigne est confié aux FB de mouvement aval).

### 8bis.2 Double rampe en cascade — ⚠️ constat périmé (code déjà sans `FB_Ramp` côté joystick)

> Vérifié 2026-08-06 : `FB_Joystick.st` actuel n'instancie **aucun** `FB_Ramp` (pipeline réel :
> `FB_AxisScale` → homme-mort, voir §2). `_JoystickAccelRate_Pct`/
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
| Code | `CODE/D_JOYSTICK/FB_Joystick.st`, `FB_AxisScale.st`, `ST_Joystick_AxisCmd.st` |
