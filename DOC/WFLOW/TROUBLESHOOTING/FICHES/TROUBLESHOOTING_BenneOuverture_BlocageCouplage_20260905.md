# 🕵️ Session de Troubleshooting — Benne ouverture / blocage couplage

> 📅 Date : 2026-09-05 · 🧩 Situation : [SITE] (inférée : `SimulationEnabled=FALSE`) · 📄 Statut : EN COURS

## 1. 🧩 Contexte figé

Snapshot unique : `Snapshot_Troubleshooting_20260905_120629.csv`, lu à 12:06:29.
Mode `E_Mode.SEMI_AUTO`; chaîne AU fermée et contacteur puissance engagé. Homing machine terminé (`MachineHomed=TRUE`, étape 60).

| Élément | Variable complète | Valeur |
|---|---|---|
| Stop sécurité global | `A_ContexteMachineGlobal.Idx303/304` | `FALSE / FALSE` |
| Commande cycle benne | `K_BenneOuvertureFermeture.Idx203_CycleCmd_Open` | `TRUE` |
| État benne | `Idx106/111/112/401` | `BUSY / Intermediate / 13.5839844 m / TRUE` |
| Couplage | `T_Permits.BothActive/Blocked/BlockReason` | `TRUE / TRUE / COUPLING_BLOCKED` |
| M2 | `O_MotionM2.Step4_MotionRequested/RelayRevActive/HwIn_BrakeIsOpen_DI` | `TRUE / TRUE / FALSE` |

## 2. 🎯 Symptôme

En cycle semi-auto, la commande couplée M1+M2 est arrêtée tandis que le cycle demande l'ouverture de la benne.

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Attendu | Lu | Verdict |
|---|---|---|---|---|---|
| 1 | AU / SafeStop / PowerCutOff actif | `A_ContexteMachineGlobal.Idx303/304` | `FALSE/FALSE` | `FALSE/FALSE` | ❌ écartée |
| 2 | Défaut benne arrêté | `K...Idx302/306` | `FALSE/WORD#0` | `FALSE/WORD#0` | ❌ écartée |
| 3 | Ouverture cycle en cours | `K...Idx203/401/111` | `TRUE/TRUE/TRUE` | `TRUE/TRUE/TRUE` | ✅ confirmée |
| 4 | Couplage interdit tant que permis agrégé incomplet | `T_Permits.BothBlocked/BlockReason` | `TRUE/COUPLING_BLOCKED` | `TRUE/COUPLING_BLOCKED` | ✅ confirmée |
| 5 | Le frein M2 ne confirme pas ouvert | `O_MotionM2.HwIn_BrakeIsOpen_DI` | `TRUE pendant marche` | `FALSE` | ❓ à refiger pendant la commande maintenue |

## 5. 📊 Arbre vertical

```text
Cycle semi-auto demande OPEN = TRUE
  → Benne BUSY / Intermediate (Delta 13.584 m) ✅
  → Intention Both = TRUE
    → permis Both = bloqué (COUPLING_BLOCKED) ✅ verrou de processus
  → M2 demandé en descente 20 %, relay reverse = TRUE
    → retour frein ouvert = FALSE ❓ à confirmer sur un snapshot durant la persistance du symptôme
```

**Résumé une ligne** : `[CycleCmd_Open=1] → [BucketBusy=1] → [BothBlocked=1, COUPLING_BLOCKED]`.

## 7. 🏁 Conclusion

- **Fait** : aucun arrêt de sécurité n'est actif. Le blocage couplé est la conséquence prévue de l'ouverture de benne toujours en cours.
- **Fait utilisateur (2026-09-05)** : la maintenance fonctionne parfaitement; le symptôme est exclusivement en plein cycle SEMI_AUTO. L'hypothèse frein/câblage est donc écartée pour cette session.
- **Important** : `O_MotionM2.Step2_ModeAuthorized=FALSE` est normal en SEMI_AUTO : cette checklist est explicitement définie pour MAINT_N1/N2. Elle ne prouve pas un blocage du cycle.
- **Traçage code** : en SEMI_AUTO, `FB_WinchCmdArbitrationM2` autorise explicitement l'override benne même lorsque le couplage est bloqué. Le snapshot confirme son émission (`RelayRevActive=TRUE`, palier 1). `BothBlocked` décrit le BOTH M1+M2, pas l'ordre M2 propre à l'ouverture de benne.
- **Fait vérifié dans le câblage** : `FB_Bucket.ReqAscent/ReqDescend` reçoit directement `WinchBothReqAscent/Descend`, eux-mêmes issus de `PRG_03.Data.WinchBothIntent` (intention joystick). Le cycle ne possède donc pas une demande autonome différente de la maintenance.
- **Conclusion précédente retirée** : l'hypothèse « le délai de redémarrage ne compte jamais parce que le cycle maintient une demande autonome » n'est pas prouvée et ne doit pas guider une modification.
- **Fait restant** : le snapshot montre une demande amont M2 (`RelayRevActive=TRUE`, palier 1), mais un frein final non commandé (`BrakeCmd=FALSE`) sans erreur, SafeStop ni permis final refusé. La barrière finale masque donc l'action ou la projection snapshot est incohérente; laquelle est indéterminable avec les variables publiées.
- **Défaut de diagnostic** : `GVL_Troubleshooting` publie le relais amont, mais pas `FB_WinchOutputInterlock.State`, `Reason`, `RestartRequired`, `RestartInhibit`, `DeadTimePending` ni ses temps écoulés. La cause finale n'est pas lisible dans le snapshot actuel.
- **Statut** : à valider par un snapshot frais pris après maintien de la demande d'ouverture.

## 8. 🛠️ Proposition

- **Immédiat, sans code** : ne pas forcer le couplage; aucun contournement n'est recommandé tant que l'état final de l'interlock n'est pas lu.
- **Définitif (à planifier C4)** : publier `FinalInterlockState`, `Reason`, `RestartRequired`, `RestartInhibit`, `DeadTimePending`, `RestartDelayElapsed` et `DeadTimeElapsed`, puis corriger uniquement la branche prouvée, avec test MAINT/SEMI_AUTO.
- **Validation requise** : humaine; aucune modification code ou forçage PLC proposé.

## 10. 📝 Journal

- 2026-09-05 12:06:29 : snapshot 541/541 lu, résultat ci-dessus.
- 2026-09-05 : opérateur confirme que MAINT fonctionne; diagnostic recentré sur le flux SEMI_AUTO.
