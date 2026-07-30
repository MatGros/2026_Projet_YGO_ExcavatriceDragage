# FB_Safety_EmergencyManagement — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-01_Analyse_Fonctionnelle_v2.0.md`](AF_Partie-01_Analyse_Fonctionnelle_v2.0.md) §5.
> Rôle de **ce** document : constitution, interfaces, séquence, intégration, écarts bus —
> et **catalogue unique** des `TC-P01-*` (ne pas les recopier dans AF01).
> Extraction code : `DOC/CHECKLISTS/EXTRACTIONS/FB_Safety_EmergencyManagement_Extraction_Code_v1.0.md`.
> ⚠️ Existant vérifié + écarts à normaliser. Pas de modif code sans validation §8.

## 🧭 Sommaire

1. Périmètre et composition
2. Contrats d'interface
3. Comportement et séquence
4. Polarités et E/S physiques
5. Intégration programme (actuel)
6. IHM et diagnostics
7. Simulation
8. Normalisation bus/DUT (cible, non implémentée)
9. Stratégie de test
10. Documents liés

## 🧪 Points de validation (`TC-P01-*` — propriétaire unique)

### Types d'essai

| Type | Sens |
|---|---|
| `AUTO` | Banc / script / suite hors production (ST de test, Python, sim). |
| `AUTO_PLC` | **Séquence intégrée à l'automate de production** — se joue toute seule dans le FB (ex. auto-test A/B au réarmement). Pas un essai opérateur manuel. |
| `SITE` | Essai terrain / câblage / AU physique. |
| `AUTO+SITE` | Les deux couches. |

### Catalogue (8 tests — regroupés par fonction)

| ID | Fonction | Attendu | Preuve | Type | Détail |
|---|---|---|---|---|---|
| TC-P01-001 | AU physique | Coupe puissance moteurs, API vivant | contacteur ouvert, PLC OK | SITE | §5.1 |
| TC-P01-002 | Maintien A/B | Perte A ou B ouvre boucle AU | `PowerKeepAlive_*=FALSE` côté Q | AUTO+SITE | §4 |
| TC-P01-003 | Réarmement | Front `ArmRequest` seul, chain OK, contacteur ouvert | pulse 1s, pas d'auto-réarmement | AUTO + AUTO_PLC | §5.3 |
| TC-P01-004 | Latch `ArmingFailed` | `EmergencyArmingFailed` latche ; Reset seul insuffisant si contacteur non engagé | bit/ErrorId | AUTO | §5.3 |
| TC-P01-005 | Acquittement ≠ réarmement | 2 actions distinctes requises | 2 actions | AUTO+SITE | §5.4 |
| TC-P01-006 | Auto-test A/B intégré | Un canal ouvert, l'autre maintenu ; chain suit ; échec ⇒ `RedundancyTestFailed` | steps 1–4, 200 ms | **AUTO_PLC** (+ AUTO en sim) | §3.3bis |
| TC-P01-007 | Lockout 5s | Échec confirm ⇒ lockout 5s | `EmergencyArmingLockoutActive` | AUTO | §5.3 |
| TC-P01-008 | Coupure sécurité | `PowerCutOffRequest=TRUE` ouvre A et B sans armement | sorties maintien FALSE | AUTO | §3 |

---

## 1. Périmètre et composition

### Responsabilité

Gérer la **coupure de puissance amont** (canaux PLC redondants fail-safe) et la **séquence
explicite de réarmement** du contacteur général, avec auto-test A/B. Ne gère **pas** les
protections mouvement métier (`FB_Safety_Winch` / `FB_Safety_Translation`) : il **consomme**
leur demande `PowerCutOff` agrégée.

### Composition POO

```text
FB_Safety_EmergencyManagement          ← façade publique, instance unique
 ├─ Logic : FB_Safety_EmergencyManagementLogic   ← décision + séquence + latches
 └─ Output : FB_Safety_EmergencyManagementOutput ← projection physique fail-safe
      ▲
      └── Cmd : ST_EmergencyManagementCmd        ← DUT interne Logic→Output
```

