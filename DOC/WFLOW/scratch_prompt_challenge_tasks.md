# Audit et Challenge d'Ingénierie : Lot T127 (Séquenceur Semi-Automatique, Sous-cycles Dive/Extraction, Diagnostic & Fiches Visuelles CI)

## Contexte Machine & Projet
- **Machine** : Excavatrice de dragage en carrière noyée sous CODESYS 3.5 (IEC 61131-3).
- **Équipements** :
  - Treuil M1 (Retenue/Câble de tête) + Treuil M2 (Fermeture/Benne) : moteurs asynchrones avec 4 contacteurs de vitesse (5 paliers de vitesse : P1 à P5).
  - Benne preneuse à commande par différentiel de câble M1/M2.
  - Pont roulant (Translation M3).
  - Capteur de niveau et détection fond Kobold (`M1_M2_KoboldBottomTouch_DI`) alimenté par contacteur dédié (`KoboldContactorCmd`).
  - Poste opérateur : Joystick Y (levage/descente), Joystick X (translation), boutons armement homme-mort (fenêtre 3s).
- **Règles physiques et de sécurité machine strictes** :
  1. Continuité du mouvement : l'opérateur tire le manche et ne doit pas subir de saccade ou de stop intermédiaire lors des transitions d'étapes (fermeture -> décollage -> accélération).
  2. Kobold 4 temps à la volée : alimentation du contacteur à la volée sans arrêt de la descente, qualification immersion $0 \rightarrow 1$, contact fond $1 \rightarrow 0$ avec coupure immédiate du contacteur (anti-chauffe).
  3. Bridage Palier $\le 4$ sous Kobold (Palier 5 strictement interdit pour cause de saturation/bruit).
  4. Bascule de mode sans perte d'étape : passage en Maintenance mémorise l'étape (`PausedState`), neutralise les commandes automatiques, et exige un ordre explicite (`BtnStart`) au retour en Semi-Auto.
  5. Diagnostic Troubleshooting : exposition de la chaîne d'attente opérateur/procédé (`ST_ChainCycleSemiAuto`).

---

## Découpage du Lot T127 à challenger

### 1. T127-A [C2] (Statut : ✅ VALIDÉ)
- Harmonisation interfaces FB_Cycle et sous-cycles avec les profils standards AF-03 §3 (`ST_Lifecycle`, `ST_Fault`). Retrait des sorties doublons obsolètes.

### 2. T127-B [C4] (Statut : ✅ VALIDÉ)
- Logique Grafcet interne X0..X13, auto-test Kobold à la volée, bridage Palier 4, coupure anti-chauffe, enchaînement continu d'extraction, gestion de pause/reprise sur bascule de mode. 14/14 tests STruCpp unitaires validés.

### 3. T127-C [C2] (Statut : ✅ VALIDÉ)
- Diagnostic Troubleshooting chronologique (`ST_ChainCycleSemiAuto` Idx209..216), raccordement `FB_TroubleshootingView`, `PRG_07_Supervision`, bannières IHM, et mise à jour AF_Partie-04 v2.3 / AF_Partie-14 v1.4.

### 4. T127-D [C4] (Statut : ⬜ À FAIRE — bloqué par T165-C2)
- Raccordement final `PRG_03` et encapsulation privée de `instCycleSemiAuto` : éliminer tout accès direct externe à `instCycleSemiAuto`, router via `PRG_03.Data.ReqProgram` et `PRG_03.Data.SequenceState`.

### 5. T127-E [C1] (Statut : ⬜ À FAIRE)
- Campagne de tests automatisés STruCpp CI & Validation non-régression G_CYCLE (exécution récurrente et archivage des rapports de tests unitaires).

### 6. T127-F [C2] (Statut : ⬜ À FAIRE)
- Fiche de test CI visuelle & Animation machine séquence Grafcet Semi-Auto : banc de test interactif avec cinématique carrière noyée complète (profil 2D, treuils, benne, câbles, nappe d'eau, trémie), chronogrammes synchronisés, cycle nominal de bout en bout et injection de défaillances (désynchro treuils -> STABILIZING, Palier 5 sous Kobold, lâcher de manche, bascule maintenance).

---

## Mission du Sous-Agent Expert Automatisme & Safety (Anti-Yes-Man)
1. **Audit critique de la granularité des tâches** : Le découpage est-il optimal, sans trou dans la raquette et sans chevauchement ?
2. **Challenge des scénarios de test et de défaillance (T127-F)** : Quels cas limites physiques ou erreurs opérateur réelles en carrière noyée doivent impérativement être intégrés dans la simulation visuelle ?
3. **Challenge de l'interconnexion PRG_03 (T127-D)** : Quels sont les points de vigilance lors de l'encapsulation privée et du passage par le bus d'arbitrage de requêtes ?
4. **Recommandations concrètes d'amélioration** pour rendre les fiches de tests et le diagnostic dépannage encore plus robustes et intuitifs pour les équipes de mise en service.
