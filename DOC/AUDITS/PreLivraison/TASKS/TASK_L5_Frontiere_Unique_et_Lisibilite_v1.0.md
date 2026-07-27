# 🏗️ FICHE DE TÂCHE — Lot L5 : frontière unique `HwIn` **+** refonte de lisibilité `PRG_00`

> 🤖 Agent d'implémentation externe · 📅 2026-07-27 · **v1.0** · 🟠 lot technique
> ⏱️ **Prérequis** : T80, L2/L3, L4a→L4d appliqués et compilés (0 erreur). ✅ C'est le cas.
> 📖 **Contexte projet et règles de travail : lire les §1 et §4 de
> [`TASK_L2-L3_Retrait_GVL_PLC_Tests_v1.0.md`](TASK_L2-L3_Retrait_GVL_PLC_Tests_v1.0.md)**
> (contexte machine, lectures obligatoires, devoir d'alerte — ils s'appliquent intégralement).

---

## 1. 🎯 Objectif — deux buts, un seul passage

`PRG_00_Inputs` est réécrit **une seule fois** pour livrer :

| But | Contenu |
|---|---|
| **A — Structure** | Une **image matérielle unique** `HwIn`. Tous les consommateurs lisent `HwIn.<domaine>.<signal>` au lieu de la variable physique |
| **B — Lisibilité** | Mise en page réfléchie : carte des blocages en tête, 1 signal = 1 flux visible, **polarité affichée à chaque étage** |

> ⚠️ **Aucun changement de comportement machine n'est attendu.** Le programme doit se comporter
> **exactement** comme aujourd'hui. Seul le *chemin* de la donnée et la *présentation* changent.

### 🧠 État actuel à connaître

**La simulation a déjà été entièrement débranchée** (lots L4a→L4d). Il n'y a plus **aucune**
référence à `GVL_Simulation` dans le code actif. Donc ici : `HwIn := HwReal` **inconditionnel**,
sans aucun `IF`. Le banc de simulation sera rebranché plus tard (lot L6), **pas par toi**.

⛔ **N'introduis aucune simulation, aucun flag, aucun aiguillage.**

---

## 2. 🔧 Travail — partie A : image matérielle

### A1. Créer les types dans `CODE/SUPERVISION/_TYPES/`

| Struct | Contenu (signaux physiques d'ENTRÉE uniquement) |
|---|---|
| `ST_HwWinch` | `M1/M2_ContactorsReleased_DI` · `M1/M2_ThermalOk_DI` · `M1/M2_BrakeIsOpen_DI` · `M1M2_TopPositionFree_DI` · `M2_TensionedCable_DI` · `COD1/COD2_PosValue` · `COD1/COD2_Alarms` · `COD1/COD2_Warnings` · états devices COD1/COD2 |
| `ST_HwTranslation` | `M3_PosTremie_DI` · `M3_PosPV_DI` · `M3_PosP2_DI` · `M3_PosP1_DI` · `M3_PosMaintenance_DI` · `M3_BrakeIsOpen_DI` · `M3_StatusWord` · `M3_ActualFrequencyHz` · état device AC600 |
| `ST_HwOperator` | `JoyXRaw_ANA1` · `JoyYRaw_ANA2` · `JoyBtnRaw` · état bus CAN · état device JOY1 |
| `ST_HwMachine` | `PowerContactorEngaged_DI` · `EmergencyChainClosed_DI` · `PhaseRotationOk_DI` · `BrakeThermalOk_DI` · `M1_M2_KoboldContactFond_DI` · `HydraulicThermalOk_DI` |
| `ST_HardwareImage` | agrège les 4 : `Winch` · `Translation` · `Operator` · `Machine` |

🔎 **Vérifie chaque nom dans le code réel avant de l'écrire** (les E/S ont été renommées le 27/07,
voir `DOC/AUDITS/PreLivraison/TABLE_Renommage_IO_v1.0.md`). N'invente aucun nom.

### A2. `PRG_00_Inputs` — section §0

```
// §0 : recopie brute du matériel, AUCUNE logique
HwReal.Winch.M1BrakeIsOpen := M1_BrakeIsOpen_DI;
… (~40 champs)

// §0bis : image utilisée par tout le programme
HwIn := HwReal;      // ⬅️ inconditionnel — le banc viendra ici au lot L6
```

