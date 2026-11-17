# T377 — Arbitrage synthèse revues ergonomie/effets de bord (glm + deepseek, 2026-11-16)

Lecture seule. Verdict consolidé : **ADVISORY — 1 lot d'aménagements à intégrer au v0.3
avant GO implémentation** ; aucun BLOQUANT confirmé après contre-vérification source.

## Retenus (intègration v0.3 au brouillon)

1. **Interlock homing unitaire pendant le cycle** (BLOQUANT retenu — glm #2, deepseek 13) :
   `BtnHome / BtnHomingAtZero / BucketReferenced` refusés tant que `CycleRunning`
   (garde à poser côté PRG_03:274 ou PRG_02). Test dédié.
2. **Anti-relance accidentelle post-HX6/HX7** (glm #11, MAJOR) : entrée cycle exige
   `BtnStart` seul si `MachineHomed` TRUE (le BtnValidation ne relance plus par réflexe).
3. **Refus de validation = cause fautive exposée** (glm #9, deepseek 6, MAJOR) :
   instruction IHM avec la 1re garde fautive (ordre de priorité) + checklist des 5
   gardes temps réel (PRG_07) + compteur affiché.
4. **Cause du dernier échec exposée en HX7** (glm #17, deepseek 11, MAJOR) : libellé
   HX7 enrichi depuis la table des causes actives (timeout HX3 ? bande ? contact ?).
5. **Bannière « sélecteur verrouillé par le cycle »** (glm #16, deepseek 10, MAJOR) :
   CmdWinchSelect forcé via PRG_03:95-99 — indiquer le forçage + resync à la sortie.
6. **Compteur de contacts capteur + trace datée** (glm #6, deepseek 5, MINEUR) :
   miroir du compteur de refus.
7. **Garde de durée montée : message d'expiration explicite** (glm #3, deepseek 3,
   MAJOR) : ClimbTimer expiré = cause dédiée + règle de reprise affichée. Le reset à la
   retombée de la commande est un design **documenté et voulu** (budget de montée
   continue, ST_fbMachineHomingCycle_Cfg.st:18-25 — pas un "pompage" à fermer).
8. **Porte de sortie = Reset conscient, à documenter par étape** (glm #15, deepseek 9) :
   la purge §4 s'applique À TOUTES les étapes (FB:294-304, preuve) — M3Locked se
   libère par Reset, pas seulement HX2A/HX7. Instruction par étape + mention « Annuler
   avec Reset ». Exit de mode = `ModeLostDuringCycle` → HX7 fail-safe (FB:263, preuve).
9. **Sémantique boutons** (glm 10, 19, 20 ; deepseek 7, 12 ; MINEUR) : libellés
   contextuels par état, consigne « relâcher le manche PUIS valider à l'IHM ».
10. **Scénarios sim à enrichir** (deepseek A) : power cut, exit mode, capteur bloqué,
    sélecteur basculé, validations répétées, montage/démontage unitaire concurrent.

## Rejetés ou réfutés (avec preuve)

1. **Fenêtre HX3→HX6 « montée possible » / dérive datum** (glm #18) : le blocage
   existe — tout mouvement treuil hors phase pendant le cycle = `MotionOutOfPhase`
   (grâce 3 s) → HX7 fail-safe (FB:244-245, §2) ; et après preset, HX4 re-vérifie la
   bande avant HX5/HX6. La dérive « silencieuse » n'est pas atteignable : un preset
   n'est PAS ré-émis hors gardes. Reste le test sim (déjà dans la liste).
2. **« C8 disparaît alors que le blocage persiste »** (glm #7) : le latch persiste
   jusqu'au dégagement, et l'instruction §10 HX2A est affichée tant que le latch est
   actif ; elle ne retombe qu'au retour HX2 (autorisé) — cohérent. La bannière
   « persistante » demandée existe par là.
3. **Anti-pompage / anti-arre-arm (deepseek 3)** : le budget « montée continue » est
   le design documenté du Cfg (ST_fb...Cfg:18-25) — une pause opérateur ne consomme rien
   par nature. Le constat se ramène au point retenu 7 (message d'expiration).
4. **Deadlock HX7 + mode** (deepseek 9) : sortie de mode en cycle = abort HX7, et
   Reset conscient en MAINT_N2 purge toujours (FB:294) — pas de deadlock, mais
   documentation étape requise (retenu 8).
5. **Interlock M3 en HX0** (deepseek 2) : `M3Locked := CycleRunning` (FB:595) — HX0
   libère M3 ; le constat se ramène au message d'entrée (retenu 9).

## Statut

Brouillon v0.2 reste la référence d'implémentation ; les 10 retenus forment le delta
v0.3 à appliquer aux docs (brouillon + séquence) en reprise, avant GO écrit du lot.
Deux vérifs code à ajouter en reprise : sémantique exacte de `CouplingInterlockFault`
(face à l'override du sélecteur) et source du `Reset` du cycle (câblage IHM).
