# ✅ Checklist Mise en Service — Joystick (v1.0)

> 🎯 **Rôle** : checklist terrain (recette machine réelle), pas une spec fonctionnelle. Répond à
> `DOC/PLAN_TASK_v1.0.md` T17. Complète `AF_Partie-08_Fonction_Joystick_v1.3.md` (§3, §4, §6bis)
> sans le modifier.
> 🗓️ Créée 2026-07-19. Audit strictement documentaire — **aucun `CODE/` modifié**.
> 🚫 Hors périmètre : paliers codeurs/vitesse (`FB_SpeedStep`), séquenceur cycle (`FB_Cycle`) —
> voir checklists dédiées si besoin.
> 📄 Sources auditées : `AF_Partie-08_Fonction_Joystick_v1.3.md`, `CODE/JOYSTICK/FB_Joystick.st`,
> `CODE/JOYSTICK/FB_AxisScale.st`, `CODE/COMMUN/FB_Ramp.st`, `CODE/DIAG/FB_DiagCanOpen.st`,
> `CODE/MAIN/PRG_01_Diagnostics.st`, `CODE/MAIN/PRG_09_Supervision.st`,
> `CODE/SUPERVISION/ST_JoystickHMI.st`, `CODE/GVL_PERSISTENT.st`, `CODE/SIMULATION/GVL_Simulation.st`.

---

## 🧰 0. Prérequis avant tout essai

