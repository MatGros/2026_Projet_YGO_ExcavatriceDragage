# 🕵️ Session de Troubleshooting — Défaut VH0008ER (DO8) qui persiste malgré les bypass

> 📅 Date : 2026-09-01 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [EN COURS]

## 1. 🧊 Contexte figé (horodaté)

> Acquisition : snapshot `Snapshot_Troubleshooting_20260901_234514.csv` (540/540, PASS).

### Variables & valeurs clés
| Élément | Variable complète (lecture) | Valeur | Verdict |
|---|---|---|---|
| Bypass réseau global (IHM) | `A_ContexteMachineGlobal.Idx202_BypassNetworkGlobal` (= `GVL_IHM.Network.Bypass.Global`) | **FALSE** | 🔴 C'est LE blocage |
| Simulation | `C_Safety.SimSafetyActive` | FALSE | 🟡 |
| Simulation | `A_ContexteMachineGlobal.Idx102_SimulationEnabled` | TRUE | 🟡 |
| M1 Bypass global | `I_LevageUnitaireM1.Safety_300.Idx329_BypassGlobal` | TRUE | ✅ |
| M1 Bypass commun | `I_LevageUnitaireM1.Safety_300.Idx330_BypassGlobalCommun` | TRUE | ✅ |
| M2 Bypass global | `J_LevageUnitaireM2.Safety_300.Idx329_BypassGlobal` | TRUE | ✅ |
| Translation Bypass réseau | `L_TranslationPontM3.Demandes_200.Idx208_BypassNetworkActive` | TRUE | ✅ |
| M3 Safety ErrorId | `L_TranslationPontM3.Safety_300.Idx317_ErrorId` | WORD#3 | 🟡 |
| M1 ErrorOperatorComm | `I_LevageUnitaireM1.Safety_300.Idx310_ErrorOperatorComm` | TRUE | 🟡 |
| M2 ErrorOperatorComm | `J_LevageUnitaireM2.Safety_300.Idx310_ErrorOperatorComm` | TRUE | 🟡 |
| M3 ErrorOperatorComm | `L_TranslationPontM3.Safety_300.Idx309_ErrorOperatorComm` | TRUE | 🟡 |
| M3 ErrorDriveComm | `L_TranslationPontM3.Safety_300.Idx310_ErrorDriveComm` | TRUE | 🟡 |
| AC600 DeviceState | `B_Inputs.Translation.AC600_DeviceState` | `NOT_FOUND` | 🟡 |
| JOY1 DeviceState | `B_Inputs.Operator.JOY1_DeviceState` | `UNKNOWN` | 🟡 |
| CanBusState | `B_Inputs.Operator.CanBusState` | INT#0 | 🟡 |

## 2. 🎯 Symptôme

Le défaut `[IO] Defaut module VH0008ER (DO8 Relais)` (4/7) **persiste** alors que l'utilisateur a activé **tous** les bypass RETAIN (`BypassNetworkGlobal`, `BypassCommunGlobal`, etc.) = TRUE. Malgré `BypassNetworkGlobal=TRUE`, le défaut de communication du module reste affiché.

## 3. 🧩 Indices / historique

- L'utilisateur a forcé tous les `Bypass*Global` du `GVL_BypassRetain` (Translation/WinchM1/M2/Sync/Network/Bucket/Commun + limites) à TRUE.
- Beaucoup de bypass **sont** effectifs (M1/M2/Translation/Sync lus TRUE dans le snapshot).
- MAIS le défaut VH0008ER reste.
- Mode `MAINT_N1`, simulation activée, banque.

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | Le bypass réseau n'atteint **pas** la variable qui coupe le défaut module E/S | `GVL_IHM.Network.Bypass.Global` (via `Idx202`) | TRUE si bypass efficace | FALSE | ✅ **Branche fautive** |
| 2 | Le défaut est déclenché par `NOT Vh0008ErValid`, alimenté par `Network.InputModules.Vh0008ErOk` | `PRG_02_Acquisition.Data.InputModules.Vh0008ErOk` | doit être TRUE si bypass | (voir §5) | 🟡 |
| 3 | `PRG_02` ne force les modules OK que si `Bypass.Global` OU `Bypass.InputModules` | `GVL_IHM.Network.Bypass.InputModules` | doit être TRUE | (non lu, à confirmer) | ❓ |
| 4 | La sim ne force pas les modules (SimSafetyActive=FALSE) | `C_Safety.SimSafetyActive` | TRUE si module sim forcé | FALSE | 🟡 |

