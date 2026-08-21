# 🧭 D-P10 — Revue INDÉPENDANTE de la refonte `FB_WinchSync` → `FB_SyncDeviation` + `FB_SyncContactor` (v0.2)

> 📄 Statut : **ÉTUDE (lecture seule, zéro code)** · 📅 2026-08-21 · 🧠 Agent automatisme indépendant
> 🎯 Mission : **challenger** la proposition `v0.1` sur le code réel, vérifier les consommateurs, proposer des solutions **vérifiées à valeur ajoutée**, chiffrer les risques de régression sécurité.
> 🔗 Base : `REVUE_SYNCHRO_TREUILS_v0.1.md` · `CODE/H_TREUILS_BENNE/FB_WinchSync.st` (186 l.) · `PRG_04_Treuils_Benne.st` · `FB_Bucket.st` · `FB_Safety_Winch.st` · `FB_Encoder_*.st` · `TRACE_ACTIONS_T146`

---

## 🏁 Verdict global : **MIXTE, orienté "structure saine / 1 verrou sécurité majeur"**

La direction générale (scinder écart codeurs / cohérence contacteurs, exposer des signaux purs, fiabiliser le bit codeur) est **bonne et conforme à la posture 1 FB = 1 responsabilité**. Mais **le point 6 (`SyncActive := 1 si Status≠erreur`) est une régression sécurité** sur le couplage croisé actuel, et **le point 2.7 (offset benne géré DANS le bloc écart) duplique une responsabilité déjà externalisée** dans `FB_Bucket`. En corrigeant ces 2 points, la refonte est verte.

---

## 1. 🔍 Vérifications factuelles — qui lit quoi (sur code, grep exhaustif)

### 1.1 Consommateurs des sorties `FB_WinchSync`

| Sortie | Consommateur (fichier : ligne) | Usage réel |
|---|---|---|
| `Status.Error` (tout ErrorId) | `PRG_04` :235 → `WinchSyncError` · `PRG_03` :72 → `FB_Cycle.WinchSyncError` · `PRG_07` :440 (`Cycle.State.WinchSyncError`), :558 (`FB_TroubleshootingView.CycleWinchSyncError`) | **FB_Cycle** :200/385 et **FB_ExtractionSequence** :145/159 = **bloque la séquence** si désynchronisme. Décodé aussi par le **banner** (voir ErrorId). |
| `Status.ErrorId` bit0 (écart) | `PRG_04` :375 (`SyncMinorDeviation`), :376-377 (`BlocksUp/Down`) · `FB_Hmi_BannerFormatter` :484 (`[SYNC] ecart M1/M2`) via `GVL_IHM.M1M2Sync.State.ErrorId` | Ralentissement/soft-stop directionnel + alarme IHM. |
| `ErrorId` bit1 (incohérence) | `PRG_04` :595-596 (`SafeStopM1/M2_Raw`) · banner :487 (`[SYNC] incoherence commande`) | **SafeStop** des 2 treuils. |
| `SyncActive` | `PRG_04` :790-795 (couplage croisé SafeStop **ET** Permit) | **anti-télescopage** : arrêt/limite d'un treuil coupe l'autre au même scan. ⚠️ critique. |
| `SyncDegradedStep1` | `PRG_04` :815/817/852/853 (`SEL(…,Eff,1)`) + `PRG_07` :471 (`SyncDegradedActive` → banner) | **ralentissement Palier 1** des 2 treuils. |
| `SyncWarn` | `PRG_04` :1077 → `SyncState.SyncWarn` → `GVL_IHM.M1M2Sync.State.SyncWarn` | LED IHM. |
| `SignedDeltaPosM` | `PRG_04` :376-377, :1075 ; `PRG_07` :441 ; `PRG_03` :73 | diagnostic + blocage directionnel. |
| `DeltaPosM` (ABS) | — *(aucun consommateur externe)* | interne uniquement. |
| `Ready` | `PRG_04` :1079 → `SyncState.Ready` | IHM. |

