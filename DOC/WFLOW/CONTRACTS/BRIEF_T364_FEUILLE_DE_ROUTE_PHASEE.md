=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → RELAIS T364 (même acteur, verrou déjà posé) ===
=== FEUILLE DE ROUTE PHASÉE — exécuter dans l'ordre, ne pas sauter de phase ===

## Contexte

T364 (refonte homing HX0-HX7) a déjà connu plusieurs allers-retours
(bug boot corrigé, timeout demandé retiré, audit en 4 phases fait). Fin
des micro-échanges : voici la feuille de route complète et ordonnée,
à exécuter phase par phase, chaque phase livrée avec preuve avant de
passer à la suivante. Objectif final : un grafcet testable de bout en
bout sur machine, sans blocage artificiel.

---

## PHASE 0 — Vérification de l'état actuel (avant tout nouveau code)

Confirmer par preuve fichier:ligne, dans l'ordre :

1. Le timeout 8s (`BucketCloseTimedOut`/`BucketCloseTimer`,
   `Cfg.CfgTimeoutBucketClose`) est bien retiré — `grep` de ces 3 noms
   sur `FB_CycleMachineHoming.st` et `ST_fbMachineHomingCycle_Cfg.st`
   doit renvoyer 0 résultat (ou dire précisément ce qui reste si non
   fait).
2. `AxisHomingError` est bien dans `TransactionAbort` (déjà vérifié PASS
   par l'orchestrateur, confirmer que rien n'a régressé depuis).
3. `ModeLostDuringCycle` → `TransactionAbort` → `HX7_FAILED` reste actif
   (déjà vérifié CONFORME, confirmer non régressé).

**Si un de ces 3 points a régressé : le signaler en premier, avant toute
autre phase.**

---

## PHASE 1 — Mode de référencement "à l'arrêt" (BLOQUANT, priorité absolue)

Exigence utilisateur explicite, répétée plusieurs fois : **deux modes de
référencement doivent exister**, l'un en repli de l'autre :

- **Mode A "à la volée"** (déjà implémenté) : référencement pendant le
  mouvement, au moment où le capteur haut est touché (`HX2→HX3`).
- **Mode B "à l'arrêt"** (MANQUANT — à implémenter) : le treuil s'arrête
  sur/après le capteur, machine au repos confirmé, PUIS le référencement
  est déclenché.

Le mode B doit être un **repli automatique** si le mode A échoue (ex. le
préréglage/preset codeur ne se confirme pas dans le temps attendu en
mode A) — pas un mode que l'opérateur doit choisir manuellement.

Livrable de cette phase : diff + preuve CI (rouge avant, vert après)
montrant que si le mode A échoue, le mode B prend le relais
automatiquement et aboutit quand même à une référence valide.

---

## PHASE 2 — Vérifier la fiabilité de `WinchesMechanicallyStopped`

Ce signal conditionne plusieurs transitions (HX1A, HX4, HX5). Avant de
lui faire confiance dans les nouvelles phases :

1. Tracer d'où il vient exactement (fichier:ligne de sa déclaration et de
   son calcul).
2. Dire clairement : est-ce une **mesure physique réelle** (vitesse
   codeur, capteur) ou une **inférence logicielle** (ex. absence de
   commande émise) ?
3. Si c'est une inférence logicielle sans mesure physique : le signaler
   comme risque (les gardes temporelles associées — couplage 300ms,
   grâce d'inertie — pourraient être trop permissives), mais NE PAS
   corriger sans validation humaine explicite du remplacement proposé.

---

## PHASE 3 — Durcissements mineurs (non bloquants, à faire si le temps le permet)

1. Timeout de garde sur HX5 si le joystick n'est jamais remis au neutre
   (actuellement : attente indéfinie possible).
2. Revérifier la logique HX3 (`HomeReqDone`) signalée "fragile" par
   l'audit — confirmer qu'elle ne peut vraiment pas double-déclencher un
   homing, avec un test CI dédié si le doute persiste.

---

## PHASE 4 — Documentation (peut être faite en parallèle par un 2e agent)

Déjà briefée séparément : `BRIEF_T364_DOC_ET_COHERENCE_CYCLE_AUTO.md` —
mise à jour AF-09, alignement avec le cycle auto, vérification des textes
opérateur. Ne bloque pas les phases 0-3.

---

## Règle de restitution — à chaque phase

- Preuve fichier:ligne systématique, jamais une déclaration sans preuve.
- Preuve CI rouge-avant/vert-après pour tout correctif de comportement.
- **Ne pas passer à la phase suivante sans avoir livré et signalé la
  précédente terminée.**
- Zéro commit sans accord explicite distinct du GO — à chaque phase, pas
  seulement à la fin.

## Objectif final mesurable

Un essai machine complet HX0→HX6 (succès) réalisable sans qu'aucun des
points listés en Phase 0-2 ne bloque artificiellement l'opérateur.
