# REGISTRE_VALEURS_TREUIL_STATUTS_v1.0 — Statut de CHAQUE valeur du modèle treuils

> 🔒 **DOCUMENT DE RÉFÉRENCE GELÉ** — **source unique des STATUTS**. Les autres documents
> (`REFERENCE_CALAGE`, `PLAN_T317`, plans de test) portent les **dérivations et commentaires**,
> mais **le statut d'une valeur se lit ICI**, et nulle part ailleurs.
> Toute contradiction entre ce registre et un autre document se tranche **en faveur de ce registre**.
>
> 🎯 **Règle fondatrice** : le simulateur travaille avec des **hypothèses** — c'est normal et
> assumé — mais **une hypothèse ne doit JAMAIS pouvoir être lue comme une mesure**.
> Ce registre rend cette frontière **vérifiable**, ligne par ligne.
>
> 📅 Créé le **2026-09-20** · Auteur : `DSH01` · Gelé à la **v1.0** (révision = nouvelle version, jamais une retouche silencieuse).

---

## 🏷️ Statuts — **référentiel canonique du projet** (+ un qualificatif)

Le référentiel reste **celui du projet** (5 classes, aucune autre) : `MESURÉE` · `DOCUMENTÉE` · `ESTIMÉE` · `SYNTHÉTIQUE` · `INCONNUE`.

| Statut | Définition | Qui peut le poser |
|---|---|---|
| **`MESURÉE`** | Relevé physique, plaque, trace machine, ou **dérivation arithmétique** d'une donnée mesurée | Preuve obligatoire (fichier + date + méthode) |
| **`DOCUMENTÉE`** | Écrite dans le code ou une doc du projet, sans preuve physique externe | Lecture de fichier (avec `fichier:ligne`) |
| **`ESTIMÉE`** | Estimation utilisateur ou **calcul non validé** par une mesure | Décision humaine tracée |
| **`SYNTHÉTIQUE`** | Valeur **inventée** dans le code, sans base physique (souvent incohérente) | Existant à corriger |
| **`INCONNUE`** | Non déterminée — **bloque** toute qualification | Mesure requise |

### 🟡 Qualificatif `HYPOTHÈSE ASSUMÉE` (sous-catégorie d'`ESTIMÉE`)

Une valeur **`ESTIMÉE` posée sciemment pour faire fonctionner le simulateur** est notée **`ESTIMÉE (HYPOTHÈSE ASSUMÉE)`**.
C'est le cas de **toute la section B** : ce sont les valeurs qui **font tourner le banc** en attendant les mesures.
👉 Le qualificatif **ne crée pas de nouvelle classe** : il rend simplement visible la frontière que l'humain exige.

🚫 **Interdits** : présenter une `ESTIMÉE` (même « assumée ») comme une mesure · faire passer une `SYNTHÉTIQUE` en `ESTIMÉE` sans décision tracée · utiliser une `INCONNUE` comme si elle était connue.

---

# A. ✅ DONNÉES RÉELLES — **GELÉES** (ne pas modifier ; toute évolution = nouvelle mesure datée)

## A1. Moteur — **plaque signalétique** (transmise par l'humain, **2026-09-20**)

| Valeur | Statut | Source |
|---|---|---|
| **Puissance nominale `Pn = 132 kW`** | **MESURÉE** | plaque moteur 2026-09-20 |
| **Vitesse nominale `n = 1475 tr/min`** | **MESURÉE** | plaque |
| **`cosφ = 0,86`** | **MESURÉE** | plaque |
| **`η = 93,5 %`** | **MESURÉE** | plaque |
| **Service `S3 - 40 %`** | **MESURÉE** | plaque (⇒ levage par cycles, pas continu) |
| `f = 50 Hz` · pôles = 4 (ns = 1500) | **MESURÉE** | plaque + construction |
| **Stator : 400 V Δ · `In = 242 A`** | **MESURÉE** | plaque |
| **Rotor : `E2 = 280 V` · `I2n = 295 A`** | **MESURÉE** | plaque (base physique du coffret) |
| Masse 1150 kg · roulements 6319 C3 · graisse K3N 45 g / 2000 h | **MESURÉE** | plaque |

### Dérivations arithmétiques de la plaque (**MESURÉE** — formule + donnée mesurée)