### 1.2 ⚠️ Faits qui contredisent la proposition v0.1

| Propos v0.1 | Réalité vérifiée | Verdict |
|---|---|---|
| 2.1 : `SyncWarn` ≈ `SyncDegradedStep1` (même condition) | **FAUX.** `SyncWarn := Status.Error` (L182) = **tout bit** (écart OU incohérence contacteurs). `SyncDegradedStep1` (L146) = **écart seul**. Les 2 ne sont PAS identiques. | La vrai confusion est que **SyncWarn conflate 2 domaines de défaut** sous une LED — c'est là le vrai gain du split, pas « 2 seuils redondants ». |
| 2.7 : « le bloc écart gère un offset benne cohérent (état benne en entrée) » | **FAUX.** L'offset est **déjà externalisé** : `FB_Bucket` §7 produit `ActiveOffsetM` (L502-512), consommé par `FB_WinchSync` ET pré-corrrigé dans `ExpectedOtherWinchPosM` de `FB_Safety_Winch` (commentaire L374-375). | Dupliquer la gestion benne dans le bloc écart = **2 sources de vérité**. Le vrai défaut est ailleurs (cf §3.5). |
| 2.8/point 1 : besoin « bypasse codeurs mais surveille contacteurs » | **Confirmé.** `BypassGlobal` (L99/L129) saute TOUTE la logique, y compris bit1. | Le besoin de désolidariser bit1 du bypass codeurs est réel. ✅ |
| point 4 : `HomedM1/M2` → `HomedAndReliable` | `Homed` de `FB_Encoder_Homing` L251 exclut DÉJÀ `HomingSuspect` (`Homed := Calib.Homed AND NOT HomingSuspect`). `EncoderIncoherent` (FB_Encoder_Safety) inclut aussi HomingSuspect. | `HomedAndReliable := EncoderAvailable AND Homed AND NOT EncoderIncoherent` est **sûr mais partiellement redondant** sur `HomingSuspect`. OK, garder pour la clarté, mais **helper `FB_EncoderReliability` n'existe PAS encore** (T146 D-A2bis « à faire »). Dépendance. |

> ✅ **`FB_DiveSearch`, `FB_ExtractionSequence`, `FB_Cycle`, `FB_Winch` : `FB_DiveSearch` ne consomme AUCUNE sortie synchro** (0 occurrence sur le grep). `FB_Cycle`/`FB_ExtractionSequence` ne consomment QUE `Status.Error` (pas `SyncActive`/`DeltaPosM`). `FB_Winch` reçoit `SyncDegradedStep1` via `PRG_04` (SEL MaxStep) — indirect.

---

## 2. 🔬 Challenge point par point + solutions de valeur ajoutée

### 2.1 Split en 2 blocs — **BÉNÉFIQUE** ✅ (certitude forte)
Deux préoccupations **réellement distinctes côté aval** :
- **incohérence contacteurs (bit1) → SafeStop** (consommation sécurité, `PRG_04` :595-596).
- **écart codeurs (bit0) → ralentissement + IHM** (`PRG_04` :815-853 + banner).
Et le besoin « bypasse codeurs / surveille contacteurs » est confirmé (le bypass actuel coupe tout).
**Blast radius vérifié** : `instWinchSync` est référencé dans `PRG_04` (×~15), `PRG_03` :72-73, `PRG_07` :440/441/470/558, `FB_TroubleshootingView` :634, et le **banner `FB_Hmi_BannerFormatter` :484-489 décode `ErrorId` (bit0/bit1)**.
➡️ **Solution valeur ajoutée** : garder une **façade composite** `instWinchSync` (ou re-composer `ErrorId` en `PRG_04`) pour préserver le décodage bit0/bit1 du banner et les lectures `PRG_03`/`PRG_07`/`Troubleshooting`. Le split DOIT être **un changement atomique** (tous les consommateurs migrés dans le même lot), jamais incrémental partiel.

