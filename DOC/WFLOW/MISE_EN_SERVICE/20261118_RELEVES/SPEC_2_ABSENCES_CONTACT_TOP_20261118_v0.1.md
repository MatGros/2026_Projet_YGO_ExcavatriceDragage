# SPEC — les 2 absences du patrimoine T377 (pour validation exploitant, puis implémentation T417-C)

CC03, 2026-11-18 · lecture seule · pas de code. Base : relecture e75d1e08 (même dossier).

## Absence 1 — Latch « contact capteur haut » (anti-martelage, trace)

**Intention** : le capteur TOP repassé en barrière pure, un contact = position déjà
perdue (surcourse). Sans trace ni verrou, l'opérateur peut re-marteler le capteur sans
que rien ne l'en empêche ni ne le journalise — le constat des challenges du 16/11
(glm/deepseek) et le point « écart patrimoine » de la relecture.

**Design (cohérent avec le nouveau grafcet 5 étapes)** :
- Nouveau latch local `TopContactLatched` dans `FB_CycleMachineHoming.st` (LOC, non
  publié via table défauts — la table FB_Safety_Winch est pleine, 12-15) :
  - set : sur `TopPositionSensor` TRUE pendant `HX2_CLIMB_TO_TOP`.
  - clear : au retour réussi `HX3_TOP_CLEARANCE → HX1` (dégagement réalisé et arrêt
    neutre) OU front Reset (§ purge).
  - effet pendant latch : entrée HX2 toujours possible après dégagement (retour HX1),
    MAIS dans HX2, avant toute nouvelle montée : si latch actif ET contact encore
    présent → refus de montée + message (sinon le retour HX1→HX2 re-martèle immédiatement).
- Publication diagnostic : 1 champ `TopContactLatched` dans `ST_homingChecklist` /
  public state + compteur de contacts `TopContactCount` (UINT, purge Reset) dans le
  miroir PRG_07.
- Message IHM obligatoire (canal `MachineHomingInstruction`, G408) : pendant le latch :
  « Contact TOP déjà touché — la position est perdue : dégager puis re-fermer benne » ;
  dans HX2 avec latch : « Approche encore plus basse — contact déjà touché ».

**Fichiers/lignes** :
1. `CODE/G_CYCLE/FB_CycleMachineHoming.st` — VAR + logique HX2/HX3 (~10 lignes) +
   purge §4 (Reset) + mapping §10 messages (~3 lignes).
2. `CODE/G_CYCLE/_TYPES/ST_MachineHoming.st` — + 2 champs diag (latch, compteur).
3. `CODE/M_MAIN/PRG_07_Supervision.st` — publication miroir (~2 lignes).
4. Checklist homing (checklist `E_HomingM1`/`F_HomingM2` remplissage FB_TroubleshootingView) — ~2 lignes.

**Critères testables** :
- TC1 : contact pendant HX2 → `TopContactLatched=TRUE`, `TopContactCount=1`, aucun
  HomeReq/preset, passage HX3 (comportement existant inchangé).
- TC2 : dégagement → retour HX1 ; dans HX2 avant re-montée : montée refusée + message
  tant que le latch est actif ; purge au retour HX3 réussi + Reset.
- TC3 : 2 contacts successifs → compteur 2 ; trace visible dans checklist.
- TC4 : Reset conscient → latch et compteur purgés.
- G408 sur les 3 libellés ; G200/palier C verts.

**Effets de bord** : aucun sur PRG_03/04/06/07 logique (publication statut seulement) ;
le seul comportement fonctionnel changé = refus de re-montée tant que latch (voulu).
SEM_AUTO : zéro impact (cycle homing seulement).

## Absence 2 — `AnyFaultActive` incomplet

**Intention** (plan §1 l.23) : le voyant « Reset disponible » doit refléter TOUT défaut
acquittable, sinon l'opérateur ne sait pas quand appuyer Reset.

**Design** : étendre `PRG_07_Supervision.st:614` (`GVL_IHM.Modes.State.AnyFaultActive`)
avec un OR explicite des sources acquittables machine : `MachineHoming.Failed`,
`MachineHomingLoss` (causes latched), `instWinchM1/M2.Fault.Latched`,
`instWinchSync.Fault.Latched`, `instBucket.Fault.Latched` (ErrorId ≠ 0 côté Latched, pas
les causes live — une cause live se re-arme de toute façon).

**Fichiers** : `PRG_07_Supervision.st` (~+5 lignes, un seul producteur, aucun consommateur touché).

**Critères testables** : TC5 : défaut homing failure → AnyFaultActive TRUE ; Reset →
FALSE si plus de cause. TC6 : défaut sync latched → TRUE. TC7 : cause live seule
(erreur opérateur comm) → TRUE tant que présente (voyant honnête), FALSE à sa retombée.

**Effets de bord** : le voyant s'allume PLUS souvent (plus honnête) — à communiquer aux
opérateurs (le Reset ne réparera pas une cause live). G506 du plan à lancer avec ce lot.
