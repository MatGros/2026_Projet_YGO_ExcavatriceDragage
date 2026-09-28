# T409 — recette Control Win de validation M3

Précondition unique : copie TwinBench Control Win en ligne, `SimulationModeActive=TRUE`, `SimM3OpenModelicaActive=TRUE`, gateway FMU sur `127.0.0.1:29061`. Ne jamais exécuter sur le PLC réel.

## Variables à surveiller

```text
PRG_T409_M3_FmuBridge.LinkReady
PRG_T409_M3_FmuBridge.Timeout
PRG_T409_M3_FmuBridge.LinkInvalid
PRG_T409_M3_FmuBridge.SensorWordIncoherent
PRG_T409_M3_FmuBridge.FmuPosition_M
PRG_T409_M3_FmuBridge.FmuVelocity_Mps
PRG_T409_M3_FmuBridge.FmuFrequency_Hz
GVL_Simulation.SimM3OpenModelica.M3_ActualFrequencyHz
GVL_Simulation.SimM3OpenModelica.M3_BrakeIsOpen_DI
GVL_Simulation.SimM3OpenModelica.M3_PosTremie_DI .. M3_PosMaintenance_DI
```

## Séquence minimale

| Test | Action | Résultat attendu |
|---|---|---|
| CW-01 | Gateway arrêté, verrous simulation vrais | `LinkReady=FALSE`, `Timeout=TRUE` après délai, image M3 neutralisée |
| CW-02 | Gateway lancé, aucune commande | `LinkReady=TRUE`, frein fermé, Hz mesure nul, position stable |
| CW-03 | Demande frein seule | frein s’ouvre après délai, position inchangée |
| CW-04 | Commande Maintenance 40 Hz (`DriveControlWord=2`) | vitesse/position augmentent, mot capteurs reste thermomètre |
| CW-05 | Retour neutre | fréquence décroît par rampe, puis frein se ferme |
| CW-06 | Commande Trémie 40 Hz (`DriveControlWord=1`) | vitesse/position diminuent, capteurs passent `00011→00111→01111→11111` |
| CW-07 | Maintien sur butée | position reste dans `[-0,30;30,30]`, sens poussé interdit |
| CW-08 | Rebond manuel autour d’un capteur | aucun mot incohérent, aucune téléportation de position |
| CW-09 | Arrêt puis relance gateway | nouvelle séquence acceptée, reprise sans saut de position |
| CW-10 | `SimulationModeActive=FALSE` | aucune écriture utile de la passerelle, image nominale conservée |

## Verdict

Un test est PASS uniquement si les variables de liaison, les retours FMU et l’image `GVL_Simulation` concordent. Une courbe seule ou `LinkReady=TRUE` ne suffit pas.

## Preuve passerelle locale

```text
python TOOLS/TWINBENCH/udp_m3_link/test_t409_gateway_roundtrip.py
[T409] roundtrip responses=100 timeouts=0 sensor_words=[1, 3]
[PASS] T409 gateway round-trip 10 ms
```

Cette preuve couvre le transport et la FMU, mais ne remplace pas les essais CW-01 à CW-10 dans Control Win.

Test de reprise exécuté :

```text
python TOOLS/TWINBENCH/udp_m3_link/test_t409_recovery.py
[T409] recovery first_seq=100 recovered_seq=0 measured_x100=40
[PASS] T409 reconnect sequence reset
```

Un reset de séquence n'est accepté qu'après une interruption supérieure à une seconde ; une trame ancienne pendant une liaison active reste rejetée.

## Lancement groupé

Pour rejouer toutes les preuves FMU locales :

```powershell
& 'C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\TWINBENCH\udp_m3_link\Run_T409_Verification.ps1'
```

Le verdict groupé est bloquant : un seul test en échec invalide la recette FMU locale.

## Trace détaillée

La passerelle accepte aussi :

```text
python TOOLS/TWINBENCH/udp_m3_link/udp_m3_fmu_gateway.py --trace-file C:\Temp\m3_t409_trace.csv
```

Le CSV contient, pour chaque trame, le mot de commande, Hz demandés, Hz mesurés, vitesse, position, état frein, statut, mot capteurs et butée. Il permet de comparer la plante FMU à l’image PLC sans interprétation visuelle.
