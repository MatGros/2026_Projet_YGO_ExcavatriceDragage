# orchestrate run r-muccone7-ffbkqx

- mode: supervisor | agent: session-3cf1e901-98db-432f-be72-298fcfb8b4bf | provider: spawn
- concurrency: 6 | durationMs: 778612 | aborted: false
- startedAt: 2026-09-22T07:26:19.759Z | finishedAt: 2026-09-22T07:39:18.371Z

## Trace chaîne M1 MAINT_N2 [completed]

Bannière du briefing projet (gabarit SKILL_BANNER) :

```text
============================================================
🎬 BRIEFING SESSION WORKFLOW PROJET — TÂCHE READ-ONLY
   Chaîne commande manuelle M1 en MAINT_N2 (câblage boutons)
============================================================
```
Briefing session Excavatrice de Dragage — analyse par sous-agent (traçage code, zéro modification).

J'ai lu les fichiers réels (pas d'export), chaque fait est cité `fichier:ligne`. **Aucun fichier modifié** (tâche READ-ONLY).

---

# 🪝 Chaîne de commande manuelle M1 en mode MAINT_N2 — rapport de traçage

## 0. Vue d'ensemble (de l'amont vers la sortie physique)

```
BtnM1Ascent/Descend
   │ (ST_MaintenanceN2Cmd.st:9-10 — actuellement ⛔ NON CÂBLÉS vers un moteur)
   ▼
ARBITRAGE  FB_WinchCmdArbitrationM1 (PRG_04) ──> RunRequest/ReqAscent/ReqDescend/StepTgt
   ▼
ReqM1Winch (struct) ──> FB_Winch (PRG_04 §6)
   ▼
WinchM1FinalInterlockRequest ──> FB_WinchOutputInterlock (PRG_06 §1)  [🏛️ barrière finale]
   ▼
M1RelayFwd/Rev + M1SpeedContactor1-4 + M1BrakeCmd  ──> protecteurs ──> DQ (PRG_06 §2ter/quater)
```

---

## 1. 🔒 Chemin FREIN M1 — référence câblée (point de départ sûr)

**Producteur → consommateurs, gardes exactes :**

| Étape | Fichier:ligne | Contenu / garde |
|---|---|---|
| Producteur boutons | `ST_MaintenanceN2Cmd.st:21-24` | `BtnM1BrakeRelease`, `BtnBothBrakeRelease` (freins) déclarés. |
| **Gate mode MAINT_N2 + AU + contacteur** | `PRG_06_Outputs.st:320-324` | `MaintenanceN2BrakeForceM1 := (Auth.Mode = E_Mode.MAINT_N2) AND EmergencyChainClosed_DI AND PowerContactorEngaged_DI AND (BtnBothBrakeRelease OR BtnM1BrakeRelease)` |
| Agrégation frein (OR sur commandes **finales**, jamais amont) | `PRG_06_Outputs.st:330` | `M1BrakeCmd := M1BrakeCmd OR MaintenanceN2BrakeForceM1` — branche parallèle bornée, les relais de sens/paliers/chaîne nominale ne sont **pas** modifiés par ce forçage. |
| Sortie physique | `PRG_06_Outputs.st:375` | `M1_BrakeRelease_RQ := M1BrakeCmd` |

**Garde du frein nominal** (la branche MAINT_N2 se greffe APRÈS) : `M1BrakeCmd := M1RelayFwd OR M1RelayRev` — jamais de frein desserré sans un sens validé (`PRG_06_Outputs.st:174,261,307`).

> ✅ **Le frein M1 est donc câblé et protégé** : il ne peut se desserrer qu'en MAINT_N2, avec chaîne AU fermée + puissance engagée, et il est structurellement couplé aux relais de sens.

---

## 2. 🕹️ Chemin MOUVEMENT M1 qui fonctionne (joystick/IHM) — étape par étape

| # | Étape | Fichier:ligne | Producteur → consommation / garde |
|---|---|---|---|
| P1 | **Producteur joystick/IHM** | `PRG_02_Acquisition` (joystick qualifié) ; boutons retenue `GVL_IHM.M1TreuilRetenue.Cmd.BtnAscent/Descend` | Alimentent `ArbIHM` |
| P2 | **Routage boutons → struct d'arbitrage** | `PRG_04_Treuils_Benne.st:492-493` | `ArbIHM.BtnAscentM1 := GVL_IHM.M1TreuilRetenue.Cmd.BtnAscent` / `BtnDescentM1` |
| P3 | **Config palier boutons** | `PRG_04_Treuils_Benne.st:523` | `ArbM1Cfg.BtnStepTgt := 5` (pleine vitesse) |
| P4 | **Arbitrage M1** | `FB_WinchCmdArbitrationM1.st:54-125` appelé `PRG_04_Treuils_Benne.st:530-540` | Sorties `RunRequest/ReqAscent/ReqDescend/StepTgt`. **Branche manuelle** (mode ≠ SEMI_AUTO) : boutons IHM si `NOT TglJoystickMaster` (`:68-87`), joystick si Select=1 (`:90-104`). Gating `RunRequest` (`:116-125`) : `ReqAscent XOR ReqDescend`, `NOT Context.BucketBusy`, `NOT WinchBothMotionBlockedByBucket`, `NOT SyncBlocks*`, `(NOT TglJoystickMaster OR DeadmanArmed)`, `AxisX=0`, atomicité Both. |
| P5 | **Publication M1Logic\*** | `PRG_04_Treuils_Benne.st:541-544` | `M1LogicRunRequest := instArbM1.RunRequest`, etc. `HOLD de transition` `WinchSelTransitionHold` force à 0 (`:572-575`). |
| P6 | **Struct ReqM1Winch** | `PRG_04_Treuils_Benne.st:1386-1418` | `RunRequest/ReqAscent/ReqDescend/SpeedStepReq := M1Logic*` ; bornes `MaxStep`, `MinStepDown` (plongée), `TopLimitM/BottomLimitM` |
| P7 | **FB_Winch (directeur)** | `FB_Winch.st:12-352`, appelé `PRG_04_Treuils_Benne.st:1457-1470` | `Enable := (Mode<>DISABLE) AND NOT InhibitM1` (MAINT_N2 ok). Permis `AscentPermit/DescendPermit := EffectivePermitM1_*` (`:1462-1463`) ; `SafeStop := SafeStopM1_Active`. Relais/Paliers `RelayFwd/Rev`, `Contactor1-4` (`:284-309`) + SpeedGuard + plancher descente (`:257-266`). |
| P8 | **Publication demande barrière** | `PRG_04_Treuils_Benne.st:1593-1612` | `WinchM1FinalInterlockRequest.Enable/Reset/PowerContactorEngaged/SafeStop/BrakeFeedback/RequestedRelayFwd/Rev/Contactor1-4/Step/Ascent+DescendPermit` |
| P9 | **Barrière finale** | `FB_WinchOutputInterlock.st` appelé `PRG_06_Outputs.st:149-165` | Gate `M1InterlockEnable` (`PRG_06:128-129`), re-contrôle PowerContactor/SafeStop/permis/DeadTime/RestartInhibit. Sorties `RelayFwd/Rev/Contactor1-4/AuthorizedStep` (`:167-174`). |
| P10 | **Protecteurs & concordance M1/M2** | `PRG_06_Outputs.st:280-291` puis `341-366` | Anti-chatter `CST_ContactorMinInterval` ; concordance contacteurs M1/M2. |
| P11 | **Sorties physiques** | `PRG_06_Outputs.st:369-375` | `M1_RelayAscent_RQ/Descent_RQ`, `M1_SpeedContactor_1..4_DQ`, `M1_BrakeRelease_RQ` |

