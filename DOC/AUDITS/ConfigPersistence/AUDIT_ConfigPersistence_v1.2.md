# 🔎 Audit — Persistance des données IHM & homogénéisation structs (v1.2)

> 📄 **Document de synthèse et plan d'exécution validé** (2026-07-23).
> Consolide toutes les décisions d'architecture validées pour l'exécution future.
> 📌 Suivi actions : `PLAN_TASK_v1.0.md` T65-T71.
> 🔁 Remplace `AUDIT_ConfigPersistence_v1.1.md`.

---

## 0. Résumé exécutif

Le 2026-07-23, un bug de persistance (`CfgMaxStepDescente` revenant aux valeurs usine) a déclenché un audit complet de la mémoire `GVL_PERSISTENT` et des structures de `GVL_IHM`.

**Décision majeure validée avec l'utilisateur** :
1. **Homogénéisation globale** : Restructuration complète des 10 groupes `GVL_IHM` en sous-structures standardisées `Cmd / State / Cfg / Safety / Bypass`.
2. **Acceptation du remapping** : Validation explicite par l'utilisateur de restructurer y compris `Modes`, `Joystick` et `Cycle` pour unifier l'ensemble du projet, avec ajouts métier ciblés (neutres calibrés dans `Joystick.State`, table `Cycle.Cfg` dédiée).
3. **Sécurisation technique (Option A)** : Généralisation de la persistance par **FB Ponts Génériques** (`FB_CfgPersistBridge_*`) pour éliminer tout risque d'oubli manuel.
4. **Outillage CI/CD** : Script Python `check_config_persistence.py` simple et rapide pour valider l'intégrité de la persistance à chaque build.

---

## 1. Ce qui est FAIT (Codé & Commité `7727123`)

| Item | Détail |
|---|---|
| **Fix Winch/Sync** | `CfgMaxStepDescente/Ascent`, rampes, limites câble (M1/M2), tolérance synchro — flag `Initialized`/`CfgInitialized` + alarme `ConfigRestoredFromPersistent` + acquittement front `BtnAckConfigRestored`. |
| **Fix Bypass** | `BypassRestoreDone` : `VAR` simple → `VAR RETAIN` dans `PRG_09_Supervision`. |
| **Revue Sécurité** | Validation expert : zéro impact sur les commandes physiques (`PRG_06` lit `GVL_PERSISTENT`). |

---

## 2. Plan d'Homogénéisation des Structs `GVL_IHM` (Validé)

Tous les groupes `GVL_IHM` adopteront la structure unifiée `Cmd / State / Cfg / Safety / Bypass` :

| Groupe | Struct | Évolution & Décision Validée |
|---|---|---|
| `M1TreuilRetenue` / `M2TreuilBenne` | `ST_WinchHMI` | ✅ Conforme (`Cmd / State / Cfg / Safety / Bypass`). |
| `TranslationM3` | `ST_TranslationHMI` | ✅ Conforme (`Cmd / State / Cfg / Safety / Bypass`). |
| `Network` | `ST_NetworkDiagHMI` | ✅ Conforme (Diagnostic + Bypass). |
| `M2Benne` | `ST_BucketHMI` | 🛠️ Restructurer en `Cmd / State / Cfg / Bypass` (`State` mécanique renommé `MechState`). |
| `Sync` | `ST_SyncHMI` | 🛠️ Restructurer en `Cmd / State / Cfg / Bypass`. |
| `Modes` | `ST_ModesHMI` | 🛠️ **Restructurer en `Cmd / State`** (décision utilisateur validée). |
| `JOY1Joystick` | `ST_JoystickHMI` | 🛠️ **Restructurer en `Cmd / State`** + **Ajout dans `State` de `NeutralXAct`/`NeutralYAct`** (lecture seule neutres calibrés). |
| `Cycle` | `ST_CycleHMI` | 🛠️ **Restructurer en `Cmd / State / Cfg / Test`** + **Création `ST_CycleCfg`** (`SetDepth_M`, `SetOffset_M`, `CfgMaxSpeed_Pct`, `CfgDrainingPauseTime`). `CycleStep` reste **non-persistant** (repart en `INIT`). |
| `Commun` | `ST_CommunHMI` | 🛠️ **Extraction sous-struct `Cfg`** (`ST_CommunCfg` : `LimitLegalDepthMinAllowed_M`, `LimitLegalEnabled`, `SelHomingApproachEnable`). |

---

## 3. Architecture Technique de Persistance (Option A Validée)

### 🧱 Principe du FB Pont Générique
Pour chaque type de struct `Cfg` ou `Bypass`, un Function Block court assure la liaison bidirectionnelle sécurisée entre `GVL_IHM` (RETAIN) et `GVL_PERSISTENT` :

```pascal
FUNCTION_BLOCK PUBLIC FB_CfgPersistBridge_WinchCfg
VAR_IN_OUT
    IhmCfg      : ST_WinchCfg;
    PersistCfg  : ST_WinchCfg;
END_VAR
VAR_OUTPUT
    RestoredThisScan : BOOL;
END_VAR

IF NOT IhmCfg.Initialized THEN
    IhmCfg := PersistCfg;           // 📥 Boot : Restauration 1 ligne depuis PERSISTENT
    IhmCfg.Initialized := TRUE;
    RestoredThisScan := TRUE;
ELSE
    PersistCfg := IhmCfg;           // 📤 Run : Sauvegarde continue 1 ligne vers PERSISTENT
END_IF;
```

### 🔒 Sécurité des Bypasses
- Les Bypasses restent en **`VAR_GLOBAL RETAIN` simple** (réinitialisés à `FALSE` lors d'un `Download` de code).
- Chaque struct `Bypass` possède son propre flag `Initialized` co-localisé (élimine le flag central partagé `BypassRestoreDone`).

---

## 4. Spécification du Script Python Gate (`check_config_persistence.py`)

Fichier : `TOOLS/AGENT_WORKFLOW/scripts/check_config_persistence.py`

### 🧪 Les 4 Contrôles Automatisés
1. **Contrôle Miroir `Cfg` $\leftrightarrow$ `PERSISTENT`** :  
   Vérifie que chaque champ présent dans un struct `*Cfg.st` possède son équivalent exact dans `GVL_PERSISTENT.st`.
2. **Contrôle Guard `Initialized`** :  
   Vérifie que tout struct `Cfg` ou `Bypass` intègre le champ `Initialized : BOOL`.
3. **Interdiction de la Sentinelle `= 0.0`** :  
   Scanne `PRG_09_Supervision.st` et bloque l'utilisation du pattern obsolète `IF ... = 0.0 THEN`.
4. **Contrôle de Non-Persistance Sécurité** :  
   Interdit la présence de variables volatiles (`CycleStep`, `DeadmanArmed`, bits de commande directes) dans `GVL_PERSISTENT.st`.

---

## 5. Feuille de Route d'Exécution (Prochaines Étapes)

1. 📝 **Étape 1** : Création/Mise à jour des types `ST_*Cfg` (`ST_CycleCfg`, `ST_CommunCfg`, `ST_WinchCfg`...) et restructuration des 10 types `ST_*HMI`.
2. 🧱 **Étape 2** : Implémentation des FB Ponts `FB_CfgPersistBridge_*`.
3. ⚙️ **Étape 3** : Mise à jour de `PRG_09_Supervision.st` (remplacement du code de copie manuel par les appels aux FB ponts).
4. 🐍 **Étape 4** : Écriture et intégration du script `check_config_persistence.py` dans `run_all_gates.py`.
5. 📦 **Étape 5** : Régénération du bundle XML `CODE/CODE_Bundle.xml` et validation finale.
