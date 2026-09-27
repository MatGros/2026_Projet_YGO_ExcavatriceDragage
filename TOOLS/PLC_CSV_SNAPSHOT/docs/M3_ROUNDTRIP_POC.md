# POC T402 — communication M3 avec la Simulation IDE CODESYS

Ce test utilise l'API officielle **ScriptEngine** déjà installée. Il ne passe ni par OPC UA,
ni par OpenModelica et ne modifie pas le programme PLC.

## 1. Préparer CODESYS

- projet ouvert ;
- **Simulation** activée dans CODESYS ;
- Login effectué et application en RUN ;
- `GVL_Simulation.SimulationModeActive = TRUE` ;
- `GVL_Simulation.SimTranslationActive = TRUE`.

## 2. Test en lecture seule

Dans **Tools > Scripting**, exécuter :

```python
exec(compile(open(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\codesys_console\codesys_m3_roundtrip_poc.py", "rb").read(), "M3_POC", "exec"))
```

Résultat attendu : `PASS T402 PROBE` avec les trois commandes finales M3 et huit retours simulés.

## 3. Test aller-retour

Toujours dans **Tools > Scripting**, exécuter simplement le lanceur dédié :

```python
execfile(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\codesys_console\codesys_m3_roundtrip_pulse_maintenance.py")
```

Le script refuse le test hors Simulation IDE. Il place brièvement
`GVL_Simulation.SimBtnMaintenance` à `TRUE`, lit la chaîne M3 puis restaure obligatoirement
le bouton à `FALSE`. Le mouvement peut rester bloqué par les modes ou sécurités : la preuve
recherchée ici est l'échange de données, pas l'autorisation de mouvement.

Résultat attendu : `PASS T402 ROUNDTRIP`.

## Limite volontaire

Ce POC ne relie pas encore OpenModelica. L'étape suivante ajoutera un canal continu et des
variables dédiées aux retours de plante, après validation de cette première communication.
