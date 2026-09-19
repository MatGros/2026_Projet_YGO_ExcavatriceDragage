# Troubleshooting — Maintenance couplée / interlock — trace 64

## Contexte figé

- Banc de simulation, mode maintenance.
- Sélecteur IHM `SelJoystickWinch = 0` : M1+M2 couplés.
- Essai : descente, arrêt, puis changement de sens et nouvelles demandes.
- Source : `Suivi_64_SIMU_Interlock_20260919.trace`, échantillonnage proche de 100 ms.

## Symptôme

Certaines demandes joystick n'entraînent aucun relais M1/M2. L'opérateur a l'impression que le mouvement couplé reste bloqué après un arrêt ou une inversion.

## Faits extraits de la trace

| Fenêtre | Observation | Force |
|---|---|---|
| 5,290–14,436 s | M2 descend seul ; ouverture benne passe d'environ 0 à 92 %. | Forte |
| 15,945 s | M1+M2 démarrent ensemble en descente après environ 1,509 s sans relais. | Forte |
| 58,097–69,262 s | M2 monte seul ; ouverture benne passe d'environ 93 à 8 %. | Forte |
| 70,669 s | M1+M2 démarrent ensemble en montée après environ 1,407 s sans relais. | Forte |
| 101,429 s | Une nouvelle montée couplée démarre correctement. | Forte |
| 116–119 s | Demande descente, `DeadmanArmed=1`, `ArmingPermit=1`, aucun relais, aucun ErrorId tracé. | Forte |
| 120,728 s | La demande opposée produit une montée couplée. | Forte |
| 126,161 s | Arrêt en limite haute logicielle, M1 environ 7,85 m. | Forte |
| 133–147 s | Plusieurs demandes de descente restent sans relais malgré `DeadmanArmed=1`, `ArmingPermit=1`, ErrorId=0. | Forte |

## Arbre des causes

| Branche | Verdict | Preuve / manque |
|---|---|---|
| Joystick / homme-mort | Éliminée pour les blocages longs | `DeadmanArmed=1`, consigne jusqu'à 100 %. |
| Armement global | Éliminée | `PRG_04.Data.ArmingPermit=1`. |
| Défaut treuil/synchronisme | Éliminé selon variables tracées | ErrorId M1/M2 et synchronisme à 0. |
| D18 seul | Éliminé comme explication des blocages de 3–14 s | Durée très supérieure à 500/800 ms. D18 reste candidat pour une partie du trou de 1,4–1,5 s. |
| Mouvement M2 seul avant M1+M2 | Confirmé | La cause exacte n'est pas départagée : T248 si le toggle est actif, garde indépendante `M3AtTremie`, ou autre commande M2. La valeur du toggle et le sélecteur arbitré sont absents de la trace. |
| Verrou de phase / permis descente / arbitrage | Non départagé | Bits internes absents de la trace 64. |
| Sorties physiques | Éliminées en première intention | Les sorties fonctionnent lors des mouvements autorisés voisins. |

## Conclusion provisoire

La trace 64 ne montre pas une panne unique de D18. Elle confirme un mouvement préparatoire M2 seul avant le mouvement couplé, sans permettre d'affirmer que `TglEnableCoupledBucketSequencing` était actif. Le code respecte ce toggle dans T248 et dans `FB_BucketCmdArbitration`. Une garde distincte force toutefois le sélecteur arbitré à M2 seul lorsque `M3AtTremie=TRUE` et `AllowWinchMoveAtTremie=FALSE`, indépendamment du toggle. La trace révèle en plus un blocage logique durable sur certaines demandes de descente ; il se situe avant les sorties et ne peut pas être attribué à D18 seul.

## Variables minimales pour la prochaine preuve

- `PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated`
- `GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing`
- `PRG_05_Translation.Data.TranslationState.LimitSwitchTremie`
- `GVL_IHM.M3Translation.Cmd.TglAllowWinchMoveAtTremie`
- `PRG_03_Modes_Cycle.Data.Auth.CoupledBucketPhaseLocked`
- `PRG_03_Modes_Cycle.Data.Auth.WinchSelTransitionHold`
- `PRG_04_Treuils_Benne.WinchBothDiveBucketOpenArmed`
- `PRG_04_Treuils_Benne.WinchBothAscentBucketCloseArmed`
- `PRG_04_Treuils_Benne.EffectivePermitM1_Descend`
- `PRG_04_Treuils_Benne.EffectivePermitM2_Descend`
- `PRG_04_Treuils_Benne.instWinchM1.DirectionChangePending`
- `PRG_04_Treuils_Benne.instWinchM2.DirectionChangePending`
- `PRG_04_Treuils_Benne.instBucket.Lifecycle.Busy`

## Action

Aucune modification de code. Ne pas utiliser la trace 64 seule pour valider un correctif D18 : elle contient aussi le séquencement benne T248 et un blocage durable distinct.

## Snapshot complémentaire — passage en cycle 2026-09-20 01:08:54

- Mode effectif : `SEMI_AUTO`, étape `AX3_OPEN_BUCKET`.
- `Bucket AutoSeqActive=FALSE` : le toggle maintenance est bien désactivé.
- `CycleCmd_Open=TRUE`, `OpenReqActive=TRUE`, `BucketBusy=TRUE` : l'ouverture provient explicitement du graphe AX3, indépendamment du toggle maintenance.
- `CoupledDiveOpenArmed=FALSE`, `CoupledAscentCloseArmed=FALSE` : le séquencement couplé maintenance n'est pas armé.
- `M3_PosTremie_DI=FALSE` : la garde trémie n'explique pas cet instant.
- Permis ouverture et descente M1/M2 vrais, aucun défaut ; relais M2 encore faux au moment précis du snapshot.

Ce snapshot corrige l'interprétation initiale : toggle désactivé confirmé. En mode cycle, AX3 possède sa propre demande d'ouverture et doit commander M2 sans dépendre de ce toggle.
