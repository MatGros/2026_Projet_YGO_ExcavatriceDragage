# Guide d'Implémentation — Unification Bus Health CAN/ETHERCAT

Date: 2026-06-30  
Projet: Excavatrice de Dragage  
Scope: Refactor diagnostic bus + niveaux de dégradation

---

## 📋 Fichiers préparés

### Nouveaux POUs ST (à créer manuellement dans CODESYS)

Ces fichiers sont en langage ST brut. Tu dois :
1. Créer un nouveau POU de type **Function Block** (ou **Program** pour PRG_BusMonitor) dans CODESYS
2. Copier-coller le contenu `.st` dans l'éditeur ST du POU
3. Exporter Device.export (via File → Generate → Device.export)
4. Relancer `extract.py --yes` pour recupérer les nouveaux POUs en XML

**Fichiers à créer dans CODESYS :**

| Fichier | Type | Dossier CODESYS | Description |
|---------|------|-----------------|-------------|
| `_TYPES.st` | (voir note ci-dessous) | `_TYPES` | Contient les enums et structs |
| `FB_DiagCanOpen.st` | Function Block | `SYSTEM` | Diagnostic bus CAN + joystick |
| `FB_BusAggregator.st` | Function Block | `SYSTEM` | Agrégation des 2 buses |
| `PRG_BusMonitor.st` | Program | `SYSTEM` | Orchestration des diagnostics |

**Note sur _TYPES.st :**  
`E_DegradationLevel` et `ST_BusHealth` sont des types (ENUM et STRUCT).  
Dans CODESYS, crée plutôt une **Global Variable List (GVL)** appelée `_TYPES` et place les déclarations TYPE à l'intérieur.

### Fichiers XML existants à modifier

Via `inject.py --yes` après modifications dans CODE/ :

| Fichier XML | Modifications | Étape du plan |
|-------------|---------------|--------------|
| `diagETHERCAT__...xml` | ✅ Reset R_TRIG + StateAtError | **DÉJÀ FAIT** |
| `FB_Encoder_Abs__...xml` | ⚠️ Complexe (voir ci-dessous) | À faire manuellement |
| `FB_Safety__...xml` | ⚠️ Inputs granulaires | À faire manuellement |
| `PLC_PRG_MAIN__...xml` | 🔄 Recâblage + GVL | À faire manuellement |

---

## 🚀 Étapes d'implémentation

### Phase 1 : Types + Nouveaux POUs (approche hybride)

1. **Créer les types dans CODESYS**  
   ```codesys
   // Créer une GVL "_TYPES" dans SYSTEM
   {ATTRIBUTE 'qualified_only'}
   VAR_GLOBAL CONSTANT
       (* Enum *)
       E_DegradationLevel : (FULL:=0, LEVEL1:=1, LEVEL2:=2, MAINTENANCE:=3);
       
       (* Struct *)
       ST_BusHealth : STRUCT
           CanHealthy          : BOOL;
           EthercatHealthy     : BOOL;
           GlobalHealthy       : BOOL;
           JoystickAvailable   : BOOL;
           EncoderM1Available  : BOOL;
           EncoderM2Available  : BOOL;
           VariateurAvailable  : BOOL;
       END_STRUCT;
   END_VAR
   ```

   **Alternative (plus simple):** Copie-colle directement le contenu de `_TYPES.st` dans l'éditeur ST de la GVL.

2. **Créer FB_DiagCanOpen dans CODESYS**  
   - New → Function Block → nom `FB_DiagCanOpen`
   - Copie-colle le contenu de `FB_DiagCanOpen.st`
   - Vérifie que les types `BUS_STATE`, `DEVICE_STATE` existent (CANopen_Manager)
   - Compile

3. **Créer FB_BusAggregator dans CODESYS**  
   - New → Function Block → nom `FB_BusAggregator`
   - Copie-colle le contenu de `FB_BusAggregator.st`
   - Compile

4. **Créer PRG_BusMonitor dans CODESYS**  
   - New → Program → nom `PRG_BusMonitor` dans **SYSTEM** task
   - Copie-colle le contenu de `PRG_BusMonitor.st`
   - ⚠️ **À adapter :** remplace les références placeholders `CoE_Encoder1_WcState`, `CANopen_Manager.GetBusState(...)` par les vraies variables/références de ton projet
   - Compile

5. **Exporter Device.export depuis CODESYS**  
   - Rebuild project → Generate → Device.export

### Phase 2 : Modifications POUs existants

6. **Extraire depuis Device.export**
   ```bash
   python tools/extract.py --yes
   ```
   Les 4 nouveaux POUs apparaissent en XML dans CODE/.

7. **Modifier diagETHERCAT__...xml**  
   ✅ **DÉJÀ FAIT** — Ready to inject

8. **Modifier FB_Encoder_Abs__...xml**  
   ⚠️ **Option A (recommandée) :** Recréer complètement  
   - Ouvre le fichier XML
   - Remplace toute la section `<TextBlobForSerialisation>` (interface + implémentation) par le contenu de `FB_Encoder_Abs_REFACTORED.st`
   - Sauvegarde
   
   **Option B (manuel) :**  
   Applique les changements patch par patch (complexe, risqué).

