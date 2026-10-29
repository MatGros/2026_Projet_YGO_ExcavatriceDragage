# MISSION D'ANALYSE AGENT B — ANALYSE CINÉMATIQUE ET ÉLECTRIQUE DE LA TRACE RÉELLE TERRAIN M3

## Contexte Projet
L'archive `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/archives/Suivi_TranslationM3bug_20260904_27_wide.csv` contient un enregistrement réel sur la machine de dragage le 2026-09-04 lors d'un comportement anormal / bug de translation M3.
La fiche de référence associée est `DOC/WFLOW/CONTRACTS/FICHE_T400_MODELISATION_TRANSLATION_M3.md`.

## Objectif de l'Agent B
Extraire de cette trace réelle et des fiches d'audit les **valeurs et grandeurs physiques réelles** mesurées sur site :
1. **Dynamique de fréquence et rampes réelles du variateur AC600** :
   - Quelles sont les rampes mesurées en accélération et décélération (en Hz/s) ?
   - Quel est le temps de réponse entre consigne (`M3_SetpointFrequencyHz`) et fréquence réelle (`M3_ActualFrequencyHz`) ?
2. **Chronogramme du frein mécanique M3** :
   - À quel moment et à quelle fréquence le frein s'ouvre-t-il (`M3_BrakeIsOpen_DI = 1`) ?
   - À quelle fréquence retombe-t-il à la coupure ? Y a-t-il un retard d'ouverture ou de fermeture mesurable ?
3. **Mots d'état et de commande variateur (StatusWord / CommandWord)** :
   - Quelles sont les valeurs réelles prises par `M3_StatusWord` à l'arrêt, en accélération, en régime établi, et lors du défaut ?
   - Quels bits commutent au moment précis du défaut ?
4. **Comportement des détecteurs inductifs / cames** :
   - Dans quel état sont les DI capteurs (`M3_PosTremie_DI` .. `M3_PosMaintenance_DI`) ?
   - Y a-t-il des micro-coupures, des rebonds ou des transitions anormales ?
5. **Cause du défaut observé dans la trace** :
   - Quels sont les codes d'erreur `TranslationM3.Safety.ErrorId` et `TranslationM3.State.ErrorId` apparaissant dans la trace, et à quel timestamp exact ?

Format attendu : Chiffré, rigoureux, chronologique, avec timestamps précis de la trace.
