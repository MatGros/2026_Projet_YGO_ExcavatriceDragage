# 🪝 CONTACTEURS — DIAGNOSTIC & PROPOSITION DE SOLUTION
**Pilotage cohérent SIMULTANÉ des contacteurs M1/M2 + détection d'écart**

| | |
|---|---|
| 📄 Type | **Proposition de solution** (mode diagnostic lecture — **zéro modif code**) |
| 🗓️ Date | 2026-08-31 |
| 🎯 Période | Pilotage treuils M1 (retenue) / M2 (benne) — paliers & contacteurs |
| 🔴 Criticité | **C1** (comportement non conforme, rejet client) |
| 📚 Référentiel | `DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md` · `STDS/` · `NAMING_CONVENTION.md` |
| 🧾 Fichiers audités | `FB_Winch.st` · `FB_SpeedStep.st` · `_TYPES/ST_SpeedStepTable.st` · `FB_WinchSync.st` · `FB_SyncContactor.st` · `FB_WinchOutputInterlock.st` · `FB_WinchStepShaper.st` · `PRG_04_Treuils_Benne.st` · `PRG_06_Outputs.st` · `GVL_PERSISTENT.st` |

---

## 🎯 Exigence client (verbatim, re-formulée en critères testables)

> « Lorsqu'on pilote les 2 treuils en même temps, il faut vraiment qu'il y ait un bout de code pour piloter les 2 contacts, que TOUS les contacteurs soient pilotés en même temps, et s'il y a un **ÉCART** (entre M1 et M2), il faut mettre un défaut. Ce n'est pas acceptable. »

1. **Simultanéité** : en mode couplé (both), les contacteurs M1 **et** M2 doivent être générés ensemble, même palier, une seule séquence commune → **zéro écart structurel** au niveau commande.
2. **Cohérence du tableau** : palier N ⇒ TOUS les contacteurs prévus par la table sont commandés (décodage **cumulatif**, jamais exclusif).
3. **Défaut sur écart** : tout écart durable M1/M2 (palier ou contacteur) ⇒ défaut latched + arrêt **commun** des 2 treuils, jamais de redémarrage auto.

---

## 1️⃣ ÉTAT ACTUEL — chaîne de pilotage des contacteurs

### 1.1 Chemin complet (source → sortie physique)

```
M1/M2 Arb (FB_WinchCmdArbitrationM1/M2)        → StepTgt (1..5, 0 = arrêt)
   │  (+ clamp §5ter PRG_04 : CommonMax* + M2-propre M2Max*)
   ▼
FB_Winch M1 & M2 (§5)
   ├── RampTargetStep = SpeedStepReq (ou 0 si direction 0 / SafeStop / !StartStop / DirectionChangePending)
   ├── FB_SpeedStep(Enable, SpeedStepReq, Table, MaxStepNumber) → StepNumber   ← SEULE sortie lue
   ├── FB_WinchStepShaper(…, TargetStep := RequestedStep) → ShapedStep = StepNumber (cadence indépendante par treuil)
   └── 🚨 DÉCODAGE CONTACTEURS (ligne 278-281 FB_Winch) :
          Contactor1 := (StepNumber = 1);
          Contactor2 := (StepNumber = 2);
          Contactor3 := (StepNumber = 3);
          Contactor4 := (StepNumber = 4);
   ▼
PRG_04 §7 → RequestedContactor1..4
   ▼
FB_WinchOutputInterlock M1/M2 (barrière finale, transmet + garde-fous)
   ▼
PRG_06 §1/§2 → Mx_SpeedContactor_1..4_DQ (sorties physiques)
```

### 1.2 🔴 CAUSE RACINE DU TABLEAU — le décodeur EXCLUSIF de FB_Winch

La table réelle `_WinchSpeedStepTable` (`CODE/GVL_PERSISTENT.st`, ligne 16-23) est **CUMULATIVE et CORRECTE** :