| Valeur | Calcul | Statut |
|---|---|---|
| Puissance apparente `S = 167,7 kVA` | √3 × 400 × 242 | **MESURÉE** (dérivée) |
| Contrôle de cohérence `P = 134,8 kW` (vs 132 plaque) | S × 0,86 × 0,935 ⇒ écart **2,1 %** ✅ | **MESURÉE** (dérivée) |
| **`Cnom = 854,6 Nm`** | 132 000 / (2π·1475/60) = 132 000 / 154,46 | **MESURÉE** (dérivée) |
| **`R2 ≈ 9,1 mΩ`/phase rotor** | `sn·E2/(√3·I2n)`, `sn = 1,67 %` (valide car `sX2 ≪ R2`) | **MESURÉE** (dérivée) |
| `ω = 154,46 rad/s` · `sn = 1,67 %` | — | **MESURÉE** (dérivée) |
| **X2 ≈ 91 mΩ** (pour `gmax_base` = 0,10) | `R2 / gmax_base` | **ESTIMÉE (HYPOTHÈSE ASSUMÉE)** (dépend de `gmax_base`) |
| **I2 au démarrage ≈ 500-700 A** (170-240 % I2n) | `E2/(√3·R_total)`, `R_total` = 0,23-0,32 Ω | **ESTIMÉE (HYPOTHÈSE ASSUMÉE)** (dépend du coffret) |

## A2. Benne — **données transmises** (2026-09-20)

| Valeur | Statut | Source |
|---|---|---|
| **Benne à vide (tare) = `7 t`** | **MESURÉE** | humain 2026-09-20 — *met fin aux 3 estimations divergentes (1-3 / 3,5 / 4,5-5 t)* |
| **Capacité ≈ `4 m³`** | **MESURÉE** | humain |
| Matière (densité 2,25 t/m³) ≈ **9 t** ⇒ **total ≈ 16 t** | **ESTIMÉE (HYPOTHÈSE ASSUMÉE)** | densité en place non mesurée |
| **Course ouvert ↔ fermé = `15 m` de câble M2** | **MESURÉE** | humain + `GVL_PERSISTENT.st:67` (`OffsetCloseM := 15.0`, REX 2026-07-27 « mesuré ») + **recoupé** : écart M2−M1 calculé = 0 → **15,03 m** (trace 48) |
| Convention ouverture : `0 % = fermée (Δ≈15 m)` · `100 % = ouverte (Δ≈0)` | **DOCUMENTÉE** | `FB_Bucket.st:583-590` |

## A3. Mécanique / transmission

| Valeur | Statut | Source |
|---|---|---|
| **`1 tour de tambour = 2,0 m` de câble** | **MESURÉE** | humain (photos + Ø tambour) |
| **Mouflage EXTERNE `1:1`** (aucun moufle suspendu) | **MESURÉE** | humain (vidéo/photos) — 2 câbles M1 + 2 câbles M2 droits |
| **Mouflage INTERNE `3:1` par câble** (2 moufles de 3 brins) | **MESURÉE** | humain (décomposition) + recoupement visuel externe |
| ⇒ `F_tambour(M2) = F_coquilles / 3` | **MESURÉE** (dérivée) | bouclage vérifié : 3T = F/2 par câble, ×2 = F |
| Ø tambour ≈ **0,637 m** | **MESURÉE** (dérivée de 2,0 m/tr) | — |

## A4. Réseau

| Valeur | Statut | Source |
|---|---|---|
| **Chute `400 V → 360 V` sous appel de charge** | **MESURÉE (1 point)** | terrain — ⇒ couple disponible **×0,81** |
| Puissance du groupe électrogène (kVA) | **INCONNUE** | — |

## A5. Mesures de traces (machine réelle, **2026-09-06**)

| Valeur | Statut | Réserve |
|---|---|---|
| `M2_TensionedCable_DI` = **TRUE 100 %** (dont 100 % des montées M1) ⇒ **charge partagée** | **MESURÉE** | aucun capteur sur M1 ⇒ partage **non quantifié** |
| Écart **intra-trace** entre voie position et voie vitesse : **×1,146** (médiane, 2 axes, 2 sens) | **MESURÉE** | **cause non tranchée** (cf. D) |
| Cadence inter-gradins **0,75-1,0 s** | **MESURÉE** | vs `FinalStepDelayElapsed` = 1 s 250 |
| P4 chargé **1,246-1,247 m/s** (CoE) · descente P4 vide **1,463-1,464** (max 1,630) | **MESURÉE** | ⚠️ **attribution palier non prouvée** (bits contacteurs, pas `StepNumber`) |
| Profondeur de travail **M1 −18,25 m** · remontée à **+8,0 m** (= capteur haut 8,5) | **MESURÉE** | — |
| Cycle réel ≈ **5-7 min** · **Kobold au fond 11,3 s/prise** | **MESURÉE** | trace 48 |
| `P5` (palier 5) jamais mesuré | **INCONNUE** | P5 non effectif avant le 2026-09-15 |

