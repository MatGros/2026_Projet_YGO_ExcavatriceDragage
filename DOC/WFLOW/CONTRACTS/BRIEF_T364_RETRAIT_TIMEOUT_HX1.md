=== RELAIS — même acteur (verrou T364 déjà posé) ===

## Décision utilisateur, explicite et répétée, non négociable

**Aucun timeout de garde, nulle part dans le homing ni le cycle.** Déjà
tranché deux fois cette session pour ce même sujet (HX1 fermeture benne).

## Constat

`BucketCloseTimedOut`/`BucketCloseTimer` (`FB_CycleMachineHoming.st:122,
146, 256-257`) est un timeout de 8s (paramétré via `Cfg.CfgTimeoutBucketClose`,
pas un littéral `T#8s` — d'où sa présence non détectée par un grep précédent).
Il intervient dans l'abandon de HX1 (`:429`) et alimente une cause de défaut
(`:353`).

## Objectif

Retirer `BucketCloseTimedOut`, `BucketCloseTimer`, et `Cfg.CfgTimeoutBucketClose`
(si plus utilisé ailleurs — vérifier avant de purger le champ de config).
La garde de fermeture benne à HX1 repose uniquement sur :
- palier 1 forcé (`CmdWinchSelect := 2`, vitesse plafonnée),
- homme-mort + joystick tiré (`BucketPermit AND JoystickPull`),
- confirmation opérateur explicite (`HomingBucketConfirmEdge`).

Aucune limite de temps — l'opérateur voit lui-même si ça bouge ou pas.

## Contraintes

- Vérifier `Cfg.CfgTimeoutBucketClose` n'est pas consommé ailleurs avant de
  le retirer de `ST_fbMachineHomingCycle_Cfg.st`.
- Retest CI (le cas H003/H009 mentionnant le timeout 8s doit être adapté).
- Preuve avant/après (grep confirmant 0 occurrence restante).
- AUCUN COMMIT sans accord explicite distinct du GO.