### 2.2 2 seuils `Warn`/`Fault` vs sortie brute — **BÉNÉFIRE, avec correction** ✅ (certitude forte)
Le vrai problème n'est pas « 2 conditions ≈ identiques » (faux, cf §1.2) mais **`SyncWarn` conflate écart + contacteurs** : la LED IHM clignote pour 2 défauts distincts. Séparer en `SyncDeviationWarn` (signale) est un vrai gain de diagnostic. MAIS :
- **La sortie écart doit rester** (`DeltaPosM`/`SignedDeltaPosM`) — consommé pour le **blocage directionnel** (`PRG_04` :375-377) : sans le signe, on perd la béquille « quel treuil bride l'autre ».
- **⚠️ Ne PAS créer un 2ᵉ seuil « critique » dans `FB_SyncDeviation`.** Le seuil critique (`CriticalSyncToleranceM` → SafeStop/PowerCutOff) vit DÉJÀ dans `FB_Safety_Winch` MECA E (L380-393), **couche indépendante défense-en-profondeur**. Un `SyncDeviationFault` = **3ᵉ seuil**, à définir **strictement sous** le critique safety, sinon flou sémantique + risque d'écran (une synchro qui "Fault" sans lancer SafeStop, et l'inverse).

**➡️ Solution valeur ajoutée :**
```
FB_SyncDeviation   — produira, ne décide PAS
  Signal : Warn  = DeltaPos > WarnTol  (info, alimente banner/signalement)
  Signal : Fault = DeltaPos > FaultTol (le « ralentir Palier 1 » décidé par le caller)
  MESURES: SignedDeltaPosM / DeltaPosM (bruts, offset corrigé) — pour diag + blocage directionnel
  → garantie: FaultTol < CriticalSyncToleranceM (Safety), avec marge
  SORTIE Diagnostic : DevGlobalOK (bool de surveillance active & saine)
```
`Warn` = signalement IHM ; `Fault` = l'ancien `SyncDegradedStep1` (forcer Palier 1), **décision de ralentir laissée au caller** (déjà le cas aujourd'hui via `PRG_04`). ⚠️ **Concilier les seuils contradictoires** : `0.10` (spec v1.0) vs `0.3/0.8` (T55) vs `0.8-2.5` (AF §6.7) — 3 docs ne sont pas d'accord. Les 2 nouveaux seuils devraient être des **entrées config** (déjà le cas `CfgSyncToleranceM`) pour trancher sur site.

### 2.3 Retirer `Mode` — **OK, couplé au point 6** (certitude moyenne)
`Mode` ne sert QUE l'arbitrage `SyncActive` (L104-111). Le caller (`PRG_03`) connaît le mode. Retirable sans risque SI on garde `SyncActive` produit par le caller. **Ne pas** le remplacer par « SyncActive = non-erreur » (cf point 6).

### 2.4 Retirer `PowerContactorEngaged` — **LOW RISK** (certitude moyenne)
N'agit que dans le GATE (§1) pour zéro les sorties hors puissance. Pour un bloc **de surveillance pure** (aucune commande mouvement), l'état puissance ne change rien au calcul d'écart (positions figées). Retirer = le caller assume le gating (il le fait déjà pour `Enable`). ⚠️ Petite régression : aujourd'hui `PowerOff` → `ErrorId` remis à zéro (GATE). Sans lui, un défaut latche persiste à la coupure → à re-préciser par le `Reset` front (déjà le pattern). **Non bloquant, priorité basse.**

### 2.5 `HomedAndReliable` en entrée — **BÉNÉFICE** ✅ (certitude forte)
Améliore le `HomedM1 AND HomedM2` (L117/137). Ajoute `EncoderAvailable + NOT EncoderIncoherent`. ✅.
- ⚠️ **2 précisions** :
  1. **Dépendance bloquante** : helper `FB_EncoderReliability` **n'existe pas encore** (T146 D-A2bis). Faire la refonte synchro AVANT le helper = passer des bits nus mal câblés. → ordre : helper d'abord, puis synchro.
  2. **Failsafe à expliciter** : si un codeur devient incohérent en cours de synchro, le bloc écart **cesse de détecter** (il ne peut pas mesurer). La garantie revient alors à `FB_Safety_Winch` M2M `EncoderAvailableEffective` (défense en profondeur). Garder cet ordre, ne pas enlever la couche safety.