| POU | Responsabilité | Interdit |
|---|---|---|
| Composite | Câblage interne Logic/Output ; exposition ports | Logique métier parallèle |
| Logic | Machine d'état, fronts Reset/Arm, ErrorId, Cmd | Écriture Q physiques |
| Output | `Enable` gate + copie Cmd → `*_RQ` | Décision / timers |
| `ST_EmergencyManagementCmd` | Bus interne 3 BOOL | Usage hors composite |

Profil AF03 : **barrière puissance / safety transverse** — pas de `StartStop` ni `SafeStop`.
`Reset` sur front. Pas de redémarrage auto après défaut.

---

## 2. Contrats d'interface

### Entrées

| Port | Producteur actuel | Sémantique |
|---|---|---|
| `Enable` | `PRG_10` = TRUE fixe | Active surveillance ; FALSE = neutralisation totale |
| `Reset` | `PRG_09.FaultMachineReset_IHM` ← `BtnFaultReset` | Front acquittement défauts FB |
| `ArmRequest` | `GVL_IHM.Modes.Cmd.BtnEmergencyArming` | Front demande réarmement |
| `EmergencyChainClosed` | `PRG_00.EmergencyChainClosed` ← `EmergencyChainClosed_DI` | Boucle AU fermée |
| `PowerContactorEngaged` | `PRG_00.PowerContactorEngaged` ← `PowerContactorEngaged_DI` | Contacteur engagé |
| `PowerCutOffRequest` | OR local M1/M2/M3 `.PowerCutOff` dans `PRG_10` | Coupure demandée par safety domaine |
| `BtnEmergencyCutOff` | `GVL_IHM.Modes.Cmd.BtnEmergencyCutOff` | **Coupure IHM maintenue** : bouton IHM (ou supervision) qui force l'ouverture des deux canaux A/B tant que maintenu — **pas** un bouton physique AU (celui-ci est dans la boucle hardware). Ne déclenche **pas** de séquence de réarmement. |

### Sorties logiques / diag

| Port | Sémantique |
|---|---|
| `Ready` | Aujourd'hui `= Enable` |
| `Busy` | Séquence active (`ArmingSeqStep <> 0`) |
| `Done` | Aujourd'hui `= PowerContactorEngaged` |
| `Error` / `ErrorId` | bit0 redondance, bit1 arming failed |
| `ArmingSeqStep` | 0…6 diagnostic |
| `RedundancyTestFailed` | Latch auto-test |
| `EmergencyArmingFailed` | Latch non-confirmation contacteur |
| `EmergencyArmingLockoutActive` | Fenêtre 5 s anti-réessai |

### Sorties vers actionneurs (via Output)

| Port FB | Q physique actuelle | Polarité |
|---|---|---|
| `PowerCutOff_A_RQ` | `PowerKeepAlive_A_RQ` | TRUE = maintien voie A |
| `PowerCutOff_B_RQ` | `PowerKeepAlive_B_RQ` | TRUE = maintien voie B |
| `EmergencyArming_RQ` | `EmergencyArming_RQ` | TRUE = impulsion réarmement |

### DUT interne

```text
ST_EmergencyManagementCmd
  PowerCutOff_A_Cmd : BOOL   // TRUE = maintien
  PowerCutOff_B_Cmd : BOOL
  EmergencyArming_Cmd : BOOL // TRUE = pulse
```

---

## 3. Comportement et séquence

### 3.1 Formules de maintien (état armé ou idle)

Hors neutralisation :

```text
PowerCutOff_A_Cmd = NOT PowerCutOffRequest
                  AND NOT ForceTestA          // seulement pendant étape 1
                  AND NOT BtnEmergencyCutOff
                  AND NOT RedundancyTestFailed

PowerCutOff_B_Cmd = NOT PowerCutOffRequest
                  AND NOT ForceTestB          // seulement pendant étape 3
                  AND NOT BtnEmergencyCutOff
                  AND NOT RedundancyTestFailed
```

### 3.2 Déclenchement armement

