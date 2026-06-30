# 📋 Analyse Fonctionnelle — Partie 4 : Fonction Joystick (v1.0)

> **Fonction métier** : acquisition et conditionnement de la commande opérateur (joystick Hall → CANopen).
> **Livrable associé** : `PRG_JOY1` en ST (appel de l'instance `FB_Joystick`).
> **Cible** : CODESYS 3.5 — application **manuelle** par l'utilisateur.
> 🔗 Dépend de : [P1 équipements](AF_Partie1_Analyse_Fonctionnelle_v1.1.md), [P3 contrat FB](AF_Partie3_Template_FB_Commun_v1.1.md).

---

## 🎯 1. Rôle métier

Traduire le **geste opérateur** (2 axes + bouton) en une **consigne normalisée en %** exploitable par les treuils et la translation.

- 🕹️ 2 axes analogiques bruts (0..10000 pts) via nœud **CANopen**.
- 🔘 1 bouton.
- 📤 Sortie : vitesse **0..100 %** + **sens** (-1 / 0 / +1) par axe.

---

## ⚙️ 2. Chaîne de traitement (pipeline)

```
RawX/Y ──► FB_AxisScale ──► FB_Filter_PT1 ──► FB_Ramp ──► ST_AxisCmd (SpeedRef %, Direction)
           calib + deadband   filtre PT1       accel/decel
```

| Étape | Bloc | Rôle métier |
|-------|------|-------------|
| 🎯 Calibration | `FB_AxisScale` | Recale le neutre, applique la zone morte, sort en % signé (-100..+100) |
| 〰️ Filtrage | `FB_Filter_PT1` | Lisse le bruit du signal Hall (filtre 1er ordre) |
| 📈 Rampe | `FB_Ramp` | Accel/décel anti-à-coups (retour zéro plus rapide) |
| 📤 Normalisation | `ST_AxisCmd` | SpeedRef (%) + Direction + Start + SafetyOk |

> ♻️ **Réutilisation** : tous ces blocs **existent déjà** dans le projet — aucune brique réinventée (conforme P3 §0).

---

## 🔌 3. Interface `FB_Joystick`

**📥 Entrées clés**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable` | BOOL | Active la logique |
| `Reset` | BOOL | Acquittement défaut (front) |
| `SafeStop` | BOOL | Arrêt sûr prioritaire |
| `SafetyOk` | BOOL | Conditions globales OK |
| `CanOnline` / `CanOperational` | BOOL | État du nœud CANopen |
| `RawX` / `RawY` | INT | Axes bruts (0..10000) |
| `RawButton` | BOOL | Bouton brut |
| `Calibrate` | BOOL | Demande recalage neutre (front) |
| `InvertX/Y`, `Deadband`, `FilterTime`, `AccelRate`, `DecelRate` | — | Paramétrage |

**📤 Sorties clés**
| Sortie | Type | Rôle |
|--------|------|------|
| `AxisCmdX` / `AxisCmdY` | `ST_AxisCmd` | Consigne normalisée (SpeedRef %, Direction) |
| `Button` | BOOL | Bouton filtré |
| `NeutralXAct` / `NeutralYAct` | INT | Neutres calibrés (IHM) |
| `Ready`/`Busy`/`Done`/`Error`/`ErrorId` | — | État FB (`ErrorId 16#0003` = calib hors plage) |

🎯 Neutre mémorisé en **`VAR RETAIN`** (persiste à la coupure). Plage de calibration valide : 2000..8000.

---

## 🛡️ 4. Sécurité

- 🛑 **Gate** : sans `Enable`, sur `SafeStop`, ou CAN non opérationnel → toutes sorties forcées à **0**.
- 🔑 **Reset sur front** : défaut calibration non auto-réarmé (conforme P3 §5).
- 🔌 **CAN down** → joystick neutralisé (pas de commande fantôme).

---

## 🗺️ 5. Mapping E/S (extrait du CFC d'origine)

| Entrée `FB_Joystick` | Variable câblée | État |
|----------------------|-----------------|------|
| `RawX` | `JoyXRaw_ANA1` | ✅ |
| `RawY` | `JoyYRaw_ANA2` | ✅ |
| `RawButton` | `JoyBtnRaw` | ✅ |
| `CanOnline` | `diagCAN.IsOnline` | ✅ |
| `CanOperational` | `diagCAN.IsOperational` | ✅ |
| `Enable` | `GVL_DEBUG.DBG_True` | ⚠️ debug |
| `SafetyOk` | `GVL_DEBUG.DBG_True` | ⚠️ debug |
| `SafeStop` | `GVL_DEBUG.DBG_False` | ⚠️ debug |
| `Reset` | (non câblé) | ⚠️ |
| `Calibrate` | (non câblé) | ⚠️ |

---

## 💻 6. Implémentation `PRG_JOY1` (ST)

> ⚠️ `FB_Joystick` est **inchangé** (déjà correct). On ne réécrit que le programme d'appel `PRG_JOY1`, aujourd'hui en CFC.

### Déclaration
```iecst
PROGRAM PRG_JOY1
VAR
    // 🕹️ Instance unique du traitement joystick (pipeline calib/filtre/rampe)
    FB_Joystick_0 : FB_Joystick;
END_VAR
```

### Corps
```iecst
(* ═══════════════════════════════════════════════════════════════
   🕹️ PRG_JOY1 — Appel du traitement joystick (version ST)
   ───────────────────────────────────────────────────────────────
   Remplace l'ancien réseau CFC. Câble les E/S physiques sur le FB,
   qui réalise en interne : calibration ➜ filtrage ➜ rampe ➜ % .
   📤 Résultat exploitable : FB_Joystick_0.AxisCmdX / .AxisCmdY
   ═══════════════════════════════════════════════════════════════ *)

FB_Joystick_0(
    // 🟢 --- Autorisations & sécurité ---
    Enable          := GVL_DEBUG.DBG_True,      // ⚠️ DEBUG : remplacer par autorisation réelle
    SafetyOk        := GVL_DEBUG.DBG_True,      // ⚠️ DEBUG : remplacer par conditions sécurité OK
    SafeStop        := GVL_DEBUG.DBG_False,     // ⚠️ DEBUG : remplacer par SafeStop global (FB_Safety)
    Reset           := FALSE,                   // ⚠️ À câbler : front acquittement défaut IHM

    // 🔌 --- État du bus CANopen (joystick) ---
    CanOnline       := diagCAN.IsOnline,        // 📡 nœud CAN présent
    CanOperational  := diagCAN.IsOperational,   // 📡 esclave en mode opérationnel

    // 📥 --- Entrées brutes joystick ---
    RawX            := JoyXRaw_ANA1,            // 🕹️ axe X brut (0..10000)
    RawY            := JoyYRaw_ANA2,            // 🕹️ axe Y brut (0..10000)
    RawButton       := JoyBtnRaw,               // 🔘 bouton brut

    // 🎯 --- Calibration ---
    Calibrate       := FALSE,                   // ⚠️ À câbler : bouton recalage neutre (front)

    // 🎛️ --- Paramètres de traitement (valeurs par défaut conservées) ---
    InvertX         := FALSE,                   // ↔️ inversion sens axe X si besoin
    InvertY         := FALSE,                   // ↕️ inversion sens axe Y si besoin
    Deadband        := 5.0,                     // 🛑 zone morte ±5 %
    FilterTime      := TIME#100ms,              // 〰️ constante de temps filtre PT1
    AccelRate       := 50.0,                    // 📈 accélération 50 %/s
    DecelRate       := 150.0                    // 📉 décélération 150 %/s (retour zéro plus rapide)
);

(* 📤 SORTIES DISPONIBLES (lecture seule, à consommer en aval) :
   ───────────────────────────────────────────────────────────────
   FB_Joystick_0.AxisCmdX.SpeedRef    : REAL  // 🚀 vitesse X 0..100 %
   FB_Joystick_0.AxisCmdX.Direction   : INT   // ➡️ -1 / 0 / +1
   FB_Joystick_0.AxisCmdY.SpeedRef    : REAL  // 🚀 vitesse Y 0..100 %
   FB_Joystick_0.AxisCmdY.Direction   : INT   // ⬆️ -1 / 0 / +1
   FB_Joystick_0.Button               : BOOL  // 🔘 bouton filtré
   FB_Joystick_0.NeutralXAct/.NeutralYAct : INT  // 🎯 neutres calibrés (IHM)
   FB_Joystick_0.Ready/.Busy/.Done    : BOOL  // 🚦 état FB
   FB_Joystick_0.Error/.ErrorId       : BOOL/WORD // 🧾 défaut (ErrorId 16#0003 = calib hors plage)
   ─────────────────────────────────────────────────────────────── *)
```

---

## 📝 7. Note d'application CODESYS 3.5 (manuel)

### 🔧 Intégration
1. **Ouvrir** `PRG_JOY1` (dossier `JOYSTICK`).
2. ⚠️ **Langage** : l'éditeur actuel est **CFC** et se fige à la création. Pour passer en ST :
   - Supprimer puis **recréer** `PRG_JOY1` en **ST** (même nom, pour ne pas casser l'appel de tâche).
3. **Coller** la déclaration (§6) puis le corps (§6).
4. **Vérifier** que la tâche (CanTask/MainTask) appelle bien `PRG_JOY1`.

### ✅ Variables à vérifier (doivent exister)
- `JoyXRaw_ANA1`, `JoyYRaw_ANA2`, `JoyBtnRaw`
- `diagCAN` (`.IsOnline`, `.IsOperational`)
- `GVL_DEBUG.DBG_True`, `GVL_DEBUG.DBG_False`
- Type `ST_AxisCmd` ; FB `FB_CycleTime`, `FB_AxisScale`, `FB_Filter_PT1`, `FB_Ramp`

### 🔒 À sécuriser après remise en service
| Entrée debug | Remplacer par |
|--------------|---------------|
| `Enable := GVL_DEBUG.DBG_True` | autorisation réelle (FB_Modes) |
| `SafetyOk := GVL_DEBUG.DBG_True` | `NOT SafeStop AND EStopOk` (FB_Safety) |
| `SafeStop := GVL_DEBUG.DBG_False` | `SafeStop` global (FB_Safety) |
| `Reset := FALSE` | bit acquittement IHM |
| `Calibrate := FALSE` | bouton calibration IHM (front) |

---

## 🔁 8. Retour d'expérience (à compléter après test)

- [ ] Calibration OK (front `Calibrate`, neutre 2000..8000) ?
- [ ] Sortie % cohérente (deadband 5 %, rampes douces) ?
- [ ] CAN coupé → sorties à 0 (gate OK) ?
- [ ] Si validé → figer le mapping sécurité définitif dans `AF_Partie2_v2.x` + clôturer cette v1.0.
