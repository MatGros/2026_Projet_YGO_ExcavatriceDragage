# Analyse Fonctionnelle - Partie 4 : Mode Semi-Auto & Sequenceur (v2.3)

> La traçabilité des versions programme/document est portée par `DOC/VERSION_HISTORY.md`.
> 🆕 v2.3 (2026-08-28) : Intégration du cycle Kobold 4 temps à la volée, bridage strict Palier $\le$ 4, enchaînement fluide d'extraction sous maintien continu joystick, gestion des bascules de mode sans perte d'étape et raccordement diagnostic Troubleshooting (`ST_ChainCycleSemiAuto`). Suite complète de tests unitaires STruCpp validée (14/14 PASS).

## 🎯 Rôle et périmètre

- **Rôle** : définir le mode semi-automatique, son séquenceur (grafcet `FB_Cycle`) et les briques de cycle transverses (`FB_DiveSearch`, `FB_ExtractionSequence`).
- **Périmètre & Architecture** : logique de séquence et demandes de mouvement produites. `PRG_03_Modes_Cycle` est l'unique instanciateur décisionnel de tous ces cycles. Les ordres sont transmis à `PRG_04_Treuils_Benne` via le bus public `Data.ReqProgram.ReqBucket`. Les sorties physiques directes restent hors de ce document (Partie 06/Outputs).
- **Type de composant** : `FB_Cycle`, `FB_DiveSearch`, `FB_ExtractionSequence` (briques ST transverses partagées Maintenance + Semi-auto).
- 🆕 Refonte du séquenceur conforme `GUIDE_SEQUENCEUR_v1.2.md` (§11bis R1-R9) : instance unique,
  homme-mort fenêtre 3 s, tempo max d'étape, `STABILIZING`.
  Conception : `DOC/WFLOW/AUDITS/DESIGN/DESIGN_SEMI_AUTO_CYCLE_v0.1.md`.

## 📑 Sommaire

