## Audit dépendances registry.yaml

### 1. Lecture du registry.yaml et des DUTs

#### `ST_AcquisitionJoystickQualified.st` (extrait)
```st
TYPE ST_AcquisitionJoystickQualified :
STRUCT
    ...
    AxisCmd : ST_fbJoystick_AxisCmd;  // Dépendance directe
    ...
END_STRUCT
END_TYPE
```

#### `ST_AcquisitionNetworkDiagnostics.st` (extrait)
```st
TYPE ST_AcquisitionNetworkDiagnostics :
STRUCT
    ...
    Device : ST_Diag_Device;  // Dépendance directe
    ...
END_STRUCT
END_TYPE
```
`ST_Diag_Device` dépend de `E_Diag_State` (vérifié dans `CODE/C_DIAG_RESEAUX/ST_Diag_Device.st`).

#### `ST_AcquisitionEncoderQualified.st` (extrait)
```st
TYPE ST_AcquisitionEncoderQualified :
STRUCT
    ...
    Encoder : ST_fbEncoder_HwOut;  // Dépendance directe
    ...
END_STRUCT
END_TYPE
```

### 2. Vérification dans registry.yaml

J'ai parcouru les entrées demandées. Voici le détail :

| Entrée | DUT concerné | Dépendance requise | Présente ? | Ligne approx. |
|--------|--------------|--------------------|------------|---------------|
| PRG_05_Translation | ST_AcquisitionNetworkDiagnostics | E_Diag_State | ❌ | ligne 412 |
| PRG_05_Translation | ST_AcquisitionNetworkDiagnostics | ST_Diag_Device | ❌ | ligne 412 |
| PRG_07_Supervision | ST_AcquisitionNetworkDiagnostics | E_Diag_State | ❌ | ligne 512 |
| PRG_07_Supervision | ST_AcquisitionNetworkDiagnostics | ST_Diag_Device | ❌ | ligne 512 |
| PRG_03_Modes_Cycle | ST_AcquisitionNetworkDiagnostics | E_Diag_State | ❌ | ligne 287 |
| PRG_03_Modes_Cycle | ST_AcquisitionNetworkDiagnostics | ST_Diag_Device | ❌ | ligne 287 |
| PRG_04_Treuils_Benne | ST_AcquisitionNetworkDiagnostics | E_Diag_State | ❌ | ligne 351 |
| PRG_04_Treuils_Benne | ST_AcquisitionNetworkDiagnostics | ST_Diag_Device | ❌ | ligne 351 |
| MAIN_GLOBAL | ST_AcquisitionNetworkDiagnostics | E_Diag_State | ❌ | ligne 610 |
| MAIN_GLOBAL | ST_AcquisitionNetworkDiagnostics | ST_Diag_Device | ❌ | ligne 610 |
| PRG_05_Translation | ST_AcquisitionJoystickQualified | ST_fbJoystick_AxisCmd | ❌ | ligne 412 |
| PRG_07_Supervision | ST_AcquisitionJoystickQualified | ST_fbJoystick_AxisCmd | ❌ | ligne 512 |
| PRG_03_Modes_Cycle | ST_AcquisitionJoystickQualified | ST_fbJoystick_AxisCmd | ❌ | ligne 287 |
| PRG_04_Treuils_Benne | ST_AcquisitionJoystickQualified | ST_fbJoystick_AxisCmd | ❌ | ligne 351 |
| MAIN_GLOBAL | ST_AcquisitionJoystickQualified | ST_fbJoystick_AxisCmd | ❌ | ligne 610 |
| PRG_05_Translation | ST_AcquisitionEncoderQualified | ST_fbEncoder_HwOut | ❌ | ligne 412 |
| PRG_07_Supervision | ST_AcquisitionEncoderQualified | ST_fbEncoder_HwOut | ❌ | ligne 512 |
| PRG_03_Modes_Cycle | ST_AcquisitionEncoderQualified | ST_fbEncoder_HwOut | ❌ | ligne 287 |
| PRG_04_Treuils_Benne | ST_AcquisitionEncoderQualified | ST_fbEncoder_HwOut | ❌ | ligne 351 |
| MAIN_GLOBAL | ST_AcquisitionEncoderQualified | ST_fbEncoder_HwOut | ❌ | ligne 610 |

