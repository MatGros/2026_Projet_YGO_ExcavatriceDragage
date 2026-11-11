# orchestrate run r-mucefchv-pw1h7q

- mode: fanout | agent: session-7288ae1e-d1a9-4d02-ab2d-4860f4f49d2b | provider: spawn
- concurrency: 6 | durationMs: 512274 | aborted: false
- startedAt: 2026-09-22T08:15:04.963Z | finishedAt: 2026-09-22T08:23:37.237Z

## Acquisition + synthèse IHM [completed]

La vérification est complète. Voici mon rapport d'audit read-only.

---

# 🕵️ Audit Read-Only — Chaîne `PhaseRotationOk` / `PhaseRotationFault`

## 🧭 Chaîne de production retracée (source de vérité = `CODE/*.st`)

```
[E/S glob.]  PhaseRotationOk_DI : BOOL        (GVL_Device_IO.st:53 / Device.export:195789)
     │
     ├─ PRG_02:190  HwReal.Machine.PhaseRotationOk_DI := PhaseRotationOk_DI;   (image brute)
     │
     └─ PRG_02:446  HwIn.Machine := SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine);  (arbitre UNIQUE)
         │
         ├─ PRG_07:407  PhaseRotationFault := NOT HwIn...                 (IHM)
         ├─ PRG_07:429  Preflight.PhaseRotationOk := HwIn...              (préflight)
         ├─ PRG_04:945/1015  FB_Safety_Winch M1/M2 (PhaseRotationOk := HwIn...)
         └─ PRG_05:479  FB_Safety_Translation M3 (PhaseRotationOk := HwIn...)
```

---

## 📋 Réponse tableau demandée

