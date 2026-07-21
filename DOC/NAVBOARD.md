# 🧭 NAVBOARD — Fiche mémo Excavatrice Dragage

## 🗺️ Circulation des données

```
┌──────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────┐
│ IHM  │◄─↕►│ GVL_IHM  │◄─↕►│ PRG_09  │◄─↕►│ PRG_XX  │◄─↕►│ FB_XX   │◄─↕►│ I/O │
│ HMI  │    │ RETAIN   │    │Supervis.│    │Control  │    │Métier   │    │Phys.│
└──────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────┘
                                   ↕
                             ┌──────────────┐
                             │GVL_PERSISTENT│ ← tout paramètre réglable
                             │ RETAIN       │
                             └──────────────┘
```

📎 Diagrammes détaillés par sous-système : `DOC/DIAGRAMS/CODE/DIAG_CODE_*.png`

## 📋 Sous-systèmes — fichiers clés

| Sous-système | Control | FB métier | Safety | IHM struct | PERSISTENT |
|---|---|---|---|---|---|
| 🕹️ Joystick | `PRG_01_Diagnostics` | `FB_Joystick` | — | `ST_JoystickHMI` | `_Joystick*` |
| 🪣 Winch M1 | `PRG_06_WinchControl` | `FB_Winch` | `FB_Safety_Winch` | `ST_WinchHMI` | `_Winch*M1*` |
| 🪣 Winch M2 | `PRG_06_WinchControl` | `FB_Winch` | `FB_Safety_Winch` | `ST_WinchHMI` | `_Winch*M2*` |
| ↔️ Translation M3 | `PRG_07_TranslationControl` | `FB_Translation` | `FB_Safety_Translation` | `ST_TranslationHMI` | `_Translation*` |
| 🗜️ Benne | `PRG_06_WinchControl` | `FB_Bucket` | — | `ST_BucketHMI` | `_Bucket*` |
| 🔄 Synchro | `PRG_06_WinchControl` | `FB_WinchSync` | — | `ST_SyncHMI` | `_WinchSync*` |
| 🛡️ Safety global | `PRG_03_Safety` | `FB_Safety_*` | — | `ST_ModesHMI` | — |
| 🔄 Modes | `PRG_04_Modes` | `FB_Modes` | — | `ST_ModesHMI` | — |
| 🔁 Cycle | `PRG_05_Cycle` | `FB_Cycle` | — | `ST_CycleHMI` | — |

## 🧱 Briques communes (COMMUN/)

`FB_FilterPT1`·`FB_Brake`·`FB_Input_Digital`·`FB_Output_Relay`·`FB_Ramp`·`FB_AxisScale`·`FB_CycleTime`

## 🍳 5 recettes fréquentes

**① Ajouter un paramètre réglable IHM**
```
GVL_PERSISTENT (défaut+RETAIN) 
  → PRG_09 (mapping vers FB si nécessaire)
  → PRG_XX (câbler sur entrée FB)
  → GVL_IHM (champ exposé, optionnel si QUALIFIED_ONLY)
```

**② Ajouter une valeur d'affichage IHM (lecture seule)**
```
Sortie FB → PRG_XX → PRG_09 (mapping ligne) → GVL_IHM champ → IHM
```

**③ Ajouter un défaut (ErrorId bit)**
```
FB_XX.ErrorId bit N → PRG_09 mapping (décapsulage booléen) → GVL_IHM
→ Reset front R_TRIG + ResetEdge.Q pour effacer le bit
```

**④ Câbler un capteur TOR ou analogique**
```
PRG_00_Inputs (lecture I/O) → PRG_XX (logique) → FB_XX → PRG_09 → GVL_IHM
```

**⑤ Changer un paramètre existant**
```
Ne toucher QUE GVL_PERSISTENT (valeur par défaut) OU IHM (si exposé).
RIEN dans les FB_*.st (leurs defaults sont des fallbacks, pas la source).
```
