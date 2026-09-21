# 📋 AUDIT TECHNIQUE T360 — CONFRONTATION TRACE SUIVI_74, RECALAGE T333 & RATIO ODOMÉTRIQUE M3

**Date d'audit** : 21 Septembre 2026  
**Auteur** : Antigravity (Expert Senior Automatisme Industriel, Sécurité Machine ISO 13849 & CI/CD)  
**Référence Tâche** : T360 (liée à T333, T300, T301)  
**Fichiers analysés** :
- Trace binaire : [`TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_74_SIMU_MAINTN1_M3_TestSim_20260920.trace`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_74_SIMU_MAINTN1_M3_TestSim_20260920.trace)
- CSV converti : [`TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_74_wide_fresh.csv`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_74_wide_fresh.csv) (4612 échantillons, 48.818 s)
- Code ST Estimateur : [`CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st)
- Code ST Simulation : [`CODE/L_SIMULATION/FB_Sim_Translation.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/L_SIMULATION/FB_Sim_Translation.st)
- Persistance : [`CODE/GVL_PERSISTENT.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/GVL_PERSISTENT.st)

---

## Executive Summary & Verdicts Clés

| Question du Brief | Verdict | Preuve Chiffrée / Justification |
|---|:---:|---|
| **1. Le correctif T333 (recalage 2 sens) fonctionne-t-il ?** | **OUI (100% Validé)** | Recalage confirmé sur **fronts montants** à l'aller (P2, PV, Trémie) et sur **fronts descendants** au retour (Trémie, PV, P2, P1). Sans T333, le retour ne recalait jamais. |
| **2. Ampleur des sauts de position sur la trace `Suivi_74` ?** | **4.53 m à 9.11 m** | Réfutation de l'hypothèse initiale ("1 à 3 mm"). Les sauts sont majeurs à chaque capteur. |
| **3. Cause racine des sauts de 4.5 m à 9 m ?** | **Incompatibilité Échelle Simu vs Automate** | Le simulateur applique `FullTravelTimeS = 8.0 s` (ratio $0.09375\text{ m/(Hz}\cdot\text{s)}$), soit **11.25 fois plus vite** que le gain automate ($0.008333\text{ m/(Hz}\cdot\text{s)}$). L'estimateur est en retard constant, et T333 comble brutalement l'écart à chaque capteur. |
| **4. Historique de `_TranslationGainMetersPerHzSec` ?** | **Créé le 05/08/2026, Inchangé** | Commit initial [`eb40478a`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/GVL_PERSISTENT.st#L109) par Mathieu Gros. Aucune dérive dans l'historique Git. |
| **5. Dérive théorique pour 1% d'erreur de ratio ?** | **200 mm sur 20 m (Trémie $\rightarrow$ P1)** | 10 cm de dérive atteinte après **10.0 m** de déplacement ininterrompu (qui correspond pile au segment le plus long PV-P2). |

---

## 1. Analyse Cinématique Détaillée de la Trace `Suivi_74`

La trace `Suivi_74_SIMU_MAINTN1_M3_TestSim_20260920.trace` a été convertie en format tabulaire large ([`Suivi_74_wide_fresh.csv`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_74_wide_fresh.csv)) :
- **Nombre d'échantillons** : 4 612 points.
- **Plage temporelle** : $t = 3\text{ ms}$ à $t = 48 818\text{ ms}$ ($\Delta t_{\text{total}} = 48.815\text{ s}$).
- **Fréquence d'échantillonnage réelle** : $dt_{\text{moyen}} = 10.59\text{ ms}$ ($\sigma = 2.1\text{ ms}$), synchrone avec la tâche 10 ms (`MainTask`).

### Chronologie des Événements et Déplacements

```text
       Aller (Sens Trémie, JoyX = +100, x : 20m ➔ 0m)
P1 (20m) ──────────────► P2 (15m) ──────────────► PV (5m) ──────────────► Trémie (0m)
 [6 481 ms]              [8 532 ms]              [11 868 ms]             [15 860 ms]
 Recal: +0.026m          Recal: -4.531m          Recal: -9.115m          Recal: -4.591m
 (R_TRIG P1)             (R_TRIG P2)             (R_TRIG PV)             (R_TRIG Trémie)

       Retour (Sens Maintenance, JoyX = -100, x : 0m ➔ 20m)
Trémie (0m) ────────────► PV (5m) ──────────────► P2 (15m) ─────────────► P1 (20m)
 [23 656 ms]             [25 988 ms]             [29 325 ms]             [33 370 ms]
 Recal: +0.011m          Recal: +4.528m          Recal: +9.115m          Recal: +4.586m
 (F_TRIG Trémie)         (F_TRIG PV)             (F_TRIG P2)             (F_TRIG P1)
```

---

## 2. Validation Formelle du Recalage T333 dans les Deux Sens

Le correctif **T333** ([`FB_Translation_PositionEstimator.st:89-130`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st#L89-L130)) a introduit l'écoute des fronts descendants (`TrigDnTremie`, `TrigDnPV`, `TrigDnP2`, `TrigDnP1`, `TrigDnMaintenance`) pour gérer la topologie en **mot thermomètre cumulatif** :
- Vers la Trémie (position décroissante) : les capteurs basculent `0 ➔ 1` $\rightarrow$ Front montant.
- Vers la Maintenance (position croissante) : les capteurs se libèrent `1 ➔ 0` $\rightarrow$ Front descendant.

### A. Trajet Aller (P1 20 m $\rightarrow$ Trémie 0 m) — Fronts Montants

| Horodatage | Événement Capteur | Déclencheur ST | $Pos_{\text{avant}}$ | $Pos_{\text{après}}$ | Saut $\Delta x$ | Fréquence M3 | JoyX |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **6 481 ms** | `M3_PosP1_DI` : 0 $\rightarrow$ 1 | `TrigP1.Q` | 19.973 m | 19.999 m | +0.026 m | 15.30 Hz | +82 |
| **8 532 ms** | `M3_PosPVP2_DI` : 0 $\rightarrow$ 1 | `TrigP2.Q` | 19.528 m | 14.997 m | **-4.531 m** | 31.98 Hz | +100 |
| **11 868 ms** | `M3_PosPV_DI` : 0 $\rightarrow$ 1 | `TrigPV.Q` | 14.113 m | 4.997 m | **-9.115 m** | 31.89 Hz | +100 |
| **15 860 ms** | `M3_PosTremie_DI` : 0 $\rightarrow$ 1 | `TrigTremie.Q` | 4.590 m | -0.001 m | **-4.591 m** | 7.96 Hz | +100 |

### B. Trajet Retour (Trémie 0 m $\rightarrow$ P1 20 m) — Fronts Descendants (T333)

| Horodatage | Événement Capteur | Déclencheur ST | $Pos_{\text{avant}}$ | $Pos_{\text{après}}$ | Saut $\Delta x$ | Fréquence M3 | JoyX |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **23 656 ms** | `M3_PosTremie_DI` : 1 $\rightarrow$ 0 | `TrigDnTremie.Q` | -0.011 m | +0.001 m | +0.011 m | 7.30 Hz | -49 |
| **25 988 ms** | `M3_PosPV_DI` : 1 $\rightarrow$ 0 | `TrigDnPV.Q` | 0.475 m | 5.003 m | **+4.528 m** | 31.91 Hz | -100 |
| **29 325 ms** | `M3_PosPVP2_DI` : 1 $\rightarrow$ 0 | `TrigDnP2.Q` | 5.888 m | 15.003 m | **+9.115 m** | 31.92 Hz | -100 |
| **33 370 ms** | `M3_PosP1_DI` : 1 $\rightarrow$ 0 | `TrigDnP1.Q` | 15.415 m | 20.001 m | **+4.586 m** | 8.00 Hz | -100 |

### 🎯 Preuve irréfutable du succès T333 :
- **Sans T333** : Aucun des fronts `TrigDn*` n'existait dans le code. Sur le trajet retour, la position estimée à $t = 33 370\text{ ms}$ aurait atteint seulement **1.78 m** au lieu de 20.0 m !
- **Avec T333** : Les fronts descendants sont interceptés avec un temps de réponse de 1 cycle (10 ms), recalant impeccablement la position aux repères physiques 5.0 m, 15.0 m et 20.0 m.

---

## 3. Réfutation de l'Hypothèse "1 à 3 mm" & Explication Physique des Sauts

L'avant-brief supposait : *"l'écart entre la position estimée juste avant recalage et la position théorique du capteur est de l'ordre de 1 à 3 mm"*.

**CETTE AFFIRMATION EST FAUSSE SUR CETTE TRACE**. Les sauts mesurés sont de **4.53 m, 9.11 m et 4.59 m**.

### Démonstration Mathématique de la Cause Racine :

1. **Dans le modèle de simulation ([`FB_Sim_Translation.st:9, 228-230`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/L_SIMULATION/FB_Sim_Translation.st#L9))** :
   $$\text{SpeedAt40Hz} = \frac{\text{CST\_PositionAtMaintenance}}{\text{FullTravelTimeS}} = \frac{30.0\text{ m}}{8.0\text{ s}} = 3.75\text{ m/s}$$
   $$\text{Ratio}_{\text{simulation}} = \frac{3.75\text{ m/s}}{40.0\text{ Hz}} = \mathbf{0.09375\text{ m/(Hz}\cdot\text{s)}}$$

2. **Dans l'estimateur odométrique automate ([`GVL_PERSISTENT.st:109`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/GVL_PERSISTENT.st#L109))** :
   $$\text{Ratio}_{\text{automate}} = \mathbf{0.008333\text{ m/(Hz}\cdot\text{s)}}\quad (\text{soit } 0.416\text{ m/s à } 50\text{ Hz})$$

3. **Rapport cinématique Simu / Automate** :
   $$\frac{\text{Ratio}_{\text{simulation}}}{\text{Ratio}_{\text{automate}}} = \frac{0.09375}{0.008333} = \mathbf{11.25}$$

4. **Intégration sur le tronçon P2 $\rightarrow$ PV (Distance = 10.0 m)** :
   - Le chariot simulé roule à $f \approx 31.9\text{ Hz}$ pendant $\Delta t = 3.336\text{ s}$ :
     $$\int f \, dt = 106.42\text{ Hz}\cdot\text{s}$$
   - L'estimateur PLC calcule :
     $$\Delta x_{\text{estimé}} = 106.42 \times 0.008333 = \mathbf{0.887\text{ m}}$$
   - Le simulateur a déplacé le chariot physique de :
     $$\Delta x_{\text{simu}} = 106.42 \times 0.09375 = \mathbf{9.977\text{ m}} \approx 10.0\text{ m}$$
   - Lorsque le capteur PV commute à 5.0 m, l'automate croyait n'avoir avancé que de 0.887 m (soit $15.0 - 0.887 = 14.113\text{ m}$).
   - **T333 force le recalage absolu** :
     $$\text{Saut} = 5.000 - 14.113 = \mathbf{-9.113\text{ m}}\quad (\text{mesuré : } -9.115\text{ m})$$

> **Conclusion Senior Ingénierie** : Ce saut de 9 mètres n'est **ni une dérive physique réelle ni un bug de l'estimateur**. C'est le résultat d'un banc de simulation configuré pour rouler 11 fois trop vite (`FullTravelTimeS = 8.0 s` au lieu des ~72-90 s de la vraie machine) face à un estimateur configuré avec les constantes réelles de la carrière.

---

## 4. Historique Git de `GVL_PERSISTENT._TranslationGainMetersPerHzSec`

Vérification exhaustive de la généalogie du gain odométrique :
- **Date de création** : Mercredi 5 Août 2026 à 16:49:10 +02:00
- **Commit d'introduction** : [`eb40478a`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/GVL_PERSISTENT.st#L109) (*feat(safety): FB_Safety_Winch M1/M2 instancié + estimateur position translation*)
- **Auteur** : Mathieu Gros (`mathieu.gros@gmail.com`)
- **Évolution postérieure** : **AUCUNE**. La ligne `_TranslationGainMetersPerHzSec : REAL := 0.008333;` n'a jamais subi la moindre modification dans tout l'arbre Git depuis sa création.

---

## 5. Calcul Théorique de Dérive Odométrique (Sensibilité à 1%)

Sur la machine réelle en carrière, l'odométrie est sensible au diamètre réel des galets, à la pression mécanique et à l'usure :

Soit une erreur relative de gain $\epsilon = 1\% = 0.01$ :

1. **Sur une course complète Trémie $\rightarrow$ P1 ($D = 20.0\text{ m}$)** :
   $$\Delta x_{\text{dérive}} = \epsilon \times D = 0.01 \times 20.0\text{ m} = \mathbf{0.200\text{ m}} = \mathbf{200\text{ mm}} = \mathbf{20\text{ cm}}$$

2. **Distance sans capteur pour atteindre une dérive de 10 cm ($\Delta x = 0.100\text{ m}$)** :
   $$D_{\text{10cm}} = \frac{\Delta x}{\epsilon} = \frac{0.100\text{ m}}{0.01} = \mathbf{10.0\text{ m}}$$

> **Remarque Architecture Machine** :
> L'intervalle capteur maximal sur la voie est précisément entre le capteur **PV (5.0 m)** et le capteur **P2 (15.0 m)**, soit exactement **10.0 mètres**.
> En conséquence, même avec une erreur de calibrage odométrique de 1% sur le terrain, **la dérive maximale entre deux recalages consécutifs ne dépassera jamais 100 mm (10 cm)** avant que le capteur suivant ne vienne corriger la position estimée.

---

## 6. Vérification de Non-Régression & Clôture

- **Modification de `CODE/`** : `git status --short -- CODE/` $\rightarrow$ **0 fichier modifié**.
- **Contrat de tâche** : [`TASK_CONTRACT_T360_TRACE_RATIO_ESTIMATEUR_M3.yaml`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T360_TRACE_RATIO_ESTIMATEUR_M3.yaml) validé conforme (`check_task_contract.py --release` : **PASS, 0 erreur, 0 avertissement**).
- **Statut T360** : Validé et clôturé.