`HwReal` et `HwIn` sont déclarés en `VAR_OUTPUT` de `PRG_00_Inputs` (lecture seule pour le reste).

### A3. Remonter les lectures d'état device dans `PRG_00`

Les 5 appels `CANbus.GetBusState()` / `…GetDeviceState()` aujourd'hui en tête de `PRG_01_Diagnostics`
migrent dans `PRG_00` §0 et remplissent `HwIn`. **Toute la logique de diagnostic reste dans
`PRG_01`** — `FB_DiagCanOpen` / `FB_DiagEthercat` ne sont pas modifiés, ils lisent `HwIn`.

### A4. Basculer les consommateurs

`PRG_00` §1 · `PRG_01_Diagnostics` · `PRG_02_Encoders` · `PRG_07_TranslationControl` ·
`PRG_08_AuxiliaryControl` → lire `PRG_00_Inputs.HwIn.<domaine>.<signal>`.

⛔ `PRG_10_Outputs` **n'est pas concerné** (sorties, pas entrées).

---

## 3. 🎨 Travail — partie B : lisibilité de `PRG_00`

### B1. Bandeau de tête + carte des blocages

```pascal
(* ══════════════════════════════════════════════════════════════════════════
   📥 PRG_00_Inputs — ACQUISITION & CONDITIONNEMENT       ⚙️ scan position 0
   ══════════════════════════════════════════════════════════════════════════
   §0  MATÉRIEL ──► HwReal ──► HwIn
   §1  HwIn     ──► FB_Input ──► VAR_OUTPUT  (filtre 20 ms, polarité NO/NC)
   §2  Décodage mot capteurs M3
   ══════════════════════════════════════════════════════════════════════════
   🗺️ CARTE DES BLOCAGES — ce qui empêche la machine de bouger si FALSE
   [BLOQUE] mouvement interdit · [ESCAL.] escalade safety · [DIAG] information seule
   ┌──────────────────────────┬──────────┬─────────────────────────────────┐
   │ EmergencyStopOk          │ [BLOQUE] │ portail maître — tout le prog.  │
   │ TopPositionSensor        │ [BLOQUE] │ ForbidAscent M1+M2 (hors bypass)│
   │ SlackCableSwitch         │ [BLOQUE] │ ForbidDescent M2                │
   │ BrakeThermalFeedback     │ [ESCAL.] │ SafeStop + PowerCutOff (3 axes) │
   │ PhaseRotationOk          │ [ESCAL.] │ SafeStop (3 axes)               │
   │ M1/M2ThermalFeedback     │ [ESCAL.] │ SafeStop axe                    │
   │ M1/M2/M3BrakeFeedback    │ [ESCAL.] │ Méca A/B/D si arrêt non confirmé│
   │ KoboldContactFond        │ [BLOQUE] │ cycle figé BOTTOM_TOUCH_WAIT    │
   │ HydraulicThermalOk       │ [DIAG]   │ aucun effet sur le mouvement    │
   └──────────────────────────┴──────────┴─────────────────────────────────┘ *)
```

⚠️ **Pas de code couleur dans le code source** : l'éditeur CODESYS affiche les commentaires en
monochrome, donc 🔴 et 🟠 y sont **indistinguables** (deux cercles pleins identiques). Les marqueurs
doivent rester lisibles en noir et blanc → **tags texte alignés en colonne**, jamais des pastilles.

🔎 **Vérifie chaque effet de blocage dans le code** (`FB_Safety_Winch`, `FB_Safety_Translation`,
`FB_Cycle`) avant de l'inscrire. Si tu constates un écart avec cette carte, **signale-le**.

### B2. Format par signal — 3 lignes maximum

```pascal
//  🔌 M1_BrakeIsOpen_DI ··············· câblage réel : 1 = contacteur commandé = DESSERRÉ
//         └─►[ ⇄ BrakeFeedbackInvertLogic 🔩 ]   ← bascule unique, 📄 AF_Partie-09 §5bis
//                └─► M1BrakeFeedback ··········· TRUE = frein SERRÉ (état sûr)
//                       └─► Méca A/B/D/E · FB_Brake · Homing
instM1BrakeFeedback(InputRaw := HwIn.Winch.M1BrakeIsOpen, InvertLogic := BrakeFeedbackInvertLogic, FilterTime := T#20MS);
M1BrakeFeedback := instM1BrakeFeedback.State;
```

### B3. Les 4 règles