| # | Point | fichier:ligne réel | Citation courte (copie littérale) | Concl. | Écart vs brief |
|---|---|---|---|---|---|
| 1 | Entrée TOR `PhaseRotationOk_DI` | `PRG_02_Acquisition.st:190` | `HwReal.Machine.PhaseRotationOk_DI         := PhaseRotationOk_DI;` | **VÉRIFIÉ** (existence/affectation) / ⚠️ **écart sur la nature** du point | 🚨 Ligne 190 **n'est PAS une déclaration VAR_INPUT** et elle écrit **`HwReal`**, pas `HwIn` comme annoncé par le brief |
| — | Déclaration brute du TOR | `GVL_Device_IO.st:53` (global, pas VAR_INPUT) ; `Device.export:195789` | `PhaseRotationOk_DI           : BOOL;` | **INDÉTERMINÉ** / constat | PRG_02 a un **VAR_INPUT VIDE** (`:14` *"AUCUNE - PILOTÉ VIA GVL_IHM & GVL_Simulation"*). La source est une **variable E/S globale**, non déclarée dans PRG_02 — le brief parle à tort d'une « déclaration VAR_INPUT » |
| 2 | `GVL_IHM.Commun.PhaseRotationFault` | `ST_CommunHMI.st:18` | `PhaseRotationFault        : BOOL; (* ⚡ Rotation de phase incorrecte — retour unique commun M1/M2/M3` | **VÉRIFIÉ** | Aucun (ligne ~18 exacte) |
| 3 | Génération du fault IHM | `PRG_07_Supervision.st:407` | `GVL_IHM.Commun.PhaseRotationFault        := NOT PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI;` | **VÉRIFIÉ** | Aucun (ligne 407 exacte, source = `HwIn.Machine.PhaseRotationOk_DI`) |
| Pol | Polarité fail-safe TRUE=OK | Conséquent sur toute la chaîne | FB_Safety_Translation:22 `(TRUE = OK)` · FB_Acquisition_Preflight:25 `// Ordre des phases reseau OK` · ST_HwMachine:10 `Contrôle rotation phases élec. OK` | **VÉRIFIÉ** | ⚠️ Le commentaire fail-safe (`TRUE = OK`) n'est **pas** à PRG_02:190 — il est documenté côté FB (`FB_Safety_Translation.st:22`) |
| Prod | Producteur unique ? | `PRG_02:190 → :446 →` consommateurs 407/429/945/1015/479 | Tous lisent `PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI` | **VÉRIFIÉ** | ⚠️ Nuance `FB_SimBench.st:690 Machine.PhaseRotationOk_DI := TRUE` (domaine **simulation HwSim**, alimente l'arbitre SEL — **pas** un second producteur du signal réel) |

---

## 🔍 Détail / analyse par point

### 1. Entrée TOR — `PRG_02_Acquisition.st:190`
Ligne réelle lue (copie littérale) :
```
190: HwReal.Machine.PhaseRotationOk_DI         := PhaseRotationOk_DI;
```
- C'est une **affectation** (opérateur `:=`), pas une déclaration.
- Cible = **`HwReal.Machine`** (image brute), et **non `HwIn`** comme l'affirme le brief. L'image arbitrée `HwIn.Machine` n'est produite qu'à la **ligne 446** via `SEL(...)`.
- **Aucune déclaration `VAR_INPUT`** de `PhaseRotationOk_DI` dans PRG_02 : le bloc `VAR_INPUT` est vide (`:14`). La source brute est une **variable E/S globale** `BOOL` (`GVL_Device_IO.st:53`, mapping physique `Device.export:195789`).
- **Commentaire fail-safe absent à cette ligne.** La polarité `TRUE = OK` est documentée ailleurs : `FB_Safety_Translation.st:22` *(TRUE = OK)*, `FB_Acquisition_Preflight.st:25` *(Ordre des phases reseau OK)*, `ST_HwMachine.st:10`.
→ **Écart de brief** : emplacement et nature du « repère » mal décrits (ce n'est ni une déclaration, ni `HwIn`).

### 2. `PhaseRotationFault` — `ST_CommunHMI.st:18`
```
18:     PhaseRotationFault        : BOOL; (* ⚡ Rotation de phase incorrecte — retour unique commun M1/M2/M3
```
Ligne exacte, type `BOOL`, commentaire de rôle. **VÉRIFIÉ.**

### 3. Génération — `PRG_07_Supervision.st:407`
```
407: GVL_IHM.Commun.PhaseRotationFault        := NOT PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI;
```
Ligne exacte, source exacte `HwIn.Machine.PhaseRotationOk_DI` (image machine arbitrée). **VÉRIFIÉ.**

### ✔️ Polarité fail-safe — **VÉRIFIÉ**
- `HwIn.Machine.PhaseRotationOk_DI = TRUE` ⇔ ordre & présence phases **OK** (négatif-logique capteur).
- `PhaseRotationFault := NOT PhaseRotationOk_DI` ⇒ `PhaseRotationFault = TRUE` ⇔ **défaut** (défaut sur TRUE, cohérent).
- Cohérence avec les FB sécurité : les deux latching `FB_Safety_Winch.st:302` et `FB_Safety_Translation.st:140` utilisent `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN` ⇔ même convention `TRUE = OK`. **Identité de convention, pas d'inversion.**

### ✔️ Producteur unique — **VÉRIFIÉ**
- L'**une et seule** source consommée par IHM et par les FB sécurité est **`PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI`**.
- Cette donnée n'a **qu'un seul producteur/arbitre** : `SEL` en `PRG_02:446`, alimenté en mode réel par `HwReal` (`:190`). **Aucune écriture directe de `HwIn.Machine.PhaseRotationOk_DI` ailleurs** dans le code source.
- `FB_SimBench.st:690` (`Machine.PhaseRotationOk_DI := TRUE`) concerne **`HwSim`** (domaine simulation) — c'est l'entrée alternative de l'arbitre SEL, **pas** un second producteur du signal réel. En mode réel, `MachineInputSourceSimulated=FALSE ⇒ SEL → HwReal` uniquement.

---

## 🚨 Écarts globaux vs brief (à signaler explicitement)

1. **Ligne 190 mal décrite** : c'est une **affectation brute `HwReal`**, pas une déclaration VAR_INPUT, et la structure écrite est **`HwReal`**, pas **`HwIn`**.
2. **Pas de déclaration VAR_INPUT dans PRG_02** : le VAR_INPUT de PRG_02 est **vide** ; `PhaseRotationOk_DI` est une **variable E/S globale** (`GVL_Device_IO.st:53`).
3. **Commentaire fail-safe `'TRUE = ordre & présence phases OK'` absent de :190** — il vit dans les FB (`FB_Safety_Translation.st:22`) et le preflight (`FB_Acquisition_Preflight.st:25`). C'est le **seul** commentaire de polarité explicite du dépôt.

## ✅ Conclusion de conformité ISO 13849 (sur les 3 piliers contrôlés)
- **Polarité fail-safe** : conforme (`TRUE = OK / FALSE = défaut`, cohérente IHM ⇔ FB sécurité). ✅
- **Producteur unique** : conforme — IHM et FB `FB_Safety_Winch`/`FB_Safety_Translation` consomment **la même source** `HwIn.Machine.PhaseRotationOk_DI`. ✅
- **Aucun** chemin alternatif de production de la donnée ni inversion de polarité détecté dans `CODE/` (hors domaine sim légitime).

*Aucun fichier modifié (audit strictement en lecture).*

## FB_Safety_Winch M1/M2 [completed]

Toutes les vérifications faites. Voici mon rapport d'audit lecture seule.

---

## 🎬 Rapport — Audit READ-ONLY `FB_Safety_Winch` / `FB_WinchStateProjection`
**Source de vérité lue** : `CODE/H_TREUILS_BENNE/*.st` (+ `CODE/A_COMMUN/FB_FaultCore.st`, `CODE/M_MAIN/PRG_04_Treuils_Benne.st`, `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/*`, `CODE/J_SUPERVISION/GVL_IHM.st`). Aucun fichier modifié.

---

### 📋 Tableau de synthèse

| Point | fichier:ligne réel | Citation littérale | Concl | Écart au brief |
|---|---|---|---|---|
| **Condition bypass + phase** | `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:302` | `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN` | **VÉRIFIÉ** | Aucun — identique au brief |
| **Latch phase** | `FB_Safety_Winch.st:303-304` | `PhaseRotationFaultLatched := TRUE;` puis `END_IF;` | **VÉRIFIÉ** | Aucun |
| **Cause 4 + Latching** | `FB_Safety_Winch.st:305-306` | L305 `instCauses[4].Active   := PhaseRotationFaultLatched;` / L306 `instCauses[4].Latching := TRUE;` | **VÉRIFIÉ** | ⚠️ Mineur : le commentaire `(* Latching := TRUE *)` n'est **pas** sur la ligne 305 mais est un **assignement séparé ligne 306** |
| **Miroir bit 4** | `FB_Safety_Winch.st:498` | `CausePhaseRotationActive  := instCauses[4].Active;` | **VÉRIFIÉ** | ⚠️ Mineur : la mention `(* bit 4 / 16#0010 *)` n'est **pas présente** sur cette ligne (commentaire absent) |
| **Bypass déclaration** | `FB_Safety_Winch.st:74` | `BypassPhaseRotation             : BOOL := FALSE;   // --> [TST] Bypass defaut rotation phases` | **VÉRIFIÉ** | Aucun — **VAR_INPUT** (interface de bloc, pas d'attribut de niveau d'accès) |
| **Projection M1** | `FB_WinchStateProjection.st:241` | `WinchM1Safety.ErrorPhaseRotation := (SafetyM1.Fault.ErrorId AND 16#0010) <> 0;` | **VÉRIFIÉ** | Aucun |
| **Projection M2** | `FB_WinchStateProjection.st:269` | `WinchM2Safety.ErrorPhaseRotation := (SafetyM2.Fault.ErrorId AND 16#0010) <> 0;` | **VÉRIFIÉ** | Aucun |

---

### 🔑 Réponses analytiques demandées

#### 1. Latching effectif (verrouillé, non réarmable auto) — **VÉRIFIÉ**
- `PhaseRotationFaultLatched` n'est positionné qu'à `TRUE` (cause 4) et **jamais remis à `FALSE` dans l'évaluation des causes** : une fois posé, il reste jusqu'à un front `ResetEdge` (§ FRONTS `FB_Safety_Winch.st:183-197`) ou au tout premier scan (init `:199-216`).
- `BypassGlobal` provoque aussi un RAZ (même bloc). Aucun chemin de réarmement implicite sur la disparition de la cause → **règle métier « Reset = front, pas de redémarrage auto » respectée**. ⚠️ Attention : `BypassGlobal` réarme les latches (RAZ) même sans Reset → un bypass Global actif efface un défaut PhaseRotation non acquitté.

#### 2. Bit utilisé 16#0010 (bit 4) — **VÉRIFIÉ**
- Cohérence complète de la chaîne :
  - Déclaration miroir `FB_Safety_Winch.st:137` : `CausePhaseRotationActive : BOOL; // . [LOC] bit4  Rotation phases (latched)`
  - Mapping bit exact : `FB_FaultCore.st:52-53` : `IF Causes[i].Active THEN Fault.ErrorId := Fault.ErrorId OR SHL(WORD#1, INT_TO_DWORD(i));` → l'index `i=4` pose le bit 4 = `16#0010`.
  - DUT `ST_SafetyWinch.st:30` : `ErrorPhaseRotation: BOOL; (* ... (bit4) *)`
  - Chaîne IHM `ST_Chain_Winch_Safety.st:15` : `Idx312_ErrorPhaseRotation: BOOL; // bit4 ...`
- **C'est le bit 4 / 16#0010**, exactement.

#### 3. Bypasses : entrées contrôlées ou variables persistantes accessibles — **VÉRIFIÉ / nuance**
- `BypassPhaseRotation` et `BypassProcess` sont **des `VAR_INPUT`** de `FB_Safety_Winch` (L74 / L68), par défaut `FALSE`, **sans attribut de niveau d'accès** dans l'interface du FB.
- Raccordement réel (PRG_04) : 
  - `FB_Safety_Winch.st:984` M1 → `GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation`
  - `FB_Safety_Winch.st:1050` M2 → `GVL_IHM.M2TreuilBenne.Bypass.PhaseRotation`
  - `BypassProcess` → OR entre `.Bypass.Process` du treuil et `GVL_IHM.Commun.Bypass.SlackCable` (L974-975 / L1042-1043).
- ⚠️ **Écart doctrinal majeur à signaler** : le struct `ST_BypassWinch.st:7-8` porte la consigne *« actionnable UNIQUEMENT en MAINT_N2, RETAIN, jamais masque les autres défauts »*, **mais** `PRG_04_Treuils_Benne.st:970` indique explicitement : `// Matrice AF-05 §4bis : bypass transmis SANS gate de mode (dérogation MES 2026, tous modes).` → En PLC, **aucun gate logiciel MAINT_N2** sur le chemin `PhaseRotation`/`Process` ; la contrainte N2 est censée être portée par le mot de passe IHM, pas par la logique automate. L'accès se fait par GVL IHM (piloté HMI), pas par variable persistante directe.
- ⚠️ **Effet collatéral** : `BypassProcess` (non `BypassPhaseRotation`) **suffit à neutraliser la cause 4** (`NOT (BypassProcess OR BypassPhaseRotation)`). Un bypass Process actif masque donc aussi le défaut rotation phases.
- ⚠️ **Défaut de redondance** : la protection PhaseRotation dépend uniquement de ce `PhaseRotationOk_DI`, **sans chaîne matérielle indépendante** type AU (cohérent avec `Enable`>`SafeStop`>permit et l'AU seule coupe brutalement — mais à noter : PhaseRotation ne passe **pas** dans `CausesPowerCutOffActive`).

#### 4. Temporisations — **AUCUNE sur le défaut rotation phases**
- **VÉRIFIÉ** : la cause 4 est **instantanée** (pas de `TON` dédié). Le retour `PhaseRotationOk_DI` est mappé **brut** en acquisition (`PRG_02_Acquisition.st:190` : `HwReal.Machine.PhaseRotationOk_DI := PhaseRotationOk_DI;`) → aucune stabilisation/filtre/temporisation avant latch.
- Les TON existants dans le FB ne concernent **pas** la rotation phases : `TonMecaB`/`TonMecaD`/`TonMecaE` = `PostRampTimeout` 3 s (L49), `TonOppositeDirection` = 1 s (L58), `TonNoMovement` = 3 s (L59), `TonRefSettle` = 2 s (L247), `TonStartupWarmup` = 3 s (L219, ne gate que la cause 0).
- ⚠️ **Point ISO 13849** : un défaut de rotation de phases (perte d'une phase, inversion) latch immédiatement, sans temporisation/rejet de transit d'établissement réseau. À challenger selon l'analyse de risques (transitoire d'enchenchement, reprise de phase → possible nuisance sur démarrage nominal).

---

### 🚨 Signalements d'écarts (hors tableau)
1. **Gate MAINT_N2 absent en PLC** sur `PhaseRotation`/`Process` (`PRG_04:970`), alors que la doctrine `ST_BypassWinch.st:7` la requiert — la protection repose sur le mot de passe IHM, pas sur la logique automate (à confirmer avec l'archi sécurité si N2 est un niveau de déverrouillage critique).
2. **`BypassGlobal` réarme les latches** sans front Reset (`FB_Safety_Winch.st:183`) — incluant `PhaseRotationFaultLatched`.
3. **`BypassProcess` neutralise aussi la cause 4** (masquage croisé au-delà du sens « Process »).
4. Aucune temporisation sur la détection rotation phases → latch instantané sur transitoire possible.
5. PhaseRotation **n'arme pas PowerCutOff** (`CausesPowerCutOffActive` L523-525 ne l'inclut pas) → seulement `SafeStop` via le groupe.

Souhaitez-vous que je pousse ces 5 constats en fiche `TROUBLESHOOTING` ou que je documente une demande de clarification (matrice N2) avant tout changement ? **Aucune modification effectuée.**

## FB_Safety_Translation M3 [completed]

Lecture complète effectuée, y compris du socle `FB_FaultCore` (nécessaire pour confirmer la projection bit↔index, non fourni au brief mais requis pour conclure sur le 16#0004). **Aucun fichier modifié** — vérification 100 % read-only.

## 🎬 Bref rappel contexte
Ce bloc est le FB de **sécurité** (`FB_Safety_Translation`), pas un FB de mouvement → sémantique `Enable`/`SafeStop`/`StartStop` s'applique en tant que "surveillance", et l'invariant en-tête (l.8-10) classe **bits 0/1/2 = communication → SafeStop seul, jamais PowerCutOff**.

## 📊 Tableau de vérification

| Point | fichier:ligne réel | Citation littérale | Concl |
|---|---|---|---|
| Condition déclenchement | `CODE/I_TRANSLATION/FB_Safety_Translation.st:140` | `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN` | ✅ **VÉRIFIÉ** — conforme au brief, ligne ~140 exacte |
| Pose du défaut | `...FB_Safety_Translation.st:141` | `PhaseRotationFault := TRUE;` | ✅ **VÉRIFIÉ** — ligne ~141 exacte |
| Projection index→cause | `...FB_Safety_Translation.st:143` | `instCauses[2].Active := PhaseRotationFault;` | ⚠️ **VÉRIFIÉ (écart cosmétique)** — le code existe, mais **sans** le commentaire `(* bit 2 / 16#0004 *)` au bout |
| Déclaration du bypass | `...FB_Safety_Translation.st:43` | `BypassPhaseRotation : BOOL := FALSE; // --> [TST] Bypass défaut rotation phases` | ✅ **VÉRIFIÉ** — ligne ~43 exacte |
| Défaut sur **bit 2 / 16#0004** | `...FB_Safety_Translation.st:143` + `.../A_COMMUN/FB_FaultCore.st:53` | `instCauses[2]…` → `Fault.ErrorId := Fault.ErrorId OR SHL(WORD#1, INT_TO_DWORD(i));` | ✅ **VÉRIFIÉ** — `FB_FaultCore` mappe **index de cause i → bit i** de `ErrorId` (et `LatchedId`, l.77). Index 2 ⇒ `16#0004`. Confirmé aussi par l.60 : `ErrorPhaseRotation … (bit2)` |
| Latching | `...FB_Safety_Translation.st:144` | `instCauses[2].Latching := TRUE;` | ✅ **VÉRIFIÉ** — cause 2 est **latchée** ; le bit resté armé dans `FB_FaultCore` (`Latch[2]`) jusqu'au front Reset (l.41-43) |
| Réarmement / Reset | `...FB_Safety_Translation.st:101-102,110-111,144` | `IF ResetEdge.Q OR BypassGlobal THEN PhaseRotationFault := FALSE;` | ✅ **VÉRIFIÉ** — effacement uniquement sur **front Reset** (`ResetEdge`, l.99-100 → l.101) ou `BypassGlobal`/premier scan. **Pas de redémarrage auto** ; cause réapparue ≠ défaut (re-set conditionnel l.140-142 ne re-pose pas le latche si déjà vrai, cohérent). Conforme principe AGENTS.md `Reset = front` |
| **SafeStop (pas StartStop)** | `...FB_Safety_Translation.st:265` et `:268` | `SafeStop := Fault.Error OR NOT PowerContactorEngaged;` · `PowerCutOff := (Fault.ErrorId AND 16#00F8) <> 16#0000;` | ✅ **VÉRIFIÉ** — `PowerCutOff` masqué sur **16#00F8 (bits 3..7)** ; le bit2 (16#0004) n'y figure **pas** ⇒ bit2 déclenche **SafeStop seul**, cohérent avec l'invariant en-tête (l.8-10 : "les défauts de communication (bits 0/1/2) ne coupent jamais la puissance amont") |
| Type de défaut & projection | `...FB_Safety_Translation.st:272` | `ErrorPhaseRotation := instCauses[2].Active;` | ✅ **VÉRIFIÉ** — type **SafeStop/acquittable** (non-PowerCutOff), exposé en sortie `ErrorPhaseRotation` + via `ST_Fault.ErrorId/LatchedId` bit2 |

## 🚨 Écarts au brief
- 🔸 **Seul écart : cosmétique** — la ligne 143 du brief annonce un commentaire `(* bit 2 / 16#0004 *)` en fin de ligne ; dans le fichier réel la ligne 143 s'arrête à `;` **sans ce commentaire**. Zéro impact fonctionnel : le bit 2 / 16#0004 est établi par la **sémantique d'index** (`FB_FaultCore` l.53) et non par un commentaire. Le brief a probablement été rédigé d'après un état antérieur ou une version annotée.

## 🛡️ Avis expert (ISO 13849)
- **Conception conforme** : cause 2 classée défaut de communication → `SafeStop` seul, **sans** coupure puissance (`PowerCutOff` réservé aux causes physiques bits 3..7). C'est le comportement correct : une erreur de séquence/rotation de phases doit freiner (rampe) mais pas sectionner l'AU.
- **Latching conforme** : acquittement sur **front Reset**, jamais sur disparition de cause → pas de redémarrage automatique, conforme au guardrail AGENTS.md.
- ☝️ **Point de vigilance à challenger** (hors brief, à vérifier terrain) : `PhaseRotationFault` utilise le latching applicatif `instCauses[2].Latching := TRUE` AVEC `FB_FaultCore.Latch[2]` ; le réarmement exige `ResetEdge.Q`. Vérifier que le `Reset` IHM est bien un **front** dédié (l.99-107) et non un niveau maintenu, sinon le défaut "clic" sur phase restera gelé. Le code est correct tel quel.

**Aucun fichier modifié** — vérification read-only, source de vérité `CODE/I_TRANSLATION/FB_Safety_Translation.st`.

## Barrière finale / Q1 sorties [completed]

Trace complete. Aucun fichier modifié (analyse statique READ-ONLY ; je n'ai volontairement **pas** créé de fiche de session troubleshooting, car le gabarit exigé écrirait un fichier — contraire à « Ne modifie AUCUN fichier »). Voici la restitution.

---

# 🔎 Q1 — Chaîne de défaut « rotation de phase » : câblée de bout en bout jusqu'aux sorties physiques ?

**Contexte tracé** : erreur rotation de phase produite par `PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI` (contact NC commun machine) → consommée par les FBs de sécurité M1/M2/M3 → classée **SafeStop ou PowerCutOff** dans chaque FB → gate `/SafeStop` du `FinalInterlockRequest` → **FB interlock de sortie** → ordres contacteurs/frein physiques.

---

## 1. Production du défaut (amont)

| Maillon | Statut | Preuve |
|---|---|---|
| **Production** `PhaseRotationOk_DI` | ✅ VÉRIFIÉ | `CODE/M_MAIN/PRG_02_Acquisition.st:190` `HwReal.Machine.PhaseRotationOk_DI := PhaseRotationOk_DI;` |
| **Classification treuils M1/M2** | ✅ VÉRIFIÉ | `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:302` `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN PhaseRotationFaultLatched := TRUE;` → cause 4 → **SafeStop** (voir ci-dessous) |
| **Classification M3** | ✅ VÉRIFIÉ | `CODE/I_TRANSLATION/FB_Safety_Translation.st:140` `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN PhaseRotationFault := TRUE;` → cause 2 |

---

## 2. Classification : rotation de phase = **SafeStop contrôlé**, jamais PowerCutOff

### M1 / M2 (`FB_Safety_Winch`)
- ✅ VÉRIFIÉ — `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:498` `CausePhaseRotationActive := instCauses[4].Active;`
- ✅ VÉRIFIÉ — SafeStop : `FB_Safety_Winch.st:516-521` : `CausesSafeStopActive := ... OR CausePhaseRotationActive ...` puis `:558` `SafeStop := CausesSafeStopActive OR ...`
- ✅ VÉRIFIÉ — exclu de PowerCutOff : `FB_Safety_Winch.st:523-525` `CausesPowerCutOffActive := CauseMotorThermalActive OR CauseMecaAActive ...` — **pas de rotation de phase**. Conclusion : **SafeStop contrôlé**, pas de coupure de l'AU.
- Confirmation bit 4 : `CODE/H_TREUILS_BENNE/FB_WinchStateProjection.st:241` `WinchM1Safety.ErrorPhaseRotation := (SafetyM1.Fault.ErrorId AND 16#0010) <> 0;` (idem `:269` M2).

### M3 (`FB_Safety_Translation`)
- ✅ VÉRIFIÉ — `FB_Safety_Translation.st:265` `SafeStop := Fault.Error OR NOT PowerContactorEngaged;` (bit2 présent dans ErrorId → SafeStop)
- ✅ VÉRIFIÉ — exclu de PowerCutOff : `FB_Safety_Translation.st:268` `PowerCutOff := (Fault.ErrorId AND 16#00F8) <> 16#0000;` → masque bits 3-7 uniquement ; **bit2 (16#0004) hors coupure AU**.
- Confirmation bit 2 : `CODE/M_MAIN/PRG_05_Translation.st:776` `TranslationSafety.ErrorPhaseRotation := instSafetyTranslationM3.ErrorPhaseRotation;`

✅ **La réaction est bien un SafeStop contrôlé, PAS un PowerCutOff brutal.** L'AU (PowerKeepAlive A/B, contacteur puissance) reste engagé ; seul le mouvement est ramené à zéro.

---

## 3. Router `FinalInterlockRequest.SafeStop` ⬅ FB de sécurité

| Maillon | Statut | Preuve |
|---|---|---|
| **M1** | ✅ VÉRIFIÉ | `PRG_04_Treuils_Benne.st:1062` `SafeStopM1_Raw := SafeStopM1_Raw OR instSafetyWinchM1.SafeStop;` → `:1105` `SafeStopM1_Active := SafeStopM1_Raw OR (CoupledBoth AND SafeStopM2_Raw);` → `:1596` `WinchM1FinalInterlockRequest.SafeStop := SafeStopM1_Active;` |
| **M2** | ✅ VÉRIFIÉ | idem `:1063` / `:1106` / `:1617` |
| **M3** | ✅ VÉRIFIÉ | `PRG_05_Translation.st:511-512` `M3_SafeStop_Aggregate := M3_SafeStop_Active OR instSafetyTranslationM3.SafeStop;` → `:674` `TranslationFinalInterlockRequest.SafeStop := M3_SafeStop_Aggregate;` |

---

## 4. Consommation dans les FB interlock de sortie (barrière finale)

### M1 / M2 — `FB_WinchOutputInterlock` : **SafeStop réellement consommé**
- ✅ VÉRIFIÉ — `PRG_06_Outputs.st:153` `SafeStop := PRG_04_...WinchM1FinalInterlockRequest.SafeStop` (idem `:219` M2).
- ✅ VÉRIFIÉ — dans le FB : `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st:393` `ELSIF SafeStop OR PermitFinalBlocked THEN ...` → `:402-403` `RelayFwd := FALSE; RelayRev := FALSE;` + `:403` `Contactor1..4 := FALSE;` → BrakeCmd : `:487` `BrakeCmd := RelayFwd OR RelayRev;` → retombe à 0.
- ✅ VÉRIFIÉ — sorties physiques M1/M2 : `PRG_06_Outputs.st:369-384` `M1_RelayAscent_RQ := M1RelayFwd; ... M2_BrakeRelease_RQ := M2BrakeCmd;`

### M3 — `FB_TranslationOutputInterlock` : **`SafeStop` déclaré mais NON consommé dans le FB**
- ⚠️ **ÉCART / DOUTE** — `CODE/I_TRANSLATION/FB_TranslationOutputInterlock.st:15` `SafeStop : BOOL;` est le **seul** occurrence du mot dans le fichier : **le FB ne lit jamais son entrée SafeStop**. C'est un **connecteur inerte** (câblé en `PRG_06:438` mais ignoré). La coupure M3 n'est donc **pas** redondée à la barrière finale.
- ✅ La coupure M3 est néanmoins réelle **en amont**, via `FB_Translation` : `PRG_06:442` alimente `BrakeReleaseRequest` et `RequestedDriveControlWord` depuis `instTranslationM3` (PRG_05:678/680), et `FB_Translation` bloque la rampe sur `EffectiveSafeStop` :
  - `CODE/I_TRANSLATION/FB_Translation.st:270` `EffectiveSafeStop := SafeStop OR (ReqTremie AND NOT EffectivePermitM3_Tremie) OR ...`
  - `:277-278` `IF ... OR EffectiveSafeStop ... THEN RampTargetPct := 0.0;` → rampe rapide (`:286` `DecelRate := SEL(EffectiveSafeStop, ...FastRate)`)
  - `:323-329` `RequestedDriveControlWord := 1/2/0` (→ 0 quand le frein n'est plus commandé / `:343` forcé 0 sur `Fault.Error`), frequence rampe `:331` → 0.
  - → sorties physiques `PRG_06:457-459` `M3_BrakeRelease_RQ`, `M3_CommandWord`, `M3_SetpointFrequencyHz` tombent à l'état sûr.

---

## 🔗 Trace complète résumée (nom → nom)

```
PhaseRotationOk_DI (PRG_02:190)
  └─ FB_Safety_Winch M1/M2 (cause4/bit16#0010)  — SafeStop=OUI, PowerCutOff=NON
  │     └─ SafeStopMx_Raw (PRG_04:1062/1063) → SafeStopMx_Active (:1105/1106)
  │           └─ WinchMxFinalInterlockRequest.SafeStop (:1596/1617)
  │                 └─ FB_WinchOutputInterlock.SafeStop (PRG_06:153/219)
  │                       └─ §5 ELSIF SafeStop (:393) → RelayFwd/Rev, Contactor1..4 = FALSE (:402-403)
  │                             └─ BrakeCmd = 0 (:487)
  │                                   └─ Mx_Relay*_RQ, Mx_SpeedContactor_*_DQ, Mx_BrakeRelease_RQ (PRG_06:369-384)
  └─ FB_Safety_Translation M3 (cause2/bit16#0004) — SafeStop=OUI, PowerCutOff=NON
        └─ M3_SafeStop_Aggregate (PRG_05:511-512) → TranslationFinalInterlockRequest.SafeStop (:674)
              └─ a) FB_Translation.EffectiveSafeStop (:270) → rampe rapide → DriveCtrlWord/freq/brake=0 (:277-286,323-343)
              │       └─ M3_CommandWord, M3_SetpointFrequencyHz, M3_BrakeRelease_RQ (PRG_06:457-459)
              └─ b) FB_TranslationOutputInterlock.SafeStop (PRG_06:438) → ⚠️ inerte (jamais lu, FB_Translation...:15)
```

---

## ✅ Conclusion Q1

**VÉRIFIÉ** — la chaîne de défaut rotation de phase est câblée de bout en bout jusqu'aux **sorties physiques** M1/M2/M3, et la réaction est un **SafeStop contrôlé** (rampes → 0, contacteurs/frein retombent, AU engagé) :

- **M1/M2** : VÉRIFIÉ de bout en bout, en double chemin (sécurité + barrière `FB_WinchOutputInterlock`). 
- **M3** : VÉRIFIÉ (coupure effective via `FB_Translation`), **MAIS** la barrière finale `FB_TranslationOutputInterlock` n'est **pas** un niveau de défense indépendant pour SafeStop (entrée inerte).

---

## ⚠️ Écarts au brief & doutes sécurité

1. **[Écart majeur] `SafeStop` inerte dans `FB_TranslationOutputInterlock`** (`CODE/I_TRANSLATION/FB_TranslationOutputInterlock.st:15` — seule occurrence). L'entrée est câblée (`PRG_06:438`) mais jamais lue. Conséquence : en M3, la protection SafeStop (dont rotation phase) repose sur **un seul** mécanisme (`FB_Translation`), sans redondance à la barrière finale contrairement aux treuils. Si le blocage amont venait à faillir (mémorisation d'un sens/consigne), le FB de sortie ne couperait rien. → **À corriger** (consommer `SafeStop` dans le FB, p.ex. en forçant `DriveControlWord := 0; BrakeCmd := FALSE;`).

2. **[Écart mineur] `SafeStop` de `FB_TranslationOutputInterlock` n'apparaît que dans le VAR_INPUT** : la porte de sécurité « SafeStop » n'est pas implémentée dans la logique (`ELSIF`/gate). Vérifier aussi que la machine d'état ne laisse aucun chemin où `DriveControlWord` pourrait rester ≠ 0 hors rampe.

3. **[Point d'attention ISO 13849]** Dans `FB_Safety_Winch`, la **survitesse ne pilote PAS PowerCutOff** (latch dédié `OverspeedFaultLatched` commenté `:451-452`). Hors périmètre Q1 (il s'agit de rotation phase), mais à trancher.

4. **Pas de latch/Reset spécifique rotation phase séparé** : rotation phase est latched avec les autres causes (`Fault.Latched`), réarmement via `FaultMachineReset_IHM` — conforme « pas de redémarrage auto ». RAS.

**Lecture du tracé effectuée sans snapshot PLC** (analyse statique pure, pas d'acquisition `GVL_Troubleshooting` nécessaire) ; rien ne modifie le moindre fichier.

## Bandeau IHM + Preflight [completed]

Vérification READ-ONLY terminée. Aucun fichier modifié. J'ai pu confirmer l'intégralité des chaînes cause→bit→ErrorID→IHM ainsi que le bit preflight.

## ✅ Tableau récapitulatif

| Élément | fichier:ligne réel | Citation littérale | Conclusion | Écart éventuel |
|---|---|---|---|---|
| **M1 ErrorPhaseRotation = bit4** | `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:305` | `instCauses[4].Active := PhaseRotationFaultLatched;` | ✅ **VÉRIFIÉ** | — |
| **M1/M2 ErrorId bit4 = 16#0010** | `CODE/H_TREUILS_BENNE/FB_WinchStateProjection.st:241/269` | `WinchM1Safety.ErrorPhaseRotation := (SafetyM1.Fault.ErrorId AND 16#0010) <> 0;` | ✅ **VÉRIFIÉ** | — |
| **ST winch : Rotation phases (bit4)** | `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_SafetyWinch.st:30` | `ErrorPhaseRotation: BOOL; (* ⚡ Mauvaise rotation de phases électriques (bit4) *)` | ✅ **VÉRIFIÉ** | — |
| **Bandeau `[M1] ErrorID:05`** | `CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st:924-925` | `IF WinchM1Safety.ErrorPhaseRotation AND Vh0800Valid … THEN AlarmArray[…]:= '[M1] ErrorID:05 - rotation phases';` | ✅ **VÉRIFIÉ** | Numéro `05` = cause nº5 (bit4), convention cause 1-based — voir remarque (a) |
| **Bandeau `[M2] ErrorID:05`** | `CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st:972-973` | `[M2] ErrorID:05 - rotation phases` | ✅ **VÉRIFIÉ** | idem M1 |
| **M3 ErrorPhaseRotation = bit2** | `CODE/I_TRANSLATION/FB_Safety_Translation.st:272` + `ST_SafetyTranslation.st:13` | `ErrorPhaseRotation := instCauses[2].Active;` · `(* … rotation de phases électriques (bit2) *)` | ✅ **VÉRIFIÉ** | — |
| **Bandeau `[M3] ErrorID:03`** | `CODE/I_TRANSLATION/…/FB_Hmi_BannerFormatter.st:1011-1012` | `IF TranslationSafety.ErrorPhaseRotation AND Vh0800Valid … [M3] ErrorID:03 - rotation phases` | ✅ **VÉRIFIÉ** | — |
| **Entrée historique M1** | `FB_Hmi_BannerFormatter.st:1191-1192` | `IF (HistoM1 AND 16#0010) … '[HISTO] [M1] ErrorID:05 - rotation phases'` | ✅ **VÉRIFIÉ** | cohérent (bit4 ⇒ 05) |
| **Preflight bit 16#0100 = rotation de phase** | `CODE/A_COMMUN/FB_Acquisition_Preflight.st:76` | `IF NOT PhaseRotationOk THEN PreflightErrorId := PreflightErrorId OR 16#0100;` | ✅ **VÉRIFIÉ** | — |
| **Commentaire bit8 = phases OK** | `FB_Acquisition_Preflight.st:65` | `bit8 phases OK` (`16#0100` = bit 8) | ✅ **VÉRIFIÉ** | — |
| **Câblage preflight PhaseRotationOk** | `CODE/M_MAIN/PRG_07_Supervision.st:429` | `PhaseRotationOk := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,` | ✅ **VÉRIFIÉ** | même source HW que les FB safety |

---

## 🔎 Verdict par question

**1. Cohérence M1/M2 bit4 → ErrorID 05 ?** ✅ **VÉRIFIÉ, cohérent.**
Rotation de phases = `instCauses[4]` (bit4, `16#0010`), et le label IHM `ErrorID:05` correspond bien au bit 4 selon la convention interne « numéro de cause = index + 1 » (bit0→01, bit2→03, bit4→05…).

**2. Cohérence M3 bit2 → ErrorID 03 ?** ✅ **VÉRIFIÉ, cohérent.**
`ErrorPhaseRotation := instCauses[2].Active` (bit2, `16#0004`) → label `ErrorID:03`.

**3. Le bit preflight 16#0100 est-il bien la rotation de phase ?** ✅ **VÉRIFIÉ, oui.**
Posé par `NOT PhaseRotationOk` (ligne 76), documenté `bit8 phases OK` (ligne 65), `16#0100` = bit 8, alimenté par la même entrée HW `PhaseRotationOk_DI` que les FB safety. Pas de collage de bit erroné.

**4. Messages IHM non trompeurs ?** ✅ **VÉRIFIÉ, non trompeurs.** Chaque message porte le préfixe axe `[M1]/[M2]/[M3]` + texte descriptif exact du défaut physique (« rotation phases »).

---

## ⚠️ Écarts au brief / observations (2, à caractère documentaire, non bloquant)

- **(a) « ErrorID:05 » ≠ valeur hex du bitfield.** Le label n'est pas la valeur brute de `ErrorId` (un bit4 = `16#0010`, pas `05`) mais un **numéro de cause 1-based**. Risque de mauvaise lecture « 05 = code hex » par un opérateur/mainteneur. Non trompeur aujourd'hui grâce au texte, mais la convention mérite d'être documentée explicitement comme « numéro de cause », pas « code hex ».
- **(b) Le numéro ErrorID n'est pas global à la machine.** `ErrorID:03` = surchauffe moteur (M1/HISTO, ligne 1186) **mais** rotation phases (M3) ; `ErrorID:05` = rotation phases (M1/M2) **mais** MecaB (M3). Sans le préfixe `[M1]/[M3]` + texte, un affichage « code seul » serait équivoque. Aujourd'hui inoffensif, mais fragilise la maintenance / toute réutilisation en vue diagnostic code seul.

**Aucun écart bloquant ni incohérence sécurité-machine détecté sur les 4 points contrôlés.** Tout est reproductible à la lecture des lignes citées.

## Injectabilité Q2 + CI [completed]

Vérification terminée. Rapport structuré.

---

## 🎬 Briefing session (AGENTS.md) — reprise par sous-agent vérification

Cette mission est une **vérification READ-ONLY** (aucun fichier modifié), hors catalogue de tâches — pas de skill chargée, pas d'action d'écriture. L'autovérification liaison (gates) est **sans objet** puisqu'aucun code n'est produit.

---

## 🎯 Réponse à Q2 — défaut rotation de phase injectable en simulation / CI

### 1. Citation littérale ligne ~690 — ⚠️ **ÉCART au brief confirmé**

Fichier réel lu : `CODE\L_SIMULATION\FB_SimBench.st` (chemin actif, ligne 690) :

```iecst
690: Machine.PhaseRotationOk_DI             := TRUE;
```

> ⚠️ **ÉCART** : la citation du brief `Machine.PhaseRotationOk_DI := TRUE; (* ecrit a CHAQUE scan -> ecrase tout forcage operateur *)` est **FAUSSE au sens littéral** :
> - Le commentaire `(* ecrit a CHAQUE scan -> ecrase tout forcage operateur *)` **n'existe nulle part** dans le fichier (grep `ecrase|CHAQUE|forcage|forcé` → 0 occurrence sur la ligne 690 ; les 3 occ. trouvées sont sans rapport : lignes 88/188/615 d'autres contextes).
> - La ligne réelle est **sans aucun commentaire**, et l'espacement diffère.

> ✅ **Effet décrit** : néanmoins **conforme à la réalité**. La ligne 690 est située dans la **région `§5 Simulation securite et image machine`**, corps du banc **exécuté seulement si `Enable=TRUE`** (garde en tête : `FB_SimBench.st:257 IF NOT Enable THEN ... RETURN;`). **Chaque scan** où la simulation machine est active, `Machine.PhaseRotationOk_DI` est **écrit à `TRUE` sans aucune condition**, donc **écrase tout forçage opérateur** (write IHM/online, bypass). La sémantique (« écrit à chaque scan, écrase tout forçage ») est vraie ; la citation parenthétique ne l'est pas.

### 2. Mécanisme alternatif d'injection — **n'existe pas**

Recherche exhaustive dans toute la chaîne simulation :

| Source | Résultat |
|---|---|
| `CODE\L_SIMULATION\GVL_Simulation.st` | **AUCUNE variable rot. phase**. Le seul stimulus safety machine est `SimSafetyActive` (l.30, gate de **domaine**, pas un stimulus de défaut). Aucun `SimPhaseRotation*`. |
| `CODE\L_SIMULATION\FB_SimBench.st` | Seule occurrence `Machine.PhaseRotationOk_DI := TRUE` à la l.690. **Aucun stimulus, aucun forçage FALSE possible.** |
| Publication HwSim | `PRG_02_Acquisition.st:399 HwSim.Machine := instSimBench.Machine` (image sim = sortie du banc). |
| Sélection HwIn | `PRG_02_Acquisition.st:446 HwIn.Machine := SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine)` — en simu, HwIn.Machine ≡ HwSim.Machine ≡ **TRUE forcé**. |

**Conclusion injection** : pour faire `PhaseRotationOk_DI = FALSE` en simulation, il faudrait **modifier la source `FB_SimBench.st:690`** (changement de code) — aucun mécanisme d'injection existant (pas de variable GVL, pas d'override HwSim, pas de stimulus dédié). Sur machine **réelle** (`SimulationModeActive=FALSE`), le bit vient du DI physique `%IX225.4` via `PRG_02_Acquisition.st:190 HwReal.Machine.PhaseRotationOk_DI := PhaseRotationOk_DI;` — le défaut est alors **physiquement** déclenchable par le relais de surveillance de phases, hors simulation.

### 3. Tests CI existants (`TOOLS/TEST_AUTO_CI/`)

⚠️ Note : les sources de tests actives vivent sous `RESULTS\<domaine>\tests\*.st` (le runner y recopie sources + rapports). Fichiers réels vérifiés :

| Fichier | Injection rot. phase | Niveau |
|---|---|---|
| `RESULTS\I_TRANSLATION\tests\test_fb_safety_translation.st:55-61` | ✅ `fb.PhaseRotationOk := FALSE;` → assert `fb.ErrorPhaseRotation` | **FB unitaire** (réaction du Safety, **pas** le chemin simu) |
| `RESULTS\I_TRANSLATION\tests\test_fb_translation.st:951-956` | ✅ `PhaseRotationOk := FALSE` → assert `ErrorPhaseRotation` | **FB unitaire** M3 |
| `RESULTS\H_TREUILS_BENNE\tests\test_fb_safety_winch.st` | ❌ `PhaseRotationOk` **toujours `TRUE`** (aucun cas défaut, aucun assert `ErrorPhaseRotation`) | **Aucune couverture rot. phase M1/M2** |
| `RESULTS\J_SUPERVISION\tests\test_fb_hmi_bannerformatter.st:147` | ✅ `WinchM1Safety.ErrorPhaseRotation := TRUE` | HMI/bannière (**affichage** uniquement) |
| `RESULTS\L_SIMULATION\tests\test_fb_simbench.st` | ❌ **aucune mention** `Phase/Rotation` | Banc FB_SimBench non couvert |

Aucun test CI ne couvre l'injection du défaut au **niveau simulation/banc** (`HwIn/HwSim.Machine.PhaseRotationOk_DI=FALSE`), et il ne peut pas y en avoir puisque ce chemin est structurellement bloqué par la l.690.

---

## ✅ Conclusion formelle

- 🔴 **Injectable en simulation aujourd'hui : NON.** La ligne `FB_SimBench.st:690` force `TRUE` à chaque scan ; aucune variable `GVL_Simulation`, aucun override `HwSim`, aucun stimulus dédié ne permet de forcer `FALSE` sans modifier la source. (Uniquement déclenchable en réel via `%IX225.4`.)
- 🟠 **Couvert par un test CI existant : OUI — partiellement / indirectement.** Le test unitaire injecte `PhaseRotationOk:=FALSE` **directement à l'entrée du FB Safety M3** (`test_fb_safety_translation.st:55`, `test_fb_translation.st:951`) et vérifie `ErrorPhaseRotation` — cela valide la **réaction du FB**, pas le **chemin d'injection simu**. **Aucun** test CI pour M1/M2 (treuils), **aucun** au niveau banc (`FB_SimBench`).

### Concl : **VÉRIFIÉ**

Toutes les affirmations reposent sur une lecture directe des fichiers cités (`CODE\L_SIMULATION\FB_SimBench.st`, `CODE\L_SIMULATION\GVL_Simulation.st`, `CODE\M_MAIN\PRG_02_Acquisition.st`, tests sous `TOOLS\TEST_AUTO_CI\RESULTS\…\tests\`). **Écart signalé** : le commentaire de la citation du brief n'existe pas dans le code réel (la ligne 690 est sans commentaire), bien que l'effet décrit (« écrit chaque scan, écrase tout forçage ») soit exact.

#### Recommandation (si une injonction est souhaitée pour couvrir M1/M2 + le chemin banc)
Ajouter un stimulus explicite dans `GVL_Simulation` (ex. `SimPhaseRotationFault : BOOL`) consommé par `FB_SimBench.st:690` — décision de **conception/code**, hors périmètre de cette vérification READ-ONLY.

## Verrouillage Q4 Reset [completed]

# 🔍 Q4 — Verrouillage du défaut de rotation de phase (ISO 13849)

Analyse READ-ONLY des 2 FB + socle `FB_FaultCore`. Aucun fichier modifié.

## Éléments clés observés

**Le motif de latch est identique et correct sur les 3 axes** : un `SET` conditionnel uniquement, le `FALSE` n'est atteint QUE sur le front Reset (ou bypass test / 1er scan). **Aucune ligne ne remet le latch à FALSE quand `PhaseRotationOk` repasse à TRUE** — donc pas de réarmement auto.

| Élément | Treuils M1/M2 (`FB_Safety_Winch`) | Translation M3 (`FB_Safety_Translation`) |
|---|---|---|
| Front Reset | `FB_Safety_Winch.st:181` `ResetEdge(CLK := Reset)` → `:183` `IF ResetEdge.Q OR BypassGlobal THEN` | `FB_Safety_Translation.st:99` `ResetEdge(CLK := Reset)` → `:101` `IF ResetEdge.Q OR BypassGlobal THEN` |
| Effacement latch | `:186` `PhaseRotationFaultLatched := FALSE;` | `:102` `PhaseRotationFault := FALSE;` |
| Pose latch (SET seul) | `:302-304` `IF NOT PhaseRotationOk THEN PhaseRotationFaultLatched := TRUE; END_IF;` | `:140-142` `IF NOT PhaseRotationOk THEN PhaseRotationFault := TRUE; END_IF;` |
| Cause → Active/Latching | `:305-306` `instCauses[4].Active := PhaseRotationFaultLatched; .Latching := TRUE;` | `:143-144` `instCauses[2].Active := PhaseRotationFault; .Latching := TRUE;` |
| Ré-alarme socle | `:488` `instFault(Enable, Reset, instCauses)` | `:233` idem |

**Conformité du socle** (`FB_FaultCore.st:37-43, 63-69`) : le latch socle (`Latch[i]`) n'est effacé que sur front Reset (`:41`), et re-armé si la cause est `Active AND Latching` (`:66`). VUE LIVE `Fault.Error = ErrorId<>0` (`:57`) retombe seule ; la LATCHÉE reste posée jusqu'au Reset. Aucun effacement automatique.

**Ordre d'exécution (déterminant pour le re-verrouillage)** : le bloc Reset s'exécute en tête (`§1` FRONTS & REARMENT), l'évaluation cause + ré-pose du latch plus bas dans le même scan (`:301-307`). Donc si `PhaseRotationOk=FALSE` persistant après Reset, le latch est re-posé **immédiatement au scan suivant**.

---

## ✔️ Bilan par axe

| Axe | Latching | Reset (front ?) | Re-verrouillage cause persistante | Risque réarmement auto |
|---|---|---|---|---|
| **M1 / M2** (treuils) | ✅ OUI — `:303` SET seul, `PhaseRotationFaultLatched` | ✅ OUI front `R_TRIG` `:181` → `:186` | ✅ OUI immédiat : cause évaluée chaque scan, re-posée `:302` si `PhaseRotationOk=FALSE` | ✅ **AUCUN** — retour phases→TRUE n'efface pas le latch `:186` |
| **M3** (translation) | ✅ OUI — `:141` SET seul, `PhaseRotationFault` | ✅ OUI front `R_TRIG` `:99` → `:102` | ✅ OUI immédiat : re-posée `:140` si `PhaseRotationOk=FALSE` | ✅ **AUCUN** — `:102` seul point d'effacement |

**Tous les éléments : VÉRIFIÉ** (sources code + socle lus directement, aucune inférence).

---

## ⚠️ Écarts / nuances à signaler

1. **Réarmement via `BypassGlobal` (test)** — `:183` / `:101` : un `ResetEdge.Q OR BypassGlobal` efface le latch. C'est le **bypass de test/troubleshooting uniquement** (`[TST]`, GVL_IHM), pas un réarmement automatique. Normale exploitation : front Reset seul. Conforme.

2. **Pas de temporisation de maintien dédiée au défaut de phase** — contrairement aux autres causes (MecaB `PostRampTimeout`, etc.), la rotation de phase est **latchée directement sans TON/debounce**. Ce n'est pas un défaut (un inverseur de phase est un état matériel stable à corriger), mais note que son déclenchement est immédiat — acceptable en l'absence de transitoires.

3. **M3 : `PowerCutOff` n'inclut PAS la phase (bit2)** — `:268` ne masque que `16#00F8` (bits 3..7). La rotation de phase déclenche **SafeStop seul** (`:265 Fault.Error`), jamais la coupure amont. Conforme à l'invariant d'en-tête `:8-10`. C'est un choix documenté, pas un risque de réarmement.

4. **M1/M2 : la phase (bit4) → SafeStop uniquement, pas `PowerCutOff`** — `:523-525` (`CausesPowerCutOffActive`) n'inclut pas la cause phase. Même logique que M3. Conforme à l'architecture (mou de câble etc.).

5. **Un seul Reset, jamais conditionné** — conforme à `FB_FaultCore.st:11` (§9 std) : le Reset agit même `Enable=FALSE`, donc impossible d'acquitter en éteignant/rantant le FB. ✅

---

## 🎯 Conclusion Q4

**VÉRIFIÉ sur les 3 axes (M1/M2/M3)** : le verrouillage du défaut de rotation de phase est **effectif et sûr** —
- ✅ Pas de réarmement automatique : latch SET-seul, effacé uniquement sur front Reset ;
- ✅ Reset sur **front** (`R_TRIG`), jamais niveau — cause disparue **+ appui conscient** requis ;
- ✅ Re-verrouillage **immédiat** (même scan) si la cause persiste après Reset ;
- ✅ Retour des phases à TRUE **n'efface pas** le latch → absence de déverrouillage parasite.

**Aucun risque de réarmement auto identifié.** Les seuls effacements alternatifs sont le bypass test `BypassGlobal` (délibéré, `[TST]`) et le 1er scan — aucun des deux ne constitue un réarmement automatique en exploitation.

## Bypass encadrement Q5 [completed]

J'ai collecté toutes les preuves nécessaires. Voici mon rapport de vérification READ-ONLY.

---

## 🎬 Audit Q5 — Bypass de rotation de phase (`BypassPhaseRotation`) : ENCADRÉS ?

**Expert ISO 13849 / Sécurité machine | CODESYS 3.5 | 100% lecture, aucun fichier modifié.**
Source de vérité : code versionné `CODE/*.st` (pas d'export Device.export, conforme AGENTS.md).

---

### 📂 Liste exhaustive des usages (7 occurrences)

| # | fichier:ligne | Rôle | Réf |
|---|---|---|---|
| 1 | `CODE\H_TREUILS_BENNE\FB_Safety_Winch.st:74` | Déclaration entrée FB | `BypassPhaseRotation : BOOL := FALSE;` |
| 2 | `CODE\H_TREUILS_BENNE\FB_Safety_Winch.st:302` | Consommation sécurité M1/M2 | « `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN` » |
| 3 | `CODE\I_TRANSLATION\FB_Safety_Translation.st:43` | Déclaration entrée FB | `BypassPhaseRotation : BOOL := FALSE;` |
| 4 | `CODE\I_TRANSLATION\FB_Safety_Translation.st:140` | Consommation sécurité M3 | « `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN` » |
| 5 | `CODE\M_MAIN\PRG_04_Treuils_Benne.st:984` | **Câblage réel M1** | « `BypassPhaseRotation := GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation,` » |
| 6 | `CODE\M_MAIN\PRG_04_Treuils_Benne.st:1050` | Câblage réel M2 | « `BypassPhaseRotation := GVL_IHM.M2TreuilBenne.Bypass.PhaseRotation,` » |
| 7 | `CODE\M_MAIN\PRG_05_Translation.st:496` | Câblage réel M3 | « `BypassPhaseRotation := GVL_IHM.M3Translation.Bypass.PhaseRotation,` » |

**Sens du câblage ligne 984 (VÉRIFIÉ) :** `GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation` est un bit d'échange IHM branché directement sur l'entrée `BypassPhaseRotation` du FB de sécurité `FB_Safety_Winch` (M1). A l'intérieur (ligne 302, Cause 4 « Defaut rotation de phases treuil »), ce bypass **neutralise le latch du défaut de rotation de phases électriques** : la montée/descendre n'est plus bloquée malgré une rotation de phases incorrecte. Même schéma pour M2 (1050) et M3 (496 → FB_Safety_Translation:140). **Il s'agit d'un bypass fonctionnel d'une protection de sécurité.**

---

### 🔍 Sources IHM, niveau d'accès, persistance

**a) Source IHM (VÉRIFIÉ) :** Les bits vivent dans `GVL_IHM` (`ST_WinchHMI.Bypass.PhaseRotation`, `ST_TranslationHMI.Bypass.PhaseRotation`).
- `CODE\J_SUPERVISION\GVL_IHM.st:5` : « Variables **volatiles** d'échange temps-réel (IHM <-> Automate) ».
- Définition : `ST_BypassWinch.st:18` et `ST_BypassTranslation.st:13` (bit `PhaseRotation`).

**b) Niveau d'accès / gate de mode (⚠️ DÉDUIT, point critique) :**
- Doctrine **déclarée** MAINT_N2 : `ST_BypassWinch.st:7` « actionnable **UNIQUEMENT en MAINT_N2**, RETAIN », idem `ST_BypassTranslation.st:4`.
- Mais en **code de câblage**, le bypass PhaseRotation n'est **PAS gate par le mode**, ni sur treuil, ni sur M3 :
  - `PRG_04_Treuils_Benne.st:970-971` : « **bypass transmis SANS gate de mode (dérogation MES 2026, tous modes)** » → M1/M2 PhaseRotation **actif dans tous les modes, y compris production**.
  - `PRG_05_Translation.st:462` définit `M3_MaintN2 := (Auth.Mode = E_Mode.MAINT_N2)`, mais il n'est appliqué **qu'à `BypassLimitSwitch`** (ligne 500 et 603). `BypassPhaseRotation` (ligne 496) est câblé **sans** `M3_MaintN2`. → M3 PhaseRotation **non gate par le mode**.

➡️ **La doctrine « MAINT_N2 uniquement » n'est pas implémentée pour PhaseRotation.** La restriction est laissée au contrôle d'accès de l'écran HMI (hors `CODE/`, pas de `.vis` auditable ici) → **niveau écran INDÉTERMINÉ**, niveau code **sans gate**.

**c) Persistance (VÉRIFIÉ, point positif) :** `Bypass.PhaseRotation` **n'est PAS répliqué en RETAIN**.
- La synchro bidirectionnelle `FB_MirrorBypassRetain` (`PRG_07_Supervision.st:345-355`) ne couvre **QUE** les bits `.Global` (+ LimitLegal/TopLimit*/Cable/SlackCable du Commun). `PhaseRotation` n'y figure pas.
- → **NON persistant** : revient à `FALSE` à chaque coupure/mise sous tension. Défaut de sécurité auto-restauré au boot. ✅

**d) Traçabilité / visibilité IHM (⚠️ DÉDUIT, lacune) :**
- Bandeau opérateur `FB_Hmi_BannerFormatter`: `AnyBypassActive` (ligne 430) → « ATTENTION: Bypass actif » (ligne 441) n'est alimenté **que** par les bits `.Global` (PRG_07:732-737). Un bypass **PhaseRotation granulaire seul ne déclenche AUCUN bandeau**.
- Fiche diag `FB_TroubleshootingView`: remonte `ErrorPhaseRotation` (Idx312/311/312) **mais aucun indicateur de l'état du bypass PhaseRotation** (seuls Global/TopLimit* sont remontés, lignes 211-216).
- → **Aucun signal opérateur dédié** de l'activation de ce bypass.

---

### ⚠️ Risque sécurité & verdict Q5

**Est-ce encadré ? → EN PARTIE (NON pour le gate de mode / visibilité).**

Points **encadrant** (positifs, VÉRIFIÉS) :
- ✅ Non persistant (retour FALSE au boot).
- ✅ Bypass **granulaire** : ne neutralise que la « Cause 4 », n'écrase pas les autres défauts du FB (doctrine respectée dans le mécanisme).
- ✅ Latch conservé : si `PhaseRotationOk` est faux et bypass inactif, le défaut est latched et remonte (PRG_07:407, alarmes BannerFormatter:924/972/1011, diag).

Points **fragiles** (risque, DÉDUIT) :
- ❌ **Aucun gate de mode en code** : bypass PhaseRotation opérable en **production** (M1/M2 « dérogation tous modes » ; M3 sans `M3_MaintN2`). Contradiction avec la doctrine « MAINT_N2 uniquement ».
- ❌ **Silencieux** : neutralise la détection de rotation de phases **sans alerte opérateur dédiée** et sans bandeau (seuls les `.Global` affichent « Bypass actif »).
- ❌ **Contournement possible de la chaîne de protection** si l'écran IHM permet l'écriture (niveau écran INDÉTERMINÉ).

**Risque concret signalé :** un opérateur/mainteneur (ou un défaut de config IHM) peut activer `Bypass.PhaseRotation` et **silencer un défaut de rotation de phases en production** sans visibilité, tout en laissant la machine commandable. Or la rotation de phases protège sens de rotation et santé électrique moteur/transmission : un bypass actif cache un raccordement erroné → dommage mécanique/électrique possible (non-couverture d'un défaut de sécurité).

---

### 🎯 Recommandation (suggestion, hors périmètre READ-ONLY)
Aligner le **code** sur la doctrine : gate `MAINT_N2` sur `BypassPhaseRotation` (comme déjà fait pour `BypassLimitSwitch` M3, `PRG_05:500`), retirer la « dérogation tous modes », et ajouter un indicateur de traçabilité dédié dans `FB_TroubleshootingView` + bandeau dès qu'un bypass granulaire sécurité est actif.

Aucun fichier modifié.

## merge [completed]

# 🎬 SYNTHÈSE UNIQUE — Vérification « rotation de phase » (Q1–Q5)

**Posture** : audit 100% read-only (aucun fichier modifié). Source de vérité = `CODE/*.st` (versionné), jamais `Device.export`. Conformité ISO 13849 contrôlée sur les 3 piliers (polarité fail-safe, producteur unique, latching/reset).

**⚠️ Note de cadrage** : les 8 sous-agents couvrent **Q1, Q2, Q4, Q5**. Aucun sous-agent n'a été dédié à **Q3** explicitement — si le brief prévoit une « Q3 », elle n'a **pas** été traitée (à challenger/relancer).

---

## RÉSUMÉ DES VERDICTS (1 coup d'œil)

| Q | Sujet | Verdict global | Points VÉRIFIÉ | Points DÉDUIT | Points INDÉTERMINÉ |
|---|---|---|---|---|---|
| **Q1** | Chaîne de bout en bout → sorties physiques | ✅ **VÉRIFIÉ** (M1/M2 double chemin ; M3 coupure effective mais barrière finale inerte) | 14 | 0 | 1 (entrée PRG_02 non-VAR_INPUT) |
| **Q2** | Injectable en simulation / CI | 🔴 **VÉRIFIÉ = NON injectable** actuellement | 5 | 1 | 0 |
| **Q4** | Verrouillage / pas de réarmement auto | ✅ **VÉRIFIÉ** sur M1/M2/M3 | 6 | 0 | 0 |
| **Q5** | Bypass encadré | ⚠️ **EN PARTIE** — encadré négatif, **mais gate de mode absent + silencieux** | 4 VÉRIFIÉ / 3 DÉDUIT / 1 INDÉTERMINÉ | 3 | 1 (niveau écran IHM) |

---

## Q1 — Chaîne de bout en bout jusqu'aux sorties physiques

### 1. Production du défaut (amont)

| Maillon | Concl | fichier:ligne réel | Citation littérale |
|---|---|---|---|
| Entrée TOR `PhaseRotationOk_DI` | **VÉRIFIÉ** (existence/affectation) / ⚠️ **écart sur la nature** | `CODE/M_MAIN/PRG_02_Acquisition.st:190` | `HwReal.Machine.PhaseRotationOk_DI := PhaseRotationOk_DI;` |
| Déclaration brute du TOR | **INDÉTERMINÉ / constat** | `CODE/M_MAIN/GVL_Device_IO.st:53` | `PhaseRotationOk_DI : BOOL;` (globales E/S) |
| **Arbitre unique** HwIn | **VÉRIFIÉ** | `PRG_02_Acquisition.st:446` | `HwIn.Machine := SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine);` |

**🚨 Écarts de brief (Q1-amont) :**
1. **Ligne 190 mal décrite** : c'est une **affectation brute `HwReal`**, PAS une déclaration `VAR_INPUT`, et elle écrit **`HwReal`**, pas `HwIn` comme l'annonce le brief.
2. **Pas de déclaration VAR_INPUT dans PRG_02** : le `VAR_INPUT` de PRG_02 est **vide** (`:14` *« AUCUNE - PILOTÉ VIA GVL_IHM & GVL_Simulation »*). La source est une **variable E/S globale** (`GVL_Device_IO.st:53`). Le brief parle à tort de « déclaration VAR_INPUT ».
3. **Commentaire fail-safe absent de :190** : la polarité `TRUE = OK` est documentée côté FB (`FB_Safety_Translation.st:22`, `FB_Acquisition_Preflight.st:25`, `ST_HwMachine.st:10`), pas sur le repère d'acquisition.

---

### 2. Classification M1/M2/M3 — rotation de phase = **SafeStop**, jamais PowerCutOff

**M1 / M2 — `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st`**

| Point | Concl | fichier:ligne | Citation |
|---|---|---|---|
| Condition bypass+phase | **VÉRIFIÉ** | `:302` | `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN` |
| Latch phase | **VÉRIFIÉ** | `:303-304` | `PhaseRotationFaultLatched := TRUE;` · `END_IF;` |
| Cause 4 + latching | **VÉRIFIÉ** | `:305-306` | `instCauses[4].Active := PhaseRotationFaultLatched;` → `instCauses[4].Latching := TRUE;` ⚠️ `Latching` sur ligne séparée |
| Miroir bit 4 | **VÉRIFIÉ** | `:498` | `CausePhaseRotationActive := instCauses[4].Active;` ⚠️ commentaire `(* bit 4 *)` absent de la ligne |
| SafeStop (oui) | **VÉRIFIÉ** | `:516-521`, `:558` | `CausesSafeStopActive := ... OR CausePhaseRotationActive ...` → `SafeStop := ...` |
| Exclu PowerCutOff | **VÉRIFIÉ** | `:523-525` | `CausesPowerCutOffActive := CauseMotorThermalActive OR CauseMecaAActive ...` — **pas de rotation de phase** |

**M3 — `CODE/I_TRANSLATION/FB_Safety_Translation.st`**

| Point | Concl | fichier:ligne | Citation |
|---|---|---|---|
| Condition déclenchement | **VÉRIFIÉ** | `:140` | `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN` |
| Pose défaut | **VÉRIFIÉ** | `:141` | `PhaseRotationFault := TRUE;` |
| Index→cause bit2 | **VÉRIFIÉ** (écart cosmétique) | `:143` | `instCauses[2].Active := PhaseRotationFault;` — ⚠️ **sans** `(* bit 2 / 16#0004 *)` |
| Latching | **VÉRIFIÉ** | `:144` | `instCauses[2].Latching := TRUE;` |
| SafeStop (oui) | **VÉRIFIÉ** | `:265` | `SafeStop := Fault.Error OR NOT PowerContactorEngaged;` |
| Exclu PowerCutOff | **VÉRIFIÉ** | `:268` | `PowerCutOff := (Fault.ErrorId AND 16#00F8) <> 16#0000;` → bit2 **hors** coupure AU |

**Socle bit↔index (`CODE/A_COMMUN/FB_FaultCore.st`)** — requis pour confirmer la projection :
- **VÉRIFIÉ** `:52-53` → `Fault.ErrorId := Fault.ErrorId OR SHL(WORD#1, INT_TO_DWORD(i));` → index i ⇒ bit i (M1/M2 index 4 ⇒ `16#0010` ; M3 index 2 ⇒ `16#0004`).
- **VÉRIFIÉ** `:77` mapping `LatchedId` parallèle.

**Bit utilisés — VÉRIFIÉ sur toute la chaîne :**
- M1/M2 `16#0010` : `FB_Safety_Winch.st:137` (déclaration miroir `bit4`), `FB_WinchStateProjection.st:241/269`, `ST_SafetyWinch.st:30` `(* (bit4) *)`, `ST_Chain_Winch_Safety.st:15` `Idx312 ... // bit4`.
- M3 `16#0004` : `ST_SafetyTranslation.st:13` `(* (bit2) *)`, `PRG_05_Translation.st:776` `TranslationSafety.ErrorPhaseRotation := instSafetyTranslationM3.ErrorPhaseRotation;`.

---

### 3. Routeur `FinalInterlockRequest.SafeStop` ⬅ FB sécurité

| Axe | Concl | fichier:ligne | Citation |
|---|---|---|---|
| M1 | **VÉRIFIÉ** | `PRG_04_Treuils_Benne.st:1062,1105,1596` | `SafeStopM1_Raw := SafeStopM1_Raw OR instSafetyWinchM1.SafeStop;` → `SafeStopM1_Active := ...` → `WinchM1FinalInterlockRequest.SafeStop := SafeStopM1_Active;` |
| M2 | **VÉRIFIÉ** | `:1063,1106,1617` | idem M1 |
| M3 | **VÉRIFIÉ** | `PRG_05_Translation.st:511-512,674` | `M3_SafeStop_Aggregate := M3_SafeStop_Active OR instSafetyTranslationM3.SafeStop;` → `TranslationFinalInterlockRequest.SafeStop := ...` |

---

### 4. Barrière finale (sorties physiques)

**M1/M2 — `FB_WinchOutputInterlock` : SafeStop RÉELLEMENT consommé ✅**

| Point | Concl | fichier:ligne | Citation |
|---|---|---|---|
| Câblage entrée | **VÉRIFIÉ** | `PRG_06_Outputs.st:153/219` | `SafeStop := PRG_04_...WinchM1FinalInterlockRequest.SafeStop` |
| Consommation | **VÉRIFIÉ** | `FB_WinchOutputInterlock.st:393` | `ELSIF SafeStop OR PermitFinalBlocked THEN ...` |
| Sorties coupées | **VÉRIFIÉ** | `:402-403,487` | `RelayFwd := FALSE; RelayRev := FALSE; Contactor1..4 := FALSE;` → `BrakeCmd := RelayFwd OR RelayRev;` (→0) |
| Physiques | **VÉRIFIÉ** | `PRG_06_Outputs.st:369-384` | `M1_RelayAscent_RQ := M1RelayFwd; ... M2_BrakeRelease_RQ := M2BrakeCmd;` |

**M3 — `FB_TranslationOutputInterlock` : 🚨 `SafeStop` déclaré mais INCERTE dans le FB**

| Point | Concl | fichier:ligne | Citation |
|---|---|---|---|
| Déclaration | **VÉRIFIÉ (écart)** | `FB_TranslationOutputInterlock.st:15` | `SafeStop : BOOL;` — **seule** occurrence du mot dans le fichier ; **le FB ne lit jamais son entrée SafeStop** (connecteur inerte) |
| Coupure M3 réelle en amont | **VÉRIFIÉ** (via `FB_Translation`) | `FB_Translation.st:270-343` | `EffectiveSafeStop := SafeStop OR ...` → `RampTargetPct := 0.0; DecelRate := SEL(EffectiveSafeStop,...FastRate)` → `RequestedDriveControlWord` 1/2/0 |
| Sorties physiques M3 | **VÉRIFIÉ** | `PRG_06:457-459` | `M3_BrakeRelease_RQ, M3_CommandWord, M3_SetpointFrequencyHz` → état sûr |

**🚨 Écarts de brief / doutes sécurité (Q1, barrière finale) :**
1. **[Écart MAJEUR] `SafeStop` inerte dans `FB_TranslationOutputInterlock`** (`:15` — seule occurrence). L'entrée est câblée (`PRG_06:438`) mais **jamais lue**. Conséquence : en M3, la protection SafeStop (dont rotation de phase) repose sur **un seul** mécanisme (`FB_Translation`), **sans redondance** à la barrière finale — contrairement aux treuils. Si le blocage amont faillit, le FB de sortie ne couperait rien. → **À corriger** (consommer `SafeStop`, p.ex. forcer `DriveControlWord := 0; BrakeCmd := FALSE;`).

**🎯 Conclusion Q1 : VÉRIFIÉ** — chaîne câblée de bout en bout jusqu'aux sorties physiques M1/M2/M3 ; réaction = **SafeStop contrôlé** (rampes→0, contacteurs/frein retombent, AU engagé, **PAS de PowerCutOff** brutal). M1/M2 en **double chemin** (sécurité + barrière). M3 effectif via `FB_Translation` **MAIS barrière finale non indépendante** (écart majeur ci-dessus).

---

## Q2 — Injectable en simulation / couverture CI

### 1. Citation ligne 690 — ⚠️ ÉCART au brief **confirmé**

| Point | Concl | fichier:ligne | Citation |
|---|---|---|---|
| Forçage sim chaque scan | **VÉRIFIÉ (effet)** | `CODE/L_SIMULATION/FB_SimBench.st:690` | `Machine.PhaseRotationOk_DI := TRUE;` |
| Commentaire cité | ❌ **ÉCART** | — | Le commentaire `(* ecrit a CHAQUE scan -> ecrase tout forcage operateur *)` **n'existe nulle part** (grep `ecrase|CHAQUE|forcage` → 0 sur l.690). La ligne réelle est **sans commentaire**, espacement différent. |

✅ **Effet décrit conforme à la réalité** : l.690 est dans `§5 Simulation securite et image machine`, exécutée seulement si `Enable=TRUE` (`:257 IF NOT Enable THEN ... RETURN;`). Chaque scan sim actif, `Machine.PhaseRotationOk_DI` écrit `TRUE` sans condition → **écrase tout forçage opérateur**. La sémantique est vraie ; la citation parenthétique ne l'est pas.

### 2. Mécanisme alternatif d'injection — **N'existe pas** 🔴

| Source | Concl | Preuve |
|---|---|---|
| `GVL_Simulation.st` | **VÉRIFIÉ (aucun stimulus)** | Aucune variable rot. phase ; seul `SimSafetyActive` (l.30, gate de **domaine**, pas stimulus de défaut) |
| `FB_SimBench.st` | **VÉRIFIÉ (unique occurrence)** | Seule l.690 `Machine.PhaseRotationOk_DI := TRUE` — aucun stimulus/forçage FALSE possible |
| Publication HwSim | **VÉRIFIÉ** | `PRG_02_Acquisition.st:399` `HwSim.Machine := instSimBench.Machine` |
| Sélection HwIn | **VÉRIFIÉ** | `PRG_02:446` SEL → en sim, HwIn.Machine ≡ HwSim.Machine ≡ TRUE forcé |

**→ Injectable aujourd'hui : NON.** Pour forcer FALSE il faudrait **modifier la source `FB_SimBench.st:690`**. En réel (`SimulationModeActive=FALSE`), le bit vient du DI physique `%IX225.4` via `PRG_02:190`.

### 3. Couverture CI (`RESULTS/<domaine>/tests/*.st`) — **partielle / pas le chemin simu**

| Test | Couverture rot. phase | Niveau |
|---|---|---|
| `RESULTS/I_TRANSLATION/tests/test_fb_safety_translation.st:55-61` | ✅ `fb.PhaseRotationOk := FALSE` → assert `ErrorPhaseRotation` | FB unitaire Safety M3 (**réaction**, pas chemin simu) |
| `RESULTS/I_TRANSLATION/tests/test_fb_translation.st:951-956` | ✅ `PhaseRotationOk := FALSE` → assert `ErrorPhaseRotation` | FB unitaire M3 |
| `RESULTS/H_TREUILS_BENNE/tests/test_fb_safety_winch.st` | ❌ `PhaseRotationOk` **toujours TRUE**, aucun cas défaut | **Aucune couverture rot. phase M1/M2** |
| `RESULTS/J_SUPERVISION/tests/test_fb_hmi_bannerformatter.st:147` | ✅ `WinchM1Safety.ErrorPhaseRotation := TRUE` | HMI/bannière (affichage seul) |
| `RESULTS/L_SIMULATION/tests/test_fb_simbench.st` | ❌ aucune mention `Phase/Rotation` | Banc FB_SimBench non couvert |

**🎯 Conclusion Q2 : VÉRIFIÉ** — simulation injectable **NON** (structurellement bloqué par l.690). Écart de brief : commentaire cité inexistant. Recommandation si injonction souhaitée : ajouter `SimPhaseRotationFault : BOOL` dans `GVL_Simulation`, consommé par `FB_SimBench.st:690` (décision de conception, hors périmètre READ-ONLY).

---

## Q4 — Verrouillage & pas de réarmement auto (ISO 13849)

**Motif identique et correct sur les 3 axes** : `SET` conditionnel seul, `FALSE` atteint **uniquement** sur front Reset (ou bypass test / 1er scan). Aucune ligne ne remet le latch à FALSE quand `PhaseRotationOk` repasse TRUE.

| Élément | M1/M2 (`FB_Safety_Winch`) | M3 (`FB_Safety_Translation`) |
|---|---|---|
| Front Reset | `:181` `ResetEdge(CLK := Reset)` → `:183` `IF ResetEdge.Q OR BypassGlobal THEN` | `:99` → `:101` idem |
| Effacement latch | `:186` `PhaseRotationFaultLatched := FALSE;` | `:102` `PhaseRotationFault := FALSE;` |
| Pose (SET seul) | `:302-304` `IF NOT PhaseRotationOk THEN PhaseRotationFaultLatched := TRUE; END_IF;` | `:140-142` idem |
| Cause→Active/Latching | `:305-306` `instCauses[4]...Latching := TRUE` | `:143-144` `instCauses[2]...Latching := TRUE` |

**Socle `FB_FaultCore.st` : VÉRIFIÉ** — `Latch[i]` effacé que sur front Reset (`:41`), ré-armé si cause `Active AND Latching` (`:66`). Un seul Reset jamais conditionné (agit même `Enable=FALSE`, `:11`) — **impossible d'acquitter en éteignant/rantant le FB**.

**Ordre d'exécution (re-verrouillage) : VÉRIFIÉ** — le bloc Reset (`§1 FRONTS`) s'exécute en tête, l'évaluation cause + re-pose plus bas dans le même scan. Si cause persistante après Reset ⇒ **re-posée immédiatement au scan suivant**.

**🎯 Conclusion Q4 : VÉRIFIÉ sur les 3 axes.**
- ✅ Pas de réarmement auto (SET-seul, effacé sur front Reset uniquement)
- ✅ Reset sur **front** (`R_TRIG`), jamais niveau — cause disparue + appui conscient
- ✅ Re-verrouillage immédiat si cause persiste
- ✅ Retour phases→TRUE **n'efface pas** le latch
- ⚠️ Nuances : `BypassGlobal` (test `[TST]`) efface les latches sans Reset ; pas de TON/débounce dédié au défaut de phase (déclenchement immédiat, acceptable hors transitoires) — aucun des deux n'est un réarmement auto en exploitation.

---

## Q5 — Bypass de rotation de phase (`BypassPhaseRotation`) : encadré ?

### Liste exhaustive des 7 occurrences

| # | fichier:ligne | Rôle | Citation |
|---|---|---|---|
| 1 | `FB_Safety_Winch.st:74` | Déclaration entrée FB M1/M2 | `BypassPhaseRotation : BOOL := FALSE;` |
| 2 | `FB_Safety_Winch.st:302` | Consommation sécurité M1/M2 | `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN` |
| 3 | `FB_Safety_Translation.st:43` | Déclaration entrée FB M3 | `BypassPhaseRotation : BOOL := FALSE;` |
| 4 | `FB_Safety_Translation.st:140` | Consommation sécurité M3 | `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN` |
| 5 | `PRG_04_Treuils_Benne.st:984` | Câblage réel M1 | `BypassPhaseRotation := GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation,` |
| 6 | `PRG_04_Treuils_Benne.st:1050` | Câblage réel M2 | `BypassPhaseRotation := GVL_IHM.M2TreuilBenne.Bypass.PhaseRotation,` |
| 7 | `PRG_05_Translation.st:496` | Câblage réel M3 | `BypassPhaseRotation := GVL_IHM.M3Translation.Bypass.PhaseRotation,` |

### 3 dimensions d'encadrement

**a) Source / persistance — VÉRIFIÉ (point positif)**
- `GVL_IHM.st:5` : « Variables **volatiles** d'échange temps-réel (IHM <-> Automate) ».
- `FB_MirrorBypassRetain` (`PRG_07_Supervision.st:345-355`) ne réplique en RETAIN **QUE** `.Global` + LimitLegal/TopLimit*/Cable/SlackCable. **`PhaseRotation` n'y figure pas → NON persistant, retour FALSE au boot.** ✅

**b) Niveau d'accès / gate de mode — ⚠️ DÉDUIT, point critique**
- Doctrine déclarée MAINT_N2 : `ST_BypassWinch.st:7` « actionnable **UNIQUEMENT en MAINT_N2**, RETAIN », idem `ST_BypassTranslation.st:4`.
- **Mais en code** : `PRG_04:970-971` « **bypass transmis SANS gate de mode (dérogation MES 2026, tous modes)** » → M1/M2 actif en **production**. Et `PRG_05_Translation.st:462` définit `M3_MaintN2` mais ne l'applique **qu'à `BypassLimitSwitch`** (`:500`,`:603`), **pas** à `BypassPhaseRotation` (`:496`).
- ➡️ **La doctrine « MAINT_N2 uniquement » n'est PAS implémentée pour PhaseRotation en code.** La restriction est laissée au **contrôle d'accès écran IHM** → **niveau écran INDÉTERMINÉ**, niveau code **sans gate**.

**c) Visibilité / traçabilité IHM — ⚠️ DÉDUIT, lacune**
- `FB_Hmi_BannerFormatter` : `AnyBypassActive` (`:430`) → « ATTENTION: Bypass actif » (`:441`) alimenté **que** par `.Global` (`PRG_07:732-737`). **Un bypass PhaseRotation granulaire seul ne déclenche aucun bandeau.**
- `FB_TroubleshootingView` : remonte `ErrorPhaseRotation` (Idx312/311/312) **mais aucun indicateur de l'état du bypass PhaseRotation** (seuls Global/TopLimit* remontés, `:211-216`).
- ➡️ **Aucun signal opérateur dédié** de l'activation de ce bypass (**silencieux**).

**🎯 Conclusion Q5 : EN PARTIE (NON pour gate de mode / visibilité).**

| Type | Verdict | Détail |
|---|---|---|
| Non persistant (boot→FALSE) | ✅ **VÉRIFIÉ** | `FB_MirrorBypassRetain` n'inclut pas PhaseRotation |
| Bypass granulaire (cause 4 seule) | ✅ **VÉRIFIÉ** | n'écrase que `NOT (BypassProcess OR BypassPhaseRotation)` |
| Latch conservé quand bypass inactif | ✅ **VÉRIFIÉ** | `PRG_07:407`, BannerFormatter `:924/972/1011` |
| **Gate de mode en code** | ❌ **DÉDUIT (absent)** | `PRG_04:970` « tous modes » ; M3 sans `M3_MaintN2` |
| **Alerte opérateur / bandeau dédié** | ❌ **DÉDUIT (absent)** | seuls `.Global` alimentent le bandeau |
| **Niveau écran IHM (maj)** | ⚠️ **INDÉTERMINÉ** | hors `CODE/`, pas de `.vis` auditable |

**🚨 Risque sécurité signalé :** opérateur/mainteneur (ou config IHM) peut activer `Bypass.PhaseRotation` et **silencer un défaut de rotation de phases en production sans visibilité**, machine restant commandable — cache un raccordement erroné → dommage mécanique/électrique possible. Deux écarts collatéraux : `BypassProcess` **suffit** à neutraliser la cause 4 (masquage croisé) ; rotation de phase **n'arme pas PowerCutOff** (`CausesPowerCutOffActive` `:523-525` l'exclut → seulement SafeStop).