---

## 3. 🏛️ Barrière finale M1 (plancher minimum à conserver en MAINT_N2)

Le `FB_WinchOutputInterlock` (`instWinchOutputInterlockM1`) **bloque le mouvement M1** si l'une de ces conditions est vraie :

| Condition barrière | Fichier:ligne | Nature |
|---|---|---|
| `M1InterlockEnable = FALSE` ⇔ `Enable` (PRG_04:1593, toujours TRUE) **OU `PowerCutOff`** (`WinchM1FinalInterlockRequest.PowerCutOff`) | `PRG_06_Outputs.st:128-129` ; source `instSafetyWinchM1.PowerCutOff` `PRG_04:1610` | Coupure dure (thermique, Méca A/B/C/D/E escalade — `FB_Safety_Winch.st:523-525`) |
| `PowerContactorEngaged = FALSE` (chaîne AU/puissance) | `PRG_06:152` ; gate interne aussi `FB_WinchOutputInterlock.st:148` | Coupure immédiate de toutes sorties |
| `SafeStop` (`WinchM1FinalInterlockRequest.SafeStop` = `SafeStopM1_Active`) | `PRG_06:153` ; `FB_WinchOutputInterlock.st:393` | Coupure rampe sans FAULT, `Enable` maintenu |
| **Permis directionnels** : `PermitFinalBlocked` ⇔ `(RelayFwd AND NOT AscentPermit) OR (RelayRev AND NOT DescendPermit)` | `FB_WinchOutputInterlock.st:186-187` | Défense en profondeur re-consommée (`effectivePermit` PRG_04:1111-1114) |
| `RestartInhibit` / `RestartRequired` (anti-redémarrage auto, latch à `Reset`) | `FB_WinchOutputInterlock.st:200-212, 357-363` | Jamais de redémarrage automatique après défaut |
| `DeadTimePending` (temps mort directionnel `DeadTimeSameDir/OppositeDir` 500/700 ms) | `:424-430` | Séquencement |
| Plancher de **montée de palette** `CST_StepRampFloorDelay := T#400ms` | `FB_WinchOutputInterlock.st:136, 431-455` | +1 cran / 400 ms max, défense en profondeur |

**En MAINT_N2**, `instWinchM1.Enable` et `instSafetyWinchM1.Enable` restent actifs (mode ≠ DISABLE) → la chaîne mouvement est **théoriquement ouverte**, mais bloquée par plusieurs gardes détaillées en §4.

---

## 4. 🎯 POINT D'INJECTION RECOMMANDÉ pour M1

**Recommandation : injecter `BtnM1Ascent`/`BtnM1Descend` dans l'entrée d'arbitrage `ArbIHM.BtnAscentM1`/`BtnDescentM1` — `PRG_04_Treuils_Benne.st:492-493`.**

```st
// PRG_04_Treuils_Benne.st (zone §3, lignes 492-493) — modification à cadrer (NON FAITE, read-only)
ArbIHM.BtnAscentM1  := GVL_IHM.M1TreuilRetenue.Cmd.BtnAscent
                       OR (GVL_IHM.MaintenanceN2State.Mode=MAINT_N2 AND GVL_IHM.MaintenanceN2Cmd.BtnM1Ascent);
ArbIHM.BtnDescentM1 := GVL_IHM.M1TreuilRetenue.Cmd.BtnDescent
                       OR (GVL_IHM.MaintenanceN2State.Mode=MAINT_N2 AND GVL_IHM.MaintenanceN2Cmd.BtnM1Descend);
```

**Justification :**
- **Point d'injection minimal** (2 lignes) : il produit **exactement** les mêmes demandes que le joystick/IHM — `RunRequest`, `ReqAscent`, `ReqDescend`, `StepTgt` (palier 5 via `ArbM1Cfg.BtnStepTgt`, `PRG_04:523`) — en réutilisant **intégralement** la chaîne existante : arbitrage (P4) → `M1Logic*` (P5) → `ReqM1Winch` (P6) → `FB_Winch` (P7) → barrière (P8/P9) → sorties (P10/P11).
- **Conserve TOUT le plancher sécurité de §3** : `SafeStop`, `EffectivePermitM1_*` (process+safety+NOT SafeStop+couplage), `PowerCutOff`, watchdog frein — car les guards sont ré-appliqués par `FB_Winch` et par la barrière finale. Aucune protection n'est courte-circuitée.
- **Aligné sur le contrat** : `FB_WinchCmdArbitrationM1` prévoit déjà une branche « boutons IHM » (`IHM.BtnAscentM1/BtnDescentM1`, `:75-82`) ; il suffit d'y amener les boutons MAINT_N2. C'est le mécanisme *intended* par le FB (commentaire `FB_WinchCmdArbitrationM1.st:70-87`).

**Alternative (moins sûre, non recommandée)** : injecter en aval, directement dans `M1LogicRunRequest/ReqAscent/ReqDescend` après `PRG_04:544` + `M1LogicRequestStepTgt := 5`. Fonctionnellement `FB_Winch` bloquerait encore via `DirectionConflict`, permis et `SafeStop`, **mais** on court-circuite l'arbitrage (atomicité Both, `SyncBlocks*`, `BucketBusy`, `RequestConflict`) → plus fragile pour un test couplé.

> ⚠️ **Précondition d'exploitation** : la branche boutons IHM n'est active que si `NOT TglJoystickMaster` (`FB_WinchCmdArbitrationM1.st:68`). En MAINT_N2, il faut garantir `TglJoystickMaster = FALSE` (sinon le joystick est requis et les boutons sont ignorés). À intégrer dans le cadrage du câblage.

---

## 5. ⚠️ Ruptures & ambiguïtés relevées (à trancher avant câblage)

