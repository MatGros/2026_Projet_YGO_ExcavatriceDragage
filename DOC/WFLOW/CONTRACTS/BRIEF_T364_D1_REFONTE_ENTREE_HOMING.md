=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===

## 1. Contexte

Suite à l'audit T364 (`DOC/WFLOW/AUDITS/AUDIT_T364_HOMING_4_POINTS_20260921.md`).
L'exploitant a d'abord demandé de retirer la validation "3 appuis JOY" à
l'entrée du homing (HX1_CHOICE). L'audit a montré que la supprimer
brutalement casse 3 mécanismes (armement HX7, verrou M3, messages). **Ce
brief remplace cette demande par le vrai besoin, reformulé et confirmé par
l'exploitant 2026-09-21** :

> Au démarrage automate, si la machine n'est PAS référencée : elle ne doit
> PAS pouvoir bouger du tout. L'opérateur ferme la benne à l'œil, appuie
> "référencer" (UNE action claire) → si l'environnement le permet (déjà en
> MAINT_N2), bascule automatiquement en pilotage couplé (Winch=0) et monte
> seule jusqu'à la référence. Si l'environnement ne le permet pas (pas en
> MAINT_N2), le système doit clairement demander de passer en MAINT_N2
> d'abord — pas de mouvement possible avant ça.

Ce n'est donc pas "supprimer toute validation" — c'est **redéfinir où et
comment l'entrée dans le homing est validée**, en respectant la doctrine
déjà validée (référencement = MAINT_N2 uniquement, `T185:104-107 APPROVED`).

## 2. Objectif

1. Confirmer/clarifier l'état actuel exact de l'entrée HX0→HX1→HX2
   (`FB_CycleMachineHoming.st:530-580` environ, à revérifier sur le code
   courant) : combien d'actions opérateur sont réellement nécessaires
   aujourd'hui entre "machine non référencée, à l'arrêt" et "montée
   couplée en cours" ?
2. Proposer une séquence conforme au besoin reformulé ci-dessus :
   - Hors MAINT_N2 : aucun mouvement possible, message clair demandant de
     passer en MAINT_N2 (déjà partiellement présent, à vérifier/renforcer).
   - En MAINT_N2, machine non référencée : une action opérateur unique et
     claire ("fermer la benne puis valider référencement") déclenche la
     bascule automatique en pilotage couplé + montée, SANS étape
     intermédiaire de sélection manuelle du sens/treuil.
3. Vérifier que cette proposition NE casse PAS les 3 points identifiés par
   l'audit (armement HX7, verrou M3, messages) — si un conflit existe,
   proposer comment le résoudre dans la nouvelle séquence, ne pas l'ignorer.
4. Vérifier E1 de l'audit (couplage réel des 2 treuils en montée HX2 — le
   FB n'a pas d'entrée WinchSel, aucun contrôle qu'ils montent ensemble) :
   ce point doit être résolu dans le même mouvement, puisque le besoin
   exploitant implique explicitement "pilotage couplé (Winch=0)".

## 3. Devoir de challenge

- Ne pas proposer une séquence qui retire une confirmation opérateur sans
  la remplacer par un contrôle machine équivalent ou supérieur.
- Si la fermeture benne "à l'œil" (sans capteur fiable) pose un risque
  identifié ailleurs dans l'audit (E2 : commit benne sans vérification),
  le signaler explicitement — ne pas le corriger silencieusement dans ce
  lot s'il dépasse le périmètre.
- Citer précisément quelles lignes de code changent, avant/après, pour
  chaque étape de la séquence proposée.

## 4. Livrables

- Proposition de séquence HX0→HX2 revue, avec diff (si accord GO obtenu
  séparément avant code).
- Analyse écrite d'abord (comme pour l'audit initial) : PAS de code avant
  validation explicite de la séquence proposée par l'exploitant.

## 5. Contraintes non négociables

- AUCUN CODE avant validation explicite de la séquence proposée.
- AUCUN COMMIT sans accord explicite distinct du GO.
- Ne pas toucher à la doctrine MAINT_N2 déjà validée (référencement =
  MAINT_N2 uniquement) — la respecter, pas la remettre en cause.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
