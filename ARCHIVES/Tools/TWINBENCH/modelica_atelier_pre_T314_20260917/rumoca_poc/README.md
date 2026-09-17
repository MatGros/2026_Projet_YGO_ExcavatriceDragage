# POC Rumoca — M3

> **Statut 2026-09-17 : piste R&D gelée comme socle utilisateur.**
> La référence Windows du projet est OpenModelica + OMEdit + OMSimulator ; voir
> `DOC/WFLOW/AUDITS/REORIENTATION_RUMOCA_OPENMODELICA_20260917.md`.

Ce POC isole Rumoca de la bibliothèque Modelica Standard Library et de la scène OMEdit. Il teste
la chaîne minimale : Modelica → compilation Rumoca → simulation → rapport HTML.

Il reprend le cycle M3 de référence : Maintenance de 1 s à 5 s, puis Trémie de 7 s à 11 s.
Il ne remplace pas `Dredge.TranslationM3Plant`, OMSimulator, SimBench ni le PLC.

## Lancer

Pour l'utilisation normale, ne cherchez pas les fichiers internes : double-cliquez uniquement
sur `TOOLS/TWINBENCH/Lancer_TwinBench.bat`. Il ouvre l'atelier interactif avec M3, M1/M2,
commandes, vue 2D éditable et chronogramme.

Le plus simple : double-cliquer sur `Lancer_Rumoca_POC.bat`, puis choisir le scénario. Le
runtime portable attendu par le lanceur est `runtime/rumoca.exe`; à défaut il utilise la copie
locale `%LOCALAPPDATA%/TwinBench/runtime/rumoca/0.9.20/rumoca.exe`.

Depuis PowerShell à la racine du projet :

```powershell
powershell -ExecutionPolicy Bypass -File TOOLS/TWINBENCH/modelica_atelier/rumoca_poc/Run_Rumoca_M3_POC.ps1 -Scenario M3
```

Le fichier `RumocaM3Poc_<scenario>_dashboard.html` s'ouvre automatiquement. Le lanceur convertit le rapport
texte natif Rumoca en tableau de bord local avec courbes Canvas (position, vitesse, frein et
capteurs). Le script signale le temps mur ; c'est la première mesure
de performance, pas encore un benchmark certifié contre OpenModelica.

Pour la recette visuelle de séquence benne :

```powershell
powershell -ExecutionPolicy Bypass -File TOOLS/TWINBENCH/modelica_atelier/rumoca_poc/Run_Rumoca_M3_POC.ps1 -Scenario Grab
```

Le rapport doit montrer : fermeture de `1 s` à `3,5 s`, `bucketClosedDI=1`, puis remontée conjointe
M1/M2 de `4 s` à `9 s`. Les valeurs sont volontairement nommées hypothèses POC ; elles ne valent
ni dimensionnement de mouflage ni validation de la transition machine AX10 → AX11.

Le scénario benne force actuellement le solveur explicite `rk-like`. Le solveur automatique BDF
de Rumoca 0.9.20 échoue à `t=0,12 s` sur ses discontinuités ; c'est un écart de maturité mesuré,
pas une anomalie masquée par le script.

## Recette M3 T287 / T296

```powershell
powershell -ExecutionPolicy Bypass -File TOOLS/TWINBENCH/modelica_atelier/rumoca_poc/Run_Rumoca_M3_POC.ps1 -Scenario M3Faults
```

Dans le rapport, tracer `frequencyTargetHz`, `pvZoneDI`, `tremieRawDI`, `p1RawDI`,
`sensorBounceFaultDI`, `brakeReleaseCmd`, `brakeFeedbackDI` et `brakeStuckFaultDI`.
Le POC injecte un rebond de 80 ms au départ puis à la position P1, et un frein collé de 13 s à
14,5 s. Position PV, largeur de
zone et durées sont des paramètres provisoires : ce n'est pas la clôture de T287 ou T296.

## Ce que ce POC évalue

- simplicité d'installation et de lancement ;
- diagnostic de compilation Rust ;
- stabilité du solveur sur le profil M3 ;
- qualité du rapport interactif ;
- limite immédiate : le modèle `Dredge.mo` complet avec `Modelica.Mechanics.MultiBody` n'est pas
  encore résolu par Rumoca sur ce poste.