---

## ÉCARTS AU BRIEF — INVENTAIRE COMPLET

| # | Sévérité | Écart | Preuve (fichier:ligne) |
|---|---|---|---|
| 1 | 🚨 Majeur | `SafeStop` **inerte** dans `FB_TranslationOutputInterlock` (jamais lu) → M3 sans redondance barrière finale | `FB_TranslationOutputInterlock.st:15` (seule occurrence), câblé `PRG_06:438` |
| 2 | Modéré | Ligne 190 **mal décrite** : affectation brute `HwReal`, pas déclaration `VAR_INPUT`, pas `HwIn` | `PRG_02_Acquisition.st:190` |
| 3 | Modéré | Pas de `VAR_INPUT` dans PRG_02 (vide `:14`) ; source = variable E/S globale | `GVL_Device_IO.st:53` |
| 4 | Modéré | **Gate MAINT_N2 absent en code** pour PhaseRotation, contrairement doctrine `ST_BypassWinch.st:7` | `PRG_04:970` (« tous modes »), `PRG_05:496` (sans `M3_MaintN2`) |
| 5 | Modéré | **Bypass silencieux** : aucun bandeau ni indicateur diag dédié | `FB_Hmi_BannerFormatter:430/441`, `FB_TroubleshootingView:211-216` |
| 6 | Faible (cosmétique) | Commentaire `(* bit 2 / 16#0004 *)` absent en fin de l.143 | `FB_Safety_Translation.st:143` |
| 7 | Faible (cosmétique) | Commentaire `(* bit 4 / 16#0010 *)` absent sur l.305/498 | `FB_Safety_Winch.st:305,498` |
| 8 | Faible | Citation brief `(* ecrit a CHAQUE scan... *)` **inexistante** dans le code (l.690 sans commentaire) | `FB_SimBench.st:690` |
| 9 | Faible | Label `ErrorID:05` = numéro de cause 1-based, **pas** valeur hex (bit4=`16#0010`, pas 05) — convention à documenter | `FB_Hmi_BannerFormatter.st:924-925/972-973` |
| 10 | Faible | ErrorID non global à la machine (`03`=surchauffe M1 mais rot. phases M3) — sans préfixe axe + texte, équivoque | BannerFormatter |
| 11 | Faible | `BypassGlobal` réarme les latches sans Reset ; `BypassProcess` suffit à masquer cause 4 | `FB_Safety_Winch.st:183,302` |
| 12 | Faible | Commentaire fail-safe `TRUE = OK` absent de :190 — vit dans les FB | `FB_Safety_Translation.st:22`, `FB_Acquisition_Preflight.st:25` |

