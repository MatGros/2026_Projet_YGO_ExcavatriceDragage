=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===
=== URGENT — demande client ancienne, jamais traitée ===

## 1. Contexte

`T224`, criticité C4 (la plus haute de l'échelle du projet), existe dans le
catalogue depuis longtemps mais **n'a jamais été travaillée** (statut vide,
aucun code, aucune analyse). Mentionnée dans le mail client GCAM
(2026-09-15) : *"Armement joystick : le permit d'armement est parfois
incohérent avec les autorisations réelles de mouvement. L'utilisateur peut
voir le joystick armé alors que le mouvement est interdit, ce qui génère
ensuite des défauts 'commande sans mouvement'."*

## 2. Objectif

`ArmingPermit` peut être `TRUE` (joystick affiché "armé") alors qu'un
interlock final, un délai de reprise, un défaut mouvement ou un actionneur
(M1/M2/M3) est en réalité indisponible pour l'action sélectionnée.
L'opérateur croit pouvoir bouger, tente, et se prend un défaut "commande
sans mouvement" — trompeur et source de confusion terrain.

1. Identifier **toutes** les conditions réelles de disponibilité par axe
   (M1, M2, M3) et par sens.
2. `ArmingPermit` doit refléter la disponibilité réelle de l'action
   sélectionnée — pas juste "chaîne AU fermée + mode correct".
3. Ne pas confondre pause normale (relâchement volontaire), `SafeStop` et
   `PowerCutOff` — ce sont 3 états différents, `ArmingPermit` doit rester
   cohérent dans les 3 cas sans en masquer un par un autre.
4. Préserver les mouvements réellement disponibles sur les autres axes —
   ne pas désarmer tout le joystick pour un seul axe indisponible.

## 3. Méthode

- Lire `FB_Joystick.st` (l'armement vit probablement là), et tous les
  points de calcul de permis aval par axe (`FB_WinchCmdArbitrationM1/M2.st`,
  `FB_Translation.st`/chaîne M3) pour cartographier les conditions réelles
  de disponibilité.
- Tracer précisément où `ArmingPermit` est calculé aujourd'hui et ce qu'il
  ignore.
- Proposer la correction : soit enrichir `ArmingPermit` directement, soit
  séparer clairement "possibilité d'armer" (global) de "disponibilité par
  axe/sens" (détaillé) si le mélange actuel est la cause du problème.

## 4. Devoir de challenge

- Ne pas supposer la cause — tracer par preuve fichier:ligne chaque
  condition qui peut faire "commande sans mouvement" alors qu'`ArmingPermit`
  restait `TRUE`.
- Vérifier que le correctif ne introduit pas de nouveau risque (ex. un
  axe réellement disponible qui se retrouve désarmé à tort).

## 5. Livrables

- Diagnostic écrit avec preuve avant tout code.
- Diff réel + preuve CI avant/après.
- Bundle + diff bundle + G200 --report + gates palier C.
- Contrat `TASK_CONTRACT_T224_*.yaml` (C4).

## 6. Contraintes non négociables

- AUCUN COMMIT sans accord explicite distinct du GO.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
- Ne pas toucher à la chaîne AU ni aux sécurités mouvement indépendantes
  de l'armement.