1. [🧪 Points de validation](#1--points-de-validation)
2. [🧱 Principes](#2--principes)
3. [🪨 Petits cycles réutilisables](#3--petits-cycles-réutilisables)
4. [🔄 Cycle semi-auto (grafcet)](#4--cycle-semi-auto-grafcet)
5. [⚖️ Synchronisation pendant les mouvements](#5--synchronisation-pendant-les-mouvements)
6. [💬 Messages et diagnostics](#6--messages-et-diagnostics)
7. [📜 Suivi historique](#7--suivi-historique)
8. [❓ TBD](#8--tbd)
9. [📚 Documents liés](#9--documents-liés)

## 🧪 1 · Points de validation

> **État** : `V-I` validé et implémenté (tests automatisés STruCpp verts) · `V` validé doc · `NV` non validé.

| ID | Intention | Preuve | Type | Réf | État |
|---|---|---|---|---|---|
| <nobr><code>TC-P04-001</code></nobr> | Relâchement manche (retour centre) stoppe sans perte d'étape | `StartStop=FALSE`, étape inchangée | `💻 AUTO` | <small>§2</small> | `V-I` |
| <nobr><code>TC-P04-002</code></nobr> | Cycle produit des demandes, zéro sortie physique | Aucune Q/PDO écrite par `FB_Cycle` | `💻 AUTO` | <small>§2</small> | `V-I` |
| <nobr><code>TC-P04-003</code></nobr> | `STABILIZING` fige l'étape (hold sûr) | Étape figée, pas de reprise auto | `💻 AUTO` | <small>§4</small> | `V-I` |
| <nobr><code>TC-P04-004</code></nobr> | Reprise après `STABILIZING` : Cause + Reset + nouvel ordre | 3 conditions nécessaires | `💻 AUTO` | <small>§2</small> | `V-I` |
| <nobr><code>TC-P04-010</code></nobr> | `FB_DiveSearch` : mise en service recherche de couche | Transition READY -> SEARCHING | `💻 AUTO` | <small>§3</small> | `V-I` |
| <nobr><code>TC-P04-011</code></nobr> | Séquence Kobold 4 temps à la volée + coupure contacteur sur fond | Alimentation contacteur + coupure anti-chauffe | `💻 AUTO` | <small>§3</small> | `V-I` |
| <nobr><code>TC-P04-012</code></nobr> | Interdiction Palier 5 sous Kobold | Vitesse > 4 déclenche défaut bloquant immédiat | `💻 AUTO` | <small>§3</small> | `V-I` |
| <nobr><code>TC-P04-013</code></nobr> | Bascule Semi-Auto vers Maintenance | Mémorise étape, bloque commandes, reprise explicite | `💻 AUTO` | <small>§4</small> | `V-I` |
| <nobr><code>TC-P04-020</code></nobr> | `FB_ExtractionSequence` : mise en service séquence extraction | Transition READY -> CLOSING | `💻 AUTO` | <small>§3</small> | `V-I` |
| <nobr><code>TC-P04-021</code></nobr> | Enchaînement continu d'extraction sous maintien joystick | Fermeture $\rightarrow$ Décollage $\rightarrow$ Nominal sans à-coup | `💻 AUTO` | <small>§3</small> | `V-I` |

---

## 🧱 2 · Principes

| Règle | Exigence |
|---|---|
| 🔄 Programme ST | `FB_Cycle` reste un séquenceur ST à machine d'état, conforme `GUIDE_SEQUENCEUR_v1.2.md` R1-R9. |
| ✍️ Demandes seulement | Le cycle produit des demandes de mouvement, jamais des sorties physiques directes. |
| 🕹️ Présence opérateur | Tant qu'un mouvement est commandé, l'intention maintenue (manche défléchi) est requise. |
| 🛑 Relâchement | Relâchement manche (retour centre) $\Rightarrow$ `StartStop=FALSE`, étape conservée, pas de reprise automatique. |
| 🛡️ `STABILIZING` | Un `SafeStop` du domaine concerné place le cycle en hold sûr (état d'attente/stabilisation). |
| 🔑 Reprise | Cause disparue + Reset sur front + nouvel ordre explicite (StartCycle). |
| 🧩 Réutilisation | Diving et Extraction sont des briques ST réutilisées en maintenance et en semi-auto. |
| 🕹️ Homme-mort (D2) | Appui = autorisation 3 s ; mouvement continue sans ré-appui tant que manche défléchi ; arrêt au neutre. |
| 🏁 Début de graphe | À la TRÉMIE, treuils en position HAUTE — rebouclage sur `X0_PREPARATION`. |

---

## 🪨 3 · Petits cycles réutilisables

### 🌊 `FB_DiveSearch` — Diving / plongée Kobold

- **Auto-test 4 temps à la volée** :
  1. **Repos hors de l'eau ($> 0.0$ m)** : Capteur $\text{DI} = 0$, contacteur coupé (`KoboldContactorCmd = FALSE`).
  2. **Amorçage descente** : Activation à la volée du contacteur (`KoboldContactorCmd := TRUE`).
  3. **Immersion dans la tranche d'eau** : Front montant $\text{DI} = 1$ (capteur qualifié et sous tension).
  4. **Recherche de fond en Palier $\le 4$** : Vitesse plafonnée à $3.5$ m/s max (Palier 4). **Palier 5 strictement interdit** (parasites/saturation).
  5. **Contact fond validé** : Front descendant $\text{DI} = 0$ $\rightarrow$ validation fond (`BottomTouchConfirmed := TRUE`) et **coupure immédiate du contacteur Kobold** (`KoboldContactorCmd := FALSE`) pour éviter l'échauffement thermique.

### ⛏️ `FB_ExtractionSequence` — Extraction

- **Enchaînement fluide sans rupture de mouvement** :
  1. **Attente fond validé** : Prêt à fermer dès que le fond est confirmé.
  2. **Tirage joystick vers l'arrière ($Y > 0$)** : Fermeture de la benne sous maintien continu.
  3. **Confirmation benne fermée** : Décollage immédiat sans relâcher le manche.
  4. **Palier de contrôle ($2.0$ m)** : Vitesse minimale bridée (`ForceMinSpeedStep := TRUE`).
  5. **Remontée nominale** : Libération de la vitesse nominale jusqu'au seuil haut d'égouttage.

### ⏱️ 3bis · Dérivation physique des temporisations de garde & Matrice d'état sûr

#### 1. Dérivations cinématiques unifiées (Base vitesse la plus lente : Palier 1 mini)
Toutes les temporisations de garde constituent un **plafond anti-blocage** (surveillance de progression réelle). Elles sont calculées sur la base de la vitesse la plus lente crédible ($V_{P1\_mini} = 0.15\text{ m/s}$ sous charge/mou) et d'un facteur de marge de sécurité $\ge 1.5$ :

1. **Recherche immersion (`CalculatedImmersionTimeout`)** :
   - Course max : du plafond haut d'exploitation (`CableLimitAscent_M`, sourcé dans `GVL_IHM.Commun.Cfg.CfgCableLimitAscent_M`) jusqu'à la borne basse d'immersion (`ImmersionLower_M`) $\Rightarrow \Delta H = \text{CableLimitAscent\_M} - \text{ImmersionLower\_M}$. La descente peut démarrer n'importe où entre `DiveStartMin_M` et `CableLimitAscent_M` : on retient la borne la plus large pour ne jamais sous-dimensionner le plafond.
   - **Calcul dynamique en RUNTIME** (facteurs en `VAR CONSTANT` : `CST_DiveSpeedMin_Mps = 0.15`, `CST_TimeoutMarginFactor = 1.5`, plancher de course `CST_TimeoutMinCourse_M = 1.0`) :
     $$\Delta T_{imm} = \frac{\max(1.0, \text{CableLimitAscent\_M} - \text{ImmersionLower\_M})}{V_{P1\_mini}} \times 1.5$$
     *(Pour les valeurs par défaut $7.5\text{ m} - (-0.5\text{ m}) = 8.0\text{ m} \Rightarrow \Delta T_{imm} = 80.0\text{ s}$)*.
2. **Recherche fond (`CalculatedBottomTimeout`)** :
   - Course max sous l'eau : De la borne basse d'immersion (`ImmersionLower_M`) jusqu'à la limite légale autorisée (`LimitLegalDepthMin_M`, sourcée dans `GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M`) $\Rightarrow \Delta H = \text{ImmersionLower\_M} - \text{LimitLegalDepthMin\_M}$.
   - **Calcul dynamique en RUNTIME** (mêmes `VAR CONSTANT` que la recherche immersion) :
     $$\Delta T_{fond} = \frac{\max(1.0, \text{ImmersionLower\_M} - \text{LimitLegalDepthMin\_M})}{V_{P1\_mini}} \times 1.5$$
     *(Pour les valeurs de référence $-0.5\text{ m} - (-35.0\text{ m}) = 34.5\text{ m} \Rightarrow \Delta T_{fond} = 345.0\text{ s}$)*.
   - 🛡️ **Garde de sécurité** : Si l'exploitant modifie la profondeur légale admissible sur le site, le plafond de temporisation s'ajuste automatiquement sans nécessiter de modification logicielle.
3. **Fermeture benne (`CfgBucketCloseTimeout`)** :
   - Formule : $\text{CfgBucketCloseTimeout} \ge 2.5 \times \text{FB\_Bucket.CfgTimeoutDuration}$ (où $\text{CfgTimeoutDuration} = 6.0\text{ s}$ est le watchdog mécanique interne).
   - Dérivation : $\Delta T_{close} = 6.0\text{ s} \times 2.5 = 15.0\text{ s} \Rightarrow$ **Seuil figé : `T#15s`** (évite la course entre les deux watchdogs).
4. **Contrôle remontée lente (`ControlAscentTimeout`)** :
   - **Calcul dynamique en RUNTIME** car la distance $\text{ControlAscentDistance\_M}$ ($d_{ctrl}$) est paramétrable par l'opérateur sur l'IHM (ex: 1.0 m à 5.0 m) :
     $$\Delta T_{ctrl} = \frac{\text{ControlAscentDistance\_M}}{V_{P1\_mini}} \times 2.0 = \frac{d_{ctrl}}{0.15} \times 2.0$$
     *(Exemple pour $d_{ctrl} = 2.0\text{ m} \Rightarrow \Delta T = 26.6\text{ s} \approx \text{T\#27s}$)*.

#### 2. Matrice d'état sûr post-Timeout par étape

| Étape en défaut | Condition de timeout | État interne | Comportement physique & Action de repli sûre |
|---|---|---|---|
| `SEARCHING_IMMERSION` | Immersion non détectée après `CalculatedImmersionTimeout` | `ERROR_HOLD` | `DescendPermit := FALSE`, coupure contacteur Kobold (`KoboldContactorCmd := FALSE`), `Ready := FALSE`. `FB_DiveSearch` cesse d'imposer `DescendPermit` ; la remontée de dégagement reste disponible via le pilotage treuil normal. |
| `SEARCHING_BOTTOM` | Fond non détecté après `CalculatedBottomTimeout` | `ERROR_HOLD` | `DescendPermit := FALSE`, coupure contacteur Kobold anti-chauffe, `Ready := FALSE`. Descente bloquée, remontée disponible via pilotage treuil normal. |
| `CLOSING_BUCKET` | Benne non fermée après `CfgBucketCloseTimeout` | `ERROR_HOLD` | `BucketCloseRequest := FALSE`, `AscentPermit := FALSE`, `Lifecycle.Busy := FALSE`. Arrêt des consignes benne/treuils, dégagement opérateur requis. |
| `CONTROL_ASCENT` | Décollage non achevé après `ControlAscentTimeout` | `ERROR_HOLD` | `AscentPermit := FALSE`, `ForceMinSpeedStep := FALSE`, `Lifecycle.Busy := FALSE`. Arrêt sécurisé des consignes automatiques, maintien sous frein. |

#### 3. Arbitrage et Gel formel du Bypass Séquence Kobold (`BypassPreconditions`)
- **Contexte terrain & REX** : En exploitation sur plan d'eau boueux ou en cas de capteur Kobold défaillant, l'opérateur de carrière doit pouvoir poursuivre l'extraction en mode manuel/dégradé sous sa responsabilité visuelle directe sans être bloqué par l'automate.
- **Décision de conception arrêtée (Option 1 - Gel documenté)** :
  1. Le bypass `TglBypassDiveSearchSequence` court-circuite la qualification préalable de position et de capteur pour autoriser la descente.
  2. **Garde-fou inviolable** : L'interdiction du Palier 5 sous l'eau (`Palier5ForbiddenFault := TRUE` si `CurrentSpeedStep > 4`) et la coupure contacteur restent **strictement actives même sous bypass**.
  3. Ce mécanisme est gelé tel quel dans le code : aucun saut brutal n'est toléré au-delà du déverrouillage de la précondition.

#### 4. Mécanique interne d'acquisition & Capture d'étape (D1 / D2)
- **Anti-pompage homme-mort (D1)** : L'intégration temporelle s'effectue via un accumulateur de temps de mouvement effectif (`ImmersionTimerAcc`/`BottomTimerAcc += CycleTime`), le cumul n'avançant que sous descente réellement demandée (`MotionRequestActive AND MotionDirection = -1`). `CycleTime` est la période de tâche `MainTask` passée en `VAR_INPUT` (`T#10ms`, valeur câblée dans `PRG_03_Modes_Cycle`). Le cumul est réarmé à zéro dans la transition d'entrée d'étape et sur front montant de `Reset`.
- **Défaut latché survivant au cycle `Enable`** : les latches timeout (`TimeoutImmersionFault`/`TimeoutBottomFault`, `Latching:=TRUE`) ne sont **pas** effacés à `Enable=FALSE` — seul un front `Reset` conscient les acquitte. Si `Enable` repasse à `TRUE` avec un défaut déjà latché, `Fault.Latched` reste actif (pas de front `Fault.Error` → `StepAtFault` conserve la valeur figée au premier déclenchement, ou `WAIT_PRECONDITIONS` si le gate a été traversé entre-temps).
- **Capture ordonnée `StepAtFault` (D2)** : Mémorisation de `PrevState := State` en fin de scan. À l'instant du latch d'erreur (front montant `Fault.Error`), `StepAtFault := PrevState` est figé **avant** le basculement vers `ERROR_HOLD`.


---

## 🔄 4 · Cycle semi-auto (grafcet)

### 4.1 Instance unique du séquenceur

`FB_Cycle` est instancié en **une seule instance** dans `PRG_03_Modes_Cycle` :

```text
PRG_03_Modes_Cycle
 ├─ FB_Modes
 └─ instCycleSemiAuto : FB_Cycle   ← actif en SEMI_AUTO
```

- **Mémorisation d'étape** : Lors d'un basculement en Maintenance, `instCycleSemiAuto` conserve son étape courante (`PausedState`). Les demandes d'actionneurs sont neutralisées.
- **Reprise sécurisée** : Au retour en `SEMI_AUTO`, l'étape est conservée en pause (`WaitingResume := TRUE`). Un appui volontaire sur `BtnStart` ou armement homme-mort est exigé pour reprendre le cycle.

### 4.2 Enum `E_CycleStep`

```pascal
TYPE E_CycleStep :
(
    X0_PREPARATION      := 0,   (* 🏁 Début de graphe : à la TRÉMIE, treuils en position HAUTE *)
    X1_HOMING           := 1,   (* vitesses lentes pour chercher capteur top + référencement *)
    X2_WORK_POS_SELECT  := 2,   (* sélection cible Trémie/P1/Maintenance + translation validée *)
    X3_OPEN_BUCKET      := 3,   (* ouverture benne (si déjà ouverte → passe vite) *)
    X4_DESCEND_OPEN     := 4,   (* plongée benne ouverte, M1+M2 synchro, Kobold mesure ON *)
    X5_BOTTOM_CONFIRMED := 5,   (* fond validé (FB_DiveSearch) ; arrêt descente *)
    X6_CLOSE_BUCKET     := 6,   (* fermeture benne — tolérance « à peu près fermé » *)
    X7_CTRL_ASCENT      := 7,   (* remontée palier 1 de contrôle *)
    X8_ASCENT_LOADED    := 8,   (* remontée nominale jusqu'à limite haute *)
    X9_DRAIN_PAUSE      := 9,   (* égouttage temporisé — temps affiché IHM *)
    X10_TRANSLATE_DUMP  := 10,  (* translation vers trémie + avertissements IHM *)
    X11_OPEN_DUMP       := 11,  (* ouverture benne = vidage ; montée possible, descente ouvre *)
    X13_DONE_SYNC       := 13,  (* fin de cycle, synchronisation finale (R4) + compteur *)
    STABILIZING         := 14   (* état d'attente/stabilisation (ex-ERROR_HOLD) — pas une erreur *)
);
END_TYPE
```

---

## ⚖️ 5 · Synchronisation pendant les mouvements

| Mécanisme | Portée | Seuils réels |
|---|---|---|
| Écart de position continu (`FB_SyncDeviation`/`FB_WinchSync`) | Tout mouvement M1/M2 synchronisé | `CfgSyncToleranceM=0.10m` (Warn) / `CfgSyncCriticalToleranceM=0.50m` (Fault) |
| Contrôle de remontée lente (`FB_Cycle`, **X7_CTRL_ASCENT uniquement**) | Étape X7 seulement | `CtrlAscentToleranceM=0.25m` sur `CtrlAscentDistM=2.0m` ; `CtrlAscentTimeout=T#30s` |
| Écart de vitesse (`FB_Cycle`, X7 uniquement) | Étape X7 seulement | `SpeedMismatchThresholdMps` |

---

## 💬 6 · Messages et diagnostics (Troubleshooting)

La structure `ST_ChainCycleSemiAuto` (affichée dans `FB_TroubleshootingView` / `GVL_Troubleshooting.CycleSemiAuto`) publie l'arbre chronologique d'état :

| Index | Champ | Type | Description |
|---|---|---|---|
| `Idx101` | `ModeSemiAutoActive` | `BOOL` | 1 si mode `SEMI_AUTO` actif |
| `Idx104` | `DeadmanArmed` | `BOOL` | État armement homme-mort |
| `Idx105` | `MancheDeflechi` | `BOOL` | Joystick hors zone neutre |
| `Idx206` | `Step` | `E_CycleStep` | Étape active du cycle |
| `Idx207` | `StepStr` | `STRING(80)` | Libellé explicite de l'étape |
| `Idx208` | `StepAtError` | `E_CycleStep` | Étape mémorisée lors du dernier défaut |
| `Idx209` | `WaitingForOperator` | `BOOL` | 1 si l'automate attend un geste humain |
| `Idx210` | `WaitingForProcess` | `BOOL` | 1 si l'automate attend une condition procédé |
| `Idx211` | `OperatorActionId` | `UINT` | Identifiant numérique de l'action attendue |
| `Idx212` | `OperatorAction` | `STRING(120)` | Consigne affichée à l'opérateur |
| `Idx213` | `ExpectedAxis` | `E_OperatorAxis` | Organe attendu (`JOYSTICK_X`, `JOYSTICK_Y`, etc.) |
| `Idx214` | `ExpectedDirection` | `INT` | Direction attendue (-1 descente/gauche, +1 montée/droite) |
| `Idx215` | `WaitingResume` | `BOOL` | 1 si cycle en pause après bascule de mode |
| `Idx216` | `PausedState` | `E_CycleStep` | Étape de reprise mémorisée |

---

## 📜 7 · Suivi historique

| Version | Date | Changement |
|---|---|---|
| v2.3 | 2026-08-28 | Intégration séquence Kobold 4 temps à la volée, bridage strict Palier $\le 4$, extraction fluide sans rupture de mouvement, bascule de mode sans perte d'étape (`PausedState`, `WaitingResume`), diagnostic chronologique enrichi `ST_ChainCycleSemiAuto` (Idx209..216) et validation 100% tests STruCpp <nobr><code>TC-P04-001..021</code></nobr>. |
| v2.2 | 2026-08-26 | Mise en conformité `GUIDE_EDITION_AF_v1.0` et révision seuils synchro. |
| v2.1 | — | Refonte séquenceur `GUIDE_SEQUENCEUR_v1.2.md`. |

---

## ❓ 8 · TBD

- Manœuvre de rattrapage synchro (catch-up) et axe prioritaire — voir §5 (seuils/tempos déjà codés).

---

## 📚 9 · Documents liés

- [AF_Partie-02](AF_Partie-02_Architecture_Programme_v3.2.md) : Architecture générale et POU.
- [AF_Partie-03](AF_Partie-03_Contrats_Composants_v2.3.md) : Contrats FB et profils de composants.
- [AF_Partie-14](AF_Partie-14_Fonction_Troubleshooting_v1.3.md) : Diagnostic Troubleshooting.
- [GUIDE_SEQUENCEUR](DOC/STDS/GUIDES/GUIDE_SEQUENCEUR_v1.2.md) : Règles de conception Grafcet en ST.
