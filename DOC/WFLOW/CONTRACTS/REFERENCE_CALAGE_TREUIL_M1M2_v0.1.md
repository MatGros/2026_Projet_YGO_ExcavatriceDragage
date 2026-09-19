# REFERENCE_CALAGE_TREUIL_M1M2_v0.1 — Bloc de calage du modèle électrique treuils

**Statut** : 🟡 **PROPOSITION — RÉVISION 3** · valeurs `ESTIMÉE` sauf §0 (plaque **MESURÉE**).
> 🚩 **RÉVISION 3 (2026-09-20)** — **PLAQUE SIGNALÉTIQUE RÉELLE OBTENUE** (132 kW · 1475 tr/min · In 242 A · E2 280 V · I2n 295 A · S3-40 %) ⇒ **lire §0 EN PREMIER**.
> **Conséquences** : ① la **charge réelle** est **7 t de tare + jusqu'à 9 t de matière ≈ 16 t** (l'arbitrage « 10 t » du §1 est **caduc**) ② `Cnom = 854,6 Nm` et `Cmax ≈ 2051-2222 Nm` (le sim à 3800 est faux de **78 %**) ③ `R2 = 9,1 mΩ` ⇒ le coffret inventé est **absurde** et il est désormais **borné sans l'ouvrir** ④ `i ≈ 31-34` confirmé par un argument de conception ⇒ **la voie POSITION est la référence**.
> ⚠️ **Sections à recalculer** (valeurs dérivées des anciennes hypothèses 111 kW / 10 t / i=48 ou 37) : **§2** (termes de charge), **§8.1/8.2/8.3** (masses et fenêtres de décrochage, bâties sur le **coffret inventé**). Le recalcul est **le périmètre de T321**.
> 🏷️ **STATUTS** : la **source unique** des statuts (`MESURÉE` / `DOCUMENTÉE` / `ESTIMÉE` / `SYNTHÉTIQUE` / `INCONNUE`) est **`DOC/WFLOW/REGISTRES/REGISTRE_VALEURS_TREUIL_STATUTS_v1.0.md`** — en cas de contradiction, **le registre prime**. Ce document-ci porte les **dérivations**, pas les statuts.
**Révision 2 (2026-09-20)** — corrections issues d'un **challenge par 3 agents indépendants** :
① la borne de masse est **PAR CÂBLE** (la charge est partagée entre les 2 câbles) ② le mapping couple était **construit sur `i = 48`** alors que la mesure donne **`i ≈ 34-39`** ⇒ **à recalculer** ③ la **voie de vitesse CoE est fausse** — **démontré par le code** (§6) ④ intégrer la chute **400→360 V** (couple **×0,81**) et le **service S3**.
**Date** : 2026-09-20 · **Périmètre** : `FB_Sim_WinchMotor` / `FB_Sim_WinchElectrical` / `FB_Sim_Encoder` (T317, T318)
**Origine** : arbitrage humain « 10 t » (2026-09-20) + mesures de traces (06/09) + recherche externe **auditée** (rapport Gemini rejeté comme source).
🚫 **Aucun code écrit.** Ce document ne fait que fixer les valeurs cibles et **ce qui les mesurera**.

---

## 0. 📋 PLAQUE SIGNALÉTIQUE RÉELLE — **MESURÉE** (transmise le 2026-09-20)

| Grandeur | Valeur plaque | Impact |
|---|---|---|
| **Puissance nominale** | **132 kW** | *(et non 111 kW estimés)* |
| **Vitesse nominale** | **1475 tr/min** | ω = 154,46 rad/s |
| **cosφ / rendement** | **0,86 / 93,5 %** | recalcul de contrôle : √3×400×242×0,86×0,935 = **134,8 kW** ⇒ **cohérent à 2,1 %** ✅ |
| **Service** | **S3 - 40 %** | confirme le levage par cycles (duty mesurée ≈ 20-30 %) |
| **Stator** | 400 V Δ · **In = 242 A** | *(et non ~200 A estimés)* |
| **Rotor (bagues)** | **E2 = 280 V** · **I2n = 295 A** | **base physique du coffret** |
| Masse | 1150 kg | cohérent avec J ≈ 4-7 kg·m² (roulements 6319 C3) |

