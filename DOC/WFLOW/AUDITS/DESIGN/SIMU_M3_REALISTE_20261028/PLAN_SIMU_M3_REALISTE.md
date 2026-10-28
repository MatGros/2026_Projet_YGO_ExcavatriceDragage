# 🧪 Plan — Simulateur M3 plus réaliste

> Etat courant du chantier : T417 dans DOC/WFLOW/TASKS.yaml et son contrat lie. Ce document conserve le cadrage ou le bilan anterieur ; il ne vaut pas validation du lot courant.

> 2026-10-28 · branche `work/base-machine-simu` · fusion Expert A + Expert B (synthèse : `SYNTHESE_EXPERTS_A_B.md`)
> 🎯 But : **simuler une mécanique plausible**, puis observer le programme. L'apparition d'un défaut n'est pas un critère de réglage ni une preuve de fidélité du modèle.
> 🔒 **Seul le simulateur bouge** (`CODE/L_SIMULATION/`, `GVL_Simulation`, tests CI, gates). **Programme machine intouché.**
> 🧭 Règle : **aucune couche en double**. Le simulateur lit les mêmes réglages que le programme (`GVL_PERSISTENT`).

---

## 1. 🔍 Pourquoi la simu actuelle ne montre rien

| ❌ Aujourd'hui | ✅ Réalité |
|---|---|
| Frein ne se ferme pas tant que f > 0,5 Hz (`FB_Sim_TranslationBrake.st:69`) | Frein à manque de courant : **retombe dès la coupure bobine** |
| Frein fermé = vitesse 0 instantanée (`FB_Sim_Translation.st:260-262`) | Petit arrêt mécanique (court à 10-20 Hz) |
| Chariot = esclave de la fréquence, sans masse | Variateur à 0 + frein ouvert → chariot poussable (benne qui balance) |
| Capteur Trémie à 5 cm de la butée | **≈ 50 cm** |
| Positions et échelle **en dur dans la simu** (0/5/15/20/30, `FullTravelTimeS`) = doublon des réglages machine | Une seule source : `GVL_PERSISTENT` |
| Aucune mesure de dépassement | — |
| Clignotement capteurs absent (bruit < hystérésis, profils OFF) | Au franchissement : vu → perdu → retrouvé → fixe |

## 2. 📐 Hypothèses de travail (réglables, pas de mesure terrain)

| Paramètre | Valeur |
|---|---|
| Butée ↔ capteur extrême | 0,5 m |
| P1 ↔ Trémie / P1 ↔ Maintenance | 5 m / 5 m (vidéo ancienne : 5 ± 0,5 m, 9 s, vmax ≈ 0,7 m/s sans variateur) |
| Positions de travail | Trémie 0 · PV 1,5 · P2 3,5 · P1 5 · Maintenance 10 |
| Vitesse | 1 m/s à 50 Hz = gain 0,02 m/(Hz·s) (= `GVL_PERSISTENT` actuel) |
| Arrêt variateur (mot = 0) | Rampe variateur ~25 Hz/s, pas de roue libre |
| Arrêt propre manuel | 0,5 à 1 s après capteur, net |
| Glissade frein | faible (paramètre) |

## 3. 🧱 Lots

| # | Lot | Ce que ça change | Coût |
|---|---|---|---|
| **L0** | 🧮 **Calculateur de position du programme : réglage site simple** (= reprise T301) | Positions réelles des capteurs + **1 coefficient** à calcul unique, saisis sur site. Petits sauts au recalage acceptés. Programme modifié : **en premier**, avant toute simu | S-M |
| **L1** | 📏 **Une seule source de réglage** | Voir §4 (cadrage détaillé) | S |
| **L2** | 📊 **Indicateurs** (simu, observation seule) | Position vraie · dépassement après capteur · butée touchée + vitesse · frein fermé en mouvement · roue libre · mouvement pendant ouverture benne · écart calculateur ↔ vrai | S |
| **L3** | 🛑 **Frein physique** | Retombe sur coupure bobine quelle que soit la vitesse · décélération de freinage paramétrable | S-M |
| **L4** | 🛞 **Poussée benne frein ouvert** | Variateur à 0 + frein ouvert → poussée du pendule + frottement + pente option. À faire après L3. Sert à trancher l'hypothèse « poussé frein ouvert » | M |
| **L5** | 📡 **Capteurs : mécanisme de franchissement** | Vu → perdu → retrouvé → fixe, **selon la position sur la came**, à chaque passage | S-M |

🎛️ Chaque lot L2-L5 a son bit `SimM3…` dans `GVL_Simulation` (OFF = actuel). L1 n'a pas de bit : c'est une correction de source (marge butée 0 = ancien comportement).

## 4. 📏 Cadrage L1 — une seule source de réglage

**Objectif** : le simulateur ne porte plus aucune position ni échelle de vitesse en dur ; il lit les 6 réglages machine de `GVL_PERSISTENT` (5 positions + gain). Seule donnée propre à la simu : la marge butée.

| Élément | Aujourd'hui | Après L1 |
|---|---|---|
| Positions capteurs simu | `CST_PositionAt*` en dur | `_TranslationPos{Tremie,PV,P2,P1,Maintenance}_M` lues (`FB_SimBench` → entrées `FB_Sim_Translation`) |
| Vitesse chariot simu | `30 m / 37,5 s × f / 40 Hz` | `_TranslationGainMetersPerHzSec × f` |
| Butées | 0 et 30 m (collées aux capteurs) | Capteur extrême ± `SimM3EndStopMargin_M` (défaut **0,5**) |
| Position de départ simu | 20 m en dur | `_TranslationPosP1_M` |
| Calculateur machine | inchangé | **inchangé** |

