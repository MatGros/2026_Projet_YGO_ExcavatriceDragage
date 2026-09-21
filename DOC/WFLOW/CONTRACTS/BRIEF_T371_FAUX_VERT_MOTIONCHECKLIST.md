=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT (ou relais si même acteur que T224) ===

## 1. Contexte

Trouvé pendant l'investigation T224 (`ArmingPermit`). C'est un **symptôme
distinct** de T224 (armement trompeur côté opérateur) et de T370
(discordance contacteurs M1/M2) : ici, c'est **l'outil de diagnostic
lui-même** (`ST_MotionChecklist`) qui ment au technicien — il affiche un
état "vert/OK" alors que la barrière de mouvement refuse réellement la
commande. Un technicien qui se fie à cet outil pour diagnostiquer un
blocage en maintenance sera induit en erreur.

Catalogué séparément de T224/T370 pour ne pas mélanger 2 symptômes
différents (armement vs outil d'explication) dans une même revue.

## 2. Objectif

Rendre `ST_MotionChecklist` fidèle à l'état réel de la barrière de
mouvement — plus de faux vert.

**Cible technique** : `FB_WinchOutputInterlock.st` porte probablement la
logique de barrière réelle (Reason/Fault.Error/State) que
`ST_MotionChecklist` ne reflète pas correctement aujourd'hui.

## 3. Borne de contrat — NON NÉGOCIABLE, arbitrée avant tout code

**Publication d'état SEULE autorisée sur `FB_WinchOutputInterlock.st`.**

- Autorisé : ajouter/exposer des sorties qui publient l'état réel déjà
  calculé en interne (Reason, Fault.Error, State) vers l'extérieur du FB,
  pour que `ST_MotionChecklist` puisse enfin les lire honnêtement.
- **Interdit** : toute modification de la logique de barrière elle-même —
  aucune ligne qui change QUAND la barrière autorise ou refuse un
  mouvement. C'est un FB de sécurité, on ne touche qu'à ce qu'il *dit*,
  jamais à ce qu'il *décide*.
- Alternative écartée (et pourquoi) : corriger uniquement côté IHM en
  faisant lire à `Step8` un état approximatif — écarté parce que ça
  laisserait l'IHM interpréter un état ambigu au lieu de lire la vérité à
  la source. La publication d'état à la source est plus sûre et plus
  simple à terme.

## 4. Méthode — preuve avant correctif

1. Lire `FB_WinchOutputInterlock.st` en entier : identifier précisément
   où Reason/Fault.Error/State sont calculés en interne, et ce qui est
   déjà exposé en `VAR_OUTPUT` vs ce qui reste privé.
2. Lire `ST_MotionChecklist` (et son FB producteur) : identifier
   précisément quelle donnée il lit aujourd'hui pour afficher son
   "vert", et pourquoi cette donnée peut être vraie alors que la barrière
   refuse réellement.
3. Reproduire le faux vert en test isolé (CI) : un cas où la barrière
   refuse (Reason ≠ vide, State = refus) mais où `ST_MotionChecklist`
   affiche encore OK — AVANT tout correctif, preuve rouge.
4. Ajouter les sorties de publication manquantes, câbler
   `ST_MotionChecklist` dessus.
5. Test de non-régression sur les **4 `Reason` déjà posés** dans
   `FB_WinchOutputInterlock.st` — aucun des 4 ne doit changer de
   comportement, seule leur visibilité change.

## 5. Devoir de challenge

- Vérifier qu'aucune autre fonction ne dépend du fait que ces états restent
  privés (encapsulation) avant de les exposer — si une dépendance existe,
  la signaler avant de casser l'encapsulation à la légère.
- Confirmer qu'il n'existe pas déjà une sortie similaire ailleurs qui
  aurait juste besoin d'être câblée, plutôt que d'en créer une neuve.

## 6. Livrables

- Preuve du faux vert reproduit en isolé (rouge avant correctif).
- Diff réel (nouvelles sorties `VAR_OUTPUT` + câblage IHM/diagnostic).
- Test de non-régression sur les 4 `Reason` (preuve avant/après identique).
- Bundle + diff bundle + G200 --report + gates palier C.
- Contrat `TASK_CONTRACT_T371_*.yaml` (C4).

## 7. Contraintes non négociables

- `FB_WinchOutputInterlock.st` : **publication d'état seule**, zéro ligne
  de logique de barrière modifiée — relis §3 avant chaque édition.
- AUCUN COMMIT sans accord explicite distinct du GO.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
- Lié à T224 et T370 (même investigation d'origine) — vérifier
  `TASK_LOCKS.json` pour collision avant de commencer.
