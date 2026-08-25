# 🎯 Design — Table des Fonctions dans les documents AF (v0.2 — convention finalisée)

📅 2026-08-25 · 🧑‍💻 T153-B · Intègre les 5 conditions du challenge indépendant (v0.1 §🕵️) +
tranche Q-TF1 à Q-TF6. v0.1 conservée telle quelle (historique, non écrasée).
🚦 Prérequis T153-A (resynchro AF-08) : **fait** — voir `DOC/AF/AF_Partie-08_Fonction_Joystick_v2.3.md`.

## ✅ Décisions actées (Q-TF1 à Q-TF6)

| # | Décision |
|---|---|
| **Q-TF1** | Pilote unique = **AF-08** (déjà designée en v0.1, resynchronisée par T153-A). Rétrofit des autres AF = chantier ultérieur distinct, non lancé ici. |
| **Q-TF2** | Criticité **au cas par cas, jamais héritée mécaniquement du FB porteur** — un FB par ailleurs critique peut porter une fonction non-sécurité (ex. calibration dans `FB_Joystick`). Justification écrite dans la colonne `Description` si la criticité de la fonction diffère de l'intuition portée par son FB. |
| **Q-TF3** | Outillage **livré avec le pilote** (T153-C), pas différé — condition 4 du challenge. |
| **Q-TF4** | `Statut` saisi à la main **tant que l'outillage n'existe pas** ; dès que `extract_functions_matrix.py` (T153-C) est disponible, le champ devient **dérivé automatiquement** par croisement `Réalisée par`/`TC couvrants` — la saisie manuelle actuelle n'est qu'un pont vers l'automatisation, pas une cible durable. |
| **Q-TF5** | `Réalisée par` élargi à **`FB` / `PRG` / `gate`** (voir format §1 ci-dessous) — condition 2. |
| **Q-TF6** | Domaines **multi-fiches** (AF-09+, une fiche par FB) : la Table des fonctions vit **dans chaque sous-fiche**, pas au niveau chapô — chaque sous-fiche reste propriétaire unique de sa plage `TC-Pxx-*` (pattern déjà en place, ne pas le casser). Le chapô (`AF_Partie-NN_vX.Y.md`) garde un simple renvoi tabulaire "Fiche → ID plage F" comme il le fait déjà pour les TC (`AF_Partie-10 §Points de validation`, table `Fiche | TC couverts`). AF-08 (mono-fiche) n'est pas concernée par cette règle — la table y vit directement dans le document unique. |

## 💡 Proposition finalisée

### 1. Emplacement — fusion avec §1 « Rôle et périmètre » (condition 5)

**Pas de nouvelle section séparée.** La Table des fonctions **remplace/étend** la sous-section
prose de §1 qui listait déjà Entrée/Sortie/Fait/Ne fait pas — ces informations deviennent des
colonnes de la table plutôt qu'un tableau séparé qui risque de diverger. §1 garde une phrase
d'intro (rôle en une ligne) puis enchaîne directement sur la table.

Placement dans le document : §1, **avant** « 🧪 Points de validation » (qui reste une section à
part — la Table catalogue les fonctions, les TC les valident, ce sont deux artefacts distincts
avec une relation many-to-many, pas une fusion des deux).

### 2. Format de la table

| Colonne | Contenu |
|---|---|
| `ID` | `F<NN>.<seq>` — `NN` = numéro de Partie AF, `seq` = compteur `01`, `02`… plat, sans catégorisation a priori |
| `Fonction` | Nom court, verbe d'action |
| `Description` | 1-3 phrases, complètes (toutes les entrées/conditions pertinentes citées — voir défauts v0.1 ci-dessous) |
| `Réalisée par` | 🆕 **`FB` / `PRG` / `gate`** — ex. `FB_Joystick`, ou `PRG_04_Treuils_Benne` (gate câblé en PRG, pas dans un FB, cf. `TC-P08-008`) |
| `Criticité` | `C0`-`C4` (échelle `TASKS.yaml`), au cas par cas (Q-TF2) |
| `TC couvrants` | Liste `TC-Pxx-nnn` — **un TC ne peut apparaître que sur une seule fonction** sauf note explicite justifiant le partage (correction du défaut F08.02/F08.06 v0.1) |
| `Statut` | ✅/⚠️/❌ — manuel jusqu'à T153-C, puis dérivé (Q-TF4) |

