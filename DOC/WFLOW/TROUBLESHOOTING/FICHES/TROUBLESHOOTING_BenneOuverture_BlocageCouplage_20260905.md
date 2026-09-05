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
- **Cause racine confirmée par code + signature snapshot** : `FB_WinchOutputInterlock` maintient `RestartRequired=TRUE` après l'arrêt. Son `RestartDelay` n'accumule que sous `NOT MotorRequest`. En cycle, `OpenReq` conserve `MotorRequest=TRUE` avant que les 750 ms de pause ne soient écoulées : le timer est alors arrêté à jamais et la branche `ELSIF RestartRequired OR DeadTimePending` coupe les sorties finales. Signature correspondante : relais demandé amont (`RelayRevActive=TRUE`, palier 1), mais `BrakeCmd=FALSE`, sans erreur, SafeStop ni permis final refusé.
- **Pourquoi MAINT fonctionne** : le relâchement naturel du joystick fournit la pause à zéro qui laisse le délai se purger; ce n'est pas le cas de la requête cycle continue.
- **Défaut de diagnostic** : `GVL_Troubleshooting` publie le relais amont, pas l'état/raison finale de `FB_WinchOutputInterlock`; l'état `WAIT_RESTART_DELAY` n'est donc pas visible dans le snapshot.
- **Statut** : à valider par un snapshot frais pris après maintien de la demande d'ouverture.

## 8. 🛠️ Proposition

- **Immédiat, sans code** : ne pas forcer le couplage. Une pause réelle à zéro d'au moins 750 ms avant le lancement cycle contourne le défaut, à valider uniquement en état sûr.
- **Définitif (à planifier C4)** : faire progresser `RestartDelay` pendant l'attente d'une demande maintenue (et publier `FinalInterlockState`, `RestartRequired`, `RestartDelayElapsed` dans le snapshot), avec test de non-régression MAINT/SEMI_AUTO.
- **Validation requise** : humaine; aucune modification code ou forçage PLC proposé.

## 10. 📝 Journal

- 2026-09-05 12:06:29 : snapshot 541/541 lu, résultat ci-dessus.
- 2026-09-05 : opérateur confirme que MAINT fonctionne; diagnostic recentré sur le flux SEMI_AUTO.
