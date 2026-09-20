# DIAGNOSTIC T352 — Cause historique du câblage `GVL_Simulation` du service d'auto-acquittement borné (T278)

> Fiche de diagnostic **T352** (parent T278) · agent `DSH17` · 2026-09-21
> Brief : `DOC/WFLOW/CONTRACTS/BRIEF_T352_AUTORESETDIAG_JAMAIS_DECLENCHE.md`
> Contrat : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T352_AUTORESETDIAG_ENABLE_DEFAUT.yaml`
> **Toutes les affirmations ci-dessous sont adossées à une ligne réelle ou à une commande reproduite.**

---

## 1. Symptôme observé (utilisateur, 2026-09-21, watch machine réelle, AU manipulé)

| Observable | Constat |
|---|---|
| `instAutoResetTransientDiag.State` | figé à `0` |
| `instAutoResetTransientDiag.Phase` | jamais `1` ni `2` |
| `instAutoResetTransientDiag.ResetPulse` | jamais `TRUE` |
| Entrées de la chaîne AU (`EmergencyChainClosed`, …) | bougent normalement |

---

## 2. Cause racine — **prouvée**, pas supposée

### 2.1 Le mécanisme : 2 entrées d'autorisation, seules portes d'entrée de la machine à états

```
FB_AutoResetTransientDiag.st:87   IF (State = 0) AND StartupEnable AND NOT StartupStarted AND SafeCommon
                                     AND NOT PowerContactorEngaged THEN ... State := 1;
FB_AutoResetTransientDiag.st:97   IF (State = 0 OR State = 4) AND PowerRearmEnable AND PowerRearmEdge.Q
                                     AND NOT RearmStarted THEN ... State := 2;
```

Sans `StartupEnable` **et** `PowerRearmEnable` à `TRUE`, la machine à états **ne peut pas** quitter `State=0` — quelle que soit la chaîne AU. `Phase` reste `0` (`:157`) et `ResetPulse` reste `FALSE` (`:47`). Le symptôme est donc **exactement** celui d'entrées d'autorisation à `FALSE`, et non d'une logique interne cassée.

### 2.2 Le câblage réel

```
PRG_02_Acquisition.st:225   StartupEnable    := GVL_Simulation.AutoResetTransientDiagAtStartupEnable,
PRG_02_Acquisition.st:226   PowerRearmEnable := GVL_Simulation.AutoResetTransientDiagAfterRearmEnable,
GVL_Simulation.st:106       AutoResetTransientDiagAtStartupEnable    : BOOL := FALSE;
GVL_Simulation.st:107       AutoResetTransientDiagAfterRearmEnable   : BOOL := FALSE;
```

### 2.3 **Zéro écrivain** sur ces 2 booléens

`grep AutoResetTransientDiag` sur `CODE/` → **16 occurrences**, réparties en : 1 déclaration d'instance (`PRG_02:33`), 4 lectures de sortie (`PRG_02:244`, `:255`), 11 lignes de câblage, **et 0 affectation**. Aucun `:=` n'écrit jamais ces 5 paramètres, dans aucun fichier de `CODE/`. Aucun toggle IHM non plus (`CODE/J_SUPERVISION/` : 0 occurrence).

**Conclusion 2.1–2.3 : le service était structurellement inerte.** Il ne pouvait pas fonctionner, ni « tomber en panne ».

---

## 3. Cause **historique** : fonctionnalité livrée NON ACTIVÉE, jamais validée — **ce n'est pas une erreur de câblage**

La question posée par le brief était : « erreur de câblage dès le départ, ou fonctionnalité jamais terminée ? ». Réponse **prouvée** : **ni l'un ni l'autre au sens d'un bug** — les `FALSE` ont été **écrits dans le contrat de tâche**, et l'activation a été **reportée à une validation humaine qui n'a jamais eu lieu**.

### Preuve P1 — les `FALSE` sont une décision contractuelle

```yaml
# DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T278_AU_ALARMS_FILTERING_AND_AUTO_RESET.yaml:94-99
parameters:
  AutoResetAtStartupEnable: false
  AutoResetAfterPowerRearmEnable: false
  AutoResetMaxAttempts: 1
  AutoResetInterAttemptTime: 'T#1s'
  AutoResetStabilizationTime: 'T#1s'
```

### Preuve P2 — l'activation était explicitement conditionnée à une validation humaine restée ouverte

```yaml
# même fichier:157-160
validation:
  status: PENDING
  validated_by: HUM
  validated_at: ''
  notes: Validation humaine et essais CODESYS requis avant activation des flags AutoResetTransientDiag*.