---

## RECOMMANDATIONS (hors périmètre READ-ONLY, à valider par huain)

1. **[Correctif prioritaire]** Consommer `SafeStop` dans `FB_TranslationOutputInterlock` (forcer `DriveControlWord := 0; BrakeCmd := FALSE;`) pour redonder la protection M3 à la barrière finale.
2. **[Conformité]** Aligner le code sur la doctrine : gate `M3_MaintN2` sur `BypassPhaseRotation` (+ revoir « dérogation tous modes » M1/M2 `PRG_04:970`).
3. **[Visibilité]** Alimenter un bandeau / indicateur dédié à l'activation de `Bypass.PhaseRotation`.
4. **[Couverture test]** Ajouter un stimulus `SimPhaseRotationFault` dans `GVL_Simulation` pour rendre le chemin sim injectable + couvrir M1/M2 (`test_fb_safety_winch.st`) et le banc (`test_fb_simbench.st`).
5. **[Documentation]** Documenter la convention « ErrorID = numéro de cause 1-based, pas hex ».

---

**Aucun fichier modifié** (mission de vérification 100% read-only). Toutes les preuves citées ci-dessus proviennent d'une lecture directe des fichiers `CODE/*.st` listés.

## summary

合并结果：# 🎬 SYNTHÈSE UNIQUE — Vérification « rotation de phase » (Q1–Q5)