Conditions **toutes** requises sur front `ArmRequest` :

1. `ArmingSeqStep = 0`
2. `EmergencyChainClosed = TRUE`
3. `EmergencyArmingLockoutActive = FALSE`
4. `PowerContactorEngaged = FALSE` (contacteur non engagé)

Pas d'auto-réarmement sur simple retour boucle saine.

### 3.3 Étapes

| Step | Nom | Durée | Action | Échec |
|---|---|---|---|---|
| 1 | TestA | 200 ms | Ouvre A seul | Si chain encore TRUE → `RedundancyTestFailed`, retour 0 |
| 2 | RestoreA | 200 ms | Rétablit A | Si chain FALSE en fin → retour 0 |
| 3 | TestB | 200 ms | Ouvre B seul | Idem redondance → 0 |
| 4 | RestoreB | 200 ms | Rétablit B | Si chain FALSE → 0 ; sinon → 5 |
| 5 | Pulse | 1 s | `EmergencyArming_Cmd=TRUE` | — |
| 6 | Confirm | ≤ 2 s | Attend `PowerContactorEngaged` | Timeout → `EmergencyArmingFailed` + lockout 5 s |

Succès étape 6 : retour IDLE, lockout off.

### 3.3bis Auto-test A/B = essai `AUTO_PLC` intégré

À chaque réarmement réussi jusqu'au pulse, le FB **teste les deux sorties de maintien
sans procédure manuelle séparée** :

| Phase | `PowerKeepAlive_A` | `PowerKeepAlive_B` | Attendu sur `EmergencyChainClosed` |
|---|---|---|---|
| TestA (200 ms) | **FALSE** (forcé) | TRUE (maintenu) | doit **ouvrir** (FALSE) |
| RestoreA | TRUE | TRUE | doit **refermer** (TRUE) |
| TestB (200 ms) | TRUE | **FALSE** (forcé) | doit **ouvrir** |
| RestoreB | TRUE | TRUE | doit **refermer** |

- Un seul canal est ouvert à la fois : l'autre reste en maintien — ce n'est pas une coupure
  AU opérateur, c'est la **preuve runtime** que chaque voie commande bien la boucle.
- Si la chain ne suit pas la voie testée ⇒ collé/shunté ⇒ `RedundancyTestFailed` (latch).
- Déclencheur : le même front `ArmRequest` que le réarmement (pas un bouton « test » dédié).
- Observable : `ArmingSeqStep` 1…4, puis 5 (pulse) si OK.
- Couvert par **TC-P01-006** (`AUTO_PLC`) ; rejouable aussi en sim (`AUTO`) si SimBench
  câblé correctement (§7).

### 3.4 Acquittements

| Défaut | Condition d'effacement |
|---|---|
| `RedundancyTestFailed` | Front `Reset` (cause disparue côté process = opérateur / câblage) |
| `EmergencyArmingFailed` | Front `Reset` **et** `PowerContactorEngaged=TRUE` |

**Comportement code retenu** : après expiration du lockout 5 s, un nouvel `ArmRequest` peut
relancer la séquence même si `EmergencyArmingFailed` est encore latche ; le latch IHM/diag
reste jusqu'au Reset conditionnel.

### 3.5 Temporisations nommées

| Timer | Valeur |
|---|---|
| Test / restore A ou B | `T#200ms` |
| Pulse armement | `T#1s` |
| Confirm contacteur | `T#2s` |
| Lockout | `T#5s` |

---

## 4. Polarités et E/S physiques

| Rôle | Signal acquisition / Q | TRUE signifie |
|---|---|---|
| Boucle AU | `EmergencyChainClosed_DI` → `EmergencyChainClosed` | Boucle fermée / saine |
| Contacteur | `PowerContactorEngaged_DI` → `PowerContactorEngaged` | Contacteur engagé |
| Maintien A/B | `PowerKeepAlive_A/B_RQ` | Relais maintien excité (fail-safe) |
| Pulse réarmement | `EmergencyArming_RQ` | Commande mécanique de réarmement active |