| Palier | K1 | K2 | K3 | K4 | Note |
|---|---|---|---|---|---|
| **P1** | 0 | 0 | 0 | 0 | vitesse la plus basse (K1..K4 off) |
| **P2** | **1** | 0 | 0 | 0 | **K1 seul** |
| **P3** | **1** | **1** | 0 | 0 | **K1+K2** |
| **P4** | **1** | **1** | **1** | 0 | K1+K2+K3 |
| **P5** | **1** | **1** | **1** | **1** | K1+K2+K3+K4 |

`ST_SpeedStepTable.st` le porte (P1R1..P5R4) et `FB_SpeedStep.st` §2 (lignes 74-78) le **décode correctement** (sorties `Contactor1..4` cumulatives).

**🚨 MAIS `FB_Winch` §5 IGNORE la table** : il ne lit que `SpeedStep.StepNumber` (ligne 217) et **écrase** les contacteurs avec un décodage **EXCLUSIF** `ContactorN := (StepNumber = N)` (lignes 278-281).

Conséquence — **EXACTEMENT le symptôme décrit** :

| Palier demandé | Décodage exclusif actuel | Décodage cumulatif attendu |
|---|---|---|
| P1 | K1 **on** (→ faux) | **tous off** |
| **P2** | K2 on, **K1 off** → `PALIER 2 VIDE` | K1 on |
| **P3** | K3 on, **K1+K2 off** → `PALIER 3 : 1+2 ÉTEINTS` | K1+K2 on |
| P4 | K4 on, **K1+K2+K3 off** | K1+K2+K3 on |
| P5 | seul K4 on (K1-K3 off) | K1+K2+K3+K4 on |

**Verrou** : si `Fault.Error` ⇒ tous contacteurs à FALSE (ligne 292-296) — correct.

> 📌 **Constat de non-régression** : l'ancienne version `CODE_BACKUP/.../TREUILS/FB_Winch.st` (l.322-335) lisait bien `Table.PxRy`. Le refactor « interface plat → structs » (T190-B) a remplacé la lecture de table par le test exclusif `(StepNumber=N)` et **a perdu la table** dans FB_Winch. Donc **le décodage est la cause** ; **la table n'est PAS à corriger** (elle est déjà cumulative et conforme).

---

## 2️⃣ PILOTAGE SIMULTANÉ — analyse de l'existant

### 2.1 M1 et M2 sont-ils pilotés avec la MÊME consigne ?

| Niveau | Constat |
|---|---|
| Arbitrage amont | M1 et M2 = **2 instances FB_SEPARES** (`instArbM1`/`instArbM2`). En mode both ils partent de la même `BothIntent`, **mais** M2 applique des clamps propres : `M2MaxStep* := 1` si `M2_BucketJogLimit`, `ManualBucketLimitsActive`, `BucketNotClosedAscentStep1`, `SlackCableAscentStep1` (PRG_04 §5ter, l.831-842). |
| Clamp de palier | `CommonMaxStep*` (commun M1=M2) OK pour écarts sync/extraction ; **mais les clamps M2-propres ne réduisent PAS M1** ⇒ en mode couplé "benne pas fermée / mou de câble", **M2 peut être à P1 pendant que M1 reste libre** → écart structurel. |
| Cadence de palier | Chaque `FB_Winch` a **son propre `FB_WinchStepShaper`** et **son propre `FB_WinchStepShaper` de direction** → deux machine-états indépendantes, deux temporisations. Même cible, **transitoires de cadence non synchronisés**. |
| Décodage contacteur | Fait **indépendamment dans chaque FB_Winch** (2× §5). Aucun point unique qui dérive M1+M2 d'un même palier. |

### 2.2 Conclusion : **pas de mécanisme garantissant l'enclenchement simultané**

Il n'existe **AUCUN « bout de code » qui pilote un couple de contacteurs M1/M2 d'une seule source**. Les 2 treuils sont deux FBs autonomes et faiblement couplés. La simultanéité n'est donc **pas garantie par construction** — elle ne tient qu'à la convergence fortuite des consignes, des clamps et des cadences.

