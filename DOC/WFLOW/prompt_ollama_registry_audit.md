# Préambule obligatoire — sous-agent Ollama

## Contexte projet & Persona
Automate CODESYS 3.5, machine de dragage en carrière noyée. Code ST dans `CODE/`, appliqué manuellement par l'utilisateur. Sécurité machine réelle.

Expert Senior Automatisme Industriel. Style TDAH-Friendly. Réponds en français. Rigueur, zéro blabla.

---

## MISSION : Diagnostic et correction `registry.yaml` — dépendances manquantes des nouveaux DUTs T165-B1

### Contexte
La tâche T165-B1 a créé 3 nouveaux DUTs dans `CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/` :
- `ST_AcquisitionJoystickQualified.st` — dépend de `ST_fbJoystick_AxisCmd` (dans `CODE/D_JOYSTICK/`)
- `ST_AcquisitionNetworkDiagnostics.st` — dépend de `ST_Diag_Device` (dans `CODE/C_DIAG_RESEAUX/`), lui-même dépend de `E_Diag_State`
- `ST_AcquisitionEncoderQualified.st` — dépend de `ST_fbEncoder_HwOut` (dans `CODE/E_CODEURS/_TYPES/`)

Ces 3 DUTs ont été injectés dans `TOOLS/TEST_AUTO_CI/registry.yaml` pour les 7 entrées suivantes :
- `FB_SimBench` (L_SIMULATION)
- `FB_Hmi_BannerFormatter` (J_SUPERVISION) — déjà corrigé pour `E_OperatorAxis` et `ST_fbEncoder_HwOut`
- `PRG_02_Acquisition` (M_MAIN)
- `PRG_03_Modes_Cycle` (M_MAIN)
- `PRG_04_Treuils_Benne` (M_MAIN)
- `PRG_05_Translation` (M_MAIN)
- `PRG_07_Supervision` (M_MAIN)
- `MAIN_GLOBAL` (M_MAIN)

### Erreurs de compilation rencontrées (dernière exécution)

**PRG_05_Translation / PRG_07_Supervision :**
```
ST_AcquisitionNetworkDiagnostics.st:12: error: Undefined type 'ST_DIAG_DEVICE'
```
→ `ST_Diag_Device` manquant. Il faut : `E_Diag_State.st` + `ST_Diag_Device.st` AVANT `ST_AcquisitionNetworkDiagnostics.st`.

**PRG_03_Modes_Cycle :**
- Compilation réussie mais `.Busy/.Done/.Error` plats → déjà corrigé dans `FB_TestHarness_PRG_03.st`

**PRG_07_Supervision :**
```
ST_AcquisitionJoystickQualified.st:12: error: Undefined type 'ST_FBJOYSTICK_AXISCMD'
```
→ `ST_fbJoystick_AxisCmd` manquant avant `ST_AcquisitionJoystickQualified`. Déjà patché globalement par script Python mais à vérifier.

### TA MISSION (READ-AUDIT uniquement)

1. **Lire** `TOOLS/TEST_AUTO_CI/registry.yaml` (les entrées PRG_03, PRG_04, PRG_05, PRG_07, MAIN_GLOBAL).

2. **Vérifier** que pour chaque entrée contenant `ST_AcquisitionNetworkDiagnostics.st`, les 2 dépendances suivantes apparaissent **AVANT** dans la liste `sources:` :
   - `CODE/C_DIAG_RESEAUX/E_Diag_State.st`
   - `CODE/C_DIAG_RESEAUX/ST_Diag_Device.st`

3. **Vérifier** que pour chaque entrée contenant `ST_AcquisitionJoystickQualified.st`, la dépendance suivante apparaît **AVANT** :
   - `CODE/D_JOYSTICK/ST_fbJoystick_AxisCmd.st`

4. **Vérifier** que pour chaque entrée contenant `ST_AcquisitionEncoderQualified.st`, la dépendance suivante apparaît **AVANT** :
   - `CODE/E_CODEURS/_TYPES/ST_fbEncoder_HwOut.st`

5. **Produire un tableau** avec : entrée registry | dépendance | présente (✅/❌) | ligne approximative.

6. **Si des manques sont détectés** : rédiger les corrections exactes à appliquer (format diff ou description précise de l'insertion : après quelle ligne, quel contenu).

### Fichier à analyser
`TOOLS/TEST_AUTO_CI/registry.yaml`

### Fichiers DUT à lire pour connaître leurs dépendances exactes
- `CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_AcquisitionJoystickQualified.st`
- `CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_AcquisitionNetworkDiagnostics.st`
- `CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_AcquisitionEncoderQualified.st`

### Format de restitution attendu
```
## Audit dépendances registry.yaml

| Entrée | DUT | Dépendance | Présente |
|--------|-----|-----------|---------|
| PRG_05_Translation | ST_AcquisitionNetworkDiagnostics | E_Diag_State | ❌ |
...

## Corrections à appliquer
[Liste précise des insertions]
```
