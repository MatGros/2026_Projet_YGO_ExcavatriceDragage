# 🚀 SETUP FINAL — Création des POUs dans CODESYS

**Objectif** : Créer une base saine et importable en CODESYS sans problème.

**Workflow** :
1. Crée chaque POU dans CODESYS (copie-colle les codes ST fournis)
2. Compile & vérifie qu'il n'y a pas d'erreur
3. **Exporte Device.export** quand tout est OK
4. Réinjecte proprement via `inject.py`

---

## 📋 Checklist — POUs à créer (dans cet ordre)

### ✅ Prérequis : Types & GVL

**1. Créer une GVL `_TYPES` (Global Variable List)**

Dans CODESYS :
- Right-click **Application** → **Add Object** → **Global Variable List**
- Nom : `_TYPES`
- Éditeur : ST (Text)

**Contenu à copier-coller :**
```codesys
{ATTRIBUTE 'qualified_only'}
VAR_GLOBAL CONSTANT
END_VAR

{ATTRIBUTE 'qualified_only'}
VAR_GLOBAL
    (* Degradation level enum *)
    E_DegradationLevel_FULL        : INT := 0;
    E_DegradationLevel_LEVEL1      : INT := 1;
    E_DegradationLevel_LEVEL2      : INT := 2;
    E_DegradationLevel_MAINTENANCE : INT := 3;
END_VAR
```

**Alternative (plus propre - TYPE dans GVL)** :
```codesys
TYPE E_DegradationLevel :
(
    FULL        := 0,
    LEVEL1      := 1,
    LEVEL2      := 2,
    MAINTENANCE := 3
);
END_TYPE

TYPE ST_BusHealth :
STRUCT
    CanHealthy          : BOOL;
    EthercatHealthy     : BOOL;
    GlobalHealthy       : BOOL;
    JoystickAvailable   : BOOL;
    EncoderM1Available  : BOOL;
    EncoderM2Available  : BOOL;
    VariateurAvailable  : BOOL;
END_STRUCT
END_TYPE
```

---

**2. Créer une GVL `GVL_BusHealth`**

Dans CODESYS :
- Right-click **Application** → **Add Object** → **Global Variable List**
- Nom : `GVL_BusHealth`
- Éditeur : ST

**Contenu :**
```codesys
{ATTRIBUTE 'qualified_only'}
VAR_GLOBAL
    BusHealth : ST_BusHealth;
END_VAR
```

---

### ✅ Nouveaux FBs

**3. Créer `FB_DiagCanOpen` (Function Block)**

Dans CODESYS → SYSTEM folder :
- Right-click **SYSTEM** → **Add Object** → **Function Block**
- Nom : `FB_DiagCanOpen`
- Langage : ST

**Copie le contenu complet du fichier CODE/FB_DiagCanOpen.st**

---

**4. Créer `FB_BusAggregator` (Function Block)**

Dans CODESYS → SYSTEM folder :
- Right-click **SYSTEM** → **Add Object** → **Function Block**
- Nom : `FB_BusAggregator`
- Langage : ST

**Copie le contenu complet du fichier CODE/FB_BusAggregator.st**

---

**5. Créer `PRG_BusMonitor` (Program)**

Dans CODESYS → **Logique API** → **SYSTEM** task :
- Right-click **SYSTEM** → **Add Object** → **Program**
- Nom : `PRG_BusMonitor`
- Langage : ST
- **Assignement à tâche** : MainTask (20ms) ou CanTask (10ms) — tu choisis

**Copie du fichier CODE/PRG_BusMonitor.st avec ADAPTATIONS** :
- Remplace `CoE_Encoder1_WcState`, etc. par **tes vraies variables EtherCAT**
- Remplace `CANopen_Manager.GetBusState(...)` par l'appel réel
- Remplace `GVL_DEBUG.DBG_ResetBusHealth` par la vraie variable Reset

---

## 🔧 Modifications POUs existants

⚠️ **Ces modifications sont complexes.** Tu as deux options :

### Option 1 : Modifications manuelles dans CODESYS (sûr)
- Ouvre chaque FB dans CODESYS
- Modifie directement l'interface et le code
- Compile & teste
- Exporte Device.export