**Posture** : audit 100% read-only (aucun fichier modifié). Source de vérité = `CODE/*.st` (versionné), jamais `Device.export`. Conformité ISO 13849 contrôlée sur les 3 piliers (polarité fail-safe, producteur unique, latching/reset).

**⚠️ Note de cadrage** : les 8 sous-agents couvrent **Q1, Q2, Q4, Q5**. Aucun sous-agent n'a été dédié à **Q3** explicitement — si le brief prévoit une « Q3 », elle n'a **pas** été traitée (à challenger/relancer).

---

## RÉSUMÉ DES VERDICTS (1 coup d'œil)

| Q | Sujet | Verdict global | Points VÉRIFIÉ | Points DÉDUIT | Points INDÉTERMINÉ |
|---|---|---|---|---|---|
| **Q1** | Chaîne de bout en bout → sorties physiques | ✅ **VÉRIFIÉ** (M1/M2 double chemin ; M3 coupure effective mais barrière finale inerte) | 14 | 0 | 1 (entrée PRG_02 non-VAR_INPUT) |
| **Q2** | Injectable en simulation / CI | 🔴 **VÉRIFIÉ = NON injectable** actuellement | 5 | 1 | 0 |
| **Q4** | Verrouillage / pas de réarmement auto | ✅ **VÉRIFIÉ** sur M1/M2/M3 | 6 | 0 | 0 |
| **Q5** | Bypass encadré | ⚠️ **EN PARTIE** — encadré négatif, **mais gate de mode absent + silencieux** | 4 VÉRIFIÉ / 3 DÉDUIT / 1 INDÉTERMINÉ | 3 | 1 (niveau écran IHM) |