Double dénomination FB `PowerCutOff_*_RQ` vs Q `PowerKeepAlive_*_RQ` : **même polarité maintien**.
Voir écart normalisation §8.

Filtre acquisition : anti-rebond 20 ms sur les deux DI (`FB_Input` dans `PRG_00`).

---

## 5. Intégration programme (architecture cible)

> ⚠️ **Architecture en cours de migration** : le code actuel utilise encore des PRG séquentiels
> (`PRG_00`…`PRG_10`). L'architecture cible (AF02 v3) prévoit des **pages CFC** avec chargeurs :
> `PRG_ACQUISITION_CFC`, `PRG_MODES_CFC`, `PRG_SAFETY_CFC`, `PRG_OUTPUTS_LD`, etc.
> Le flux logique reste identique ; seuls les conteneurs changent.

### 5.1 Chaîne d'appels (logique, indépendante du conteneur)

```text
Acquisition (DI)
   │  lit EmergencyChainClosed_DI → EmergencyChainClosed
   │  lit PowerContactorEngaged_DI → PowerContactorEngaged
   ▼
Safety domaines (Winch M1/M2, Translation) → produisent PowerCutOff
   ▼
Modes / Cycle
   ▼
Agrégation PowerCutOff (OR des 3 safety) → PowerCutOffRequest
   ▼
Sorties (Outputs)          ← UNIQUE appel du composite :
   instSafetyEmergencyManagement (composite)
     ├─ Logic   (interne)
     └─ Output  (interne)
   puis écrit Q :
     PowerKeepAlive_A/B_RQ
     EmergencyArming_RQ
```

| FB / rôle | Appelé dans (cible) | Rôle |
|---|---|---|
| `FB_Input` chain/contactor | Acquisition CFC | Début — qualifie DI |
| `FB_Safety_Winch` M1/M2 | Safety CFC | Avant mouvements |
| `FB_Safety_Translation` | Safety CFC | Avant mouvements |
| `FB_Safety_EmergencyManagement` | **Outputs LD** seulement | Fin — après agrégat OR PowerCutOff |
| Logic / Output | **Jamais hors composite** | Même scan que le parent |
| `FB_Sim_Safety` | via SimBench dans Acquisition | Début (boucle sim) |

### 5.2 Câblage de l'instance (Outputs)

| Élément | Emplacement |
|---|---|
| Instance | `PRG_OUTPUTS_LD.instSafetyEmergencyManagement` |
| Agrégation PowerCutOff | Bus `ST_Safety_PowerCutOffRequest` depuis Safety CFC |
| Publication Q | Juste après l'appel FB dans Outputs LD |
| Portail mouvement | `PowerContactorEngaged` (**lu** par le FB, pas produit par lui) |

Conformité AF02 : AU en **chaîne sortie**, pas de page CFC AU orpheline.
Cible : rester dans `PRG_OUTPUTS_LD`.

### 5.4 Démarrage — autotest au premier boot (Start-up Self-Check)

Au premier cycle après `Enable=TRUE` (démarrage PLC ou téléchargement), le FB exécute
un **autotest de cohérence** avant d'autoriser toute séquence de réarmement :

| Étape | Vérification | Comportement si échec |
|---|---|---|
| 1 | `EmergencyChainClosed = TRUE` (boucle AU fermée) | Bloque toute séquence ; `ErrorId` bit0 si boucle ouverte sans demande |
| 2 | `PowerContactorEngaged = FALSE` (contacteur au repos) | Bloque ; contacteur déjà engagé = anomalie câblage/retour |
| 3 | `PowerKeepAlive_A = TRUE` ET `PowerKeepAlive_B = TRUE` (maintien actif) | `RedundancyTestFailed` si l'un FALSE (canal ouvert) |
| 4 | Pas de séquence en cours (`ArmingSeqStep = 0`) | Bloque si séquence résiduelle |

Ces vérifications sont **synchrones, déterministes, non bloquantes** (1 cycle). Si tout est OK,
le FB passe en `Ready=TRUE` et attend un front `ArmRequest`.

