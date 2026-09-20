# 🕵️ Session de Troubleshooting — T338 — Position M2 figée sous commande + saut post-AU

> 📅 Date : 2026-09-20 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : **DIAGNOSTIC CLOS · CORRECTIF APPLIQUÉ (Phase 2) — recette humaine en attente**
> 🔒 Tâche : `T338` (C1) · 🏷️ Acteur : `DSH10` · 🔍 Mode : read-only `CODE/` (zéro correctif en Phase 1)
> 📥 Preuves d'entrée : snapshots `GVL_Troubleshooting` (536/536) du 2026-09-20 — voir §6.

---

## 1. 🧊 Contexte figé (horodaté)

**Situation** : banc en **SIMULATION** (`A_ContexteMachineGlobal.Idx102_SimulationEnabled = TRUE`), mode `E_Mode.SEMI_AUTO`, cycle auto en cours sur `E_AutoCycleStep.AX3_OPEN_BUCKET`. M1, contacteurs, homme-mort, contacteurs de direction et de vitesse **fonctionnels et synchronisés**. Le défaut est **strictement localisé à M2**.

**Snapshot de référence (incident n°2)** : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/snapshot/Snapshot_Troubleshooting_20260920_172509.csv` (17:25:09).

| Élément | Variable complète | Valeur | Horodatage |
|---|---|---|---|
| Position BRUTE M2 (image HwIn) | `GVL_Troubleshooting.B_Inputs.Winch.COD2_PosValue` | **UDINT#0** | 17:25:09 |
| Vitesse brute M2 (PDO CoE) | `GVL_Troubleshooting.B_Inputs.Winch.COD2_SpdValue` | **DINT#-525** | 17:25:09 |
| Position brute vue par l'encodeur M2 | `J_LevageUnitaireM2.Inputs_100.Idx101_EncoderRawPos` | **DINT#0** | 17:25:09 |
| Position M2 exposée | `H_LevageSynchroniseM1M2.Idx102_M2_CablePos_M` | **REAL#23.5** (figée) | 17:25:09 |
| Position BRUTE M1 (comparatif) | `B_Inputs.Winch.COD1_PosValue` | UDINT#420536 | 17:25:09 |
| Position M1 exposée | `I_LevageUnitaireM1.Inputs_100.Idx102_CablePos_M` | REAL#8.5 | 17:25:09 |
| Vitesse brute M1 | `B_Inputs.Winch.COD1_SpdValue` | DINT#0 | 17:25:09 |
| Commande M2 | `O_MotionM2.RelayRevActive` / `SpeedContactor1Active` | TRUE / TRUE | 17:25:09 |
| Consigne M2 | `J_LevageUnitaireM2.Demandes_200.Idx208_ArbitratedSpeed_Pct` | REAL#80 (palier 4) | 17:25:09 |
| Frein M2 | `J_...M2.Control_400.Idx404_BrakeReleaseAuthorized` | TRUE | 17:25:09 |
| Référence M2 | `F_HomingM2.HomingHomed` / `HomingSuspect` | **TRUE / FALSE** | 17:25:09 |
| Défaut codeur M2 | `J_...M2.Safety_300.Idx311_ErrorEncoder` | **FALSE** | 17:25:09 |
| Absence de mouvement M2 | `J_...M2.Safety_300.Idx320_ErrorNoMovement` | **FALSE** | 17:25:09 |
| État benne | `K_...Idx101_BucketIsOpen` / `Idx102_BucketIsClosed` | FALSE / **TRUE** | 17:25:09 |
| Écart M2−M1 | `K_...Idx103_OffsetPos_M` / `Idx112_DeltaPosition_M` | REAL#15 / REAL#15 | 17:25:09 |

**Valeurs dérivées (arithmétique vérifiée, `FB_Encoder_Scale.st:34-38` : `CablePosM = (DINT(RawPos) − DINT(HomingRefRaw)) × 2.0/8192`, soit `/4096`)** :

| Grandeur | Calcul | Valeur |
|---|---|---|
| `HomingRefRaw` M2 (17:25) | `0 − 23.5×4096` | **−96 256 pts** (UDINT `4 294 932 480`) |
| `HomingRefRaw` M1 (17:25) | `420 536 − 8.5×4096` | 385 720 pts |
| Vitesse M2 reconstruite | `−525 × 0.1 × 2.0 / 60` (`FB_Encoder_SpeedMeasure.st:49`) | **−1,75 m/s** (descente pleine) |

**Deux snapshots supplémentaires exploitables** (mêmes variables) :

| Snapshot | COD1_PosValue (M1) | M1_CablePos_M | COD2_PosValue (M2) | M2_CablePos_M | `HomingRefRaw` M2 déduit |
|---|---|---|---|---|---|
| `..._165459.csv` (16:54:59) | 693 850 | −1.3671875 | 517 287 | 0.298583984 | 516 064 |
| `..._172509.csv` (17:25:09) | 420 536 | 8.5 | **0** | **23.5** | **−96 256** |
| `..._174333.csv` (17:43:33) | 343 667 | 7.859619 | 1 039 975 | 8.845459 | **1 003 744** |

⚠️ À 17:43:33 : `1 003 744 = 1 100 000 − 96 256 = CST_M2EncoderInitialRaw − 23,5 m×4096` — **valeur non fortuite, voir §6/§7**.

---

## 2. 🎯 Symptôme

**S1** : sous commande de descente/ouverture active (contacteurs de sens + palier + frein desserré, `RelayRevActive = TRUE`), la position M2 **brute** (et donc la position exposée) **reste figée** à 23,5 m, tandis que la **vitesse brute CoE** continue de publier −525 (soit −1,75 m/s) — **sans aucun défaut** (`ErrorEncoder = FALSE`, `ErrorNoMovement = FALSE`, `HomingSuspect = FALSE`). Conséquence : l'écart M2−M1 se fige à 15,0 m = `OffsetCloseM` → benne vue « fermée » à jamais, ouverture impossible.

**S2** : après arrêt d'urgence + réarmement, M2 **saute** d'une valeur de l'ordre de 8,50 m à **204,677 m**, `Homed` restant **TRUE** et `HomingSuspect` **FALSE**.

**Caractère** : reproductible (2 fois le 2026-09-20), et **structurel** (voir §7 : le seuil est atteint par simple cumul de descente).

---

## 3. 🧩 Indices / historique

- **Déjà rencontré** (utilisateur) : « en triturant un peu le programme on se retrouve complètement bloqué avec le simulateur ».
- **Récupération observée** : levée **uniquement** par un cycle complet (sortie simulation → retour simulation → plusieurs AU), jamais par une action isolée → signature d'un **état de banc non rejoué**, pas d'une corruption matérielle.
- **Changements récents** : `T328` (couplage mécanique M1/M2), `T300-P-A` (refonte `FB_SimBench` M3), `T314` (parité SimBench). Les snapshots 16:54 / 17:25 / 17:43 encadrent ces travaux.
- **Alarmes** : aucune (`ErrorEncoder`, `ErrorNoMovement`, `HomingSuspect`, `BucketFaultActive` tous à FALSE au 17:25:09).
- **Effet de bord 120 %** : `BucketOpening_Pct = 100 × (OffsetCloseM − Delta) / (OffsetCloseM − OffsetOpenM)` (`FB_Bucket.st:650-655`), avec `OffsetOpenM = 0.0` / `OffsetCloseM = 15.0` (`GVL_PERSISTENT.st:64-82`) → **120 % ⟺ Delta = M2−M1 = −3,0 m**, c'est-à-dire M1 **3 m au-dessus** d'un M2 figé. Non bornage **volontaire et documenté** (`FB_Bucket.st:645-648`, `ST_BucketHMIState.st:23`) : le 120 % est bien un **signal de diagnostic**, pas un défaut propre.

---

## 4. 🌳 Arbre des causes & hypothèses (exhaustif)

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| H1 | **(a)** `FB_SimBench` ne produit pas de position valide pour M2 | `B_Inputs.Winch.COD2_PosValue` (sortie directe de `instSimEncoderM2.RawPosOut`, `FB_SimBench.st:492`) | 0 si le modèle codeur est en butée basse (`FB_Sim_Encoder.st:128-133`) | **0** | ✅ **CONFIRMÉ** |
| H2 | **(b)** la valeur SimBench n'atteint pas HwIn (routage simulation) | `HwIn.Winch.COD2_PosValue` → `HwInM2.RawPosIn` → image diag `J_...Idx101_EncoderRawPos` | = valeur publiée par le banc | **0 = 0**, routage intact (`FB_TroubleshootingView.st:245`, `PRG_02:642`) | ❌ **RÉFUTÉ** |
| H3 | **(c)** HwIn reçoit la fréquence mais `FB_Encoder` n'intègre pas la position (bug commun M1/M2) | `FB_Encoder_Abs.st:116-120` + `FB_Encoder_Scale.st:34-38` | copie directe du PDO puis conversion linéaire | reçoit **0** → expose **23,5 m** = exactement `(0−(−96 256))/4096` | ❌ **RÉFUTÉ** (voir note ci-dessous) |
| H4 | La vitesse non nulle prouve que le codeur tourne, donc la position devrait bouger | `FB_Encoder_SpeedMeasure.st:18/49` | hypothèse implicite **fausse** : la vitesse ne vient **pas** de la position | vitesse = objet CoE `0x6031:01` **indépendant** du PDO position | ❌ **RÉFUTÉ** (prémisse invalide) |
| H5 | **Pollution RETAIN** `FB_Encoder_Homing.st:286` = cause du **saut** S2 | `Calib.LastKnownRawPos` | s'il alimentait `CablePosM` | **consommé nulle part ailleurs** que `FB_Encoder_Homing.st:183` (grep exhaustif `CODE/`) | ❌ **RÉFUTÉ comme cause du saut** |
| H6 | **Pollution RETAIN** `FB_Encoder_Homing.st:286` = cause de l'**aveuglement** (aucune alerte) | `Calib.LastKnownRawPos` + `InitDone` | un saut doit armer `HomingSuspect` | mémoire **rafraîchie en continu** (`:286`) **et** contrôle exécuté **une seule fois par session** (`:181-190`, `InitDone` jamais réarmé car `Enable := TRUE` constant `PRG_02:594/649`) | ✅ **CONFIRMÉ (aveuglement)** |
| H7 | Transaction de homing invalide mais validée | `FB_Encoder_Homing.st:230` → `:243` → `:249` | le readback doit prouver un déplacement réel | `PendingHomingRefRaw = RawPos − TargetPoints` **puis** `CandidateRawDiff = RawPos − PendingHomingRefRaw ≡ TargetPoints` → `ReadbackOk` **toujours TRUE sur un raw figé** | ✅ **CONFIRMÉ (vérification circulaire)** |
| H8 | Le garde-fou « absence de mouvement » aurait dû alarmer | `FB_Safety_Winch.st:437-443` | armé sous commande + frein desserré + codeur dispo | **inhibé** : `NOT RefWindowActive AND NOT BenneBusy`, or `CrossCheckEnable := SyncOperationPermit` = **FALSE pendant toute manipulation benne** (`PRG_04:415-424`, `:990`) → `RefWindowActive` TRUE (`FB_Safety_Winch.st:248-249`) | ✅ **CONFIRMÉ (garde-fou muet en condition d'usage)** |
| H9 | Init de simulation partiellement ratée (ré-init du raw) | `FB_SimBench.st:273-280` | un raw persistant non nul doit être **conservé** | `IF RawPosM2 = 0 THEN RawPosM2 := CST_M2EncoderInitialRaw` → **ré-injection de 1 100 000 pts** après un cycle simulation OFF/ON | ✅ **CONFIRMÉ (prouvé par la référence du 17:43)** |
| H10 | `FB_Encoder_Safety` borne la position affichée | `FB_Encoder_Safety.st:70/80` | bornes ±99 m appliquées à la mesure transmise | `CablePosMSafe := CablePosM` **sans bornage** ; les bornes n'alimentent que `Fault.Error` (`:53`, `:81`) | ✅ **CONFIRMÉ** : 23,5 m et 204,677 m sont transmissibles tels quels |
| H11 | Bug matériel / bus M2 (EtherCAT, esclave) | `instDiagEthercat.DeviceEncoderM2.Operational`, `COD2_Alarms` | 0 alarme, esclave opérationnel | `COD2_Alarms = 0`, `DeviceState = RUNNING`, `EncoderAvailable = TRUE` | ❌ **RÉFUTÉ** |

### ⚠️ Note H3 — la prémisse « FB_Encoder intègre la position depuis la fréquence » est **fausse par construction**

`FB_Encoder_Abs.st:116-120` recopie le PDO position **tel quel** (`RawPos := RawPosIn;`), sans aucune intégration. Il n'existe **aucun** `Pos += Spd×dt` dans la chaîne codeur. Position et vitesse sont **deux objets PDO distincts** (position absolue `0x6000h` vs vitesse `0x6031:01` en 0,1 RPM, `FB_Encoder_SpeedMeasure.st:5-6`), **sans contrôle croisé** dans le code commun. C'est **précisément** ce qui rend le couple « position figée + vitesse non nulle + zéro défaut » **physiquement représentable** — y compris sur machine réelle. Point de robustesse à traiter séparément (§8, option D), **non** un C0 (aucun défaut de sécurité armé n'est contourné).

---

## 5. 📊 Arbre vertical du flux M2 — chaîne complète tracée, point par point avec M1

| # | Étage | M2 (défaillant) | M1 (sain) | Verdict |
|---|---|---|---|---|
| 1 | Commande de sens (PRG_06 → banc) | `PRG_06_Outputs.Data.M2RelayRev` → `FB_SimBench.M2_RelayRev` (`PRG_02:297`) | `M1_RelayRev` (`PRG_02:286`) | identique ✅ |
| 2 | Modèle codeur | `instSimEncoderM2(... RawPos := RawPosM2)` (`FB_SimBench.st:400-413`) | `instSimEncoderM1(... RawPos := RawPosM1)` (`:314-327`) | **code identique** ✅ |
| 3 | Comptage | branche `ELSIF RelayRev` : `IF RawPos >= Increment THEN RawPos -= Increment; ELSE RawPos := 0;` (`FB_Sim_Encoder.st:128-133`) | même branche, mais `RawPos` encore loin du plancher | **plancher 0 atteint côté M2** ❌ |
| 4 | Retour vitesse | `TargetSpeedMps := -SpeedMps;` (`:136`) puis `RawSpdOut` (`:160-172`) | idem | **la vitesse n'est pas coupée par la butée** ❌ |
| 5 | Publication banc | `Winch.COD2_PosValue := instSimEncoderM2.RawPosOut` (`FB_SimBench.st:492`) | `Winch.COD1_PosValue := ...M1...` (`:486`) | symétrique ✅ |
| 6 | Image simulée | `HwSim.Winch := instSimBench.Winch` (`PRG_02:391`) | idem | ✅ |
| 7 | Aiguillage | `HwIn.Winch := SEL(WinchInputSourceSimulated, HwReal.Winch, HwSim.Winch)` (`PRG_02:438`) | idem | **valeur 0 transmise intacte** ✅ |
| 8 | Frontière HW encodeur | `HwInM2.RawPosIn := HwIn.Winch.COD2_PosValue` (`PRG_02:642`) ; `SlaveOperational` (`:646`) | `HwInM1.*` (`:587-591`) | symétrique ✅ |
| 9 | Acquisition | `FB_Encoder_Abs.st:116-120` : `RawPos := RawPosIn` (0) ; `EncoderAvailable = TRUE` (`:75-77/91`) | `RawPos := 420 536` | **reçoit bien 0, donc recopie 0** ✅ |
| 10 | Mise à l'échelle | `FB_Encoder_Scale.st:34-38` : `(0 − (−96 256))/4096 = 23,5 m` | `(420 536 − 385 720)/4096 = 8,5 m` | **arithmétique exacte** ✅ |
| 11 | Sécurité / bornage | `FB_Encoder_Safety.st:53/70/80` : 23,5 m dans les bornes, mesure transmise sans clamp | 8,5 m | ✅ |
| 12 | Fiabilité | `FB_EncoderReliability.st:30/34` : `EncoderAvailable=TRUE`, pas d'incohérence → `EncoderFault=FALSE` | idem | **aucun défaut** ❌ |
| 13 | Vitesse exposée | `FB_Encoder.st:184-190` (`SpdValueIn` = PDO vitesse) → −1,75 m/s, `Valid=TRUE` | 0 m/s | **incohérence position/vitesse non détectée** ❌ |
| 14 | Homing / référence | `FB_Encoder_Homing.st:230/243/249/263-266` : preset sur raw figé → ref = `0 − 96 256` → readback « OK » → `Homed=TRUE`, `HomingSuspect=FALSE` | référence stable | **homing circulaire validé** ❌ |
| 15 | Publication | `PRG_02:680-691` → `FB_WinchStateProjection.st:154` → `H_...Idx102_M2_CablePos_M = 23,5` | `:87` → 8,5 | **symptôme observé** ❌ |

```text
[RelayRev M2:BOOL=1] → [FB_Sim_Encoder:RawPos UDINT=0] ❌ plancher dur
       └─→ [RawSpdOut:DINT=-525] ✅ vitesse pleine (jamais coupée par la butée)
