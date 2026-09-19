# 06 — BILAN & CHALLENGE · Calage du modèle électrique des treuils (SimBench T317 / T318)

> 🎯 **Document de PASSATION** : à donner tel quel à un agent (autre modèle, autre outil) chargé de **CHALLENGER** l'analyse.
> ⛔ **Mission du challenger** : read-only, **aucune modification, aucun commit**. Verdict **par affirmation**, avec **preuve `fichier:ligne`**. Ne rien valider par confort.
> ✅ Le dépôt est accessible (`C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage`) → les chemins cités sont réels et vérifiables.
> 📄 Lire d'abord : `AGENTS.md`, `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`.
> 🗣️ Restitution **en français**, courte, dense, tableaux > prose. Ce qui n'est pas vérifiable ⇒ `NON VÉRIFIABLE` (jamais deviné).
> 🧭 **La section §3 est le cœur du document : c'est ma propre liste de faiblesses.** Le challenger doit commencer par là.

---

## 1. Objet

Excavatrice de dragage (carrière noyée), automatisme **CODESYS 3.5**. **2 treuils** :
- **M1 = treuil de RETENUE** (2 câbles, prise directe **1:1**)
- **M2 = treuil de BENNE / FERMETURE** (2 câbles, **mouflages internes 3 brins par câble → 3:1 par câble**)

Moteurs **asynchrones à ROTOR BOBINÉ**, démarrage par **cascade de résistances rotoriques** (5 paliers). Le simulateur `FB_SimBench` publie une image simulée (`HwSim`) — **diagnostic seul, inopérant sur machine réelle** (`SimulationModeActive = FALSE`).

**But du travail** : rendre le modèle électrique **théoriquement crédible** aujourd'hui, **remplissable par des mesures** plus tard. Ce n'est **pas** une validation machine.

---

## 2. Ce qui est ÉTABLI (à challenger ligne par ligne)