---

## Q1 — Chaîne de bout en bout jusqu'aux sorties physiques

### 1. Production du défaut (amont)

| Maillon | Concl | fichier:ligne réel | Citation littérale |
|---|---|---|---|
| Entrée TOR `PhaseRotationOk_DI` | **VÉRIFIÉ** (existence/affectation) / ⚠️ **écart sur la nature** | `CODE/M_MAIN/PRG_02_Acquisition.st:190` | `HwReal.Machine.PhaseRotationOk_DI := PhaseRotationOk_DI;` |
| Déclaration brute du TOR | **INDÉTERMINÉ / constat** | `CODE/M_MAIN/GVL_Device_IO.st:53` | `PhaseRotationOk_DI : BOOL;` (globales E/S) |
| **Arbitre unique** HwIn | **VÉRIFIÉ** | `PRG_02_Acquisition.st:446` | `HwIn.Machine := SEL(MachineInputSourceSimulated, HwReal.Machine, HwSim.Machine);` |

**🚨 Écarts de brief (Q1-amont) :**
1. **Ligne 190 mal décrite** : c'est une **affectation brute `HwReal`**, PAS une déclaration `VAR_INPUT`, et elle écrit **`HwReal`**, pas `HwIn` comme l'annonce le brief.
2. **Pas de déclaration VAR_INPUT dans PRG_02** : le `VAR_INPUT` de PRG_02 est **vide** (`:14` *« AUCUNE - PILOTÉ VIA GVL_IHM & GVL_Simulation »*). La source est une **variable E/S globale** (`GVL_Device_IO.st:53`). Le brief parle à tort de « déclaration VAR_INPUT ».
3. **Commentaire fail-safe absent de :190** : la polarité `TRUE = OK` est documentée côté FB (`FB_Safety_Translation.st:22`, `FB_Acquisition_Preflight.st:25`, `ST_HwMachine.st:10`), pas sur le repère d'acquisition.

