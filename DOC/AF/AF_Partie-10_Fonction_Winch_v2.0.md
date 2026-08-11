# Analyse Fonctionnelle — Partie 10 : Fonction Winch M1/M2 (v2.0)

> Rôle : mouvement treuils M1 (Retenue) / M2 (Benne), safety métier, synchro, benne, barrière finale.
> **Détail technique par FB** : voir les 9 fiches dédiées (§1). Ce chapô reste au niveau machine
> + intégration programme + TBD Lot 4 — il ne recopie pas les interfaces/`TC-` des fiches.
> Source code actuel : `CODE/TREUILS/*.st` · instances dans `PRG_TREUILS_CFC.st` et `PRG_SAFETY_CFC.st` (tous deux ST actuels), `PRG_OUTPUTS_LD.st` (Ladder généré). Cible de migration CFC native : **une seule page** `PRG_04_Treuils_Benne.xml` — elle absorbe la partie M1/M2/benne de `PRG_SAFETY_CFC` (safety câblée en parallèle visible sur la même page). Aucune page safety séparée n'est une cible.
> 🗺️ Architecture cible faisant foi : `DOC/AF/AF_Partie-02_Architecture_Programme_v3.1.md` §2 et §4.
> Extraction : `DOC/TESTS/CHECKLISTS/EXTRACTIONS/FB_Winch_Extraction_Code_v1.0.md`.
> v1.14 archivée : `ARCHIVES/Doc/AF_Partie-09_Fonction_Winch_v1.14.md`.

## 🧭 Sommaire

1. Composition — fiches FB dédiées
2. Rôle machine
3. DUT et bus
4. Intégration programme
5. Alertes et écarts (transverses)
6. Commande vitesse par palier — décidé et implémenté (2026-08-06)
7. Documents liés

## 🧪 Points de validation

Catalogue `TC-P10-*` **réparti dans les fiches FB** (propriétaire unique par fiche, pas
dupliqué ici) :

| Fiche | TC couverts |
|---|---|
| [`FB_Winch`](AF_Partie-10_FB_Winch_v1.0.md) | <nobr><code>TC-P10-011</code></nobr>, 017, 018, 019 |
| [`FB_Safety_Winch`](AF_Partie-10_FB_Safety_Winch_v1.0.md) | <nobr><code>TC-P10-001</code></nobr> à 010 |
| [`FB_WinchSync`](AF_Partie-10_FB_WinchSync_v1.0.md) | <nobr><code>TC-P10-014</code></nobr>, 015, 016 |
| [`FB_WinchOutputInterlock_LD`](AF_Partie-10_FB_WinchOutputInterlock_LD_v1.0.md) | <nobr><code>TC-P10-012</code></nobr>, 013, 020, 021, 022 |
| [`FB_Bucket`](AF_Partie-10_FB_Bucket_v1.0.md) | <nobr><code>TC-P10-023</code></nobr> à 034 |
| [`FB_Winch_Symmetry`](AF_Partie-10_Fonction_Winch/FB_Winch_Symmetry_v1.0.md) | Diagnostic MES-008, symétrie |
| [`FB_SpeedStep`](AF_Partie-10_Fonction_Winch/FB_SpeedStep_v1.0.md) | Décodage paliers 1..5 & garde-fou |
| [`FB_WinchLoadEstimator`](AF_Partie-10_Fonction_Winch/FB_WinchLoadEstimator_v1.0.md) | Diagnostic charge 2D |
| [`FB_DriftGuard`](AF_Partie-10_Fonction_Winch/FB_DriftGuard_v1.0.md) | Dérive position sous frein |

---

## 1. Composition — fiches FB dédiées