| # | Rupture / ambiguïté | Preuve | Impact en MAINT_N2 |
|---|---|---|---|
| R1 | **`BtnM1Ascent/Descend` ne pilotent AUCUN moteur.** Le seul usage de `MaintenanceN2.Cmd.*` est un **diagnostic** `ActiveForcing` (`PRG_07_Supervision.st:705-710`) et les **freins** (`PRG_06:320-331`). `st ST_MaintenanceN2Cmd` n'est jamais consommé par l'arbitrage M1 | `PRG_07:705-716` ; `grep MaintenanceN2.Cmd` → seuls PRG_07 et PRG_06 freins | Confirmé : boutons moteur non câblés (état actuel) |
| R2 | **Perte com opérateur bloque le mouvement même en boutons :** `instCauses[0].Active = NOT (JoystickOnline OR JoystickOperational OR HeartbeatIhmOk)` → `SafeStop` | `FB_Safety_Winch.st:269`, `:516-521`, `:558` ; alimenté `PRG_04:937-939` | En MAINT_N2 **sans joystick**, `SafeStop` probablement actif → le mouvement M1 serait bloqué par la barrière (`PRG_06:153`). **À lever via bypass `OperatorComm` ou alimentation joystick/heartbeat** |
| R3 | **Descente M1 verrouillée par `WinchDescentAuth_M3`** (verrou de descente treuil si M3 pas à P1/Maintenance) | `PRG_04:1083-1084` ; `PRG_03:509-514` | En MAINT_N2, la descente M1 peut être bloquée au permit si `TglEnableWinchDescentLock_M3` actif sans position M3 validée |
| R4 | **Branche « boutons IHM » conditionnée à `NOT TglJoystickMaster`** — le forçage des boutons MAINT_N2 dépend du sélecteur joystick global | `FB_WinchCmdArbitrationM1.st:68-87` | Prédéterminer `TglJoystickMaster` en MAINT_N2 sous peine de boutons inopérants |
| R5 | **Atomicité / blocages `Context`** en mouvement MAINT_N2 unitaire : `SyncBlocksAscent/Descent` (déviation mineure) et `WinchBothMotionBlockedByBucket` restent appliqués par l'arbitrage | `PRG_04:510-512,517-521` ; `FB_WinchCmdArbitrationM1.st:116-125` | Si benne en cours ou écart synchro, M1 bouton sera neutralisé (attend, pas dangereux) |
| R6 | **Palier 5 (pleine vitesse) pour les boutons** : `ArbM1Cfg.BtnStepTgt := 5` alors que le commentaire `ST_MaintenanceN2Cmd` annonce « Palier 1 Vitesse Lente » | `PRG_04:523` ; `ST_MaintenanceN2Cmd.st:9-10` | **Incohérence** : en MAINT_N2/forçage unitaire, le palier est 5, pas 1. À confirmer (vitesse lente attendue → `BtnStepTgt := 1`) |

---

### 🔴 Verdict / recommandation livrable

1. **Injecter** `BtnM1Ascent/BtnM1Descend` à **`PRG_04_Treuils_Benne.st:492-493`** (entrée `ArbIHM`), gated par `Mode = MAINT_N2`, avec `TglJoystickMaster = FALSE` forcé en MAINT_N2.
2. **Résoudre R2** (alimentation joystick/heartbeat ou bypass opérateur) sinon SafeStop bloque tout mouvement — c'est la rupture la plus bloquante pour un essai boutons sans joystick.
3. **Trancher R6** (palier 5 vs palier 1) avec le responsable — sécurité ISO 13849 : un forçage de vitesse en maintenance doit rester au palier lent.
4. Conserver **intacte** la chaîne `FB_Winch` + `FB_WinchOutputInterlock` (plancher de §3) — aucune protection à contourner pour relier les boutons moteur.

*Rapport READ-ONLY : aucune modification effectuée. Toutes les références proviennent du code versionné (`CODE/*.st`), pas d'un export CODESYS.*

## Trace chaîne M2 MAINT_N2 [completed]

# 🪝 Chaîne de commande manuelle M2 en MAINT_N2 — Rapport de traçage

**Posture :** Traçage READ-ONLY (aucun fichier modifié). Toutes les preuves sont `fichier:ligne` sur la source active `CODE/*.st` (hors `CODE_BACKUP/`/`TOOLS/.tmp`, hors `Device.export`).

---

## 🎯 Conclusion au bout du rapport

**POINT D'INJECTION RECOMMANDÉ M2** — le plus petit ensemble réutilisant la totalité des gardes aval :

> 🔧 Dans **`FB_WinchCmdArbitrationM2.st`** (ou en amont dans **`PRG_04_Treuils_Benne.st:494-495`** qui alimente `ArbIHM.BtnAscentM2/BtnDescentM2`), câbler `GVL_IHM.MaintenanceN2.Cmd.BtnM2Ascent / BtnM2Descend` en **OR** sur les sources de la branche « Mode Boutons IHM » (`FB_WinchCmdArbitrationM2.st:104-111`), **gated par `Auth.Mode = E_Mode.MAINT_N2`** (homogène à la protection des freins, `PRG_06:320-331`). Ce point réutilise intégralement : arbitrage → `FB_Winch` (instWinchM2) → `FB_WinchOutputInterlock` → PRG_06. Aucune nouvelle garde à inventer ; le `StepTgt` est déjà poussé à `Cfg.BtnStepTgt` (palier 5).

---

## 1️⃣ Chemin FREIN M2 de référence (producteur → sortie)

**Producteur :** `GVL_IHM.MaintenanceN2.Cmd.BtnM2BrakeRelease` + `BtnBothBrakeRelease` (`ST_MaintenanceN2Cmd.st:22-24`) — **déjà câblé et protégé** — c'est LE modèle à suivre.

| Étape | Producteur | Consommateur | Garde exacte | Réf. |
|---|---|---|---|---|
| 1 | Bouton IHM frein | PRG_06 | — | `ST_MaintenanceN2Cmd.st:22-24` |
| 2 | PRG_06 → force frein M2 | `M2BrakeCmd` | `Mode=MAINT_N2` **ET** `EmergencyChainClosed_DI` **ET** `PowerContactorEngaged_DI` **ET** (`BtnBothBrakeRelease` OU `BtnM2BrakeRelease`) | `PRG_06_Outputs.st:325-329` |
| 3 | OR force sur sortie frein | `M2BrakeCmd` | `M2BrakeCmd := M2BrakeCmd OR MaintenanceN2BrakeForceM2` (OR sur commande finale, jamais sur demande amont) | `PRG_06_Outputs.st:331` |
| 4 | Sortie physique | `M2_BrakeRelease_RQ` | — | `PRG_06_Outputs.st:384` |