```

Et côté catalogue : `TASKS.yaml:4029` — *« flags GVL par defaut FALSE. Bundle/G200 PASS ; **validation CODESYS humaine restante** »*. Le contrat T278 est resté `status: IN_PROGRESS`.

➡️ **La cause racine est une dette de recette, pas un défaut de code** : le lot a été clos « livré » sur la foi de gates mécaniques vertes alors que sa fonctionnalité était volontairement désarmée et attendait une recette humaine qui n'a pas eu lieu. T352 est la clôture de ce fil.

### Preuve P3 — l'**emplacement** de ces paramètres n'a jamais été décidé

`GVL_Simulation.st` est **absent** du `scope.allowed` du contrat T278 :

```yaml
# TASK_CONTRACT_T278_...yaml:38-45
scope:
  allowed:
    - DOC/WFLOW/TASKS.yaml
    - DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T278_....yaml
    - CODE/A_COMMUN/FB_FaultCore.st
    - CODE/C_DIAG_RESEAUX/FB_Diag_Ethercat.st
    - CODE/C_DIAG_RESEAUX/FB_Diag_CanOpen.st
    - CODE/M_MAIN/PRG_02_Acquisition.st
    - CODE/M_MAIN/PRG_07_Supervision.st
```

Or le commit d'introduction `cb5ae5ea` (2026-09-19, unique commit porteur de ce FB et de son câblage) y ajoute 9 lignes :

```
git show cb5ae5ea --stat
  CODE/C_DIAG_RESEAUX/FB_AutoResetTransientDiag.st   | 161 +
  CODE/L_SIMULATION/GVL_Simulation.st                |   9 +     <-- HORS scope.allowed
  CODE/M_MAIN/PRG_02_Acquisition.st                  |  25 +-