## 5. 📊 Arbre vertical des hypothèses (flux de données)

```text
GVL_BypassRetain.BypassNetworkGlobal (RETAIN, forcé TRUE)
   └─>?? PRG_07 restauration boot (§2b) ne traite PAS BypassNetworkGlobal
       └─>?? PRG_07 synchro (mirror) ne traite PAS BypassNetworkGlobal
           => GVL_IHM.Network.Bypass.Global reste FALSE  🔴
                 |
                 ├─>PRG_02 §1bis: IF MachineSimulated OR Bypass.Global OR InputModules THEN
                 |      Vh0008ErOk := TRUE     ← NE PASSE PAS (Bypass.Global=FALSE)
                 |      ELSE Vh0008ErOk := (VH_0008ER.GetDeviceState()=RUNNING)  ← exécuté
                 |
                 └─>Vh0008ErOk=FALSE → NOT Ok → TofFault(1.5s) → Vh0008ErValid=FALSE
                    → FB_Hmi_BannerFormatter §5.0 ligne 592
                    → Alarme "[IO] Defaut module VH0008ER (DO8 Relais)"  🔴
```

**Résumé une ligne** : `BypassNetworkGlobalRETAIN=1 → non câblé → Network.Bypass.Global=0 → Vh0008ErOk dépend état réel → défaut maintenu` 🔴

## 6. 📊 Données / interactions

### Cause racine démontrée par le code
Les 3 sources du bypass réseau **ne mentionnent pas** `Network.Bypass.Global` :
- `PRG_07_Supervision.st` §2b (lignes 232-285) : restaure `BypassTranslation/M1/M2/Sync/Commun/...` mais **AUCUN** `BypassNetworkGlobal` ni `BypassBucketGlobal`.
- `PRG_07_Supervision.st` §2c (lignes 290-299) : 9 `instMirrorBypass*`, mais **aucun** pour `Network.Bypass` ni `Bucket`.
- `PRG_02_Acquisition.st` ligne 185 : condition d'activation = `MachineInputSourceSimulated OR GVL_IHM.Network.Bypass.Global OR GVL_IHM.Network.Bypass.InputModules`. Seuls ces **2 champs IHM** coupent le défaut module.

=> Le `BypassNetworkGlobal` du `GVL_BypassRetain` est **une variable orpheline** : déclarée, jamais relayée vers `GVL_IHM.Network.Bypass.Global`. Forcée à TRUE, elle n'agit sur rien.

## 7. 🏁 Conclusion

- **Cause racine** : `BypassNetworkGlobal` (RETAIN) n'est **jamais propagé** vers `GVL_IHM.Network.Bypass.Global` (ni vers `.InputModules`). Le diagnostic module E/S de `PRG_02` ne lit que `GVL_IHM.Network.Bypass.Global`/`.InputModules`. Du coup le défaut du module VH0008ER (état réel non RUNNING) reste levé.
- **Statut** : CAUSE IDENTIFIÉE — correction à valider.

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : forcer `GVL_IHM.Network.Bypass.Global := TRUE` **ou** `GVL_IHM.Network.Bypass.InputModules := TRUE` directement à l'IHM. Impact : coupe le défaut module E/S sur-le-champ. Risque : bypass réseau total (jamais en production).
- **Option 2 (définitif / cohérence du projet)** : câbler `BypassNetworkGlobal` dans `PRG_07` comme les autres (restauration boot + mirror `instMirrorBypassNetwork`), et de même pour `BypassBucketGlobal` (probablement aussi orphelin). Impact : comportement symétrique aux autres bypass. Nécessite build + test CI.
- **⚠️ Validation requise** : humaine — ne pas modifier le code / forcer une variable sans validation.

## 9. ✅ Vérification de la correction / non-régression

> À compléter après application validée. Critère : `Vh0008ErValid=TRUE` et alarme 4/7 disparue, sans régression sur les autres axes.

## 10. 📝 Journal (chronologique)

- 2026-09-01 : diagnostic initial. Snapshot `..._234514.csv` analysé. Cause racine = `BypassNetworkGlobal` non câblé vers `GVL_IHM.Network.Bypass.Global`.

---

📖 Guide de remplissage : `GUIDE_Troubleshooting.md` (même dossier).
