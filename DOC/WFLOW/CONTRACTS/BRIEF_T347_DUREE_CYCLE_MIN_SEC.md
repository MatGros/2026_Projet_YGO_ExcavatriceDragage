=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===

## 1. Contexte

Projet excavatrice de dragage (CODESYS 3.5, ST). Demande utilisateur 2026-09-20 :
le type TIME est mal géré sur le panel IHM physique (affichage peu lisible pour
l'opérateur). Audit mené par l'orchestrateur : 11 champs TIME exposés dans GVL_IHM
au total, mais seuls GVL_IHM.CycleSemiAuto.State.CurrentCycleElapsed et
LastCycleDuration sont des durées MÉTIER destinées à l'opérateur. Les 9 autres
(watchdogs 500ms/900ms/1s250, heartbeat IHM, timeout benne) sont du diagnostic
technique interne et restent en TIME — HORS PÉRIMÈTRE de cette tâche, décision
déjà actée avec l'utilisateur.

## 2. Objectif de la tâche (T347)

Remplacer le type TIME par 2 champs INT (minutes écoulées illimité + secondes
écoulées 0..59) pour CurrentCycleElapsed et LastCycleDuration, sur toute la chaîne
PLC → IHM. Format confirmé par l'utilisateur : 2 champs entiers séparés, pas de
décimale.

## 3. Chaîne complète à modifier (toutes les occurrences relevées)

### 3a. Déclaration TIME à remplacer (2 sites, même paire de champs)

```
CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleState.st:35-36
    CurrentCycleElapsed    : TIME;        (* Durée écoulée du cycle en cours *)
    LastCycleDuration      : TIME;        (* Durée du dernier cycle achevé (figée à X13) *)

CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_SequencePublicState.st:26-27
    CurrentCycleElapsed : TIME;             // Durée écoulée du cycle SEMI_AUTO en cours
    LastCycleDuration   : TIME;             // Durée du dernier cycle SEMI_AUTO achevé (figée à X13)
```

Remplacer chaque paire par 4 champs INT (nommage à trancher par l'agent en
respectant NAMING_CONVENTION.md — suggestion : CurrentCycleElapsedMin/Sec,
LastCycleDurationMin/Sec).

### 3b. Production de la valeur (chronomètre interne)

```
CODE/G_CYCLE/FB_CycleSemiAuto.st:148-149  (déclaration VAR_OUTPUT, à adapter au nouveau format)
CODE/G_CYCLE/FB_CycleSemiAuto.st:330-332  (CycleRunTimer.ET -> CurrentCycleElapsed : conversion à ajouter ici, TIME -> min/sec)
CODE/G_CYCLE/FB_CycleSemiAuto.st:1577     (LastCycleDuration := CurrentCycleElapsed : fige la durée à l'achèvement X13, adapter à la paire de champs)
```

### 3c. Propagation FB → PRG_03 → GVL_IHM

```
CODE/M_MAIN/PRG_03_Modes_Cycle.st:359-360   (recopie depuis instCycleSemiAuto)
CODE/M_MAIN/PRG_03_Modes_Cycle.st:458-459   (RAZ à T#0s — adapter à 0/0)
CODE/M_MAIN/PRG_03_Modes_Cycle.st:532-533   (RAZ à T#0s — adapter à 0/0)
CODE/M_MAIN/PRG_07_Supervision.st:665-666   (recopie finale vers GVL_IHM.CycleSemiAuto.State)
```

⚠️ Vérifier ces numéros de ligne au moment de l'exécution — d'autres lots ont été
committés depuis (T340/T341/T342/T346), le fichier a pu bouger.

## 4. Contraintes de conception

- Conversion depuis le TON interne (CycleRunTimer.ET, type TIME) vers minutes/
  secondes : utiliser les opérateurs standards CODESYS (TIME_TO_UDINT ou
  équivalent + division/modulo), pas de bibliothèque externe.
- Minutes : illimité (INT suffit largement pour un cycle de dragage, pas de durée
  qui dépasse ~32000 minutes). Secondes : borné 0..59.
- Aucune perte de précision perceptible pour l'opérateur — l'arrondi à la seconde
  est acceptable et voulu (demande explicite : "pas besoin d'être précis à la
  seconde... enfin si, en secondes c'est bien").
- Respecter NAMING_CONVENTION.md pour le nommage des 4 nouveaux champs (suffixes
  d'unité, pas de notation hongroise).
- GVL_IHM reste la seule structure à laquelle le collègue IHM se réfère : mettre
  à jour DOC/WFLOW/AUDITS/TABLE_ECHANGE_IHM_T299_COMPTEURS_2026-09-20.md ou créer
  une table équivalente pour ce lot, à livrer rapidement au collègue dès que les
  noms de champs sont stables (mémoire feedback_gvl_ihm_frozen_structure.md).

## 5. Hors périmètre (ne pas toucher)

- Les 9 autres champs TIME de GVL_IHM (watchdogs, heartbeat, timeout benne) —
  restent en TIME, diagnostic technique.
- ST_WinchState, ST_SafetyWinch, ST_TranslationState, ST_CommunHMI — aucun de ces
  fichiers ne doit être modifié par ce lot.

## 6. Chantiers concurrents (verrous actifs au moment du brief)

- T345 (brief transmis, en cours potentiel) : CODE/G_CYCLE/FB_CycleSemiAuto.st —
  MÊME FICHIER que ce lot (T347 touche aussi FB_CycleSemiAuto.st:148-149/330-332/
  1577). Vérifier TASK_LOCKS.json avant de commencer : si T345 est en cours sur ce
  fichier, séquencer (attendre la clôture de T345) ou coordonner les zones
  touchées (T345 = bloc AX14_TRANSLATE_DUMP ~ligne 1433-1457, T347 = lignes
  148-149/330-332/1577 — zones disjointes mais même fichier, prudence sur les
  numéros de ligne qui vont bouger).
- Aucun autre agent connu sur PRG_03_Modes_Cycle.st, PRG_07_Supervision.st,
  ST_CycleState.st, ST_SequencePublicState.st au moment du brief.

## 7. Livrables attendus

- Diff réel sur les 6 fichiers listés en §3.
- Table d'échange IHM mise à jour (nouveaux champs GVL_IHM).
- Bundle complet + diff bundle + G200 --report + gates palier C.
- Contrat de tâche TASK_CONTRACT_T347_*.yaml (C2, interface IHM).
- Mise à jour DOC/WFLOW/TASKS.yaml (T347, toi seul choisis/incrémentes ton tag
  agent réel dans TASK_LOCKS.json).

## 8. Contraintes non négociables

- AUCUN COMMIT sans accord explicite distinct du GO d'implémentation.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
- Non-régression : le comportement du chrono (démarre sur Lifecycle.Busy, se fige
  à X13, RAZ au démarrage/arrêt du mode) doit être strictement identique, seul le
  type d'exposition change.
