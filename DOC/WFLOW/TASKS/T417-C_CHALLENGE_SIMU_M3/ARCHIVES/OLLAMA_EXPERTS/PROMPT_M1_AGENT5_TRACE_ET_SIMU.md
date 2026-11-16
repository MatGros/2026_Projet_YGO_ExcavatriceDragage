# MISSION AGENT 5 — RECLASSEMENT TRACE CODESYS M3 PAR ÉCHELLE / TYPE DE DONNÉES

## Contexte
Le fichier `Suivi_97_SIMU_M3_Translation_M3_manu_auto_20261116.trace` contient 30 variables M3, mais :
- Toutes les variables ont la même échelle `Min=-12, Max=12`, ce qui écrase les booléens (`0..1`) et fait déborder les fréquences/pourcentages (`0..100` ou `0..5000`).
- 5 variables clés sont masquées (`Visible=False` : `DeadmanArmed`, `Error`, `PositionReached`, `ActiveTremie`, `ActiveMaintenance`).
- Il manque `M3_PosPV_DI`, `TranslationState.ErrorId`, `TranslationState.EstimatedPosM3_M`, et `GVL_Simulation.SimM3ObsPositionTrue_M`.

## Objectif Évaluable
Définir l'ordre exact et les bornes `[Min..Max]` optimales de chaque variable pour générer une trace CODESYS `.trace` 100 % orientée M3, classée par groupe de type de donnée et d'échelle :
1. Groupe A : Booléens de commande, capteurs et frein M3 (`0/1`)
2. Groupe B : Positions M3 et cible (`m` et code cible)
3. Groupe C : Consignes vitesse (`%` / `Hz`), étape `Step` et `ErrorId`
4. Groupe D : Fréquence brute variateur (`ActualFrequencyHz` en `0.01 Hz`, soit `0..5000`)
