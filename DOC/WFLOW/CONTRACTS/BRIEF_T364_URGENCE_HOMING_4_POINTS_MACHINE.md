=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===
=== URGENT — observation machine réelle 2026-09-21 ===

## Contexte — PÉRIMÈTRE ÉLARGI, LIRE AVANT TOUT

4 points remontés en direct par l'exploitant en testant le cycle homing
(`CODE/G_CYCLE/FB_CycleMachineHoming.st`) sur machine réelle. Ces 4 points
ont été trouvés en observant SEULEMENT 2-3 étapes sur 8 (HX0→HX7 + HXF).
**Constat de l'exploitant : si 2-3 étapes produisent déjà 4 écarts réels,
la confiance dans l'ensemble du cycle est rompue.**

## Objectif n°1 — AUDIT COMPLET AVANT tout correctif ponctuel

Avant de traiter les 4 points listés plus bas, un agent avec posture
d'expert senior automaticien (challenge, zéro complaisance, cf. AGENTS.md
§Persona) doit auditer **l'intégralité** de `FB_CycleMachineHoming.st` —
toutes les étapes HX0 à HXF, pas seulement celles où l'utilisateur a
regardé :

1. Pour CHAQUE étape (HX0, HX1_CHOICE, HX2_CLIMB, HX2N_NEUTRAL, HX3, HX3N,
   HX4, HX5, HX6 si existante, HX7_LOCKED_REFERENCE, HXF_FAILED) : vérifier
   la cohérence texte IHM / condition de transition réelle / geste attendu,
   comme fait pour les points 1-2-4 ci-dessous.
2. Chercher systématiquement d'autres incohérences du même type (texte
   obsolète, condition trop stricte/trop laxiste, garde manquante ou
   surprenante) sur les étapes NON mentionnées par l'utilisateur.
3. Vérifier la cohérence des messages `MachineHomingInstruction` un par un
   (liste complète : grep `MachineHomingInstruction :=` dans le fichier)
   contre le geste/la condition réellement exigée à ce moment précis.
4. Produire un rapport écrit AVANT tout code : tableau étape par étape,
   verdict CONFORME/SUSPECT/NON CONFORME, avec preuve fichier:ligne pour
   chaque verdict.

**Aucun correctif de code tant que ce rapport d'audit n'est pas remis et
validé par l'utilisateur.** Les 4 points ci-dessous sont un point de départ
connu, pas une liste exhaustive.

## Point 1 — HX1 exige MAINT_N2, l'utilisateur pensait MAINT_N1

Message observé : *"Homing: HX1 - RefHoming Passer en MAINT_N2 pour
référencer"* (`:835`). Code : `Mode : E_Mode; // referencement : MAINT_N2
seul` (`:21`), confirmé `:554` et `:387-394` (déverrouillage IHM exige
`MAINT_N2`).

**Action** : ce n'est PAS forcément un bug — c'est peut-être une doctrine
existante que l'utilisateur ne se rappelle plus avoir validée. Vérifier
l'historique (git log / TASKS.yaml T336/T340) pour voir si "référencement =
MAINT_N2 uniquement" a été une décision explicite. Si oui, l'expliquer
clairement à l'utilisateur (ne pas coder). Si c'est un vrai écart avec
l'intention (référencement normal censé être possible en MAINT_N1), proposer
un correctif chiffré — ne pas trancher seul.

## Point 2 — Retirer la validation "3 appuis JOY" à HX1_CHOICE

Code actuel (`:557`) : `ELSIF BootReady AND ExplicitValidationPulse AND
ModeIsMaint2 THEN` — le passage à l'étape de choix (HX2/HX2N/HX7) est
conditionné à une validation joystick (3 appuis). L'utilisateur veut que dès
que les conditions (`BootReady`, `ModeIsMaint2`) sont réunies, on soit
**directement** dans l'étape de choix, sans geste de validation
supplémentaire.

**Action** : retirer `AND ExplicitValidationPulse` de la condition d'entrée
HX1→(HX2/HX2N/HX7). Vérifier `ExplicitValidationPulse` (chercher sa
définition) n'est pas utilisé ailleurs de façon critique avant de le retirer
ici uniquement. Preuve CI avant/après.

## Point 3 — Benne utilisable hors homing sans limite FDC (risque)

Constat utilisateur : hors cycle homing et machine non référencée (`NOT
MachineHomed`), il peut utiliser la benne entre les fins de course sans
qu'aucune restriction ne s'applique — jugé "pas logique". Proposition
utilisateur : dans ce cas (non référencé), forcer `WinchSel = 2` (sélection
treuil benne) et **désactiver les FDC benne**, pour que l'opérateur puisse
fermer la benne physiquement à l'œil, en sécurité contrôlée, en attendant le
référencement.

**Action** : analyser l'état actuel (comment la benne est pilotable hors
homing aujourd'hui, quelles gardes existent déjà), confirmer si le risque
décrit est réel (preuve, pas supposition), puis proposer la mécanique
exacte demandée (bascule `WinchSel=2` + désactivation FDC benne
conditionnée à `NOT MachineHomed`) — NE PAS CODER avant validation de
l'utilisateur sur la mécanique précise, car ça touche une garde de
sécurité mouvement (sensible).

## Point 4 — Texte HX2 obsolète, ne mentionne pas la fermeture benne

Message actuel HX2 (`:812`) : *"HX2 - RefHoming Tirer JOY palier 1 vers FDC
haut"* — ne dit jamais à l'opérateur de fermer la benne visuellement à un
moment de la séquence, alors que l'utilisateur s'attend à cette consigne
plus tôt dans le flux (pas seulement à HX4 où elle apparaît actuellement,
`:824`).

**Action** : relire toute la séquence HX1→HX7 et les textes associés
(`:783-845`), vérifier avec l'utilisateur SI la fermeture benne doit
apparaître plus tôt (HX2/HX3) ou si HX4 est le bon endroit et que le texte
HX2 doit juste être complété d'un rappel. Ne pas décider seul — proposer
2-3 formulations et laisser trancher.

## Contraintes non négociables

- **AUDIT COMPLET D'ABORD** (§Objectif n°1) — aucun correctif avant remise
  du rapport et validation utilisateur.
- AUCUN COMMIT sans accord explicite distinct du GO.
- Point 3 touche une garde de sécurité mouvement — pas de code avant
  validation explicite de la mécanique par l'utilisateur.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
- Vérifier `TASK_LOCKS.json` avant de commencer (FB_CycleMachineHoming.st
  potentiellement touché par d'autres lots récents T340).
- Posture challenge stricte : ne rien valider par défaut, chercher
  activement ce qui cloche, pas seulement confirmer les 4 points déjà
  connus.
