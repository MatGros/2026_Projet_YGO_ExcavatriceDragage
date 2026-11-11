# T399 — Feuille de route TwinBench hybride PLC / OpenModelica

Date : 2026-09-27  
Statut : **proposition à valider — aucun développement lancé**

## 1. Décision d'architecture

```text
CODESYS 3.5 / logique PLC
  └─ variables symboliques et sorties finales
       ⇅ passerelle locale horodatée
          ├─ enregistreur / rejeu déterministe
          ├─ OpenModelica (physique unique)
          └─ PySide6/QML (commande, vue, paramètres, traces)
```

| Couche | Responsabilité unique |
|---|---|
| PLC | Séquence, rampes PLC, sécurités, interlocks, frein logique, sélection HwReal/HwSim |
| Passerelle Python | Communication, typage, snapshot, séquence, horodatage, validité, timeout |
| OpenModelica | Moteurs, transmissions, inerties, freins physiques, câbles, benne, capteurs |
| PySide6/QML | Interaction, paramétrage, diagrammes, zoom, traces ; **aucune physique** |

La marque du PLC est secondaire. Le protocole réellement disponible dans le runtime CODESYS reste déterminant.
OPC UA est le candidat prioritaire ; CODESYS Gateway ou une table Modbus typée restent des solutions de repli à instruire.

## 2. Phases et lots candidats

Les références `P0.x` sont des lots candidats, pas encore des tâches actives du catalogue. Chaque lot C2+ recevra son propre contrat au moment de son activation.

| Phase / lot | Statut | Criticité prévue | Résultat attendu | Dépendance / décision |
|---|---|---:|---|---|
| **P0.1 Inventaire runtime CODESYS** | OBLIGATOIRE | C2 | Version runtime, simulation ou cible, OPC UA, Symbol Configuration, licences, certificats, fréquence accessible | Première action |
| **P0.2 Contrat de signaux** | OBLIGATOIRE | C3 | Liste typée PLC→plante et plante→HwSim, unités, causalité, domaine, validité, timeout | Après P0.1 |
| **P0.3 Politique de sûreté de liaison** | OBLIGATOIRE | C3 | États déconnecté/périmé/incohérent, neutralisation, interdiction de hold-last, journal des écritures | Avec P0.2 |
| **P1.1 Modèle M3 granulaire** | OBLIGATOIRE | C2 | Moteur, variateur, rampe, frein, transmission, chariot, 5 capteurs, butées mécaniques | Reprise T314 |
| **P1.2 Paramètres et provenance** | OBLIGATOIRE | C2 | Chaque valeur marquée MESURÉ / CODE PLC / HYPOTHÈSE / À VÉRIFIER / NON MODÉLISÉ | Avant comparaison réel |
| **P1.3 Scénarios et tests M3** | OBLIGATOIRE | C2 | Repos, deux sens, PV, freinage, rebond capteur, approche des butées, perte commande | Après P1.1 |
| **P2.1 Moteur d'exécution omc.exe** | OBLIGATOIRE | C2 | Vérifier, compiler, simuler, arrêter, recharger une variante, remonter les diagnostics | T314 existante |
| **P2.2 Application PySide6/QML** | OBLIGATOIRE | C2 | Joystick, schéma large, réglages, tags courts, états de connexion | Après P2.1 |
| **P2.3 Traces et rejeu** | OBLIGATOIRE | C2 | Acquisition 10 ms, zoom, curseur, événements, export et rejeu déterministe | Après P1.3 |
| **P3.1 Connecteur PLC lecture seule** | CONDITIONNEL | C3 | Lire les vraies variables CODESYS sans écrire dans le PLC | GO après P0.1–P0.3 |
| **P3.2 Mode shadow** | CONDITIONNEL | C3 | Comparer sorties PLC réelles et réponse Modelica sans retour vers le PLC | Après P3.1 et tests de charge |
| **P4.1 Boucle fermée sur runtime virtuel** | CONDITIONNEL | C4 | Injecter une image HwSim complète dans un CODESYS virtualisé | Sorties physiques neutralisées et prouvées |
| **P4.2 Adaptateur HwSim atomique** | CONDITIONNEL | C4 | Écriture par domaine, séquence, timestamp, validité ; jamais de mélange réel/simulé | Nouveau contrat C4 + GO humain |
| **P5.1 Modèle M1/M2 et benne** | OBLIGATOIRE PLUS TARD | C3 | Deux treuils, deux chemins mécaniques, mouflage interne 3:1, benne articulée, câbles et charge | Mesures mécaniques disponibles |
| **P5.2 Calibration M1/M2** | CONDITIONNEL | C3 | Réducteurs, tambours/couches, inerties, frottements, effort, codeurs, asymétrie de charge | Relevés terrain |
| **P6.1 Shadow sur machine réelle** | HYPOTHÈSE | C4 | Observation strictement passive, débit limité, arrêt immédiat sans effet machine | Étude séparée + autorisation |
| **P6.2 Remplacement de SimBench** | HYPOTHÈSE | C4 | Décision seulement après parité complète, rejeu, gates et recette humaine | Par défaut : **NON** |