| Fiche | FB détaillé | Contenu |
|---|---|---|
| [`AF_Partie-10_FB_Winch_v1.0.md`](AF_Partie-10_FB_Winch_v1.0.md) | `FB_Winch` | Mouvement, palier, sens (🔧 2026-08-06 : frein retiré, voir §1bis) |
| [`AF_Partie-10_FB_Safety_Winch_v1.0.md`](AF_Partie-10_FB_Safety_Winch_v1.0.md) | `FB_Safety_Winch` | 7 mécanismes A-G, masques, bypass |
| [`AF_Partie-10_FB_WinchSync_v1.0.md`](AF_Partie-10_FB_WinchSync_v1.0.md) | `FB_WinchSync` | Synchro niveau 1, couplage croisé |
| [`AF_Partie-10_FB_WinchOutputInterlock_LD_v1.0.md`](AF_Partie-10_FB_WinchOutputInterlock_LD_v1.0.md) | `FB_WinchOutputInterlock_LD` | Barrière finale, watchdog frein, anti-redémarrage |
| [`AF_Partie-10_FB_Bucket_v1.0.md`](AF_Partie-10_FB_Bucket_v1.0.md) | `FB_Bucket` (+ `FB_DiveSearch`, `FB_ExtractionSequence`) | Benne, désynchronisation M1/M2, glissement, assistants |
| [`AF_Partie-10_Fonction_Winch/FB_Winch_Symmetry_v1.0.md`](AF_Partie-10_Fonction_Winch/FB_Winch_Symmetry_v1.0.md) | `FB_Winch_Symmetry` | Diagnostic passif symétrie & décalages M1/M2 |
| [`AF_Partie-10_Fonction_Winch/FB_SpeedStep_v1.0.md`](AF_Partie-10_Fonction_Winch/FB_SpeedStep_v1.0.md) | `FB_SpeedStep` | Décodeur consigne % -> contacteurs & garde-fou |
| [`AF_Partie-10_Fonction_Winch/FB_WinchLoadEstimator_v1.0.md`](AF_Partie-10_Fonction_Winch/FB_WinchLoadEstimator_v1.0.md) | `FB_WinchLoadEstimator` | Estimation charge 2D palier x vitesse |
| [`AF_Partie-10_Fonction_Winch/FB_DriftGuard_v1.0.md`](AF_Partie-10_Fonction_Winch/FB_DriftGuard_v1.0.md) | `FB_DriftGuard` | Capture & surveillance dérive sous frein |

<div style="display:flex; flex-direction:column; align-items:stretch; width:100%; margin:12px 0;">
  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #38bdf8; padding:6px 10px; border-radius:4px; font-size:12px;">
    📡 &nbsp;<b>FB_Encoder_SpeedMeasure / Abs</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Acquisition positions & vitesses M1/M2</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#38bdf8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">Positions M1/M2 & Vitesses</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #f43f5e; padding:6px 10px; border-radius:4px; font-size:12px;">
    🛡️ &nbsp;<b>FB_Safety_Winch (×2) & FB_WinchSync (×1)</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Contrôle dérive (DriftGuard), synchro M1/M2 & sécurités</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#f43f5e" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">Autorisations mouvement & Limites</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #fbbf24; padding:6px 10px; border-radius:4px; font-size:12px;">
    ⚙️ &nbsp;<b>FB_Winch (×2) & FB_Bucket (×1)</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Pilotage treuils M1/M2, décodeur paliers FB_SpeedStep</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#fbbf24" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">Ordres contacteurs & Freins</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #4ade80; padding:6px 10px; border-radius:4px; font-size:12px;">
    🔒 &nbsp;<b>FB_WinchOutputInterlock_LD (×2)</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Barrière finale matérielle outputs & BrakeCmd</span>
  </div>
</div>

Benne = sous-fonction M2 : aucune I/O propre, réutilise `FB_Winch` M2. Fiche dédiée dans ce dossier.

### 1bis. Frein — couplage direct (🔧 2026-08-06, demande client)

`FB_Brake` (COMMUN, séquence temporisée frein manque-courant) est **retiré de la composition
`FB_Winch`** — reste utilisé tel quel par `FB_Translation` (M3), non touché. Décision client :
le frein ne doit jamais pouvoir diverger de l'état des contacteurs de sens, donc plus de FB
intermédiaire avec sa propre temporisation/état — couplage structurel direct.