> 🛠️ **Ce que le client demande est exactement ce point : un générateur commun du couple de contacteurs, en couplage.**

---

## 3️⃣ DÉTECTION D'ÉCART — existant & lacunes

### 3.1 La détection EXISTE déjà (partiellement)

`FB_SyncContactor` (dans `FB_WinchSync` §3, instancié en §4 PRG_04) :

```
MismatchActive := SyncEnable AND (
    RelayFwdM1<>RelayFwdM2 OR RelayRevM1<>RelayRevM2 OR
    Contactor1M1<>Contactor1M2 OR Contactor2M1<>Contactor2M2 OR
    Contactor3M1<>Contactor3M2 OR Contactor4M1<>Contactor4M2 );
ContactorMismatch := MismatchTimer.Q;   // filtre T#500ms
```

→ `instCauses[1]` ⇒ `FaultErrorId bit 16#0002` (latched) ⇒ **SafeStop des 2 treuils** via PRG_04 §5 (`SafeStopM1_Raw/M2_Raw`, + cross-couplage `SafeStopMx_Active := ... OR (SyncActive AND SafeStopMy_Raw)`). **Le défaut sur écart de contacterre existe donc.**

### 3.2 🔴 Lacunes de cette détection (à combler)

| # | Lacune | Impact |
|---|---|---|
| L1 | **Filtre 500 ms** | Tolère un écart commandé de 500 ms EN mouvement couplé ⇒ divergence mécanique mesurable avant arrêt. |
| L2 | **Comparaison des COMMANDES, pas des feedbacks** | `FB_Winch.Sensors.ContactorsAllOff` (feedback physique) n'est **jamais** passé à `FB_SyncContactor`. Seuls les ordres `instWinchM1.Contactor1..4` sont comparés. Un contacteur réel bloqué (collé/ouvert) reste invisible ici. |
| L3 | **Active uniquement si `instWinchSync.Enable`** | Gate = `SyncEnable AND NOT bucketBusy AND NOT homing AND NOT inhibit`. Pendant une **action benne**, homing ou hors synchro, **la cohérence contacteur est coupée**. |
| L4 | **Ne compare ni le PALIER ni la DIRECTION sources** | Ne détecte que le symptôme `Contactor*`, pas la cause amont (`StepTgt`/`StepNumber` M1≠M2). |

> Conclusion : la surveillance est un **filet de sécurité post-commande**, mais elle n'empêche **pas** la non-simultanéité ni n'alerte vite. Le client veut un écart **prévenu** (commande commune) **et détecté** (défaut).

---

## 4️⃣ DESIGN PROPOSÉ

### 4.A — Décodage contacteur cumulatif (correction tableau / décodage)

🎯 **Décision** : remettre la **table comme source unique** du décodage. Le code décodeur correct existe **déjà dans `FB_SpeedStep`** (sorties `Contactor1..4` cumulatives). `FB_Winch` doit les **ré-émettre** au lieu de re-décoder en exclusif.

```iecst
// FB_Winch §5 — REMPLACER les lignes 278-281 :
Contactor1 := SpeedStep.Contactor1;   // venant de Table.PxR1
Contactor2 := SpeedStep.Contactor2;   // venant de Table.PxR2
Contactor3 := SpeedStep.Contactor3;   // venant de Table.PxR3
Contactor4 := SpeedStep.Contactor4;   // venant de Table.PxR4
```

- ✅ Utilise le même palier `StepNumber` déjà calculé (§5 ligne 211 `SpeedStep(...)`) — l'instance `FB_SpeedStep.StepNumber` sert déjà de `RequestedStep`. On réutilise simplement ses 4 sorties contacteur **au lieu de les jeter**.
- ✅ Table `_WinchSpeedStepTable` **inchangée** (déjà cumulative/conforme).
- ✅ `ST_SpeedStepTable` inchangé.
- ⚠️ **Point à valider avec l'électrotechnicien** : Palier **1 = tous contacteurs off** (volonté actuelle de la table). Vérifier que la motorisation accepte un cran sans contacteur de vitesse (démarrage direct) ; sinon passer P1 = `{K1}`.

