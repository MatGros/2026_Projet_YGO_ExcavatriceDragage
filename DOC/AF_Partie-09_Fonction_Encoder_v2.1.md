# Analyse Fonctionnelle — Partie 9 : Codeurs & Référencement (Homing) (v2.1)

> Rôle : mesure position/vitesse câble, référencement (homing), bornage et cohérence.
> Producteur unique position/vitesse pour tout le programme (Winch, Safety, Cycle, IHM).
> **Détail technique par FB** : voir les 6 fiches dédiées (§1). Ce chapô reste au niveau machine
> + intégration programme — il ne recopie **pas** les interfaces/`ErrorId`/`TC-` des fiches.
> Source code : `CODE/CODEURS/*.st` (déjà réécrit nouvelle génération, cf. en-têtes `.st` —
> ce n'est pas du code legacy à migrer) · instances dans `PRG_02_Encoders.st` (POU ST actuel).
> Cible : la chaîne codéurs complète rejoint `PRG_02_Acquisition_CFC` (rang 02) — voir §4.2.
> ⚠️ **Point d'arbitrage ouvert pour le lot M1** : le homing lit le mode de marche — voir §4bis.
> 🗺️ Architecture cible faisant foi : `DOC/AF_Partie-02_Architecture_Programme_v3.0.md` §2 et §4.
> Extraction : `DOC/CHECKLISTS/EXTRACTIONS/FB_Encoder_Extraction_Code_v1.0.md`.
> v2.0 archivée : `ARCHIVES/Doc/AF_Partie-09_Fonction_Encoder_Homing_v2.0.md`.
> v1.11 archivée : `ARCHIVES/Doc/AF_Partie-10_Fonction_Encoder_Homing_v1.11.md`.

⚠️ **Statut de ce document (2026-07-31)** : la v2.1 corrige des interfaces FB **fabriquées** dans
les 6 fiches lors de leur création (v1.0, éclatement de l'ancien fichier monolithique) — noms de
ports inexistants, polarité `TopPositionSensor` inversée, entrée `BypassGlobal` omise. Corrigées
contre une lecture ligne à ligne de `CODE/CODEURS/*.st`. Un seul point reste réellement une cible
de migration (pas encore câblée) : la vitesse forcée palier 1 pendant un cycle de référencement
non abouti, **M1/M2 uniquement** (fiche `FB_Encoder_Homing` §4, cross-ref `AF_Partie-10`) —
**M3/Translation exclu** : pas de mécanisme de homing équivalent aujourd'hui (positionnement par
5 capteurs discrets, toujours réputés fiables), décision utilisateur 2026-07-31.

## 🧭 Sommaire

1. Composition — fiches FB dédiées
2. Rôle et pipeline
3. DUT et bus
4. Intégration programme
4bis. ⚖️ Point d'arbitrage OUVERT — le homing lit le mode de marche
5. Procédure terrain
6. Alertes et écarts
7. Documents liés

## 🧪 Points de validation

Catalogue `TC-P09-*` **réparti dans les 6 fiches FB** (propriétaire unique par fiche) :

| Fiche | TC couverts |
|---|---|
| [`FB_Encoder_Abs`](AF_Partie-09_Fonction_Encoder/FB_Encoder_Abs_v1.0.md) | TC-P09-001, 002 |
| [`FB_Encoder_Homing`](AF_Partie-09_Fonction_Encoder/FB_Encoder_Homing_v1.0.md) | TC-P09-003 à 009 |
| [`FB_Encoder_Scale`](AF_Partie-09_Fonction_Encoder/FB_Encoder_Scale_v1.0.md) | TC-P09-013 |
| [`FB_Encoder_Safety`](AF_Partie-09_Fonction_Encoder/FB_Encoder_Safety_v1.0.md) | TC-P09-010, 011, 012 |
| [`FB_Encoder_SpeedMeasure`](AF_Partie-09_Fonction_Encoder/FB_Encoder_SpeedMeasure_v1.0.md) | TC-P09-014 |
| [`FB_Encoder_SpeedMonitor`](AF_Partie-09_Fonction_Encoder/FB_Encoder_SpeedMonitor_v1.0.md) | TC-P09-015 |

⏸️ **M2 (rédaction effective des tests)** différé après implémentation du nouveau code — décision
utilisateur 2026-07-31. Ce catalogue reste la référence d'attribution, pas encore exécuté.

---

## 1. Composition — fiches FB dédiées

| Fiche | FB détaillé | Contenu |
|---|---|---|
| [`FB_Encoder_Abs`](AF_Partie-09_Fonction_Encoder/FB_Encoder_Abs_v1.0.md) | `FB_Encoder_Abs` | Acquisition brute bus EtherCAT, statut esclave & preset |
| [`FB_Encoder_Homing`](AF_Partie-09_Fonction_Encoder/FB_Encoder_Homing_v1.0.md) | `FB_Encoder_Homing` | Référencement nominal/unitaire, RETAIN Calib & doutes boot |
| [`FB_Encoder_Scale`](AF_Partie-09_Fonction_Encoder/FB_Encoder_Scale_v1.0.md) | `FB_Encoder_Scale` | Conversion linéaire points bruts ➔ mètres câble |
| [`FB_Encoder_Safety`](AF_Partie-09_Fonction_Encoder/FB_Encoder_Safety_v1.0.md) | `FB_Encoder_Safety` | Bornage [-99;+99] m, incohérence & verrou SEMI_AUTO |
| [`FB_Encoder_SpeedMeasure`](AF_Partie-09_Fonction_Encoder/FB_Encoder_SpeedMeasure_v1.0.md) | `FB_Encoder_SpeedMeasure` | Calcul vitesse m/s sur fenêtre 50 ms sans retard PT1 |
| [`FB_Encoder_SpeedMonitor`](AF_Partie-09_Fonction_Encoder/FB_Encoder_SpeedMonitor_v1.0.md) | `FB_Encoder_SpeedMonitor` | Surveillance & diagnostic des sauts de vitesse brusques |

---

## 2. Rôle et pipeline

```text
FB_Encoder_Abs ──► FB_Encoder_Homing ──► FB_Encoder_Scale ──► FB_Encoder_Safety ──► FB_Encoder_SpeedMeasure
   (bus EtherCAT)    (référencement,        (pts → m)           (bornage,             (vitesse câble,
    RawPos/preset)     RETAIN Calib)                              cohérence boot)        50ms/6 éch.)
```

2 instances (M1/M2), toutes dans `Acquisition (CFC)` — **producteur unique** position/vitesse.
`FB_Encoder_SpeedMonitor` (diagnostic, `Safety (CFC)`) : détecte variation brusque, **pas** de SafeStop direct.

Interfaces, `ErrorId` et logique détaillée : **fiches dédiées** (§1). Ce chapô ne documente que
le rôle machine du pipeline et son intégration — toute redite d'interface ici a dérivé de la
réalité par le passé (v1.0), elle est volontairement retirée.

---

## 3. DUT et bus

| DUT | Champs clés | Producteur | Consommateur |
|---|---|---|---|
| `ST_Encoder_Calib` | `HomingRefRaw`, `LastKnownRawPos`, `RestartCoherenceTolerancePts`(1000), `Homed`, `HomingSuspect` | `FB_Encoder_Homing` (VAR_IN_OUT) | lui-même, `FB_Encoder_Scale` |
| `ST_EncoderHMI` | `RawPos/Alarms/SlaveOperational/Error/ErrorId` | `Supervision` | IHM |
| `ST_WinchCfg` | `CfgTopSensorPos_M`, `CfgCableLimitAscent_M` | GVL_PERSISTENT (IHM) | `Acquisition/03/06` |
| `ST_WinchState` | `Homed/HomingBusy/.../HomingRefRaw/Encoder` | `Supervision` | IHM |
| `ST_WinchCmd` | `BtnHome/BtnConfirmCoherence/BtnHomingAtZero` | IHM | `Acquisition (CFC)` |

---

## 4. Intégration programme

### 4.1 État actuel du code (ST, avant migration)

```text
Acquisition  DI/simulation → HwIn.Winch.COD1/2_*
Acquisition  diag EtherCAT device
Acquisition  ← PRODUCTEUR UNIQUE position/vitesse
  1. instEncoderAbsM1/M2      (RawPos, EncoderAvailable)
  2. instHomingM1/M2          (Homed, HomingSuspect, HomingRefRaw) → écrit Calib RETAIN
  3. instEncoderScaleM1/M2    (CablePosM)
  4. instEncoderSafetyM1/M2   (CablePosMSafe, EncoderIncoherent)
  5. instEncoderSpeedMeasureM1/M2 (Speed_Mps, SignedSpeed_Mps, Valid)
Safety  instSpeedMonitorM1/M2 (diagnostic, seuils=0 actuellement)
PRG_02_Encoders  agrège EncoderFaultPresentM1/M2 := EncoderIncoherent → EncoderFaultPresent
Modes  EncoderFaultPresent → bloque SEMI_AUTO (repli MAINT_N1) — lu 1 scan après Acquisition
Treuils  ForbidAscent, TopLimitM:=CfgCableLimitAscent_M (≠ CfgTopSensorPos_M — limite exploit. ≠ cible homing)
Supervision  copie vers IHM
```

### 4.2 Cible — chaîne codéurs dans `PRG_02_Acquisition_CFC`

Acquérir une mesure physique, la mettre à l'échelle, en déduire une vitesse et juger sa validité
est **une seule responsabilité**. Les cinq étages `instEncoderAbs` → `instHoming` → `instEncoderScale`
→ `instEncoderSafety` → `instEncoderSpeedMeasure` (M1/M2/M3) rejoignent donc la page acquisition.

✅ Effet attendu : les instances aujourd'hui dupliquées entre `PRG_ACQUISITION_CFC` et
`PRG_02_Encoders` (`instEncoderAbsM1/M2`, `instEncoderScaleM1/M2`, `instHomingM1/M2`) sont
unifiées, avec un producteur unique. Le cycle prouvé `Acquisition ↔ Encoders` disparaît.

⚠️ **Aucune sémantique codéur ne change** : les `ErrorId`, les seuils (`PositionMinM/MaxM` = ±99.0 m),
les polarités, `HomingSuspect`, `EncoderIncoherent` et la procédure terrain §5 restent identiques.
Seule **l'affectation POU** change.

⚠️ **Cette fusion n'est pas réalisable en l'état** : le homing lit une donnée produite par un POU
aval. Ce point est ouvert — §4bis.

📌 Lot de migration : **M1** de `DOC/AUDITS/Architecture/PLAN_EXECUTION_MIGRATION_7POU.md` (C4, rebuild).

---

## ⚖️ 4bis. Point d'arbitrage OUVERT — le homing lit le mode de marche

> 🚨 **Statut : ARBITRAGE REQUIS, non tranché.** À instruire au lancement du lot **M1**.
> Cette section **constate un fait de code**. Elle ne décide rien, ne propose aucune option
> préférée, et ne modifie aucune sémantique safety.

### Dépendance prouvée (`CODE/MAIN/PRG_02_Encoders.st`)

`FB_Encoder_Homing` M1 et M2 reçoivent trois entrées dérivées de `PRG_MODES_CFC` :

| Ligne | Port alimenté | Expression exacte lue dans le code |
|---|---|---|
| `:72` | `Mode` (M1) | `PRG_MODES_CFC.Auth.Mode` |
| `:74-75` | `UnitaryMode` (M1) | `(PRG_MODES_CFC.Auth.Mode = E_Mode.MAINT_N2) AND (PRG_MODES_CFC.Auth.JoystickWinchSelectArbitrated <> 3)` |
| `:76` | `WinchSelected` (M1) | `(PRG_MODES_CFC.Auth.JoystickWinchSelectArbitrated = 1)` |
| `:122` | `Mode` (M2) | `PRG_MODES_CFC.Auth.Mode` |
| `:124-125` | `UnitaryMode` (M2) | `(PRG_MODES_CFC.Auth.Mode = E_Mode.MAINT_N2) AND (PRG_MODES_CFC.Auth.JoystickWinchSelectArbitrated <> 3)` |
| `:126` | `WinchSelected` (M2) | `(PRG_MODES_CFC.Auth.JoystickWinchSelectArbitrated = 2)` |

La même lecture existe sur les étages voisins de la chaîne : `instEncoderAbsM1/M2` (`:55`, `:105`)
et `instEncoderSafetyM1/M2` (`:155`, `:168`) reçoivent également `PRG_MODES_CFC.Auth.Mode`.

### Pourquoi c'est bloquant pour M1

`FB_Encoder_Homing` utilise ces entrées pour autoriser ses deux flux : `MAINT_N1` pour le flux
nominal, `MAINT_N2` + `WinchSelected` pour le flux unitaire (fiche `FB_Encoder_Homing` §3, bits
`ErrorId` 0 « Mode non autorisé » et 1 « Mauvais treuil sélectionné »).

Or dans l'architecture cible, l'acquisition est au **rang 02** et les modes au **rang 03** :

```text
02 PRG_02_Acquisition_CFC   ← devrait contenir instHomingM1/M2
03 PRG_03_Modes_Cycle_CFC   ← produit Auth.Mode et Auth.JoystickWinchSelectArbitrated
```

Le consommateur s'exécuterait donc **avant** son producteur. La règle d'ordonnancement
(`AF_Partie-02` §4) l'interdit sauf retard d'un scan explicitement documenté, et l'invariant
projet interdit tout retard d'un scan sur `Reset`, `SafeStop`, `PowerCutOff`, une commande ou une
sortie.

### Ce qui doit être tranché — et par qui

🚨 **La question porte sur une autorisation de mouvement de référencement. Elle relève d'un
arbitrage utilisateur/sécurité, pas d'un choix d'agent.** Aucune réponse ne doit être déduite,
inventée ou reformulée depuis la présente documentation.

Questions ouvertes à instruire, avec preuve de code à l'appui :

1. `Mode`, `UnitaryMode` et `WinchSelected` sont-ils des **autorisations** (donc légitimement
   produites par les Modes au rang 03), ou des **faits d'entrée** reconstructibles au rang 02 ?
2. Si la dépendance est irréductible, où le homing doit-il vivre pour respecter la règle
   producteur-avant-consommateur, sans découper la chaîne codéur en deux propriétaires ?
3. Quel serait l'effet exact d'un retard d'un scan sur `Mode` côté homing — et cet effet
   touche-t-il une commande, un interlock ou une autorisation de mouvement ?

⛔ **Tant que ce point n'est pas tranché par l'utilisateur, le lot M1 ne peut pas déplacer
`instHomingM1/M2`.** Référence pilotage : `DOC/AUDITS/Architecture/PLAN_EXECUTION_MIGRATION_7POU.md`
§4, lot M1, point dur n°2.

---

## 5. Procédure terrain

**Cotes réelles (RETAIN, MES-009)** — ⚠️ différentes du défaut déclaré :
| Paramètre | Défaut déclaré | Réel (RETAIN) |
|---|---|---|
| `CfgTopSensorPos_M` | 8.5 m | **8.0 m** |
| `CfgCableLimitAscent_M` | 8.0 m | **7.5 m** |

**Nominal** :
1. **Confirmation visuelle benne ouverte** (opérateur, avant tout mouvement) — tant que M1/M2 ne
   sont pas référencés, `CablePosM` est potentiellement faux : aucun interlock automatique basé
   sur la position (y compris l'état benne côté `FB_Bucket`) n'est fiable à ce stade. Seule une
   vérification visuelle permet de lancer les 2 moteurs ensemble en confiance.
2. Monter M1+M2 au capteur haut → relâcher (arrêt confirmé) → `BtnHome` → `Homed` sur les 2
   instances indépendamment. `HomingRefRaw` calculé, `CablePosM≈8.0m`.
3. **Une fois référencé**, `CablePosM` redevient fiable : presser `ConfirmOpenPosition`
   (`FB_Bucket`) pour amorcer le suivi automatique `BucketState.IsOpen` — action **distincte** de
   l'étape 1 (vérification visuelle pré-homing) et **postérieure** à elle, voir
   `CODE/TREUILS/BENNE/FB_Bucket.st` en-tête REX 2026-07-08.

**Unitaire (MAINT_N2)** : sélectionner treuil → manœuvrer → arrêt confirmé → `CfgHomingTargetM` → `BtnHome`.

**Bouton spécial** `BtnHomingAtZero` : force homing au centre exact (0.0 m), usage mise en service.

**Contrôle visuel `CfgTopSensorPos_M`** : référencer au capteur haut → descendre au contact visuel eau → si `CablePosM ≠ 0.00m`, ajuster `CfgTopSensorPos_M` de l'écart constaté (RETAIN) et répéter.

---

## 6. Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | ✅ résolu | `Homed=FALSE` seul (sans `HomingSuspect`) ne bloque pas `SEMI_AUTO` | Comportement voulu — non-référencé ≠ incohérent. Traitement cible (M1/M2 uniquement, décision 2026-07-31) : signalement IHM (`Homed` déjà exposé) + vitesse forcée palier 1 pour le cycle de référencement. Détail et TODO câblage : fiche `FB_Encoder_Homing` §4 |
| 2 | P1 | Bits 6/7/8 `ErrorId` Homing non codés | TBD legacy, non résolu |
| 3 | P1 | `CfgTopSensorPosM` : 2 valeurs cohabitent (8.5 déclaré / 8.0 réel) | RETAIN (8.0 m) prime — écart documenté, pas une action |
| 4 | P2 | `CodeSeqTriggerCmd` jamais résolu | TODO ouvert |
| 5 | P2 | `SpeedMonitor` seuils inertes (`0`/`T#0ms`) | Volontaire jusqu'à T45 — ⚠️ voir fiche `FB_Encoder_SpeedMonitor` §4 : activer `SpeedGuardEnable` sans régler `SpeedStabilityTimeout` bride la machine au palier 1 en permanence |
| 6 | info | `BtnHomingAtZero` — combiné avec `BtnHome` en amont dans `PRG_02_Encoders`, pas un port `FB_Encoder_Homing` séparé | Clarifié fiche Homing §2 |
| 7 | info | Numérotation `ErrorId` différente par FB (pas de table unifiée) | Assumé — chaque fiche documente sa propre table |
| 8 | 🔴 **P0 hors doc** | Perte de bus codeur (`EncoderAvailable=FALSE`) ⇒ `RawPos` gelé ⇒ position reste dans la plage ⇒ `SEMI_AUTO` reste autorisé sur une position figée | Trou de sécurité réel, indépendant de cette doc — à instruire en lot dédié C3/C4, cross-ref fiche `FB_Encoder_Safety` §3 |
| 10 | 🚨 **Arbitrage requis** | `instHomingM1/M2` lit `PRG_MODES_CFC.Auth.*` (`PRG_02_Encoders.st:72,74-76,122,124-126`) : dans la cible, l'acquisition (rang 02) précède les modes (rang 03) | **Non tranché** — arbitrage utilisateur/sécurité au lancement du lot M1. Faits et questions ouvertes : §4bis. Aucune décision ne doit être déduite par un agent |
| 9 | 🟠 **Nommage** | Suffixe d'unité `_M`/`_Mps` incohérent au sein du domaine CODEURS : `CfgTopSensorPosM`, `CfgHomingTargetM`, `PositionMinM`/`PositionMaxM`, `CablePosM` (sans underscore) **vs** `Speed_Mps`/`SignedSpeed_Mps` de `FB_Encoder_SpeedMeasure` (avec underscore, conforme). `FB_Encoder_SpeedMonitor` aggrave : `SpeedMps`/`SpeedDeltaMps`/`SpeedVariationThresholdMps` sans underscore, à côté de `Speed_Mps` du FB voisin. Règle : `NAMING_CONVENTION.md` §Suffixes d'unité, « toujours précédés d'un underscore ». Egalement : `ST_WinchCfg.CfgTopSensorPos_M` (IHM, avec underscore) **et** le port FB `CfgTopSensorPosM` (sans) désignent la même notion sous 2 formes. **Ne pas renommer au fil de l'eau** (casse IHM/bundle, `NAMING_CONVENTION.md` §Variables IHM) — lot de renommage dédié à trancher séparément. |

---

## 7. Documents liés

| Doc | Lien |
|---|---|
| AF02 | Acquisition, producteur unique |
| AF03 | Contrat FB mouvement (Homing n'en est pas un) |
| AF05 | Modes — MAINT_N1/N2, blocage SEMI_AUTO |
| AF06 | E/S physiques codeurs |
| AF10 | Winch — consommateur position/vitesse, Méca D, vitesse forcée palier 1 (M1/M2) |
| AF13 | Simulation codeurs |
| Code | `CODE/CODEURS/*.st`, `CODE/MAIN/PRG_02_Encoders.st` |
