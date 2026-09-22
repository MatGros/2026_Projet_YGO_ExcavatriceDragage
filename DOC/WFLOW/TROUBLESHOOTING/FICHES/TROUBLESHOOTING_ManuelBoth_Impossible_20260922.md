# 🕵️ Session de Troubleshooting — Boutons IHM « Both » (M1+M2) sans effet en manuel

> 📌 **Emplacement** : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_ManuelBoth_Impossible_20260922.md`
> 📅 Date : 2026-09-22 · 🧊 Situation : **[À PRÉCISER PAR L'EXPLOITANT — SIMULATION ou MACHINE]** · 📄 Statut : **[EN COURS]** (chaîne tracée sur source, mesures en ligne à relever)
> 🏷️ Acteur : DSH01 (orchestrateur, **read-only CODE/**) · Tâche : aucune (diagnostic ouvert) · Origine : demande exploitant urgente 2026-09-22

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte (verbatim exploitant)

> « Device.Application.GVL_IHM.Commun.BtnWinchBothDescent — Je commande les boutons both manu.
> `Device.Application.GVL_IHM.Modes.Cmd.SelJoystickWinch = 0`
> `Device.Application.GVL_IHM.Modes.Cmd.TglJoystickMaster = 0`
> Il me manque quoi pour pouvoir bouger les treuils en manu via IHM ? »

**Réglages opérateur annoncés** : `SelJoystickWinch = 0` (M1+M2 **couplés**) et `TglJoystickMaster = 0` (**boutons IHM**, joystick **pas** maître).

### ✅ Ces deux réglages sont CORRECTS — ce ne sont PAS la cause

| Réglage | Ce qu'il fait dans le code | Verdict |
|---|---|---|
| `TglJoystickMaster = 0` | `FB_WinchCmdArbitrationM1.st:68` `IF NOT TglJoystickMaster` → **branche « Mode Boutons IHM »**, où `BothIntent` est consommé (`:70-74`) | ✅ bon chemin |
| `SelJoystickWinch = 0` | `ST_ModesCmd.st:12` « 0 = M1+M2 couplés (nominal), 1 = M1 seul, 2 = M2 seul — **unitaires MAINT_N2 uniquement** » | ✅ cohérent avec une commande « both » |

## 2. 🎯 Symptôme

La commande « both » (montée ou descente des 2 treuils) émise depuis l'IHM **ne produit aucun mouvement**, en mode manuel, avec les réglages ci-dessus.

## 3. 🔗 Chaîne complète tracée sur source (producteur → routeur → consommateur)

```text
GVL_IHM.Commun.BtnWinchBothAscent / BtnWinchBothDescent      [IHM, ST_CommunHMI.st:37-38]
   ↓ PRG_03_Modes_Cycle.st:156-164   ← ⚠️ GATE DE MODE ICI
     WinchBothMotionActive := (direction <> 0) AND (Auth.Mode <> E_Mode.SEMI_AUTO)
   ↓ BothIntent (publié vers PRG_04)
   ↓ FB_WinchCmdArbitrationM1.st:68-87  (TglJoystickMaster=FALSE → branche boutons)
     ReqAscent/ReqDescend := BothIntent.*   ;   StepTgt := Cfg.BtnStepTgt
     Cfg.BtnStepTgt := 5  (PRG_04:523-524 → 100 % / palier max : OK)
   ↓ FB_WinchCmdArbitrationM1.st:116-125  RunRequest := …
     ⚠️ ET  BothDirectionAuthorized (:113-115) :
        = (ReqAscent) AND Context.M1AscentAllowed AND Context.M2AscentAllowed   ← LES DEUX !
   ↓ PRG_04:517-520   Context.MxAscentAllowed := EffectivePermitMx_Ascent
   ↓ PRG_04:1113-1114 EffectivePermitM1_Ascent := ProcessAndSafetyPermitM1_Ascent
                                               AND NOT SafeStopM1_Active
                                               AND (NOT CoupledBoth OR ProcessAndSafetyPermitM2_Ascent)
                       (et symétriquement pour M2)
   ↓ PRG_04:1095-1096 ProcessAndSafetyPermitMx_Ascent := ProcessPermitMx_Ascent AND SafetyPermitMx_Ascent
   ↓ PRG_04:1103/1105 CoupledBoth := instWinchSync.SyncActive OR WinchBothMotionActive
                      SafeStopM1_Active := SafeStopM1_Raw OR (CoupledBoth AND SafeStopM2_Raw)  ← CROISÉ
