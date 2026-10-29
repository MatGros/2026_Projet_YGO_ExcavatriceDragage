# Consultation d'Ingénierie : Conception Dynamique Réaliste Treuils M1/M2 & Benne (T421)

## 1. Contexte & Données Réelles de Mesure
Sur la machine réelle en carrière noyée (Excavatrice de Dragage), des enregistrements réels scan par scan à 10 ms (fichier `Suivi_86`) ont permis d'extraire les comportements physiques réels suivants lors de la coupure des commandes contacteurs :

1. **Montée Treuil (M1 / M2 levage charge)** :
   - À pleine vitesse ($V_{\text{cut}} = 1.14\,\text{m/s}$) : glissement inertiel mesuré = **`+0.543 m`** en 0.65 s (la gravité freine la charge).
2. **Descente Treuil (M1 / M2 descente gravitaire)** :
   - À pleine vitesse ($V_{\text{cut}} = 1.50\,\text{m/s}$) : glissement inertiel mesuré = **`-1.205 m`** en 1.06 s (le poids et la gravité emportent le grappin).
3. **Basse Vitesse / Jog (Palier 1)** :
   - À petite vitesse ($V_{\text{cut}} = 0.12\,\text{m/s}$) : glissement mesuré = **`+0.021 m`** en 0.24 s (arrêt quasi-immédiat, proportionnel à la vitesse).
4. **Cinématique Benne (Écart relatif $M_2 - M_1$)** :
   - À l'ouverture complète au-dessus de la trémie, la commande coupe avec une anticipation de $1.30\,\text{m}$ ; la mécanique finit sa course sur l'inertie jusqu'à la butée ouverte ($0.0\,\text{m}$).
   - **Exigence stricte exploitant** : la cinématique de benne doit être **rigoureusement identique en commande Manuelle (joystick) et en cycle Automatique (étape AX15B)**. Aucune condition d'étape auto ne doit créer une divergence physique par rapport au mode manuel.

## 2. Architecture Actuelle du Banc de Simulation
- `FB_Sim_Encoder.st` : Modèle de comptage d'impulsions codeur incrémental/absolu.
  Actuellement, il possède une entrée `CoastDistanceM : REAL`. À la retombée de `RelayFwd` et `RelayRev`, il continue d'incrémenter ou décrémenter à la vitesse palier 1 (`MinSpeedMps`) jusqu'à épuiser une réserve de points `CoastPtsLeft = CoastDistanceM * PointsPerRev / CableM_PerRev`.
- `FB_SimBench.st` : Banc global instanciant `instSimEncoderM1` et `instSimEncoderM2`.
  Actuellement, `SimWinchCoast_M` était injecté en dur à $1.30\,\text{m}$ sur M1 et M2, ce qui provoquait l'aberration physique de faire monter M1 de $1.30\,\text{m}$ lors d'un simple arrêt en montée.

## 3. Travail Demandé (Étude & Conception Pure — Aucun code à modifier sur le dépôt)
En tant qu'Expert Senior en Automatisme Industriel et Simulation Temps Réel :
1. **Conception de la loi de décélération / roulis** :
   - Comment modéliser la dissymétrie Montée ($\approx 0.54\,\text{m}$) vs Descente ($\approx 1.20\,\text{m}$) ?
   - Comment garantir la proportionnalité à la vitesse d'approche (pour que le jog s'arrête en quelques centimètres) ?
   - Faut-il intégrer ce calcul directement dans `FB_Sim_Encoder` (ex. calcul dynamique à la coupure selon `SpeedMps` et `MovingDir`) ou le piloter depuis `FB_SimBench` ?
2. **Gestion de l'anticipation de la Benne** :
   - Comment articuler le roulis propre aux treuils de levage et la dynamique d'ouverture/fermeture de benne sans artifice liant le modèle à l'étape AX15B ?
3. **Cas limites et robustesse** :
   - Que se passe-t-il si l'opérateur inverse le sens ou réenclenche le contacteur pendant le glissement ?
   - Comment éviter tout à-coup ou incohérence de vitesse mesurée ?
4. **Proposition d'implémentation ST** :
   - Fournis un schéma d'algorithme clair et les blocs d'implémentation ST recommandés pour `FB_Sim_Encoder` et/ou `FB_SimBench`.
