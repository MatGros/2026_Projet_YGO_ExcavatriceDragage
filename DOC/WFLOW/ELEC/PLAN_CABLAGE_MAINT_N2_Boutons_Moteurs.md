# 🪝 Plan technique unique — Câblage des 6 boutons moteur MAINT_N2 (M1/M2)

**Objet** : fusion des 3 rapports de trace (M1, M2, Both+séquencement benne) en UN plan de
câblage au niveau **variable/signal** des 6 boutons de commande moteur du mode MAINT_N2.
Toutes les preuves sont `fichier:ligne` sur la source active `CODE/*.st`
(hors `CODE_BACKUP/`, hors `Device.export`). Aucun code ne doit être inventé : le câblage
décrit quelles variables alimentent quels points d'injection, en conservant les gardes aval.

**Résumé en 1 phrase** : les 6 boutons moteur MAINT_N2 existent en IHM
(`GVL_IHM.MaintenanceN2.Cmd.*`) mais ne commandent **aucun** moteur aujourd'hui ; pour les câbler,
on les OR-résume, **gated par `Auth.Mode = E_Mode.MAINT_N2`**, sur les 3 canaux canoniques
existants : boutons unitaires M1 (point `PRG_04:492-493`), boutons unitaires M2
(point `PRG_04:494-495`), et intention both (point `PRG_03:156-159`).

---

## 1. Boutons ciblés (producteurs IHM)

Déclaration canonique — structure d'échange IHM `ST_MaintenanceN2HMI` :

| Bouton | Variable IHM complète | Type / commentaire |
|---|---|---|
| M1 Montée | `GVL_IHM.MaintenanceN2.Cmd.BtnM1Ascent` | `ST_MaintenanceN2Cmd.st:9` |
| M1 Descente | `GVL_IHM.MaintenanceN2.Cmd.BtnM1Descend` | `ST_MaintenanceN2Cmd.st:10` |
| M2 Montée | `GVL_IHM.MaintenanceN2.Cmd.BtnM2Ascent` | `ST_MaintenanceN2Cmd.st:11` |
| M2 Descente | `GVL_IHM.MaintenanceN2.Cmd.BtnM2Descend` | `ST_MaintenanceN2Cmd.st:12` |
| Both Montée | `GVL_IHM.MaintenanceN2.Cmd.BtnBothAscent` | `ST_MaintenanceN2Cmd.st:13` |
| Both Descente | `GVL_IHM.MaintenanceN2.Cmd.BtnBothDescend` | `ST_MaintenanceN2Cmd.st:14` |

Structuration `Cmd`/`State` : `ST_MaintenanceN2HMI.st:6-11`. L'état `ST_MaintenanceN2State`
ne porte que `Authorized` et `ActiveForcing` — **pas de `Mode`** (`ST_MaintenanceN2State.st:6-11`).

**⚠️ NOMENCLATURE VÉRIFIÉE (écart vs rapport M1)** : le chemin réel est
`GVL_IHM.MaintenanceN2.Cmd.BtnM1Ascent` (et non `GVL_IHM.MaintenanceN2Cmd.BtnM1Ascent`, ni
« `GVL_IHM.MaintenanceN2State.Mode` »). La porte de mode canonique est
`PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2` (cf. §5).