### 4.B — Génération SIMULTANÉE du couple M1/M2 (nouveau FB)

🎯 **Décision** : un **producteur unique du couple de contacteurs en mode couplé**, respectant « 1 FB = 1 responsabilité ».

**Nouveau POU : `FB_WinchContactorCoupler`** (`CODE/H_TREUILS_BENNE/`)

Rôle : en `SyncActive=TRUE`, dériver **UN** palier commun + **UN** sens commun, et produire **à la fois** les 2 jeux de contacteurs M1/M2 à partir de la MÊME source, en UN seul scan.

```
FB_WinchContactorCoupler
  IN : Enable, Reset, SyncActive
       ReqStepM1, ReqStepM2            (consignes arbitrées, après clamp)
       EffPermitM1_Ascent/Descend, EffPermitM2_Ascent/Descend   (permis effectifs)
       SafeStopM1, SafeStopM2
       Table : ST_SpeedStepTable       (= _WinchSpeedStepTable)
  OUT: CoupledStep : INT               (palier commun 0..5)
       Contactor1M1..4_M1, Contactor1M2..4_M2   (jeux IDENTIQUES)
       CoupledActive : BOOL
       StepMismatch  : BOOL            (écart consigne M1≠M2 détecté)
```

Logique interne (ST) :
```iecst
// 1) Palier commandé commun = le MIN des deux consignes (= le plus sûr).
CoupledStep := MIN(ReqStepM1, ReqStepM2);

// 2) Permis / SafeStop communs (le + restrictif gagne) :
IF NOT SyncActive THEN CoupledActive := FALSE; CoupledStep := 0;
ELSIF EffectiveStop (SafeStopM1 OR SafeStopM2) THEN CoupledStep := 0;
ELSIF NOT (EffPermitM1_Ascent OR EffPermitM1_Descend) OR
      NOT (EffPermitM2_Ascent OR EffPermitM2_Descend) THEN CoupledStep := 0;

// 3) Décodage cumulatif UNIQUE via la table (2 jeux identiques) :
CASE CoupledStep OF
  1:  M1: C1:=T.P1R1;. C4:=T.P1R4;   M2: identique
  2:  M1: C1:=T.P2R1;..              M2: identique
  ...
END_CASE;

// 4) Écart de consigne (avant décodage) :
StepMismatch := SyncActive AND (ReqStepM1 <> ReqStepM2);
```

**Câblage PRG_04** : en mode couplé, la sortie du coupler **supplante** les 4 sorties `Contactor1..4` des FB_Winch M1/M2 lors de l'assemblage des `WinchM1/M2FinalInterlockRequest` (§7). Hors couplage, on garde le décodage autonome de chaque FB_Winch (4.A). La barrière finale `FB_WinchOutputInterlock` reste **inchangée** (garde-fous propres par treuil).

### 4.C — Renforcer la détection d'écart

1. **Fusionner M2-propre dans le commun en couplage** : faire entrer `M2_BucketJogLimit`, `ManualBucketLimitsActive`, `BucketNotClosedAscentStep1`, `SlackCableAscentStep1` **dans la borne commune** `CommonMaxStep*` quand `SyncActive` ⇒ la consigne elle-même ne peut plus diverger (complète 4.B étape 4 : `ReqStepM1 ≡ ReqStepM2`).
2. **Réduire le filtre** `FB_SyncContactor` de 500 ms → ~100 ms **en couplage** (`CfgMismatchDebounce` paramétrable) ; garder 500 ms hors couplage.
3. **Comparer aussi `StepNumber` M1 vs M2** (cause) en plus de `Contactor*` (symptôme) ⇒ fauter **dès la cause**, pas seulement au 1er contacteur divergent.
4. **Câbler le feedback physique** (`M1_ContactorsReleased_DI`/`M2_ContactorsReleased_DI` via `Sensors.ContactorsAllOff`) en renfort : un contacteur réel collé devient détectable même si la commande est identique (complément de `FB_Safety_Winch`, propriétaire du défaut « contacteur collé » T181-08).
5. **Garder le latch + pas de redémarrage auto** (déjà acquis via `instCauses[1].Latching := TRUE` et le socle `FB_FaultCore`).