### 2.7 / point 5 Offset benne — **CORRECTION de cible** (certitude forte)
L'offset est **déjà externalisé** dans `FB_Bucket` §7 (L502-512) :
- `BUSY` → suit l'écart réel (`CablePosM2-CablePosM1`)
- `CloseReq OU IsClosed` → `OffsetCloseM`
- **else** → `OffsetOpenM`

**Le vrai défaut** (qui correspond au besoin 2.7) : si on **s'arrête en intermédiaire non référencé** (ni fermé, ni ouvert, ni BUSY), le dernier `else` force `OffsetOpenM` → saut d'écart artificiel → fausse alarme, voire blocage. Ce n'est **pas** la responsabilité du bloc écart.

**➡️ Solution valeur ajoutée (et non pas le point 2.7) :**
```
Cible du correctif = FB_Bucket §7 (producteur unique d'offset), PAS FB_SyncDeviation
  Ajouter un état « HoldOffset » : quand une action benne s'arrête à mi-course
  (ni BUSY, ni Closing/Closed, ni Opening vérifié) → gel d'ActiveOffsetM à l'écart réel
  (latche la dernière valeur CablePosM2 - CablePosM1), pour que DeltaPosM reste ≈0 au stop
  et que l'on monte les 2 treuils en gardant l'écart réel (cas 7 m).
FB_SyncDeviation reste un CONSOMMATEUR pur de ActiveOffsetM (aucune entrée « état benne »).
```
Cela respecte le producteur-unique (règle d'or du projet), évite 2 sources de vérité, et satisfait exactement le besoin « on part de l'écart réel et on monte les 2 ».

### 2.6/point 6 `SyncActive` — **🔴 RÉGRESSION SÉCURITÉ (le verrou)**
Contre le code réel :
- `SyncActive` conduit le **couplage croisé anti-télescopage** `PRG_04` :790-795 (SafeStop ET Permit).
- En l'état, `SyncActive` reste `TRUE` en mode MAINT_N1 même en erreur (L132-135). Le couplage est **maintenu** pendant un défaut.
- Si on le redéfinit `SyncActive := (Status n'est pas en erreur)` :
  `SafeStopM1_Active := SafeStopM1_Raw OR (FALSE AND SafeStopM2_Raw)` → le blocage **ne se propage plus** au moment où le défaut survient (ex. glissement M1 qui doit stopper M2).
→ **Abaissement réel de la protection pendant le défaut. À refuser tel quel.**

**Solution de valeur ajoutée — décorréler 2 sémantiques :**
| Signal | Sémantique | Origine | Reste TRUE en erreur |
|---|---|---|---|
| `SyncActive` (couplage) | « mode couplé, autorise la croix » | appelé par le caller (à partir du mode) | **OUI** (doit rester TRUE pour garder l'anti-télescopage) |
| `SyncSurveillanceOK` | « surveillance synchro saine » | `NOT Status.Error` des 2 blocs | **NON** (c'est le diag) |
| `DeviationWarn/Fault` | signalement écart | bloc écart | non pertinent |

L'IHM affiche `SyncSurveillanceOK` (diagnostic) ; le couplage consomme `SyncActive` (stable). **Réintervertir point 6** : ne PAS lier `SyncActive` à l'erreur.

---

## 3. 🛡️ Risques de régression sécurité (ordre de gravité)

| # | Risque | Gravité | Mitigation |
|---|---|---|---|
| R1 | `SyncActive` lié à l'erreur → désengage le couplage croisé SafeStop/Permit pendant un défaut | **CRITIQUE** | garder `SyncActive` = autorisation de couplage stable (point 6 rejeté) |
| R2 | Découpe de `ErrorId` (bit0/bit1) casse le décodage du banner + `PRG_03`/`PRG_07`/`Troubleshooting` | haute | façade composite + migration atomique + préserver bit0=écart/bit1=incoh |
| R3 | 2ᵉ seuil « Fault » qui empiète sur le critique `FB_Safety_Winch` (SafeStop/PowerCutOff) | haute | `FaultTol < CriticalSyncToleranceM`, critique safety gardé unique |
| R4 | Suppression `HomedM1/M2` sans le helper `FB_EncoderReliability` prêt → codeur non fiable non bloquant | moyenne | helper d'abord (T146) |
| R5 | `Reset` front / latage `ErrorId` perdu au passage (GATE power-off) | faible | garder `Reset` front + `ErrorId` composite en PRG_04 |

**Temporisation à conserver** : `MismatchTimer T#500ms` (cohérence contacteurs, filtre transition/rampe) et `DeviationTimer T#800ms` (transitoire coast-down arrêt). ⚠️ Note code : `SyncDegradedStep1` (L146) est **instantané** (non filtré par le timer 800ms, contrairement au latche bit0). Répliquer fidèlement ce double comportement (latche filtré pour `Error` / signal instantié pour dégradation) dans le nouveau bloc.

---

## 4. 💡 Valeur ajoutée concrète (au-delà du renommage)

1. **Découplage `SyncActive`/`SyncSurveillanceOK`** (solution point 6).
2. **`FB_SyncDeviation` = producteur de signal à `Warn`/`Fault` + `SignedDelta`** — déplacer la **décision de ralentissement** (déjà) chez le caller : **expliciter** que PRG_2 `SEL(...,MaxStep,1)` reste l'endroit du Palier 1, pour que le caller puisse aussi fusionner `Fault` avec benne/anti-mou (comme aujourd'hui avec `M2_ForceSlowSpeed`).
3. **Offset : correctif d'état `HoldOffset` dans `FB_Bucket`** (producteur unique) — répond au besoin intermédiaire sans dupliquer.
4. **Troubleshooting/IHM** : exposer `SyncDeviationWarn`, `SyncContactorMismatch`, `SyncSurveillanceOK` (3 LEDs distinctes) en plus du `DeltaPosM`. Le banner décode déjà bit0/bit1 — réutiliser le même mapping composite. Alimenter `ST_SyncState` (ajouter `DeviationWarn`, `ContactorMismatch`, `SurveillanceOK`).
5. **Alignement docs seuils** (0.10 vs 0.3/0.8 vs 0.8-2.5) → 2 seuils config + trancher la définition `Fault` vs critique Safety (une seule référence).

---

## 5. 📋 Verbatim décisionnel — Décision proposée / justification / certitude

| Point | Décision proposée | Justification vérifiée | Certitude |
|---|---|---|---|
| Split 2 blocs | ✅ **Adopté** (`FB_SyncDeviation` + `FB_SyncContactor`), mais **façade composite `instWinchSync`/`ErrorId`** pour ne pas casser banner + PRG_03/07 | consommateurs multiples décodent `ErrorId` bit0/bit1 ; besoin réel de séparer bit1 des codeurs | **forte** |
| 2 seuils Warn/Fault | ✅ **Adopté**, `Warn`=signalement, `Fault`=force Palier 1 (déjà chez le caller). **Garder `SignedDeltaPos`** ; **ne PAS recréer un seuil « critique »** (rester sous `CriticalSyncTolerance` Safety) | SyncWarn conflate actuellement écart+écart ; signe consommé pour le blocage direction | **forte** |
| Sortie écart brute | ✅ **Garder `DeltaPosM` + `SignedDeltaPosM`** (diagnostic + blocage) | consommé PRG_2/07/03 | **forte** |
| Retirer `Mode` | ✅ **Adopté** — mais `SyncActive` doit rester autorisation couplage, produit par le caller | Mode ne sert que l'arbitrage `SyncActive` | **moyenne** |
| Retirer `PowerContactorEngaged` | ✅ **Adopté** (bloc de surveillance, caller gate) | utilisé seulement dans le GATE ; peu de risque ; non prioritaire | **moyenne** |
| `HomedAndReliable` en entrée | ✅ **Adopté** — mais **après** création du helper `FB_EncoderReliability` (T146 D-A2bis) | helper inexistant ; Homed exclut déjà HomingSuspect | **forte** |
| Gestion offset benne DANS le bloc écart | ❌ **Rejeté** — résoudre dans `FB_Bucket` (état `HoldOffset`) | offset déjà externalisé `FB_Bucket`:502 ; dupliquer = 2 sources | **forte** |
| `SyncActive := 1 si non-erreur` | ❌ **Rejeté** — remplacé par `SyncActive` (couplage stable) + `SyncSurveillanceOK` (diag) | couplage croisé :790-795 se désengage en défaut | **forte** |
| Garder TON 500/800ms | ✅ **Conserver** + reproduire le double comportement (latche `Error` filtré vs dégradation instantanée) | filtre transitoire mécanique ; cohérence avec le code | **forte** |

---

## 6. 📐 Ordre d'implémentation recommandé

**Ordre (séquencement qui réduit le risque) :**
1. **Créer le helper `FB_EncoderReliability`** (T146 D-A2bis) + expose `M1/M2_HomedAndReliable` (défaut-blatoire : aucune migration synchro sans lui).
2. **Correctif `FB_Bucket` `HoldOffset`** (état intermédiaire) — indépendant, single-producer.
3. **Refonte synchro** en un **lot atomique** : 2 nouveaux FB + façade composite `instWinchSync` + migration des consommateurs (`PRG_04`, `PRG_03`, `PRG_07`, banner) **dans la même modification** + conservation du mapping `ErrorId` bit0/bit1.
4. **Alignement des seuils doc** (0.10/0.3/0.8/2.5) + tranche Warn vs Fault vs Safety.
5. **IHM/Troubleshooting** : exposer les 3 nouveaux bits (`DeviationWarn`/`ContactorMismatch`/`SurveillanceOK`).

**Ce qu'il NE faut PAS faire :**
- ❌ **Ne pas lier `SyncActive` à l'erreur** (verrou de régression sécurité).
- ❌ **Ne pas mettre l'offset benne dans le bloc écart** (2 sources de vérité).
- ❌ **Ne pas recréer un seuil « critique » dans `FB_SyncDeviation`** (empitche sur la couche Safety).
- ❌ **Ne pas supprimer `instWinchSync` sans façade/migration atomique** (casse banner + FB_PRG03/07/Troubleshooting).
- ❌ **Ne pas faire le split avant le helper `FB_EncoderReliability`** (câblage de bits bruts).
- ❌ **Ne pas perdre les temporisations** 500/800ms ni la distinction latche-Error / signalé-dégradé.

---

## 7. 📚 Sources vérifiées (code)
- `CODE/H_TREUILS_BENNE/FB_WinchSync.st` (L117/137/146/151/160/182)
- `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (L235/375-377/517-543/595-596/790-795/815-853/1075-1082)
- `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` (L494-512)
- `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` (L372-393, M2M E)
- `CODE/E_CODEURS/FB_Encoder_Homing.st` (L251), `FB_Encoder_Safety.st` (L107), `FB_Encoder_Abs.st` (L101)
- `CODE/M_MAIN/PRG_07_Supervision.st` (L378/440/470/493/558), `PRG_03_Modes_Cycle.st` (L72-73), `FB_Hmi_BannerFormatter.st` (L484-489)
- `CODE/G_CYCLE/FB_Cycle.st` (L200/385), `FB_ExtractionSequence.st` (L145/159)
- [`TRACE_ACTIONS_T146_REFERENCEMENT_CODEURS.md`](TRACE_ACTIONS_T146_REFERENCEMENT_CODEURS.md) (D-A2b/D-P3/D-P9)