## A6. Écrit dans le code / la doc (**DOCUMENTÉE**)

| Valeur | Source | Réserve |
|---|---|---|
| Mapping palier → contacteurs : `P1=0000 · P2=1000 · P3=1100 · P4=1110 · P5=1111` | `GVL_PERSISTENT.st:16-22` | — |
| `PointsPerRev = 8192` (« 13 bits single-turn ») | `PRG_02_Acquisition.st:72` | ⚠️ **non vérifié** contre le codeur réel |
| `WinchMaxStepAscent = 5` · `WinchMaxStepDescent = 4` (RETAIN) | `GVL_PERSISTENT.st:140-141` | — |
| `SpeedGuardEnable := FALSE` (surveillance survitesse **gelée**) | `PRG_04_Treuils_Benne.st:1394,1462` | — |
| `_WinchSpeedConfig.SpeedBandMaxMps = [0,4 ; 0,8 ; 1,2 ; 1,6 ; 2,0]` | `GVL_PERSISTENT.st:27` | **provisoire, non validée en charge** |

---

# B. 🟡 VALEURS `ESTIMÉE (HYPOTHÈSE ASSUMÉE)` — **GELÉES COMME HYPOTHÈSES** (pour faire tourner le sim)

> 🔓 Ces valeurs **feront tourner le banc**. Elles sont **assumées**, **étiquetées**, et **remplaçables uniquement par une mesure** (T322). Aucune ne doit être présentée comme mesurée.

| Valeur | Valeur retenue | Pourquoi cette hypothèse | Ce qui la remplacera |
|---|---|---|---|
| **`Cmax/Cnom`** | **2,4 - 2,6** ⇒ `Cmax ≈ 2051-2222 Nm` | typique rotor bobiné levage | fiche VEM / essai de calage |
| **`i` (réduction)** | **≈ 32,5** (fourchette **31-34**) | déduit par conception (benne pleine à vitesse max ≈ point nominal) + borne dure `i ≤ 33,6` | **comptage tours moteur / tour tambour** |
| **`J` (inertie ramenée)** | **4 - 7 kg·m²** | masse moteur 1150 kg, carcasse de cette taille | fiche moteur + volant de frein |
| **`η_méca`** | **0,85** | non sourcé (réducteur inconnu) | plaque réducteur / mesure |
| **Densité du matériau** | **2,25 t/m³** ⇒ matière **9 t** | alluvions/gravier en place | pesée / analyse |
| **Partage de charge M1/M2** | **≈ 50/50** | imposé par la puissance (106 % de Cnom/câble à 16 t) | tension de câble / essai M1 seul porteur |
| **Poids **immergé** (flottabilité)** | **non modélisé** (on travaille en air) | simplification | essai / calcul de flottabilité |
| **Égouttage en remontée** | **30-50 %** de la charge | contre-expertise + cohérent avec les traces | pesée en fin de remontée |
| **Sur-effort d'arrachage `k`** | **1,6 - 3,1** selon palier et partage | succion de fond (ordre de grandeur) | essai instrumenté au fond |
| **`gmax_base`** | **0,08 - 0,12** | plage usuelle ; **appréciation issue d'un rapport de recherche rejeté** | `R2/X2` mesuré |
| **`θ_max` (ouverture)** | **90° ou 180°** | observation visuelle | fiche/plan de la benne |
| **Vitesse max réelle** | **1,40-1,49 m/s** (voie position) | cohérence plaque + charge + `i` | mesure après correction de la voie codeur |
| **Température / vieillissement** | **non modélisés** | hors périmètre pré-calage | — |

---

# C. ⚙️ VALEURS `SYNTHÉTIQUE` DU CODE — **à remplacer** (périmètre **T321**)

