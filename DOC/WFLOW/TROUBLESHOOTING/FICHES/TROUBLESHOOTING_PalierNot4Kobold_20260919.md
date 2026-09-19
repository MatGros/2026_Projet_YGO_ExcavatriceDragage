# 🕵️ Diagnostic — Défaut cycle SEMI_AUTO "Palier 4 non confirmé" (bit9) en simulation

📅 2026-09-19 · 🧊 SIMULATION BANC · 📄 Statut : **EN COURS — cause indirecte non prouvée**

## 1. Symptôme

En cycle SEMI_AUTO (plongée Kobold), le défaut **`instCauses[9]`** — *"Palier 4 non confirmé sur
M1 et/ou M2 pendant la recherche Kobold"* — se déclenche en simulation, quasi instantanément après
une manip de coupure/relance joystick. Le joystick reste **en permanence déflecté à fond** en
simulation (jamais relâché) : ce n'est donc **pas** un problème d'homme-mort/joystick.

## 2. Preuve obtenue par trace CODESYS (`Suivi_55_SIMU_DefMecaB_20260919.trace`)

Outil utilisé : `TOOLS/PLC_CSV_SNAPSHOT/external_python/trace_to_csv.py` (validé — sortie
recoupée avec un parsing manuel, résultats identiques).

Chronologie (repère `PRG_03_Modes_Cycle.instCycleSemiAuto.CycleStep`) :

| t (ms) | Étape | Fait observé |
|---|---|---|
| 11085 | AX4 (descente plongée) | M1 et M2 rampent `0→1→2→3→4` en ~1,6s (conforme, 500ms/cran) |
| 12697 | AX4 | M1 **et** M2 confirment palier **4** |
| **14307** | **entrée AX5** (init Kobold) | `M1_M2_KoboldMeasureEnable_RQ` passe 0→1 **ET**, au **même timestamp**, `M1.StepNumber` et `M2.StepNumber` retombent **instantanément à 0**, ensemble |
| — | AX5→AX6→AX7 | le palier **ne remonte jamais** à 4 |
| 14808 | entrée AX6 | `PalierNot4Timer` (PT=2s) démarre |
| **16819** | — | défaut déclenché — soit **2011 ms** après l'entrée AX6 (quasi exactement 2,0s) |

**Conclusion directe (prouvée)** : l'activation du contacteur Kobold à l'entrée d'AX5 coïncide
avec une remise à zéro simultanée du palier M1 **et** M2. Rien ne les relance avant l'expiration du
watchdog 2s démarré en AX6.

## 3. Mécanisme identifié dans le code (cause directe, prouvée par lecture)

Un seul bloc de `FB_CycleSemiAuto.st` (lignes 638-696) peut zéroter **M1 et M2 simultanément** :

```
IF NOT Enable OR NOT PowerContactorEngaged OR EncoderFaultPresent THEN
    WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.StepTgt := 0;
    WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.StepTgt := 0;
    ...
    RETURN;
END_IF;
```

C'est une neutralisation "retour sécurisé" prévue pour une vraie coupure globale (Enable OFF,
perte puissance) — mais si l'une des 3 conditions "clignote" un seul scan pendant AX5/AX6, elle
coupe les deux treuils **au milieu même de la fenêtre qui vérifie le palier** (remarque de
l'utilisateur, validée : un reset ne doit jamais s'invoquer pendant l'étape qui surveille le
défaut, seulement aux transitions d'état légitimes).

## 4. Cause INDIRECTE — pas encore prouvée (3 candidats, 1 déjà écarté)

| Candidat | Source (simulation) | Statut |
|---|---|---|
| `EncoderFaultPresent` | `FB_SimBench.st:426/432` — `COD1/COD2_DeviceState` figé en dur à `RUNNING` | ❌ **Écarté avec certitude** — ne peut jamais valoir autre chose que FAUX en sim |
| `PowerContactorEngaged` | `instSimSafety.SimContactorOk` (`FB_Sim_Safety.st`) — ne retombe que si `ChainOpenReq` (chaîne AU / test coupure / `PowerCutOffRequest`) reste vrai `CST_ContactorDropDelay` | 🟡 Aucun lien visible avec le Kobold à ce stade — pas encore vérifié en trace |
| `Enable` (`instModes.Auth.Mode = SEMI_AUTO`) | `FB_Modes` (arbitrage mode) | 🟡 **Piste la plus probable**, pas encore vérifiée en trace |

## 5. Prochaine étape — variables à ajouter à la trace (chemins exacts)

```
PRG_03_Modes_Cycle.instCycleSemiAuto.Enable
PRG_03_Modes_Cycle.instCycleSemiAuto.PowerContactorEngaged
PRG_03_Modes_Cycle.instModes.Auth.Mode
PRG_03_Modes_Cycle.instCycleSemiAuto.EncoderFaultPresent   (optionnel, déjà écarté par le code)
```

Refaire la même manip (coupure joystick + relance rapide) avec ces 4 variables en plus de celles
déjà tracées (`CycleStep`, `M1/M2.StepNumber`, `EncoderM1/M2.CablePosM`, `Joystick.*`,
`M1_M2_KoboldMeasureEnable_RQ`, etc. — liste complète dans le `.trace` original).

**Ce qui confirmera la cause** : laquelle des 3 variables passe à une valeur "défaut" exactement à
`t≈14307ms` (entrée AX5 / activation Kobold). Une fois identifiée, remonter à SA propre source
(pourquoi elle bascule à cet instant) avant de proposer un correctif — ne pas corriger le symptôme
(le bloc RETURN) sans avoir compris pourquoi une des 3 conditions se déclenche.

## 6. Règle d'or — rappel

⛔ Aucune modification de code n'a été faite sur ce sujet. Cause à prouver par lecture de variable
(trace), jamais par inférence seule. Ne pas modifier `FB_CycleSemiAuto.st` sans validation humaine
explicite une fois la cause indirecte confirmée.

## 7. Fichiers/outils utiles pour la suite

- Trace analysée : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_55_SIMU_DefMecaB_20260919.trace`
- Convertisseur (⚠️ non documenté dans le skill troubleshooting, à corriger séparément) :
  `TOOLS/PLC_CSV_SNAPSHOT/external_python/trace_to_csv.py` + `select_trace_and_export.ps1`
- Code clé : `CODE/G_CYCLE/FB_CycleSemiAuto.st` (§ lignes 339-350 cause 8/9, §638-696 garde global),
  `CODE/M_MAIN/PRG_03_Modes_Cycle.st:190-194` (câblage Enable/PowerContactorEngaged/EncoderFaultPresent)
