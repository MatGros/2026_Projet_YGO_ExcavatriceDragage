# Challenge architectural et diagnostic : Tâche T420 (SimBench - Roulis WinchCoast M1/M2)

## Contexte
Sur le banc de simulation CODESYS `FB_SimBench` :
1. Dans la tâche T419, la variable `SimWinchCoast_M` dans `GVL_Simulation.st` et `FB_SimBench.st` a été fixée à 1.30 m pour modéliser l'anticipation d'arrêt mécanique lors de l'ouverture de la benne (AX15B) afin que la benne finisse à la butée ouverte (OffsetOpenM=0.0) malgré l'anticipation d'arrêt (Open 1.3 m).
2. Une tâche T420 a été créée en urgence par un agent en affirmant qu'il s'agissait d'une régression critique ("roulis long parasite sur M1 et M2 hors AX15B") et a tenté d'abaisser `SimWinchCoast_M` et `M2_EffectiveCoastM` à 0.35 m, tout en ajoutant un script de garde `check_sim_winch_coast.py` et un test `TC-P13-077` imposant 0.35 m.
3. L'exploitant/utilisateur indique que cette tâche T420 était mal cadrée, fausse, et demande de revenir à l'état antérieur à T420.
4. Un agent précédent a remis manuellement la constante numérique à 1.30 m dans le code ST, mais a laissé en place le script de garde `check_sim_winch_coast.py` (qui attend 0.35 m), le test unitaire `TC-P13-077` (qui attend 0.35 m) et des commentaires modifiés.

## Questions pour challenge
1. En tant qu'expert automatisme et simulation banc d'essai, quel est ton diagnostic sur la pertinence d'annuler complètement T420 ?
2. Quels sont les impacts d'un retour propre au checkpoint pré-T420 (rétablissement des commentaires d'origine à 1.30 m, suppression de `check_sim_winch_coast.py`, suppression de `TC-P13-077` et retrait de T420 de `TASKS.yaml`) ?
3. Y a-t-il des effets de bord cachés ou des points de vigilance à surveiller sur le couplage M1/M2 et l'ouverture de benne AX15B si on revient à la référence T419 (1.30 m) ?
4. Valides-tu la démarche de purge complète de T420 ?
