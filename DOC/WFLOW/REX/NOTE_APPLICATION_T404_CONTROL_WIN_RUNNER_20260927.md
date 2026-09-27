# T404 — POC Control Win Runner isolé

## Verdict

🟠 **Chaîne de copie et de transformation validée, déploiement volontairement bloqué.**

| Contrôle | Résultat |
|---|---|
| Projet source sélectionné | `v0.7.29_SimBench_POC_UDP_20260927.project` |
| SHA-256 source avant/après | `c6e12a7a8a09da7981c82ad26d79d8409f4f27ae8f75aa366b8cf5e0805b7ab5` — identique |
| Workspace | `%LOCALAPPDATA%\TwinBenchControlWin` |
| Device source | type `4097`, ID `0000 000a`, version `3.5.19.10` |
| Device dérivé | type `4096`, ID `0000 0004`, version `3.5.19.10` |
| Import Application natif | PASS |
| Compilation Control Win | REFUS — 293 erreurs, 1 avertissement |
| Déploiement | Non exécuté, bloqué par le runner |
| Service Control Win | Arrêté après le test |

## Architecture retenue

L'API `Update Device` ne remplace pas le device constructeur par Control Win dans
ce projet. Le runner ne force donc plus cette opération. Il :

1. copie le projet sélectionné sous `Imported_Source.project` ;
2. exporte nativement son objet `Application` depuis cette copie ;
3. crée un projet neuf avec `CODESYS Control Win V3 x64` ;
4. importe l'Application complète sous le nouveau `PLC Logic` ;
5. compile avant d'autoriser tout téléchargement.

Le projet original n'est jamais ouvert par CODESYS.

## Cause du refus de compilation

Les variables et objets produits par l'arbre matériel du PLC réel ne se trouvent
pas dans l'objet `Application`. Leur absence est donc normale dans le projet
Control Win :

- entrées/sorties directes : `M3_PosTremie_DI`, `M3_CommandWord`,
  `M1_RelayAscent_RQ`, etc. ;
- codeurs : `COD1_*`, `COD2_*` et objets `COD1_CODEUR`, `COD2_CODEUR` ;
- objets de bus/device : `CANbus`, `AC600_ECAT_Drive`, `Local_Digital_IO`,
  `VH_0800END`, `VH_0808ETP`, `VH_0008ER`, etc. ;
- joystick et chaîne sécurité matériels.

Le rapport complet est local :
`%LOCALAPPDATA%\TwinBenchControlWin\Logs\20260927_160848_prepare.json`.

## Garde-fous validés

- autotest runner : `14/14 PASS` ;
- contrôle SHA-256 avant/après chaque action ;
- ScriptEngine confiné au dossier `Current` ;
- cible réseau future limitée à `PC-Z-VICTUS / CODESYS Control Win V3 x64` ;
- adresse de préparation `127.0.0.1` ;
- état `PREPARE_FAILED` interdisant le bouton Déployer ;
- aucune modification de `CODE/` ou `PRJ_CODESYS/` ;
- aucun login, téléchargement ou démarrage runtime pendant ce test.

## Décision requise

La suite nécessite un lot séparé : générer dans le **projet Control Win dérivé
uniquement** un adaptateur `HW_SIM` déclarant les symboles matériels simples et
remplaçant explicitement les appels `GetDeviceState()` des objets de bus.

Cet adaptateur ne doit jamais être importé dans le projet PLC réel. Sa génération
doit être reproductible depuis un catalogue versionné des symboles et types.