--- 

## 6. IHM et diagnostics

| Couche | Nom | TRUE signifie |
|---|---|---|
| Demande safety métier | `PowerCutOff` / futur bus `ST_Safety_PowerCutOffRequest` | « Je demande la **coupure** » |
| Entrée composite | `PowerCutOffRequest` | Idem |
| Sortie logique interne | `PowerCutOff_A/B_Cmd` puis `PowerCutOff_A/B_RQ` | **Maintien** fail-safe (TRUE = OK) — nom historique FB |
| Q physique device | `PowerKeepAlive_A/B_RQ` | **Maintien** (TRUE = relais excité) — nom matériel clair |

Donc : **`ST_Safety_PowerCutOffRequest` + `PowerKeepAlive_*_RQ` = cohérent**  
(demande de coupure d'un côté, action physique de maintien de l'autre).  
Ce qui reste ambigu, c'est seulement le port FB `PowerCutOff_*_RQ` (même polarité que KeepAlive).
Alignement optionnel = lot L5, pas bloquant pour comprendre le flux.

---

## 6. IHM et diagnostics

### Commandes (`ST_ModesCmd`)

| Champ | Usage |
|---|---|
| `BtnEmergencyArming` | → `ArmRequest` (front) |
| `BtnEmergencyCutOff` | → `BtnEmergencyCutOff` (niveau) — **commande IHM** (arrêt à distance), **pas** un bouton hardware ; les boutons hardware sont sur la chaîne AU physique (entrées `EmergencyChainClosed_DI`) |
| `BtnFaultReset` | → chaîne `FaultMachineReset_IHM` → `Reset` (avec autres défauts métier) |

### États déclarés (`ST_ModesState`) — contrat attendu

| Champ | Source attendue |
|---|---|
| `PowerContactorEngaged` | `PRG_00` (mappé) |
| `EmergencyChainOk` | `PRG_00.EmergencyChainClosed` |
| `PowerContactorOk` | miroir contacteur |
| `PowerCutOffActive` | OR safety domaines (polarité alarme) |
| `EmergencyArmable` | chain OK ∧ step0 ∧ ¬lockout ∧ ¬RedundancyFail ∧ ¬PowerContactorEngaged |
| `EmergencyArmingBusy` | Busy ∨ lockout |
| `RedundancyTestFailed` | sortie FB |
| `EmergencyArmingFailed` | sortie FB |