### Option 2 : Modifications via CODE/ XML (rapide mais technique)
- Je modifie les fichiers XML via Edit
- Tu réinjectes avec `inject.py --yes`
- Tu réimportes dans CODESYS

Je recommande **Option 1** pour la tranquillité.

---

## 📝 Modifications détaillées (Option 1 — Manuel)

### **FB_DiagEthercat** — Déjà modifié dans CODE/diagETHERCAT__....xml

Vérification seulement : ouvre le FB dans CODESYS et vérifie que tu as :
- ✅ Interface complète (Reset, StateAtError)
- ✅ ResetEdge : R_TRIG en VAR
- ✅ Logique Reset sur front (ResetEdge.Q)

Si non → copie le contenu de `CODE/diagETHERCAT__...xml` → remplace dans CODESYS

---

### **FB_Safety** — Inputs granulaires

**Avant (current)** :
```codesys
VAR_INPUT
    ...
    EthercatOk : BOOL;    // Plat, pas granulaire
END_VAR
```

**Après** :
```codesys
VAR_INPUT
    ...
    JoystickAvailable   : BOOL;
    EncoderM1Available  : BOOL;
    EncoderM2Available  : BOOL;
    VariateurAvailable  : BOOL;
END_VAR
```

**Copie le code complet de CODE/FB_Safety_REFACTORED.st**

---

### **FB_Encoder_Abs** — Conformité AF_Partie3

**Avant** : interface incomplète, corps dupliqué, pas ErrorId bitfield

**Après** : conforme AF_Partie3, Reset R_TRIG, ErrorId bitfield, gate EtherCAT

**⚠️ Attention** : Ce changement est important. 
**Copie le code COMPLET de CODE/FB_Encoder_Abs_REFACTORED.st**

(ou applique manuellement : c'est faisable mais long)

---

### **PLC_PRG_MAIN** — Recâblage

Changements :
1. Supprimer `InstanceJoystick : FB_Joystick;` en double
2. Recâbler `InstanceSafety` avec sorties de `BusAggregator`

**Pseudo-code** :
```codesys
// Appel de Safety avec inputs granulaires
InstanceSafety(
    Enable := TRUE,
    EStopArmed := LocalEmergencyStopTOR,
    CanOnline := GVL_BusHealth.BusHealth.CanHealthy,
    CanOperational := GVL_BusHealth.BusHealth.CanHealthy,
    JoystickAvailable := GVL_BusHealth.BusHealth.JoystickAvailable,
    EncoderM1Available := GVL_BusHealth.BusHealth.EncoderM1Available,
    EncoderM2Available := GVL_BusHealth.BusHealth.EncoderM2Available,
    VariateurAvailable := GVL_BusHealth.BusHealth.VariateurAvailable
);
```

---

## 🔄 Workflow final

```
1. CODESYS : Crée les 5 POUs (_TYPES, GVL_BusHealth, 3 FBs) + Modifications
   └─ Compile & teste chaque création
   
2. CODESYS : File → Export → Device.export
   
3. Terminal : python tools/extract.py --yes
   └─ Vérifie que les 3 nouveaux FBs sont en XML
   
4. Vérification : Check CODE/*.xml (ne doit pas avoir de <Null Name="TextLines" />)
   
5. Terminal : python tools/inject.py --yes
   └─ Réinjecte les fichiers modifiés (diagETHERCAT, FB_Safety, etc.)
   
6. CODESYS : Reimport Device.export
   └─ Compile l'ensemble
   
7. ✅ Test & déploiement
```

---

## 📞 Besoin d'aide ?

Si une création échoue dans CODESYS :
1. **Erreur de syntaxe** → vérifie que le code ST est complet (pas de `&lt;` `&gt;`)
2. **Type manquant** → assure-toi que _TYPES est créée EN PREMIER
3. **Variable non trouvée** → vérifie que GVL_BusHealth existe
4. **Import échoue** → sauvegarde le project, ferme CODESYS, réouvre, puis reimporte

---

## ✅ Signal de succès

Quand tu auras créé et exporté :
- ✅ Device.export contient les 5 nouveaux POUs (3 FBs + 2 GVLs)
- ✅ Pas d'erreurs de compilation dans CODESYS
- ✅ extract.py montre `nouveaux : 5 | modifiés : X | inchangés : Y`

Quand c'est OK → dis-moi et on termine les injections XML.