```

## 4. 🌳 Arbre des causes — ce qui peut manquer, par ordre de probabilité

| # | Condition manquante | Où | Variable à lire en ligne |
|---|---|---|---|
| **C1** | **Le mode n'est pas un mode manuel** : la commande est **inhibée en `SEMI_AUTO`** | `PRG_03:164` | `GVL_IHM.Modes.State.*` / `PRG_03_Modes_Cycle.Data.Auth.Mode` |
| **C2** | **Chaîne AU non armée** ⇒ `SafetyPermit` FALSE ⇒ **tous** les permis FALSE | `FB_Safety_Winch` (gate `Enable`) | état AU armé + `…PermitVisibility` |
| **C3** | **`SafeStop` sur l'AUTRE treuil** : en couplé, `SafeStopM2` coupe M1 (et réciproquement) | `PRG_04:1105` | `SafeStopM1_Active` / `SafeStopM2_Active` (publiés `PRG_04:1706-1707`) |
| **C4** | **Benne** : `BucketBusy` **ou** `WinchBothMotionBlockedByBucket` | `PRG_04:499` / `:396` | `instBucket.Lifecycle.Busy`, `WinchBothMotionBlockedByBucket` |
| **C5** | **Écart de synchronisme** bloquant | `PRG_04:511-512` | `SyncMinorDeviationBlocksUp` / `…Down` |
| **C6** | **Permis process** manquant (limites câble, butée, interlock axe) | `PRG_04:1095-1096` | `ProcessPermitMx_Ascent` |
| **C7** | **Un seul des deux permis** suffit à tout bloquer (atomicité) | `M1Arb:113-115` | `EffectivePermitM1_Ascent` **ET** `…M2_Ascent` |
| **C8** | Si **simulation** : chaîne AU **non refermable** ⇒ armer impossible ⇒ C2 | `T369` | `GVL_Simulation.SimChainOk` |

## 5. 🔑 Test décisif (2 minutes, en ligne CODESYS, sans modifier le code)

```text
1. LIRE LE MODE          Auth.Mode            → doit être MAINT_N1 (page 5) ou MAINT_N2 (page 4)
                                              → si SEMI_AUTO : CAUSE TROUVÉE (page IHM 1 ou après boot)
2. MAINTENIR la descente both et lire, DANS LE MÊME SCAN :
     EffectivePermitM1_Descend  ET  EffectivePermitM2_Descend   (les DEUX)
     → un seul FALSE = commande both JAMAIS émise (atomicité)