| # | Affirmation | Statut | Preuve / réserve |
|---|---|---|---|
| 1 | Le modèle électrique est **diagnostic seul**, aucun consommateur métier | ✅ DOCUMENTÉE | `FB_SimBench.st:133-138` · sorties `[DIAG]` |
| 2 | **La CHARGE n'est pas câblée** ⇒ `C_résistant = 80 Nm` ⇒ **aucun décrochage par charge n'est exécutable** | ✅ DOCUMENTÉE | `SimWinchLoadFrac_Ratio` absent de `GVL_Simulation` **et** non passé dans `PRG_02_Acquisition.st:262-355` |
| 3 | Décrochage testé **seulement à s=1 et sous 28 tr/min**, sinon **forcé FALSE** | ✅ DOCUMENTÉE | `FB_Sim_WinchMotor.st:151-164` |
| 4 | `IsStalled` = **latch jamais réarmé** ; l'état instantané `Motor.Stalled` est **privé** | ✅ DOCUMENTÉE | `FB_Sim_WinchMotor.st:159-161` / `:58` |
| 5 | **Aucune saturation basse** de vitesse ⇒ emballement silencieux possible | ✅ DOCUMENTÉE | `FB_Sim_WinchMotor.st:140-143` |
| 6 | **Aucun courant** calculé ; `VoltageRatio2` figé à 1,0 (400 V en dur) | ✅ DOCUMENTÉE | `FB_SimBench.st:294,317` |
| 7 | **Résistances = constantes**, aucune thermique R(T), aucun I²t | ✅ DOCUMENTÉE | `FB_Sim_WinchMotor.st:67-71` |
| 8 | **Aucun terme transitoire** de commutation de gradin | ✅ DOCUMENTÉE | `FB_Sim_WinchMotor.st:131-137` + `PLAN_T317 §corrections-1` |
| 9 | Mapping **palier → contacteurs** : P1=0000 · P2=1000 · P3=1100 · P4=1110 · P5=1111 | ✅ DOCUMENTÉE | `GVL_PERSISTENT.st:16-22` |
| 10 | **Vitesses réelles mesurées** (traces 2026-09-06) : P4 chargé = **1,246-1,247 m/s** (plateaux 7,1 s et 13,7 s) · descente P4 vide = **1,463-1,464** (max 1,630) · **P5 jamais mesuré** (inexistant avant le 15/09) | ✅ MESURÉE | traces 40 / 44 / 46 — ⚠️ **attribution palier non prouvée** (bits contacteurs, pas `StepNumber`) |
| 11 | Deux voies de vitesse qui **divergent de 12,7 %** : écart **intra-trace** (trace 46, t=65,0→70,5 s) `Δposition` 7,785 m vs `∫v_CoE` 6,800 m — **identique M1/M2 et montée/descente** | ✅ MESURÉE | trace 46 · **cause NON TRANCHÉE** (cf. §3.2) |
| 12 | `CablePosM` et `V_CoE` **partagent la constante 2,0 m/tr** ⇒ elle **s'annule** dans leur rapport ⇒ l'écart est **dans l'échelle CoE `0x6031` ou `PointsPerRev`** | ✅ DOCUMENTÉE | `FB_Encoder_Scale.st:38` + `FB_Encoder_SpeedMeasure.st:49` |
| 13 | **1 tour de tambour = 2,0 m** et **mouflage EXTERNE 1:1, aucun moufle suspendu** | ✅ CONFIRMÉE par l'humain (photos + Ø tambour) | — |
| 14 | **Mouflage INTERNE : 2 moufles indépendants de 3 brins** (3 brins/câble) ⇒ `F_tambour(M2) = F_coquilles/3` | ✅ CONFIRMÉE par l'humain (décomposition explicite) | bouclage vérifié : moufle d'un câble = 3T = F/2, ×2 = F |
| 15 | **Course benne ouvert↔fermé = 15 m de câble sur M2** | ✅ MESURÉE | `GVL_PERSISTENT.st:67` → `OffsetCloseM := 15.0` (REX **2026-07-27**, « mesuré ») **+ recoupé** : écart M2−M1 calculé = **0 → 15,03 m** sur 8188 éch. de la trace 48 |
| 16 | Le **% d'ouverture du code** est linéaire en **écart M2−M1** : `100×(15−Δ)/15` | ✅ DOCUMENTÉE | `FB_Bucket.st:583-590` |
| 17 | **La charge est PARTAGÉE entre M1 et M2** (pas de « M1 seul porteur » en montée) | ✅ MESURÉE | `M2_TensionedCable_DI` = **TRUE sur 100 %** de la trace 46, dont **100 %** des phases de montée M1 |
| 18 | **Puissance/Cnom** : `√3·400·200 = 138,6 kVA` × cosφ 0,86 × η 0,935 ⇒ **≈ 111 kW** ⇒ **Cnom ≈ 719 Nm** (1475 tr/min) | 🟠 ESTIMÉE (In = oral, cosφ/η = hypothèses) | — |
| 19 | `Cmax/Cnom ≈ 2,2-2,6` pour un rotor bobiné de levage ⇒ **Cmax ≈ 1700-1800 Nm** (le sim a **3800**) | 🟠 ESTIMÉE (sources web **non primaires**) | recoupé par 2 recherches indépendantes |
| 20 | `J` moteur ≈ 3,5-4,5 kg·m² (le sim a **45**) — **mais J est le recalage le MOINS critique** en statique | 🟠 ESTIMÉE | idem |
| 21 | `i` : **`i = 48` est EXCLU** (exigerait 1858-2140 tr/min > synchronisme en montée) | ✅ démonstration physique | `n ≤ 1500` en montée |
| 22 | **Faux sentiment de sécurité chiffré** : au palier 5 benne pleine, le sim ne décrocherait qu'à **1193 tr/min** alors que le réel décroche **sous 678-777 tr/min** | 🟠 ESTIMÉE (dépend de `i` et de la charge) | §§8.2/8.3 de `REFERENCE_CALAGE` |

