# 📚 Point de Situation : Analyse Fonctionnelle & Spécifications Métier (DOC/AF/)

**Date** : 2026-09-05  
**Auteur / Rôle** : Revue de Cohérence Documentaire & Spécifications  
**Référentiel** : DOC/AF/, DOC/README.md, DOC/STDS/CODE_QUALITY_STANDARDS.md §0

---

## 🧭 1. Cartographie des Spécifications Actives (DOC/AF/)

L'ensemble des documents d'analyse fonctionnelle définit le comportement physique, la cinématique, les flux de commande et les exigences de sécurité machine.

| Document Spécification | Version Active | Rôle & Périmètre Technique | Statut & Alignement Code |
|---|:---:|---|:---:|
| [AF_Partie-01](DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md) | **v2.1** | Analyse fonctionnelle générale, sécurité électrique, chaîne AU & boucle de puissance | ✅ Aligné (Bypass MES v1.4 intégrés) |
| [AF_Partie-02](DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md) | **v3.2** | Architecture globale, répartition des 7 POU (PRG_02 à PRG_07), MainTask 4/20/10ms | ✅ Source unique d'architecture cible |
| [AF_Partie-03](DOC/AF/AF_Partie-03_Contrats_Composants_v2.3.md) | **v2.3** | Modèle de composants POO, contrats Light / Standard, FB_FaultCore, ST_Lifecycle | ✅ Référentiel des interfaces FB |
| [AF_Partie-04](DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md) | **v2.3** | Séquenceur de dragage semi-automatique Grafcet X0..X13, sous-cycles Kobold | ✅ Aligné (Tests CI STruCpp 100%) |
| [AF_Partie-05](DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md) | **v2.1** | Modes de marche manuels, Maintenance N1 (assistée) & N2 (secours / bypass) | ✅ Aligné |
| [AF_Partie-06](DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md) | **v2.4** | Acquisition unique HwReal/HwSim/HwIn, filtrage TOR, détection de défauts bus | ✅ Aligné (PRG_02_Acquisition) |
| [AF_Partie-07](DOC/AF/AF_Partie-07_Interface_IHM_v2.3.md) | **v2.3** | Interface IHM/Supervision, structures ST_*HMI, bannières d'alarmes, lecture seule | ✅ Aligné (PRG_07_Supervision) |
| [AF_Partie-08](DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md) | **v2.5** | Décodage joystick CANopen, gestion homme-mort, armement, zones mortes, paliers | ✅ Aligné (NC-110 & Cfg persistant) |
| [AF_Partie-09](DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md) | **v2.4** | Chaîne codeurs absolus EtherCAT, homing unitaire/conjoint, calcul vitesse glissante 50ms | ✅ Aligné (Preset centre-plage & cible M2) |
| [AF_Partie-10](DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md) | **v2.1** | Régulation levage M1/M2, synchronisme, gestion d'ouverture/fermeture benne | ✅ Aligné (Découplage Décision/Muscle) |
| [AF_Partie-11](DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md) | **v2.3** | Translation chariot M3, variateur AC600 EtherCAT, décodage 5 capteurs de position | ✅ Aligné |
| [AF_Partie-12](DOC/AF/AF_Partie-12_Fonction_Diagnostic_v1.4.md) | **v1.4** | Diagnostic réseaux (CANopen, EtherCAT), surveillance thermique et rotations de phase | ✅ Aligné |
| [AF_Partie-13](DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md) | **v2.5** | Modèle cinématique simulé, émulation capteurs/variateurs, mode banc hors-sol | ✅ Aligné (L_SIMULATION/) |
| [AF_Partie-14](DOC/AF/AF_Partie-14_Fonction_Troubleshooting_v1.4.md) | **v1.4** | Vue de dépannage chronologique, capture d'états d'éjection et traçage inverse | ✅ Aligné (FB_TroubleshootingView) |

---

## 🧪 2. Traçabilité des Points de Validation (TC-Pxx-nnn)

Chaque document d'analyse fonctionnelle intègre une matrice formelle de Cas de Test :
- **Numérotation Immuable** : Format standardisé par pas de 10 (TC-P01-010, TC-P04-020, etc.).
- **Couverture Automatisée** : Les points de type AUTO et AUTO+SITE font l'objet de harnais de simulation et de bancs d'essais TOOLS/TEST_AUTO_CI/.
- **Alignement Réciproque** : Le script G450_check_af_ci_coverage.py et G470_check_tc_uniqueness.py garantissent l'unicité des identifiants et la correspondance exacte entre les exigences textuelles et les assertions de test.

---

## 📌 3. Principes Directeurs Documentaires

1. **Règle de Version Unique Active** : Une seule version _vX.Y d'une analyse fonctionnelle réside sous DOC/AF/. Les versions antérieures sont systématiquement déplacées sous ARCHIVES/Doc/.
2. **Maintenance Automatisée des Liens** : Le script G340_check_doc_links.py garantit que toutes les références croisées (dans le code ST, les contrats et les guides) pointent vers la version active la plus élevée.