---

### 2. Classification M1/M2/M3 — rotation de phase = **SafeStop**, jamais PowerCutOff

**M1 / M2 — `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st`**

| Point | Concl | fichier:ligne | Citation |
|---|---|---|---|
| Condition bypass+phase | **VÉRIFIÉ** | `:302` | `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN` |
| Latch phase | **VÉRIFIÉ** | `:303-304` | `PhaseRotationFaultLatched := TRUE;` · `END_IF;` |
| Cause 4 + latching | **VÉRIFIÉ** | `:305-306` | `instCauses[4].Active := PhaseRotationFaultLatched;` → `instCauses[4].Latching := TRUE;` ⚠️ `Latching` sur ligne séparée |
| Miroir bit 4 | **VÉRIFIÉ** | `:498` | `CausePhaseRotationActive := instCauses[4].Active;` ⚠️ commentaire `(* bit 4 *)` absent de la ligne |
| SafeStop (oui) | **VÉRIFIÉ** | `:516-521`, `:558` | `CausesSafeStopActive := ... OR CausePhaseRotationActive ...` → `SafeStop := ...` |
| Exclu PowerCutOff | **VÉRIFIÉ** | `:523-525` | `CausesPowerCutOffActive := CauseMotorThermalActive OR CauseMecaAActive ...` — **pas de rotation de phase** |

**M3 — `CODE/I_TRANSLATION/FB_Safety_Translation.st`**

| Point | Concl | fichier:ligne | Citation |
|---|---|---|---|
| Condition déclenchement | **VÉRIFIÉ** | `:140` | `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN` |
| Pose défaut | **VÉRIFIÉ** | `:141` | `PhaseRotationFault := TRUE;` |
| Index→cause bit2 | **VÉRIFIÉ** (écart cosmétique) | `:143` | `instCauses[2].Active := PhaseRotationFault;` — ⚠️ **sans** `(* bit 2 / 16#0004 *)` |
| Latching | **VÉRIFIÉ** | `:144` | `instCauses[2].Latching := TRUE;` |
| SafeStop (oui) | **VÉRIFIÉ** | `:265` | `SafeStop := Fault.Error OR NOT PowerContactorEngaged;` |
| Exclu PowerCutOff | **VÉRIFIÉ** | `:268` | `PowerCutOff := (Fault.ErrorId AND 16#00F8) <> 16#0000;` → bit2 **hors** coupure AU |

**Socle bit↔index (`CODE/A_COMMUN/FB_FaultCore.st`)** — requis pour confirmer la projection :
- **VÉRIFIÉ** `:52-53` → `Fault.ErrorId := Fault.ErrorId OR SHL(WORD#1, INT_TO_DWORD(i));` → index i ⇒ bit i (M1/M2 index 4 ⇒ `16#0010` ; M3 index 2 ⇒ `16#0004`).
- **VÉRIFIÉ** `:77` mapping `LatchedId` parallèle.

**Bit utilisés — VÉRIFIÉ sur toute la chaîne :**
- M1/M2 `16#0010` : `FB_Safety_Winch.st:137` (déclaration miroir `bit4`), `FB_WinchStateProjection.st:241/269`, `ST_SafetyWinch.st:30` `(* (bit4) *)`, `ST_Chain_Winch_Safety.st:15` `Idx312 ... // bit4`.
- M3 `16#0004` : `ST_SafetyTranslation.st:13` `(* (bit2) *)`, `PRG_05_Translation.st:776` `TranslationSafety.ErrorPhaseRotation := instSafetyTranslationM3.ErrorPhaseRotation;`.

---

### 3. Routeur `FinalInterlockRequest.SafeStop` ⬅ FB sécurité

| Axe | Concl | fichier:ligne | Citation |
|---|---|---|---|
| M1 | **VÉRIFIÉ** | `PRG_04_Treuils_Benne.st:1062,1105,1596` | `SafeStopM1_Raw := SafeStopM1_Raw OR instSafetyWinchM1.SafeStop;` → `SafeStopM1_Active := ...` → `WinchM1FinalInterlockRequest.SafeStop := SafeStopM1_Active;` |
| M2 | **VÉRIFIÉ** | `:1063,1106,1617` | idem M1 |
| M3 | **VÉRIFIÉ** | `PRG_05_Translation.st:511-512,674` | `M3_SafeStop_Aggregate := M3_SafeStop_Active OR instSafetyTranslationM3.SafeStop;` → `TranslationFinalInterlockRequest.SafeStop := ...` |

---

### 4. Barrière finale (sorties physiques)

**M1/M2 — `FB_WinchOutputInterlock` : SafeStop RÉELLEMENT consommé ✅**

| Point | Concl | fichier:ligne | Citation |
|---|---|---|---|
| Câblage entrée | **VÉRIFIÉ** | `PRG_06_Outputs.st:153/219` | `SafeStop := PRG_04_...WinchM1FinalInterlockRequest.SafeStop` |
| Consommation | **VÉRIFIÉ** | `FB_WinchOutputInterlock.st:393` | `ELSIF SafeStop OR PermitFinalBlocked THEN ...` |
| Sorties coupées | **VÉRIFIÉ** | `:402-403,487` | `RelayFwd := FALSE; RelayRev := FALSE; Contactor1..4 := FALSE;` → `BrakeCmd := RelayFwd OR RelayRev;` (→0) |
| Physiques | **VÉRIFIÉ** | `PRG_06_Outputs.st:369-384` | `M1_RelayAscent_RQ := M1RelayFwd; ... M2_BrakeRelease_RQ := M2BrakeCmd;` |

**M3 — `FB_TranslationOutputInterlock` : 🚨 `SafeStop` déclaré mais INCERTE dans le FB**

| Point | Concl | fichier:ligne | Citation |
|---|---|---|---|
| Déclaration | **VÉRIFIÉ (écart)** | `FB_TranslationOutputInterlock.st:15` | `SafeStop : BOOL;` — **seule** occurrence du mot dans le fichier ; **le FB ne lit jamais son entrée SafeStop** (connecteur inerte) |
| Coupure M3 réelle en amont | **VÉRIFIÉ** (via `FB_Translation`) | `FB_Translation.st:270-343` | `EffectiveSafeStop := SafeStop OR ...` → `RampTargetPct := 0.0; DecelRate := SEL(EffectiveSafeStop,...FastRate)` → `RequestedDriveControlWord` 1/2/0 |
| Sorties physiques M3 | **VÉRIFIÉ** | `PRG_06:457-459` | `M3_BrakeRelease_RQ, M3_CommandWord, M3_SetpointFrequencyHz` → état sûr |

**🚨 Écarts de brief / doutes sécurité (Q1, barrière finale) :**
1. **[Écart MAJEUR] `SafeStop` inerte dans `FB_TranslationOutputInterlock`** (`:15` — seule occurrence). L'entrée est câblée (`PRG_06:438`) mais **jamais lue**. Conséquence : en M3, la protection SafeStop (dont rotation de phase) repose sur **un seul** mécanisme (`FB_Translation`), **sans redondance** à la barrière finale — contrairement aux treuils. Si le blocage amont faillit, le FB de sortie ne couperait rien. → **À corriger** (consommer `SafeStop`, p.ex. forcer `DriveControlWord := 0; BrakeCmd := FALSE;`).

**🎯 Conclusion Q1 : VÉRIFIÉ** — chaîne câblée de bout en bout jusqu'aux sorties physiques M1/M2/M3 ; réaction = **SafeStop contrôlé** (rampes→0, contacteurs/frein retombent, AU engagé, **PAS de PowerCutOff** brutal). M1/M2 en **double chemin** (sécurité + barrière). M3 effectif via `FB_Translation` **MAIS barrière finale non indépendante** (écart majeur ci-dessus).

---

## Q2 — Injectable en simulation / couverture CI

### 1. Citation ligne 690 — ⚠️ ÉCART au brief **confirmé**

| Point | Concl | fichier:ligne | Citation |
|---|---|---|---|
| Forçage sim chaque scan | **VÉRIFIÉ (effet)** | `CODE/L_SIMULATION/FB_SimBench.st:690` | `Machine.PhaseRotationOk_DI := TRUE;` |
| Commentaire cité | ❌ **ÉCART** | — | Le commentaire `(* ecrit a CHAQUE scan -> ecrase tout forcage operateur *)` **n'existe nulle part** (grep `ecrase|CHAQUE|forcage` → 0 sur l.690). La ligne réelle est **sans commentaire**, espacement différent. |