**Valeurs dérivées — vérifiées :**
- **`Cnom = 854,6 Nm`** (132 000 / 154,46)
- **`R2 ≈ 9,1 mΩ`** par phase rotor : `sn·E2 / (√3·I2n)` avec `sn = 1,67 %` ✅ *formule valide car `sX2 ≪ R2` à faible glissement (+2 % d'erreur)*
- **`Cmax ≈ 2051-2222 Nm`** pour `Cmax/Cnom = 2,4-2,6` — ⚠️ **ratio typique, PAS mesuré** ⇒ **le sim à 3800 Nm est faux de ~78 %**

### 🔴 Conséquence 1 — le coffret rotorique INVENTÉ est absurde, et il est maintenant **BORNÉ**

| Modèle | R2 par phase | R_total (P1) | **I2 au démarrage** | Verdict |
|---|---|---|---|---|
| **Sim actuel** | 0,08 Ω | 3,6 Ω | **45 A** *(vs 295 A nominal)* | ❌ **absurde** — le moteur ne produirait presque pas de couple |
| **Réel (dérivé)** | **9,1 mΩ** | **0,23-0,32 Ω** | **~500-700 A** (170-240 % de I2n) | ✅ cohérent avec un démarrage rhéostatique |

⇒ `RotorResistanceOwn_Ohm` du code est **8,8× trop grand**, et l'array `[3,6 ; 1,9 ; 0,9 ; 0,35 ; 0] Ω` est **hors d'échelle d'un facteur ~10-100**.
🎯 **Contrainte physique NOUVELLE** : en imposant `I2_démarrage ≈ 2-2,5 × I2n` (pratique des démarreurs rotoriques) ⇒ **`gmax(P1) ≈ 2,5-3,5`** ⇒ **`R_total(P1) ≈ 0,23-0,32 Ω`** ⇒ **`Rext(P1) ≈ 0,22-0,31 Ω`**. **Le coffret est donc borné SANS l'ouvrir** (à confirmer par relevé ohmique).

### 🔴 Conséquence 2 — la CHARGE réelle **remplace** l'arbitrage « 10 t » du §1

| Élément | Valeur | Statut |
|---|---|---|
| **Benne à VIDE (tare)** | **7 t** | ✅ **MESURÉE** — fin des 3 estimations divergentes (1-3 / 3,5 / 4,5-5 t) |
| Capacité | **~4 m³** | DOCUMENTÉE |
| Matière (2,25 t/m³) | ~9 t | ESTIMÉE (densité en place) |
| **TOTAL benne pleine** | **≈ 16 t** *(en air)* | ESTIMÉE mais **ancrée sur la tare mesurée** |

⇒ **§1 ci-dessous (« 10 t = masse totale suspendue ») est CADUC** : il reposait sur une estimation utilisateur (« godet chargé ~10 t »). **Valeur réelle : 7 t de tare + jusqu'à ~9 t de matière.**

### 🎯 Conséquence 3 — la plaque **CONFIRME `i ≈ 31-34`**, donc la voie **POSITION**

Argument de conception canonique en levage : **une benne pleine à la vitesse maximale ≈ le point nominal du moteur**.
```text
i = (m_totale/2) × g × r / (Cnom × η)     m_totale = 16 t, Cnom = 854,6 Nm
   η = 0,85 → i = 34,4            η = 0,95 → i = 30,8
   ⇒ i ≈ 31-34, à confronter à la borne dure i ≤ 33,6 (vitesse ascensionnelle)
```
Et le couple/puissance correspondants : **16 t à i = 32,5 ⇒ 904 Nm/câble = 106 % de Cnom = 140 kW = 106 % de 132 kW** ⇒ la machine travaille **à sa limite S3** avec une benne pleine à vitesse max ⇒ **explique le plateau observé** et **confirme `i ≈ 32-34`**.
⇒ La vitesse max vraie qui en découle (**≈ 1,40-1,49 m/s**) correspond à la **voie POSITION (1,486 m/s)** et **pas** à la voie CoE (1,287 m/s) ⇒ **la voie CoE est bien la fautive** (sous-lecture 12,7 %) ⇒ 🚨 **la marge de survitesse reste érodée** (§6).

### 🟠 Conséquence 4 — bornes de masse recalculées (132 kW, pas 110)

`m ≤ P·η/(g·v)` **par câble** : à 1,486 m/s et **132 kW** ⇒ **≤ 7,7 t/câble** ⇒ **≤ 15,4 t au total** ⇒ **une benne de 16 t à ~1,43 m/s est cohérente** ✅ *(l'ancienne borne « 7,4 t » utilisait 110 kW : elle sous-estimait la machine).*

⚠️ **À REFAIRE** : toutes les **fenêtres de décrochage par palier** (§8.2 / §8.3) ont été calculées avec le **coffret inventé** ⇒ à recalculer dès que les gradins réels seront connus. Et « le palier 5 ne tient pas 5 t/câble » vaut pour un **démarrage à l'arrêt** (couple à `s=1`) — **pas** pour un maintien en mouvement (le couple **max** du palier reste 2051-2222 Nm).

---

## 1. ⚠️ Arbitrage « 10 t » — **CADUC depuis la plaque signalétique** (voir §0)

> Conservé pour traçabilité. **La valeur réelle est : tare 7 t + jusqu'à 9 t de matière.**


| Élément | Valeur | Statut |
|---|---|---|
| **Masse totale suspendue (SWL)** | **≈ 10 t** | **ARBITRÉE** par l'humain (2026-09-20) |
| dont **matière extraite** | **≈ 7-9 t** | ESTIMÉE (oral terrain, **non noté**) |
| dont **benne vide (tare)** | **≈ 1-3 t** (déduite du SWL) | ESTIMÉE — ⚠️ la tare **4,5-5 t** du rapport Gemini **n'est PAS retenue** (incompatible avec 7-9 t de matière sous 10 t de SWL) |
| **Partage entre les 2 câbles** | M1 **et** M2 montent ensemble ⇒ chaque moteur ne porte qu'**une fraction** du SWL | 🔴 **NON VÉRIFIÉ** — le partage **n'est pas garanti 50/50** (au décollage du fond, M2 porte l'essentiel ; en descente, M1) |

⚠️ **Justification de l'arbitrage — ordre de grandeur, PAS une réfutation dure** (la puissance moteur est **ESTIMÉE**, et le partage des 2 câbles est inconnu) :

```text
Si les 10 t étaient la charge UTILE seule ⇒ total ≈ 18-20 t ⇒ ≈ 9-10 t PAR CÂBLE à 1,0 m/s
P_par_moteur = 9 000 × 9,81 × 1,0 / 0,85 ≈ 104 kW   (≈ 115 kW à 10 t/câble)
⇒ à la limite — voire au-delà — des ~106-111 kW ESTIMÉS par moteur ⇒ le treuil calerait.
⇒ Hypothèse retenue : les 10 t sont le SWL TOTAL suspendu aux 2 câbles.
```
🟠 **Si le partage entre câbles n'était PAS effectif** (un seul câble portant tout), alors 10 t sur un moteur exigeraient **≈ 500-1000 Nm selon `i`, soit 75-151 kW** ⇒ **impossible** au-delà de i≈39 ⇒ **le partage est nécessaire** *si* la machine a réellement levé 10 t à 1,29 m/s (à vérifier).

---

## 1bis. Structure mécanique de la benne (analyse utilisateur 2026-09-20 — « à vérifier »)

| Élément | Description | Statut |
|---|---|---|
| **Mouflage INTERNE** (fermeture/ouverture) | **2 moufles indépendants de 3 brins** (3 brins **par câble**) ⇒ **rapport unitaire par câble = 3:1** · ouvrir/fermer de **Δh** ⇒ chaque câble ravalé de **3·Δh** · **v_câble = 3 × v_coquille** | ✅ **CONFIRMÉ par l'humain (2026-09-20)** — décomposition exacte |
| **Efforts de fermeture** | 6 brins porteurs repris ⇒ **T = F_coquilles / 6** · tambour M2 enroulant les **2 câbles** : **F_tambour = 2·T = F_coquilles / 3** ⇒ **M₂ = (F_coquilles/3) × R_t** | ✅ **CONFIRMÉ** — *vérification de bouclage : moufle d'un câble = 3T = F/2, × 2 câbles = F ✅ (aucun double comptage)* |
| **COURSE benne ouvert ↔ fermé** | **15 m de câble sur M2** (écart M1/M2 : **0 m ouvert ↔ 15 m fermé**) — mesuré sur la machine | ✅ **MESURÉE** : `GVL_PERSISTENT.st:67` → **`OffsetCloseM := 15.0`** (REX **2026-07-27** : « 10.0 → 15.0, offset M1/M2 en fermeture benne **mesuré** ») + **RECOUPÉ par les traces** : écart calculé M2−M1 = **0 → 15,03 m** sur 8188 éch. |
| **Modèle de benne du code** | `BucketOpening_Pct = 100 × (15 − Δ)/15` avec **Δ = M2 − M1** ⇒ 0 % = fermé (Δ≈15) · 100 % = ouvert (Δ≈0) | ✅ **Cohérent** — le code intègre donc **naturellement** la course relative mesurée (pas de facteur 3 ou 6 erroné) |
| ⚠️ **Contrainte qui vérifie le mouflage** | Course relative **15 m** ⇒ **Δh = 15 / (rapport par câble)** — **mais en ROTATION, pas en translation** : le câble suit un **arc** = `d_eff × θ` ⇒ `d_eff = 15 / (3 × θ_max)` | ✅ **Résolu** : la géométrie est **rotative** (coquilles en rotation autour du pivot) ⇒ **le levier effectif vaut 3,2 m si θ_max = 90°** et **1,6 m si θ_max = 180°** — deux valeurs **plausibles** pour une benne de 10 t. *Mon objection « 5 m de course linéaire » était une erreur de modélisation de ma part (j'avais supposé une translation).* |
| **Convention ANGULAIRE (proposition utilisateur)** | État benne = **angle θ** ∈ [0 (fermée) ; θ_max (ouverte)] avec **θ_max ≈ 90° ou 180°** ; le **%** = **θ / θ_max** | ✅ **Le `BucketOpening_Pct` du code est linéaire en course de câble**, elle-même ≈ linéaire en θ (arc ⇒ `ΔL ∝ θ`) ⇒ **le % est un proxy fidèle de l'angle** (écart résiduel possible : loi en cosinus de la distance entre réas fixes, quelques % sur la course) |
| **Résolution angulaire** | **6 °/m** de course M2 si θ_max = 90° · **12 °/m** si θ_max = 180° | Seuils du code convertis : `CoherenceLimitM = 1,0 m` → **±6° / ±12°** ; `CloseAnticipationM = 1,2 m` → 7,2° / 14,4° ; `OpenAnticipationM = 1,3 m` → 7,8° / 15,6° |
| 🔎 **À confirmer** | `OffsetCloseM = 15,0` porte le commentaire **« valeur à reconfirmer au premier essai benne en charge »** (`GVL_PERSISTENT.st:64`) ⇒ la course **peut varier légèrement en charge** (allongement de câble, géométrie sous effort) | 🟡 À reconfirmer |
| **Câbles supérieurs** | **4 câbles** vers le chariot : **2 de fermeture** (vers le moufle) + **2 de retenue** (fixés aux oreilles de la tête) | ANALYSÉ (vidéo) |
| **Mouflage EXTERNE** | **Prise directe 1:1**, aucun moufle suspendu | ✅ **CONFIRMÉ par l'humain** (photos + diamètre tambour) |
| **Treuil de retenue (M1)** | Vitesse de levage **= v_câble retenue** (1:1) | ANALYSÉ |
| **Treuil de fermeture (M2)** | Benne fermée en levage : **même vitesse linéaire que M1** | ANALYSÉ + ✅ **RECOUPÉ par les traces** (M1/M2 = 1,246 / 1,247 m/s) |
| | Ouverture **en l'air** : **M1 porte la charge**, M2 déroule à **6 × v_écartement** | ANALYSÉ |

### 🔴 Conséquence : erreur **STRUCTURELLE** du modèle, pas seulement de calage

`FB_Sim_WinchElectrical` applique le **même** `LoadNominalTorque_Nm` à M1 **et** à M2, comme deux treuils interchangeables. Or :

- **M1** porte une **part du poids** (2 câbles de retenue, 1:1) ;
- **M2** porte la **tension de FERMETURE**, **amplifiée par le moufle interne** ⇒ son couple tambour est ∝ **F_coquilles / 3** — ce n'est **pas** une part du poids ;
- la **cinématique d'ouverture** (v_câble M2 = **6 × v_ouverture**) n'est **pas modélisée du tout** ⇒ dans le sim, M2 se comporte exactement comme M1.

### 🟢 Partage de charge — **mesuré**, plus supposé

`M2_TensionedCable_DI` = **TRUE sur 100 % de la trace 46**, dont **100 % des phases de montée M1** ⇒ **le câble de fermeture est TOUJOURS tendu** ⇒ **la charge est PARTAGÉE** entre M1 et M2 (l'hypothèse « M1 seul porteur » pendant la montée est **écartée**).
⇒ Confirme la borne **par câble / par treuil**. Et **si** la montée tracée portait bien ~10 t, la puissance prouve qu'**aucun treuil n'en portait plus de ~7,4 t** ⇒ partage au moins **26 / 74**.

---

## 1ter. Apports de la CONTRE-EXPERTISE externe (2026-09-20) — audités

> Source : rapport de challenge externe (agent sans le contexte projet). Les 3 premiers points sont **retenus** (physiquement fondés) ; le 4ᵉ est un **angle mort à modéliser**.

| # | Apport | Statut retenu | Impact sur le modèle |
|---|---|---|---|
| **A** | **ÉGOUTTAGE** : la charge **varie de 30 à 50 % pendant UNE SEULE remontée** (eau + fines évacuées en ~10 s) | 🟠 ESTIMÉE (pas de source) mais **mécanisme réel** et cohérent avec les traces | ⇒ **la charge n'est PAS constante** : il faut un terme `drainage` dans le temps **et** en fonction de l'altitude (le matériau s'égoutte surtout à l'émersion). **Corollaire** : mes bornes de masse `m ≤ P·η/(g·v)` s'appliquent à la **charge DRAINÉE** (fin de remontée) ⇒ les bornes sont **valides mais portent sur le cas le plus léger** |
| **B** | **COUCHES DE CÂBLE** : 2-3 couches sur le tambour ⇒ **rayon effectif +5 à 10 %** entre le fond et la surface | ✅ PHYSIQUE, **quantifiée** | ⇒ ① la conversion **2,0 m/tr est valable à UNE couche près** ⇒ **±5-10 % d'incertitude supplémentaire sur `i`** (que je n'avais pas quantifiée !) ② la **profondeur affichée dérive** de 5-10 % selon la couche ③ le couple résistant et la vitesse varient ∝ rayon |
| **C** | **Rôle d'ÉTANCHÉITÉ de M2** : benne pleine, M2 **doit** rester tendu, sinon les coquilles s'ouvrent et le matériau se vidange ⇒ **M2 peut porter l'ESSENTIEL au moment de l'émersion** | ✅ PHYSIQUE (corroboré : `M2_TensionedCable_DI` = 100 % tendu) | ⇒ le partage **n'est pas symétrique par construction** : la tension de M2 est dictée par l'**étanchéité**, pas par une répartition 50/50 ⇒ à modéliser comme tel |
| **D** | **OUVERTURE DE BENNE = GRAVITÉ** : M1 maintient (vitesse nulle), M2 **dévide** ; les coquilles s'écartent **par leur propre poids** | ✅ Observation vidéo + cohérent avec les traces (M2 descente max **1,615** < M1 **1,841 m/s**) | ⇒ pendant l'ouverture, **le couple de M2 est quasi NUL** (il dévide contre les seuls frottements, voire en hypersynchrone) ⇒ **l'ouverture ne doit PAS être modélisée comme un effort moteur** |
| **E** | Moteurs de carrière souvent **S3 40-60 %** ⇒ un « 110 kW » affiché ne fait que **75-90 kW en S1** | ✅ Argument valable, **à nuancer** | La duty mesurée ≈ **20-30 %** (cycle 5-7 min dont ~1-2 min de levage) ⇒ **reste dans S3** ⇒ la puissance S3 est applicable **pendant la montée** ; le dérating S1 ne joue que sur un effort soutenu |
| **F** | **Tare « ≈ 3,5 t »** (contre-expertise) vs **1-3 t** (déduite) vs **4,5-5 t** (rapport Gemini) | 🔴 **INCONNUE** — 3 estimations, **aucune source** | La tare reste à **peser** (plaquette de benne) |

### 🔎 Recoupements indépendants apportés par la contre-expertise (utiles au dossier)
- ✅ **Visuel vidéo** : `1:1` externe, **6 brins internes = 2 moufles de 3** (⇒ 3:1/câble), **M2 tendu pendant le levage**, **M1 seul porteur pendant l'ouverture** ⇒ corrobore **4 points** que je n'avais que par la mesure/le code.
- ✅ **Absurdités confirmées par la physique** : `Cmax = 3800 Nm` ≈ un moteur de **200 kW** ou un rapport Cmax/Cnom **> 5** (impossible) ; `J = 45 kg·m²` ≈ l'inertie d'un moteur de **500 kW** ⇒ les deux constantes sont **fausses d'un facteur ~2 et ~10**.
- ✅ Leur estimation de `i` (**28-35**) converge avec ma branche « voie position » (**32-33**) — **pas** avec la branche 38,5-39.

### ❌ Points de la contre-expertise ÉCARTÉS (après vérification)
1. **« Cause possible = base de temps d'échantillonnage fausse »** ⇒ **RÉFUTÉ** : le rapport **par échantillon** (médiane **1,146**, sur 2 axes et 2 sens) compare deux grandeurs dérivées du **même pas de temps** ⇒ il est **indépendant de la base de temps**. L'écart est donc bien une **différence d'échelle** (comptage ↔ objet CoE `0x6031`).
2. **§15 incohérent** : ils annoncent une « course mécanique de traverse ≈ 2,5 m » puis concluent « 3 brins × ≈5 m = 15 m » (2,5 vs 5) ⇒ **la question « 15 m par câble ou somme des 2 câbles ? » n'est PAS tranchée** par leur rapport.
3. **§21 non rigoureux** : leur `i ∈ [28,35]` mélange des vitesses de **montée** et de **descente** (secteurs physiques différents) — la **zone** est bonne, la **méthode** non.
4. **⚠️ Angle mort PROCESS** : ils proposent de **modifier `FB_Sim_WinchMotor.st`** (Cmax, J, condition de décrochage) et de câbler la charge — **or `T317` est BLOQUÉ en R0** (aucune ligne de ST avant validation humaine des 5 questions P0) et le câblage de la charge est une **extension T318**. Ces actions sont **justes techniquement mais interdites en l'état** : leur rapport ne pouvait pas le savoir (contexte manquant).

---

## 2. Table de calage — correspondance **1:1** avec les constantes réelles du code

⚠️ **Les noms proposés par la recherche externe n'existent pas dans le code.** Voici la correspondance exacte — c'est cette table qui sera appliquée.

| Constante **du code** (nom exact) | Fichier | Défaut actuel | **Valeur recalée** | Statut | **Ce qui la mesurera** |
|---|---|---|---|---|---|
| `MaxTorque_Nm` (Cmax) | `FB_Sim_WinchMotor` | 3800 (**SYNTHÉTIQUE**) | **1750-1800 Nm** | ESTIMÉE | Plaque (Cmax/Cnom ≈ 2,4-2,6) ou essai de calage / traction |
| `LoadNominalTorque_Nm` (terme **matière**) | `FB_Sim_WinchElectrical` | 2500 (**SYNTHÉTIQUE**) | **≈ 509 Nm/câble** (4,5 t de matière/câble à i=32,5, η=0,85) | ESTIMÉE (matière) / **MESURÉE** (tare 7 t) | Courant stator stable en montée pleine charge |
| `LoadFrictionTorque_Nm` → devient **terme tare** | idem | 80 (**SYNTHÉTIQUE**) | **≈ 396 Nm/câble** (tare **7 t** ⇒ 3,5 t/câble) | **MESURÉE** (tare plaque benne) | Courant stator stable en montée benne vide |
| `Inertia_KgM2` | `FB_Sim_WinchMotor` | 45 (**SYNTHÉTIQUE**) | **3,5-4,5 kg·m²** | ESTIMÉE | Fiche moteur carcasse 315 (J rotor 2,2-3,2 + frein 0,5-0,8 + charge 0,44) |
| `SlipAtMaxTorqueBase_Ratio` (gmax base) | idem | 0,08 | **0,08-0,10** — ✅ *plage confirmée plausible* | ESTIMÉE | Calcul `R2/X2` ou mesure du glissement au couple max |
| `CST_RotorExtResistanceStep_Ohm` | idem | [3,6 ; 1,9 ; 0,9 ; 0,35 ; 0] (**SYNTHÉTIQUE**) | **gradins réels du coffret** | INCONNUE | Relevé ohmique aux bornes du coffret (nb réel de gradins inconnu) |
| `RotorResistanceOwn_Ohm` | idem | 0,08 (**SYNTHÉTIQUE**) | plaque + coffret | INCONNUE | Plaque (E2, I2n) + mesure |
| `MinSpeedMps` / `MaxSpeedMps` | `FB_Sim_Encoder` | 1,0 / **2,0** | ⛔ **à revoir — voir §6** | INCONNUE | Mesure de la vitesse câble par palier |
| `CableM_PerRev` | `PRG_02_Acquisition` / `FB_Sim_Encoder` | 2,0 | **à confirmer** (semi-confirmé 2026-07-02) | DOCUMENTÉE | 1 tour de tambour = ? m de câble |

---

## 3. Deux grandeurs **non transposables** dans le modèle

| Grandeur proposée | Pourquoi elle n'est **pas** une constante du sim |
|---|---|
| **`Cnom` ≈ 720 Nm** | **Kloss n'utilise que `Cmax` et `gmax`.** `Cnom` n'apparaît nulle part dans le modèle → valeur **documentaire seulement** (sert à vérifier le ratio Cmax/Cnom et à comparer au courant mesuré) |
| **`i`** | Le sim travaille en **m/s** via `CableM_PerRev` + `Min/MaxSpeedMps` : le rapport de réduction y est **implicite** → ce n'est pas une constante du modèle, mais il **commande tous les couples** du §2 |

🔴 **`i` N'EST PAS 48.** Les mesures donnent **`i ≈ 34-39`** : 1,287 m/s ⇒ `i ≤ 38,8` ; 1,486 m/s ⇒ `i ≤ 33,7`. **`i = 48` est exclu dans les deux lectures** (il exigerait 1858-2140 tr/min, **au-dessus du synchronisme en montée**).
⇒ **`i` doit être MESURÉ** (tours moteur par tour de tambour) : c'est **le levier n°1** — vitesse **et** masse varient de ∓20 % avec lui. **Toute valeur de couple calculée avec 48 est périmée** (dont les 765 Nm @10 t du rapport de recherche) : **à i = 37, compter 471-540 Nm/câble pour 10 t partagés**.

🎯 **Meilleure estimation actuelle : `i ≈ 32-33`** — raisonnement par **ancres INDÉPENDANTES** :
| Ancre | Ce qu'elle impose |
|---|---|
| **`1 tour de tambour = 2,0 m`** — **CONFIRMÉ par l'humain** (analyse photos + diamètre tambour), **sans mouflage (1:1)** | la constante de conversion de la **voie position** est **juste** |
| `PointsPerRev = 8192` (« 13 bits », `PRG_02:72`) + ordre de grandeur de la profondeur indiquée (M1 **−18,25 m**) | ⇒ **la voie POSITION est ancrée** ⇒ c'est **la voie CoE qui est fausse** (elle **sous-lit de 12,7 %**) |
| Montée : `n ≤ 1500` (physique) | `v_vraie = 1,486 m/s` ⇒ **`i ≤ 33,6`** ; à n = 1450 (glissement 3,4 %) ⇒ **`i = 32,5`** |

✅ **Contrôle de cohérence croisé** : avec `i = 32,5` et `n = 1449 tr/min`, la vitesse **vraie** = **1,487 m/s (89,2 m/min)** et la valeur **affichée** par la voie CoE défectueuse = **1,29 m/s (77,9 m/min)** ⇒ **ce sont EXACTEMENT les deux mesures** (position 1,486 · CoE 1,287).
🚫 **Piège écarté** : la mémoire utilisateur « **75 m/min** » n'est **pas** une ancre indépendante — c'est la vitesse **lue à l'IHM**, donc **la voie CoE elle-même** ⇒ s'en servir pour valider la voie CoE était **circulaire**. Et « 60 m/min » impliquerait `i = 48` ⇒ 1795 tr/min > synchronisme ⇒ **exclu**.

---

## 4. 💡 Aucune restructuration nécessaire

La formule **existante** du couple résistant est déjà de la bonne forme :

```text
FB_Sim_WinchElectrical §4 :  C_résistant = LoadFrictionTorque_Nm + taux_charge × LoadNominalTorque_Nm
```

| | Actuel | Recalé (**par câble**, i=37) |
|---|---|---|
| terme fixe | 80 Nm (frottements) | **≈ 100 Nm (tare)** |
| terme variable | 2500 × taux | **≈ 400 × taux (matière)** |
| **taux = 0** | 80 Nm | **≈ 100 Nm** ✅ benne vide |
| **taux = 1** | 2580 Nm | **≈ 500 Nm** ✅ benne pleine (10 t partagés = **5 t/câble**) |

⇒ **Aucun changement de structure** : on remplace 2 valeurs, la sémantique devient « 0 = benne vide, 1 = benne pleine ».

---

## 5. 🚦 Prérequis bloquant : la charge n'est **pas câblée**

| Fait vérifié | Conséquence |
|---|---|
| `SimWinchLoadFrac_Ratio` et `SimWinchCoupledActive` sont des `VAR_INPUT` de `FB_SimBench` **absents de `GVL_Simulation`** et **non passés** dans l'appel `instSimBench(...)` (`PRG_02_Acquisition.st:262-355`) | La charge vue par le modèle vaut **toujours 0** ⇒ `C_résistant = 80 Nm` |
| Le décrochage par charge exige `C(s=1) < C_résistant` | À 80 Nm, **aucun décrochage n'est possible** (le plus petit `C(s=1)` vaut 604 Nm) |

🚨 **Donc, aujourd'hui, le banc ne produit pas de faux positifs : il ne produit RIEN.** Le test de décrochage voulu est **inexerçable** tant que la charge n'est pas câblée (extension T318 : 2 déclarations `GVL_Simulation` + 2 lignes de câblage).
⚠️ Corollaire : la formule « le recalage élimine les faux positifs » est **inexacte** — le recalage fera **apparaître** des décrochages (voir §8), il n'en supprime pas.

---

## 6. ✅ Contradiction vitesse — **TRANCHÉE** (preuve par le code, 2026-09-20)

**Les deux voies partagent la MÊME constante** : `CablePosM = (RawPos − Ref) × 2,0/8192` (`FB_Encoder_Scale.st:38`) et `V_CoE = Spd × 0,1 × 2,0/60` (`FB_Encoder_SpeedMeasure.st:49`).
⇒ **`CableM_PerRev` s'annule dans leur rapport.** L'écart mesuré — **×1,146 intra-trace**, identique sur **M1 et M2** et en **montée comme en descente** (médiane 1,1464 ; n = 96 à 245 échantillons par fenêtre) — vaut donc **rpm_compté / rpm_rapporté**.

### 🔴 Conclusion : c'est la voie **VITESSE (CoE)** qui est fausse

L'erreur est **100 % dans le rapport comptage position / objet vitesse `0x6031`** du codeur (échelle CoE **ou** `PointsPerRev` ≠ 8192) — **PAS** dans le développement tambour.
✅ La voie **position** est **fiable** : ancrée par le homing (trace 48 : M1 max = **8,4997 m** = `CfgTopSensorPos_M` **8,5 m**).
❌ **Artefacts exclus** : filtre PT1 (supprimé du code, `FB_Encoder_SpeedMeasure.st:8`), quantification (1 count = **0,244 mm**), offset/homing/preset (constants ⇒ dérivée nulle), limiteur ±99 m. Aucun `Error`/`ErrorId` ≠ 0, aucun défaut synchro dans les traces 40/46.
ℹ️ `State.Position_M` **≡** `Measurement.CablePosM` (même signal, `FB_WinchStateProjection.st:87,154`) : il n'y a donc **qu'une source de position**, opposée à **une** voie vitesse.

### 🚨 IMPACT SÉCURITÉ (devoir d'alerte)

**Tout le logiciel de vitesse consomme la voie CoE sous-lue de ~12,7 %** :

| Consommateur | Conséquence |
|---|---|
| **Surveillance de survitesse** (`FB_Safety_Winch.st:453`, bande 2,0 m/s) | déclencherait vers **~2,29 m/s réels** ⇒ **marge érodée**. *Atténué aujourd'hui : `SpeedGuardEnable := FALSE` (`PRG_04:1394/1462`)* |
| **Bandes du load estimator** (`FB_WinchLoadEstimator.st:97-104`) | classement de charge **biaisé de 12,7 %** |
| **Apprentissage par palier** (`FB_WinchSpeedLearning.st:94-104`, table RETAIN) | la table collectée serait **biaisée de 12,7 %** ⇒ un futur apprentissage enregistrerait des vitesses **fausses** |

🎯 **À vérifier en PRIORITÉ** : configuration **EtherCAT du `0x6031`** (numérateur / dénominateur de vitesse) + **`PointsPerRev` réel** du codeur. C'est **là** que vit l'erreur.
⚠️ Le palier 5 du sim à **2,0 m/s reste IMPOSSIBLE** en montée (il exigerait `i ≈ 19-24` ⇒ **196-245 kW**). Plafond mesuré en montée : **1,29-1,49 m/s** ⇒ `i ≈ 34-39`.

### 🎯 Test d'étalonnage recommandé (plus discriminant que le mètre ruban)

1. Marquer le câble ; faire tourner le tambour d'**UN tour exact** ⇒ mesurer le **développement réel (m/tr)**.
2. Comparer la **vitesse 0x6031 rapportée** au **rpm réel compté au chrono**.
3. Si m/tr réel ≈ 2,0 **ET** rpm rapporté sous-lu de ~12,7 % ⇒ **la voie vitesse est définitivement fausse**.
⚠️ Le mètre ruban n'est valide que s'il mesure le **débobinage du câble au tambour** (repère traversant un point fixe), **jamais** le déplacement vertical de la benne (2 câbles ⇒ déplacement ≠ débobinage) ; et le trajet doit rester **dans une même couche** du tambour (le diamètre varie par couche).

---

## 7. ⚠️ `η_méca` : l'hypothèse la plus lourde qui reste non sourcée

| η réducteur+treuil | C_moteur **par câble** (5 t à i=37) | P à 1,29 m/s | % de 110 kW | Verdict |
|---|---|---|---|---|
| 0,85 | **≈ 496 Nm** | **≈ 75 kW** | **68 %** | ✅ **dans les cordes** |
| 0,96 (hélicoïdal/planétaire) | ≈ 439 Nm | ≈ 67 kW | 61 % | ✅ dans les cordes |

⚠️ **Correction de la v1** : le tableau précédent (765 Nm → 118 kW → 107 % / 95 %) était calculé avec **i = 48 ET sans partage de charge** ⇒ **périmé**.
⇒ Avec la géométrie mesurée **et** le partage, la pleine charge à vitesse max reste à **61-68 % de la puissance nominale** : **`η` n'inverse plus de conclusion**. Il reste à sourcer (plaque réducteur) pour l'**exactitude du terme de couple**, pas pour la viabilité.
📌 **Sans partage**, 10 t sur un seul câble à i=37 exigeraient **≈ 993 Nm ⇒ 151 kW ⇒ impossible** : c'est l'argument qui rend le **partage nécessaire** *si* 10 t ont réellement été levés à 1,29 m/s.

---

## 8. Impact chiffré du recalage (avant / après)

### 8.1 Couple à l'arrêt (s = 1) par palier — « ce palier peut-il démarrer cette charge ? »

| Palier | Sim actuel (Cmax 3800) | **Recalé (Cmax 1750)** |
|---|---|---|
| P1 | 1923 Nm | **886** |
| P2 | 3058 | **1408** |
| P3 (optimum, gmax ≈ 1) | 3799 | **1750** |
| P4 | 2758 | **1270** |
| P5 | 604 | **278** |

### 8.2 Masse maximale démarrable — **PAR CÂBLE**, à `i = 37`

| Palier | Sim actuel (Cmax 3800) | **Recalé (Cmax 1750)** |
|---|---|---|
| P1 | 22,8 t | **10,5 t** |
| P2 | 36,2 t | 16,7 t |
| P3 (optimum, gmax ≈ 1) | 45,0 t | **20,7 t** |
| P4 | 32,7 t | 15,0 t |
| **P5** | 7,2 t | **3,3 t** ← ne peut pas démarrer 5 t/câble |

⚠️ **Valeurs PAR CÂBLE** : pour la masse **totale**, multiplier par le nombre de câbles porteurs (≤ 2) **si le partage est effectif** — **non vérifié**.
⚠️ **Dépend de `i`** (∓20 % : à i=34 → 3,0 t / i=39 → 3,5 t au palier 5). Les valeurs « 4,3 t / 9,3 t » publiées en v1 étaient calculées avec **i = 48** ⇒ **périmées**.

🚨 **Conséquence sécurité** : avec les constantes actuelles le sim **ne voit jamais** un décrochage réel au palier 5 (il croit pouvoir démarrer 9,3 t) — mais il ne le voit pas davantage après recalage, **parce que la charge n'est pas câblée** (§5). Les deux défauts s'additionnent.

### 8.3 Fenêtre de tenue au palier 5 (zone de décrochage) — **par câble**

| Scénario | Fenêtre de glissement | Décrochage sous |
|---|---|---|
| Sim actuel (Cmax 3800 / charge 2580 Nm) | s ∈ [0,031 ; 0,204] | **1193 tr/min** |
| **Recalé — benne VIDE (100 Nm/câble)** | tient **tout le glissement** | **aucun** décrochage par charge |
| **Recalé — benne PLEINE (500 Nm/câble)** | s ∈ [0,0117 ; 0,548] | **678 tr/min** |
| ~~v1 : pleine 765 Nm (i=48)~~ | ~~s ∈ [0,0184 ; 0,348]~~ | ~~979 tr/min~~ ❌ **périmé** |

🎯 **Lecture** : avec les constantes recalées, le palier 5 **décroche dès qu'on y engage la benne pleine au-dessus de ~678 tr/min**, alors que le simulateur actuel ne décrocherait qu'à **1193 tr/min** ⇒ il **valide une manœuvre qui cale la machine réelle**. C'est la démonstration chiffrée du faux sentiment de sécurité.

---

## 9. Limites assumées (noir sur blanc)

1. **Toutes les valeurs sont `ESTIMÉE`** — fourchettes d'ingénierie, **pas des mesures**.
2. ⚠️ « `gmax base` 0,08 — **plage plausible** » : cette appréciation provient du **rapport de recherche rejeté** (Gemini) ⇒ **non sourcée** ; à traiter comme une **fourchette retenue par défaut**.
3. La **tare (1-3 t)** est **déduite** du SWL 10 t et de l'oral « 7-9 t de matière » — **aucune pesée**.
4. Le coffret de résistances reste **entièrement inconnu** : les 5 gradins et leurs valeurs ohmiques sont inventés. Le **dernier rapport (×5,38 contre λ ≈ 2,0-2,6 attendu)** est jugé **anormal** mais **invérifiable** sans relevé.
5. 🟠 **`η_méca` = 0,85 n'est sourcé par rien** : il déplace le couple de charge de **±8 %** (496 → 439 Nm/câble à i=37), mais le point de fonctionnement reste **dans les cordes** (61-68 % de la puissance nominale) ⇒ enjeu d'**exactitude**, **pas** de viabilité.
6. 🔴 **Chute 400 → 360 V non intégrée** : couple disponible **×0,81** ⇒ borne de masse **6,7 t/câble** au lieu de 7,4 ; l'appel simultané des 2 treuils (~238 kVA) **aggrave** le creux du groupe (X″d **inconnue**).
7. 🔴 **Service S3, pas continu** : la capacité « continue » de 106-111 kW est **optimiste** pour un levage par à-coups (et le rendement d'un moteur à bagues est plus bas que celui d'un moteur à cage).
8. ⚠️ **Les scénarios de décrochage des §6/§7/§8 ne s'exécutent PAS aujourd'hui** : la charge n'est **pas câblée** (`SimWinchLoadFrac_Ratio` absent de `GVL_Simulation` et non passé dans `PRG_02:262-355`) ⇒ `C_résistant = 80 Nm` ⇒ **aucun décrochage par charge n'est exécutable au banc**. Ne pas lire ces sections comme le comportement courant du simulateur.
9. ⚠️ **Ce bloc ne qualifie PAS la machine** : il rend le banc **théoriquement plausible** ; il ne remplace aucune mesure. Les valeurs réelles n'arriveront qu'en mise en service (plaque moteur, coffret, pesée benne, **`i`**, vitesse câble).

---

## 10. Actions issues de ce document

| # | Action | Nature |
|---|---|---|
| 1 | Trancher la **contradiction vitesse** §6 (A ou B) — mesure « tour tambour / tour moteur » | 🔴 bloquant dossier |
| 2 | Sourcer ou mesurer **η_méca** §7 | 🟠 |
| 3 | **Câbler la charge** (§5, extension T318 : 2 vars + 2 lignes) — sans quoi le calage est inerte | 🔴 bloquant banc |
| 4 | Relevé **ohmique du coffret** + **plaque moteur** + **pesée benne** | 🔴 terrain |
| 5 | Corriger les 2 **dettes documentaires** (commentaire faux `FB_SimBench.st:134`, `PLAN_T317` périmé) | 🟡 |