[COD2_PosValue:UDINT=0] → [HwInM2.RawPosIn=0] ✅ → [Abs.RawPos=0] ✅
       └─→ [Scale:(0-(-96256))/4096 = 23.5 m] ✅ → [Safety: pas de clamp] ✅
              └─→ [Reliability: EncoderFault=FALSE] ❌ aucune détection
                     └─→ [Homing: ReadbackOk ≡ TRUE] ❌ → Homed=TRUE, HomingSuspect=FALSE
                            └─→ [M2_CablePos_M = 23.5 m FIGÉE] ❌  (vitesse -1.75 m/s affichée)
```

**Résumé une ligne** : `[M2_RelayRev:BOOL=1] → [RawPosM2:UDINT=0 plancher] ❌ → [M2_CablePos_M:REAL=23.5 figée] → [SpdValueIn:DINT=-525] ❌` — chaîne correcte de bout en bout, **entrée déjà morte à l'étage 3**.

---

## 6. 📊 Données / interactions & chronogramme

### Lectures & essais
- **Lecture croisée des 3 snapshots** (16:54, 17:25, 17:43), mêmes variables → reconstruction de l'historique du raw M2 : `517 287 → 0 → 1 039 975`.
- **Vérification d'unicité** par grep exhaustif sur `CODE/` : `LastKnownRawPos` n'est lu **qu'en** `FB_Encoder_Homing.st:183` ; `BucketOpening_Pct` n'est produit **qu'en** `FB_Bucket.st:650-655` ; `CrossCheckEnable` n'est alimenté **qu'en** `PRG_04:920/990`.
- **Contrôle arithmétique** des trois références M2 déduites : 516 064 / −96 256 / 1 003 744 → les trois positions exposées se recalculent **exactement** depuis les raw lus (0 erreur d'arrondi).
- **Aucune acquisition nouvelle demandée** : les 3 snapshots archivés suffisent (règle §4bis de la skill : un seul canal, pas de lecture Watch).

### Chronogramme (événements × signaux — valeurs issues des snapshots 🟢, enchaînement déduit 🟡)

| Événement | Raw M2 (`COD2_PosValue`) | M2_CablePos_M | `HomingRefRaw` M2 | Spd M2 | Homed / Suspect |
|:---|:---:|:---:|:---:|:---:|:---:|
| T0 = 16:54:59 (raw sain, loin du plancher) | 517 287 | 0.298 | 516 064 | 0 | TRUE / FALSE |
| → 🟡 cumul de descente nette ≈ 126 m (517 287 pts / 4096) | ↓↓↓ | ↓↓↓ | inchangée | −1,75 m/s | TRUE / FALSE |
| **T1 = 17:25:09 — PLANCHER** | **0** | **23.5 (figée)** | **−96 256** | **−525** | **TRUE / FALSE** |
| → 🟡 recalage benne : cible = `M1_CablePosM(8.5) + OffsetCloseM(15.0)` = **23,5 m** (`PRG_02:531`) appliquée sur raw figé → `ref = 0 − 96 256` ; readback circulaire ⇒ **validé** | 0 | 23.5 | −96 256 | 0 | TRUE / FALSE |
| → 🟡 AU + sortie simulation + retour simulation + AU | — | — | persistée | — | — |
| **T2 — ré-init du raw** : `FB_SimBench.st:277-279` (`RawPosM2 = 0 ⇒ 1 100 000`) | **1 100 000** | **≈ 292 m** *(ou 204,677 m si `R0 = 296 459`, voir ci-dessous)* | −96 256 (persistée) | — | TRUE / **FALSE** |
| **T3 = 17:43:33 — preuve de la ré-init** | 1 039 975 | 8.845 | **1 003 744** = **1 100 000 − 96 256** | 0 | TRUE / FALSE |

**Preuve directe du mécanisme de S2 (T3)** : `HomingRefRaw` M2 vaut **1 003 744**, valeur **impossible** sans un raw valant **exactement 1 100 000** au moment du recalage — or `1 100 000 = CST_M2EncoderInitialRaw` (`FB_SimBench.st:177`), constante qui **n'est écrite qu'à un seul endroit** (`FB_SimBench.st:277-279`) et **seulement si le raw persisté vaut 0**. Le lien « plancher 0 → ré-injection de 1 100 000 pts » est donc **établi par mesure**, pas par hypothèse.

**Chiffre 204,677 m (S2)** — chemin arithmétique unique et cohérent, **un seul inconnu** :

```
position avant AU : 8,50 m  →  ref = R0 − 8,5×4096 = R0 − 34 816
position après AU : 204,677 m = (1 100 000 − ref)/4096
   ⇒ 1 100 000 − R0 + 34 816 = 838 357  ⇒  R0 = 296 459 pts