| Constante (nom exact) | Fichier | Valeur actuelle | Écart vs réel | Valeur cible (hypothèse) |
|---|---|---|---|---|
| `RotorResistanceOwn_Ohm` | `FB_Sim_WinchMotor.st` | **0,08 Ω** | ❌ **×8,8 trop grand** (réel 9,1 mΩ) | **0,0091 Ω** |
| `CST_RotorExtResistanceStep_Ohm` | idem | **[3,6 ; 1,9 ; 0,9 ; 0,35 ; 0]** Ω | ❌ **hors d'échelle ×10-100** (I2 = 45 A vs 295 A) | **≈ [0,31 ; 0,20 ; 0,12 ; 0,06 ; 0]** Ω *(borné, à confirmer)* |
| `MaxTorque_Nm` (Cmax) | idem | **3800 Nm** | ❌ **+78 %** | **≈ 2100 Nm** |
| `Inertia_KgM2` | idem | **45 kg·m²** | ❌ **×7-10** | **≈ 5 kg·m²** |
| `SlipAtMaxTorqueBase_Ratio` | idem | 0,08 | ✅ plausible | 0,08-0,12 |
| `LoadNominalTorque_Nm` (matière) | `FB_Sim_WinchElectrical.st` | 2500 Nm | ❌ sans rapport | **≈ 509 Nm/câble** |
| `LoadFrictionTorque_Nm` → **terme tare** | idem | 80 Nm | ❌ sans rapport | **≈ 396 Nm/câble** (tare **7 t**) |
| `MinSpeedMps` / `MaxSpeedMps` | `FB_Sim_Encoder.st` | 1,0 / **2,0** m/s | ❌ **2,0 m/s impossible** (plafond physique ≈ 1,54) | **≈ 0,3 / 1,45** |
| `CoupledPeerGain_Ratio` · `LoadTransitionFilter_S` | `FB_Sim_WinchElectrical.st` | 0,5 · 0,5 s | non ancré | à valider |
| `CST_StallSpeedThreshold_Rpm` | `FB_Sim_WinchMotor.st` | 28 tr/min | convention | à revoir avec la condition de décrochage |
| `SynchronousSpeed_Rpm` · `CycleTime_S` | idem | 1500 · 0,01 | ✅ **justes** | — |

---

# D. 🔴 INCONNUES — **bloquantes** (périmètre **T322**)

| # | Inconnue | État de la contrainte connue |
|---|---|---|
| 1 | **Échelle de la voie vitesse** (`0x6031` : numérateur/dénominateur) **ou** `PointsPerRev` réel vs résolution du codeur | divise les mesures de 12,7 % — **action n°1, faisable dans l'IDE** |
| 2 | **`i` mesuré** | hypothèse 32,5 · borne dure **≤ 33,6** |
| 3 | **Coffret rotorique** : nombre réel de gradins + Ω | **borné** : `Rext(P1) ≈ 0,22-0,31 Ω` (via `I2_démarrage ≈ 2-2,5 × I2n`) |
| 4 | **`Cmax/Cnom` réel** | hypothèse 2,4-2,6 |
| 5 | **`J` réel** | hypothèse 4-7 kg·m² |
| 6 | **Groupe électrogène (kVA)** | — |
| 7 | **Charge réelle en service** (immergée, après égouttage) | tare **7 t MESURÉE** ; total ≤ 16 t en air |
| 8 | **`P5` (palier 5)** : vitesse et tenue réelles | jamais mesuré (P5 effectif depuis le 2026-09-15) |
| 9 | **Pente charge ↔ vitesse** | exige des essais **avec la charge NOTÉE** (protocole T322) |
| 10 | **Raideur / constante de temps du COUPLAGE mécanique M1/M2** + **cas de blocage des mâchoires** | 🆕 **non modélisés avant T328** (seule liaison existante : descente couplée `SimM2CoupledDescentModelActive`) ⇒ plan `PLAN_T328_SIMBENCH_COUPLAGE_MECANIQUE_M1M2.md` · constante de rattrapage `CST_SimWinchCouplingTauS = 1,0 s` en `ESTIMÉE (HYPOTHÈSE ASSUMÉE)`, **à mesurer en T322** · plage plausible selon le challenger physique : **0,2 à 2 s** — **aucune trace disponible ne permet de la borner** |

---

# E. 🔒 RÈGLES DE GEL

