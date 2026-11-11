# 🏗️ Point de Conformité : Standards du Projet & Base de Code (CODE/ vs STDS/)

**Date** : 2026-09-05  
**Auteur / Rôle** : Contrôle Qualité Logicielle, Architecture & CI/CD  
**Référentiels** : DOC/STDS/CODE_QUALITY_STANDARDS.md, DOC/STDS/NAMING_CONVENTION.md, DOC/STDS/GUIDES/GUIDE_GATES_ET_TESTS_v1.2.md

---

## 🧭 1. Architecture du Code Source (CODE/) & Organisation 7 POU

La base de code automate est organisée selon une décomposition chronologique et fonctionnelle stricte de A_COMMUN à M_MAIN :

`	ext
CODE/
├── A_COMMUN/          --> Types transverses, socle FB_FaultCore, ST_Fault, ST_Lifecycle
├── B_AU_SECURITE/      --> Gestion boucle AU, surveillance arrêts d'urgence physiques
├── C_DIAG_RESEAUX/     --> Diagnostics bus CANopen et EtherCAT
├── D_JOYSTICK/         --> Acquisition, filtrage, décodage paliers et homme-mort
├── E_CODEURS/          --> Chaîne de mesure, homing unitaire/conjoint, vitesse 50ms
├── F_MODES/            --> Sélection et gestion des autorisations de modes de marche
├── G_CYCLE/            --> Séquenceur de dragage Semi-Auto X0..X13, sous-cycles Kobold
├── H_TREUILS_BENNE/    --> Régulation levage M1/M2, synchronisme, cinématique benne
├── I_TRANSLATION/      --> Pilotage chariot M3, variateur AC600, décodage 5 capteurs
├── J_SUPERVISION/      --> Interface IHM, bannières d'alarmes défilantes, ponts persistants
├── K_DEPANNAGE/        --> Vue Troubleshooting pas-à-pas et capture d'éjection
├── L_SIMULATION/       --> Modèle cinématique complet pour tests hors-sol
└── M_MAIN/             --> Orchestration des 7 POU d'exécution (PRG_02 à PRG_07)
`

### Table des 7 POU dans MainTask

| Rang | Programme POU | Périodicité | Responsabilité Unique & Sécurité |
|:---:|---|:---:|---|
| **01** | PRG_02_Acquisition | 4 ms (Rapide) | Frontière unique E/S (HwReal/HwSim/HwIn), qualification codeurs & joystick |
| **02** | PRG_03_Modes_Cycle | 20 ms (Std) | Machines d'état modes & séquenceur Semi-Auto (Décision centrale) |
| **03** | PRG_04_Treuils_Benne| 4 ms (Rapide) | Exécution commandes treuils M1/M2, Safety levage & barrière benne |
| **04** | PRG_05_Translation | 20 ms (Std) | Exécution translation M3, Safety translation & variateur AC600 |
| **05** | PRG_06_Outputs | 4 ms (Rapide) | Barrière finale physique des sorties TOR et gestion coupure PowerCutOff |
| **06** | PRG_07_Supervision | 20 ms (Std) | Lecture seule stricte, bannières IHM, synchronisation persistante GVL |

---

## 📐 2. Respect des Standards Qualité & Nommage

### A. Standards de Déclaration & Encapsulation (CODE_QUALITY_STANDARDS.md)
- **Contrats FB Socle** : Généralisation des profils Light (Enable/Ready) et Standard (Enable/Reset/Ready/Fault: ST_Fault + Lifecycle).
- **Élimination du Code Mort** : Zéro variable orpheline déclarée, respect des règles MISRA-IEC 61131-3.
- **Régions & Lisibilité** : Structuration du code par régions explicites {region " §N ...\} alignées sur les sections des spécifications fonctionnelles.
- **Cartouches d'Entête** : Longueur $\le 15$ lignes, suppression intégrale du journal intime / REX dans les sources .st, utilisation de la whitelist d'émojis CODESYS.

### B. Conventions de Nommage (NAMING_CONVENTION.md)
- **Zéro Notation Hongroise** : Pas de préfixe de type (Flag, Speed), primauté au rôle sémantique.
- **Polarité Positive des Arbitrages (NC-100)** : Tout signal d'autorisation répond à la règle positive (TRUE = autorisé, FALSE = bloqué : *Permit, *Allowed).
- **Typage DUT Propriétaire (NC-110)** : Format ST_fb<NomFb>_<Rôle> pour toute structure privée d'un bloc.
- **Suffixes d'Unités Normalisés (NC-030)** : Utilisation systématique de _M, _Pct, _Hz, _Ms, _Mps.

---

## 🛡️ 3. Bilan de l'Outillage de Validation & Portails Mécaniques (Gates)

La suite de tests et de vérifications mécaniques (un_all_gates.py) assure un contrôle systématique sur 4 paliers :

1. **Palier A (Bloc Isolé)** : G100 (Style de code) & G110 (Règles de nommage NC-010..070).
2. **Palier B (Liaison & Câblage)** : G200 (Vérification de liaison bloquante — 0 erreur de câblage sur le bundle) & G210.
3. **Palier C (Structure & Bundle XML)** : G300 à G493 (Persistance GVL, absence de collision de noms HW G350, syntaxe PLCopenXML, 100% tests automatisés CI).
4. **Palier D (Compilation Réelle)** : Validation syntaxique et d'import CODESYS 3.5.

**Résultat Global** : Le bundle CODE_XML/CODE_Bundle.xml est synchronisé et intègre 100% des briques logiques dans le strict respect de l'architecture cible.