**🚨 RUPTURE COMMUNE (les 3 traces s'accordent)** : ces 6 boutons sont consommés **uniquement**
en diagnostic `ActiveForcing` (`PRG_07_Supervision.st:705-710`) — aucune occurrence dans le
chemin de commande `PRG_04`/`PRG_06`. **Ils ne commandent donc RIEN en sortie** : le câblage
ci-dessous est manquant, pas un forçage à lever.

---

## 2. Chaîne cible (ce que le câblage doit réutiliser intégralement)

```
Boutons MAINT_N2 (gated MAINT_N2)
   ▼
Canaux d'arbitrage existants (M1 unitaire / M2 unitaire / Both)
   ▼
FB_WinchCmdArbitrationM1/M2  → M1Logic* / M2Logic*  (PRG_04:541-544, 564-567)
   ▼
ReqM1Winch / ReqM2Winch       (PRG_04:1386-1418 / 1473-1493)
   ▼
FB_Winch instWinchM1/M2        (PRG_04:1457-1470 / 1523-…)
   ▼
WinchM1/M2FinalInterlockRequest (PRG_04:1593-1612 / 1614-…) → FB_WinchOutputInterlock
   ▼
PRG_06 : relais/paliers/frein + concordance M1/M2 + sorties physiques
          (PRG_06_Outputs.st:128-174, 305-384)
```

---

## 3. Câblage bouton par bouton

### 3.1 Boutons unitaires M1 — `BtnM1Ascent` / `BtnM1Descend`

- **Point d'injection exact** : entrée d'arbitrage `ArbIHM.BtnAscentM1` / `ArbIHM.BtnDescentM1`
  — `PRG_04_Treuils_Benne.st:492-493`.
- **Câblage variable/signal** (OR sur la source nominale boutons IHM `M1TreuilRetenue`), avec porte MAINT_N2 :

```
ArbIHM.BtnAscentM1  := GVL_IHM.M1TreuilRetenue.Cmd.BtnAscent
                       OR (Auth.Mode = MAINT_N2 AND GVL_IHM.MaintenanceN2.Cmd.BtnM1Ascent)
ArbIHM.BtnDescentM1 := GVL_IHM.M1TreuilRetenue.Cmd.BtnDescent
                       OR (Auth.Mode = MAINT_N2 AND GVL_IHM.MaintenanceN2.Cmd.BtnM1Descend)
```

- **Gardes conservées** (aval, non re-dérivées) :
  - Branche « Mode Boutons » M1 `FB_WinchCmdArbitrationM1.st:75-82` (BtnAscentM1→ReqAscent, palier `Cfg.BtnStepTgt`);
  - Gate `RunRequest` M1 `FB_WinchCmdArbitrationM1.st:116-125` : `NOT RequestConflict`, **`NOT Context.BucketBusy`**, `NOT WinchBothMotionBlockedByBucket`, `NOT SyncBlocks*`, homme-mort/neutre si joystick maître (ici `NOT TglJoystickMaster` ⇒ neutre), atomicité `BothDirectionAuthorized`;
  - Palier bouton = pleine vitesse : `ArbM1Cfg.BtnStepTgt := 5` (`PRG_04:523`);
  - Chaîne `ReqM1Winch` → `FB_Winch` (Enable = mode≠DISABLE ET NOT InhibitM1, `PRG_04:1458`, permits directionnels `:1462-1463`) → `WinchM1FinalInterlockRequest` (Enable, PowerContactorEngaged, SafeStop, permits, `PRG_04:1593-1612`) → `FB_WinchOutputInterlock` (gate `M1InterlockEnable`, `PRG_06:128-129`) → protecteurs/concordance (`PRG_06:305-366`) → `M1_BrakeRelease_RQ/M1_RelayAscent_RQ/M1_RelayDescent_RQ/M1_SpeedContactor_1..4_DQ` (`PRG_06:369-375`).

### 3.2 Boutons unitaires M2 — `BtnM2Ascent` / `BtnM2Descend`

- **Point d'injection exact** : entrée d'arbitrage `ArbIHM.BtnAscentM2` / `ArbIHM.BtnDescentM2`
  — `PRG_04_Treuils_Benne.st:494-495` (ou, en amont, la branche « Mode Boutons » de `FB_WinchCmdArbitrationM2.st:104-111`).
- **Câblage variable/signal** (symétrique M1, avec porte MAINT_N2) :

```
ArbIHM.BtnAscentM2  := GVL_IHM.M2TreuilBenne.Cmd.BtnAscent
                       OR (Auth.Mode = MAINT_N2 AND GVL_IHM.MaintenanceN2.Cmd.BtnM2Ascent)
ArbIHM.BtnDescentM2 := GVL_IHM.M2TreuilBenne.Cmd.BtnDescent
                       OR (Auth.Mode = MAINT_N2 AND GVL_IHM.MaintenanceN2.Cmd.BtnM2Descend)
```

- **Gardes conservées** : branche « Mode Boutons » M2 `FB_WinchCmdArbitrationM2.st:104-111`
  (`IHM.BtnAscentM2/BtnDescentM2`, palier `Cfg.BtnStepTgt`, `ArbM2Cfg.BtnStepTgt := 5` `PRG_04:524`) ;
  gate `RunRequest` M2 `FB_WinchCmdArbitrationM2.st:143-151` : `NOT RequestConflict`,
  **`NOT WinchBothMotionBlockedByBucket`**, `NOT SyncBlocks*` (synchro inversée),
  atomicité `BothDirectionAuthorized`. Chaîne `ReqM2Winch` → `FB_Winch instWinchM2` → `WinchM2FinalInterlockRequest` → `FB_WinchOutputInterlock` (gate `M2InterlockEnable`) → `M2_RelayAscent_Close_RQ/M2_RelayDescent_Open_RQ/M2_SpeedContactor_x_DQ/M2_BrakeRelease_RQ` (`PRG_06:378-384`).

### 3.3 Boutons Both — `BtnBothAscent` / `BtnBothDescend`

- **Point d'injection exact** : dérivation de l'intention both opérateur
  — `PRG_03_Modes_Cycle.st:155-165` (branche boutons IHM communs).
  Variable cible : `WinchBothMotionDirection` (`PRG_03:156-162`), publiée ensuite dans
  `Data.WinchBothIntent` (`PRG_03:328-330`).
- **Câblage variable/signal** (OR sur le bouton both nominal `GVL_IHM.Commun.BtnWinchBoth*`, avec porte MAINT_N2) :

```
WinchBothMotionDirection :=  1 si (GVL_IHM.Commun.BtnWinchBothAscent  OR (MAINT_N2 AND BtnBothAscent))
                          : -1 si (GVL_IHM.Commun.BtnWinchBothDescent OR (MAINT_N2 AND BtnBothDescend))
                          :  0 sinon
```

- **⚠️ NE PAS réinjecter en parallèle dans `ArbIHM.BtnAscentM1 + BtnAscentM2` (`PRG_04:492-495`)** :
  ce chemin est **unitaire** et perdrait l'atomicité both (`BothDirectionAuthorized`) et la
  protection `RequestConflict` (cf. `FB_WinchCmdArbitrationM1 :113-115`).
- **Gardes conservées** : `WinchBothMotionActive := (Direction≠0) AND NOT SEMI_AUTO`
  (`PRG_03:163-164`) ; gate both dans M1/M2 (`BothIntent.Active` → `BothIntent.*` + palier,
  `FB_WinchCmdArbitrationM1:70-74/94-98`, `M2:99-103/123-127`) ; `WinchBothMotionBlockedByBucket`
  gate M1 `FB_WinchCmdArbitrationM1:118` **et** M2 `M2:144` ; `WinchBothReq*→instBucket` pour
  l'auto-séquencement benne (`PRG_04:284-286`, `PRG_04:353-354`).

---

## 4. Interaction avec le séquencement benne (les 3 traces)

### 4.1 La règle absolue both (benne)
Descente `only` benne ouverte / montée `only` benne fermée → `FB_BucketCmdArbitration`
`_bucketopen/close` : `FB_BucketCmdArbitration.st:49-58`.

Armement (bit-identique) :
```text
WinchBothDiveBucketOpenArmed := TglEnableCoupledBucketSequencing AND Mode≠SEMI_AUTO
                                AND NOT CoupledPhaseLocked AND MotionActive AND ReqDescend
                                AND NOT BucketIsOpen
WinchBothAscentBucketCloseArmed := idem avec ReqAscent AND NOT BucketIsClosed
```
Sources : `FB_BucketCmdArbitration.st:49-58` ; toggle `TglEnableCoupledBucketSequencing`
(`PRG_04:315`, défaut TRUE `ST_CommunCfg`).

### 4.2 Refus silencieux dans MAINT_N2 — OUI
`instArbBucket` est appelé inconditionnellement (`PRG_04:323-329`), `Mode<>SEMI_AUTO` est vraie
en MAINT_N1/N2. Résultat :
```text
WinchBothMotionBlockedByBucket := WinchBothDiveBucketOpenArmed AND NOT instBucket.Lifecycle.Busy   // PRG_04:396
→ gate RunRequest M1 (FB_WinchCmdArbitrationM1:118) et M2 (FB_WinchCmdArbitrationM2:144) → FALSE
```
Donc en MAINT_N2, monter/descendre en **both** avec la benne dans le mauvais état **bloque
silencieusement** les deux treuils — c'est la défense en profondeur à conserver.

### 4.3 Asymétrie M1 vs M2 (écart entre les traces M1 et M2 — rupture à signaler)
- Gate M1 : `NOT Context.BucketBusy` **présent** (`FB_WinchCmdArbitrationM1:117`).
- Gate M2 : **aucun** `NOT Context.BucketBusy` — M2 s'appuie sur l'override benne
  `FB_WinchCmdArbitrationM2:65-82` (qui ne prend effet QUE si `WinchSel=2` OU `SEMI_AUTO`).
  Conséquence : un **bouton unitaire M2** câblé en §3.2 peut générer une demande de mouvement
  alors que `Lifecycle.Busy` est vraie (hors jog/SEMI_AUTO), contrairement à M1. À cadrer côté
  maintenance : soit accepter l'asymétrie, soit ajouter une garde équivalente `NOT BucketBusy`.

### 4.4 Subtilité déterminante du câblage Both par bouton (écart joystick vs bouton)
Le séquencement benne **joystick** fonctionne car `FB_Modes` force
`JoystickWinchSelectArbitrated := 2` (jog benne) pendant ouverture/fermeture, **MAIS uniquement
sur déflexion du manche** (`JoystickPull XOR JoystickPush`) :
```text
CoupledBucketSeqEnable AND (JoystickWinchSelectRequest = 0) AND (JoystickPull XOR JoystickPush)  // FB_Modes.st:375-377
```
Un appui sur `BtnBoth*` **ne déflecte pas le manche** ⇨ `JoystickWinchSelectArbitrated` reste à 0
⇒ la benne n'est **pas auto-conduite** à l'état requis, et le mouvement both est simplement
**bloqué** par `WinchBothMotionBlockedByBucket` (refus silencieux, aucune correction automatique).
C'est le point d'interaction clé entre les trace M1/M2 (arbitrage) et le trace both (séquenceur).

---

## 5. Gardes communes à conserver (plancher final — non négociable)

| Garde | Source | Effet en MAINT_N2 |
|---|---|---|
| Porte de mode MAINT_N2 sur l'injection | `PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2` (`PRG_06:320-325`, `PRG_07:704`) | seul le MAINT_N2 active ces boutons (sinon OR permanent) |
| Homme-mort / neutre joystick | `FB_WinchCmdArbitrationM1:121,124` / `M2:147,150` | neutre ici (mode boutons, `NOT TglJoystickMaster`) |
| Anti-conflit sens `RequestConflict` | `M1:112` / `M2:139` | jamais montée+descente simultanées |
| Atomicité both `BothDirectionAuthorized` | `M1:113-115` / `M2:140-142` | départ jamais isolé |
| Anti-redémarrage `RestartInhibit` | `FB_WinchOutputInterlock.st` | pas de redémarrage auto après défaut |
| Temps mort directionnel DeadTime | `FB_WinchOutputInterlock.st` | 500/700 ms directionnel |
| Plancher de palier | `FB_WinchOutputInterlock.st` | +1 cran / 400 ms |
| Coupure dure `PowerCutOff` / `PowerContactorEngaged` / `SafeStop` | `FB_WinchOutputInterlock.st`, `PRG_06:128-129,152-153` | chaîne AU + puissance avant tout mouvement |
| Concordance contacteurs M1/M2 | `PRG_06:341-366` | anti-désynchronisation câbles |
| Frein non desserré sans sens validé | `PRG_06:307-308, 320-331` | `M1BrakeCmd := M1RelayFwd OR M1RelayRev`, forçage N2 strictement borné |

---

## 6. Ruptures & contradictions entre les traces

| # | Rupture / contradiction | Preuve | Résolution |
|---|---|---|---|
| R1 | Nomenclature du rapport M1 erronée (`GVL_IHM.MaintenanceN2Cmd…`, `…MaintenanceN2State.Mode`) | chemin réel `GVL_IHM.MaintenanceN2.Cmd.*` (`ST_MaintenanceN2HMI.st:8`) ; `ST_MaintenanceN2State` sans champ `Mode` | utiliser `GVL_IHM.MaintenanceN2.Cmd.*` + porte `Auth.Mode` (`PRG_06:320`, `PRG_07:704`) |
| R2 | Boutons moteur MAINT_N2 non câblés (0 consommateur commande) | seuls `PRG_07_Supervision.st:705-710` (diag `ActiveForcing`) | le câblage §3 est à créer (aucun conflit d'écriture) |
| R3 | Asymétrie garde `BucketBusy` M1/M2 | M1 `FB_WinchCmdArbitrationM1:117` vs M2 pas de clause | §4.3 — à cadrer |
| R4 | Both bouton vs joystick : le séquencement T248 ne s'arme pas sur bouton | `FB_Modes.st:375-377` exige `JoystickPull XOR JoystickPush` | §4.4 — refus silencieux, pas de correction benne |
| R5 | Point d'injection Both : injecter dans `GVL_IHM.Commun.BtnWinchBoth*` directement risquerait d'écraser une entrée IHM | `PRG_03:156-159` lit la GVL ; `PRG_04:496-497` la re-routage (legacy) | injecter **en amont du calcul** de `WinchBothMotionDirection` (`PRG_03:156-162`), en OR avec porte MAINT_N2 |
| R6 | `ArbIHM.BtnWinchBothAscent/Descent` (`PRG_04:496-497`) non consommés par le FB (le both passe par `BothIntent`) | `FB_WinchCmdArbitrationM1:70-74` ; `ST_fbWinchCmdArbitration_IHM.st:19-20` | ne **pas** se brancher ici pour le both |

---

## 7. Synthèse des points d'injection (uniquement ces 5 lignes logiques)

| Bouton | Point d'injection | Fichier:ligne |
|---|---|---|
| BtnM1Ascent / BtnM1Descend | `ArbIHM.BtnAscentM1 / BtnDescentM1` | `PRG_04_Treuils_Benne.st:492-493` |
| BtnM2Ascent / BtnM2Descend | `ArbIHM.BtnAscentM2 / BtnDescentM2` | `PRG_04_Treuils_Benne.st:494-495` |
| BtnBothAscent / BtnBothDescend | `WinchBothMotionDirection` (amont de `Data.WinchBothIntent`) | `PRG_03_Modes_Cycle.st:155-165` |

Chaque câblage est un **OR résumé sur la source nominale existante**, gardé par
`PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2`, et réutilise **intégralement** la chaîne
aval (arbitrage → FB_Winch → interlock final → PRG_06). Aucune nouvelle garde à inventer.

---

## 8. Décisions de cadrage humain actées (2026-09-22, orchestrateur DSH01)

| # | Point cadré | Décision | Preuve / renvoi |
|---|---|---|---|
| **D1** | Plancher de sécurité des 6 boutons | **gate MAINT_N2 + chaîne AU fermée + barrière finale existante** ; NI homme-mort NI garde frein-seul supplémentaires, NI zéro-interlock | décision exploitant (choix unique) |
| **D2** | Modification | **patch limité** : uniquement les 5 lignes logiques §7, réutilisation de la chaîne existante, **aucun refactor** | décision exploitant |
| **D3** | Both & séquencement benne (R4) | **Both soumis à `WinchBothMotionBlockedByBucket`** — refus silencieux traité par T375 (message opérateur). Aucune dérogation au séquencement. | décision exploitant |
| **D4** | Asymétrie `BucketBusy` M1/M2 (R3) | **NON tranchée ici** — relève de **T354** (tâche ouverte DSH20, en attente d'arbitrage humain O1/O2/O3 + alerte §11.2 « état Busy collé »). Le câblage §3 conserve le comportement de gate existant de chaque axe **sans le modifier** (M1 porte `NOT BucketBusy`, M2 non). | `TROUBLESHOOTING_T354_ASYMETRIE_GARDE_M1_M2_20260921.md` — asymétrie NON SOURCÉE ; T354 porte l'arbitrage |
| **D5** | Porteur d'implémentation | **DSH30** — détenteur du verrou T374 (phase read-only en cours). L'implémentation ne s'ouvre qu'après remise de DSH30 **et** validation humaine de ce plan (C4). | verrou T374/DSH30 |
| **D6** | Historique "fonctionnaient avant" | REFUTÉ pour ce dépôt : les 6 boutons n'ont jamais commandé un moteur ici (git `3de7547f` = préparation structure « sans toucher aux sorties »). Le câblage est à créer, pas à restaurer. | `git log -S "BtnM1Ascent"` → `3de7547f` |

**Condition de démarrage du lot code (C4)** : ce plan validé humainement + remise de l'analyse des conditions de DSH30 (`BRIEF_T374_DSH_CONDITIONS_EXISTANTES.md`) + GO humain explicite. Aucune ligne de `CODE/` avant cela.
