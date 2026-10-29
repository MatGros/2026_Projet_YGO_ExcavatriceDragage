# MISSION D'ANALYSE AGENT C — CARTOGRAPHIE DES DÉFAUTS RÉELS M3 & ÉMERGENCE PHYSIQUE NATURELLE

## Contexte Projet
Plusieurs défauts ont été rencontrés sur la machine réelle concernant la translation M3 :
- Fiche `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md` (arrêt correct aux FDC en manuel, mais en cycle auto à l'arrivée sur P1 ou Trémie le chariot continue d'avancer / franchit la cible).
- Fiche `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_M3_FDC_Frein_RebondCapteurs_20260915.md` (défaut de séquence / retour frein aux FDC et rebond capteur pendant ~1 s).
- Fiche `DOC/WFLOW/CONTRACTS/FICHE_T400_MODELISATION_TRANSLATION_M3.md` (données de modélisation).
- Spécification `DOC/AF/AF_Partie-11_Fonction_Translation_v2.4.md`.

## Objectif de l'Agent C
Identifier comment concevoir la simulation SimBench M3 pour que ces comportements et risques **émergent naturellement de la physique**, SANS tricherie ni forçage artificiel de défaut :
1. **Pourquoi l'arrêt manuel fonctionne et l'arrêt cycle automatique échouait-il sur le terrain ?**
   - Analyser la divergence entre le verrou latché en manuel (`FB_Translation.st:179-204`) et le retrait de demande en cycle automatique (`FB_CycleSemiAuto.st`), en présence d'un rebond capteur ou d'un élan inertiel.
2. **Comment modéliser l'inertie du chariot et le frottement rail ?**
   - Si le variateur coupe sa poussée, quelle distance parcourt un chariot en roue libre avant que le frein ne morde ?
   - Quelle décélération appliquer quand le frein serre à vitesse non nulle ?
3. **Comment modéliser les cames et détecteurs inductifs de façon réaliste ?**
   - Une came a une longueur finie (ex. passage sur PV ou P1) ; un détecteur a une hystérésis mécanique et un retard électrique.
   - Comment un dépassement de consigne fait-il naturellement perdre le capteur et basculer le mot de position ?
4. **Matrice des garde-fous et non-régression** :
   - Quels principes respecter pour s'assurer que le modèle de simulation n'altère en aucun cas la logique de sécurité ou de commande du programme automate ?

Format attendu : Synthétique, orienté conception fonctionnelle, clair et précis.