3. Si un permis est FALSE, DESCENDRE la chaîne :
     ProcessAndSafetyPermitMx  ←  ProcessPermitMx  +  SafetyPermitMx
     SafeStopMx_Active         (regarder AUSSI l'autre axe : croisement)
     BucketBusy / WinchBothMotionBlockedByBucket
     SyncMinorDeviationBlocksUp/Down
4. Si SafetyPermitMx = FALSE  →  état AU armé + chaîne fermée (C2/C8)
```

## 5bis. 🎯 INSTRUMENT DE LECTURE — checklist mouvement M1/M2 (c'est fait pour ça)

`ST_MotionChecklist.st:4` : *« Permet de voir en un coup d'œil pourquoi un ordre de mouvement ne fait pas coller les relais. »*
**À lire en ligne** : `GVL_Troubleshooting.N_MotionM1` (M1) et `GVL_Troubleshooting.O_MotionM2` (M2).

| Étape | Champ | Sens (source : DUT) |
|---|---|---|
| 1 | `Step1_PowerEngaged` | Contacteur principal sous tension — **« Armer puissance via Reset »** |
| 1bis | `HwIn_PowerContactorEngaged_DI`, `HwIn_BrakeIsOpen_DI`, `Cmd_BrakeRelease` | vérité terrain E/S + commande frein |
| 2 | `Step2_ModeAuthorized` | MAINT_N1 ou N2 actif — **✅ acquis (mode relevé = MAINT_N1)** |
| 3 | `Step3_NotBusyOtherTask` | pas d'autre séquence (Homing, benne, …) |
| 4 | `Step4_MotionRequested`, `RequestedDirection` (+1/−1/0), `RequestedSpeedPct` | demande active — **si IHM : `TglJoystickMaster` doit être à 0** |
| 5 | `Step5_NoSafetyFault` | pas de SafeStop ni AU actif sur l'axe |
| 6 | `Step6_DirectionAllowed` | sens autorisé (permis) |
| 7 | `Step7_BrakeReleased` | commande frein + retour frein OK |
| 8 | `Step8_OutputInterlockOk` / `_InterlockState` / `_InterlockReason` | barrière finale |
| bilan | **`AllConditionsMet`** | 🟢 TRUE ⇒ **les relais DOIVENT coller** |
| sortie | `RelayFwdActive`, `RelayRevActive`, `SpeedContactor1Active` | relais/contacteur réellement commandés |

**Méthode** : lire **de haut en bas, en maintenant le bouton** — **le premier FALSE est la cause**.

## 5ter. 🔎 Faits N1 établis sur source (et AUTOCORRECTION d'une piste)

| Fait | Preuve | Conséquence pour la commande « both » en N1 |
|---|---|---|
| En **N1 la synchro est IMPOSÉE**, non désactivable | `FB_WinchSync.st:118-119` (`SyncActive := TRUE`) | `CoupledBoth := SyncActive OR WinchBothMotionActive` (`PRG_04:1103`) **TRUE** ⇒ **atomicité + SafeStop croisé actifs** |
| Le blocage par **écart de synchro est BYPASSÉ** quand la commande both est active | `PRG_04:465-466` (`… AND NOT WinchBothMotionActive`) | ❌ **Piste « synchro » RÉFUTÉE pour les boutons both** (elle ne tient que pour les boutons **unitaires**) |
| `SafeStop` **croisé** | `PRG_04:1105` (`SafeStopM1_Active := SafeStopM1_Raw OR (CoupledBoth AND SafeStopM2_Raw)`) | un SafeStop sur **M2** bloque **M1** (et réciproquement) |
| **Un seul permis manquant bloque les DEUX** | `M1Arb:113-115` + `PRG_04:1113-1114` | il faut `EffectivePermitM1_*` **ET** `EffectivePermitM2_*` |
| Boutons **unitaires** = **N2 uniquement** | `ST_ModesCmd.st:12` | en **N1**, la commande unitaire n'est pas le chemin nominal ⇒ **utiliser les boutons « both »** (ce que fait l'exploitant) |
| Câblage `BothIntent` **sain** (aucune rupture) | `PRG_03:328-330` → `PRG_04:284-286`, `:535`, `:558` → `FB_WinchCmdArbitrationM1/M2` | la voie IHM → arbitrage est **complète** ; si rien ne bouge, c'est une **condition aval**, pas un câblage mort |

## 6. 🚨 Piège de mode par page IHM (vérifié sur source)

`PRG_03_Modes_Cycle.st:69-86` : le **changement de page IHM force le mode** :

| Page IHM | Mode forcé |
|---|---|
| **page 5** | `E_Mode.MAINT_N1` |
| **page 4** | `E_Mode.MAINT_N2` |
| **page 1** | `E_Mode.SEMI_AUTO` |
| *au boot PLC* | `SelMode := E_Mode.SEMI_AUTO` (`:75`) |

⇒ **Sur la page 1, ou juste après un boot, les boutons « both » ne peuvent rien faire** : la commande est inhibée par `Auth.Mode <> SEMI_AUTO` (`PRG_03:164`).

## 6bis. ✅ CAUSE RACINE TROUVÉE (finding exploitant, **vérifié sur source**)

**Symptôme** : boutons « both » M1+M2 sans effet en MAINT_N1/N2, alors que le mode, l'AU et les encodeurs sont corrects.
**Cause** : le **séquencement automatique de benne en pilotage couplé** est **actif par défaut** et **il bloque la commande both** tant que la benne n'est pas dans l'état requis.

### Chaîne complète (producteur → bloqueur → consommateur)

| Étape | Code | Contenu |
|---|---|---|
| 1 | `ST_CommunCfg.st:29` | `TglEnableCoupledBucketSequencing : BOOL := TRUE;` — **toggle IHM, ACTIF PAR DÉFAUT** |
| 2 | `PRG_04:315` | `ArbBucketContext.TglEnableCoupledBucketSequencing := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing;` |
| 3 | `FB_BucketCmdArbitration.st:49-53` | `WinchBothDiveBucketOpenArmed := TglEnableCoupledBucketSequencing AND (Mode <> SEMI_AUTO) AND NOT CoupledPhaseLocked AND MotionActive AND ReqDescend AND NOT BucketIsOpen;` |
| 4 | `PRG_04:396` | `WinchBothMotionBlockedByBucket := WinchBothDiveBucketOpenArmed AND NOT instBucket.Lifecycle.Busy;` |
| 5 | `PRG_04:510` | `ArbContext.WinchBothMotionBlockedByBucket := WinchBothMotionBlockedByBucket;` |
| 6 | `FB_WinchCmdArbitrationM1.st:118` / `M2:144` | `RunRequest := … AND NOT Context.WinchBothMotionBlockedByBucket …` ⇒ **RunRequest = FALSE** ⇒ **aucun mouvement** |

### Règle de conception à connaître (asymétrie)

| Commande | État de benne EXIGÉ | Preuve |
|---|---|---|
| **Descente** couplée | benne **OUVERTE** (`NOT BucketIsOpen` ⇒ armement du blocage) | `FB_BucketCmdArbitration.st:52` |
| **Montée** couplée | benne **FERMÉE** | `FB_BucketCmdArbitration.st:57` |

Relâchement prévu par conception : `CoupledPhaseLocked` (T248, `ST_Modes_Autorisations.st:22` — *« la perte de l'état ouvert/fermé en mouvement ne relance plus de blocage "descente/montée interdite" fantôme »*).

### 🔇 Ce blocage est SILENCIEUX — défaut réel à corriger

`FB_Hmi_BannerFormatter.st:727-756` porte la famille de messages **`[TREUIL] Descente/Montée interdite`** — mais **uniquement pour les refus de PERMIS** (chariot M3 pas à P1, limite légale, limite basse câble, mou de câble, treuil M1/M2, limite haute, capteur haut). **Aucun message ne couvre le refus par séquencement benne couplé** : l'opérateur voit un bouton inerte **sans aucune explication**. Même famille que le SafeStop de demande sans bandeau (§3ter) et que T369 (« abandons silencieux »).

### Instrument de contrôle en ligne

| Variable | Sens |
|---|---|
| `GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx204_CoupledDiveOpenArmed` | ouverture auto armée (descente couplée demandée, benne non ouverte) |
| `GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx104_AutoSeqActive` | séquencement auto en cours |
| `GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing` | **le toggle à désactiver pour retrouver le pilotage both « pur »** |

## 6ter. 🗺️ CARTE DES « AUTO » — piège de vocabulaire (vérifié sur source)

Le mot « benne auto » recouvre **plusieurs mécanismes distincts** dans ce projet. Confusion coûteuse : l'exploitant a cherché « le mode benne AUTO » alors que le bloqueur de la commande couplée est un **toggle précis**.

| # | Toggle / signal | Source | Défaut | Ce qu'il fait | Mode concerné |
|---|---|---|---|---|---|
| **1** | **`GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing`** | `ST_CommunCfg.st:29` | **TRUE** | **Benne auto en pilotage COUPLÉ** : descente → ouvre d'abord ; montée → ferme d'abord — **et bloque le mouvement both** tant que la benne n'est pas dans l'état requis | **MAINT_N1/N2, WinchSel=0** ← **cause du symptôme de cette fiche** |
| 2 | `Commun.Cfg.TglEnableKoboldAutoStopDescent` | `ST_CommunCfg.st:22` | **FALSE** | Arrêt automatique de la descente au contact du fond (Kobold) | tous modes (hors manche non neutre) |
| 3 | `M2TreuilBenne.Bucket.Cmd.TglEnableDumpAtTremie` | `ST_BucketCmd.st:21` | **FALSE** | Assistance **vidage à la trémie** (ouverture auto quand M3 est à la trémie) | manuel/MAINT |
| 4 | `CycleSemiAuto.Cmd.TglAutoDiveM2Step5Trial` | `ST_CycleCmd.st:15` | **FALSE** | Essai **T291-A** : M2 palier 5 en descente auto (M1 palier 4) — **non persisté** | **SEMI_AUTO** uniquement |
| 5 | `BucketAutoCloseActive` — **pas un toggle** | `PRG_04:503-505` | — | Fermeture auto de la benne **par le CYCLE** (AX10) + **plafond de palier M2** (`FB_WinchCmdArbitrationM2.st:78-79`) | **SEMI_AUTO uniquement** |
| 6 | `Commun.Cfg.TglEnableWinchDescentLock_M3` | `ST_CommunCfg.st:32` | **TRUE** | Verrou **descente treuils** si le pont M3 n'est pas à P1/Maintenance | MAINT |
| 7 | `ExtractionAssist` / `ExtractionControlActive` | `PRG_04:299-300`, `:588-605` | **retiré** | Assistance extraction = **legacy supprimée** (`ExtractionAssistActive := FALSE` en dur) ; ne subsiste que la phase « vitesse contrôlée » AX11 | — |

### 3 pièges à ne plus confondre
1. 🔴 Le **« benne auto » du cycle SEMI_AUTO (n°5)** n'est **pas** le toggle n°1 : il est **automatique dès que le mode est SEMI_AUTO**, **sans aucun interrupteur**, et il **plafonne le palier M2**.
2. 🟢 Le **n°1** n'agit **que** en **pilotage couplé `WinchSel=0` en N1/N2** — d'où des comportements différents selon mode et sélection.
3. 🟡 Le **n°3 (DumpAtTremie)** est une **autre** ouverture automatique (trémie), indépendante du n°1.

### Contrepartie du contournement (à assumer)
`OFF` = **comportement brut** : *« jamais gouverné par `instBucket.Busy` hors action MANUELLE benne (WinchSel=2) / DumpAtTremie / ExtractionAssist »* — donc **le PLC n'ouvre plus et ne ferme plus la benne tout seul** en couplé : c'est à l'opérateur de mettre la benne dans l'état voulu.

## 7. 🏁 Conclusion (mise à jour 2026-09-22T06:30)

**CAUSE RACINE TROUVÉE ET PROUVÉE SUR SOURCE** : la commande « both » M1+M2 était refusée parce que le **séquencement automatique de benne en pilotage couplé** est **actif par défaut** (`ST_CommunCfg.st:29`, `TglEnableCoupledBucketSequencing := TRUE`), que la benne n'était pas dans l'état exigé par le sens demandé (`FB_BucketCmdArbitration.st:49-58`), et que l'assistance armée **bloque alors le mouvement couplé** (`PRG_04:396` → `:510` → `FB_WinchCmdArbitrationM1.st:118` / `M2:144`) — **sans aucun message opérateur**.

| Élément | Statut |
|---|---|
| 🏆 **Origine de la cause** | **FINDING EXPLOITANT** (« il faut désactiver le mode benne auto ») — la fiche le crédite comme tel |
| ✅ **Vérification** | Chaîne de 6 maillons rejouée sur source par l'orchestrateur DSH01 ; 2 pistes concurrentes **réfutées** sur mesure (synchro imposée en N1 — bypassée en commande both ; « défaut qui coupe l'AU » — chaine fermée, aucun lockout) |
| 🔓 **Contournement immédiat** | Désactiver `TglEnableCoupledBucketSequencing` **ou** mettre la benne dans l'état requis **ou** atteindre `CoupledPhaseLocked` (T248) |
| 🛠️ **Correctif de fond** | **Tâche T375** (C3, contrat validé, agent principal en cours) : message opérateur **nommé** pour ce refus + une cause latchée **ne doit plus être masquée** par un témoin de validité + **garde-fou G524** anti-voie-de-blocage-silencieuse |
| ⚖️ **Reste à arbitrer par l'humain** | Défaut `TRUE` conservé (+ message) ou passé à `FALSE` en maintenance ; criticité C3 vs C4 du lot T375 |

## 8. ✅ Actions & suite

- [ ] Exploitant : relever le **mode** + les **4 permis effectifs** + `SafeStop*` + `BucketBusy` pendant l'appui (données du §5).
- [ ] Préciser **simulation ou machine** (change C8).
- [ ] Aucun code modifié (diagnostic **read-only**). Tout correctif éventuel sera **cadré en contrat** et **implémenté par un agent principal**, jamais par l'orchestrateur.
- [ ] Si la cause est une **commande légitimement inhibée** (mode/sécurité) → **pas de correctif** : c'est le comportement voulu, c'est l'IHM qu'il faut corriger.
