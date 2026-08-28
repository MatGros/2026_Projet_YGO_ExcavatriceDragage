# MISSION : RE-SPÉCIFICATION FORMELLE & ARCHITECTURE DES SÉQUENCES GRAFCET DIVE_SEARCH ET EXTRACTION

Tu es l'expert senior en Automatisme Industriel, Sécurité Machine (ISO 13849) et Régulation Treuils de Carrière.
Ta mission est de cadrer, modéliser sous forme de Grafcet rigoureux (étapes, actions, réceptivités, sécurités de repli, diagnostics) les deux briques critiques du cycle semi-automatique :
1. `FB_DiveSearch` (Recherche du fond de gravière assistée par capteur Kobold)
2. `FB_ExtractionSequence` (Fermeture benne, décollement et remontée avec palier de contrôle)

---

## 📊 DONNÉES DE TERRAIN & MESURES PHYSIQUES RÉELLES (Plongée Kobold)

Voici l'enregistrement chronologique réel d'une plongée typique avec Kobold :
- t = 44.0 à 45.8s : Palier haut initial fixe (+7.00 m), Kobold = 0 (désactivé hors d'eau).
- t = 46.0s : Commande d'activation contacteur Kobold (+7.00 m), signal Kobold passe à 1 (capteur alimenté & sain).
- t = 46.2 à 47.0s : Amorçage & accélération descente (+6.95 m -> +5.90 m, vitesse -0.25 m/s à -2.25 m/s).
- t = 47.2 à 50.2s : Descente continue à vitesse nominale régulée (-3.5 m/s, passage de +5.20 m à -5.30 m).
- t = 50.4 à 51.0s : Amorçage décélération / approche du fond (-5.75 m à -6.28 m, vitesse -2.25 m/s à -0.4 m/s).
- t = 51.2s : Détection contact fond de gravière (Signal Kobold passe de 1 à 0 sur front descendant à -6.30 m). Fin de commande et stabilisation.
- t = 51.4s : Arrêt stabilisé (-6.30 m), Kobold retombe à 0 (coupure alimentation pour éviter surchauffe).

---

## ⚠️ CONTRAINTES PHYSIQUES & SÉCURITÉS IMPÉRATIVES

1. **Règle Palier Vitesse & Contacteurs (Limitation dynamique)** :
   - Pour que la détection Kobold soit physiquement opérationnelle (immunité perturbations / dynamique mécanique), la vitesse de descente DOIT impérativement être bridée au **Palier 4 (3 contacteurs actifs)** maximum.
   - Le **Palier 5 (4 contacteurs actifs)** est STRICTEMENT INTERDIT lors d'une recherche Kobold.
   - Si la vitesse ou la consigne dépasse le Palier 4 au moment d'activer le Kobold -> Bloquer la séquence avec alarme explicite (*"Mesure Kobold impossible : vitesse trop élevée / Palier 5 interdit"*).

2. **Règle Thermique & Test dynamique 4 temps du Kobold** :
   - Le capteur Kobold chauffe rapidement sous tension permanente dans l'air.
   - Activation conditionnée à une altimétrie paramétrable (`CfgKoboldActivationDepthM`, par défaut proche du plan d'eau ~ 0.0 m).
   - Test dynamique en 4 temps :
     * **Temps 0 (Repos/Sécurité)** : Avant activation, vérifier DI = 0 (pas de collage contact).
     * **Temps 1 (Mise sous tension & Auto-test)** : Activer contacteur Kobold (`KoboldContactorCmd := TRUE`). Attendre tempo T081 (ex. 150-300 ms).
     * **Temps 2 (Qualification Capteur)** : Vérifier que DI passe à 1 (`KoboldBottomTouch = 1`). Si pas de transition 0->1 avant timeout -> Défaut alimentation/capteur Kobold, blocage immédiat.
     * **Temps 3 (Recherche & Détection Fond)** : Descente en Palier <= 4. Dès contact fond -> DI passe de 1 à 0 (front descendant) -> Contact fond avéré ! Coupure immédiate du contacteur Kobold pour protection thermique.

3. **Règle de Relâchement / Interruption Opérateur (Repli obligatoire)** :
   - Si l'opérateur relâche le joystick en cours de plongée : arrêt immédiat des treuils (maintien sécurité).
   - Si l'interruption a lieu après activation du Kobold ou en dessous du seuil d'eau sécurisé : INTERDICTION de repartir directement en descente (risque de collision aveugle avec le fond sans recalage).
   - Protocole de repli imposé : Exiger une remontée benne fermée jusqu'à une altimétrie de dégagement (`CfgSafeReentryDepthM`) avant d'autoriser une nouvelle tentative de plongée.

4. **Séquence d'Extraction (`FB_ExtractionSequence`)** :
   - Fermeture benne en fond de fouille (surveillance effort / temps de fermeture).
   - Décollage maîtrisé avec palier de contrôle à basse vitesse pour vérifier la stabilisation, le centrage de charge et l'absence de surtension/écart codeurs M1/M2.
   - Transition vers la remontée nominale vers la surface.

---

## 🎯 LIVRABLES ATTENDUS DE TA REVUE

Fournis une analyse technique et une spécification complète :
1. **Modélisation Grafcet détaillée de `FB_DiveSearch`** :
   - Énumération des états (`E_DiveSearchState`).
   - Pour chaque étape : Actions commandées, Réceptivités de transition, Temporisations associées (T081, T082, timeouts).
   - Arbre des causes de blocage et repli vers l'étape de remontée de sécurité.
2. **Modélisation Grafcet détaillée de `FB_ExtractionSequence`** :
   - Énumération des états (`E_ExtractionSequenceState`).
   - Étapes de fermeture, décollage, palier de contrôle, remontée nominale.
3. **Tableau des Interfaces IHM & Diagnostic Troubleshooting** :
   - Messages pour le bandeau IHM (`OperatorActionId`, `OperatorAction`, `WaitingForOperator`, `WaitingForProcess`).
   - Champs requis pour la vue dépannage `ST_ChainDiveSearch` et `ST_ChainExtractionSequence`.