9. **Modifier FB_Safety__...xml**  
   Pareil qu'étape 8 — remplace le contenu par `FB_Safety_REFACTORED.st`

10. **Modifier PLC_PRG_MAIN__...xml**  
    À faire :
    - Supprimer la déclaration `InstanceJoystick : FB_Joystick` (doublonne)
    - Garder une seule instance (dans MAIN ou dans PRG_JOY1, à décider)
    - Recâbler `InstanceSafety` pour recevoir les sorties de `BusAggregator` au lieu de `LocalEthercatOk`
    - Exemple :
      ```
      InstanceSafety(
          Enable := TRUE,
          EStopArmed := LocalEmergencyStopTOR,
          CanOnline := GVL_BusHealth.BusHealth.CanHealthy (ou DiagCanOpen.CanOnline),
          CanOperational := GVL_BusHealth.BusHealth.CanHealthy,
          JoystickAvailable := GVL_BusHealth.BusHealth.JoystickAvailable,
          EncoderM1Available := GVL_BusHealth.BusHealth.EncoderM1Available,
          EncoderM2Available := GVL_BusHealth.BusHealth.EncoderM2Available,
          VariateurAvailable := GVL_BusHealth.BusHealth.VariateurAvailable
      );
      ```

11. **Réinjecter dans Device.export**
    ```bash
    python tools/inject.py --yes
    ```
    Confirme `[t]out` pour réinjecter tous les fichiers modifiés.

12. **Réimporter Device.export dans CODESYS**  
    - Project → Build → Reimport (ou drag-drop Device.export)
    - Compile l'ensemble du projet

---

## 🧪 Vérification

### Tests unitaires (simulés)

- **FB_DiagCanOpen :** Connecte `DeviceState := DEVICE_STATE.NOT_FOUND` → vérifie `JoystickAvailable = FALSE`
- **FB_BusAggregator :** `EncoderM1Online := FALSE` seul → `EncoderM1Available = FALSE`, `EncoderM2Available = TRUE`
- **FB_Safety :** `EncoderM1Available := FALSE` → `ErrorId.3 = TRUE`, `SafeStop = TRUE`
- **FB_Encoder_Abs :** `EthOnline := FALSE` → `ErrorId.2 = TRUE`, `Error = TRUE`

### Tests intégrés

- Lance MainTask (20ms) → PRG_BusMonitor s'exécute
- Vérifie que `GVL_BusHealth.BusHealth` se remplit correctement
- Simule une perte de joystick CAN → `SafeStop` doit passer TRUE
- Simule une perte d'encodeur M1 → `FB_Encoder_Abs` (M1) doit se gater

---

## ⚠️ Points d'attention

### GVL_BusHealth non créée
Ce projet ne contient **pas** une GVL appelée `GVL_BusHealth` actuellement.  
Tu dois la créer manuellement dans CODESYS avec le contenu :
```codesys
VAR_GLOBAL
    BusHealth : ST_BusHealth;
END_VAR
```

### Références variables EtherCAT
Dans `PRG_BusMonitor.st`, certaines références sont placeholders :
- `CoE_Encoder1_WcState`, `CoE_Encoder1_State`
- `CoE_Encoder2_WcState`, `CoE_Encoder2_State`
- `CoE_Variateur_WcState`, `CoE_Variateur_State`

Tu dois les remplacer par les vraies variables EtherCAT/I/O de ton projet.

### Nomenclature instances
- Dans PRG_BusMonitor : `DiagEthEncoderM1`, `DiagEthEncoderM2`, `DiagEthVariateur`
- Dans PRG_COD1 : renommer `instFB_Encoder_Abs_0` → `EncoderM1`
- (Créer PRG_COD2 avec instance `EncoderM2`)

---

## 📚 Fichiers d'aide

- `_TYPES.st` : Enum + Struct déclarations
- `FB_DiagCanOpen.st` : Bus CAN + Joystick
- `FB_BusAggregator.st` : Consolidation (2 buses)
- `PRG_BusMonitor.st` : Programme orchestration
- `FB_Encoder_Abs_REFACTORED.st` : Version refactorisée (copy-paste dans XML)
- `FB_Safety_REFACTORED.st` : Inputs granulaires (copy-paste dans XML)

---

## 🔄 Workflow complet

```bash
# 1. Créer les nouveaux POUs dans CODESYS (manuellement)
#    - _TYPES (GVL)
#    - FB_DiagCanOpen
#    - FB_BusAggregator
#    - PRG_BusMonitor
#    - GVL_BusHealth

# 2. Exporter depuis CODESYS
#    File → Generate → Device.export

# 3. Extraire
extract.py --yes

# 4. Modifier les XML existants avec le contenu des _REFACTORED.st
#    (ou utiliser Edit tool pour remplacer <TextBlobForSerialisation>)

# 5. Réinjecter
inject.py --yes

# 6. Réimporter dans CODESYS
#    Project → Build → Reimport Device.export

# 7. Compiler & tester
```

---

## 📞 Besoin d'aide ?

- Vérifier les chemins relatifs des imports (VAR declarations)
- Vérifier les types CAN/ETHERCAT (BUS_STATE, DEVICE_STATE) existent
- Vérifier que GVL_BusHealth est défini globalement
- Vérifier que PRG_BusMonitor est assigné à la bonne tâche (MainTask ou CanTask)