**Écart vérifié** : `PRG_09_Supervision` mappe aujourd'hui `Modes.State.PowerContactorEngaged` ;
les autres champs armement de `ST_ModesState` ne sont pas encore alimentés depuis le FB.
À corriger lors de la normalisation (sans changer le DUT IHM s'il est déjà consommé écran).

---

## 7. Simulation

`FB_Sim_Safety` (via `FB_SimBench`) :

- `SimChainOk := PowerCutOff_A AND PowerCutOff_B AND NOT BtnEmergencyStop`
- Latch contacteur sur `EmergencyArming` ; retombée immédiate si chain ouverte

**Correctif L1 appliqué** dans `PRG_00` → `instSimBench` :

| Entrée SimBench | Source |
|---|---|
| `PowerKeepAlive_A` | `PowerKeepAlive_A_RQ` (Q FB, scan N-1) |
| `PowerKeepAlive_B` | `PowerKeepAlive_B_RQ` |
| `EmergencyArming_RQ` | `EmergencyArming_RQ` (pulse FB, scan N-1) |

La sim rejoue la **vraie** chaîne sortie, comme le terrain.

---

## 8. Normalisation bus/DUT (cible — plan, pas code)

Alignement AF02/AF03 + synthèse 5 bus. **À valider avant implémentation.**

### 8.1 Principes

1. Une instance, un producteur des Q puissance/réarmement : Outputs.
2. Pas de GVL comme bus de commande interne pour les états armement.
3. Agrégation `PowerCutOff` nommée et visible (DUT), produite côté Safety.
4. IHM reste frontière `Cmd/State` ; mapping Supervision lit le bus State/Diag Emergency.
5. DUT interne Logic→Output conserve `ST_EmergencyManagementCmd` (privé composite).

### 8.2 DUT proposés (noms à figer)

| DUT | Producteur | Contenu minimal | Lecteurs |
|---|---|---|---|
| `ST_Safety_PowerCutOffRequest` | `PRG_SAFETY_CFC` (agrégateur) | `Request : BOOL`, optionnel masque sources | `PRG_OUTPUTS_LD` → `PowerCutOffRequest` |
| `ST_HwIn_Machine` (existant / étendu) | Acquisition | DI chain + contactor déjà dans `ST_HwMachine` | FB via Acquisition qualifiée |
| `ST_State_Emergency` | Outputs / composite | Step, Busy, Armable, ChainOk, ContactorOk | Supervision, troubleshooting |
| `ST_Diag_Emergency` | Outputs / composite | Error, ErrorId, RedundancyFail, ArmingFail, Lockout | Supervision, IHM State |

### 8.3 Lots d'implémentation proposés (ordre)

| Lot | Contenu | Risque | Prérequis |
|---|---|---|---|
| **L0 Doc** | Cette spec + extraction + liens AF01/02/03 | Nul | — |
| **L1 Sim** | Corriger câblage `FB_SimBench` KeepAlive/Arming | ✅ Fait (`PRG_00`) | — |
| **L2 IHM map** | Alimenter tous les champs `ST_ModesState` armement depuis FB | Faible | Validation |
| **L3 DUT State/Diag** | Introduire bus publics ; retirer dépendance `GVL_Global` armement | Moyen | AF03 fiche contrat |
| **L4 Agrégat PowerCutOff** | DUT depuis Safety ; OR hors Outputs anonyme | Moyen | CFC Safety |
| **L5 Noms polarité** | Option alignement `PowerKeepAlive` sur ports FB | Élevé (renommage large) | Export device + décision |

### 8.4 Hors scope de ce FB

- Méca A–E treuil / safety translation (Parties 09/11)
- Mapping device EtherCAT/CAN (Partie 06)
- Graphisme IHM (Partie 07)

---

## 9. Stratégie de test

| Couche | Cible | TC | Type |
|---|---|---|---|
| **Intégré production** | Séquence armement steps 1–4 dans le FB | P01-006 (et amorce P01-003) | **AUTO_PLC** |
| Unitaire / suite ST | Logic + timers hors ou en sim | P01-003…010 | AUTO |
| Composite | Enable gate, sorties | P01-010, 002 | AUTO |
| Linkage | Unique writer Q | P01-011 | AUTO |
| Site | AU physique, indépendance câblage A/B | P01-001, 002, 005 | SITE |

Les résultats d'exécution restent hors AF (scripts / checklists / registres).

---

## 10. Documents liés

| Doc | Lien |
|---|---|
| AF01 §5 | Règles **machine** AU/réarmement (sans dupliquer interfaces ni TC) |
| AF02 | Instance dans `PRG_OUTPUTS_LD` ; pas de page AU orpheline |
| AF03 | Profil barrière / Reset front / intégrité liaisons (pas d'ID bus) |
| AF06 | Noms DI/DQ puissance |
| AF07 | Champs `ST_Modes*` |
| AF13 | `FB_Sim_Safety` |
| Extraction | `DOC/CHECKLISTS/EXTRACTIONS/FB_Safety_EmergencyManagement_Extraction_Code_v1.0.md` |

Fichiers code de référence :

- `CODE/AU/FB_Safety_EmergencyManagement.st`
- `CODE/AU/FB_Safety_EmergencyManagementLogic.st`
- `CODE/AU/FB_Safety_EmergencyManagementOutput.st`
- `CODE/AU/ST_EmergencyManagementCmd.st`
- `CODE/MAIN/PRG_10_Outputs_LD.st`
- `CODE/MAIN/PRG_00_Inputs.st`
- `CODE/SIMULATION/FB_Sim_Safety.st`
