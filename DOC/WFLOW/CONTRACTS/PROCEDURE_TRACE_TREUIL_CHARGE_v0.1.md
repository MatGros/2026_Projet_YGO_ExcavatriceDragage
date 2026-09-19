# PROCEDURE_TRACE_TREUIL_CHARGE_v0.1 — Enregistrer la vitesse réelle par palier et par charge

**Statut** : 🟡 proposition — **à valider par l'humain** avant enregistrement sur machine.
**Date** : 2026-09-20 · **Périmètre** : treuils M1/M2 (`FB_Winch`, paliers 1..5) · **Hors périmètre** : M3 / cycle semi-auto.
**Liste de variables** : `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/trace_treuils_charge_v1.txt` (**108 variables** = 52 éprouvées + 56 ajouts).
⚠️ La config de trace d'origine contenait un **doublon** (`M2_SpeedContactor_1_DQ` présent 2×) : supprimé ici.

---

## 1. But — 4 résultats attendus
| # | Résultat | Pourquoi c'est bloquant |
|---|---|---|
| **R1** | **Vitesse réelle du palier 5** (jamais mesurée : P5 n'était pas effectif lors des traces du 06/09) | `MaxSpeedMps = 2,0` et `SpeedBandMaxMps[5] = 2,0` sont des **extrapolations non validées** |
| **R2** | **Pente charge ↔ vitesse** (même palier, benne vide **vs** benne pleine) | Le modèle suppose **une vitesse par palier** — mesuré faux : **P1 → 0,29 m/s ET 0,75 m/s** (facteur 2,6) |
| **R3** | **Cohérence position ↔ vitesse** — écart **confirmé sur 3 traces / 2 sessions** : la position lit **+13 à +15 %** au-dessus de la vitesse codeur CoE (−12,6 % intra-trace sur la trace 46) | Une des deux voies a une **erreur d'échelle** ⇒ fausse le rapport de réduction **et** la borne de masse de 15 % |
| **R4** | **Cadence inter-gradins** (mesuré **0,75-1,0 s** contre **1 s 250** configuré) | Conditionne la logique de séquencement des gradins |

---

## 2. ⚠️ Limite des traces existantes (à assumer)

Sur les traces du 06/09, **l'état de charge n'a pas été noté** (pleine ? à moitié ?). Conséquences :

- ✅ **Les bornes de masse restent valides** : `m ≤ P·η/(g·v)` est une **borne supérieure** ⇒ elle tient **quelle que soit la charge inconnue** (donc « ≤ 7,4 t à 1,287 m/s » reste vrai).
- ❌ **La pente charge ↔ vitesse est inexploitable** : on ne peut pas attribuer une vitesse à une charge connue.
- ❌ Le **facteur 2,6 au palier 1** (0,29 vs 0,75) reste **inexpliqué** : deux hypothèses (charge, ou traînée/succion de la benne ouverte au fond) — non départageables sans notation.

⇒ **La notation de la charge est le point critique de cette procédure.** Sans elle, la session ne sert à rien.

---

## 3. Ce que la nouvelle liste de variables ajoute

Base **éprouvée** = les **53 lignes** des traces existantes (**52 uniques** — un doublon `M2_SpeedContactor_1_DQ` a été retiré). Ajouts :

| Bloc | Ajout | Ce que ça résout |
|---|---|---|
| **Palier explicite** | `M1/M2Treuil…State.StepNumber`, `FinalAuthorizedStep`, `SpeedCmd_Pct`, `CommandedAscent/Descend` | Fin de la **déduction du palier par les contacteurs** (source d'erreur) |
| **Plafonds actifs** | `GVL_PERSISTENT._CommunCfgPersist.WinchMaxStepAscent / Descent` | Explique **pourquoi** P5 est ou non autorisé (valeur **RETAIN** ≠ défaut code) |
| **Charge** | `EstimatedLoadPct`, `LoadEstimateConfigured`, `SpeedStable` (M1+M2) | Proxy de charge + dit si l'estimation est **validée** |
| **2ᵉ voie mesure** | `SpeedDelta_Mps`, `Measurement.CablePosM` (M1+M2) | Résout **R3** (position vs vitesse) |
| **Blocage** | `AxisBlockReason`, `Data.TraceM1/M2.BlockReason`, `FinalInterlockReason`, `FinalMotorRequest` | Distingue **défaut** / **refus de permis** / **palier non autorisé** |
| **Timers** | `FinalStepDelayElapsed`, `FinalBrakeTimeoutElapsed`, `FinalRestartDelayElapsed` | Chronologie exacte du refus + **R4** |
| **Zones** | `InTopSlowdownZone`, `SpeedGuardLimited` | Détecte un **plafonnement de palier** (bordure de course) faussant la mesure |
| **Sim (même trace)** | `instSimBench.MotorTorqueM1_Nm`, `MotorIsStalledM1`, `instWinchElectricalM1.Slip_Ratio`, `ResistiveTorqueAct_Nm`, **`instWinchElectricalM1.SpeedAct_Rpm`**, **`instWinchElectricalM1.IsStalled`** + gates `GVL_Simulation.*` | **Comparaison sim ↔ réel dans la même trace** (base du miroir T320). ⚠️ `IsStalled` est **latché** (jamais réarmé) ; l'état instantané (`Motor.Stalled`) est une **variable locale privée** → **non traversable** (encapsulation) : l'exposer exigerait une **nouvelle sortie publique** |

---

## 4. Protocole d'enregistrement

### 4.1 Prérequis (à vérifier avant de lancer)

1. **Logiciel à jour** (palier 5 effectif) et `WinchMaxStepAscent = 5` **réellement actif** (valeur **RETAIN**, ≠ défaut de type).
2. ⚠️ **Vérifier que CHAQUE ligne de la liste résout** dans la boîte de dialogue Trace de CODESYS (**2 min**). Motif : les sorties relais ont été **renommées `_DQ` → `_RQ` le 2026-09-18** (commit `3e765aa5`), or la liste a été dérivée des traces du **06/09**, donc **d'avant le renommage**. Les entrées courtes sans domaine (`COD1_PosValue`, `M1_BrakeIsOpen_DI`…) viennent elles aussi de la config d'origine : leur **chemin complet** peut être exigé.
3. `GVL_Simulation.SimulationModeActive = **FALSE**` → on mesure la **machine**, pas le banc.
4. Aucun défaut armé. ⛔ `SpeedGuardEnable` **n'est pas traçable utilement** : il est **forcé à `FALSE`** en `PRG_04_Treuils_Benne.st:1394/1462` (surveillance survitesse **gelée**) → aucune influence sur la vitesse mesurée.
5. Trace : **période 100 ms**, durée **≥ 180 s**, déclenchement **manuel**, **108 variables** (liste fournie, sans doublon).
6. **Noter** : date, opérateur, matériau, profondeur, et **toute anomalie** (bruit, à-coup, odeur, alarme).

### 4.2 🎯 Test d'étalonnage des 2 voies de vitesse (**2 min, à faire AVANT tout le reste**)

**✅ Preuve PRIMAIRE — comparaison INTRA-trace (même instant, même fenêtre, 2 treuils)**
Trace 46, t = 65,0 → 70,5 s : `Δposition` = **7,785 m** vs `∫vitesse CoE dt` = **6,800 m** ⇒ **la position lit +12,6 %** (M2 : +12,7 % ; idem en descente). C'est **la** preuve : aucune hypothèse de comparaison.

**🟡 Corroboration inter-sessions (indicative, PAS une preuve)**
Dérivée de la position (trace 48, 13,6 min) = **1,486 / −1,841 m/s** vs vitesse CoE (trace 46) = **1,287 / −1,630 m/s** → **×1,155 / ×1,129**.
⚠️ Deux **sessions distinctes** ⇒ l'écart suppose des points de fonctionnement comparables.

**Conséquence** : une des deux voies a une **erreur d'échelle de ~13 %** ; ça déplace la **borne de masse** de 13 % (**≈ 6,7 t à 360 V / 7,4 t à 400 V, PAR CÂBLE**).

**Protocole du test (moteur à l'arrêt, benne suspendue libre, **hors eau**, sans charge) :**

1. Tracer (`CablePosM` M1+M2, `Measurement.SignedSpeed_Mps` M1+M2, `COD1_PosValue`, `COD1_SpdValue`, période 100 ms).
2. **Marquer le câble** (repère peint/adhésif) à hauteur d'un point fixe de la machine.
3. Commander un mouvement **lent et continu** (palier 1) sur une distance **mesurée au mètre ruban ≥ 2 m**.
4. **Comparer** : `Δposition IHM` **vs** distance ruban **vs** `∫vitesse CoE dt`.
5. Noter les 3 valeurs dans la grille §4.4 (ligne « ÉTAL »).

⇒ La voie qui colle au mètre ruban est la bonne ; l'autre se corrige par **une constante** (et on saura laquelle des deux hypothèses est fausse : développement tambour **2,0 m/tr** ou conversion codeur **0,1 tr/min**).

### 4.3 Séquence — 11 plateaux (≈ 20 min machine)

Pour chaque plateau : **le tenir ≥ 5 s à vitesse stable**, **hors zone de ralentissement** (`InTopSlowdownZone = FALSE`) et **hors décollage du fond**.

| Passe | Sens | Palier | État benne | Remarque |
|---|---|---|---|---|
| 1 | Montée | P1 | **VIDE fermée** | benne fermée, **hors d'eau / sans traînée au fond** |
| 2 | Montée | P2 | VIDE fermée | ⚠️ la machine ne tient P2/P3 que ~0,8 s → **forcer la tenue** (joystick bloqué au seuil du palier) |
| 3 | Montée | P3 | VIDE fermée | idem |
| 4 | Montée | P4 | VIDE fermée | |
| 5 | Montée | **P5** | VIDE fermée | 🎯 **mesure clé (R1)** |
| 6-10 | Montée | P1 → P5 | **PLEINE** | après une **vraie prise de matériau**, puis **dégager du fond** avant de mesurer |
| 11 | Descente | P4 | PLEINE | ⚠️ **P4 = plafond réel en descente** (`WinchMaxStepDescent = 4` en **RETAIN**, `GVL_PERSISTENT.st:140`) |
| **12** | **Montée** | P1 puis P4 | **VIDE ouverte** | 🎯 **OUVERTURE EN L'AIR, M1 seul porteur** (structure : M2 déroule pendant que M1 lève) ⇒ **borne de masse de la TARE sans ambiguïté de partage** + observation de la relation **v_câble M2 = 6 × v_ouverture** |
| ~~13~~ | ~~Descente~~ | ~~P5~~ | ~~PLEINE~~ | ⛔ **SUPPRIMÉ** : exigerait `WinchMaxStepDescent ≥ 5` ⇒ **modification de configuration non autorisée pour une mesure** |

🔁 **Idéal** : 2 répétitions par ligne (dispersion). L'analyse accepte une session partielle — **mieux vaut 6 plateaux bien notés que 12 approximatifs**.

⛔ **Tenue forcée de P2/P3** (~0,8 s) : **autorisée benne VIDE et hors eau uniquement** — **proscrite benne chargée ou benne au fond** (commande maintenue en zone limite + effort d'arrachement).

### 4.4 Grille de notation (à remplir pendant la session)

| # | t début | Sens | Palier (IHM) | État benne | Matériau | Profondeur (m) | Vitesse lue IHM | Stabilité (s) | Anomalie |
|---|---|---|---|---|---|---|---|---|---|
| 1 | | | | | | | | | |

---

## 5. Traitement des données (mon rôle, après réception)

1. Parsing du `.trace` (**UTF-16** + tables `ToUnicode` si export PDF) → table par échantillon.
2. Extraction des **plateaux** : `StepNumber` stable **et** sens stable **et** `SpeedStable` **et** hors zones de ralentissement.
3. Sortie : **table `palier × sens × charge → vitesse médiane`** (m/s et m/min) + min/max + durée.
4. **R2** : régression `vitesse = f(charge)` par palier → la pente qui manque au modèle.
5. **R3** : contrôle position vs intégrale de vitesse sur chaque plateau (fenêtre intérieure) → identification de la voie fausse.
6. **R1** : vitesse P5 → **borne resserrée** du rapport de réduction (`i = 2,0 × n / (60 × v)`, `n ≤ 1500` en montée).
7. **R4** : horodatage des transitions de palier → cadence réelle vs `FinalStepDelayElapsed`.
8. Restitution dans `DOC/WFLOW/CONTRACTS/REFERENCE_CALAGE_TREUIL_M1M2_v0.1.md` (**statut `MESURÉE`**) + recalage des constantes du sim.

---

## 6. Ce que cette session ne pourra PAS donner

| Manque | Raison | Contournement |
|---|---|---|
| **Courant stator** (le meilleur proxy de charge) | ❌ **aucun capteur** : vérifié, les seules entrées analogiques sont les 2 axes joystick (`JoyXRaw_ANA1`, `JoyYRaw_ANA2`) ; côté treuils il n'y a que des **contacts thermiques** on/off | Notation manuelle (§4.3) · `EstimatedLoadPct` (**empirique**, non certifié) · **option matérielle** : 1 TC + 1 entrée analogique sur l'alimentation moteur (décision humaine) |
| Poids réel de la benne pleine | Aucune pesée embarquée | La **borne supérieure** `m ≤ P·η/(g·v)` — **valable PAR CÂBLE** — reste exploitable sans pesée |
| Charge exacte à chaque instant | Pas de mesure directe | Le **bucket opening %** + la notation donnent la classe (vide/pleine/transit) |

---

## 7. Sécurité — rappels avant d'enregistrer

- 🛑 **Respecter les limites logicielles** : limite légale `-30 m`, limite câble montée **7,5 m**, capteur haut physique **8,5 m**, ralentissements de bordure (haut **0,5 m** / bas **1,0 m**, palier plafonné à 1).
- 🛑 **Ne jamais forcer un palier dans une zone de ralentissement** : la mesure serait faussée **et** le matériel sollicité hors specs.
- 🛑 **P5 est nouveau** (validé machine en M2 le **2026-09-15**) : première exploitation **en montée à vide**, chargé seulement après constat du comportement.
- 🛑 Le **décollage du fond** (arrachage) est un **transitoire** : il ne fait pas partie des plateaux — s'il arrive, le tracer **à part** et le **noter**.
- 🚫 Aucune donnée `Device.export` du dépôt n'est une référence : seule la source versionnée compte.

---

## 8. État des mesures déjà acquises (base de comparaison)

| Palier | Benne | Vitesse mesurée | Source |
|---|---|---|---|
| P1 | PLEINE | **0,734 / 0,752 m/s** (44-45 m/min) | 2 cycles 06/09 · ⚠️ **attribution palier NON PROUVÉE** : plateau mesuré en fenêtre **contacteurs = 0000** ⇒ « P1 » **ou** phase non commandée. À revérifier avec **les bits relais** (`_RQ`) |
| P1 | ouverte ~87 % | ~~0,29-0,30 m/s~~ | ⚠️ **NON VÉRIFIÉ** (contrôle indépendant) : seules des phases **courtes (1-1,6 s)** existent, **aucun plateau soutenu** |
| P4 | PLEINE | **1,246 / 1,247 m/s** (74,8 m/min) | idem (plateaux 7,1 s et 13,7 s) |
| P4 | descente, vide | **1,463-1,464** · max **1,630 m/s** (97,8 m/min) | idem |
| **P5** | — | ⛔ **jamais mesuré** | — |
| *(dérivée position, trace 48)* | montée / descente | **1,486** / **−1,841 m/s** (89 / −110 m/min) | 13,6 min, 8188 éch. |

**Cycle réel complet (trace 48, 13,6 min — 2 appuis fond)** : profondeur atteinte **M1 −18,25 m / M2 −16,41 m** · remontée à M1 **+8,0 m** (= capteur haut 8,5 m ✅) · benne ouverte 95 % à la descente → **0 % après la prise** → 95 % au déversement · **Kobold au fond 11,3 s par prise** · **~5-7 min par cycle**.
*Note : `|posM1 − posM2|` ≈ 10 m en permanence — **normal** (géométries/zeros différents) ; le vrai indicateur de synchro est `M1M2Sync.State.DeltaPos_M` (≤ 0,15 m, trace 46), **non tracé** dans la trace 48.*

Autres acquis : inter-gradins **0,75-1,0 s** · `SyncDelta` M1/M2 **≤ 0,15 m** · **aucun défaut** dans les cycles tracés · borne de masse **≈ 7,4 t PAR CÂBLE** à 400 V (≈ 6,7 t à 360 V) ⇒ **≈ 14,8 t au total SI la charge est partagée entre les 2 câbles** (partage **non vérifié**).

⚠️ **Rapport de réduction : NON fixé.** Les 2 voies de vitesse impliquent **i ≈ 34-39** (1,287 m/s ⇒ i ≤ 38,8 ; 1,486 m/s ⇒ i ≤ **33,7**) ⇒ **i doit être MESURÉ** (tours moteur par tour tambour, + compter les brins), **pas déduit d'une trace ambivalente**. Seule certitude : **i = 48 est exclu dans les deux lectures**. ⇒ Toutes les valeurs de couple du `REFERENCE_CALAGE` construites avec **i = 48** sont **à recalculer** (à i = 37 : **471-540 Nm/câble** pour 10 t, et non 765 Nm).