**Garde clé :** le frein n'est **jamais** desserré sans un sens valide en nominale (`M2BrakeCmd := M2RelayFwd OR M2RelayRev`, `PRG_06:262/308`) ; le forçage MAINT_N2 reste une **branche parallèle strictement bornée**, bornée à « MAINT_N2 + AU fermée + puissance engagée » (`PRG_06:310-324`). L'AU physique coupe l'énergie en amont.

---

## 2️⃣ Chemin MOUVEMENT M2 fonctionnel (joystick/IHM → sortie)

**Producteur nominal :** `GVL_IHM.M2TreuilBenne.Cmd.BtnAscent/BtnDescent` (mode boutons) ou `Joystick.AxisY` (mode joystick maître).

| Étape | Producteur → Consommateur | Garde / routage | Réf. |
|---|---|---|---|
| 1 | IHM `BtnAscent/BtnDescent` → `ArbIHM.BtnAscentM2/BtnDescentM2` | — | `PRG_04:494-495` |
| 2 | → `FB_WinchCmdArbitrationM2` (`instArbM2.IHM`) | `Auth`, `Joystick`, `BothIntent`, `Context`, `TglJoystickMaster` | `PRG_04:553-563` |
| 3 | **Mode Boutons** : `IHM.BtnAscentM2 → ReqAscent/StepTgt` (**POINT D'INJECTION**) | `IF NOT TglJoystickMaster` ; `StepTgt := Cfg.BtnStepTgt` (palier 5) ; sinon joystick (Select=2) | `FB_WinchCmdArbitrationM2.st:104-111` |
| 4 | Gating global `RunRequest` | `NOT WinchBothMotionBlockedByBucket` ; block synchro mineur ; joystick maître ⇒ Deadman armé ; atomicité both (`BothDirectionAuthorized`) ; anti-conflit sens | `FB_WinchCmdArbitrationM2.st:139-151` |
| 5 | → `ReqM2Winch` (RunRequest/ReqAscent/ReqDescend/SpeedStepReq) | bornes vitesse/limites | `PRG_04:1473-1493` |
| 6 | → `FB_Winch` (`instWinchM2`) | Enable = `Mode≠DISABLE ET NOT InhibitM2` ; SafeStop ; permits directionnels ; step shaper ; StepTgt→StepNumber | `PRG_04:1523-1536` |
| 7 | → `WinchM2FinalInterlockRequest` (RelayFwd/Rev/Contactor/Step) | `instWinchM2` = source | `PRG_04:1620-1626` |
| 8 | → **`FB_WinchOutputInterlock`** barrière finale (`instWinchOutputInterlockM2`) | `Enable=(M2InterlockEnable)` = `Enable ET NOT PowerCutOff` ; SafeStop ; Ascent/DescendPermit ; temps mort + `DeadTimeSameDir/OppositeDir` ; `RestartInhibit` (latch anti-redémarrage) ; plancher de cran +400ms | `PRG_06:191-192, 215-231` + `FB_WinchOutputInterlock.st:144-475` |
| 9 | → protecteurs anti-chatter relais sens + paliers | `CST_ContactorMinInterval=400ms` | `PRG_06:293-304` |
| 10 | Sorties physiques | `M2_RelayAscent_Close_RQ`, `M2_RelayDescent_Open_RQ`, `M2_SpeedContactor_x_DQ`, `M2_BrakeRelease_RQ` | `PRG_06:378-384` |

**Barrière finale = étage **immuable** :** `FB_WinchOutputInterlock.st:144-475` (gate `NOT Enable OU NOT PowerContactorEngaged` → coupure ; SafeStop/PermitFinalBlocked → coupure ; RestartDelay 500ms anti-court-cycle ; DeadTime 500/700ms directionnel ; §3bis maintien borné 400ms ; watchdog frein 500ms → latch).

---

## 3️⃣ Ruptures constatées

| Rupture | Preuve | Conséquence |
|---|---|---|
| 🔴 **`BtnM2Ascent/BtnM2Descend` ne commandent AUCUN moteur** | seuls consommateurs = `PRG_07_Supervision.st:707-708` (`ActiveForcing`, indicateur uniquement) ; aucune occurrence dans `PRG_04`/`PRG_06` | les boutons MAINT_N2 « mouvement » sont **morts** au sens commande |
| 🔴 Les boutons MAINT_N2 ne câblent ni `ArbIHM` ni `ReqM2Winch` | `PRG_04:494-495` / `1473-1493` n'utilisent que `M2TreuilBenne.Cmd.*` | le point d'injection nominal est libre (aucun conflit d'écriture) |
| ⚠️ `ActiveForcing` est **lecture seule** (`PRG_07:704-710`) | aucun `M*Ascent/Descend` n'est consommé ailleurs | pas de garde à lever, juste un câblage manquant |

---

## 4️⃣ Particularités M2 vs M1 (commande manuelle)

| Particularité | Preuve | Impact commande manuelle M2 |
|---|---|---|
| **Séquençage benne override** : si `BucketBusy ET BucketM2RunRequest ET (WinchSel=2 OU SEMI_AUTO)`, M2 suit la benne (override prioritaire sur les boutons) | `FB_WinchCmdArbitrationM2.st:65-82` | en MAINT_N2 avec jog benne actif, injecter un bouton M2 n'aura pas d'effet tant que l'override benne tourne (sécurité anti-désynchronisation, REX 2026-09-04) |
| **Atomicité both** : en `BothIntent.Active`, seul le permit agrégé du sens est valable (départ jamais isolé) | `FB_WinchCmdArbitrationM2.st:140-142` ; `FB_WinchCmdArbitrationM1` id. | si le point d'injection est une commande M2 **unitaire** (`BothIntent` inactif), ce verrou tombe naturellement |
| **Permis directionnels benne** : `M2Ascent/DescendPermitApplied` gated par `instBucket.M2_RunRequest` (défense en profondeur) | `PRG_04:1131-1134` | en forçage manuel pur (pas de benne), `instBucket.M2_RunRequest=FALSE` ⇒ le gate benne ne bloque pas |
| **Exemption vidage Trémie** : `WinchDescentAuth_M3=FALSE` coupe la descente M2 **sauf** si jog benne/programme benne actif | `PRG_04:1083-1089` | une « descente/ouverture » forcée M2 doit lever cette exemption ou être bornée au jog benne |
| **CoupledBoth** : `WinchBothMotionActive` (même sans `SyncEnable`, ex. MAINT_N2) propage SafeStop/permits entre les 2 treuils | `PRG_04:1103-1114` | en MAINT_N2, `SyncEnable` peut être faux mais `WinchBothMotionActive` reste actif si commande both ⇒ pas de départ isolé |
| **⚠️ MecaB "ErrorID:09" — à vérifier côté IHM** : dans le code, `MecaB` (absence confirmation arrêt contacteurs/frein) = `instCauses[8]` ⇒ **bit 8**, escadé SafeStop+PowerCutOff après `PostRampTimeout` ; `bit 9` = **MecaC** (glissement benne, `instCauses[9]`). Le n° « 09 » peut être le **numéro d'affichage IHM**, pas le bit interne | `FB_Safety_Winch.st:141-146, 502-525` ; `TON PostRampTimeout=3s` (`:49`) | MecaB/MecaC coupent la puissance M2 (`CausesPowerCutOffActive`, `FB_Safety_Winch:523-525`) → le chemin frein `PowerContactorEngaged_DI` et le mouvement tombent tant que non acquittés (`Reset` sur front) |
| MecaC/glissement benne n'est armé que si `BenneHoldStillActive` (toujours `FALSE` ici) | `FB_Safety_Winch.st:354` ; `PRG_04:1031` | inert pour la commande M2 pure |

---

## ✅ Point d'injection M2 recommandé (synthèse)

**`FB_WinchCmdArbitrationM2.st:104-111` (branche « Mode Boutons »)** — avec alimentation amont complémentaire en `PRG_04:494-495` :

```iecst
// dans PRG_04:494-495 (avant instArbM2)
ArbIHM.BtnAscentM2 := GVL_IHM.M2TreuilBenne.Cmd.BtnAscent
              OR ((Auth.Mode = E_Mode.MAINT_N2) AND GVL_IHM.MaintenanceN2.Cmd.BtnM2Ascent);
ArbIHM.BtnDescentM2 := GVL_IHM.M2TreuilBenne.Cmd.BtnDescent
              OR ((Auth.Mode = E_Mode.MAINT_N2) AND GVL_IHM.MaintenanceN2.Cmd.BtnM2Descend);
```

**Pourquoi ici :**
- Réutilise **100% de la chaîne de garde aval** (arbitrage → `FB_Winch` → barrière finale `FB_WinchOutputInterlock` → protecteurs → PRG_06) sans contourner une seule sécurité.
- `StepTgt` est déjà forcé à `Cfg.BtnStepTgt`=palier 5 en mode boutons (`FB_WinchCmdArbitrationM2.st:107/111`).
- Le gainage `Auth.Mode = MAINT_N2` est **homogène** à la protection frein existante (`PRG_06:320-331`) : aucun mouvement MAINT_N2 hors du mode autorisé, chaîne AU fermée et puissance engagée imposées plus bas par la barrière finale.
- Le câblage des **boutons physiques** se fait ensuite sur `GVL_IHM.MaintenanceN2.Cmd` (ou sur `M2TreuilBenne.Cmd`), sans toucher à la logique.

**Cas limites à lever avant câblage :** (a) jog benne override prioritaire en MAINT_N2 — décider si le forçage doit être bloqué pendant `BucketBusy` ; (b) exemption « vidage Trémie » pour la descente — la borne à `MAINT_N2` + absence de benne la lève déjà partiellement.

Tâche READ-ONLY — aucun fichier modifié. `BtnM2Ascent/BtnM2Descend` restent des boutons « morts » (indicateur `ActiveForcing` seul) jusqu'au câblage du point d'injection.

## Trace Both couple + séquencement benne [completed]

I have fully traced the path. Let me compile the final structured report.

---

============================================================
🎬 BRIEFING SESSION WORKFLOW PROJET / AGENTS.MD ACTIF
============================================================
Briefing session Excavatrice de dragage — **compréhension lecture-seule** du pilotage couplé (Both) en MAINT_N2 et de l'interférence benne. Aucun fichier modifié.

---

# 🪝 Rapport — Commande Couplée M1+M2 (Both) en MAINT_N2 & séquencement benne

**Objectif** : comprendre la commande manuelle COUPLÉE M1+M2, où brancher `BtnBothAscent/BtnBothDescend`, et l'effet du séquencement benne auto sur ce câblage. Purement READ-ONLY. Toutes références = `fichier:ligne` réels lus.

---

## 1. 🎯 Le chemin de commande JOYSTICK COUPLÉ M1+M2

La montée/descente couplée (les "deux bras" = les 2 treuils qui bougent ensemble) est produite par **`WinchBothIntent`**, publié par PRG_03, consommé par les 2 FB d'arbitrage M1/M2. Deux sources amont convergent : **joystick** (Select=0) et **boutons Both** (`GVL_IHM.Commun.BtnWinchBothAscent/Descent`, déjà câblés).

### Tableau étape par étape

| # | Étape | Fichier:ligne | Contenu |
|---|-------|---------------|---------|
| 1 | **Joystick physique** | `CODE\M_MAIN\PRG_02_Acquisition.st:492` | `Data.Joystick.AxisCmdY ← instJoystick.AxisCmdY` |
| 2 | **FB_Joystick** (sémantique sens) | `CODE\D_JOYSTICK\FB_Joystick.st:278-307` | `AxisCmdY.DirectionPositive := CmdYVal>seuil`, `DirectionNegative`, `AtNeutral`. `Direction := +1` (pull/montée) / `-1` (push/descente) / `0` (neutre) — lignes 305-307. `StepTgt` 1..5. |
| 3 | **Convention Pull=Montée** | `CODE\F_MODES\FB_Modes.st:113-114`, `CODE\M_MAIN\PRG_03_Modes_Cycle.st:113-114` | `JoystickPull := AxisY.DirectionPositive` ; `JoystickPush := AxisY.DirectionNegative`. |
| 4 | **Intention both (joystick)** | `CODE\M_MAIN\PRG_03_Modes_Cycle.st:150-154` | Si `TglJoystickMaster` : `WinchBothMotionDirection := AxisY.Direction` ; `WinchBothMotionActive := DeadmanArmed AND SelectArbitrated=0 AND Mode<>SEMI_AUTO`. |
| 5 | **Intention both (boutons)** | `CODE\M_MAIN\PRG_03_Modes_Cycle.st:156-164` | Si bouton : `BtnWinchBothAscent→Direction=1`, `BtnWinchBothDescent→Direction=-1` ; `WinchBothMotionActive := (Direction<>0) AND Mode<>SEMI_AUTO`. |
| 6 | **Publication bus** | `CODE\M_MAIN\PRG_03_Modes_Cycle.st:328-330` | `Data.WinchBothIntent.Active/ReqAscent/ReqDescend` (intention unique tous modes). |
| 7 | **Consommation PRG_04** | `CODE\M_MAIN\PRG_04_Treuils_Benne.st:284-286` | `WinchBothMotionActive/ReqAscent/ReqDescend ← WinchBothIntent`. |
| 8 | **Arbitrage M1** | `CODE\H_TREUILS_BENNE\FB_WinchCmdArbitrationM1.st:94-98` (joystick) / `:70-74` (boutons) | `BothIntent.Active` → `ReqAscent/ReqDescend := BothIntent.*`, `StepTgt := Joystick.StepTgt` (joystick) ou `Cfg.BtnStepTgt` (boutons). |
| 9 | **Arbitrage M2** | `CODE\H_TREUILS_BENNE\FB_WinchCmdArbitrationM2.st:123-127` (joystick) / `:99-103` (boutons) | Idem M1. Asymétrie : chemin benne en tête (lignes 65-82) si `Arbitrated=2` ou `SEMI_AUTO`. |
| 10 | **Gate RunRequest M1** | `FB_WinchCmdArbitrationM1.st:116-125` | `RunRequest := (ReqAscent OR ReqDescend) AND NOT RequestConflict AND NOT BucketBusy AND NOT WinchBothMotionBlockedByBucket AND NOT SyncBlocks AND ... AND BothDirectionAuthorized`. |
| 11 | **Gate RunRequest M2** | `FB_WinchCmdArbitrationM2.st:143-151` | Idem + **synchro inversée** (lignes 145-146). |
| 12 | **Résultat arbitrage** | `PRG_04_Treuils_Benne.st:541-544` / `:564-567` | `M1LogicRunRequest/M2LogicRunRequest` + `M1LogicRequestStepTgt`. |
| 13 | **Route vers FB_Winch** | `PRG_04_Treuils_Benne.st:1389` / `:1476` | `ReqM1Winch.SpeedStepReq := M1LogicRequestStepTgt` (idem M2) → `instWinchM1( instWinchM2(` (lignes 1457/1523). |
| 14 | **Sorties M1/M2** | `FB_Winch.st` (via PRG_06) | Relais Fwd/Rev + palier + frein → moteurs physiques. |

> 🔑 **Point clé** : l'arbitre M1/M2 consomme l'intention **`WinchBothIntent`** — la même, quelle que soit l'origine (joystick Select=0 **ou** boutons Both). C'est le point d'émulation M1+M2 simultanés.

---

## 2. 📍 Où brancher `BtnBothAscent/BtnBothDescend` (injection recommandée)

### État actuel
- `BtnBothAscent/BtnBothDescend` déclarés inactifs : `ST_MaintenanceN2Cmd.st:13-14`, mais **consommés nulle part pour le mouvement** — seuls `PRG_07_Supervision.st:709-710` les lisent (diagnostic `ActiveForcing`) et `PRG_06_Outputs.st:323-329` lit les boutons **frein** (pas les mouvements).
- Le chemin Both **fonctionnel existant** est `GVL_IHM.Commun.BtnWinchBothAscent/BtnWinchBothDescent` (`ST_CommunHMI.st:37-38`), déjà consommé par `PRG_03_Modes_Cycle.st:156-159`.

### ➡️ Point d'injection recommandé
Câbler `ST_MaintenanceN2Cmd.BtnBothAscent` → **`GVL_IHM.Commun.BtnWinchBothAscent`** et `BtnBothDescend` → **`GVL_IHM.Commun.BtnWinchBothDescent`**.

C'est l'injection **exactement identique** aux M1+M2 simultanés : elle alimente `WinchBothMotionDirection` (`PRG_03:156-164`) → `Data.WinchBothIntent` (`:328-330`) → `instArbM1/instArbM2` `BothIntent` branch (`FB_WinchCmdArbitrationM1:70-74/94-98`, `M2:99-103/123-127`) → `FB_Winch` → sorties M1/M2.

*Preuve que c'est le bon point unique* : `PRG_03:156` (bouton) ET `:151` (joystick) alimentent la **même variable** `WinchBothMotionDirection`.

⚠️ **Ne pas** injecter en parallèle dans `ArbIHM.BtnAscentM1 + BtnAscentM2` (`PRG_04:492-495`) : ce chemin est unitaire (M1 séparé de M2), perdrait l'atomicité Both et l'anti-conflict `RequestConflict`.

---

## 3. 🪣 Le blocage par `FB_BucketCmdArbitration` — conditions exactes & application en MAINT_N2

### Conditions exactes d'armement

| Flag armé | Condition | Fichier:ligne |
|-----------|-----------|---------------|
| **WinchBothDiveBucketOpenArmed** (descente benne ouverte) | `TglEnableCoupledBucketSequencing` **AND** `Mode<>SEMI_AUTO` **AND** `NOT CoupledPhaseLocked` **AND** `MotionActive AND ReqDescend` **AND** `NOT BucketIsOpen` | `FB_BucketCmdArbitration.st:49-53` |
| **WinchBothAscentBucketCloseArmed** (montée benne fermée) | Idem avec `ReqAscent` **AND** `NOT BucketIsClosed` | `FB_BucketCmdArbitration.st:54-58` |

### Le refus silencieux — chaîne complète

| # | Étape | Fichier:ligne |
|---|-------|---------------|
| 1 | `ST_CommunCfg.st:29` — `TglEnableCoupledBucketSequencing := TRUE` (défaut) → injecté `PRG_04:315` | |
| 2 | `FB_BucketCmdArbitration` arme dive-open/ascent-close (cf. tableau) | `:49-58` |
| 3 | `PRG_04:330-331` capture les 2 flags | |
| 4 | **Garde-fou** `WinchBothMotionBlockedByBucket := WinchBothDiveBucketOpenArmed AND NOT instBucket.Lifecycle.Busy` | `PRG_04_Treuils_Benne.st:396` |
| 5 | Routing vers l'arbitre : `ArbContext.WinchBothMotionBlockedByBucket := WinchBothMotionBlockedByBucket` | `PRG_04_Treuils_Benne.st:510` |
| 6 | **M1** : `RunRequest := ... AND NOT Context.WinchBothMotionBlockedByBucket` → **FALSE** | `FB_WinchCmdArbitrationM1.st:118` |
| 7 | **M2** : idem → **FALSE** | `FB_WinchCmdArbitrationM2.st:144` |

### S'applique-t-il en MAINT_N2 ? **OUI**

`FB_BucketCmdArbitration` est appelé inconditionnellement (`PRG_04:323-329`, `Enable:=TRUE`, `Auth := PRG_03.Data.Auth`) et sa condition `Mode<>SEMI_AUTO` est **VRAIE en MAINT_N1/MAINT_N2**. Donc en MAINT_N2, une demande Both montée/descente avec benne dans le mauvais état **bloque RunRequest M1 **et** M2** via `WinchBothMotionBlockedByBucket`.

### ⚠️ Subtilité physique déterminante pour le câblage Both (joystick vs boutons)

Le séquencement **joystick** fonctionne parce que `FB_Modes.st:375-393` (T248) **force `JoystickWinchSelectArbitrated := 2` (jog benne)** pendant la phase d'ouverture/fermeture, puis revient à `0` (couplé). **Or ce mécanisme est déclenché uniquement par `JoystickPull/JoystickPush` (déflexion du manche)** — `FB_Modes.st:377` :

```st
ELSIF CoupledBucketSeqEnable AND (JoystickWinchSelectRequest = 0) AND (JoystickPull XOR JoystickPush) THEN
```

Une pression sur **`BtnBothDescend` maintient le manche au neutre** (`JoystickPull=Push=FALSE`). Donc :

1. **T248 ne force PAS le sélecteur à 2** → `JoystickWinchSelectArbitrated` reste à la valeur choisie par l'opérateur.
2. `FB_BucketCmdArbitration` arme bien `WinchBothDiveBucketOpenArmed` et émet `CmdOpen_IHM` (`FB_BucketCmdArbitration:62`), mais **M2 ne suivra la benne que si `Arbitrated=2`** — sinon l'override benne de `FB_WinchCmdArbitrationM2:65-67` est **inactif**.
3. Résultat : en sélecteur couplé (0) + `BtnBothDescend` benne non ouverte → **`WinchBothMotionBlockedByBucket` reste TRUE** (benne jamais ouverte, `Busy` jamais posé par M2) → **blocage silencieux total M1+M2**.

---

## 4. 📌 Impact du séquencement benne sur le câblage Both — doctrine de conduite

| Scénario MAINT_N2, `TglEnableCoupledBucketSequencing`=ON (défaut) | Comportement avec `BtnBoth*` câblés sur `Commun.BtnWinchBoth*` |
|---|---|
| Benne **dans l'état requis** (`IsClosed` pour la montée / `IsOpen` pour la descente) | ✅ Both monte/descend normalement. Pas d'armement → pas de blocage. |
| Benne **pas dans l'état requis**, opérateur en **sélecteur couplé (0)** | 🚫 **Blocage silencieux M1+M2.** L'auto-ouverture via `CmdOpen_IHM` ne se concrétise pas (M2 ne suit pas en couplé). Doit d'abord amener la benne manuellement (jog `WinchSel=2`) OU désactiver le toggle. |
| Benne pas dans l'état requis, opérateur passe d'abord en `WinchSel=2` (jog benne) | ✅ Jog benne ouvre/ferme (override M2 actif), puis retour sélecteur 0 → Both part. |
| `TglEnableCoupledBucketSequencing`=OFF (bouton IHM) | ✅ Comportement brut : 2 treuils sans condition benne (par conception, `ST_CommunCfg.st:26-28`). |

### 3 recommandations de câblage (sans modifier le séquencement, en s'y pliant)

1. **Câbler `BtnBothAscen/Descend` → `GVL_IHM.Commun.BtnWinchBothAscen/Descend`** uniquement — point d'injection unique, atomique, identique au joystick.
2. **En sélecteur couplé + benne mauvaise** : le mouvement est légitimement refusé. Ne pas contourner par un bypass — c'est la protection mécanique benne. Le comportement attendu est **exactement le même que le joystick** : amener la benne à l'état requis (jog `WinchSel=2`) avant de demander le couplé.
3. **Conscience du diagnostic** : le blocage est **silencieux** (aucun défaut fault, juste `RunRequest=FALSE`). Prévoir l'IHM `BothBlocked`/`BothBlockReason` (déjà produit `PRG_04:1141-1155`) pour guider l'opérateur — c'est l'objet de la tâche T375 (message IHM), à câbler en même temps que les boutons.

---

## Annexes — preuves fichier:ligne

- Boutons Both déclarés sans consommateur mouvement : `ST_MaintenanceN2Cmd.st:13-14`, `ST_MaintenanceN2HMI.st:8` (champ `Cmd`), `GVL_IHM.st:24` struct complète. Consommation seule : `PRG_07_Supervision.st:704-716` (diag) et `PRG_06:323-329` (freins).
- Boutons Both **câblés** (cible d'injection) : `ST_CommunHMI.st:37-38` → `PRG_03_Modes_Cycle.st:156-159`.
- Blocage benne : `ST_CommunCfg.st:29` → `FB_BucketCmdArbitration.st:49-58` → `PRG_04:330-331,396,510` → `FB_WinchCmdArbitrationM1:118` / `M2:144`.
- T248 (séquencement benne joystick) : `FB_Modes.st:364-393` (déclenchement sur `JoystickPull/Push`).
- Override benne M2 conditionné `Arbitrated=2` ou `SEMI_AUTO` : `FB_WinchCmdArbitrationM2.st:65-67`.

*Aucun fichier n'a été modifié — lecture seule.*

## supervisor [via researcher] [completed]

J'ai vérifié les faits critiques directement dans la source active, puis fusionné les 3 rapports. Livrable persiste : `DOC/WFLOW/PLAN_CABLAGE_MAINT_N2_Boutons_Moteurs.md`.

## Synthèse — Plan unique de câblage des 6 boutons moteur MAINT_N2

**Une phrase** : les 6 boutons existent en IHM (`GVL_IHM.MaintenanceN2.Cmd.*`) mais ne commandent **aucun** moteur (uniquement le diagnostic `ActiveForcing`, `PRG_07:705-710`) ; il faut les OR-résumer, **gated par `Auth.Mode = MAINT_N2`**, sur les 3 canaux canoniques existants.

| Bouton | Point d'injection exact | Preuve | Gardes conservées (aval) |
|---|---|---|---|
| **BtnM1Ascent/Descend** | `ArbIHM.BtnAscentM1/BtnDescentM1` | `PRG_04:492-493` | Gate RunRequest M1 `FB_...M1:116-125` (**NOT `BucketBusy`**, `WinchBothMotionBlockedByBucket`, `SyncBlocks`, atomicité Both, palier `Cfg.BtnStepTgt`=5 `PRG_04:523`) |
| **BtnM2Ascent/Descend** | `ArbIHM.BtnAscentM2/BtnDescentM2` | `PRG_04:494-495` | Gate RunRequest M2 `FB_...M2:143-151` (synchro inversée) — **sans** garde `NOT BucketBusy` |
| **BtnBothAscent/Descend** | `WinchBothMotionDirection` (amont de `Data.WinchBothIntent`) | `PRG_03:155-165,328-330` | `BothIntent.Active` gates M1/M2 (`M1:70-74/94-98`, `M2:99-103/123-127`), `WinchBothMotionBlockedByBucket` (`M1:118`, `M2:144`), `NOT SEMI_AUTO` |

Tous alimentent la même chaîne finale : `ReqM1/M2Winch` → `FB_Winch` → `WinchM1/M2FinalInterlockRequest` → `FB_WinchOutputInterlock` → `PRG_06:128-384` (relais, paliers, frein, concordance M1/M2).

## Ruptures & contradictions signalées (entre les 3 traces)

- **R1 (nomen. rapport M1 fausse)** : M1 citait `GVL_IHM.MaintenanceN2Cmd.*` / `...MaintenanceN2State.Mode`. Réalité : `GVL_IHM.MaintenanceN2.Cmd.*` (`ST_MaintenanceN2HMI.st:8`) et `ST_MaintenanceN2State` **n'a pas de champ `Mode`**. La porte canonique est `PRG_03...Auth.Mode=MAINT_N2` (`PRG_06:320`, `PRG_07:704`).
- **R2 (rupture commune)** : boutons moteur N2 **non câblés** (0 consommateur de commande) — le câblage est manquant, pas à lever.
- **R3 (asymétrie M1/M2)** : M1 a `NOT Context.BucketBusy` (`FB_...M1:117`) ; M2 **n'en a pas** (`M2:143-151` ne garde que `WinchBothMotionBlockedByBucket`). Un bouton unitaire M2 peut demander du mouvement pendant `Lifecycle.Busy` — à cadrer.
- **R4 (both bouton vs joystick)** : le séquencement T248 ne s'arme **que sur déflexion du manche** (`FB_Modes.st:375-377`, `JoystickPull XOR JoystickPush`). Un appui `BtnBoth*` ne la déclenche pas ⇒ refus silencieux de `WinchBothMotionBlockedByBucket` (`PRG_04:396`) sans correction automatique de benne.
- **R5/R6 (point both)** : ne pas injecter dans `ArbIHM.BtnWinchBoth*` (`PRG_04:496-497`) ni écraser `GVL_IHM.Commun.BtnWinchBoth*` ; injecter en amont du calcul de `WinchBothMotionDirection`.

Le séquencement benne s'applique bien en MAINT_N2 (`instArbBucket` inconditionnel, `Mode≠SEMI_AUTO` vraie) via `FB_BucketCmdArbitration.st:49-58` + `PRG_04:396`.

## Limite (posture)
Je suis un sous-agent en portée **lecture seule** : le plan décrit le câblage au niveau **variable/signal** (OR + porte mode sur les 5 lignes précisées), **aucun code inventé ni écrit**. Toute implémentation réelle dans `CODE/*.st` doit passer par le workflow AGENTS.md (contrat C2+, plan validé, puis gates mécaniques) piloté par l'orchestrateur.

## summary

supervisor 结论：J'ai vérifié les faits critiques directement dans la source active, puis fusionné les 3 rapports. Livrable persiste : `DOC/WFLOW/PLAN_CABLAGE_MAINT_N2_Boutons_Moteurs.md`.

## Synthèse — Plan unique de câblage des 6 boutons moteur MAINT_N2

**Une phrase** : les 6 boutons existent en IHM (`GVL_IHM.MaintenanceN2.Cmd.*`) mais ne commandent **aucun** moteur (uniquement le diagnostic `ActiveForcing`, `PRG_07:705-710`) ; il faut les OR-résumer, **gated par `Auth.Mode = MAINT_N2`**, sur les 3 canaux canoniques existants.

| Bouton | Point d'injection exact | Preuve | Gardes conservées (aval) |
|---|---|---|---|
| **BtnM1Ascent/Descend** | `ArbIHM.BtnAscentM1/BtnDescentM1` | `PRG_04:492-493` | Gate RunRequest M1 `FB_...M1:116-125` (**NOT `BucketBusy`**, `WinchBothMotionBlockedByBucket`, `SyncBlocks`, atomicité Both, palier `Cfg.BtnStepTgt`=5 `PRG_04:523`) |
| **BtnM2Ascent/Descend** | `ArbIHM.BtnAscentM2/BtnDescentM2` | `PRG_04:494-495` | Gate RunRequest M2 `FB_...M2:143-151` (synchro inversée) — **sans** garde `NOT BucketBusy` |
| **BtnBothAscent/Descend** | `WinchBothMotionDirection` (amont de `Data.WinchBothIntent`) | `PRG_03:155-165,328-330` | `BothIntent.Active` gates M1/M2 (`M1:70-74/94-98`, `M2:99-103/123-127`), `WinchBothMotionBlockedByBucket` (`M1:118`, `M2:144`), `NOT SEMI_AUTO` |

Tous alimentent la même chaîne finale : `ReqM1/M2Winch` → `FB_Winch` → `WinchM1/M2FinalInterlockRequest` → `FB_WinchOutputInterlock` → `PRG_06:128-384` (relais, paliers, frein, concordance M1/M2).

## Ruptures & contradictions signalées (entre les 3 traces)

- **R1 (nomen. rapport M1 fausse)** : M1 citait `GVL_IHM.MaintenanceN2Cmd.*` / `...MaintenanceN2State.Mode`. Réalité : `GVL_IHM.MaintenanceN2.Cmd.*` (`ST_MaintenanceN2HMI.st:8`) et `ST_MaintenanceN2State` **n'a pas de champ `Mode`**. La porte canonique est `PRG_03...Auth.Mode=MAINT_N2` (`PRG_06:320`, `PRG_07:704`).
- **R2 (rupture commune)** : boutons moteur N2 **non câblés** (0 consommateur de commande) — le câblage est manquant, pas à lever.
- **R3 (asymétrie M1/M2)** : M1 a `NOT Context.BucketBusy` (`FB_...M1:117`) ; M2 **n'en a pas** (`M2:143-151` ne garde que `WinchBothMotionBlockedByBucket`). Un bouton unitaire M2 peut demander du mouvement pendant `Lifecycle.Busy` — à cadrer.
- **R4 (both bouton vs joystick)** : le séquencement T248 ne s'arme **que sur déflexion du manche** (`FB_Modes.st:375-377`, `JoystickPull XOR JoystickPush`). Un appui `BtnBoth*` ne la déclenche pas ⇒ refus silencieux de `WinchBothMotionBlockedByBucket` (`PRG_04:396`) sans correction automatique de benne.
- **R5/R6 (point both)** : ne pas injecter dans `ArbIHM.BtnWinchBoth*` (`PRG_04:496-497`) ni écraser `GVL_IHM.Commun.BtnWinchBoth*` ; injecter en amont du calcul de `WinchBothMotionDirection`.

Le séquencement benne s'applique bien en MAINT_N2 (`instArbBucket` inconditionnel, `Mode≠SEMI_AUTO` vraie) via `FB_BucketCmdArbitration.st:49-58` + `PRG_04:396`.

## Limite (posture)
Je suis un sous-agent en portée **lecture seule** : le plan décrit le câblage au niveau **variable/signal** (OR + porte mode sur les 5 lignes précisées), **aucun code inventé ni écrit**. Toute implémentation réelle dans `CODE/*.st` doit passer par le workflow AGENTS.md (contrat C2+, plan validé, puis gates mécaniques) piloté par l'orchestrateur.
