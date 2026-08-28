# Préambule obligatoire — sous-agent Ollama
Automate CODESYS 3.5, machine de dragage en carrière noyée.
Sécurité machine réelle. Expert Senior Automatisme & Rédaction Spécifications Fonctionnelles. Style TDAH-Friendly. Réponds en français. Zéro blabla.

---

# MISSION D'ALIGNEMENT DOCUMENTAIRE : AF-02, AF-04, AF-10

## 1. Contexte de la décision d'architecture
Dans le cadre du lot T166, nous avons centralisé **toutes les décisions de cycle et d'assistances de dragage** dans `PRG_03_Modes_Cycle` :
- `PRG_03_Modes_Cycle` instancie désormais :
  - `FB_Modes` (Arbitrage des modes machine)
  - `FB_Cycle` (Séquenceur Maître semi-automatique X0..X13)
  - `FB_DiveSearch` (Assistance plongée et recherche fond Kobold)
  - `FB_ExtractionSequence` (Séquence extraction matière et décollage)
- `PRG_04_Treuils_Benne` est déchargé des instances `FB_DiveSearch` et `FB_ExtractionSequence`. Il conserve sa responsabilité de **muscle et sécurité physique** : régulation vitesses/paliers treuils M1/M2, synchronisation `FB_WinchSync`, commande benne `FB_Bucket`, sécurités treuils `FB_Safety_Winch` et barrières finales.
- `PRG_03` publie toutes ses demandes sur `Data : ST_ModesCycleInterPrg` (`Data.Auth`, `Data.ReqProgram.ReqBucket`, `Data.SequenceState`).

## 2. Travail demandé
Rédige les propositions de mise à jour textuelle exactes pour les 3 documents d'analyse fonctionnelle :

1. **`AF_Partie-02_Architecture_Programme_v3.2.md`** :
   - Mettre à jour le tableau des 7 PRG (§3 Responsabilités) pour refléter que `PRG_03` porte tous les cycles (`FB_Cycle`, `FB_DiveSearch`, `FB_ExtractionSequence`) et que `PRG_04` est dédié au pilotage treuils/benne/synchro/safety.
   - Mettre à jour la section `PRG_03_Modes_Cycle` et `PRG_04_Treuils_Benne` pour acter le flux `ReqProgram.ReqBucket` et les retours N-1.

2. **`AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md`** :
   - Mettre à jour le rôle et périmètre : `FB_DiveSearch` et `FB_ExtractionSequence` sont des briques de cycle transverses rattachées opérationnellement à `PRG_03_Modes_Cycle`.
   - Préciser la transmission des commandes vers `PRG_04` via le bus `ReqProgram`.

3. **`AF_Partie-10_Fonction_Winch_v2.1.md`** :
   - Mettre à jour le rôle et la table des composants de `PRG_04` pour retirer l'instanciation directe de DiveSearch/Extraction, tout en précisant que `PRG_04` arbitre et applique les requêtes benne et Kobold reçues de `PRG_03.Data.ReqProgram`.

Fournis des blocs markdown prêts à l'intégration, concis, denses, conformes à la norme documentaire du projet (zéro perte d'information technique, TDAH-friendly).