```

➡️ Des paramètres de **production** ont été garés dans la seule GVL disponible au porteur, faute d'emplacement autorisé. C'est la **deuxième cause**, et celle qui rend le bug invisible à la lecture : `GVL_Simulation.X` ressemble à un réglage de banc.

### Preuve P4 — le gate existant ne pouvait pas le voir (exemption par **chemin**, pas par **usage**)

`TOOLS/AGENT_WORKFLOW/scripts/G100_check_code_style.py` interdit `GVL_Simulation.` hors frontière simulation :

```python
# :69-71
# Decision humaine 2026-08 : GVL_Simulation est interdit hors implementation
# CODE/L_SIMULATION et ces frontieres (7 POU cibles).
# :73-78
SIMULATION_ALLOWED_PATHS = {
    "CODE/M_MAIN/PRG_02_Acquisition.st": SimulationAllowance(
        executable_usage="Produit HwReal/HwSim/HwIn et aiguille reel/simule.",
```

`PRG_02_Acquisition.st` est donc sur l'allowlist **pour la frontière réel/simulé** — et cette exemption, appliquée au **fichier entier**, a laissé passer **5 lectures de paramètres de production** sans rapport avec la frontière. Le gate était vert.

### Preuve P5 — aucun test unitaire du FB n'existait

`TOOLS/TEST_AUTO_CI/RESULTS/C_DIAG_RESEAUX/tests/` contenait 3 fichiers (`FB_Diag_CanOpen`, `FB_Diag_Ethercat`, `FB_Diag_IhmHeartbeat`) : **aucun test de `FB_AutoResetTransientDiag`**. Le lot T278 a ajouté un FB sans preuve unitaire — c'est ce qui a permis de livrer un automate d'état mort sans que rien ne le signale.

---

## 4. Preuve de fonctionnement du FB en isolation (AVANT correctif)

Harnais CI du projet (`TOOLS/TEST_AUTO_CI`), FB instancié **seul**, `StartupEnable`/`PowerRearmEnable` forcés à `TRUE` — nouveau fichier `TOOLS/TEST_AUTO_CI/RESULTS/C_DIAG_RESEAUX/tests/test_fb_autoresettransientdiag.st` :

```
=== RESUME ===
PASS  FB_AutoResetTransientDiag (6/6)
  PASS  TC-T352-001 Demarrage par defaut : Phase 1, impulsion apres stabilisation, verrouillage
  PASS  TC-T352-002 Post-rearmement : Phase 2 sur front contacteur, impulsion puis verrouillage
  PASS  TC-T352-003 Gardes safety : chaine AU ouverte, coupure puissance, mouvement actif
  PASS  TC-T352-004 Annulation : chute de la garde pendant la sequence -> Cancelled + Lockout
  PASS  TC-T352-005 Borne haute : 3 impulsions espacees puis verrouillage definitif
  PASS  TC-T352-006 Neutralisation : Enable=FALSE -> service remis au repos
  -- Encapsulation (interface FB) -- PASS IN=11 OUT=6 IN_OUT=0 LOCAL=10
```

➡️ **La logique interne du FB est saine.** Le défaut est **entièrement en amont** : le câblage. Aucune ligne du FB n'a été modifiée (AC10 du contrat).

---

## 5. Arbitrage de conception retenu (et pourquoi)

**Décision :** câbler les 2 autorisations **en dur à `TRUE` au site d'appel**, et **supprimer** les 5 paramètres de `GVL_Simulation` ; les 3 `Cfg_` reprennent les **défauts déclarés du FB**.

| Option | Verdict |
|---|---|
| **(a) `TRUE` en dur au site d'appel** ✅ **retenue** | 0 variable, 0 état retenu, effet immédiat à l'import, traçable à la lecture du câblage, supprime toute dépendance de production à `GVL_Simulation` |
| (b) Constante nommée dans une GVL de config dédiée | Crée un conteneur pour 2 items ; `GVL_PERSISTENT.st` figure déjà au périmètre d'un autre acteur (CC01/T299-T340-T341) |
| (c) `GVL_PERSISTENT` défaut `TRUE` | ⛔ **valeur RETENUE** : un essai qui la met à `FALSE` laisse la fonction morte **sans aucune trace dans le code** — exactement la classe de bug réparée ici. Et `G380_check_config_persistence.py` impose le pattern `ST_*Cfg` + `FB_CfgPersistBridge_*` + `Initialized` pour un paramètre configurable : 1 type + 1 bridge + 1 miroir pour 2 booléens qu'**aucun opérateur** ne doit toucher |

Les 3 `Cfg_` ne sont **pas** perdus : leurs valeurs effectives sont **identiques** avant/après, elles viennent désormais des défauts déclarés du FB :

```
FB_AutoResetTransientDiag.st:21   Cfg_MaxAttempts           : USINT := 1;
FB_AutoResetTransientDiag.st:22   Cfg_StabilizationTime     : TIME := T#1s;
FB_AutoResetTransientDiag.st:23   Cfg_InterAttemptTime      : TIME := T#1s;
avant (GVL_Simulation.st:108-110) : 1 / T#1s / T#1s   ==> STRICTEMENT IDENTIQUE
```

**Contrepartie assumée et tracée** : plus de réglage en ligne des 3 temporisations. Un besoin de 2 ou 3 tentatives devient une **nouvelle tâche explicite** (changement de contrat), pas un booléen caché.

---

## 6. 🚨 Devoir d'alerte — 2 constats **hors périmètre**, signalés et **non corrigés**

### ⛔ A1 — Une fois activé, le pulse est **structurellement un no-op** sur EtherCAT/CANopen

- Les bits de perte de liaison sont **déjà auto-effacés à chaque scan** dès que le lien revient :
  `FB_Diag_Ethercat.st:131` (`AND 16#FFEF; (* Effacement auto dès que RUNNING *)`), `:141`, `:151` ;
  `FB_Diag_CanOpen.st:100` (`Effacement auto si la liaison revient`), `:109`.
- `ResetTransient` ne fait que **ré-écrire le même masque sur les mêmes bits**, et **uniquement si l'équipement est déjà en ligne** : `FB_Diag_Ethercat.st:106-112`, `FB_Diag_CanOpen.st:77-78`.
- Or `DiagnosticsStable` exige **tous** les esclaves EtherCAT **et** le master CANopen en ligne :
  `PRG_02:234-235` ; `FB_Diag_Ethercat.st:196-197` ; `FB_Diag_CanOpen.st:130`.

➡️ **Au moment où la condition d'entrée du pulse devient vraie, les bits sont déjà à 0.** L'activation corrige l'**observabilité** (State/Phase/ResetPulse bougeront enfin, ce que l'utilisateur attendait) mais **ne masquera aucune alarme** : le besoin métier T278/GCAM n'est **pas** tenu par ce seul correctif. Traiter A1 touche la **classification des alarmes** et exige la matrice des causes GCAM → **lot séparé**, pas T352.

### ⛔ A2 — La moitié « masquage / hiérarchisation IHM » de T278 n'existe pas

`FB_FaultCore.st` et `PRG_07_Supervision.st` figuraient au `scope.allowed` du contrat T278 (lignes 41 et 45) mais sont **absents** du commit `cb5ae5ea`. `grep -i "transitoir|Transient"` sur tout `CODE/` : **0** occurrence d'une hiérarchisation d'alarme T278 (les seuls résultats sont des mécanismes préexistants sans rapport : `FB_SyncContactor:54`, `FB_SyncDeviation:45`, `FB_Hmi_BannerFormatter:463`). Les objectifs `OBJ-01`/`OBJ-02` du contrat T278 sont donc **non implémentés**.

### ⚠️ A3 — Le détecteur générique de la même classe révèle 16 sites, dont 14 hors périmètre

`python TOOLS/AGENT_WORKFLOW/scripts/G516_check_dead_config_switch.py . --scan-all` (mode informatif) : **16** booléens de GVL consommés en argument nommé de FB et jamais écrits dans `CODE/`, dont **les 2 du bug T352** (`GVL_Simulation.st:106-107`). Les 14 autres sont des réglages de banc / bits de bypass dont l'écriture est **légitimement externe au PLC** (`GVL_BypassRetain.BypassAuArmingPreconditions`, `SimWinchDynamicsActive`, `SimBucketJamActive`, `SimM2CoupledDescentModelActive`, `SimulationModeActive`, …).

Trier « réglage de banc » contre « interrupteur de production » est une **décision humaine** — c'est précisément la confusion qui a produit ce bug. Le mode bloquant de G516 est donc **délibérément étroit** (invariant de câblage T352, 0 faux positif) et **aucune exemption n'a été posée par l'agent**. La population des 14 sites est **remontée à l'orchestrateur** pour arbitrage avant tout élargissement.

---

## 7. Traçabilité d'impact (producteur → routeur → consommateur)

| Maillon | Qui | Où |
|---|---|---|
| **Producteur** (avant) | personne — les 5 paramètres n'avaient aucun écrivain | `GVL_Simulation.st:106-110` |
| **Producteur** (après) | le site d'appel lui-même, valeur littérale `TRUE` | `PRG_02_Acquisition.st:225-226` |
| **Routeur** | `instAutoResetTransientDiag` (déclaré `PRG_02:33`, appelé `PRG_02:223`) | `FB_AutoResetTransientDiag.st` |
| **Consommateur final** | `instDiagCanOpen.ResetTransient` et `instDiagEthercat.ResetTransient` | `PRG_02:244` et `PRG_02:255` → `FB_Diag_CanOpen.st:77`, `FB_Diag_Ethercat.st:105` |

Consommateur final **nommé** : le bit de diagnostic réseau des FB `FB_Diag_CanOpen` / `FB_Diag_Ethercat`. Voir A1 pour la limite d'effet de ce consommateur.

---

## 8. Garde-fou livré (règle projet `fix:` + `guard:`)

| Élément | Détail |
|---|---|
| Script | `TOOLS/AGENT_WORKFLOW/scripts/G516_check_dead_config_switch.py` — **nouveau** |
| Mode bloquant (palier C) | Invariant de câblage T352 : les 2 autorisations de `instAutoResetTransientDiag` sont des littéraux `TRUE`, et **aucune** entrée du FB n'est servie par `GVL_Simulation` |
| Rouge **avant** correctif | `7 erreur(s)` sur le contenu `HEAD` de `PRG_02_Acquisition.st` (reproduit) |
| Vert **après** correctif | `0 erreur(s)` |
| Autorecette | `--selftest` PASS : 2/2 interrupteurs morts détectés, `MaxAttempts` (écrit) et `SimulationModeActive` (lecture scalaire) non signalés, écriture en commentaire neutralisée, recâblage sur GVL → rouge, retour à `FALSE` → rouge, appel disparu → rouge |
| Mode informatif | `--scan-all` (16 sites, non bloquant, population à arbitrer — voir A3) |
| ID | `G515` étant **pris** (T262-B/DSH16), ce gate porte `G516` |

---

## 9. Non-régression

- Gardes de sécurité du FB **inchangées** : `SafeCommon` (`:70`), `EmergencyChainClosed`, `PowerCutOffActive`, `MotionActive`, `PowerContactorEngaged`, borne `1..3` (`:66-68`), `Lockout` après salve, annulation immédiate (`:122`).
- Chaîne AU, sécurités mouvement, codeurs de sécurité, contacteurs, freins : **aucun fichier touché** (`CODE/B_AU_SECURITE/**`, `CODE/E_CODEURS/**`, `PRG_04`, `PRG_05`, `PRG_06` interdits et non modifiés).
- Aucun redémarrage automatique de mouvement ou de cycle : le FB ne produit que `ResetPulse` (impulsion 1 scan) vers des bits de diagnostic réseau.
- Valeurs de réglage effectives identiques (§5).