Nouvelle architecture :
- `FB_Winch` ne produit plus aucune sortie frein (`BrakeCmd`/`BrakeCommandOpenConfirmed`/
  `BrakeContactorCheck` retirés de son interface).
- `FB_WinchOutputInterlock_LD` calcule `BrakeCmd := RelayFwd OR RelayRev` **après** avoir
  finalisé ces deux sorties (§5 de sa logique) — hérite automatiquement de toutes leurs
  conditions de sécurité (Error, RestartInhibit, RestartRequired, MotorRequest) sans les
  répéter. Watchdog conservé : `BrakeFeedback` (retour physique brut, ex-DI
  `Mx_BrakeIsOpen_DI`, câblé directement depuis `PRG_04`) comparé à `BrakeCmd`, timeout
  500 ms → `ErrorId` bit0 → coupe le mouvement (mécanisme `Error` déjà existant).
- `PRG_06_Outputs_LD` recalcule **la même expression** indépendamment sur les DQ finaux
  (`M1BrakeCmd := M1RelayFwd OR M1RelayRev`) pour piloter la bobine physique — visible
  directement dans le réseau Ladder, sans ouvrir `FB_WinchOutputInterlock_LD` (même doctrine
  de visibilité que les autres barrières finales, voir en-tête `PRG_06_Outputs_LD.st`).

⚠️ Contrepartie assumée (décision client, pas une omission) : le frein n'attend plus de
confirmation physique du contacteur de sens avant de s'ouvrir (l'ancien `ContactorEngaged`,
anti-retombée du 2026-08-06 matin, est retiré) — le couplage est désormais sur la **commande**
`RelayFwd`/`RelayRev`, pas sur leur confirmation terrain. Le risque théorique (frein ouvert
avant engagement mécanique réel du contacteur) est jugé acceptable par le client au profit de
la garantie structurelle "jamais de mouvement commandé sans frein desserré".

### 1ter. Tempo de reprise basée sur l'état frein, pas le centre joystick (🔧 2026-08-07)