| Règle | |
|---|---|
| 1 | **Le flux tient sur une ligne** : `source ──►[traitement]──► sortie`, puis `└►` consommateurs |
| 2 | **La polarité est écrite à chaque étage** (voir B2) — c'est là que se cachent les pièges |
| 3 | **Le blocage est un tag court aligné** `[BLOQUE]` / `[ESCAL.]` / `[DIAG]`, pas une phrase — et **jamais un code couleur** (l'éditeur CODESYS est monochrome). Les emojis de forme distincte (⚠️ ⛔ 🔩 📄) restent utiles ; les pastilles de couleur ne le sont pas |
| 4 | **Le « pourquoi » part en doc**, le code garde un renvoi `📄 AF_Partie-09 §5bis` |

⚠️ **Zéro perte d'information** : tout commentaire explicatif retiré du code doit être **déplacé**
dans l'`AF_PartieN` correspondante, jamais supprimé. Liste les déplacements dans ton rapport.

### B4. Cas particulier à signaler, pas à corriger

`PRG_03_Safety.st:42` fait `ThermalFeedback := NOT PRG_00_Inputs.M1ThermalFeedback` : `PRG_00`
sort « TRUE = sain », mais ce FB attend « TRUE = défaut ». **Deux conventions cohabitent.**
👉 Mentionne-le dans le commentaire du signal concerné et dans ton rapport. **Ne corrige rien.**

---

## 4. ⛔ Interdictions

- ❌ Aucun changement de **logique**, de **polarité**, de **seuil**, de **temporisation**
- ❌ Aucune réintroduction de simulation, de flag `GVL_Simulation`, d'aiguillage
- ❌ Aucun renommage de variable (les E/S ont déjà été renommées)
- ❌ Ne touche pas aux `FB_*`, ni à `PRG_03`, `PRG_04`, `PRG_05`, `PRG_06`, `PRG_09`, `PRG_10`
- ❌ Ne modifie pas l'ordre d'exécution des programmes
- ❌ Aucun commit

---

## 5. 🛑 Pièges

| # | Piège |
|---|---|
| **CK9** | **Ordre impératif** : `PRG_00` §0 (remplissage) → §1 (conditionnement) → `PRG_01`. Si `HwIn` est lu avant d'être rempli, retard d'un scan sur `DeviceJoystick.Operational` → gate `FB_Joystick` |
| P2 | ~40 signaux redirigés : **une seule faute silencieuse suffit**. Procède domaine par domaine (Winch, puis Translation, puis Operator, puis Machine) et vérifie chaque bloc |
| P3 | Certains signaux sont consommés par **plusieurs** programmes. Cherche **toutes** les occurrences avant de renommer un accès |
| P4 | Les commentaires actuels contiennent des `REX aaaa-mm-jj` qui expliquent des décisions de sécurité : **ils se déplacent, ils ne disparaissent pas** |

---

## 6. 📤 Livrable

`DOC/AUDITS/PreLivraison/TASKS/RAPPORT_L5_v1.0.md` :

- tableau des **~40 signaux** : nom physique → champ `HwIn` → consommateurs mis à jour
- liste des **commentaires déplacés** vers la doc (source → destination)
- confirmation : plus aucune lecture directe d'un `_DI`/`_ANA`/`COD*`/`M3_*` hors `PRG_00` §0
- écarts constatés entre la **carte des blocages** et le code réel
- tes alertes (§4 de la fiche L2-L3)

### ✅ Critères de sortie

- [ ] `HwIn := HwReal` inconditionnel, aucun `IF`, aucun flag de simulation
- [ ] Toute lecture matérielle est dans `PRG_00` §0 — nulle part ailleurs
- [ ] Aucune polarité, aucun seuil, aucune tempo modifiés
- [ ] Carte des blocages présente et **vérifiée dans le code**
- [ ] Zéro information perdue (commentaires déplacés, pas supprimés)
- [ ] Commentaires **français** + emoji, en-têtes `(* … *)` conservés

### 🧪 Validation (par l'utilisateur, pas par toi)

1. Compilation CODESYS **0 erreur / 0 warning**
2. **Comparaison signal à signal** : chaque `VAR_OUTPUT` de `PRG_00` doit valoir exactement ce
   qu'elle valait avant le lot, machine à l'arrêt puis en mouvement lent
3. Essai machine complet (prévu sous quelques jours)
