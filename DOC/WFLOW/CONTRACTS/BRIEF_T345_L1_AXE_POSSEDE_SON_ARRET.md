=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===

## 1. Contexte

Projet excavatrice de dragage (CODESYS 3.5, ST). Sujet gelé depuis
`PLAN_T334_PHASE3_AUTORITE_ARRET_AXE.md` (DSH07, 2026-09-20) : le mécanisme
`TranslationStopTimer` (`FB_CycleSemiAuto.st:361-365`) est **partagé entre
AX2_TRANSLATE_P1 et AX14_TRANSLATE_DUMP** — il exige 500ms continus de
`At_Xxx AND NOT Busy` alors que le ré-armement de la demande est immédiat,
donc sous capteur qui rebondit la transition ne peut jamais s'armer.

**Confirmation terrain 2026-09-21** : l'utilisateur a reproduit le blocage
en direct sur AX2 (translation M3, arrivée P1, machine réelle) — preuve que
ce n'est pas théorique.

Le plan gelé propose 3 lots séquencés (L1→L2→L3). **Ce brief ne couvre que
L1**, seul lot immédiatement actionnable :

- **L1** : l'axe possède son propre arrêt (détection indépendante de la
  demande, `ArrivalLock` non levé par perte de demande, publication d'un
  fait public d'arrêt confirmé). Décision **D1 déjà tranchée 🟢 OUI**
  (gater les bypass M3 sur MAINT_N2 à la consommation).
- **L2 est BLOQUÉ** : nécessite le verrou `T331/DSH09` sur
  `FB_CycleSemiAuto.st` libéré — **toujours actif au moment de ce brief**,
  vérifier `TASK_LOCKS.json` avant de commencer, ne pas y toucher.
- **L3 est hors périmètre** (D4 tranché 🟢 abandonner l'uniformisation).
- **D3** (coupure dure au retour Trémie) reste en attente de la trace L0
  (10ms) — hors périmètre de ce lot, ne pas y toucher.

## 2. Objectif de la tâche

Implémenter **L1 uniquement**, tel que défini dans le plan gelé
(`PLAN_T334_PHASE3_AUTORITE_ARRET_AXE.md` §L1, ligne 136) :

1. Détection d'arrêt **indépendante de la demande** — l'axe (translation M3)
   détecte et publie lui-même son état d'arrêt confirmé, sans dépendre de la
   persistance de la demande opérateur/cycle.
2. `ArrivalLock` (ou équivalent) **non levé par la perte de la demande** —
   une fois l'arrivée verrouillée, elle reste vraie même si la demande
   retombe (le rebond capteur ne doit plus pouvoir annuler un arrêt déjà
   confirmé).
3. Publication d'un **fait public** d'arrêt confirmé (`VAR_OUTPUT` à
   déclarer sur le FB concerné) — consommable ensuite par L2 (hors périmètre
   ici, mais l'interface doit être prête).
4. Garde de mode des bypass (Q4/D1) : gater les bypass M3 sur MAINT_N2 à la
   consommation.

## 3. Périmètre exact

- `CODE/I_TRANSLATION/FB_Translation.st`
- `CODE/M_MAIN/PRG_05_Translation.st`
- Tests `I_TRANSLATION` + `M_MAIN`

**Explicitement HORS périmètre** : `CODE/G_CYCLE/FB_CycleSemiAuto.st`
(verrou T331 actif), toute modification de `TranslationStopTimer` lui-même
(il vit dans `FB_CycleSemiAuto.st`, L2), toute décision D3.

## 4. Devoir de challenge

- Revérifier toi-même que le verrou T331/DSH09 est bien encore actif sur
  `FB_CycleSemiAuto.st` avant de commencer — si libéré entre-temps, alerter
  avant d'étendre le périmètre (ne pas décider seul d'enchaîner sur L2).
- Vérifier que la nouvelle détection d'arrêt indépendante ne réintroduit pas
  un risque déjà écarté ailleurs (relire `FB_Safety_Translation.st` pour les
  interactions sécurité).
- Le plan gelé cite des lignes précises (`FB_TranslationCmdArbitrationM3.st:65`,
  `PRG_05:408-428`, `FB_Translation_PositionDecoder.st:116`) — revérifier
  qu'elles sont toujours exactes avant de s'appuyer dessus (le fichier a
  bougé depuis T333/T360).

## 5. Chantiers concurrents

- Vérifier `TASK_LOCKS.json` avant de commencer — `PRG_05_Translation.st`
  est actif dans le périmètre T361 (correctif simulation en cours,
  vérifier collision avant d'éditer).

## 6. Livrables attendus

- Diff réel de L1.
- Preuve par test CI (I_TRANSLATION + M_MAIN) : rebond capteur simulé ne
  doit plus jamais bloquer la transition d'arrêt confirmé.
- Bundle + diff bundle + G200 --report + gates palier C.
- Contrat `TASK_CONTRACT_T345_L1_*.yaml` (C3/C4).
- `TASKS.yaml` mis à jour, tag agent choisi/incrémenté par l'agent lui-même
  dans `TASK_LOCKS.json`.

## 7. Contraintes non négociables

- AUCUN COMMIT sans accord explicite distinct du GO.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
- Ne pas toucher à `FB_CycleSemiAuto.st` (verrou T331) ni à D3 (trace L0
  requise, hors périmètre).