| # | Vérification | Valeur attendue | Où lire |
|---|---|---|---|
| 0.1 | Mode simulation désactivé | `GVL_Simulation.SimulationModeActive = FALSE` | Vue instance CODESYS (pas d'IHM graphique — voir ⚠️ §6) |
| 0.2 | Signal joystick réel (pas simulé) | `GVL_Simulation.BusJoystickSignalIsReal = TRUE` | idem |
| 0.3 | Bus/nœud CANopen joystick réel (pas simulé) | `GVL_Simulation.BusJoystickIsReal = TRUE` | idem |
| 0.4 | Temporisations homme-mort en valeurs **production** (pas les valeurs test banc) | `PRG_01_Diagnostics.FB_Joystick_0.DeadmanRearmTimeout = T#10S` et `.NeutralHoldTime = T#500MS` | Vue instance `FB_Joystick_0` |

⚠️ **Point de vigilance majeur** (`PRG_01_Diagnostics.st` lignes 58-62, commentaire en l'état dans
le code) : ces temporisations basculent **automatiquement** entre valeurs test (5 min / 1 s, si
`NOT BusJoystickSignalIsReal`) et production (10 s / 500 ms, si signal réel) via un `SEL` sur
`BusJoystickSignalIsReal`/`SimulationModeActive`. Le point 0.2 ci-dessus est donc la **condition
racine** de 0.4 — si le signal reste marqué simulé par erreur (flag non repassé à `TRUE`), le
homme-mort réel tournera silencieusement avec des délais de confort (5 min de réarmement) au lieu
des délais sûrs (10 s) **sans qu'aucune alarme ne le signale**. À vérifier explicitement au
commissioning, pas supposé.

---

## 🎯 1. Calibration du neutre (`BtnCalibrate`, front)

| # | Procédure | Attendu | Pass/Fail |
|---|---|---|---|
| 1.1 | Manche au repos physique, déclencher `GVL_IHM.JOY1Joystick.BtnCalibrate` (front) | `NeutralXMem`/`NeutralYMem` (`FB_Joystick_0.NeutralXAct`/`NeutralYAct`) prennent la valeur `RawX`/`RawY` courante | Neutre affiché = brut lu au moment du front, à ±0 pt |
| 1.2 | Calibrer avec `RawX` ou `RawY` hors plage **2000..8000** (ex. manche non raccordé, 0 ou 10000) | Calibration **refusée**, `ErrorId` bit0 (`16#0001`) levé, `Error := TRUE` | FAIL si le neutre est quand même mémorisé hors plage |
| 1.3 | Après échec 1.2 : reset (front `Reset`) **avec** RawX/Y toujours hors plage | `ErrorId` bit0 **reste** levé (pas d'auto-effacement, cause non disparue) | FAIL si le défaut s'efface sans cause résolue |
| 1.4 | Ramener RawX/Y en plage valide, puis reset (front) | `ErrorId` bit0 s'efface, `Error := FALSE` | — |
| 1.5 | Couper puis remettre l'automate sous tension, sans recalibrer | Neutre conservé (`_JoystickNeutralX/Y` en `GVL_PERSISTENT`, `VAR RETAIN`, défaut 5000) | FAIL si le neutre revient à 5000 après coupure alors qu'il avait été recalé ailleurs |

📌 Le neutre calibré (`NeutralXAct`/`NeutralYAct`) et l'`ErrorId` de calibration ne sont **pas**
mirorés dans `GVL_IHM` (`ST_JoystickHMI` n'expose que `RawX/RawY/RawButton/CmdX/CmdY/Online/
Operational/Error/ErrorId` — pas les neutres) : la vérification 1.1/1.5 nécessite la vue instance
CODESYS en ligne sur `PRG_01_Diagnostics.FB_Joystick_0`, pas un écran opérateur (aucune IHM
graphique livrée à ce jour, cf. `PLAN_TASK_v1.0.md`).

---

## 🎚️ 2. Neutre & Deadband

| # | Procédure | Attendu | Pass/Fail |
|---|---|---|---|
| 2.1 | Manche au neutre calibré, lecture `SpeedXPct`/`SpeedYPct` | `0.0 %`, `DirectionX`/`DirectionY = 0` | FAIL si valeur résiduelle non nulle |
| 2.2 | Déflexion progressive jusqu'à 10 % (deadband par défaut) | `SpeedXPct`/`SpeedYPct` restent à `0.0` tant que `\|OutPct\| <= Deadband` (10.0 % câblé en dur dans `PRG_01_Diagnostics.st`) | FAIL si un mouvement de consigne apparaît sous 10 % |
| 2.3 | Déflexion juste au-delà de 10 % | Sortie proportionnelle non nulle apparaît immédiatement (pas de saut brutal, transition continue à la sortie de deadband) | — |
| 2.4 | Déflexion pleine échelle (manche en butée physique) | `SpeedXPct`/`SpeedYPct` → **100 %** exactement (pas au-delà) si `RawX`/`RawY` atteint bien 0 ou 10000 en butée | Voir §5 si dépassement |
| 2.5 | Symétrie Fwd/Rev | Écart de deadband/échelle comparable des deux côtés du neutre (asymétrie attendue **uniquement** si le neutre calibré n'est pas exactement à 5000 — `FB_AxisScale` recalcule l'échelle séparément de chaque côté du neutre, voir §2bis) | — |

📎 **§2bis — comportement attendu si neutre ≠ 5000** : `FB_AxisScale` calcule l'échelle côté
haut sur `(10000 - Neutral)` et côté bas sur `Neutral` — un neutre décalé (ex. 4500) donne une
plage physique différente de chaque côté (5500 pts vers le haut, 4500 vers le bas), ce qui est
**normal et attendu**, pas un défaut, tant que 100 % est atteint aux deux extrêmes physiques.

---

## 🔴 3. Homme-mort (armement / reconfirmation / désarmement)

| # | Procédure | Attendu | Pass/Fail |
|---|---|---|---|
| 3.1 | Appuyer le bouton **hors neutre** (manche dévié) | `DeadmanArmed` reste `FALSE` (armement refusé hors neutre) | FAIL si armé |
| 3.2 | Revenir au neutre, appuyer le bouton **au neutre**, puis dévier le manche | `DeadmanArmed := TRUE` dès l'appui au neutre ; mouvement effectif dès la déflexion (au-delà du deadband) | — |
| 3.3 | En mouvement (armé), **relâcher** le bouton | Décélération selon `DecelRate` (rampe, pas un arrêt brutal), `DeadmanArmed` reste vrai jusqu'à expiration de `DeadmanRearmTimeout` (10 s prod) **si aucune reconfirmation** | FAIL si arrêt instantané non rampé (devrait décélérer, pas couper) |
| 3.4 | En mouvement, **maintenir** le bouton enfoncé en continu au-delà de 10 s | Pas de désarmement (le maintien continu compte comme reconfirmation permanente — `NOT RawButton` doit rester `FALSE`) | FAIL si désarmement malgré maintien continu |
| 3.5 | En mouvement, **relâcher** le bouton et ne pas le réappuyer pendant > 10 s | `DeadmanArmed → FALSE` après 10 s exactement (± 1 cycle MainTask, 10 ms), rampe vers 0 déclenchée par la perte d'armement, pas par une coupure `Enable` | — |
| 3.6 | Revenir au neutre puis **tenir** le neutre ≥ 500 ms sans avoir bougé depuis l'armement (bouton toujours armé) | `DeadmanArmed` **reste `TRUE`** (garde `LeftNeutralSinceArm` — un opérateur qui arme puis hésite ne doit pas être désarmé avant d'avoir réellement bougé) | FAIL si désarmé alors qu'aucun mouvement n'a jamais commencé |
| 3.7 | Armer, bouger, revenir au neutre et **tenir** ≥ 500 ms | `DeadmanArmed → FALSE` (fin de geste normale) | — |
| 3.8 | Armer, bouger, **traverser rapidement le neutre en inversant le sens** (Fwd→Rev) sans s'y arrêter | `DeadmanArmed` **reste `TRUE`** (traversée < 500 ms ne compte pas comme fin de geste) | FAIL si désarmé sur une simple inversion de sens |
| 3.9 | Changer de Mode (MAINT_N1 → MAINT_N2 ou → SEMI_AUTO) pendant un geste armé en cours | `DeadmanArmed → FALSE` immédiatement au changement de mode, quel que soit l'état du manche | FAIL si l'armement survit au changement de mode |
| 3.10 | Reprise après désarmement (n'importe quelle cause 3.5/3.7/3.9) | Nouvel appui **au neutre** requis pour réarmer — un appui hors neutre après désarmement ne doit pas réarmer (revoir 3.1) | — |

---

## 🔌 4. Perte de communication CAN

| # | Procédure | Attendu | Pass/Fail |
|---|---|---|---|
| 4.1 | Débrancher/couper le bus CANopen pendant un mouvement armé | `BusCanOpenOP.Operational → FALSE` → gate `FB_Joystick` s'active : sorties forcées à 0, `DeadmanArmed → FALSE` immédiatement (coupure, pas rampe — c'est une perte de commande, pas un relâchement volontaire) | FAIL si le dernier ordre reste actif après perte CAN |
| 4.2 | Pendant la coupure CAN | `GVL_IHM.JOY1Joystick.ErrorId` bit0 (`16#0001`, perte liaison CAN) et/ou bit1 (`16#0002`, non-opérationnel) levés selon le cas | — |
| 4.3 | Rebrancher le bus | Retour à `Operational := TRUE` après reprise ; `ErrorId` s'efface sur reset (front) une fois le bus effectivement rétabli (pas d'auto-effacement sans front `Reset`) | — |
| 4.4 | Reset (front) **pendant que le bus est encore coupé** | `ErrorId` bits **restent** levés (cause encore présente) | FAIL si effacement prématuré |
| 4.5 | Après rebranchement + reset : réarmement homme-mort | Nouvel appui **au neutre** requis (comme après toute neutralisation, §3.1/3.10) — aucun mouvement ne doit reprendre "tout seul" à la reconnexion | FAIL si un mouvement repart sans nouvel appui bouton |

---

## ⚠️ 5. Valeurs incohérentes / hors plage capteur

| # | Procédure | Attendu | Pass/Fail |
|---|---|---|---|
| 5.1 | Injecter `RawX`/`RawY` **au-delà de 10000** ou **en dessous de 0** (simuler dérive/défaut capteur Hall, hors plage nominale 0..10000) | 🛡️ `FB_AxisScale`, `FB_Ramp` et la consigne finale M3 bornent la sortie : `SpeedXPct`/`SpeedYPct` restent dans ±100 % et `SpeedRefPct` M3 dans 0..100 %. **À confirmer dans CODESYS** | FAIL si une sortie hors plage est observée |
| 5.2 | Si 5.1 confirme un dépassement, vérifier l'effet en aval selon le consommateur | **M1/M2 (treuils)** : sans risque direct — `FB_SpeedStep` plafonne au palier 5 quel que soit le dépassement (paliers discrets, `MaxStepNumber`). **M3 (translation)** : une limitation finale est appliquée dans `PRG_07_TranslationControl` avant `FB_Translation` | FAIL si une sortie hors plage est observée |
| 5.3 | `RawX`/`RawY` figés (valeur constante suspecte, ex. capteur bloqué en butée) pendant un mouvement en cours | Aucune détection dédiée dans `FB_Joystick`/`FB_AxisScale` (pas de garde-fou "signal figé" identifié dans le code audité) — à la charge de la vigilance opérateur / d'un contrôle externe | Signaler si jugé nécessaire, hors périmètre modification |
| 5.4 | `RawButton` erratique (rebond, glitch électrique) pendant un geste armé | `DeadmanEdge` (`R_TRIG`) ne réagit qu'aux fronts — un rebond bref ne doit pas désarmer si le niveau reste globalement maintenu dans la fenêtre `DeadmanRearmTimeout` | FAIL si un simple rebond électrique désarme un geste en cours |

---

## 🧭 6. Limites de cette checklist (transparence)

- Aucune IHM graphique de supervision n'existe à ce jour (`visu/` vide, `GVL_IHM` seul) : toutes
  les vérifications de neutre calibré, `DeadmanArmed`, `ErrorId` détaillé se font via la **vue
  instance CODESYS en ligne**, pas un écran opérateur.
- §5.1/5.2 identifie un **écart potentiel de robustesse capteur** (limitation ajoutée après
  `FB_AxisScale`/`FB_Ramp`), confirmé par lecture de code mais **pas testé physiquement** dans le
  cadre de cet audit (documentaire, sans banc). À vérifier en priorité lors du premier essai
  terrain avec capteur réel avant confiance totale en la robustesse de la chaîne M3.
- Items T15 (source exacte `EmergencyStopOk`) et T16 (vestige `PRG_JOY1`) référencés par
  `AF_Partie-08` restent des tâches **distinctes** de T17 (voir `PLAN_TASK_v1.0.md`) — non
  traités ici. Pour information, l'audit de ce document confirme que `EmergencyStopOk` est déjà
  câblé sur un retour contacteur réel (`PRG_00_Inputs.EmergencyStopOk_DI`), plus un stub debug —
  T15 semble déjà résolu en l'état du code, à confirmer/clore séparément si le projet le souhaite.