**Fichiers** : `FB_Sim_Translation.st`, `FB_SimBench.st`, `GVL_Simulation.st` · tests `TOOLS/TEST_AUTO_CI` (FB_Sim_Translation, `FB_TestLoopTranslation` : 6 m / 20 m en dur) · gate `G518` réécrit (vérifie que la simu **lit** le gain, au lieu de comparer deux constantes).

**Critères** :
- AC1 Changer en ligne une position `GVL_PERSISTENT` déplace le capteur simulé correspondant.
- AC2 Gain identique → aucun saut de recalage > 5 cm au passage des capteurs (calculateur = vrai).
- AC3 Le chariot peut dépasser de 0,5 m le capteur Trémie / Maintenance avant la butée.
- AC4 Marge 0 + valeurs actuelles → comportement identique à aujourd'hui (non-régression CI).
- AC5 Aucun fichier hors `L_SIMULATION`, tests CI et gates modifié ; G200 PASS.
- AC6 Geste habituel inchangé (joystick, boutons simu).

**Réglage en simu** (en ligne, valeurs persistantes) : Trémie 0 · PV 1,5 · P2 3,5 · P1 5 · Maintenance 10 · gain 0,02.
⚠️ Les valeurs initiales du code `GVL_PERSISTENT` (0/5/15/20/30) ne changent pas : un reset origine les remet.

## 5. 🧪 Tests du chantier (Device + simulateur intégré)

| # | Scénario | On regarde |
|---|---|---|
| T1 | Manuel → Trémie, joystick tenu, 20 Hz | Arrêt net ≈ capteur ? défaut ? |
| T2 | Manuel → P1 | idem |
| T3 | Auto AX14 → Trémie | Continue ? jusqu'à la butée ? benne qui s'ouvre en mouvement ? |
| T4 | Auto AX2 → P1 | idem + passage AX2 → AX3 |
| T5 | Franchissement capteurs (L5) | Le clignotement **ne gêne pas** : 0 défaut, 0 relance, 0 étape sautée |
| T6 | Non-régression bits OFF | Identique à aujourd'hui · geste habituel inchangé |

👉 Acceptation : même mécanique et mêmes réglages en manuel/auto ; décroissance du variateur après retrait de commande ; frein répondant à sa bobine ; balancement secondaire et amorti. Les résultats T1-T6 sont relevés tels quels, sans imposer un dépassement ou un défaut et sans régler le banc pour les provoquer.

## 6. 🛡️ Garde-fous

- Simu active seulement si `SimulationModeActive` + `SimTranslationActive` ; entrée machine = `SEL(HwReal, HwSim)` (`PRG_02_Acquisition.st:450-453`).
- Le simulateur **lit** `GVL_PERSISTENT`, n'écrit jamais `GVL_PERSISTENT` / `GVL_IHM` / `ST_IHM_MANU`.
- `guard:` : gate « aucun POU hors `L_SIMULATION`/PRG_02 ne lit `GVL_Simulation` ni `instSimBench` ».
- Chaque lot : bundle + diff bundle + G200 PASS avant restitution.

## 6bis. ⏸️ Reporté (constaté en essai 2026-10-28)

- 🪝 **Roulis treuils simulé** : `SimWinchCoast_M` = 1,30 m (réglé pour la benne, T419) appliqué aussi à M1 (`FB_SimBench.st:343`) → M1 dépasse la limite haute de 1,3 m (7,5 → 8,8 m). Cible : roulis par axe et par sens, réaliste (M1 montée ≈ 0,5 m, descente ≈ 1 m, à caler sur traces). Retrouver l'origine dans git.
- ✅ Essai auto L0+L1 : position réelle simu 5,297 m quand la position calculée affiche 5,0 → le dépassement auto (~0,3 m) est invisible côté programme (calculateur figé au retrait de la demande).

## 7. 🚫 Écarté

Modelica/TwinBench (gelé) · modèle électrique AC600 · élasticité câbles · rebond élastique butée · bruit aléatoire scan par scan · toute modif `FB_Translation` / `PRG_05` / `PRG_06`.

## 8. 📌 Noté pour le chantier programme (pas maintenant)

- Recalage du calculateur sur **5 capteurs** (PV/P2 compris), l'utilisateur pensait 3 → à trancher. Sur site : mesurer les 5 positions.
- Calculateur figé dès que la demande tombe → dépassement invisible côté machine.
- 2 chemins ferment le frein en aval de `FB_Brake` : coupure Trémie (`PRG_06_Outputs.st:428-450`) et veto d'étape auto (`PRG_05_Translation.st:399-409,700-706`).
- `ArrivalStopConfirmed` non consommé · rampe interne sur la demande (100 % en auto) et non sur la fréquence envoyée · `FB_Brake.DelayMotorDecel` mort.
- Hypothèse défaut frein (non prouvée) : `FB_Brake` croit le frein ouvert tant que sa rampe interne n'est pas finie alors qu'un chemin aval l'a fermé → écart > 1 s → défaut « parfois ».
