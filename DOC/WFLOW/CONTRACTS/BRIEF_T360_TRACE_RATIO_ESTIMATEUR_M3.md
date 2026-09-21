=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===
=== ANALYSE SEULE — AUCUN CODE/ MODIFIÉ ===

## 1. Contexte

Projet excavatrice de dragage (CODESYS 3.5, ST). T333 (committé `cc682aa6`) a
corrigé un bug de recalage de position sur l'estimateur translation M3
(`FB_Translation_PositionEstimator.st`) : avant correctif, le recalage sur
capteur ne fonctionnait que dans un sens (front montant uniquement), jamais
en sens Maintenance. Le correctif n'a jamais été confirmé formellement sur
machine réelle (`test_utilisateur_20260920` de T333 : signal positif en
simulation mais non probant, pas de vérification chiffrée de la position).

L'utilisateur a fourni une trace de test simulation MAINT N1 :
`TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_74_SIMU_MAINTN1_M3_TestSim_20260920.trace`.

**Question posée par l'utilisateur** : le ratio odométrique
(`GVL_PERSISTENT._TranslationGainMetersPerHzSec = 0.008333`,
`FB_Translation_PositionEstimator.st:35`, câblé depuis
`PRG_05_Translation.st:591`) utilisé en simulation est-il cohérent avec ce
qu'on attend, et est-il resté inchangé depuis la dernière mise en service
réelle ?

**Pré-analyse rapide déjà faite par l'orchestrateur** (à vérifier
indépendamment, pas à reprendre en aveugle) : conversion de la trace via
`TOOLS/PLC_CSV_SNAPSHOT/external_python/trace_to_csv.py --format wide`,
extraction des transitions sur les bits capteur
(`M3Translation.State.AtTremie/AtPV/AtP1/AtP2/AtMaintenance`) croisées avec
`M3Translation.State.EstimatedPosM3_M`. Résultat observé : écart entre la
position estimée juste avant recalage et la position théorique du capteur de
l'ordre de 1 à 3 mm, dans les 2 sens de marche, sans asymétrie visible.
Historique git de `_TranslationGainMetersPerHzSec` (`GVL_PERSISTENT.st`) :
valeur `0.008333` inchangée depuis sa création (aucun commit ne l'a modifiée).

## 2. Objectif de la tâche (T360)

Vérification indépendante, contexte frais, de l'analyse ci-dessus — ne pas
faire confiance aux chiffres de l'orchestrateur sans les recalculer.

1. Reconvertir la trace toi-même (`trace_to_csv.py`) et extraire
   indépendamment les transitions de bits capteur croisées avec la position
   estimée. Confirmer ou infirmer les écarts mm rapportés ci-dessus, avec tes
   propres chiffres.
2. Vérifier que le recalage se produit bien dans les 2 sens de marche sur
   cette trace (aller ET retour) — c'est le point central de T333.
3. Vérifier l'historique git de `GVL_PERSISTENT._TranslationGainMetersPerHzSec`
   toi-même (`git log --follow -p -- CODE/GVL_PERSISTENT.st`) — confirmer
   qu'aucun commit ne l'a modifiée depuis sa création, et dater sa création.
4. Vérifier si le ratio est identique en simulation et en réel : tracer où
   `GainMetersPerHzSec` est réellement consommé, et si un mécanisme (FB
   simulation `FB_Sim_Translation.st` ou autre) pourrait utiliser une valeur
   différente en mode simulation.
5. Chiffrer la dérive attendue en cas d'erreur de ratio (ex. si le ratio réel
   diffère de 1% de la valeur configurée, quelle dérive en mm sur 20m de
   parcours ?) pour donner un ordre de grandeur de détection.

## 3. Devoir de challenge

- Ne pas se contenter de confirmer les chiffres de l'orchestrateur — recalculer
  indépendamment, sur le fichier trace brut, sans réutiliser le CSV déjà
  généré (`TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_74_wide.csv`) sans le
  revérifier.
- Si un écart de méthode ou de résultat apparaît par rapport à la
  pré-analyse, le signaler explicitement, avec preuve.
- Vérifier si le nombre d'échantillons dans la trace est suffisant pour
  conclure (résolution temporelle réelle vs 10ms MainTask).

## 4. Livrables attendus

- Document d'analyse sous `DOC/WFLOW/AUDITS/` ou
  `DOC/WFLOW/TROUBLESHOOTING/FICHES/` (nom au choix, cohérent avec la
  convention du projet).
- Verdict explicite : T333 fonctionne-t-il dans les 2 sens sur cette trace
  (oui/non, preuve chiffrée) ; le ratio odométrique est-il cohérent
  (oui/non, écart chiffré) ; le ratio est-il identique simu/réel (oui/non,
  preuve).
- Contrat `TASK_CONTRACT_T360_*.yaml` (C2, analyse).
- `TASKS.yaml` mis à jour (T360), tag agent choisi/incrémenté par l'agent
  lui-même dans `TASK_LOCKS.json`.

## 5. Contraintes non négociables

- AUCUN `CODE/` modifié — analyse pure.
- AUCUN COMMIT sans accord explicite distinct du GO.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle/chiffre recalculé)
  dans la même restitution.