### 4.D — Où placer la détection d'écart ?

| Composant | Place proposée | Rôle |
|---|---|---|
| **Écart de commande contacteur** (symptôme) | **`FB_SyncContactor`** (inchangé, renforcé §4.C.2/3) — déjà dans `FB_WinchSync`. | Filet post-commande. |
| **Écart de consigne/palier** (cause) | **`FB_WinchContactorCoupler`** (nouveau, sortie `StepMismatch`), consommé par PRG_04 → alimente `instWinchSync`/SafeStop. | Détection amont, plus rapide. |
| **Contacteur physiquement collé/ouvert** | **`FB_Safety_Winch`** (T181-08, déjà propriétaire) + feedback `ContactorAllOff` câblé à `FB_SyncContactor`. | Détection matérielle réelle. |
| **Réaction (latch + stop commun)** | **`PRG_04 §5`** (`SafeStopM1/M2_Active` cross-couplés) — **inchangé**, déjà correct. | Arrêt commun des 2 treuils. |

💡 Le coupler reste **dans `PRG_04`** (et non dans FB_Winch) : il orchestre les 2 treuils, ne fait pas partie d'un mouvement individuel → respect de `1 FB = 1 responsabilité` et interface transverse (comme `FB_WinchSync`).

---

## 5️⃣ IMPACT SÉCURITÉ (ISO 13849 / robustesse)

### 5.1 Le danger mécanique réel
Deux régimes de palier **divergents** ⇒ un treuil tourne plus vite que l'autre ⇒ **mou de câble** sur l'un, **surcharge / à-coup de tension** sur l'autre, risque de **télescopage** de la benne / de la flèche → désalignement mécanique et rupture.

### 5.2 Mesures pour neutraliser ce danger

| Mesure | Effet | Référence |
|---|---|---|
| **Génération commune (4.B)** | Élimine l'écart **à la source** : commandes M1/M2 toujours identiques en couplage. | Proposition 4.B |
| **Fusion clamps couplés (4.C)** | Plus de divergence M1/M2 par palier, même sous contrainte benne/mou de câble. | Proposition 4.C |
| **Décodage cumulatif (4.A)** | Chaque palier a TOUT le couple moteur attendu → pas de perte de traction soudaine (risque de chute de charge). | Proposition 4.A |
| **Détection rapide + latch (4.C)** | Tout écart durable ⇒ SafeStop commun, **jamais de redémarrage auto**. | Propositions 4.C + §3.1 (existant) |
| **Stop commun cross-couplé** | `SafeStopM1_Active := SafeStopM1_Raw OR (SyncActive AND SafeStopM2_Raw)` — déjà en place. | PRG_04 §5 / inchangé |
| **Garde-fous finaux intacts** | `FB_WinchOutputInterlock` (frein, temps mort inversion, contacteur collé T_max) restent par treuil. | inchangé |

> ⚠️ **Note ISO 13849** : la comparaison de commandes seule (logique applicative) n'est pas une barrière PL catégorisée pour la **désynchronisation mécanique** — elle est une détection fonctionnelle. La vraie sauvegarde physique reste la surveillance d'écart de **position** (`FB_SyncDeviation`, seuil Fault → PowerCutOff/SafeStop) déjà présente. La proposition rend la commande cohérente **et** la détection plus fine, sans affaiblir la sûreté matérielle existante.

---

## 6️⃣ PLAN D'IMPLÉMENTATION (étapes, fichiers, gates)

> 🔒 **Mode actuel = proposition.** Aucun fichier de la liste ci-dessous n'a été modifié. Passage à l'implémentation après **validation humaine** (contrat de tâche C1).

