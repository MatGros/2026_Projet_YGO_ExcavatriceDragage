=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===
=== URGENT — remplace toutes les versions précédentes de ce brief ===

## 1. Contexte — corrections suite audit Codex 2026-09-21

Version précédente invalidée par un agent d'audit indépendant, 3 raisons :
1. `ArrivalLock` est **privé** à `FB_Translation.st:80` — inaccessible depuis
   `FB_CycleSemiAuto.st`. Le signal réellement disponible dans ce FB est
   déjà `M3_AtP1Stable`/`M3_AtTremieStable` (routé via `PRG_03`).
2. **Erreur de sécurité de l'orchestrateur, corrigée ici** : l'affirmation
   "changer d'axe X→Y empêche le déclenchement accidentel" est **fausse**,
   prouvée par le code (`FB_CycleSemiAuto.st:996`, `:1497`, `:1517`) — si
   l'opérateur tient le joystick en diagonale (X et Y déchargés
   simultanément), une transition AX2→AX3 ou AX14→AX15 peut déclencher un
   mouvement (ouverture benne) **sans jamais passer par le neutre**.
3. `SeenNeutral` n'est donc **PAS optionnel** — c'est une exigence de
   sécurité réelle, pas un durcissement de confort. Remis dans le périmètre
   de ce lot, obligatoire.

## 2. Objectif (L2 — version corrigée)

1. **Transition sur signal déjà disponible** : utiliser `M3_AtP1Stable`
   (AX2) / `M3_AtTremieStable` (AX14) — déjà présents dans
   `FB_CycleSemiAuto.st` — comme déclencheur de transition immédiate vers
   l'étape suivante. Ne pas tenter de câbler `ArrivalLock` depuis
   `FB_Translation.st` (hors périmètre, changerait le routage inter-PRG).
2. **`SeenNeutral` obligatoire avant tout mouvement suivant** : à l'entrée
   du nouvel état (AX3 pour AX2, AX15 pour AX14), armer un verrou
   `SeenNeutralAfterArrival` qui n'autorise le prochain mouvement
   (ouverture benne, etc.) qu'après confirmation que **les DEUX axes du
   joystick (X et Y) sont repassés au neutre en même temps**, pas
   seulement l'axe utilisé pour la transition. Tant que ce n'est pas vu :
   message "Relâcher le joystick" affiché, **aucune commande treuil/benne
   émise**.
3. Test CI obligatoire du scénario diagonal (X et Y maintenus simultanément
   à l'arrivée capteur) : prouver qu'aucun mouvement ne se déclenche tant
   que `SeenNeutralAfterArrival` n'est pas vrai.
4. Appliquer symétriquement à AX2 et AX14.

## 3. Devoir de challenge

- Vérifier que `Translation_Busy` n'a pas d'autre usage dans ce FB avant
  de le retirer du point `TranslationStopTimer` (confirmé par l'audit :
  usage unique, ligne 361-365 — à revérifier sur le code courant).
- `ArrivalStopConfirmed` (créé par L1) reste non consommé pour l'instant
  — documenter explicitement que c'est un choix assumé (piste de
  fiabilisation future), pas un oubli.
- Ne pas introduire de dépendance inter-PRG nouvelle non prévue — rester
  strictement dans `FB_CycleSemiAuto.st`.

## 4. Chantiers concurrents

- Verrous T345/T347/T358 libérés par l'orchestrateur (2026-09-21T07:10,
  tous committés vérifiés propres) — plus de collision formelle. Revérifier
  `TASK_LOCKS.json` à la prise malgré tout.
- CODE_XML fortement modifié par d'autres lots en cours — ne pas générer
  de bundle complet avant clarification, diff bundle ciblé uniquement.

## 5. Livrables

- Diff réel (`FB_CycleSemiAuto.st` uniquement, sauf si un blocage
  imprévu impose d'élargir — dans ce cas, s'arrêter et remonter avant
  d'élargir).
- Preuve CI : transition immédiate sur arrivée capteur (rouge avant,
  vert après) + scénario diagonal X/Y bloqué tant que neutre non vu.
- Bundle ciblé (diff bundle) + G200 --report + gates palier C.
- Contrat `TASK_CONTRACT_T345_L2_*.yaml`.

## 6. Contraintes non négociables

- AUCUN COMMIT sans accord explicite distinct du GO.
- `SeenNeutralAfterArrival` est OBLIGATOIRE, pas optionnel — un lot qui
  livre la transition instantanée SANS ce verrou est refusé.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