1. **Le statut se lit ici**, jamais dans un autre document. Les autres docs **renvoient** à ce registre.
2. **Toute bascule de statut est journalisée** (§F) avec : valeur, ancien → nouveau statut, **preuve** (fichier/date/méthode), acteur (`DSH01`/`CC01`/`CDX01`/`HUM`…), date.
3. Une **`ESTIMÉE`** ne peut devenir **`MESURÉE`** que par une **preuve physique** nommée. Une dérivation arithmétique d'une donnée mesurée est recevable (**MESURÉE (dérivée)**), à condition que la formule soit écrite.
4. Une **`SYNTHÉTIQUE`** ne peut devenir **`ESTIMÉE`** que par **décision humaine tracée** (elle ne devient jamais `MESURÉE` sans mesure).
5. **Aucune valeur `INCONNUE` ne peut être utilisée en argument de sécurité** ni servir à qualifier la machine.
6. **Le banc ne remplace jamais la mesure** : les valeurs de §B/C font tourner le simulateur, elles ne qualifient pas la machine réelle.
7. Toute **contradiction** entre documents est tranchée **en faveur de ce registre**, et l'autre document est corrigé.

---

# F. 📓 JOURNAL DES BASCULES (à compléter, jamais réécrit)

| Date | Valeur | Ancien → Nouveau | Preuve | Acteur |
|---|---|---|---|---|
| 2026-09-20 | Puissance moteur | `ESTIMÉE` (111 kW, d'après « ~200 A » oral) → **`MESURÉE` (132 kW)** | plaque moteur transmise | DSH01 / HUM |
| 2026-09-20 | `In` stator | `ESTIMÉE` (~200 A) → **`MESURÉE` (242 A)** | plaque | DSH01 / HUM |
| 2026-09-20 | **Tare benne** | `INCONNUE` (3 estimations : 1-3 / 3,5 / 4,5-5 t) → **`MESURÉE` (7 t)** | humain | DSH01 / HUM |
| 2026-09-20 | `E2`, `I2n`, `cosφ`, `η`, service | `INCONNUE` → **`MESURÉE`** | plaque | DSH01 / HUM |
| 2026-09-20 | `Cnom` | `ESTIMÉE` (719 Nm) → **`MESURÉE (dérivée)` (854,6 Nm)** | 132 kW / 1475 tr/min | DSH01 |
| 2026-09-20 | `R2` rotor | `SYNTHÉTIQUE` (0,08 Ω) → **`MESURÉE (dérivée)` (9,1 mΩ)** | `sn·E2/(√3·I2n)` | DSH01 |
| 2026-09-20 | Mouflage externe | présumé → **`MESURÉE` (1:1)** | photos/vidéo + humain | DSH01 / HUM |
| 2026-09-20 | Mouflage interne | présumé → **`MESURÉE` (3:1 par câble)** | décomposition humain + recoupement visuel | DSH01 / HUM |
| 2026-09-20 | Course benne 15 m | `DOCUMENTÉE` (code) → **`MESURÉE`** (+ recoupement trace 0→15,03 m) | code + trace 48 + humain | DSH01 |
| 2026-09-20 | Charge totale | `ESTIMÉE` (« 10 t » arbitré) → **`CADUC`** (7 t tare + ~9 t matière) | plaque benne + humain | DSH01 / HUM |
| 2026-09-20 | Voie de vitesse de référence | indécise → **`ESTIMÉE (HYPOTHÈSE ASSUMÉE)` : voie POSITION** (i ≈ 31-34 par conception) | argument de conception + borne `i ≤ 33,6` | DSH01 |

---

## 🔗 Où sont les dérivations et commentaires

| Document | Rôle |
|---|---|
| `DOC/WFLOW/CONTRACTS/REFERENCE_CALAGE_TREUIL_M1M2_v0.1.md` | **dérivations** (Kloss, fenêtres, partage, impacts) · §0 = plaque · §6 = preuve de la voie de vitesse fautive |
| `DOC/WFLOW/PROMPTS/05_brief_recherche_moteur_treuil_benne.md` | recherche externe — ⚠️ **items P2/P3/P5 largement résolus par la plaque** : à mettre à jour |
| `DOC/WFLOW/CONTRACTS/PROCEDURE_TRACE_TREUIL_CHARGE_v0.1.md` | protocole qui **convertit les hypothèses en mesures** |
| `DOC/WFLOW/PROMPTS/06_bilan_challenge_calage_treuil.md` | bilan + auto-challenge |
| `DOC/WFLOW/TASKS.yaml` — **T320 / T321 / T322** | respectivement : miroir apprentissage · appliquer les hypothèses + câbler la charge · **recalage terrain** |