### 3. Exemple corrigé — AF-08 Joystick (v2.1, post-T153-A)

Corrections vs l'exemple v0.1 : F08.05 reste le trou de sécurité connu (Q1, non refermé ici),
F08.03/04 enrichies (ArmingPermit, DeadmanArmGraceTime), F08.07 inclut TC-P08-009/010, F08.02 ne
partage plus TC-P08-007 avec F08.06, et **F08.08 ajoutée** pour représenter `TC-P08-008` (gate
`PRG`, pas `FB` — résout la limite structurelle trouvée par le challenge).

| ID | Fonction | Description | Réalisée par | Criticité | TC couvrants | Statut |
|---|---|---|---|---|---|---|
| `F08.01` | Acquérir les axes bruts + bouton | Lit `RawX`/`RawY`/`RawButton` depuis le bus CANopen (ou l'image simulée) | `FB_Joystick` | C2 | — | ❌ |
| `F08.02` | Mettre à l'échelle proportionnellement | Convertit le compte brut ADC en % signé ±100, avec deadband centrée sur le neutre persistant | `FB_AxisScale` | C2 | `TC-P08-014` | ✅ |
| `F08.03` | Armer l'homme-mort par maintien | Appui continu `DeadmanArmHoldTime` (100ms) **et** `ArmingPermit=TRUE` au terme du maintien | `FB_Joystick` | **C4** | `TC-P08-002` | ✅ |
| `F08.04` | Désarmer sur neutre prolongé | Neutre tenu `NeutralHoldTime` (100ms), applicable seulement après `DeadmanArmGraceTime` (3s) écoulées depuis l'armement | `FB_Joystick` | **C4** | `TC-P08-004` | ✅ |
| `F08.05` | Désarmer sur perte de permission | `ArmingPermit=FALSE` ⇒ désarmement immédiat (niveau, pas front), axes à 0 | `FB_Joystick` | **C4** | `TC-P08-005` | ⚠️ *(logique FB testée ✅, mais producteur `ArmingPermit` câblé en dur `TRUE` en production — trou réel non couvert, voir Q1 `QUESTIONS_OUVERTES_PRG02_v0.1.md`)* |
| `F08.06` | Détecter un défaut capteur hors plage | `RawX`/`RawY` hors plage ⇒ arrêt (`SpeedRef=0`) + `ErrorId` bit1 (Warning) sur les 2 axes | `FB_Joystick` | C3 | `TC-P08-007` | ✅ |
| `F08.07` | Calibrer le neutre capteur | Bouton calibration mémorise le neutre si axes en zone [2000;8000], persistant au redémarrage, accessible depuis l'écran HMI | `FB_Joystick` | C2 | `TC-P08-006`, `TC-P08-009`, `TC-P08-010` | ⚠️ *(TC-P08-009/010 = type SITE, non exécutés automatiquement)* |
| `F08.08` | Interdire tout mouvement sans armement homme-mort | Gate combinant `AxisCmd*.StartStop AND DeadmanArmed` avant d'autoriser une commande treuil/translation | `PRG_04_Treuils_Benne` (**gate**, pas un FB — vérifié par script, pas par test FB) | **C4** | `TC-P08-008` | ✅ *(vérifié par `G375_check_deadman_arming_gate.py`, pas `TEST_AUTO_CI`)* |

### 4. Outillage — livré avec ce pilote (T153-C)

Un script (non existant à ce jour — nom proposé `extract_functions_matrix.py`, à créer dans
`TOOLS/AGENT_WORKFLOW/scripts/` par T153-C) parcourt `DOC/AF/AF_Partie-NN_*.md`
(et leurs sous-fiches le cas échéant, Q-TF6), extrait les tables `Fonctions` + `Points de
validation`, croise `TC couvrants` avec les tables `🧪 Points de validation` existantes pour
dériver `Statut`, produit un YAML/CSV consolidé. Détail du contrat : `TASK_CONTRACT_T153C_*`.

---
*v0.2 clôt T153-B. Prochaine étape : T153-C applique ce format sur AF-08 (déjà designé
ci-dessus §3) et livre l'outillage.*