✅ **Effet décrit conforme à la réalité** : l.690 est dans `§5 Simulation securite et image machine`, exécutée seulement si `Enable=TRUE` (`:257 IF NOT Enable THEN ... RETURN;`). Chaque scan sim actif, `Machine.PhaseRotationOk_DI` écrit `TRUE` sans condition → **écrase tout forçage opérateur**. La sémantique est vraie ; la citation parenthétique ne l'est pas.

### 2. Mécanisme alternatif d'injection — **N'existe pas** 🔴

| Source | Concl | Preuve |
|---|---|---|
| `GVL_Simulation.st` | **VÉRIFIÉ (aucun stimulus)** | Aucune variable rot. phase ; seul `SimSafetyActive` (l.30, gate de **domaine**, pas stimulus de défaut) |
| `FB_SimBench.st` | **VÉRIFIÉ (unique occurrence)** | Seule l.690 `Machine.PhaseRotationOk_DI := TRUE` — aucun stimulus/forçage FALSE possible |
| Publication HwSim | **VÉRIFIÉ** | `PRG_02_Acquisition.st:399` `HwSim.Machine := instSimBench.Machine` |
| Sélection HwIn | **VÉRIFIÉ** | `PRG_02:446` SEL → en sim, HwIn.Machine ≡ HwSim.Machine ≡ TRUE forcé |

**→ Injectable aujourd'hui : NON.** Pour forcer FALSE il faudrait **modifier la source `FB_SimBench.st:690`**. En réel (`SimulationModeActive=FALSE`), le bit vient du DI physique `%IX225.4` via `PRG_02:190`.

### 3. Couverture CI (`RESULTS/<domaine>/tests/*.st`) — **partielle / pas le chemin simu**

| Test | Couverture rot. phase | Niveau |
|---|---|---|
| `RESULTS/I_TRANSLATION/tests/test_fb_safety_translation.st:55-61` | ✅ `fb.PhaseRotationOk := FALSE` → assert `ErrorPhaseRotation` | FB unitaire Safety M3 (**réaction**, pas chemin simu) |
| `RESULTS/I_TRANSLATION/tests/test_fb_translation.st:951-956` | ✅ `PhaseRotationOk := FALSE` → assert `ErrorPhaseRotation` | FB unitaire M3 |
| `RESULTS/H_TREUILS_BENNE/tests/test_fb_safety_winch.st` | ❌ `PhaseRotationOk` **toujours TRUE**, aucun cas défaut | **Aucune couverture rot. phase M1/M2** |
| `RESULTS/J_SUPERVISION/tests/test_fb_hmi_bannerformatter.st:147` | ✅ `WinchM1Safety.ErrorPhaseRotation := TRUE` | HMI/bannière (affichage seul) |
| `RESULTS/L_SIMULATION/tests/test_fb_simbench.st` | ❌ aucune mention `Phase/Rotation` | Banc FB_SimBench non couvert |

**🎯 Conclusion Q2 : VÉRIFIÉ** — simulation injectable **NON** (structurellement bloqué par l.690). Écart de brief : commentaire cité inexistant. Recommandation si injonction souhaitée : ajouter `SimPhaseRotationFault : BOOL` dans `GVL_Simulation`, consommé par `FB_SimBench.st:690` (décision de conception, hors périmètre READ-ONLY).

---

## Q4 — Verrouillage & pas de réarmement auto (ISO 13849)

**Motif identique et correct sur les 3 axes** : `SET` conditionnel seul, `FALSE` atteint **uniquement** sur front Reset (ou bypass test / 1er scan). Aucune ligne ne remet le latch à FALSE quand `PhaseRotationOk` repasse TRUE.

| Élément | M1/M2 (`FB_Safety_Winch`) | M3 (`FB_Safety_Translation`) |
|---|---|---|
| Front Reset | `:181` `ResetEdge(CLK := Reset)` → `:183` `IF ResetEdge.Q OR BypassGlobal THEN` | `:99` → `:101` idem |
| Effacement latch | `:186` `PhaseRotationFaultLatched := FALSE;` | `:102` `PhaseRotationFault := FALSE;` |
| Pose (SET seul) | `:302-304` `IF NOT PhaseRotationOk THEN PhaseRotationFaultLatched := TRUE; END_IF;` | `:140-142` idem |
| Cause→Active/Latching | `:305-306` `instCauses[4]...Latching := TRUE` | `:143-144` `instCauses[2]...Latching := TRUE` |

**Socle `FB_FaultCore.st` : VÉRIFIÉ** — `Latch[i]` effacé que sur front Reset (`:41`), ré-armé si cause `Active AND Latching` (`:66`). Un seul Reset jamais conditionné (agit même `Enable=FALSE`, `:11`) — **impossible d'acquitter en éteignant/rantant le FB**.

**Ordre d'exécution (re-verrouillage) : VÉRIFIÉ** — le bloc Reset (`§1 FRONTS`) s'exécute en tête, l'évaluation cause + re-pose plus bas dans le même scan. Si cause persistante après Reset ⇒ **re-posée immédiatement au scan suivant**.

**🎯 Conclusion Q4 : VÉRIFIÉ sur les 3 axes.**
- ✅ Pas de réarmement auto (SET-seul, effacé sur front Reset uniquement)
- ✅ Reset sur **front** (`R_TRIG`), jamais niveau — cause disparue + appui conscient
- ✅ Re-verrouillage immédiat si cause persiste
- ✅ Retour phases→TRUE **n'efface pas** le latch
- ⚠️ Nuances : `BypassGlobal` (test `[TST]`) efface les latches sans Reset ; pas de TON/débounce dédié au défaut de phase (déclenchement immédiat, acceptable hors transitoires) — aucun des deux n'est un réarmement auto en exploitation.

---

## Q5 — Bypass de rotation de phase (`BypassPhaseRotation`) : encadré ?

### Liste exhaustive des 7 occurrences

| # | fichier:ligne | Rôle | Citation |
|---|---|---|---|
| 1 | `FB_Safety_Winch.st:74` | Déclaration entrée FB M1/M2 | `BypassPhaseRotation : BOOL := FALSE;` |
| 2 | `FB_Safety_Winch.st:302` | Consommation sécurité M1/M2 | `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN` |
| 3 | `FB_Safety_Translation.st:43` | Déclaration entrée FB M3 | `BypassPhaseRotation : BOOL := FALSE;` |
| 4 | `FB_Safety_Translation.st:140` | Consommation sécurité M3 | `IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN` |
| 5 | `PRG_04_Treuils_Benne.st:984` | Câblage réel M1 | `BypassPhaseRotation := GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation,` |
| 6 | `PRG_04_Treuils_Benne.st:1050` | Câblage réel M2 | `BypassPhaseRotation := GVL_IHM.M2TreuilBenne.Bypass.PhaseRotation,` |
| 7 | `PRG_05_Translation.st:496` | Câblage réel M3 | `BypassPhaseRotation := GVL_IHM.M3Translation.Bypass.PhaseRotation,` |

### 3 dimensions d'encadrement

**a) Source / persistance — VÉRIFIÉ (point positif)**
- `GVL_IHM.st:5` : « Variables **volatiles** d'échange temps-réel (IHM <-> Automate) ».
- `FB_MirrorBypassRetain` (`PRG_07_Supervision.st:345-355`) ne réplique en RETAIN **QUE** `.Global` + LimitLegal/TopLimit*/Cable/SlackCable. **`PhaseRotation` n'y figure pas → NON persistant, retour FALSE au boot.** ✅

**b) Niveau d'accès / gate de mode — ⚠️ DÉDUIT, point critique**
- Doctrine déclarée MAINT_N2 : `ST_BypassWinch.st:7` « actionnable **UNIQUEMENT en MAINT_N2**, RETAIN », idem `ST_BypassTranslation.st:4`.
- **Mais en code** : `PRG_04:970-971` « **bypass transmis SANS gate de mode (dérogation MES 2026, tous modes)** » → M1/M2 actif en **production**. Et `PRG_05_Translation.st:462` définit `M3_MaintN2` mais ne l'applique **qu'à `BypassLimitSwitch`** (`:500`,`:603`), **pas** à `BypassPhaseRotation` (`:496`).
- ➡️ **La doctrine « MAINT_N2 uniquement » n'est PAS implémentée pour PhaseRotation en code.** La restriction est laissée au **contrôle d'accès écran IHM** → **niveau écran INDÉTERMINÉ**, niveau code **sans gate**.

**c) Visibilité / traçabilité IHM — ⚠️ DÉDUIT, lacune**
- `FB_Hmi_BannerFormatter` : `AnyBypassActive` (`:430`) → « ATTENTION: Bypass actif » (`:441`) alimenté **que** par `.Global` (`PRG_07:732-737`). **Un bypass PhaseRotation granulaire seul ne déclenche aucun bandeau.**
- `FB_TroubleshootingView` : remonte `ErrorPhaseRotation` (Idx312/311/312) **mais aucun indicateur de l'état du bypass PhaseRotation** (seuls Global/TopLimit* remontés, `:211-216`).
- ➡️ **Aucun signal opérateur dédié** de l'activation de ce bypass (**silencieux**).

**🎯 Conclusion Q5 : EN PARTIE (NON pour gate de mode / visibilité).**

| Type | Verdict | Détail |
|---|---|---|
| Non persistant (boot→FALSE) | ✅ **VÉRIFIÉ** | `FB_MirrorBypassRetain` n'inclut pas PhaseRotation |
| Bypass granulaire (cause 4 seule) | ✅ **VÉRIFIÉ** | n'écrase que `NOT (BypassProcess OR BypassPhaseRotation)` |
| Latch conservé quand bypass inactif | ✅ **VÉRIFIÉ** | `PRG_07:407`, BannerFormatter `:924/972/1011` |
| **Gate de mode en code** | ❌ **DÉDUIT (absent)** | `PRG_04:970` « tous modes » ; M3 sans `M3_MaintN2` |
| **Alerte opérateur / bandeau dédié** | ❌ **DÉDUIT (absent)** | seuls `.Global` alimentent le bandeau |
| **Niveau écran IHM (maj)** | ⚠️ **INDÉTERMINÉ** | hors `CODE/`, pas de `.vis` auditable |

**🚨 Risque sécurité signalé :** opérateur/mainteneur (ou config IHM) peut activer `Bypass.PhaseRotation` et **silencer un défaut de rotation de phases en production sans visibilité**, machine restant commandable — cache un raccordement erroné → dommage mécanique/électrique possible. Deux écarts collatéraux : `BypassProcess` **suffit** à neutraliser la cause 4 (masquage croisé) ; rotation de phase **n'arme pas PowerCutOff** (`CausesPowerCutOffActive` `:523-525` l'exclut → seulement SafeStop).

---

## ÉCARTS AU BRIEF — INVENTAIRE COMPLET

| # | Sévérité | Écart | Preuve (fichier:ligne) |
|---|---|---|---|
| 1 | 🚨 Majeur | `SafeStop` **inerte** dans `FB_TranslationOutputInterlock` (jamais lu) → M3 sans redondance barrière finale | `FB_TranslationOutputInterlock.st:15` (seule occurrence), câblé `PRG_06:438` |
| 2 | Modéré | Ligne 190 **mal décrite** : affectation brute `HwReal`, pas déclaration `VAR_INPUT`, pas `HwIn` | `PRG_02_Acquisition.st:190` |
| 3 | Modéré | Pas de `VAR_INPUT` dans PRG_02 (vide `:14`) ; source = variable E/S globale | `GVL_Device_IO.st:53` |
| 4 | Modéré | **Gate MAINT_N2 absent en code** pour PhaseRotation, contrairement doctrine `ST_BypassWinch.st:7` | `PRG_04:970` (« tous modes »), `PRG_05:496` (sans `M3_MaintN2`) |
| 5 | Modéré | **Bypass silencieux** : aucun bandeau ni indicateur diag dédié | `FB_Hmi_BannerFormatter:430/441`, `FB_TroubleshootingView:211-216` |
| 6 | Faible (cosmétique) | Commentaire `(* bit 2 / 16#0004 *)` absent en fin de l.143 | `FB_Safety_Translation.st:143` |
| 7 | Faible (cosmétique) | Commentaire `(* bit 4 / 16#0010 *)` absent sur l.305/498 | `FB_Safety_Winch.st:305,498` |
| 8 | Faible | Citation brief `(* ecrit a CHAQUE scan... *)` **inexistante** dans le code (l.690 sans commentaire) | `FB_SimBench.st:690` |
| 9 | Faible | Label `ErrorID:05` = numéro de cause 1-based, **pas** valeur hex (bit4=`16#0010`, pas 05) — convention à documenter | `FB_Hmi_BannerFormatter.st:924-925/972-973` |
| 10 | Faible | ErrorID non global à la machine (`03`=surchauffe M1 mais rot. phases M3) — sans préfixe axe + texte, équivoque | BannerFormatter |
| 11 | Faible | `BypassGlobal` réarme les latches sans Reset ; `BypassProcess` suffit à masquer cause 4 | `FB_Safety_Winch.st:183,302` |
| 12 | Faible | Commentaire fail-safe `TRUE = OK` absent de :190 — vit dans les FB | `FB_Safety_Translation.st:22`, `FB_Acquisition_Preflight.st:25` |

---

## RECOMMANDATIONS (hors périmètre READ-ONLY, à valider par huain)

1. **[Correctif prioritaire]** Consommer `SafeStop` dans `FB_TranslationOutputInterlock` (forcer `DriveControlWord := 0; BrakeCmd := FALSE;`) pour redonder la protection M3 à la barrière finale.
2. **[Conformité]** Aligner le code sur la doctrine : gate `M3_MaintN2` sur `BypassPhaseRotation` (+ revoir « dérogation tous modes » M1/M2 `PRG_04:970`).
3. **[Visibilité]** Alimenter un bandeau / indicateur dédié à l'activation de `Bypass.PhaseRotation`.
4. **[Couverture test]** Ajouter un stimulus `SimPhaseRotationFault` dans `GVL_Simulation` pour rendre le chemin sim injectable + couvrir M1/M2 (`test_fb_safety_winch.st`) et le banc (`test_fb_simbench.st`).
5. **[Documentation]** Documenter la convention « ErrorID = numéro de cause 1-based, pas hex ».

---

**Aucun fichier modifié** (mission de vérification 100% read-only). Toutes les preuves citées ci-dessus proviennent d'une lecture directe des fichiers `CODE/*.st` listés.
