# orchestrate run r-mucxvj0c-5n4gsx

- mode: fanout | agent: session-2902925a-96fc-4672-ae76-a2b0b20d5ff2 | provider: spawn
- concurrency: 6 | durationMs: 465789 | aborted: false
- startedAt: 2026-09-22T17:19:32.604Z | finishedAt: 2026-09-22T17:27:18.393Z

## Transition de cycle AX10→AX11 [completed]

J'ai maintenant la chaîne complète. Synthèse de l'analyse.

## Analyse statique — Transition AX10→AX11 & creux treuils

### (1) Condition de sortie AX10
`FB_CycleSemiAuto.st:1321` :
```st
IF DeadmanArmed AND JoystickPull AND Benne_CloseReached AND (Benne_IsClosed OR Benne_IsRoughlyClosed) THEN
    State := AX10B_RACCORDEMENT_P1;
```
Sortie conditionnée par : **homme-mort armé + joystick tiré + fermeture benne atteinte** (`Benne_CloseReached`) **et benne mécaniquement fermée/approx.**. Le départ AX9→AX10 est `FB_CycleSemiAuto.st:1291` ; entrée directe AX8→AX10 si `RaiseOffBottomM≤0` (`:1233`).

### (2) AX10B et le saut AX10→AX11
AX10B est toujours franchi (`:1324`). Un saut AX10→AX11 **direct n'existe pas**. Le transfert AX10B→AX11/AX12 (`:1347-1375`) :
- **Branche nominale** (`:1352-1354`) : `NOT fallback AND (M2_SpeedStepApplied = 1) AND M1FinalAscentStartReady AND DeadmanArmed AND JoystickPull` → **transfert atomique P1/P1** (`:1358-1359`) puis `State := AX11` (ou AX12 si distance contrôle nulle, `:1362-1366`).
- **Branche repli** (`:1367-1374`) : `Ax10bFallbackStopActive AND AscentStartStopTimer.Q`.

### (3) Publication des demandes treuils
Pendant **AX10 (`:1310-1311`) ET AX10B (`:1342-1343`)** :
```st
WinchM1Cmd.RunRequest := FALSE; ... StepTgt := 0;
WinchM2Cmd.RunRequest := FALSE; ... StepTgt := 0;
```
→ Les **deux demandes programme `WinchM1Cmd`/`WinchM2Cmd` sont simultanément nulles toute la phase AX10/AX10B**. Le **M2 est maintenu physiquement par FB_Bucket** via `BucketCmd.ReqHoldAscentP1AfterClose` (`:1345`) + le routage prioritaire benne de l'arbitre M2 (`FB_WinchCmdArbitrationM2.st:65-82` activé par `BucketHandoffP1Active`, `PRG_04:506-509`). Le **M1, lui, n'a aucune demande programme pendant toute la phase** (frein). Le transfert P1/P1 est publié au scan même du basculement (`:1358-1359`), puis repris en continu par AX11 (`:1390-1395`).

### (4) Rôles des variables décisionnelles
| Variable | Rôle | Lieu |
|---|---|---|
| `CtrlAscentStartM1/M2` | Positions de départ AX11, figées au transfert | `:1360-1361`, `:1368-1369` |
| `CtrlAscentDistM` / `CtrlAscentDistEffM` | Distance de contrôle AX11 (2 m défaut), transition AX11→AX12 | `:250`, `:339`, `:1397` |
| `AscentStartStopTimer` | Confirmation d'arrêt mécanique (500 ms) avant reprise montée en repli fallback | `:317-318`, `:1367` |
| `Ax10bHandoffWaitTimer` | Fenêtre bornée (2 s) d'attente disponibilité M1 pendant maintien M2 P1 ; timeout → repli fallback | `:319-323`, `:1348-1351` |
| `M1FinalAscentStartReady` | Condition de transfert : M1 disponible (barrière finale + **deadtime ≥700 ms**) | `:1353` ← `PRG_06:178-181` |
| `Ax10bFallbackStopActive` | Latch repli si M1 indisponible ; relâche M2 (Hold=FALSE) | `:258`, `:1319`, `:1350` |

### ⏱️ Explication du ~0,8 s terrain
`M1FinalAscentStartReady := instWinchOutputInterlockM1.Ready AND NOT RestartRequired AND NOT MotorRequest AND (DeadTimeElapsed >= T#700ms)` — **`PRG_06_Outputs.st:178-181`**. Le transfert AX10B→AX11 est donc **gelé ~0,7 s** par le temps mort de la barrière finale M1. Pendant ce gel : **M1 physique à zéro** (frein, aucune demande), M2 maintenu par la benne.

---

## Verdict branche