---

## 3. 🚨 AUTO-CHALLENGE — **mes propres faiblesses** (attaquer ici en priorité)

| # | Faiblesse | Gravité | Ce qu'il faut faire pour la lever |
|---|---|---|---|
| **1** | 🔴 **Raisonnement CIRCULAIRE** : j'ai utilisé la mémoire utilisateur « 75 m/min » pour valider la voie **CoE** — or cette mémoire vient de la **vitesse affichée à l'IHM**, donc **de la voie CoE elle-même**. Ce n'est **pas** une ancre indépendante. *(Erreur commise puis corrigée, mais c'est le type de piège à traquer.)* | 🔴 | Ne retenir que des ancres **indépendantes** : géométrie tambour, profondeur physique, comptage de tours |
| **2** | 🔴 **DEUX MONDES NON DÉPARTAGÉS** : la voie juste est soit la **position** (⇒ `i ≈ 32-33`) soit la **CoE** (⇒ `i ≈ 38,5-39`). Mon dernier argument (« la géométrie ancre la position ») repose sur **`PointsPerRev = 8192` NON VÉRIFIÉ** contre le codeur réel + un jugement **qualitatif** sur la profondeur | 🔴 | Lire la **config EtherCAT du `0x6031`** + la **résolution réelle du codeur** ; sinon **1 tour de tambour** |
| **3** | 🔴 **Attributions de palier non prouvées** : mes vitesses « par palier » sont déduites des **bits contacteurs** ; plusieurs plateaux sont mesurés en fenêtre **contacteurs = 0000** ⇒ « P1 » **ou** phase non commandée (moteur non alimenté). Aucune trace ne contient `StepNumber` | 🔴 | Refiltrer **avec les bits relais `_RQ`** + une trace future avec `StepNumber` |
| **4** | 🔴 **La charge n'a JAMAIS été notée** lors des enregistrements. Les **bornes** de masse restent valides (borne supérieure), mais **toute pente charge ↔ vitesse est inexploitable**. Et « 10 t = SWL total » est un **arbitrage humain**, pas une mesure | 🔴 | Protocole §4.4 de `PROCEDURE_TRACE_TREUIL_CHARGE_v0.1.md` (notation obligatoire) |
| **5** | 🟠 **Le partage de charge est mesuré « tendu », pas QUANTIFIÉ** : le 50/50 est une hypothèse. Mes seuils d'arrachage `k` en dépendent (je les avais d'abord donnés comme une fourchette unique = **trop grossier**) | 🟠 | Mesurer/estimer la répartition (tension de câble, ou essai où **M1 seul lève** benne **FERMÉE**) |
| **6** | 🟠 **Le mouflage 3:1 vient d'une analyse VISUELLE** (photos/vidéo) — **pas d'un plan**. Et **`θ_max` (90° ou 180°) est inconnu** ⇒ la résolution angulaire (6 ou 12 °/m) est incertaine | 🟠 | Fiche/plan de la benne, ou 2 photos + rapporteur |
| **7** | 🟠 **Les constantes du coffret de résistances sont INVENTÉES** (`[3,6 ; 1,9 ; 0,9 ; 0,35 ; 0]`) ⇒ **toutes** mes fenêtres de décrochage **par palier** en dépendent. Seuls `Cmax` et `gmax_base` sont semi-ancrés | 🟠 | Relevé ohmique réel du coffret |
| **8** | 🟠 **360 V et service S3 non intégrés numériquement** : le `×0,81` sur le couple est appliqué à la main ; la « capacité continue » de 111 kW est **optimiste** pour un levage par à-coups | 🟠 | Intégrer dans le modèle + plaque moteur (régime S3) |
| **9** | 🟠 **Mes fourchettes clés (Cmax/Cnom 2,2-2,6, J, E2, « gmax 0,08 plausible ») viennent d'un rapport de recherche REJETÉ** (Gemini : sources = liens de recherche Google, 4 valeurs auto-contradictoires). Elles sont **corroborées** par 2 recherches indépendantes, mais **aucune source primaire** n'a été lue | 🟠 | Catalogues constructeurs (VEM / Leroy-Somer / WEG), CT 207 réel |
| **10** | 🔴 **Mes analyses de trace ont produit au moins 3 erreurs** : ① « P1 ≈ 0,29-0,30 m/s » ⇒ **NON VÉRIFIÉ** (phases courtes seulement) ② « P1 = 0,73 m/s » ⇒ **attribution non prouvée** ③ j'ai failli conclure sur `DeltaPosition_M` **tracé** — **il vaut 0 en permanence** dans la trace 48 alors que l'écart **calculé** M2−M1 varie de **0 à 15 m** ⇒ **la variable tracée n'est PAS le Delta calculé** | 🔴 | Vérifier le chemin d'instance de cette variable (`M2TreuilBenne.Bucket.State.DeltaPosition_M`) : projection non rafraîchie ? |
| **11** | 🟠 **Aucune de mes prédictions n'a été validée par un essai réel** — tout vient de **traces archivées** (06/09) et de calculs | 🟠 | Le protocole de trace (11 passes) |
| **12** | 🟠 **Je n'ai PAS vérifié** : la config codeur `0x6031`, `PointsPerRev` réel, ni la cause de la divergence des 2 voies — ce sont pourtant **mes propres recommandations n°1** | 🟠 | À faire **dans l'IDE** (≈15 min), pas sur la machine |
| **13** | 🟡 **Ordre de priorité de calage** initialement faux : je mettais `J` en avant, alors que `i` est **le levier n°1** (vitesse **et** masse ∓20 %) et que `J` est **inerte en régime établi** | 🟡 | Corrigé dans `REFERENCE_CALAGE` §2/§9 |

