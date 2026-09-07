# 🕵️ Session de Troubleshooting — Synchronisme pendant pilotage benne

> Date : 2026-09-07 · Situation : [SITE MACHINE RÉELLE — contexte exact à confirmer] · Statut : [EN COURS]

## 1. Contexte figé

Le défaut est rapporté pendant le pilotage manuel de la benne. Le code contient déjà une inhibition de la surveillance d'écart M1/M2 et une temporisation de retombée. Aucun nouveau temporisateur n'est ajouté à ce stade.

Le snapshot disponible `Snapshot_Troubleshooting_20260907_122109.csv` est postérieur au défaut et montre une machine à l'arrêt ; il ne permet donc pas d'identifier la cause de l'événement.

## 2. Symptôme

Défaut rapporté par l'opérateur pendant le pilotage de la benne : type « écart » ou « synchronisme » non confirmé, avec suspicion que l'inhibition des contrôles ne reste pas assez longtemps à la retombée.

## 3. Preuves statiques — pas de doublon identifié

| Fonction | Source | Constat |
|---|---|---|
| Inhibition process | `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | `SyncOperationPermit` passe à FALSE si `ManualBucketJogActive`, commande benne, `instBucket.Lifecycle.Busy`, homing ou étape AX8..AX11. |
| Temporisation après retombée | `PRG_04_Treuils_Benne.st` | `BucketActivityHold : TOF`, `PT := T#4s`, utilisé dans `instWinchSync.Enable`. |
| Purge synchro | `CODE/H_TREUILS_BENNE/FB_WinchSync.st` | `Enable=FALSE` appelle les sous-blocs avec gate fermé et `Reset=TRUE`, remet les warnings/défauts à FALSE et purge le latch. |
| Ecart codeurs | `CODE/H_TREUILS_BENNE/FB_SyncDeviation.st` | Le calcul est conditionné par `SyncEnable`; `WarnLatched` est purgé lorsque `SyncEnable=FALSE`. |
| Ecart croisé MecaE | `PRG_04_Treuils_Benne.st` / `FB_Safety_Winch.st` | `CrossCheckEnable := SyncOperationPermit`; la vérification croisée est donc déjà inhibée pendant le pilotage benne. |
| Concordance sorties finales | `CODE/M_MAIN/PRG_06_Outputs.st` | `instSyncContactorFinal` est appelé avec `Enable := TRUE`; il compare les vecteurs physiques finaux. Ce n'est pas le même chemin que `FB_WinchSync`. |

## 4. Arbre des causes

| # | Hypothèse | Variable à lire dans le snapshot | Attendu | Verdict |
|---|---|---|---|---|
| 1 | L'inhibition amont ne tombe pas | `SyncOperationPermit` — non publié actuellement | FALSE pendant jog benne + hold | À mesurer |
| 2 | Le TOF de 4 s ne couvre pas la retombée réelle | `BucketActivityHold.Q` — non publié actuellement | TRUE pendant 4 s après fin | À mesurer |
| 3 | Un latch `FB_WinchSync` survit | `H_LevageSynchroniseM1M2.Idx302_SyncFaultActive` | FALSE après gate fermé | Statique éliminée, live à confirmer |
| 4 | Le défaut vient du contrôle final contacteurs | `PRG_06_Outputs.Data.ContactorMismatch`, diagnostic détaillé non publié dans la liste | FALSE en M2 seul, sauf discordance physique réelle | Hypothèse prioritaire |
| 5 | Transition de mode/sélecteur ou dead-time crée un chevauchement M1/M2 | relais/contacteurs finaux M1/M2 + `WinchSelTransitionHold` | pas de vecteur asymétrique persistant > 500 ms | À mesurer |
| 6 | Le message « sync » vient d'une autre brique (cycle/bandeau) | `G_CycleSemiAuto.Idx306_WinchSyncError`, `Idx205_ErrorId` | identifier le bit exact | À mesurer |

## 5. Flux causal suspect

```text
Pilotage benne
  → ManualBucketJogActive / commande benne
  → SyncOperationPermit = FALSE
  → FB_WinchSync purgé + CrossCheckEnable FALSE
  → BucketActivityHold maintient l'inhibition 4 s

En parallèle :
  sorties finales M1/M2
  → PRG_06.instSyncContactorFinal (toujours Enable=TRUE)
  → discordance physique éventuelle
  → ContactorMismatch / SafeStop
```

## 6. Données nécessaires pour conclure

Un seul snapshot doit être pris immédiatement après reproduction, sans reset préalable si possible. Variables déjà disponibles :

- `GVL_Troubleshooting.G_CycleSemiAuto.Idx205_ErrorId`
- `GVL_Troubleshooting.G_CycleSemiAuto.Idx306_WinchSyncError`
- `GVL_Troubleshooting.H_LevageSynchroniseM1M2.Idx302_SyncFaultActive`
- `GVL_Troubleshooting.H_LevageSynchroniseM1M2.Idx202_SyncEnabled_IHM`
- `GVL_Troubleshooting.J_LevageUnitaireM2.Safety_300.Idx317_ErrorMecaE`
- `GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx401_BucketBusy`
- `GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx206_CloseReqActive`
- `GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx207_OpenReqActive`
- `GVL_Troubleshooting.T_Permits.BucketMotionBlocked`

Deux signaux manquent pour trancher le timing de retombée : `SyncOperationPermit` et `BucketActivityHold.Q`. Leur ajout à la vue de troubleshooting serait préférable à un nouveau temporisateur métier.

## 7. Conclusion provisoire

- **Fait :** une temporisation de retombée de 2 s existe déjà.
- **Fait :** la synchro process et le cross-check MecaE sont déjà inhibés pendant le pilotage benne.
- **Hypothèse prioritaire :** le défaut est généré par la concordance des sorties finales dans `PRG_06`, indépendante de `FB_WinchSync`, ou par un chevauchement de sorties pendant la transition.
- **Impossible de conclure sans snapshot événementiel :** le snapshot disponible est au repos.

## 8. Proposition — après preuve uniquement

Ne pas ajouter un deuxième `TOF`. Selon le bit exact :

1. Si `FB_WinchSync` est en cause : diagnostiquer la condition qui maintient `SyncOperationPermit` à TRUE et réutiliser le `BucketActivityHold` existant.
2. Si `instSyncContactorFinal` est en cause : étudier un gate dédié à la concordance finale pendant le jog benne, sans inhiber une discordance où M1 et M2 sont tous deux commandés.
3. Si la retombée mécanique dépasse 2 s : paramétrer la temporisation existante, après mesure, plutôt que créer une seconde inhibition.

**Aucune modification de code n'est autorisée avant identification du bit de défaut et validation humaine.**

## 9. Journal

- 2026-09-07 : revue statique de `PRG_04`, `FB_WinchSync`, `FB_SyncDeviation`, `FB_Safety_Winch` et `PRG_06`.
- 2026-09-07 : confirmation d'une inhibition existante + `TOF` 2 s ; pas de doublon ajouté.