## 3. Jalons GO / NO-GO

| Jalon | GO si… | NO-GO si… |
|---|---|---|
| J0 — protocole | lecture symbolique stable, types et unités démontrés | protocole/licence inconnus ou accès seulement par adresses opaques non documentées |
| J1 — M3 hors ligne | scénarios déterministes, fréquence/vitesse bornées, hypothèses visibles | physique dupliquée dans l'IHM ou pas temporel lié au rendu graphique |
| J2 — shadow local | perte de liaison détectée, données périmées rejetées, zéro écriture | maintien silencieux de la dernière valeur ou charge PLC non mesurée |
| J3 — boucle virtuelle | runtime explicitement virtuel et sorties physiques prouvées neutralisées | doute sur une sortie réelle, mélange HwReal/HwSim ou redémarrage automatique |
| J4 — M1/M2 | cinématique et paramètres minimaux mesurés | réduction, tambours, mouflage ou comportement de benne encore contradictoires |

## 4. Ordre de réalisation recommandé

1. Exécuter P0.1 à P0.3 et figer le contrat de communication.
2. Reprendre T314 avec M3 seulement : P1 + P2 hors ligne.
3. Valider l'ergonomie et la fidélité sur traces enregistrées.
4. Ajouter P3 en lecture seule si le runtime le permet.
5. Décider séparément si P4 apporte réellement un bénéfice par rapport au SimBench PLC actuel.
6. Étendre ensuite à M1/M2 et à la benne, jamais avant les mesures mécaniques minimales.

## 5. Mesures et informations manquantes

- Runtime CODESYS exact, mode simulation ou automate cible, serveur OPC UA disponible et licencié.
- Liste des symboles réellement publiables et fréquence de lecture soutenable.
- M3 : réduction ou essai déplacement/fréquence, inertie/masse, position physique du frein, temps de réponse, cotes capteurs/butées.
- M1/M2 : réductions, diamètres et couches de tambour, inerties, géométrie de benne, raideur/jeu des câbles, répartition de charge.

Ces inconnues n'empêchent pas l'architecture ni l'IHM, mais interdisent d'appeler le modèle « fidèle au réel ».

## 6. Héritage des travaux existants

- `T314` : conservée comme socle OpenModelica Windows ; reprise après validation de ce plan.
- `T304` : reste en pause, utile seulement comme R&D historique.
- `feature/twinbench-m3-native` : conservée, non fusionnée ; la vue web peut inspirer l'ergonomie mais pas la physique.
- `FB_SimBench` : reste la référence PLC actuelle tant qu'aucun jalon C4 n'autorise autre chose.