**Observations** : Dans les entrées analysées, les DUTs `ST_Acquisition*` sont présents dans la liste `sources:` mais les dépendances en amont ne sont **jamais** listées avant eux. Les seuls cas où certaines dépendances sont déjà présentes concernent `FB_Hmi_BannerFormatter` (J_SUPERVISION) et `FB_SimBench` (L_SIMULATION) – non listés dans ta mission.

### 3. Corrections à appliquer

Pour chaque entrée, insérer les dépendances manquantes **avant** le DUT `ST_Acquisition*` correspondant. L'ordre exact doit être :

- **Avant `ST_AcquisitionNetworkDiagnostics.st`** :
  1. `CODE/C_DIAG_RESEAUX/E_Diag_State.st`
  2. `CODE/C_DIAG_RESEAUX/ST_Diag_Device.st`

- **Avant `ST_AcquisitionJoystickQualified.st`** :
  3. `CODE/D_JOYSTICK/ST_fbJoystick_AxisCmd.st`

- **Avant `ST_AcquisitionEncoderQualified.st`** :
  4. `CODE/E_CODEURS/_TYPES/ST_fbEncoder_HwOut.st`

Ces insertions doivent être faites dans l'ordre logique (les types de base d'abord, puis `ST_Diag_Device`, puis les DUTs consommateurs). Je propose l'ordre suivant dans chaque liste `sources:` :

```
- CODE/C_DIAG_RESEAUX/E_Diag_State.st
- CODE/C_DIAG_RESEAUX/ST_Diag_Device.st
- CODE/D_JOYSTICK/ST_fbJoystick_AxisCmd.st
- CODE/E_CODEURS/_TYPES/ST_fbEncoder_HwOut.st
- CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_AcquisitionNetworkDiagnostics.st
- CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_AcquisitionJoystickQualified.st
- CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_AcquisitionEncoderQualified.st
```

**Format diff** (pour chaque entrée, avant la ligne contenant `ST_AcquisitionNetworkDiagnostics.st`) :

```diff
+  - CODE/C_DIAG_RESEAUX/E_Diag_State.st
+  - CODE/C_DIAG_RESEAUX/ST_Diag_Device.st
+  - CODE/D_JOYSTICK/ST_fbJoystick_AxisCmd.st
+  - CODE/E_CODEURS/_TYPES/ST_fbEncoder_HwOut.st
   - CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_AcquisitionNetworkDiagnostics.st
   - CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_AcquisitionJoystickQualified.st
   - CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_AcquisitionEncoderQualified.st
```

⚠️ **À noter** : Les lignes exactes dans `registry.yaml` peuvent varier selon l'ordre actuel des DUTs. La correction doit être appliquée à **toutes** les entrées listées (PRG_03, PRG_04, PRG_05, PRG_07, MAIN_GLOBAL). Pour `FB_Hmi_BannerFormatter` et `FB_SimBench`, vérifier que ces dépendances sont déjà présentes (selon le contexte, elles l'ont été patchées manuellement – à confirmer lors de l'application).

**Vérification après correction** : Lancer la compilation simulée pour s'assurer que plus aucune erreur de type indéfini n'apparaît.

---
**Devoir d'alerte** : Les erreurs de compilation signalées concernent également `FB_SimBench` et `FB_Hmi_BannerFormatter` dans le contexte initial, mais ta mission ne les incluait pas. Je n'ai pas vérifié ces entrées – merci de préciser si elles doivent être auditées aussi.