| # | Étape | Fichiers | Livrable / Gate |
|---|---|---|---|
| **1** | **Corriger le décodage** : FB_Winch ré-émet les sorties table de FB_SpeedStep (`4.A`). | `CODE/.../FB_Winch.st` | Test unitaire : P1→0, P2→{K1}, P3→{K1,K2}… |
| **2** | **Créer `FB_WinchContactorCoupler`** (génération simultanée + `StepMismatch`) (`4.B`). | `CODE/H_TREUILS_BENNE/FB_WinchContactorCoupler.st` (+ `_TYPES` si DUT dédié) | Gate structure G310, contrat FB (AF-03 §3). |
| **3** | **Câbler le coupler dans PRG_04** (couplage supplante les contacteurs M1/M2, fusion clamps couplés) (`4.B`/`4.C`). | `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | Gate liaison **G200 (bloquant)**. |
| **4** | **Renforcer `FB_SyncContactor`** : debounce 100 ms couplé + comparaison `StepNumber` + feedback `ContactorAllOff`. | `CODE/H_TREUILS_BENNE/FB_SyncContactor.st` | Test unitaire mismatch. |
| **5** | **Valider feedback physique** (`4.C.4`) au coupler / `FB_Safety_Winch`. | `CODE/.../FB_Winch.st` (Sensors) · `PRG_04` (câblage) | Gate liaison. |
| **6** | **Vérifier palier P1** (all-off ou {K1}) avec l'électrotechnicien. | `CODE/GVL_PERSISTENT.st` (valeur table, si besoin) | Décision humaine ⚠️. |
| **7** | **Bandeau CI/CD complet**. | `TOOLS/AGENT_WORKFLOW/scripts/` | `generate_codesys_bundle.py` + `G200_check_linkage.py` + `run_all_gates.py --palier C`. |
| **8** | **Tests CI** (paliers cumulatifs, simultanéité, écart→SafeStop). | `TOOLS/TEST_AUTO_CI/` | Tests verts + rapport. |
| **9** | **REX versionné + intégration CODESYS manuelle** par l'humain (import PLCopenXML). | `DOC/VERSION_HISTORY.md` · `DOC/WFLOW/` | REX + VERSION_HISTORY. |

**Séquence de validation obligatoire (workflow AGENTS.md)** :
```
bundle → G200 liaison (BLOQUANT) → 21 gates palier C → tests CI → REX → import manuel CODESYS
```

> 📌 **Règle `fix:` + `guard:`** : tout correctif (étape 1) doit être accompagné d'un garde-fou de régression dans `TOOLS/AGENT_WORKFLOW/scripts/` (ex. gate qui échoue si `FB_Winch` référence `(StepNumber=N)` au lieu de `SpeedStep.Contactor*`).

---

## ✅ SYNTHÈSE

| Question | Réponse |
|---|---|
| **Palier 2 vide / palier 3 éteint 1+2** | **Décodage EXCLUSIF de `FB_Winch` §5** (`ContactorN := (StepNumber=N)`), qui **ignore la table**. La table `_WinchSpeedStepTable` est déjà **cumulative et correcte**. Non-régression du refactor structs. |
| **Pilotage simultané ?** | **NON garanti** : 2 FB_Winch autonomes, 2 cadences, clamps M2-propres → écart structurel possible. **Solution** : `FB_WinchContactorCoupler` = producteur unique du couple M1/M2. |
| **Détection d'écart ?** | **Existe** (`FB_SyncContactor` ⇒ SafeStop commun, latch). **Lacunes** : 500 ms, commandes seules, inactive en action benne/homing. **Solution** : debounce court couplé + comparaison palier + feedback physique. |
| **Correction de table ?** | **Pas nécessaire sur la donnée** — corriger le **décodage** (ré-émettre `SpeedStep.Contactor*`) ; valider simplement le palier P1. |
| **Impact safety** | La proposition **prévient** l'écart (commande commune) et **détecte plus vite** (défaut + stop commun), sans affaiblir la sûreté Position existante. |

---
*Rapport de proposition de solution — à faire valider avant toute modification de code.*
