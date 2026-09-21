=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===

## 1. Contexte

Projet excavatrice de dragage (CODESYS 3.5, ST). Grafcet semi-auto figé le 2026-09-03
(DOC/WFLOW/AUDITS/GEL_GRAFCET_SEMIAUTO_20260903.md, table lignes 101-114 = référence
opposable). Deux bugs identiques déjà repérés dans FB_CycleSemiAuto.st sur le même
schéma : transition inter-étapes qui exige un RELÂCHEMENT du joystick au lieu d'un
MAINTIEN, violant la règle "continuité sans à-coup" (mémoire feedback_cycle_semiauto_
continuite_joystick.md).

Le cas P1 (AX2→AX3) a été corrigé le 2026-09-19 (commit dcb28019) en passant d'un
relâchement générique JoystickDeflected à un geste axe-discriminé JoystickPushOnly
(Y- strict, X exclu) — corrige au passage un risque latent de confusion X/Y sur la
transition suivante.

Le cas AX14→AX15A (translation vers trémie) n'a PAS été corrigé en parallèle : même
bug, resté non aligné avec la spec.

## 2. Objectif de la tâche (T345)

Aligner la transition AT14 (AX14_TRANSLATE_DUMP → AX15A_DUMP_ARRIVE) sur la spec
gelée : JoystickDeflected AND Translation_At_Tremie → AX15A (maintien, pas relâchement).

## 3. Localisation exacte

Fichier : CODE/G_CYCLE/FB_CycleSemiAuto.st
Bloc : AX14_TRANSLATE_DUMP, lignes ~1433-1457 (vérifier les numéros réels au moment
de l'exécution — d'autres lots ont été committés depuis : T340/T341/T342/T346).

### Code actuel (bug)

```st
IF Translation_At_Tremie THEN
    TranslationCmd.ReqStart := FALSE;
    TranslationCmd.PositionTgt := 0;
    WaitingForOperator := JoystickDeflected;
    WaitingForProcess := NOT JoystickDeflected;
    OperatorAction := 'AX14 - Tremie : relacher le joystick avant ouverture.';
    IF TranslationStopTimer.Q AND NOT JoystickDeflected THEN
        State := E_AutoCycleStep.AX15A_DUMP_ARRIVE;
    END_IF;
END_IF;
```

### Correctif proposé (challengé et validé côté raisonnement par l'orchestrateur, À REVÉRIFIER par l'agent)

```st
IF Translation_At_Tremie THEN
    TranslationCmd.ReqStart := FALSE;
    TranslationCmd.PositionTgt := 0;
    WaitingForOperator := NOT JoystickDeflected;
    WaitingForProcess := JoystickDeflected;
    OperatorAction := 'AX14 - Tremie atteinte : maintenir le joystick.';
    IF JoystickDeflected THEN
        State := E_AutoCycleStep.AX15A_DUMP_ARRIVE;
    END_IF;
END_IF;
```

## 4. Ce qui a déjà été vérifié par l'orchestrateur (ne pas re-démontrer, CONTRE-VÉRIFIER)

- AX15A_DUMP_ARRIVE (lignes ~1459-1480) force déjà WinchM1Cmd/WinchM2Cmd à 0/FALSE
  à chaque scan, indépendamment du joystick → aucun risque qu'un treuil "garde une
  commande" en entrant dans AX15A avec le joystick encore à gauche (axe X).
- La transition AX15A→AX15B (ouverture réelle benne) exige déjà DeadmanArmed AND
  JoystickPush (axe Y strict) — le pattern de correction de P1 (discrimination
  d'axe) y est déjà appliqué. Retirer TranslationStopTimer.Q de la condition AT14
  ne réintroduit donc PAS le bug de confusion X/Y de P1 : ce bug concernait la
  transition SUIVANTE (ouverture benne), pas celle-ci (arrivée trémie).
- TranslationStopTimer semble un ajout postérieur à la spec figée (confirmation
  physique arrêt M3, "le FDC seul ne suffit pas si le variateur est encore en
  décélération", commentaire ligne ~346-347). L'utilisateur juge le risque
  négligeable (rampe + frein gèrent la décel M3, aucune commande treuil pendant
  ce temps) mais NE TRANCHE PAS explicitement si le timer doit être conservé
  ailleurs (log/diag) ou purement retiré de cette condition.

## 5. Ce qu'il reste à challenger (ne pas prendre pour argent comptant)

- TranslationStopTimer : vérifier s'il est utilisé ailleurs dans le fichier avant
  de le laisser en variable "morte" localement à ce bloc. S'il ne sert QUE là,
  décider avec preuve (grep) s'il faut le garder comme sécurité complémentaire
  (attendre confirmation d'arrêt M3 réel en plus du joystick) ou le retirer proprement.
- Revérifier qu'aucune autre transition du fichier ne dépend d'un état intermédiaire
  (WaitingForOperator/WaitingForProcess) de AX14 changé par ce correctif (recherche
  des usages de ces 2 flags hors du CASE).
- Rejouer mentalement (ou via test CI si le harnais le permet) le scénario opérateur :
  joystick maintenu à gauche du début (AX2) jusqu'à l'arrivée trémie → aucune
  saccade, aucun arrêt intermédiaire non voulu.

## 6. Chantiers concurrents (verrous actifs au moment du brief)

- T340 (committé, commit 266fb11f) : CODE/G_CYCLE/FB_CycleMachineHoming.st — fichier
  différent, pas de collision.
- T341 (committé, commit 4f668dd5) : CODE/J_SUPERVISION/FB_CfgT330Normalizer.st +
  PRG_07_Supervision.st — fichiers différents, pas de collision.
- T342 (committé, commit f4ca3fee) : CODE/L_SIMULATION/FB_SimBench.st — fichier
  différent, pas de collision.
- T346 (committé, commit 6cbb0a8d) : CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st —
  fichier différent, pas de collision.
- Aucun autre agent connu sur CODE/G_CYCLE/FB_CycleSemiAuto.st au moment du brief
  — vérifier TASK_LOCKS.json toi-même avant de commencer (prendre le tag, jamais
  l'orchestrateur qui l'assigne).

## 7. Livrables attendus

- Diff réel sur CODE/G_CYCLE/FB_CycleSemiAuto.st (et éventuellement le retrait
  propre de TranslationStopTimer si décidé).
- Bundle complet + diff bundle + G200 --report + gates palier C.
- Contrat de tâche TASK_CONTRACT_T345_*.yaml (C2 minimum, cycle métier).
- Mise à jour DOC/WFLOW/TASKS.yaml (T345, toi seul choisis/incrémentes ton tag
  agent réel dans TASK_LOCKS.json).

## 8. Contraintes non négociables

- AUCUN COMMIT sans accord explicite distinct du GO d'implémentation.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
- Respecter GVL_IHM figée en structure si ce lot devait y toucher (il ne devrait
  pas — signaler si un besoin apparaît).