| Branche | Hypothèse | Variable de décision | Valeur attendue | Verdict | Preuve |
|---|---|---|---|---|---|
| T1 | La transition de cycle laisse **les deux demandes programme** `WinchM1Cmd`/`WinchM2Cmd` à zéro | `WinchM1Cmd.RunRequest` / `WinchM2Cmd.RunRequest` | `FALSE`/`FALSE` pendant AX10/AX10B puis `TRUE` au scan de transfert | ✅ **CONFIRMÉE** (état volontaire de la phase benne, pas un trou d'un scan) | `FB_CycleSemiAuto.st:1310-1311`, `:1342-1343`, transfert `:1358-1359` |
| T2 | La transition laisse **les deux treuils physiques** à zéro (nominal) | `M2_SpeedStepApplied` (= `StepNumber` FB_WinchM2) / `BucketHandoffP1Active` | M2 `=1` maintenu par benne pendant AX10B ; M1 seul à zéro | ❌ **ÉLIMINÉE en nominal** — M2 est maintenu par FB_Bucket/arbitre benne | `PRG_04:499-509`, `FB_WinchCmdArbitrationM2:65-82`, `FB_Bucket.st:525-530` |
| T3 | Le ~0,8 s observé = gel AX10B→AX11 par le temps mort M1 | `M1FinalAscentStartReady` (`PRG_06.Data.M1AscentStartReady`) | `FALSE` pendant ~0,7 s → `TRUE` après purge deadtime ≥700 ms | ✅ **ROOT CAUSE — confirmée** ; M1 réellement à zéro pendant ce gel | `PRG_06_Outputs.st:178-181`, consommation `FB_CycleSemiAuto.st:1353` |
| T4 | Repli fallback possible : les **deux** treuils à zéro | `Ax10bFallbackStopActive`, `Ax10bHandoffWaitTimer.Q` (2 s) | Fallback si M1 indisponible >2 s → M2 relâché (`Hold=FALSE`) → **les deux à zéro** jusqu'à reprise AX12 | ⚠️ **CONFIRMÉE (dégradé)** — cas limite non nominal | `:319-323`, `:1348-1351`, `FB_Bucket.st:517` |

**Réponse directe** : la branche « la transition de cycle peut laisser les deux treuils à zéro » est **confirmée au niveau des demandes programme** (volontairement nulles pendant toute AX10/AX10B) et **éliminée au niveau physique en nominal** pour M2 (maintenu par la benne). Le creux de ~0,8 s réellement observé terrain est très probablement le **temps mort M1 de 700 ms** (`DeadTimeElapsed ≥ 700ms`) qui gèle le transfert AX10B→AX11 — M1 chute, M2 reste tenu.

**Variables de décision à lire** (GVL_Troubleshooting, Watch CODESYS) :
- `G_CycleSemiAuto.Idx206_Step` (étape : doit montrer passage AX10→AX10B→AX11)
- `G_CycleSemiAuto.Idx307_M1SpeedStepApplied` / `Idx308_M2SpeedStepApplied` (paliers physiques : en creux, Idx307→0, Idx308 doit rester 1)
- `G_CycleSemiAuto.Idx209/210_WaitingForOperator/Process`
- `PRG_06_Outputs.Data.M1AscentStartReady` (le vrai gate du creux ~0,8 s)
- `PRG_03_Modes_Cycle.Data.SequenceState.Step` + `Data.ReqProgram.ReqBucket.ReqHoldAscentP1AfterClose` (confirmer le maintien M2)

Si vous voulez, je peux rédiger la fiche de session `Troubleshooting` selon le skill dédié ou proposer la correction visant à garantir que M1 reçoit un maintien P1 dès la fermeture (au lieu d'attendre le deadtime) si le creux devait être atténué.

## Barrière d'atomicité treuils M1/M2 [completed]

```
============================================================
🕵️ MODE DÉPANNAGE / TROUBLESHOOTING ACTIF
============================================================
Diagnostic : chute simultanée M1+M2 à zéro à la transition AX10→AX11 (AX10B→AX11) — branche « barrière d'atomicité »
```

Analyse **statique lecture seule** (aucun fichier modifié ; scope délégué + approbations désactivées → aucune écriture, pas de fiche `DOC/WFLOW/...` créée). Chaîne tracée et vérifiée dans `CODE/`.

---

## 1. Rôle exact des 5 signaux

**`WinchBothMotionActive`** — `PRG_03_Modes_Cycle.st:342-345` (SEMI_AUTO). En cycle : `WinchM1Cmd.RunRequest AND WinchM2Cmd.RunRequest AND (même sens)`. Passe **FALSE→TRUE au SAME scan du transfert AX10B→AX11** (les deux `RunRequest` passent à 1 au scan de transfert, `FB_CycleSemiAuto:1358-1359`). C'est le déclencheur *amont* de toute la barrière.

**`WinchBothMotionReady`** — `PRG_04:1405-1406` et re-calculé `1541-1542` :
`NOT (M1.DirectionChangePending OR M2.DirectionChangePending) AND NOT (M1.Fault.Latched OR M2.Fault.Latched)`. Verrou **d'atomicité** : les 2 treuils ne sont considérés prêts qu'ensemble.

**`DirectionChangePending`** — sortie de `FB_WinchDirectionInterlock` (D18), remontée par `FB_Winch:209`. `FALSE` = sens adopté (reprise du même sens depuis le neutre immédiate depuis `LastAscent/LastDescend`, `FB_WinchDirectionInterlock:144-155`). `TRUE` = inversion ou temps mort D18 au front Enable (`:140-143`).

**`RestartRequired`** (M1/M2) — sortie diag. de `FB_WinchOutputInterlock:71`, purgée pendant l'arrêt et sur tempo anti-redémarrage (`:221-228`). Entrée de `M1AscentStartReady` (`PRG_06:179`).

**`M1AscentStartReady`** = `PRG_06:178-181` : `interlockM1.Ready AND NOT RestartRequired AND NOT MotorRequest AND DeadTimeElapsed>=700ms`. **Gate du transfert AX10B→AX11** (`FB_CycleSemiAuto:1335, 1353-1354`) : garantit que la barrière M1 est purgée avant le départ couplé. Ce n'est **pas** la cause du trou — c'est la garde qui *retarde* le transfert (ou bascule en repli `Ax10bFallbackStopActive`, `:1347-1351`) tant que M1 n'est pas prêt.

---

## 2. Conditions de neutralisation DES DEUX ensemble (sorties nulles)

Trois mécanismes, tous en `PRG_04` :

| # | Mécanisme | Ligne | Effet si actif |
|---|---|---|---|
| A | Gèle M1 si M2 pas prêt | `1407-1409` | `ReqM1Winch` forcé à 0 |
| B | Gèle M2 si M1 pas prêt | `1499-1501` | `ReqM2Winch` forcé à 0 |
| C | Barrière §7 | `1661-1678` | SI `SEMI_AUTO AND WinchBothMotionActive AND (NOT WinchBothMotionReady OR NOT WinchBothFinalRequestsCoherent)` → **M1 ET M2** `RequestedRelayFwd/Rev`, contacteurs, `Step` **tous à 0** |

`WinchBothFinalRequestsCoherent` (`1648-1656`) exige **égalité stricte** des vecteurs finaux M1/M2 (sens **et** palier **et** 4 contacteurs).

---

## 3. Réponse à la question 3 — la non-préparation simultanée retient-elle les deux ?

**OUI, ce chemin existe et est écrit noir sur blanc.** Si **M1** est "pas prêt en montée" au transfert (`instWinchM1.DirectionChangePending=TRUE` **ou** `instWinchM1.Fault.Latched=TRUE`) :
- §6-B (`1499-1501`) **gèle M2** → M2 retombe,
- le `NOT WinchBothMotionReady` du §7 (`1661-1663`) **zéro les DEUX** vecteurs finaux → M1+M2 simultanément à 0,
- relâché **uniquement** quand `WinchBothMotionReady` repasse TRUE (M1 prêt) **et** `WinchBothFinalRequestsCoherent` TRUE.

En revanche, **nominalement** (reprise même sens, pas de défaut), M1 s'adopte au même scan (`FB_WinchDirectionInterlock:144-155` → `DirectionChangePending=FALSE`), `StepNumber` 0→1 au scan de transfert (`FB_WinchStepShaper:50-52`, 1er cran immédiat), et M2 déjà à P1 → les deux vecteurs sont égaux → pas de trou. **Le "trou" site implique donc un treuil momentanément non prêt ou un vecteur divergent au scan de transfert** — cohérent avec l'hypothèse « M1 pas prêt en montée », et aggravé si un `Fault.Latched` (ex. timeout frein) traîne.

---

## 4. Purge pendant AX8..AX11

`SyncOperationPermit` exclut AX8/AX9/AX10/AX11 (`PRG_04:442-445`) → `instWinchSync.Enable=FALSE` → `FB_WinchSync` **purge** inconditionnellement (`FB_WinchSync:89-107`, Reset=TRUE, aucun latch). Pendant la phase benne/transition asymétrique, **aucune fausse Discordance/MecaE/survitesse n'apparaît**. `CoupledBoth ::= SyncActive OR WinchBothMotionActive` (`PRG_04:1103`) → reste porté par `WinchBothMotionActive`. **La purge n'est donc pas la cause du trou** — c'est un *soulagement* qui évite un blocage parasite ; le trou vient de la barrière d'atomicité §6/§7, indépendante de la purge.

---

## 5. Verdict demandé (tableau)

| Hypothèse | Variable de décision | Valeur attendue au trou | Verdict | Preuve fichier:ligne |
|---|---|---|---|---|
| Barrière d'atomicité neutralise M1+M2 tant qu'ils ne sont pas prêts simultanément | `WinchBothMotionActive` @ AX10B→AX11 (transfert) | TRUE (repasse FALSE→TRUE au scan transfert) | ✅ **Confirmée en statique** — déclencheur amont | `PRG_03_Modes_Cycle.st:342-345` ; `FB_CycleSemiAuto.st:1358-1359` |
| M1 pas prêt en montée → M2 gélé → les deux à zéro | `instWinchM1.DirectionChangePending` / `instWinchM1.Fault.Latched` | TRUE à l'instant du trou | ✅ **Confirmée** — chemin direct | `PRG_04_Treuils_Benne.st:1499-1501` |
| Les deux retenus à zéro par la barrière finale | `NOT WinchBothMotionReady` (gate §7) | TRUE pendant le trou | ✅ **Confirmée** | `PRG_04_Treuils_Benne.st:1661-1678` |
| Vecteurs M1/M2 divergents (incohérence) | `WinchBothFinalRequestsCoherent` | FALSE pendant le trou | ✅ **Confirmée comme condition complémentaire** (violet strict) | `PRG_04_Treuils_Benne.st:1648-1656` |
| M1AscentStartReady coupe le transfert | `M1FinalAscentStartReady` | FALSE → transfert attendu/repli (nul pas "trou" reprise) | ⚠️ **Garde, pas cause** — retarde, ne zérose pas le couple | `FB_CycleSemiAuto.st:1335,1353-1354` ; `PRG_06_Outputs.st:178-181` |
| Purge AX8..AX11 provoque le trou | `SyncOperationPermit` (FB_WinchSync) | FALSE pendant AX8..AX11 | ❌ **Éliminée** — soulagement, pas blocage | `PRG_04:426,442-445` ; `FB_WinchSync:89-107` |
| **Verdict global : branche barrière d'atomicité** | `WinchBothMotionReady` / `WinchBothFinalRequestsCoherent` à cet instant | les deux à FALSE au scan de décrochage | 🎯 **Cause probable du trou** : neutraliser simultanée via §6 + §7 | `PRG_04:1407-1409,1499-1501,1661-1678` |

---

## 6. Variable à lire pour **prouver** au site

⚠️ **Contrainte canal snapshot (méthode troubleshooting)** : la variable *décisionnelle directe* — `WinchBothMotionReady`, `WinchBothFinalRequestsCoherent`, `instWinchM1/M2.DirectionChangePending`, `instWinchM1/M2.Fault.Latched` — **n'est PAS exportée** :
- ni dans `ST_WinchInterPrg.st` (bus PRG_04) ni dans `GVL_Troubleshooting.st`,
- ni dans `troubleshooting_variables.txt`.

Les proxies **disponibles aujourd'hui en snapshot** insuffisent (voir pourquoi) :
| Disponible | Ce qu'elle prouve | Limite |
|---|---|---|
| `GVL_Troubleshooting.Q_TraceWinchM1.StepNumber` / `R_TraceWinchM2.StepNumber` | paliers FB | **non zérotés** par §7 → peut rester non-nul pendant le trou |
| `GVL_Troubleshooting.T_Permits.BothBlocked`/`BothBlockReason` | agrégat permis (§5) | reflète les permis, **pas** la barrière §7 → peut être FALSE au trou |
| `GVL_Troubleshooting.H_LevageSynchroniseM1M2.Idx501/502_M?CmdRelayFwd_DQ` | sorties physiques | témoigne du trou mais transitoire, hors snapshot fiable |

➡️ **Preuve formelle non lisible en snapshot sans évolution** : ajouter une recopie purement diagnostique (zéro effet de conduite) dans `ST_WinchInterPrg` + `GVL_Troubleshooting` (`T_Permits`), puis régénérer la liste snapshot — par ex. `WinchBothMotionReady`, `WinchBothFinalRequestsCoherent`, `BothAtomBarrierZero` (= condition ligne 1661-1663), `M1/M2DirectionChangePending`, `M1/M2FaultLatched`, + `SequenceState.Step`. Cette évolution demande validation humaine ; hors périmètre "lecture seule" de cette analyse.

## Écart vitesse & survaillance AX11 [completed]

# 🕵️ Analyse statique — Trou AX11 / surveillance écart vitesse M1/M2

## Chaîne de surveillance concernée (flux de données)

```
FB_CycleSemiAuto (AX11)                                        FB_WinchSync / FB_SyncDeviation (PRG_04)
  SpeedMismatchMps = |M1_Spd - M2_Spd|   (l.374)                DeltaPosM = |CableM1 - CableM2 + Offset|  (l.67-68)
  SpeedMismatchActive  (l.375-379)  ←── 0.0 / 0                 Warn  seuil1 = CfgSyncToleranceM (défaut 3.0m)
  SpeedMismatchConfirmed(l.381-382)      DÉSACTIVÉ ↓             Fault seuil2 = CfgSyncCriticalToleranceM (défaut 6.0m) TON 800ms
  instCauses[2]/[5]  → jamais actives                           → SyncDeviationFault → WinchSyncError (PRG_04:1949)
```

---

## Réponses aux 4 questions

### (1) Seuil de l'écart autorisé + confirmation temporelle

| Paramètre | Déclaration | Câblage réel (PRG_03) | Résultat |
|---|---|---|---|
| `SpeedMismatchThresholdMps` (seuil vitesse) | `FB_CycleSemiAuto.st:52` | `PRG_03_Modes_Cycle.st:246` → **`:= 0.0`** | `>0.0` jamais vrai → écart vitesse **jamais armé** |
| `SpeedMismatchTimeout` (TON confirmation) | `FB_CycleSemiAuto.st:53` | `PRG_03_Modes_Cycle.st:247` → **`:= T#0ms`** | `> T#0ms` jamais vrai → **désactivé** |

Le code local est complet (calcul l.374, gate l.375-379, TON l.381-382, causes l.477 et l.491) **mais la condition d'armement exige `> 0.0` ET `> T#0ms`**, valeurs que PRG_03 fournit littéralement à zéro avec le commentaire `// Contrôle local G7 désactivé ; protections FB_WinchSync conservées`. **La branche écart-vitesse AX11 est inertes par conception.**

### (2) Conditions SITE réelles vs banc

L'écart **vitesse** (m/s) ne peut rien déclencher : seuil=0/timeout=0 le coupent même si l'écart physique est énorme (charge benne, câbles, accélération). Un arrêt en site **ne peut PAS venir de cette branche**.

⚠️ Ce qui **reste actif** en AX11, c'est l'écart **POSITION** `FB_WinchSync/FB_SyncDeviation` : seuil Fault `CfgSyncCriticalToleranceM = _SyncCfgPersist` (défaut **6,0 m**) filtré par un **TON de 800 ms** (`FB_SyncDeviation.st:95`) → `SyncDeviationFault` → `WinchSyncError`. Cette 2ᵉ branche (position, pas vitesse) est sensible au **mou de câble / à la benne chargée / au transitoire de décollement** que le banc ne reproduit pas. Mais :
- elle est explicitement **exclue du repli AX_STAB en AX11** (`FB_CycleSemiAuto.st:467-473` : `instCauses[1]` ≠ AX11) ;
- elle **bloque la transition AX11→AX12** (`l.1399 : AND NOT WinchSyncError`) et abaisse `SpeedGuardReady` côté PRG_04 (`PRG_04:1442/1510`) → les treuils peuvent se bloquer en AX11 ; c'est un **autre** mécanisme que l'écart-vitesse demandé.

### (3) Passage AX11 → AX12

- Entrée : `AX10B_RACCORDEMENT_P1` capture `CtrlAscentStartM1/M2` puis va en AX11 **si `CfgCtrlAscentDistanceM > 0`** (`l.1360-1366`) ; sinon saute direct AX12.
- AX11 pilote M1/M2 en palier `CtrlAscentMaxStepEff` (borne [1..2], défaut 1) (`l.1392-1395`).
- Transition → AX12 (`l.1397-1404`) : **strictement sur distance** `M1 ≥ CtrlAscentStartM1 + CtrlAscentDistEffM` **ET** `M2 ≥ …` **ET** `NOT WinchSyncError`. **Aucun TON de transition** : `StabilizationTimer` (1 s) et `CtrlAscentTimeout` sont **calculés mais jamais consommés** (`.Q`/`.ET` inutilisés, confirmé grep). Le commentaire "pause de contrôle" est obsolète → c'est une **phase pilotée par distance**, pas une pause temporisée.

### (4) Rôle des configs `CfgCtrlAscentMaxStep [1..2]` / `CfgCtrlAscentDistanceM`

- `CfgCtrlAscentMaxStep` → `CtrlAscentMaxStepEff := LIMIT(1, Cfg, 2)` (`l.338`) : palier max de montée **contrôlée** AX11 (1=P1 lent, 2 optionnel). Ne conditionne **aucune sécurité** : seulement la vitesse AX11. Défaut IHM `GVL_IHM.CycleSemiAuto.Cfg.CtrlAscentMaxStep` (`PRG_03:286`).
- `CfgCtrlAscentDistanceM` → `CtrlAscentDistEffM := SEL(Cfg<=0, 2.0, Cfg)` (`l.339`) : distance de contrôle AX11 ; **c'est elle qui définit la longueur de la phase** et la condition de passage à AX12 (`l.1397-1398`) ; si ≤0 → **AX11 zappé** (passage direct AX10B→AX12). IHM `ExtractionControlDistance_M` (`PRG_03:287`). Une valeur site différente ne peut **pas** provoquer de trou : elle change la durée/palier AX11, pas un arrêt.

---

## Verdict — tableau demandé

| Hypothèse | Variable de décision | Valeur attendue | Verdict | fichier:ligne |
|---|---|---|---|---|
| Écart **vitesse** M1/M2 déclenche un arrêt pendant AX11 | `SpeedMismatchActive` (`GVL_Troubleshooting…Idx304`) | **FALSE en permanence** | ❌ **Exclu** — seuil/timeout câblés à 0 | `PRG_03_Modes_Cycle.st:246-247` ; `FB_CycleSemiAuto.st:377-378` |
| Confirmation TON écart → repli AX_STAB en AX11 | `SpeedMismatchConfirmed` / `instCauses[2]` | jamais TRUE | ❌ **Exclu** — même raison (gate `Timeout>0`) | `FB_CycleSemiAuto.st:381-382,477,491` |
| **Position** M1/M2 hors seuil critique ≠ vitesse → blocage AX11 | `WinchSyncError` (`GVL_Troubleshooting…Idx306`) | à mesurer (si >6,0 m pdt 800 ms → TRUE) | ⚠️ **Cause plausible du trou** (mais = écarts **position**, PAS la branche vitesse) — exclu du repli AX_STAB, **retient AX11** par `NOT WinchSyncError` | `FB_SyncDeviation.st:95` ; `PRG_04_Treuils_Benne.st:1949` ; `FB_CycleSemiAuto.st:1399` |
| Config site ≠ banc (palier/distance AX11) | `CfgCtrlAscentMaxStep` / `CfgCtrlAscentDistanceM` | bornés [1..2] / >0 | ❌ **Non cause** — modifie durée/palier AX11, aucun arrêt | `FB_CycleSemiAuto.st:338-339,1397-1398` ; `PRG_03:286-287` |
| Étape réelle du trou (à confirmer terrain) | `CycleStep` / `CycleStepAtError` (`Idx206`/`Idx208`) | AX11 ou AX_STAB | ⏳ à lire en snapshot | `FB_CycleSemiAuto.st:138-140` |

**Verdict final :** ❌ **NON, la branche « écart vitesse / surveillance AX11 » (`SpeedMismatch*` locale) n'est PAS une cause probable du trou** — elle est **désactivée à la source** (`PRG_03_Modes_Cycle.st:246-247` = 0.0 / 0, commentaire « Contrôle local G7 désactivé ») et ne peut mathématiquement jamais s'armer. Le « trou » en site, s'il relève d'une surveillance, provient plutôt de la branche **position** `FB_WinchSync/FB_SyncDeviation` (`WinchSyncError`, seuil critique 6,0 m / TON 800 ms) qui **retient l'étape en AX11** et coupe `SpeedGuardReady` — nettement plus plausible en site (mou de câble, benne chargée, transitoire de décollement). La fiche existante `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TrouAX10_AX11_SiteVsBureau_20260922.md` pointe déjà correctement cette séparation (hyp. 4 vs hyp. 1-3).

**Variables de décision à lire (GVL_Troubleshooting.st, présent)** :
- `GVL_Troubleshooting.G_CycleSemiAuto.Idx304_SpeedMismatchActive` → doit rester **FALSE** (preuve de non-déclenchement) — alimenté `FB_TroubleshootingView.st:771` ← `PRG_07:904`.
- `GVL_Troubleshooting.G_CycleSemiAuto.Idx306_WinchSyncError` → **TRUE** pendant le trou ⇒ cause position, pas vitesse) — `FB_TroubleshootingView.st:773` ← `PRG_07:906` ← `PRG_04:1949`.
- `GVL_Troubleshooting.G_CycleSemiAuto.Idx206_Step` / `Idx208_StepAtError` → étape exacte figée (AX11 vs AX_STAB) — `ST_ChainCycleSemiAuto.st:35-38`.

*Note sécurité : analyse statique pure, aucun code modifié. À confronter aux traces/snapshot du chantier (état réel de `Idx304/306` pendant le trou) pour trancher la branche position.*

## Retour fermeture benne & différence site/banc [completed]

# 🕵️ Verdict — retour « benne fermée » instable/tardif en site : cause plausible du trou AX10→AX11

## 1. Comment le « retour benne fermée » est produit (CloseReached / BucketCloseReached / IsClosed / auto close)

Il n'y a **pas** de signal unique « capteur de fermeture ». Le retour est **dérivé de la géométrie M1/M2** par 3 chemins qui se combinent en disjonction (OR) :

| Signal | Fichier:ligne | Nature | Persistance / debounce |
|---|---|---|---|
| `instBucket.CloseReached` (latch) | `FB_Bucket.st:635` | latch posé une fois à l'arrivée de fermeture ; ré-armé à la prochaine CmdOpen/Close | **latch** : reste TRUE tant qu'on ne relance pas un open/close — ✅ stable par construction |
| `Data.BucketCloseReached := instBucket.CloseReached` | `PRG_04:1775` → `PRG_03:263` `Benne_CloseReached` | consommé par le cycle AX10→AX10B | identité (même bit) |
| `Benne_IsRoughlyClosed` | `PRG_04:1823` → `PRG_03:266` | `IsClosed` OU (`IsIntermediate` ET Δ≥OffsetClose−2 m) OU `instCloseThreshold.Reached` | **recaclulé à CHAQUE scan sur mesure bruta Δ** 🟡 |
| `Benne_IsClosed` (état franc) | `FB_Bucket.st:433/438` | `ClassCanRun AND ABS(Δ−OffsetCloseM) ≤ CoherenceLimitM` | **instantané, sans debounce** 🟡 |
| `instCloseThreshold.Reached` (branche `CloseReachedOpening_Pct`/`ExtractionStartOpening_Pct`) | `FB_BucketCloseThreshold.st:109` | mesure qualifiée, Δ≥OffsetClose−Distance | **re-claculé chaque scan, non latched** 🟡 |
| AX10 plafond `BucketAutoCloseActive` | `PRG_04:503-505` (Step=AX10) + `FB_WinchCmdArbitrationM2:78-79` | gating sur `ReqBucket.ReqClose` | suit l'état de la séquence |
| AX10B `BucketHandoffP1Active` | `PRG_04:506-509` → `FB_WinchCmdArbitrationM2:76-77` | `Mode=SEMI_AUTO ∧ Step=AX10B ∧ instBucket.CloseReached ∧ ReqHoldAscentP1AfterClose` | dépend du latch CloseReached |

**Réponse à la question (1) :** le retour de stabilité requis ne vient **pas** d'un debounce du signal : il vient du fait que `CloseReached` est un **latch** (`FB_Bucket.st:496/500` le ré-initialise à chaque nouvelle commande open/close). Donc une fois posé, il autorise la montée. En revanche les chemins **`Benne_IsClosed` / `Benne_IsRoughlyClosed`** (nœuds de disjonction au passage AX10→AX10B, `FB_CycleSemiAuto.st:1321`) sont re-calculés à chaque scan sur la mesure **sans aucune confirmation temporelle de ≥300 ms**. Le scénario Modelica « retour actif ≥300 ms » n'est **pas** matérialisé par un `TON` sur ce front : la stabilité repose sur un **latch**, pas sur une temporisation.

## 2. Ce qui, en site, rend ce retour tardif/instable (rebond/tremblote)

Le retour se calcule sur `DeltaPosition_M = CablePosM2 − CablePosM1` (`FB_Bucket.st:428`) et `NearClosed`/`NearOpen` sur `ABS(Δ − Offset) ≤ CoherenceLimitM` (bande, `FB_Bucket.st:433`). En site réel vs banc :

- **Hydraulique benne / frottements / matière** : Δ oscille à la frontière `OffsetCloseM ± CoherenceLimitM` → `IsIntermediate`/`TooClosed` clignotent au bord de bande → `Benne_IsRoughlyClosed` retombe momentanément à FALSE (disjonction qui s'ouvre).
- **Réglage `CloseReachedOpening_Pct` / `ExtractionStartOpening_Pct`** : branche seuil additive (`FB_BucketCloseThreshold.st`) conditionnée par `MeasureValid ∧ IsIntermediate` ; un `IsIntermediate` tremblotant rend `Reached` discontinu scan à scan.
- **Codesurs / câbles / étirement M2 vs M1** : le Δ brut n'est pas filtré au niveau du nœud de transition cycle → micro-oscillation codeur près de la frontière.
- **Rien de tel au banc** : la simulation pilote M1/M2 idéalement, le Δ franchit la frontière une seule fois franchement, pas de frottement/câble → pas de clignotement.

## 3. Comment le plafond AX10 et le raccordement AX10B dépendent de ce retour

| Nœud | Fichier:ligne | Dépendance au retour |
|---|---|---|
| Plafond M2 en AX10 | `PRG_04:1309-1310` + `FB_WinchCmdArbitrationM2:78-79` (`BucketAutoMaxStepUp`) | déclenché si `BucketAutoCloseActive` = Step AX10 ∧ ReqClose. Si le franchissement « fermée » n'est pas confirmé, on reste en AX10 (fermeture) au lieu de passer en raccordement. |
| Raccordement AX10B (montée P1) | `FB_CycleSemiAuto.st:1321-1325` | **condition de sortie AX10 → AX10B : `DeadmanArm∧JoystickPull∧Benne_CloseReached∧(Benne_IsClosed∨Benne_IsRoughlyClosed)`**. Si la disjonction tremblote → sortie retardée. |
| Transfert AX10B → AX11 | `FB_CycleSemiAuto.st:1352-1366` | exige `(M2_SpeedStepApplied=1) ∧ M1FinalAscentStartReady` → c'est le **plafond** (`Cfg.BucketAutoMaxStepUp`/`CtrlAscentMaxStep`, `PRG_04:527`) qui borne M2 à P1 pendant le transfert ; `BucketHandoffP1Active` (`PRG_04:506-509`) force `StepTgt:=1`. |
| `M2MaxStepUp := 1` AX10B | `PRG_04:1307-1308` | ne s'applique que si `BucketHandoffP1Active` = vrai, lui-même dépendant du latch `CloseReached`. |

**Le « trou » mécanique est au passage AX10→AX10B** : si le retour benne-close est tardif ou tremblotant en site, le cycle bloque à AX10 et les commandes treuils restent à zéro pendant que la benne finit de se fermer, puis ne « rebranchent » la montée P1/P1 qu'au transfert AX10B→AX11 (`FB_CycleSemiAuto.st:1358-1359`) — d'où le trou AX10→AX11.

## 4. Ce qui diffère site vs banc et pourrait produire le trou uniquement en site

| Différence site vs banc | Effet sur le retour |
|---|---|
| Frottements benne + matière → Δ oscille à la frontière `OffsetClose ± Coherence` | `IsClosed`/`IsIntermediate`/`RoughlyClosed` tremblotants → sortie AX10 retardée |
| Câble/étirement M2↔M1, codeurs réels (bruit) | `DeltaPosition_M` brut instable → seuil branche (`FB_BucketCloseThreshold`) discontinu |
| Absence d'un `TON ≥300 ms` de confirmation du retour (le latch masque la non-stabilité au banc) | La non-stabilité ne « s'extériorise » qu'en site ; au banc le latch rend la disjonction vraie quasi immédiatement |
| Hydraulique : le « benne fermée » mécanique (mâchoires) n'est pas un capteur franc, c'est une inférence géométrique | pas de rebond simulé au banc |

## 5. Verdict sur la branche « retour benne fermée instable/différent en site »

> **OUI — branche PLAUSIBLE** (cause contributive crédible), avec une nuance : le retour `CloseReached` est un **latch** (stable), c'est la **disjonction `Benne_IsClosed`/`Benne_IsRoughlyClosed` + seuil `%`** qui est fragile et re-calculée à chaque scan **sans debounce de 300 ms**. C'est exactement le point qui ne « casse » qu'en site (hydraulique/frottement/câble) et pas au banc (simu idéale). La cause est donc **plausible et cohérente avec le symptôme AX10→AX11**.

## 6. Variables de décision à lire (snapshot, `GVL_Troubleshooting`)

| Hypothèse | Variable à lire | Valeur attendue | Verdict | Fichier:ligne |
|---|---|---|---|---|
| Retour `CloseReached` latché stable | `GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx112_DeltaPosition_M` + `Idx102_BucketIsClosed` + `Idx111_BucketIsIntermediate` | stable ≥300 ms ; pas de clignotement IsClosed/IsIntermediate à la fermeture | **Si tremblotant en site → conforte** | `FB_Bucket.st:433/438/635` · `PRG_04:1775` |
| Sortie AX10 → AX10B retardée par disjonction | `G_CycleSemiAuto.Idx206_Step` (doit passer AX10→AX10B→AX11) | transition immédiate, pas de stationnement prolongé en AX10 | **Si Step reste en AX10 → conforte le trou** | `FB_CycleSemiAuto.st:1321-1325` |
| Plafond M2 P1 pendant transfert | `G_CycleSemiAuto.Idx308_M2SpeedStepApplied` / `Idx307_M1SpeedStepApplied` | M2=1 et M1=1 au transfert AX10B→AX11 ; sinon commande tombe à zéro | **Si M2/M1=0 au passage → conforte** | `FB_CycleSemiAuto.st:1352-1366` · `PRG_04:1307-1310` |
| Seuil `%` discontinu | `K_BenneOuvertureFermeture.Idx111` (IsIntermediate) | `IsIntermediate` stable, pas de rebond au franchissement | **Si rebond → conforte** | `FB_BucketCloseThreshold.st:106-110` |
| Qualité de la mesure | `F_HomingM2` / `E_HomingM1` / `K_BenneOuvertureFermeture.Idx116/117_M1/M2ReferenceMissing` | M1/M2 HomedAndReliable, pas de perte de référence en cours | **Si suspect/incohérent → aggrave** | `FB_Bucket.st:430-434` |
| Permis effectif close | `T_Permits.EffectivePermitBucket_Close` | reste vrai pendant la fermeture (sinon M2 ne bouge pas) | **Si tombe → autre cause** | `PRG_04:356` |

**⚠️ Gap d'acquisition** : `CloseReached` / `Benne_IsRoughlyClosed` / `BucketHandoffP1Active` **ne sont PAS** dans `troubleshooting_variables.txt` (seuls `Idx102/111/112`, `Idx206_Step`, `Idx307/308` le sont). Pour une preuve directe il faudrait ajouter ces 3 signaux à `GVL_Troubleshooting` + à la liste du snapshot (action à valider humainement, hors périmètre lecture seule).

**Conclusion** : l'hypothèse « retour benne fermée instable/tardif en site » est **plausible** et explique cohéremment le trou AX10→AX11 — à confirmer par un snapshot sur `K_BenneOuvertureFermeture.Idx112/102/111` + `G_CycleSemiAuto.Idx206`. Le point causal le plus probable : **la disjonction `Benne_IsClosed`/`Benne_IsRoughlyClosed` et le seuil `%` sont re-calculés à chaque scan sans confirmation temporelle ≥300 ms ; le latch `CloseReached` protège le banc mais masque la non-stabilité qui ne s'exprime qu'en site.**

## merge [completed]

# 🕵️ Synthèse des 4 branches — Trou AX10→AX11 en site

**Méthode** : analyse statique lecture seule (lecture de code réelle de `CODE/`), 4 branches indépendantes, chaque verdict étayé par `fichier:ligne` et la preuve de la lecture.

---

## 📌 Branche 1 — Transition de cycle AX10→AX11 (demandes treuils / état programme)

| Hypothèse | Variable de décision | Verdict | Preuve (lecture code) | Ligne |
|---|---|---|---|---|
| La transition laisse **les deux demandes programme** `WinchM1Cmd`/`WinchM2Cmd` à zéro | `WinchM1Cmd.RunRequest` / `WinchM2Cmd.RunRequest` | ✅ **CONFIRMÉE** (état volontaire de la phase benne — les deux demandes sont **volontairement nulles** pendant toute AX10/AX10B, pas un trou d'un scan) | `RunRequest:=FALSE; StepTgt:=0` simultanément sur M1 et M2 pendant AX10 **et** AX10B | `FB_CycleSemiAuto.st:1310-1311`, `:1342-1343` |
| Transfert atomique au scan du basculement | émission P1/P1 | ✅ **CONFIRMÉE** | publications `Step` au même scan que `State:=AX11` | `FB_CycleSemiAuto.st:1358-1359` |
| La transition laisse **les deux treuils physiques** à zéro (nominal) | `M2_SpeedStepApplied` (=`StepNumber` FB_WinchM2) / `BucketHandoffP1Active` | ❌ **ÉLIMINÉE en nominal** — M2 **est maintenu physiquement** par FB_Bucket via `ReqHoldAscentP1AfterClose` + routage prioritaire benne de l'arbitre M2 ; seul M1 chute | `FB_WinchCmdArbitrationM2.st:65-82`, gating `PRG_04:499-509`, `FB_Bucket.st:525-530` | `PRG_04:499-509`, `PRG_04_Treuils_Benne.st:1307-1310` |
| Le ~0,8 s observé = **gel AX10B→AX11 par le temps mort M1** | `M1FinalAscentStartReady` | 🎯 **ROOT CAUSE confirmée** — transfert gelé pendant la purge deadtime M1 ; M1 **réellement à zéro** pendant ce gel, M2 reste tenu | `M1AscentStartReady := interlock.Ready AND NOT RestartRequired AND NOT MotorRequest AND (DeadTimeElapsed ≥ T#700ms)` ; consommé au nœud de transfert | `PRG_06_Outputs.st:178-181`, `FB_CycleSemiAuto.st:1353` |
| Repli fallback : **les deux** treuils à zéro | `Ax10bFallbackStopActive` / `Ax10bHandoffWaitTimer.Q` (fenêtre 2 s) | ⚠️ **CONFIRMÉE en mode dégradé** — cas limite non nominal | timeout 2 s → `Hold:=FALSE` (M2 relâché) → les deux à zéro jusqu'à reprise AX12 | `FB_CycleSemiAuto.st:319-323`, `:1348-1351`, `:1367-1374`, `FB_Bucket.st:517` |

---

## 📌 Branche 2 — Barrière d'atomicité treuils M1/M2 (PRG_04)

| Hypothèse | Variable de décision | Verdict | Preuve (lecture code) | Ligne |
|---|---|---|---|---|
| La barrière d'atomicité neutralise **M1 ET M2** tant qu'ils ne sont pas prêts simultanément (déclencheur amont) | `WinchBothMotionActive` (@ transfert AX10B→AX11) | ✅ **CONFIRMÉE en statique** — repasse TRUE au scan du transfert | `WinchBothMotionActive := WinchM1Cmd.RunRequest AND WinchM2Cmd.RunRequest AND même sens` ; les deux `RunRequest`→1 au scan de transfert | `PRG_03_Modes_Cycle.st:342-345`, `FB_CycleSemiAuto.st:1358-1359` |
| **M1 pas prêt en montée** → M2 gélé → **les deux à zéro** | `instWinchM1.DirectionChangePending` / `instWinchM1.Fault.Latched` (TRUE à l'instant du trou) | ✅ **CONFIRMÉE** — chemin direct écrit noir sur blanc | §6-B gèle `ReqM2Winch:=0` si M1 non prêt | `PRG_04_Treuils_Benne.st:1499-1501` |
| Les deux retenus à zéro par la barrière finale | `NOT WinchBothMotionReady` (gate §7) | ✅ **CONFIRMÉE** | `WinchBothMotionReady := NOT(DirectionChangePending M1 ou M2) AND NOT(Fault.Latched M1 ou M2)` ; §7 zéro **les deux** vecteurs finaux, contacteurs & `Step` | `PRG_04:1405-1406`, `:1541-1542`, `PRG_04_Treuils_Benne.st:1661-1678`, `:1648-1656` |
| Vecteurs M1/M2 divergents (incohérence) | `WinchBothFinalRequestsCoherent` | ✅ **CONFIRMÉE comme condition complémentaire** (égalité stricte sens+palier+4 contacteurs exigée, sinon zéro couple) | §7 condition complète | `PRG_04_Treuils_Benne.st:1648-1656` |
| `M1AscentStartReady` **coupe** le transfert | `M1FinalAscentStartReady` | ⚠️ **GARDE, pas cause** — retarde ou bascule en repli `Ax10bFallbackStopActive`, ne zérose pas le couple | gate transfert + repli | `FB_CycleSemiAuto.st:1335,1353-1354`, `PRG_06_Outputs.st:178-181`, `:1347-1351` |
| La **purge** AX8..AX11 provoque le trou | `SyncOperationPermit` (FB_WinchSync) | ❌ **ÉLIMINÉE** — c'est un *soulagement* (évite blocage parasite), pas la cause | AX8/9/10/11 exclus ↔ reset inconditionnel FB_WinchSync | `PRG_04:426,442-445`, `FB_WinchSync:89-107`, `PRG_04:1103` |

---

## 📌 Branche 3 — Écart vitesse & surveillance AX11

| Hypothèse | Variable de décision | Verdict | Preuve (lecture code) | Ligne |
|---|---|---|---|---|
| L'écart **vitesse** M1/M2 déclenche un arrêt pendant AX11 | `SpeedMismatchActive` | ❌ **ÉLIMINÉE** — **désactivée à la source** : seuil et timeout câblés à 0 (`:246-247`) → le contrôle local G7 ne peut jamais s'armer | câblage PRG_03 `:=0.0` / `:=T#0ms` + gate strict `>0.0`/`>T#0ms` ; commentaire « Contrôle local G7 désactivé ; protections FB_WinchSync conservées » | `PRG_03_Modes_Cycle.st:246-247`, `FB_CycleSemiAuto.st:52-53,374-382` |
| Confirmation TON écart → repli AX_STAB en AX11 | `SpeedMismatchConfirmed` / `instCauses[2]` | ❌ **ÉLIMINÉE** (même raison : gate `Timeout>0` jamais vrai) | TON local + mapping causes | `FB_CycleSemiAuto.st:381-382,477,491` |
| **Position** M1/M2 hors seuil critique ≠ vitesse → blocage AX11 | `WinchSyncError` | ⚠️ **Cause plausible du trou** (mais = écart **position**, pas la branche vitesse) — exclu du repli AX_STAB, **retient AX11** par `AND NOT WinchSyncError`, abaisse `SpeedGuardReady` | seuil fault `CfgSyncCriticalToleranceM` (défaut 6,0 m) + **TON 800 ms** ; **sensible en site** (mou de câble, benne chargée, transitoire de décollement) que le banc idéal ne reproduit pas | `FB_SyncDeviation.st:95`, `PRG_04_Treuils_Benne.st:1949`, `FB_CycleSemiAuto.st:1399`, `PRG_04:1442,1510` |
| Config site ≠ banc (palier/distance AX11) | `CfgCtrlAscentMaxStep` (borné [1..2]) / `CfgCtrlAscentDistanceM` (défaut 2 m ; `SEL(≤0,2.0,..)`) | ❌ **NON cause** — modifie la durée/palier AX11, aucun arrêt possible | passage AX10B→AX11 direct si `CfgCtrlAscentDistanceM≤0` | `FB_CycleSemiAuto.st:338-339,1360-1366,1392-1404`, `PRG_03:286-287` |
| Étape réelle du trou (à confirmer terrain) | `CycleStep` / `CycleStepAtError` | ⏳ **À VÉRIFIER** en snapshot terrain | mapping étape | `FB_CycleSemiAuto.st:138-140` |

---

## 📌 Branche 4 — Retour fermeture benne & différence site/banc

| Hypothèse | Variable de décision | Verdict | Preuve (lecture code) | Ligne |
|---|---|---|---|---|
| Le retour « benne fermée » est **tardif/instable en site** → sortie AX10→AX10B retardée → commandes treuils à zéro pendant que la benne finit de se fermer | `Benne_CloseReached` / `Benne_IsClosed` / `Benne_IsRoughlyClosed` | ⚠️ **PLAUSIBLE** — cause **contributive** crédible : le retour `CloseReached` est un **latch stable** (`FB_Bucket.st:635`, ré-armé à chaque CmdOpen/Close, `:496/500`), **mais** la disjonction `IsClosed`/`IsRoughlyClosed` est **recalculée à chaque scan sur la mesure brute, sans debounce ≥300 ms** → tremblote (hydraulique/frottement/matière/câble) à la frontière `OffsetCloseM ± CoherenceLimitM` | sortie AX10 : condition EXIGE `Benne_CloseReached ∧ (Benne_IsClosed ∨ Benne_IsRoughlyClosed)` | `FB_CycleSemiAuto.st:1321-1325` ; `FB_Bucket.st:428,433,438` ; `PRG_04:1775,1823`, `PRG_03:263,266` |
| Plafond M2 en AX10 / raccordement AX10B dépendent de ce retour | `BucketAutoCloseActive` (Step=AX10 ∧ ReqClose) / `BucketHandoffP1Active` (Step=AX10B ∧ CloseReached ∧ ReqHold…) | ⚠️ **PLAUSIBLE** — si fermeture non confirmée, on reste en AX10 au lieu du raccordement ; `M2MaxStepUp:=1` seulement si `BucketHandoffP1Active` | gating séquentiel + arbitration M2 | `PRG_04:503-509`, `:1307-1310`, `FB_WinchCmdArbitrationM2:76-79` |
| Seuil « % » de fermeture discontinu | `IsIntermediate` / branche `FB_BucketCloseThreshold` | ⚠️ **PLAUSIBLE si rebond** (mesure qualifiée re-calculée chaque scan, non latched ; `Reached` discontinu scan à scan) | `FB_BucketCloseThreshold.st:106-110` | `FB_BucketCloseThreshold.st:106-110` |
| Qualité mesure / référence M1-M2 | `HomingM1/M2`, `ReferenceMissing` | ⚠️ **À VÉRIFIER** — défaut masqué au banc (simu idéale) | conditions géométriques sur Δ | `FB_Bucket.st:430-434` |

---

## 🎯 Conclusion — Cause la plus probable du trou AX10→AX11 en site

**Cause primaire la plus probable** (compatible avec le ~0,8 s observé) — branche **1/T3** :

> 🕐 Le creux se produit au **transfert AX10B→AX11**, gelé par le **temps mort M1 de 700 ms** : `M1FinalAscentStartReady := interlockM1.Ready AND NOT RestartRequired AND NOT MotorRequest AND (DeadTimeElapsed ≥ T#700ms)` (`PRG_06_Outputs.st:178-181`). Pendant ce gel, **M1 est réellement à zéro** (frein, aucune demande programme — les deux demandes sont volontairement nulles pendant AX10/AX10B, `FB_CycleSemiAuto.st:1310-1311,1342-1343`), tandis que **M2 reste tenu** par FB_Bucket (`ReqHoldAscentP1AfterClose` + arbitre prioritaire benne). Le transfert atomique P1/P1 n'est publié qu'au scan où M1 redevient Ready (`FB_CycleSemiAuto.st:1358-1359`). Ce mécanisme se confirme comme **ROOT CAUSE de l'ordre de grandeur (≈0,7–0,8 s)**.

**Causes contributives / aggravantes en site** (à croiser avec les traces snapshot avant de trancher) :

1. **Barrière d'atomicité** (branche 2) — `WinchBothMotionReady` + `WinchBothFinalRequestsCoherent` (`PRG_04_Treuils_Benne.st:1661-1678,1648-1656`) : si M1 est momentanément **non-prêt en montée** (`DirectionChangePending` ou `Fault.Latched`) ou les vecteurs divergents au scan du transfert, §6 (gel M2) **+ §7** zéro **les deux** treuils simultanément. **Non lisible en snapshot actuelle** (variables non exportées) → exige évolution diagnostique.
2. **Retour benne fermée tremblotant** (branche 4) — la disjonction `Benne_IsClosed`/`Benne_IsRoughlyClosed` sans debounce fait **retarder la sortie AX10→AX10B** quand Δ oscille à la frontière (hydraulique/frottement/câble, absent au banc) → commandes à zéro pendant fermeture.
3. **Écart de POSITION (pas vitesse)** (branche 3) — `WinchSyncError` (seuil critique 6,0 m / TON 800 ms) **retient l'étape en AX11** (`AND NOT WinchSyncError` à la transition, `FB_CycleSemiAuto.st:1399`), sensible au mou de câble/benne chargée **uniquement en site**.

**Exclusions fermes** : écart *vitesse* local (`SpeedMismatch*` désactivé, `PRG_03:246-247`), purge AX8..AX11 (soulagement), configs AX11 (non bloquantes), et « les deux treuils physiques à zéro en nominal » (M2 maintenu par la benne → **éliminé en nominal**, confirmé seulement en repli fallback dégradé).

**Variables de décision à lire au chantier (snapshot `GVL_Troubleshooting`)** : `G_CycleSemiAuto.Idx206_Step` / `Idx208_StepAtError` (étape exacte), `Idx307/308_M1/M2SpeedStepApplied` (en creux : Idx307→0, **Idx308 doit rester 1**), `Idx304_SpeedMismatchActive` (doit rester FALSE), `Idx306_WinchSyncError` (TRUE ⇒ cause position), `PRG_06_Outputs.Data.M1AscentStartReady` (vrai gate du ~0,8 s), `ReqProgram.ReqBucket.ReqHoldAscentP1AfterClose` (maintien M2).

**Réponse directe** : la branche « transition de cycle laisse les deux treuils à zéro » est **confirmée au niveau des demandes programme** (volontairement nulles pendant toute AX10/AX10B) et **éliminée au niveau physique en nominal** (M2 maintenu par la benne). Le **creux ~0,8 s** réellement observé en site est très probablement le **temps mort M1 de 700 ms** qui gèle AX10B→AX11 — M1 chute, M2 reste tenu — potentiellement aggravé par la barrière d'atomicité et/ou un retour benne-close instable.

## summary

合并结果：# 🕵️ Synthèse des 4 branches — Trou AX10→AX11 en site

**Méthode** : analyse statique lecture seule (lecture de code réelle de `CODE/`), 4 branches indépendantes, chaque verdict étayé par `fichier:ligne` et la preuve de la lecture.

---

## 📌 Branche 1 — Transition de cycle AX10→AX11 (demandes treuils / état programme)

| Hypothèse | Variable de décision | Verdict | Preuve (lecture code) | Ligne |
|---|---|---|---|---|
| La transition laisse **les deux demandes programme** `WinchM1Cmd`/`WinchM2Cmd` à zéro | `WinchM1Cmd.RunRequest` / `WinchM2Cmd.RunRequest` | ✅ **CONFIRMÉE** (état volontaire de la phase benne — les deux demandes sont **volontairement nulles** pendant toute AX10/AX10B, pas un trou d'un scan) | `RunRequest:=FALSE; StepTgt:=0` simultanément sur M1 et M2 pendant AX10 **et** AX10B | `FB_CycleSemiAuto.st:1310-1311`, `:1342-1343` |
| Transfert atomique au scan du basculement | émission P1/P1 | ✅ **CONFIRMÉE** | publications `Step` au même scan que `State:=AX11` | `FB_CycleSemiAuto.st:1358-1359` |
| La transition laisse **les deux treuils physiques** à zéro (nominal) | `M2_SpeedStepApplied` (=`StepNumber` FB_WinchM2) / `BucketHandoffP1Active` | ❌ **ÉLIMINÉE en nominal** — M2 **est maintenu physiquement** par FB_Bucket via `ReqHoldAscentP1AfterClose` + routage prioritaire benne de l'arbitre M2 ; seul M1 chute | `FB_WinchCmdArbitrationM2.st:65-82`, gating `PRG_04:499-509`, `FB_Bucket.st:525-530` | `PRG_04:499-509`, `PRG_04_Treuils_Benne.st:1307-1310` |
| Le ~0,8 s observé = **gel AX10B→AX11 par le temps mort M1** | `M1FinalAscentStartReady` | 🎯 **ROOT CAUSE confirmée** — transfert gelé pendant la purge deadtime M1 ; M1 **réellement à zéro** pendant ce gel, M2 reste tenu | `M1AscentStartReady := interlock.Ready AND NOT RestartRequired AND NOT MotorRequest AND (DeadTimeElapsed ≥ T#700ms)` ; consommé au nœud de transfert | `PRG_06_Outputs.st:178-181`, `FB_CycleSemiAuto.st:1353` |
| Repli fallback : **les deux** treuils à zéro | `Ax10bFallbackStopActive` / `Ax10bHandoffWaitTimer.Q` (fenêtre 2 s) | ⚠️ **CONFIRMÉE en mode dégradé** — cas limite non nominal | timeout 2 s → `Hold:=FALSE` (M2 relâché) → les deux à zéro jusqu'à reprise AX12 | `FB_CycleSemiAuto.st:319-323`, `:1348-1351`, `:1367-1374`, `FB_Bucket.st:517` |

---

## 📌 Branche 2 — Barrière d'atomicité treuils M1/M2 (PRG_04)

| Hypothèse | Variable de décision | Verdict | Preuve (lecture code) | Ligne |
|---|---|---|---|---|
| La barrière d'atomicité neutralise **M1 ET M2** tant qu'ils ne sont pas prêts simultanément (déclencheur amont) | `WinchBothMotionActive` (@ transfert AX10B→AX11) | ✅ **CONFIRMÉE en statique** — repasse TRUE au scan du transfert | `WinchBothMotionActive := WinchM1Cmd.RunRequest AND WinchM2Cmd.RunRequest AND même sens` ; les deux `RunRequest`→1 au scan de transfert | `PRG_03_Modes_Cycle.st:342-345`, `FB_CycleSemiAuto.st:1358-1359` |
| **M1 pas prêt en montée** → M2 gélé → **les deux à zéro** | `instWinchM1.DirectionChangePending` / `instWinchM1.Fault.Latched` (TRUE à l'instant du trou) | ✅ **CONFIRMÉE** — chemin direct écrit noir sur blanc | §6-B gèle `ReqM2Winch:=0` si M1 non prêt | `PRG_04_Treuils_Benne.st:1499-1501` |
| Les deux retenus à zéro par la barrière finale | `NOT WinchBothMotionReady` (gate §7) | ✅ **CONFIRMÉE** | `WinchBothMotionReady := NOT(DirectionChangePending M1 ou M2) AND NOT(Fault.Latched M1 ou M2)` ; §7 zéro **les deux** vecteurs finaux, contacteurs & `Step` | `PRG_04:1405-1406`, `:1541-1542`, `PRG_04_Treuils_Benne.st:1661-1678`, `:1648-1656` |
| Vecteurs M1/M2 divergents (incohérence) | `WinchBothFinalRequestsCoherent` | ✅ **CONFIRMÉE comme condition complémentaire** (égalité stricte sens+palier+4 contacteurs exigée, sinon zéro couple) | §7 condition complète | `PRG_04_Treuils_Benne.st:1648-1656` |
| `M1AscentStartReady` **coupe** le transfert | `M1FinalAscentStartReady` | ⚠️ **GARDE, pas cause** — retarde ou bascule en repli `Ax10bFallbackStopActive`, ne zérose pas le couple | gate transfert + repli | `FB_CycleSemiAuto.st:1335,1353-1354`, `PRG_06_Outputs.st:178-181`, `:1347-1351` |
| La **purge** AX8..AX11 provoque le trou | `SyncOperationPermit` (FB_WinchSync) | ❌ **ÉLIMINÉE** — c'est un *soulagement* (évite blocage parasite), pas la cause | AX8/9/10/11 exclus ↔ reset inconditionnel FB_WinchSync | `PRG_04:426,442-445`, `FB_WinchSync:89-107`, `PRG_04:1103` |

---

## 📌 Branche 3 — Écart vitesse & surveillance AX11

| Hypothèse | Variable de décision | Verdict | Preuve (lecture code) | Ligne |
|---|---|---|---|---|
| L'écart **vitesse** M1/M2 déclenche un arrêt pendant AX11 | `SpeedMismatchActive` | ❌ **ÉLIMINÉE** — **désactivée à la source** : seuil et timeout câblés à 0 (`:246-247`) → le contrôle local G7 ne peut jamais s'armer | câblage PRG_03 `:=0.0` / `:=T#0ms` + gate strict `>0.0`/`>T#0ms` ; commentaire « Contrôle local G7 désactivé ; protections FB_WinchSync conservées » | `PRG_03_Modes_Cycle.st:246-247`, `FB_CycleSemiAuto.st:52-53,374-382` |
| Confirmation TON écart → repli AX_STAB en AX11 | `SpeedMismatchConfirmed` / `instCauses[2]` | ❌ **ÉLIMINÉE** (même raison : gate `Timeout>0` jamais vrai) | TON local + mapping causes | `FB_CycleSemiAuto.st:381-382,477,491` |
| **Position** M1/M2 hors seuil critique ≠ vitesse → blocage AX11 | `WinchSyncError` | ⚠️ **Cause plausible du trou** (mais = écart **position**, pas la branche vitesse) — exclu du repli AX_STAB, **retient AX11** par `AND NOT WinchSyncError`, abaisse `SpeedGuardReady` | seuil fault `CfgSyncCriticalToleranceM` (défaut 6,0 m) + **TON 800 ms** ; **sensible en site** (mou de câble, benne chargée, transitoire de décollement) que le banc idéal ne reproduit pas | `FB_SyncDeviation.st:95`, `PRG_04_Treuils_Benne.st:1949`, `FB_CycleSemiAuto.st:1399`, `PRG_04:1442,1510` |
| Config site ≠ banc (palier/distance AX11) | `CfgCtrlAscentMaxStep` (borné [1..2]) / `CfgCtrlAscentDistanceM` (défaut 2 m ; `SEL(≤0,2.0,..)`) | ❌ **NON cause** — modifie la durée/palier AX11, aucun arrêt possible | passage AX10B→AX11 direct si `CfgCtrlAscentDistanceM≤0` | `FB_CycleSemiAuto.st:338-339,1360-1366,1392-1404`, `PRG_03:286-287` |
| Étape réelle du trou (à confirmer terrain) | `CycleStep` / `CycleStepAtError` | ⏳ **À VÉRIFIER** en snapshot terrain | mapping étape | `FB_CycleSemiAuto.st:138-140` |

---

## 📌 Branche 4 — Retour fermeture benne & différence site/banc

| Hypothèse | Variable de décision | Verdict | Preuve (lecture code) | Ligne |
|---|---|---|---|---|
| Le retour « benne fermée » est **tardif/instable en site** → sortie AX10→AX10B retardée → commandes treuils à zéro pendant que la benne finit de se fermer | `Benne_CloseReached` / `Benne_IsClosed` / `Benne_IsRoughlyClosed` | ⚠️ **PLAUSIBLE** — cause **contributive** crédible : le retour `CloseReached` est un **latch stable** (`FB_Bucket.st:635`, ré-armé à chaque CmdOpen/Close, `:496/500`), **mais** la disjonction `IsClosed`/`IsRoughlyClosed` est **recalculée à chaque scan sur la mesure brute, sans debounce ≥300 ms** → tremblote (hydraulique/frottement/matière/câble) à la frontière `OffsetCloseM ± CoherenceLimitM` | sortie AX10 : condition EXIGE `Benne_CloseReached ∧ (Benne_IsClosed ∨ Benne_IsRoughlyClosed)` | `FB_CycleSemiAuto.st:1321-1325` ; `FB_Bucket.st:428,433,438` ; `PRG_04:1775,1823`, `PRG_03:263,266` |
| Plafond M2 en AX10 / raccordement AX10B dépendent de ce retour | `BucketAutoCloseActive` (Step=AX10 ∧ ReqClose) / `BucketHandoffP1Active` (Step=AX10B ∧ CloseReached ∧ ReqHold…) | ⚠️ **PLAUSIBLE** — si fermeture non confirmée, on reste en AX10 au lieu du raccordement ; `M2MaxStepUp:=1` seulement si `BucketHandoffP1Active` | gating séquentiel + arbitration M2 | `PRG_04:503-509`, `:1307-1310`, `FB_WinchCmdArbitrationM2:76-79` |
| Seuil « % » de fermeture discontinu | `IsIntermediate` / branche `FB_BucketCloseThreshold` | ⚠️ **PLAUSIBLE si rebond** (mesure qualifiée re-calculée chaque scan, non latched ; `Reached` discontinu scan à scan) | `FB_BucketCloseThreshold.st:106-110` | `FB_BucketCloseThreshold.st:106-110` |
| Qualité mesure / référence M1-M2 | `HomingM1/M2`, `ReferenceMissing` | ⚠️ **À VÉRIFIER** — défaut masqué au banc (simu idéale) | conditions géométriques sur Δ | `FB_Bucket.st:430-434` |

---

## 🎯 Conclusion — Cause la plus probable du trou AX10→AX11 en site

**Cause primaire la plus probable** (compatible avec le ~0,8 s observé) — branche **1/T3** :

> 🕐 Le creux se produit au **transfert AX10B→AX11**, gelé par le **temps mort M1 de 700 ms** : `M1FinalAscentStartReady := interlockM1.Ready AND NOT RestartRequired AND NOT MotorRequest AND (DeadTimeElapsed ≥ T#700ms)` (`PRG_06_Outputs.st:178-181`). Pendant ce gel, **M1 est réellement à zéro** (frein, aucune demande programme — les deux demandes sont volontairement nulles pendant AX10/AX10B, `FB_CycleSemiAuto.st:1310-1311,1342-1343`), tandis que **M2 reste tenu** par FB_Bucket (`ReqHoldAscentP1AfterClose` + arbitre prioritaire benne). Le transfert atomique P1/P1 n'est publié qu'au scan où M1 redevient Ready (`FB_CycleSemiAuto.st:1358-1359`). Ce mécanisme se confirme comme **ROOT CAUSE de l'ordre de grandeur (≈0,7–0,8 s)**.

**Causes contributives / aggravantes en site** (à croiser avec les traces snapshot avant de trancher) :

1. **Barrière d'atomicité** (branche 2) — `WinchBothMotionReady` + `WinchBothFinalRequestsCoherent` (`PRG_04_Treuils_Benne.st:1661-1678,1648-1656`) : si M1 est momentanément **non-prêt en montée** (`DirectionChangePending` ou `Fault.Latched`) ou les vecteurs divergents au scan du transfert, §6 (gel M2) **+ §7** zéro **les deux** treuils simultanément. **Non lisible en snapshot actuelle** (variables non exportées) → exige évolution diagnostique.
2. **Retour benne fermée tremblotant** (branche 4) — la disjonction `Benne_IsClosed`/`Benne_IsRoughlyClosed` sans debounce fait **retarder la sortie AX10→AX10B** quand Δ oscille à la frontière (hydraulique/frottement/câble, absent au banc) → commandes à zéro pendant fermeture.
3. **Écart de POSITION (pas vitesse)** (branche 3) — `WinchSyncError` (seuil critique 6,0 m / TON 800 ms) **retient l'étape en AX11** (`AND NOT WinchSyncError` à la transition, `FB_CycleSemiAuto.st:1399`), sensible au mou de câble/benne chargée **uniquement en site**.

**Exclusions fermes** : écart *vitesse* local (`SpeedMismatch*` désactivé, `PRG_03:246-247`), purge AX8..AX11 (soulagement), configs AX11 (non bloquantes), et « les deux treuils physiques à zéro en nominal » (M2 maintenu par la benne → **éliminé en nominal**, confirmé seulement en repli fallback dégradé).

**Variables de décision à lire au chantier (snapshot `GVL_Troubleshooting`)** : `G_CycleSemiAuto.Idx206_Step` / `Idx208_StepAtError` (étape exacte), `Idx307/308_M1/M2SpeedStepApplied` (en creux : Idx307→0, **Idx308 doit rester 1**), `Idx304_SpeedMismatchActive` (doit rester FALSE), `Idx306_WinchSyncError` (TRUE ⇒ cause position), `PRG_06_Outputs.Data.M1AscentStartReady` (vrai gate du ~0,8 s), `ReqProgram.ReqBucket.ReqHoldAscentP1AfterClose` (maintien M2).

**Réponse directe** : la branche « transition de cycle laisse les deux treuils à zéro » est **confirmée au niveau des demandes programme** (volontairement nulles pendant toute AX10/AX10B) et **éliminée au niveau physique en nominal** (M2 maintenu par la benne). Le **creux ~0,8 s** réellement observé en site est très probablement le **temps mort M1 de 700 ms** qui gèle AX10B→AX11 — M1 chute, M2 reste tenu — potentiellement aggravé par la barrière d'atomicité et/ou un retour benne-close instable.
