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