**Décision client** : `RestartDelay` (interlock final, tempo avant réautorisation d'un mouvement
après arrêt) ne doit plus démarrer sur `FwdRevSpeedFeedbackOff` (retour contacteur, image
indirecte du centre joystick) mais sur `NOT BrakeFeedback` — c'est-à-dire une fois le frein
**réellement confirmé fermé** par son propre retour physique. Plus fiable que le centre
joystick (qui ne dit rien de la réalité mécanique et n'existe que dans certains modes) : l'état
frein fonctionne identiquement en Mode Boutons IHM, Mode Joystick, ou un futur séquenceur auto.

- `RestartDelay` : `T#1000ms` → **`T#1500ms`**, décompté à partir de la confirmation frein
  fermé (pas de la commande d'arrêt) — délai réel total = fermeture mécanique du frein +
  1500ms, volontairement plus prudent que l'ancien calcul.
- `RestartRequired` reste armé **instantanément** sur l'arrêt commandé (`NOT MotorRequest`,
  bloque §5 dès ce scan) — seul le **décompte** de la tempo change de déclencheur.

**Un seul verrou de fait entre deux reprises, reprise ou inversion confondues** : `RestartDelay`
(1500ms + fermeture réelle frein) est structurellement toujours ≥ `DirectionInterlockDelay`
(400/900ms max, §1). Après une pause réelle suffisante (~2s), les deux verrous sont déjà levés
en tâche de fond avant même la nouvelle demande opérateur — la reprise est alors instantanée,
que la nouvelle demande soit dans le même sens ou inversée. Pas un cumul des deux tempos, un
seul verrou dominant (`RestartDelay`, toujours le plus long des deux).

---

## 2. Rôle machine

Treuil M1 (Retenue) et M2 (Benne) : levage/retenue de charge par câble, 5 paliers de vitesse
par contacteurs discrets (pas de variateur continu), frein à manque de courant. Sécurité par
défense en profondeur (7 mécanismes détaillés dans la fiche `FB_Safety_Winch`).

---

## 3. DUT et bus

| DUT | Producteur | Consommateur |
|---|---|---|
| `ST_WinchFinalInterlockRequest` | `PRG_TREUILS_CFC.st` actuel ; cible `PRG_04_Treuils_Benne.xml` absente | `PRG_OUTPUTS_LD.st` actuel ; cible `PRG_06_Outputs_LD` |
| `ST_SpeedStepTable` | config IHM/RETAIN | `FB_Winch`/`FB_SpeedStep` |
| `ST_SafetyWinch` | `Supervision` (agrège) | IHM |
| `ST_BypassWinch` | IHM RETAIN | `FB_Safety_Winch` |
| `ST_ContactorCheck` (COMMUN) | `FB_Winch` (contacteurs sens/vitesse) | `FB_Safety_Winch`, IHM |

---

## 4. Intégration programme

### 4.1 État actuel du code (ST, avant migration)

```text
Safety ST actuel (`PRG_SAFETY_CFC.st`)        instSafetyWinchM1/M2, instSpeedMonitorM1/M2, instLoadEstimatorM1/M2
Treuils ST actuel (`PRG_TREUILS_CFC.st`)
  §1  instBucket (Benne, appelé EN PREMIER — évite fenêtre de commande manuelle parasite)
  §2  Arbitrage M1 (SEMI_AUTO / MAINT / joystick / boutons)
  §3  Arbitrage M2 (Benne prioritaire > SEMI_AUTO > joystick/boutons)
  §3bis Assistance maintenance (DiveSearch/ExtractionSequence)
  §3ter Coupure immédiate M1/M2 en fin de cycle benne
  instWinchSync (lu 1 scan après arbitrage)
  §5  Limites basses + couplage croisé
  §6/7 Exécution instWinchM1/M2
  §8  Publication ST_WinchFinalInterlockRequest → Outputs
Outputs Ladder (`PRG_OUTPUTS_LD.st`)      instWinchOutputInterlockM1/M2_LD (Q finales)
```

**Dépendances** : Joystick (`AxisCmdY`, `DeadmanArmed`), Modes (`JoystickWinchSelectArbitrated`,
`InhibitM1/M2`, `SyncEnable`), Encodeurs (`CablePosM`, `Homed`, vitesse), Cycle (SEMI_AUTO).

### 4.2 Cible — `PRG_04_Treuils_Benne` (rang 04 de la `MainTask`)

Découpage **par ensemble mécanique**. M1 (retenue) et M2 (benne) sont indissociables : la benne
est suspendue entre les deux, et l'ouverture, la fermeture, la synchro et le câble mou dépendent
de leur **combinaison**. Une seule page les porte, avec leur safety.

| Ce qui migre dans `PRG_04_Treuils_Benne` | Provenance actuelle |
|---|---|
| Arbitrages M1/M2, benne, synchro, assistants plongée/extraction | `PRG_TREUILS_CFC` |
| `instSafetyWinchM1/M2`, `instSpeedMonitorM1/M2`, `instLoadEstimatorM1/M2` | partie M1/M2/benne de `PRG_SAFETY_CFC` |

⚠️ **Aucune sémantique safety ne change** : les mécanismes Méca A→E, les bits `ErrorId` 14/15,
`ForbidAscent`/`ForbidDescent`, les seuils et les polarités restent ceux décrits dans les fiches FB.
Seule **l'affectation POU** change : la safety devient visible en parallèle des blocs métier sur
la même page, ce qui supprime par construction le cycle prouvé `Safety ↔ Treuils`.

`PowerCutOff` : cette page publie **sa demande** M1/M2. L'agrégation et la coupure restent la
responsabilité exclusive de la barrière finale `PRG_06_Outputs_LD` (AF02 §2). Aucun POU « safety
machine globale » n'existe dans la cible.

📌 Lot de migration : **M3** de `DOC/WFLOW/AUDITS/Architecture/PLAN_EXECUTION_MIGRATION_7POU.md` (C4, rebuild).

---

## 5. Alertes et écarts (transverses)

| # | Gravité | Point | Détail |
|---|---|---|---|
| 1 | info | 7 mécanismes (A-G), pas 5 | `FB_Safety_Winch` §6 |
| 2 | info | Doc AF02 legacy décrit CFC générique ≠ PRG réels | Architecture cible à part |

Écarts spécifiques à un FB (double délai palier, `DelayMotorDecel` code mort, garde-fou non
persistant) : voir la fiche FB concernée (§7 de chaque fiche) et §6 ci-dessous.

---

## 6. Commande vitesse par palier — DÉCIDÉ et implémenté (retour terrain 2026-08-06)

> ✅ **Décision prise et codée le 2026-08-06**, en connaissance de cause et **sans les essais en
> charge réels** initialement posés comme préalable (`PLAN_TASK.md` Lot 4, T91) : retour terrain
> répété d'un délai joystick→contacteur de plusieurs secondes, tracé à la rampe %/s
> (`CfgRampAccelRate=10%/s`) qui retardait `RequestedStep>0`. Décision utilisateur explicite de
> remplacer immédiatement la rampe par une temporisation fixe par palier, asymétrique
> montée/descente, plutôt que d'attendre une campagne d'essais en charge. À surveiller au
> prochain cycle d'essais réels (T91 reste un point de vigilance, pas classé clos).

### 6.1 Mécanisme implémenté (`FB_Winch.st`, commit 2026-08-06)

| Mécanisme | Avant | Après (implémenté) |
|---|---|---|
| Accélération/décélération | `FB_Ramp` générique, %/s (`CfgRampAccelRate`/`CfgRampDecelNormalRate`/`CfgRampDecelFastRate`, retirés) | `RampTargetPct` alimente directement `FB_SpeedStep` (pas de lissage) ; progressivité assurée par la tempo par palier ci-dessous |
| Hausse palier | Délai fixe unique `T#1s500ms`, symétrique montée/descente | `EffectiveStepDelay := EffectiveDirectionInterlockDelay + T#100ms` → **500ms en descente / 1000ms en montée** (déduit de l'interlock de sens, pas un réglage séparé) |
| Interlock changement de sens | `DirectionInterlockDelay` unique 200ms | Asymétrique : `DirectionInterlockDelayDescent := T#400ms` / `DirectionInterlockDelayAscent := T#900ms`, toujours < la tempo palier correspondante (interlock jamais le facteur limitant, garanti par construction) |
| Arrêt (relâchement joystick) | Suivait la rampe de décélération (contacteurs engagés plusieurs secondes après l'ordre d'arrêt) | Coupure **instantanée** de `RelayFwd`/`RelayRev` et des 4 contacteurs de vitesse dès `Direction=0`, même scan |
| Coupure finale (freinage) | `DelayMotorDecel` code mort dans `FB_Brake.st` | Sans objet côté treuil : `FB_Brake` retiré (§1bis), le frein suit désormais `RelayFwd OR RelayRev` sans aucune temporisation |
| Garde-fou vitesse mesurée | Existe, désactivé, non persistant | Inchangé par ce lot |
| Bandes de vitesse par palier | Théoriques, jamais mesurées | Voir §6.3, non traité par ce lot |

### 6.2 Doctrine anti-retombée associée (`FB_WinchOutputInterlock_LD.st`, commit 2026-08-06)

⚠️ **Révisée le même jour (§1bis)** : la doctrine ci-dessous (contacteur confirmé physiquement
AVANT ouverture frein, via `ContactorEngaged := NOT FwdRevSpeedFeedbackOff`) a été implémentée
le matin du 2026-08-06, puis **remplacée l'après-midi même** par un couplage direct sur la
commande (`BrakeCmd := RelayFwd OR RelayRev`, décision client — voir §1bis pour le raisonnement
et la contrepartie assumée). Conservé ici pour l'historique de la décision, périmé en pratique.

**T91 (asymétrie montée/descente) et T93 (tempo par palier au lieu de rampe %/s) sont ainsi
implémentés** ; seule l'apprentissage/validation en charge réelle (T91 volet essais) reste ouvert.

### 6.3 TBD — Apprentissage vitesse par palier (nouveau, T96)

**Constat** : `SpeedBandMaxMps` est aujourd'hui rempli à la main avec des valeurs théoriques.
Aucun mécanisme de mesure/calibration automatique n'existe (T95 mentionne "étendre
`FB_Winch_Symmetry`" sans détailler de mécanisme).

**Besoin exprimé** :

| Élément | Détail |
|---|---|
| Déclencheur | Mode maintenance dédié : "Apprentissage à vide" et "Apprentissage en charge" (2 jeux de bandes distincts) |
| Capture | Sur chaque palier, après stabilité (~1-2 s), mesure vitesse peu filtrée (évite un pic transitoire) |
| Stockage | Remplace/alimente `SpeedBandMaxMps[1..5]`, un jeu par condition (vide/charge) |
| Robustesse | Valeur brute jamais utilisée telle quelle : **offset réglable** (marge) avant utilisation comme seuil de garde-fou |
| Cas d'usage cité | Alimentation groupe électrogène vs secteur → vitesse réelle différente à charge égale ; l'apprentissage évite une calibration manuelle poste par poste |

**TBD à trancher avant code** :
- Bit unique (sélection vide/charge par ailleurs) ou 2 bits dédiés distincts ?
- Portée : par treuil (M1/M2 séparés) — cohérent avec `SpeedBandMaxMps` déjà par instance
- Durée de stabilité et fenêtre de mesure (lien `FB_Encoder_SpeedMeasure`, déjà fenêtre 50 ms — probablement insuffisant seul, agrégation supplémentaire à définir)
- FB dédié proposé (nom informatif, pas engageant) : `FB_WinchSpeedLearning`

Suivi pilotage : `PLAN_TASK.md` T96.

### 6.3bis ⚖️ Surveillance de symétrie M1/M2 (`FB_Winch_Symmetry` — MES-008 & Diagnostic)

**Objectif** : Identifier passivement si un décalage entre les deux treuils (M1 et M2) provient d'un retard d'automatisme/contacteur ou d'un problème mécanique/frein.

**Métriques mesurées passivement (exécuté dans le ST actuel `PRG_TROUBLESHOOTING_CFC.st`, cible `PRG_07_Supervision` qui absorbe le troubleshooting en lecture seule stricte)** :
- `DeltaStartDelay_Ms` : Écart de temps au démarrage des mouvements M1/M2.
- `DeltaBrakeReleaseTime_Ms` & `DeltaBrakeApplyTime_Ms` : Écart de temps d'ouverture/fermeture effective des freins.
- `DeltaStopTime_Ms` & `DeltaStopDistance_Mm` : Écart de temps et de distance parcourue lors de la phase d'arrêt.
- `MaxSyncDeviation_M` : Écart maximal de position synchro pendant la course.

**Consommation IHM / Diagnostic** : Ces données alimentent `ST_WinchSymmetryHMI` et la page Diagnostic de l'IHM pour orienter la maintenance terrain.

### 6.4 Ne pas faire sans étude terrain (rappel)

- Ne pas trancher `DelayMotorDecel` (supprimer vs implémenter) sans les essais MES-006 (audit C4)
- Ne pas activer `SpeedGuardEnable` avant calibration réelle (T94 dépend de T95)
- Ne pas remplacer la rampe %/s sans valider l'impact sur `FB_Cycle`, IHM, `GVL_PERSISTENT`

---

## 7. Documents liés

| Doc | Lien |
|---|---|
| AF01 | AU/PowerCutOff — chaîne électrique |
| AF03 | Contrat FB mouvement |
| AF05 | Modes — InhibitM1/M2, SyncEnable |
| AF06 | E/S physiques treuils |
| AF09 | Codeurs — Homed, position, vitesse |
| PLAN_TASK | Lot 4 (T87/T91/T93/T94/T95/T96) — décision non prise, étude terrain requise |
| Code | `CODE/TREUILS/*.st`, `CODE/MAIN/PRG_04_Treuils_Benne.st` (ST actuel) ; cible `PRG_04_Treuils_Benne.xml` absente |