---

## 4. Les 3 questions qui commandent TOUT le reste

| # | Question | Coût | Ce qu'elle débloque |
|---|---|---|---|
| **Q1** | **Quelle voie de vitesse est juste ?** (config EtherCAT `0x6031` + `PointsPerRev` réel, ou **1 tour de tambour**) | 15-20 min | Tranche `i` **et** la marge de survitesse (si la CoE sous-lit, les seuils 2,0 m/s sont érosés vers **~2,29 m/s réels**) |
| **Q2** | **`i` réel** (tours moteur par tour de tambour, + compter les brins) | 10 min machine | Fixe vitesse, masse, découpage — **∓20 % sur tout** |
| **Q3** | **`θ_max` et la course réelle de la benne** (fiche/plan) | 5 min | Fixe la résolution angulaire (6 ou 12 °/m) et les seuils (%/degrés) |
| *(terrain)* | **Plaque moteur** (Cmax/Cnom, E2, R2, In, S3) + **relevé ohmique du coffret** | — | Toutes les valeurs absolues de couple et de décrochage |

---

## 5. Actions, dans l'ordre

| # | Action | Où | Débloque |
|---|---|---|---|
| 1 | Lire **config codeur** (`0x6031` : numérateur/dénominateur) + **résolution réelle** vs `PointsPerRev = 8192` (`PRG_02:72`) | IDE CODESYS | Q1 |
| 2 | **Compter les tours** moteur/tambour (benne libre, hors eau) | Machine | Q2 |
| 3 | Lire **plaque moteur** + **relevé du coffret** + mesurer le **Ø tambour** réel | Machine | Couples absolus |
| 4 | **Fiche/plan benne** : θ_max + reconfirmer la course **15 m en charge** (`GVL_PERSISTENT.st:64` dit « à reconfirmer au premier essai en charge ») | Doc/machine | Q3 |
| 5 | **Câbler la charge** au sim (extension T318 : 2 vars `GVL_Simulation` + 2 lignes dans l'appel) | CODE | Rend les tests de décrochage **exécutables** |
| 6 | Lancer le **protocole de trace** (`PROCEDURE_TRACE_TREUIL_CHARGE_v0.1.md` : test d'étalonnage + 11 passes) | Machine | Pente charge↔vitesse, plafond P5, cadence inter-gradins |

---

## 6. Mission du challenger — ce que j'attends de toi

1. **Verdict par affirmation** du §2 : `CONFIRMÉ` / `FAUX` / `PARTIEL` / `NON VÉRIFIABLE`, avec **valeur recalculée** et **preuve `fichier:ligne`**.
2. **Attaque les 13 faiblesses du §3** : lesquelles sont réelles, lesquelles j'exagère, et **lesquelles j'ai oubliées**.
3. **Cherche ce que je n'ai PAS vu** : thermique / service S3, choc mécanique réducteur, mou de câble, poids du câble suspendu à −18 m, survitesse, comportement multi-treuils simultanés, effet des couches de câble sur le Ø effectif, tout autre facteur invalidant.
4. **Vérifie les 6 livrables** du §7 : cohérence interne, chiffres périmés, affirmations non étayées, chemins de variables inexistants.
5. **Format imposé** : tableau `# | Affirmation | Verdict | Valeur retenue | Preuve` puis **liste d'erreurs** (les plus graves d'abord), **ce qui est NON VÉRIFIABLE**, et **3 actions prioritaires**.

---

## 7. Livrables de la session (tous **non commités**, en attente de validation humaine)

| Fichier | Contenu | État |
|---|---|---|
| `DOC/WFLOW/PROMPTS/05_brief_recherche_moteur_treuil_benne.md` | Brief de recherche externe (sources rejetées/cibles, 7 questions, 14 formules, 4 contraintes) | ✅ |
| `DOC/WFLOW/CONTRACTS/REFERENCE_CALAGE_TREUIL_M1M2_v0.1.md` | **Bloc de calage** (révision 2) : structure mécanique, `i`, couples, bornes de masse, fenêtres de décrochage, limites | ✅ corrigé 2× |
| `DOC/WFLOW/CONTRACTS/PROCEDURE_TRACE_TREUIL_CHARGE_v0.1.md` | Protocole d'enregistrement (étalonnage + 11 passes + grille de notation + sécurité) | ✅ |
| `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/trace_treuils_charge_v1.txt` | Liste de **108 variables** de trace (sans doublon) | ✅ |
| `DOC/WFLOW/CONTRACTS/PLAN_T320_SIMBENCH_MIROIR_APPRENTISSAGE_VITESSE.md` | Plan : le sim publie une enveloppe de vitesse indexée comme la table d'apprentissage (comparaison auto sim ↔ réel) | 🟡 en attente de validation |
| *(cette synthèse)* `DOC/WFLOW/PROMPTS/06_bilan_challenge_calage_treuil.md` | Bilan + auto-challenge + passation | ✅ |

---

## 8. Ce que je n'ai PAS fait (volontairement ou par blocage)

- ❌ **Aucune ligne de code ST écrite** : `T317` est **bloqué en R0** (5 questions P0 non tranchées) et `AGENTS.md` interdit d'écrire du ST avant validation humaine.
- ❌ **Aucun fichier de `CODE/` modifié**, **aucun commit**, aucun déplacement de fichier.
- ❌ **Aucun recalage appliqué** dans le simulateur : tout est **proposition** (`REFERENCE_CALAGE`).
- ❌ **Aucune validation terrain** : rien n'a été mesuré par mes soins, uniquement analysé depuis des traces archivées.
- ❌ **Aucun seuil de sécurité touché** (`SpeedGuardEnable` reste `FALSE`, bandes et surveillance inchangées).
- ⚠️ **Dettes signalées, non corrigées** : commentaire faux `FB_SimBench.st:133-134` ; `PLAN_T317` périmé (« `FB_Sim_WinchElectrical` pas encore écrit » → il l'est) ; configs de trace contenant des **doublons** de variables.
