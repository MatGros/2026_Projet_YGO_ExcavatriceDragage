# Analyse Fonctionnelle — Partie 8 : Fonction Joystick (v2.2)

> **Version** : v2.2 — 2026-08-25 — refonte selon `GUIDE_EDITION_AF_v1.0.md` (TC macro, table
> fonctions, sections normées)
> 🔗 **Dépend de** : AF02 (architecture), AF03 (contrats FB/DUT), AF06 (acquisition)
> 📄 **CODE associé** : `CODE/D_JOYSTICK/FB_Joystick.st`, `FB_AxisScale.st`, `ST_Joystick_AxisCmd.st`
> · instance `PRG_02_Acquisition.instJoystick`

## 📑 Sommaire

1. [🎯 Rôle et périmètre](#1--rôle-et-périmètre)
2. [🧪 Table des points de validation](#2--table-des-points-de-validation)
3. [🔄 Pipeline et composition (F08.01, F08.02)](#3--pipeline-et-composition-f0801-f0802)
4. [🔌 Interface publique](#4--interface-publique)
5. [🔫 Homme-mort (F08.03, F08.04)](#5--homme-mort-f0803-f0804)
6. [📡 Calibration et défaut capteur (F08.05, F08.06)](#6--calibration-et-défaut-capteur-f0805-f0806)
7. [🔒 Interlock consommateurs (F08.07, F08.08)](#7--interlock-consommateurs-f0807-f0808)
8. [🖥️ IHM, Configuration & Dépannage](#8--ihm-configuration--dépannage)
9. [📜 Suivi historique](#9--suivi-historique)
10. [❓ TBD](#10--tbd)
11. [📚 Documents liés](#11--documents-liés)

---

## 1 · 🎯 Rôle et périmètre

- **Rôle** : convertir le geste opérateur (manche 2 axes + bouton, nœud CANopen) en
  intention de conduite exploitable par les FB de mouvement, avec sécurité homme-mort intégrée.
- **Périmètre strict** : acquisition, mise à l'échelle, homme-mort, défaut capteur, calibration.
  Ne fait **pas** : arbitrage mode/sélecteur, limites machine, frein, `PowerCutOff`, pilotage Q
  physique — **ni** la décision de qui a le droit d'armer (`ArmingPermit` = entrée externe).
- **Type de composant** : Producteur d'intention (pas un FB de mouvement).
- **Contrat AF03** : `standard` (remonte défaut capteur/calibration/bus via `Status : ST_FbStatus`).

### Table des fonctions

| ID | Fonction | Description | Réalisée par | Criticité | TC couvrants | Statut |
|---|---|---|---|---|---|---|
| `F08.01` | Acquérir axes + bouton | Lit `RawX`/`RawY`/`RawButton` (bus CANopen ou image simulée) | `FB_Joystick` | 🔵 C2 | <nobr><code>TC-P08-010</code></nobr> | ✅ |
| `F08.02` | Mettre à l'échelle | Brut ADC → % signé ±100, deadband ADC sur neutre persistant, saturation stricte | `FB_AxisScale` | 🔵 C2 | <nobr><code>TC-P08-010</code></nobr> | ✅ |
| `F08.03` | Armer homme-mort | Maintien bouton `DeadmanArmHoldTime` (100ms) **ET** `ArmingPermit=TRUE` | `FB_Joystick` | 🔴 C4 | <nobr><code>TC-P08-020</code></nobr> | ✅ |
| `F08.04` | Désarmer homme-mort | `ArmingPermit=FALSE` (immédiat) **ou** neutre tenu `NeutralHoldTime` après grâce `DeadmanArmGraceTime` (3s) | `FB_Joystick` | 🔴 C4 | <nobr><code>TC-P08-020</code></nobr> | ✅ |
| `F08.05` | Détecter défaut capteur | `RawX`/`RawY` hors `[0;10000]` ± marge 500 → `SpeedTgt=0` 2 axes + Warning | `FB_Joystick` | 🟠 C3 | <nobr><code>TC-P08-030</code></nobr> | ✅ |
| `F08.06` | Calibrer neutre | Front `BtnCalibrate` en zone `[2000;8000]` → mémorise neutre persistant, sinon Fault | `FB_Joystick` | 🔵 C2 | <nobr><code>TC-P08-040</code></nobr> | ⚠️ SITE non exécuté |
| `F08.07` | Interdire mouvement sans armement | Consommateur combine `AxisCmd*.StartStop AND DeadmanArmed` avant tout ordre translation ; **partiel** sur treuils (voir §Intégration) | `PRG_04`/`PRG_05` (câblage), vérifié par `gate` `G375` | 🔴 C4 | <nobr><code>TC-P08-050</code></nobr> | ⚠️ partiel (treuils) |
| `F08.08` | Signaler armement refusé | `ArmingPermitDenied := RawButton AND NOT ArmingPermit` (warning IHM) | `FB_Joystick` | ⚪ C1 | <nobr><code>TC-P08-060</code></nobr> | ⚠️ non testé |

> `TC-P08-010` couvre `F08.01`+`F08.02` (même pipeline acquisition+échelle) ; `TC-P08-020` couvre
> `F08.03`+`F08.04` (armement+désarmement, même TC macro) — partage volontaire (règle guide 3-6
> TC macro), pas un oubli.

---

## 2 · 🧪 Table des points de validation

| <nobr>ID Unique</nobr> | Groupe | Comportement Attendu | <nobr>Type</nobr> | <nobr>Réf FB</nobr> |
|---|---|---|---|---|
| <nobr><code>TC-P08-010</code></nobr> | **Acquisition & échelle** | `RawX=9000→80%`, `RawY=300→-94%` proportionnel (pas seulement aux bornes) ; deadband ADC centrée neutre | <nobr><code>💻 AUTO</code></nobr> | <small><code>FB_AxisScale</code></small> |
| <nobr><code>TC-P08-020</code></nobr> | **Homme-mort** | Armement maintien+permission ; relâché avant fin = annulé ; désarmement (décélération normale, pas coupure) sur `ArmingPermit=FALSE` ou neutre tenu après grâce 3s | <nobr><code>💻 AUTO</code></nobr> | <small><code>FB_Joystick</code></small> |
| <nobr><code>TC-P08-030</code></nobr> | **Défaut capteur** | Hors plage ±marge ➔ `SpeedTgt=0` 2 axes, `ErrorId` bit1 Warning auto-effacé | <nobr><code>💻 AUTO</code></nobr> | <small><code>FB_Joystick</code></small> |
| <nobr><code>TC-P08-040</code></nobr> | **Calibration** | Hors `[2000;8000]` ➔ Fault bit0 à acquitter ; neutre persiste après redémarrage PLC | <nobr><code>⚡ AUTO+SITE</code></nobr> | <small><code>FB_Joystick</code></small> |
| <nobr><code>TC-P08-050</code></nobr> | **Gate consommateurs** | Translation refuse tout ordre sans `DeadmanArmed` (tous modes) ; Treuils **seulement** en mode Joystick Maître (asymétrie non tranchée, §7/Q2) | <nobr><code>🔒 GATE</code></nobr> | <small><code>G375_check_deadman_arming_gate.py</code></small> |
| <nobr><code>TC-P08-060</code></nobr> | **Armement refusé** | `ArmingPermitDenied=TRUE` pendant tout appui bouton si `ArmingPermit=FALSE` | <nobr><code>⬜ GAP</code></nobr> | <small><code>FB_Joystick</code></small> |

> ⚠️ **`TC-P08-050` n'est pas un test de FB** : le gate vit dans `PRG_04_Treuils_Benne.st` /
> `PRG_05_Translation.st` (câblage de collage), pas dans `FB_Joystick` (qui ignore Winch/Translation)
> ni dans un futur `FB_Winch` (le gate n'est pas dans son interface). Preuve = script, pas instance.
>
> ⚠️ **`TC-P08-060` = GAP** : `ArmingPermitDenied` existe et est câblé, mais aucun scénario ne le
> vérifie dans `test_fb_joystick.st`.

---

## 3 · 🔄 Pipeline et composition (F08.01, F08.02)

```text
RawX/Y ──► FB_AxisScale (deadband ADC + échelle ±100%) ──► Homme-mort (force 0 si non armé) ──► ST_Joystick_AxisCmd
```

Simulation (F08.01) : `FB_Sim_Joystick` ne simule que les entrées brutes ; le homme-mort réel de
`FB_Joystick` reste actif (pas de bypass, AF13).

---

## 4 · 🔌 Interface publique

### Entrées (`VAR_INPUT`)

| Port | Type | Rôle | Producteur actuel |
|---|---|---|---|
| `Enable` | `BOOL` | Active le bloc | `TRUE` fixe (`PRG_02_Acquisition`) |
| `Reset` | `BOOL` | Acquittement défaut (front) | `PRG_07_Supervision.FaultMachineReset_IHM` |
| `ArmingPermit` | `BOOL` | Seule permission d'armement — `FALSE` = armement bloqué + désarme un geste armé | ⚠️ `TRUE` câblé en dur, voir §10 Q1 |
| `BusCanOpenOP` / `JoystickOP` | `ST_Diag_Device` | Présence nœud CAN / device esclave | `FB_Diag_CanOpen` |
| `RawX` / `RawY` | `INT` | Axe brut (0..10000) | `HwIn.Operator` |
| `RawButton` | `BOOL` | Bouton homme-mort brut | `HwIn.Operator` |
| `BtnCalibrate` | `BOOL` | Demande recalage neutre | `GVL_IHM.JOY1Joystick.Cmd` |
| `DeadbandRaw` | `INT` | Zone morte ADC (déf. 300) | `GVL_PERSISTENT` |
| `NeutralHoldTime` / `DeadmanArmHoldTime` / `DeadmanArmGraceTime` | `TIME` | Temporisations (100ms/100ms/3s) | constantes d'appel |
| `RawOutOfRangeMargin` | `INT` | Marge défaut capteur (déf. 500) | constante d'appel |
| `NeutralXMem` / `NeutralYMem` (`IN_OUT`) | `INT` | Neutre persistant | `GVL_PERSISTENT` |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `AxisCmdX` / `AxisCmdY` | `ST_Joystick_AxisCmd` | Consigne normalisée (`Enable`, `StartStop`, `SpeedTgt`, `DirectionPositive/Negative`, `AtNeutral`) |
| `Button` | `BOOL` | = `RawButton` |
| `NeutralXAct` / `NeutralYAct` | `INT` | Neutre actif |
| `DeadmanArmed` | `BOOL` | Geste armé |
| `AtNeutral` | `BOOL` | 2 axes en zone morte |
| `ArmingPermitDenied` | `BOOL` | Warning : appui bouton pendant `ArmingPermit=FALSE` |
| `Ready` / `Error` | `BOOL` | État standard (socle `FB_FbStatus`) |
| `ErrorId` | `WORD` | Code défaut bitfield (socle `FB_FbStatus`) |
| `Status` | `ST_FbStatus` | Statut complet (socle `FB_FbStatus`) |
| `SpeedTgtX_Pct` / `SpeedTgtY_Pct` | `REAL` | Miroir maintenance `SpeedTgt` |
| `DirectionX` / `DirectionY` | `INT` | Miroir maintenance direction |

**Gate** (`NOT Enable OR BusLost`) : sorties à 0, `DeadmanArmed=FALSE`, timers reset, `RETURN` —
reset complet. Distinct de `RawOutOfRange` (défaut capteur, §Calibration) qui neutralise les
axes **sans** réinitialiser les timers d'armement homme-mort.

---

## 5 · 🔫 Homme-mort (F08.03, F08.04)

| Paramètre | Défaut | Rôle |
|---|---|---|
| `DeadmanArmHoldTime` | 100ms | Appui maintenu avant armement |
| `DeadmanArmGraceTime` | 3s | Délai après armement avant que le neutre puisse désarmer |
| `NeutralHoldTime` | 100ms | Neutre tenu avant désarmement (après grâce) |

Armement (F08.03) = front bouton → maintien 100ms → si `ArmingPermit=TRUE` au terme : armé,
**indépendamment de la position des axes**. Pas de reconfirmation périodique (le FB ne re-surveille
pas le bouton une fois armé).

Désarmement (F08.04) = `ArmingPermit=FALSE` (niveau, immédiat) **ou** neutre tenu après la grâce.

⚠️ **Ce que « immédiat » ne veut PAS dire** : perdre `ArmingPermit` ne coupe pas la puissance et
n'est pas un arrêt d'urgence — `DeadmanArmed:=FALSE` force `SpeedTgt:=0`/`StartStop:=FALSE`, ce qui
déclenche côté FB de mouvement aval (`FB_Winch`/`FB_Translation`) une **décélération normale**
(rampe palier existante), pas une coupure brutale. C'est la même sémantique que
`TC-P08-011`/`TC-P08-012` (v2.1, tests vivants `test_fb_joystick.st:451,492`) : un `ArmingPermit`
retiré en cours de geste armé — ex. fin de cycle benne — doit stopper le mouvement même bouton
tenu, par construction (c'est la raison d'être de `ArmingPermit`, voir §10 Q1). Si le besoin réel
est différent (ex. ne désarmer que sur relâchement effectif du bouton, jamais sur perte de
permission), c'est un changement de comportement `FB_Joystick` — code C4, hors périmètre d'une
mise à jour documentaire, à qualifier en tâche dédiée si confirmé.

---

## 6 · 📡 Calibration et défaut capteur (F08.05, F08.06)

| Mécanisme | Détection | Effet |
|---|---|---|
| Calibration (front `BtnCalibrate`) | Hors `[2000;8000]` | Fault bit0, à acquitter (Reset + axes en zone) |
| Défaut capteur (continu) | Hors `[0;10000]` ± marge 500 | `SpeedTgt=0` sur les 2 axes, Warning bit1 auto-effacé |
| Perte bus CAN (`BusCanOpenOP`/`JoystickOP` non opérationnel) | Continu | Gate complet (§Interface), Warning bit2 auto-effacé |

Neutre persistant (`NeutralXMem`/`NeutralYMem`), survit au redémarrage PLC.

---

## 7 · 🔒 Interlock consommateurs (F08.07, F08.08)

`AxisCmdY`/`DirectionY` → `PRG_04_Treuils_Benne` (M1/M2) · `AxisCmdX`/`DirectionX` →
`PRG_05_Translation` (M3), sélecteur `GVL_IHM.Modes.Cmd.TglJoystickMaster`.

| Consommateur | Exige `DeadmanArmed` | Preuve |
|---|---|---|
| Translation (M3) | **Tous les modes**, y compris boutons IHM | `PRG_05_Translation.st:186-187` — condition tautologique par construction |
| Treuils (M1/M2) | **Seulement** en mode Joystick Maître (`TglJoystickMaster=TRUE`) | `(NOT TglJoystickMaster OR JoystickDeadmanArmed)`, `PRG_04_Treuils_Benne.st:442,486` |

⚠️ **Asymétrie réelle, non tranchée** (F08.07 partiel sur treuils) : en pilotage boutons IHM
(`TglJoystickMaster=FALSE`), les treuils ne requièrent **pas** le homme-mort — contrairement à la
Translation. Bug à corriger ou comportement voulu (bouton IHM = geste conscient équivalent) ?
Arbitrage humain requis avant toute modification de `PRG_04` — voir §10 Q2.

F08.08 (`ArmingPermitDenied`) est un warning diagnostic pur (visibilité IHM d'un armement refusé),
sans effet sur le gate ci-dessus.

---

## 8 · 🖥️ IHM, Configuration & Dépannage

`ST_JoystickHMI` = `Cmd` (`BtnCalibrate`) + `State` (Raw, AxisCmd, neutres, `DeadmanArmed`,
`AtNeutral`, Online/Operational, Error/ErrorId). Pas de sous-struct `Cfg` dans `ST_JoystickHMI` —
mais des réglages existent bien, pas tous au même niveau de maturité :

| Réglage | Persistant ? | Réglable depuis un écran IHM ? |
|---|---|---|
| `DeadbandRaw` (`_JoystickDeadbandRaw`) | ✅ `GVL_PERSISTENT`, `RETAIN` | ❌ force CODESYS direct uniquement |
| `NeutralXMem`/`NeutralYMem` | ✅ `GVL_PERSISTENT`, `RETAIN` | ✅ via `BtnCalibrate` (F08.06) |
| `RawOutOfRangeMargin` | ❌ constante en dur (`PRG_02_Acquisition.st:314` = `500`) | ❌ |

`Bypass` : **existe**, mais pas porté par ce FB — `FB_Diag_CanOpen.NetworkBypassActive`/
`SimBypassActive` (AF12 Diagnostic) alimentent `DeviceJoystickOnlineEff`, source de
`BusCanOpenOP`/`JoystickOP` consommés directement par le gate `FB_Joystick`. Un bypass réseau IHM
peut donc masquer une perte de bus joystick — hors périmètre AF08, voir AF12.

Dépannage (`GVL_Troubleshooting.Joystick : ST_JoystickChecklist`) : vue chronologique dédiée
(`FB_TroubleshootingView.st`), champs parfois recalculés en doublon de l'IHM (ex. `NeutralXAct`
y est un `BOOL` "au neutre", vs `INT` valeur réelle dans `ST_JoystickState`) — voir AF14.

---

## 9 · 📜 Suivi historique

- **v2.0 → v2.1 (2026-08-25)** : resynchro interface réelle (`ArmingPermit` remplace
  `Mode`/`BenneBusy`/`DeadmanReconfEnable`/`DeadmanRearmTimeout`, retirés du code) ; profil AF03
  corrigé `standard` (était `light`, déjà inexact) ; `FB_Ramp`/`FB_Filter_PT1` confirmés absents.
- **Confirmé (2026-08-25)** : sémantique désarmement sur perte `ArmingPermit` (immédiat, niveau,
  décélération normale côté FB de mouvement aval — pas de coupure de puissance) **conservée
  volontairement**. Challengée (revue de l'ancien `CODE_20260807_v0.5.25` : `Mode`/`BenneBusy`
  désarmaient déjà activement un geste en cours, même logique) et tranchée : reste le comportement
  cible, pas juste hérité.
- **v2.1 → v2.2 (2026-08-25)** : refonte format selon `GUIDE_EDITION_AF_v1.0.md` — 14 TC détaillés
  consolidés en 6 TC macro (règle guide §3 : 3-6 max) ; suppression des redites entre corps et
  historique ; sections renumérotées et taguées par fonction `F08.xx` ; alerte `ArmingPermit`
  repliée dans le TBD (Q1) au lieu d'une section dédiée (une question non tranchée n'a qu'un seul
  domicile : le TBD).
- Archive : `ARCHIVES/Doc/AF_Partie-08_Fonction_Joystick_v2.0.md`.

---

## 10 · ❓ TBD

- **Q1 — `ArmingPermit` non câblé** (🔴 sécurité) : câblé en dur `TRUE` dans
  `PRG_02_Acquisition.st:303` (« câblage temporaire »), aucun producteur réel. Aucun désarmement
  automatique n'existe aujourd'hui sur changement de mode ou fin de cycle benne — trou de sécurité
  non compensé ailleurs. Piste de câblage proposée (non validée) :
  `DOC/WFLOW/AUDITS/PRG02_20260824/PROPOSITION_ArmingPermit_Cablage_v0.1.md`. Arbitrage humain
  requis, ne pas refermer sans décision — voir
  `DOC/WFLOW/AUDITS/PRG02_20260824/QUESTIONS_OUVERTES_PRG02_v0.1.md`.
- **Q2 — Homme-mort treuils en mode boutons IHM** (🔴 sécurité) : voir §7 — asymétrie
  Treuils/Translation, bug ou voulu ? Arbitrage humain requis avant de modifier `PRG_04`.
- Filtre par défaut et double rampe Joystick↔FB mouvement : non tranché, pas d'autorisation de
  coder (risque interférence rampe si réintroduite côté joystick).
- Présence bouton `BtnCalibrate` sur écran HMI réel : non vérifiée terrain.

---

## 11 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF02 | Architecture programme, `PRG_02_Acquisition` |
| AF03 | Contrat `standard`, socle `FB_FbStatus` |
| AF06 | `HwIn.Operator` (brut/sim) |
| AF07 | `ST_JoystickHMI` |
| AF10 / AF11 | Consommateurs `AxisCmdY`/`AxisCmdX` + `DeadmanArmed` |
| AF13 | `FB_Sim_Joystick` |
| Code | `CODE/D_JOYSTICK/FB_Joystick.st`, `FB_AxisScale.st`, `ST_Joystick_AxisCmd.st` |