saut = (1 100 000 − 296 459)/4096 = 803 541/4096 = 196,177 m   (8,50 + 196,177 = 204,677 ✅)
```
👉 Le saut **+196,177 m** correspond **exactement** à un raw ré-injecté à `CST_M2EncoderInitialRaw` avec la référence RETAIN **conservée**. Le seul inconnu est `R0 = 296 459 pts` (raw avant AU), **non capturé** à ce moment — voir question ouverte Q1. **Aucune autre hypothèse testée ne reproduit ce nombre** (voir §7).

---

## 7. 🏁 Conclusion

### Verdict tranché : **(a) — bug du simulateur seul.** (b) et (c) sont **réfutés avec preuve**.

- **(b) réfuté** : la valeur publiée par le banc (0) est **celle lue côté encodeur** (`J_...Idx101_EncoderRawPos = 0` = `HwIn.Winch.COD2_PosValue`, `FB_TroubleshootingView.st:245`) → le routage `SimBench → HwSim → HwIn → HwInM2` est **intact**, il transporte fidèlement une valeur morte.
- **(c) réfuté** : `FB_Encoder` fait **exactement** ce qu'il doit de l'entrée reçue — il recopie 0 (`FB_Encoder_Abs.st:117`) et en déduit **23,5 m** avec une précision au point (`FB_Encoder_Scale.st:34-38`). Aucun signe d'échec d'intégration : **il n'y a pas d'intégration** dans cette chaîne (H4). **Pas d'escalade C0**, le code commun M1/M2 n'est pas la cause du blocage.

### Cause racine — 3 facteurs, dans l'ordre de causalité

| # | Cause | Localisation | Rôle |
|---|---|---|---|
| **CR1** | **Plancher dur `RawPos := 0` dans la branche de descente du modèle codeur, sans couper le retour de vitesse.** Compteur **non signé** sans butée fonctionnelle : une fois à 0, la position est **définitivement figée en descente**, alors que la vitesse publiée reste la vitesse **pleine** commandée. | `FB_Sim_Encoder.st:128-133` (`ELSE RawPos := 0;`) + `:136` (`TargetSpeedMps := -SpeedMps;`) + `:160-172` | **Symptôme 1** — reproduit le couple « position figée + vitesse non nulle + zéro défaut » |
| **CR2** | **Ré-injection silencieuse de `CST_M2EncoderInitialRaw` (1 100 000 pts) quand le raw persisté vaut 0**, à la première activation du banc. Saut de **268,55 m** d'un seul scan, jamais signalé. | `FB_SimBench.st:273-280` (+ constantes `:176-177`) ; mémoire `GVL_PERSISTENT.st:157-158` (`VAR_GLOBAL PERSISTENT RETAIN`) | **Symptôme 2** — cause du saut, **prouvée** par `HomingRefRaw = 1 003 744` à 17:43:33 |
| **CR3** | **Référence RETAIN polluée par un homing appliqué sur un raw figé + vérification de readback mathématiquement circulaire** : `PendingHomingRefRaw = RawPos − TargetPoints` puis `CandidateRawDiff = RawPos − PendingHomingRefRaw ≡ TargetPoints` **quel que soit** `RawPos` ⇒ `ReadbackOk` toujours TRUE. Le homing **certifie** un codeur mort. | `FB_Encoder_Homing.st:230` / `:243` / `:249` / `:263-266` | **Aggravant** — la référence 23,5 m (puis la persistance de `−96 256`) devient « officielle », `Homed = TRUE` |

**Aggravants d'aveuglement (pourquoi rien n'a alerté)** :

| # | Mécanisme | Localisation | Effet |
|---|---|---|---|
| AG1 | Contrôle de cohérence au redémarrage comparant le raw à une mémoire **rafraîchie en continu** avec ce même raw, et exécuté **une seule fois par session PLC** (`InitDone` jamais réarmé : `Enable := TRUE` constant) | `FB_Encoder_Homing.st:181-190`, `:285-287`, `:290` ; `PRG_02:594` / `:649` | un saut **intra-session** est **structurellement invisible** à `HomingSuspect` |
| AG2 | Garde-fou « absence de mouvement malgré commande » **inhibé** en manipulation benne (`NOT RefWindowActive AND NOT BenneBusy`, avec `CrossCheckEnable := SyncOperationPermit` FAUX pendant tout homing/benne) | `FB_Safety_Winch.st:437-443`, `:247-254` ; `PRG_04:415-424`, `:920`, `:990`, `:1017` | **muet exactement dans la condition du défaut** (`ErrorNoMovement = FALSE` au 17:25:09) |
| AG3 | Aucun contrôle croisé position ↔ vitesse : deux PDO indépendants, `EncoderFault` ne regarde que la disponibilité et le bornage | `FB_Encoder.st:184-190`, `FB_EncoderReliability.st:30`, `FB_Encoder_Safety.st:53` | « position figée + vitesse −1,75 m/s » **sans aucun défaut** |

### Piste RETAIN (hypothèse de l'orchestrateur, `FB_Encoder_Homing.st:286`) — verdict **nuancé, tranché**

- ❌ **RÉFUTÉE comme cause du saut** : `Calib.LastKnownRawPos` n'entre dans **aucun** calcul de position (grep exhaustif : lu uniquement en `FB_Encoder_Homing.st:183`). La référence qui produit le saut est `Calib.HomingRefRaw` (`FB_Encoder_Homing.st:264`, **champ RETAIN** `ST_Encoder_Calib.st:12`) — **et non** `LastKnownRawPos`.
- ✅ **CONFIRMÉE comme cause d'aveuglement** : `LastKnownRawPos` étant recopié **en continu** (`:286`) depuis un `RawPos` lui-même figé/ré-injecté, le contrôle de cohérence `:183-187` compare **le même raw à lui-même** → `RawDiffRestart = 0` → `BootIncoherentError` jamais armé → **aucune alerte `HomingSuspect`**, même après plusieurs AU, ce qui reproduit exactement l'observation.
- 🟠 **Nuance honnête** : sur machine réelle, la sémantique visée par `:286` (« le codeur a-t-il bougé pendant que l'automate était hors tension ? ») est légitime. Le défaut n'est pas le rafraîchissement en soi, mais l'**absence de détection d'un saut intra-session**.

### Pourquoi « strictement M2 » ? (et pourquoi ce n'est pas rassurant)

Aucune **asymétrie de code** M1/M2 n'existe : les deux étages 1→15 du §5 sont **symétriques**, et `GVL_PERSISTENT.st:157-158` initialise les **deux** raw à 1 000 000. La différence est **uniquement l'historique de comptage** : la butée 0 est atteinte après ≈ `1 000 000/4096 = 244 m` de **descente nette cumulée**, et M2 (benne) en cumule beaucoup plus que M1 dans ces essais (M1 lu à 420 536 / 343 667 / 693 850, jamais proche de 0). **La faute est latente sur M1** : elle se déclenchera au même seuil.

### Statut : **DIAGNOSTIC CLOS** — correctif **à valider par l'humain**. Aucun code modifié (`CODE/` en lecture seule, conforme à la mission).

---

## 8. 🛠️ Correction — Phase 2 (Option 1) **APPLIQUÉE**, puis options restantes

### 8.1 ✅ Appliqué le 2026-09-20 — lot T338 Phase 2 (`DSH10`), contrat C2 `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T338_SIM_ENCODER_FLOOR.yaml`

**GO orchestrateur CC01 (2026-09-20)** : corriger le plancher dans `FB_Sim_Encoder.st` **M1 ET M2**
(même code, deux instances dans `FB_SimBench`) ; interdits : `FB_Encoder`/`FB_Encoder_Homing` et
toute `E_CODEURS/` (chaîne réelle hors scope), AG1/AG2/AG3 (autres tâches).

| # | Ce qui a changé | Où |
|---|---|---|
| 1 | **Plancher muet supprimé** : le comptage brut est traité comme un entier **signé 32 bits** (idiome déjà utilisé dans le même fichier, §2 injection test) → la descente **franchit 0** au lieu de s'y figer | `FB_Sim_Encoder.st` §3 (branches `RelayRev` et roulis arrière) |
| 2 | **Symétrie** : la branche de montée utilise la même arithmétique signée explicite (supprime aussi le rebouclage UDINT silencieux à 2^32) | `FB_Sim_Encoder.st` §3 (`RelayFwd` + roulis avant) |
| 3 | **Saturation signalée** : nouvelle garde de plage `±CST_CountTravelLimitPts` (2^30 pts = 262 144 m, demi-plage signée) → comptage borné **et** `CountSaturated := TRUE` au même scan **et** vitesse de mouvement purgée | `FB_Sim_Encoder.st` §3bis + `VAR CONSTANT` + `VAR_OUTPUT CountSaturated` |
| 4 | Saturation remise à `FALSE` hors `Enable` (pas de drapeau figé) | `FB_Sim_Encoder.st` §1 |
| 5 | **Spécification réalignée** : `TC-P13-032` (« ne descend jamais sous 0 ») **remplacé** par le franchissement continu de 0 + saturation signalée ; nouvelles exigences `TC-P13-036/037/038` ; `TC-P13-031` passé de `NV` à `V-I` | `DOC/AF/AF_Partie-13_Fonction_Simulation/FB_Sim_Encoder_v1.1.md` (nouvelle version) |
| 5bis | **`v1.0` archivée** (autorisation CC01) : **déplacée** vers `ARCHIVES/Doc/AF/AF_Partie-13_Fonction_Simulation/FB_Sim_Encoder_v1.0.md` — jamais une source active, **contenu conservé** (9 115 o), dossier `ARCHIVES/Doc` **ignoré par Git** ⇒ côté versionné le lot apparaît comme un renommage `v1.0 → v1.1`, aucune suppression de contenu | `ARCHIVES/Doc/…` (hors suivi) + avertissement D3 `G340` levé (4 → 3) |
| 6 | **Garde-fou** `G510_check_sim_silent_floor.py` : refuse toute butée littérale sur un comptage brut de position (`*RawPos*`, `*PosPts*`, `*Odom*`) sans saturation signalée, avec `--selftest` rejetant la mutation d'incident | `TOOLS/AGENT_WORKFLOW/scripts/` + branchement `run_all_gates.py` palier C + `registry.yaml` |

**Preuves (Phase 2)** :

| Preuve | Résultat |
|---|---|
| CI `FB_Sim_Encoder` | **9/9 PASS, 0 FAIL** (dont `TC-P13-036` = régression directe du blocage M2 : comptage à 0 + descente → −41 pts, **ne reste pas à 0**) |
| `G510 --selftest` | **PASS** — réactif au motif d'incident ré-injecté dans le fichier réel, sans faux positif |
| `G200_check_linkage.py --report` | **PASS** — 135 OK / 0 KO, 2 006 instances vérifiées |
| Bundle + diff bundle | `CODE_XML/CODE_Bundle.xml` frais (G390 PASS) + `CODE_XML/CODE_DiffBundle.xml` (objet `FB_Sim_Encoder`) |
| Gates palier C | **41/46 PASS** — les **5 FAIL sont exactement les dettes pré-existantes** documentées avant ce lot (`G300`, `G340`, `G408`, `G430`, `G483`) : **aucun échec introduit**. `G510` **PASS** (0,30 s) |

> ⚠️ **Point d'alerte (devoir d'alerte, hors lot)** : `TC-P13-032` était **`NV` = non implémenté** au
> catalogue, alors que le code l'implémentait bel et bien — et c'est cette exigence qui a produit
> l'incident. Une exigence écrite sans discernement physique (ici : « un compteur brut ne descend
> jamais sous 0 ») a été implémentée à la lettre. C'est la raison du remplacement de l'exigence,
> pas un simple ajustement de code.

### 8.2 ⏸️ Restant à arbitrer (non appliqué — validation humaine requise)

- **CR2 — ré-injection silencieuse du comptage (`FB_SimBench.st:273-280`)** : `RawPosM2 = 0 ⇒ 1 100 000 pts` au premier scan du banc → saut de position d'un seul scan (**cause directe du symptôme 2**). Fichier sous **verrou DSH03** ⇒ **hors lot**, à porter par une tâche dédiée. *Proposition* : ré-initialiser sur une **plage** plausible ou sur un état explicite de banc, jamais sur une sentinelle `0` ambiguë ; et ne jamais republier un saut que la chaîne aval ne sait pas qualifier.
- **Option 0 (immédiat, sans code)** : sur le banc, une seule **montée** suffit désormais à ressortir d'un comptage négatif (plus de blocage définitif) ; éviter le cycle simulation OFF/ON tant que CR2 n'est pas traité.
- **Option 2 (code commun — décision séparée)** : (a) readback de homing **non circulaire** ; (b) détection de **saut de position intra-session** (`HomingSuspect`) ; (c) contrôle croisé **position ↔ vitesse**. *Bénéfice machine réelle, mais hors scope simulateur* → `E_CODEURS/` + `FB_Safety_Winch.st` = contrat C2/C3 dédié.
- **AG1** *(InitDone une seule fois par session)* : candidat **T339/T341** (dette qualité) — **non traité ici** (non trivial : touche `FB_Encoder_Homing`).
- **AG2** *(garde-fou « absence de mouvement » inhibé pendant toute manipulation benne)* : autre tâche ; **contradiction documentation ↔ code** signalée (`PRG_04:404-405` vs `FB_Safety_Winch.st:248-249/:453`) — **Q4 remontée séparément par CC01, pas à corriger dans ce lot**.
- **Q5** *(purge des mémoires RETAIN de banc)* : **NON** — décision humaine séparée ; rien purgé.
- **Q1** *(nom exact de la vitesse m/s affichée)* : à exposer seulement avec accord humain ; **hors scope diagnostic**.

### 8.3 🔎 Observation connexe (non corrigée, hors scope)

`Increment` peut valoir **0** (facteur de confort `SpeedScaleFactor = 0`) : la position est alors figée **alors que la vitesse pleine est encore publiée** — même famille de signature que le symptôme 1, par un autre chemin. Non traité ici (ce n'est pas un plancher et `SpeedScaleFactor = 0` est un réglage opérateur explicite) : à trancher dans un lot dédié.

---

## 9. ✅ Vérification de la correction / non-régression

> ⚠️ **Hand-off humain** : recette terrain + intégration CODESYS manuelle. Les contrôles mécaniques ci-dessous sont **faits** ; la recette opérateur reste à faire.

- [x] **M2 sous commande de descente** : comptage **à 0** ⇒ scan suivant à −41 pts, **jamais figé** (test `TC-P13-036`, CI 9/9 PASS).
- [x] **Continuité bidirectionnelle** : franchissement de 0 dans les deux sens, valeurs exactes au point (tests `TC-P13-032`/`TC-P13-038`).
- [x] **Aucune saturation muette** : au-delà de ±`CST_CountTravelLimitPts`, comptage borné **et** `CountSaturated = TRUE` **et** `RawSpdOut = 0` (test `TC-P13-037`).
- [x] **Non-régression modèle** : `TC-P13-001/002/034/035` inchangés et verts ; preset + latence couverts par le nouveau `TC-P13-031`.
- [x] **Garde-fou** : `G510 --selftest` PASS + gate branché palier C.
- [x] **Liaison** : `G200 --report` PASS (0 erreur).
- [x] **Gates palier C** : 41/46 PASS — les 5 FAIL (`G300`/`G340`/`G408`/`G430`/`G483`) sont **les dettes pré-existantes**, identiques à la baseline d'avant lot ; `G510` PASS, bundle frais (G390 PASS).
- [x] **Hors périmètre vérifié propre** : `G340` n'ajoute **aucune erreur** pour ce lot (un seul **AVERTISSEMENT D3** attendu : deux versions actives de `FB_Sim_Encoder`, archivage de `v1.0` = décision humaine) ; `G430` ne relève **rien** dans `FB_Sim_Encoder.st`.
- [x] **Spécification** : `FB_Sim_Encoder_v1.1.md` (exigence remplacée), cartouche ST + `registry.yaml` alignés.
- [ ] **Recette opérateur (humaine, CODESYS)** : sur banc, M2 sous commande de descente → position **qui évolue** avec la vitesse ; plus aucun blocage définitif à l'atteinte du zéro de comptage ; `CountSaturated` reste `FALSE` en usage réel.
- [ ] **Test Q2 restant (falsifiable)** : si un saut de position se reproduit avant traitement de CR2, relever `Idx311_ErrorEncoder` (attendu `TRUE` à > 99 m) vs `HomingSuspect` (attendu `FALSE`).
- [ ] **CR2** : à traiter pour supprimer définitivement le **saut** post-AU (reste ouvert).

---

## 10. 📝 Journal (chronologique)

- **2026-09-20 19:34** — Verrou `T338` posé au nom de `DSH10` (premier tag libre, vérifié : DSH01 contaminé, DSH02..DSH09 pris). Lecture seule `CODE/`.
- **2026-09-20 19:3x** — Traçage complet `SimBench → HwIn → FB_Encoder → position` ; comparaison M1/M2 étage par étage ; exploitation des **3 snapshots** archivés (16:54:59 / 17:25:09 / 17:43:33).
- **2026-09-20 19:3x** — Verdict tranché **(a) bug simulateur seul** ; (b) et (c) réfutés avec preuve (valeur 0 déjà présente côté HwIn ; `CablePosM` M2 recalculée exactement depuis ce 0).
- **2026-09-20 19:3x** — Cause du saut S2 **prouvée par mesure** : `HomingRefRaw` M2 = 1 003 744 = `CST_M2EncoderInitialRaw (1 100 000) − 96 256` → ré-injection `RawPosM2 = 0 ⇒ 1 100 000`.
- **2026-09-20 19:3x** — Piste RETAIN : **réfutée comme cause du saut** (`LastKnownRawPos` n'alimente aucune position), **confirmée comme cause d'aveuglement**. Aggravants AG1/AG2/AG3 identifiés avec `fichier:ligne`.
- **2026-09-20 19:3x** — Fiche créée. **Aucun code modifié, aucun commit.**
- **2026-09-20 19:5x** — Arbitrage CC01 : **GO Option 1** (Q1 reportée, Q2 à vérifier au prochain essai, Q3 tranchée par l'agent, Q4 remontée séparément, Q5 = non) ; AG1 noté candidat T339/T341.
- **2026-09-20 20:0x** — Contrat C2 `TASK_CONTRACT_T338_SIM_ENCODER_FLOOR.yaml` créé et validé (`check_task_contract.py` **PASS 0 erreur / 0 avertissement**). Verrou élargi (vérification anti-collision : `FB_Sim_Encoder.st` **absent** des périmètres T300/T328 de DSH03).
- **2026-09-20 20:1x** — Correction `FB_Sim_Encoder.st` (plancher supprimé, comptage signé explicite, garde de plage signalée §3bis, `CountSaturated`) + 5 tests CI (dont la régression directe `TC-P13-036`) + garde-fou `G510` + spec v1.1 + chapô AF-13 + `registry.yaml`.
- **2026-09-20 20:2x** — **CI `FB_Sim_Encoder` 9/9 PASS** (1er run : 6/9 — deux attentes de test erronées : `REAL_TO_UDINT` **arrondit** (40,96 → 41) et le harnais **ré-injecte** le `VAR_IN_OUT` avant chaque appel ; tests corrigés en pilotant la mémoire comme le fait le caller réel).
- **2026-09-20 20:2x** — `G510 --selftest` **PASS** (mutation d'incident ré-injectée dans le fichier réel → détectée) · `G200 --report` **PASS (0 erreur)** · bundle + diff bundle générés.
- **2026-09-20 20:4x** — Arbitrage CC01 : correctif accepté (diff vérifié sur le code réel), **GO commit** ; `v1.0` **archivée** (déplacement vers `ARCHIVES/Doc/…`, `G340` D3 → levé : 4 → 3 avertissements, 109 erreurs **inchangées**) ; CR2 confirmé **OUVERT** (tâche dédiée en cours de création, verrou DSH03 à coordonner) ; Q1 toujours en attente d'accord humain.
- **2026-09-20 20:5x** — **Commit `8fd4d62e`** : 12 fichiers (code + test + garde-fou + spec v1.1 + archivage + contrat + fiche + rapports CI). **Aucun push** (branche 6 commits devant `origin/main`). Fichiers de coordination (`TASKS.yaml`, `TASKS_ORCHESTRATOR.yaml`, `run_all_gates.py`, `CODE_XML/*`) **volontairement exclus** : ils portent le travail non commité d'autres acteurs (T336/T339/T340/T341, G504/G507).


---

### ❓ Questions ouvertes (à trancher avant tout correctif)

| # | Question | Pourquoi c'est bloquant |
|---|---|---|
| **Q1** | **Nom complet exact de la « vitesse en m/s » lue par l'opérateur** : `Data.EncoderM2.Measurement.Speed_Mps` (issue du PDO `0x6031:01`) ou une autre variable d'IHM ? | confirme définitivement H4 (la vitesse est **indépendante** de la position). Si c'est une vitesse **dérivée de la position**, la conclusion change et il faut rouvrir l'analyse. |
| **Q2** | **Au moment du saut à 204,677 m** : relever `B_Inputs.Winch.COD2_PosValue` **avant** et **après** AU, + `F_HomingM2.HomingHomed` / `HomingSuspect` / `J_...Safety_300.Idx311_ErrorEncoder`. | ferme le seul inconnu du §6 (`R0`). ⚠️ **Prédiction falsifiable** : à 204,677 m (> 99 m), `FB_Encoder_Safety.st:53/81` doit poser `EncoderIncoherent = TRUE` → `Idx311_ErrorEncoder = TRUE` **alors que** `HomingSuspect` reste **FALSE**. Si `Idx311` est FALSE à cette valeur, **mon verdict est faux** et il faut rouvrir. |
| **Q3** | Le compteur brut du **modèle** doit-il être un UDINT non signé, ou un DINT signé façon codeur absolu multitour ? | conditionne l'option 1 (butée symétrique) ; impacte `FB_Sim_Encoder.st` (verrou `L_SIMULATION`). |
| **Q4** | L'inhibition d'AG2 (`RefWindowActive` via `NOT CrossCheckEnable`) est-elle **voulue** pour la Cause 15, ou est-ce un effet de bord du gate benne ? Le commentaire `PRG_04:404-405` affirme « MecaA et survitesse restent ACTIFS via CrossCheckEnable » — **contredit** par `FB_Safety_Winch.st:248-249` (`RefWindowActive` TRUE quand `CrossCheckEnable` FALSE) qui **remet à zéro** MecaA (`:251`) et **inhibe** la survitesse (`:453`). | contradiction **documentation ↔ code** : à trancher avant d'écrire un correctif de surveillance ; décision de sécurité (arbitrage humain). |
| **Q5** | Faut-il purger les mémoires `PERSISTENT RETAIN` de banc (`_SimEncoderRawPosM1/M2`, `_CalibM1/M2`) au retour d'un état incohérent ? | ces mémoires survivent au reset froid **et** au download (`GVL_PERSISTENT.st:3/10`) : une référence polluée peut traverser une remise en service. |
