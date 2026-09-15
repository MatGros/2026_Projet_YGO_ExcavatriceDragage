# 📏 Procédure d'Étalonnage Odométrie & Cotes Capteurs M3 (Tâche T301)

> **Document guide / fiche de terrain**  
> **Composant concerné** : [`FB_Translation_PositionEstimator.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st)  
> **Source de configuration** : [`GVL_PERSISTENT.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/GVL_PERSISTENT.st)  
> **Tâche associée** : `T301` (Criticité C1 — annexe / mise en service)

---

## 🧭 1. Conventions d'Axe & Point Zéro Machine

L'axe de translation M3 est orienté selon la convention physique validée (REX 2026-08-21, [`AF_Partie-11 §4`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/AF/AF_Partie-11_Fonction_Translation_v2.4.md#L396)) :

- **Origine 0.00 m = TRÉMIE (Extrême gauche de la digue)**.
- **Extrémité ~30.00 m = MAINTENANCE (Extrême droite de la digue)**.
- **Sens de déplacement** :
  - **Sens `+1` (Fwd)** : Translation **vers la Trémie** ➔ la position métrique **décroît** vers 0.00 m.
  - **Sens `-1` (Rev)** : Translation **vers la Maintenance** ➔ la position métrique **croît** vers 30.00 m.

---

## 📍 2. Mesure & Calibrage des Cotes Réelles des 5 Capteurs

Les 5 capteurs inductifs sont répartis le long de la voie de roulement. À chaque détection d'un capteur, `FB_Translation_PositionEstimator` recale immédiatement sa position estimée sur la cote persistée.

### Relevé des cotes physiques au sol
Mesurer au décamètre ruban ou au télémètre laser la distance de chaque capteur par rapport au contact mécanique Trémie (0.00 m) :

| Capteur physique | Rôle fonctionnel | Valeur théorique actuelle | Cote réelle mesurée (m) | Variable dans `GVL_PERSISTENT.st` |
|---|---|---|---|---|
| **Trémie** | Butée fin de course gauche | `0.0 m` | **0.00 m** (Référence fixe) | `_TranslationPosTremie_M` |
| **PV** | Ralentissement approche Trémie | `5.0 m` | *[ À relever ]* | `_TranslationPosPV_M` |
| **P2** | Point intermédiaire | `15.0 m` | *[ À relever ]* | `_TranslationPosP2_M` |
| **P1** | Ralentissement Maintenance / Arrêt P1 | `20.0 m` | *[ À relever ]* | `_TranslationPosP1_M` |
| **Maintenance** | Butée fin de course droite | `30.0 m` | *[ À relever ]* | `_TranslationPosMaintenance_M` |

---

## ⏱️ 3. Étalonnage du Ratio Fréquence / Déplacement (`GainMetersPerHzSec`)

### Problématique
Actuellement, le gain vaut `_TranslationGainMetersPerHzSec := 0.008333;` (m/s par Hz).  
Il a été calculé sur une base théorique :  
$$50\text{ Hz} \times 0.008333 = 0.4166\text{ m/s} \quad (\approx 25\text{ m/min})$$  
Selon le diamètre réel des galets de roulement, le rapport du réducteur et le glissement mécanique, ce ratio peut dériver de 5 à 15 % par rapport à la vitesse réelle du pont.

### Méthode d'étalonnage chrono-cinématique sur machine
1. Positionner le pont à l'arrêt sur un repère franc (ex: capteur Trémie ou P2).
2. Lancer une translation en régime stabilisé à **$F = 50.0\text{ Hz}$**.
3. Chronométrer le temps $T$ (en secondes) nécessaire pour parcourir une distance connue $\Delta L$ (ex. entre Trémie et P2, soit environ 15 m réels).
4. Calculer la vitesse réelle :
   $$V_{mes} = \frac{\Delta L}{T} \quad (\text{en m/s})$$
5. Calculer le nouveau gain d'odométrie :
   $$\text{Nouveau Gain} = \frac{V_{mes}}{50.0\text{ Hz}} = \frac{\Delta L}{T \times 50.0}$$

### Exemple chiffré :
- Si le pont parcourt $\Delta L = 15.0\text{ m}$ en $T = 33.0\text{ s}$ à 50.0 Hz :
  - $V_{mes} = 15.0 / 33.0 = 0.4545\text{ m/s}$
  - $\text{Gain} = 0.4545 / 50.0 = \mathbf{0.009091\text{ m/s/Hz}}$
- Modifier dans [`CODE/GVL_PERSISTENT.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/GVL_PERSISTENT.st#L109) :
  ```pascal
  _TranslationGainMetersPerHzSec : REAL := 0.009091; // Ajusté après étalonnage du JJ/MM/AAAA
  ```

---

## 🎯 4. Résultat attendu
Une fois le gain ajusté et les vraies cotes des capteurs renseignées :
- L'odométrie calculée par l'estimateur correspond fidèlement au déplacement réel du pont.
- Lors du franchissement d'un capteur inductif, le recalage ne provoque plus de "saut" visible sur l'IHM (l'écart entre position estimée et position capteur devient quasi nul).
