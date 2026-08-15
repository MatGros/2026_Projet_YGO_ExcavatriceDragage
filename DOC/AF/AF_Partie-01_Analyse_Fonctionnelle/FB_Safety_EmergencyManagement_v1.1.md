# FB_Safety_EmergencyManagement — Spec composant (v1.1)

> Rôle machine (vague) : [`AF_Partie-01_Analyse_Fonctionnelle_v2.0.md`](AF_Partie-01_Analyse_Fonctionnelle_v2.0.md) §5.
> Rôle de **ce** document : constitution, interfaces, séquence, intégration, écarts bus —
> et **catalogue unique** des `TC-P01-*` (ne pas les recopier dans AF01).
> Extraction code : `DOC/TESTS/CHECKLISTS/EXTRACTIONS/FB_Safety_EmergencyManagement_Extraction_Code_v1.0.md`.
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
| `💻 AUTO` | Banc / script / suite hors production (Python, sim). |
| `⚡ AUTO_PLC` | Séquence intégrée à l'automate de production (se joue seule dans le FB). |
| `🟢 SITE` | Essai terrain / câblage / AU physique. |
| `⚡ SITE+AUTO` | Couverture mixte (Automate + Terrain). |

### Catalogue (9 tests — regroupés par fonction)

| ID | Intention | Comportement attendu | Preuve | Type | Réf |
|---|---|---|---|---|---|
| <nobr><code>TC-P01-001</code></nobr> | AU physique | Coupe puissance moteurs, API vivant | Contacteur ouvert | `🟢 SITE` | §5.1 |
| <nobr><code>TC-P01-002</code></nobr> | Maintien A/B | Perte canal A ou B ouvre la boucle AU | `MaintainA/B_RQ=FALSE` | `⚡ SITE+AUTO` | §4 |
| <nobr><code>TC-P01-003</code></nobr> | Réarmement | Front `ArmRequest` + boucle OK ➔ pulse 1s | Pulse 1s (step 5) | `⚡ AUTO_PLC` | §5.3 |
| <nobr><code>TC-P01-004</code></nobr> | Ack Cause/Ack | `Reset` efface l'affichage (interlock reste sur Cause) | `Error=FALSE` | `💻 AUTO` | §3.4bis |
| <nobr><code>TC-P01-005</code></nobr> | Séquencement | Acquittement et réarmement 2 actions distinctes | 2 actions requises | `⚡ SITE+AUTO` | §5.4 |
| <nobr><code>TC-P01-006</code></nobr> | Auto-test A/B | Test croisé A/B au réarmement (échec ➔ `RedundancyFail`) | Steps 1–4 (200ms) | `⚡ AUTO_PLC` | §3.3bis |
| <nobr><code>TC-P01-007</code></nobr> | Lockout 5s | Échec confirmation contacteur ➔ verrouillage 5s | `LockoutActive=TRUE` | `💻 AUTO` | §5.3 |
| <nobr><code>TC-P01-008</code></nobr> | Coupure métier | `PowerCutOffRequest=TRUE` coupe A et B sans armer | `MaintainA/B_RQ=FALSE` | `💻 AUTO` | §3 |
| <nobr><code>TC-P01-009</code></nobr> | Re-latch Cause | Cause persistante ➔ ré-alarme au prochain essai | `Ack=FALSE` | `💻 AUTO` | §3.4bis |

---

## 1. Périmètre et composition

### Responsabilité

Gérer la **coupure de puissance amont** (canaux PLC redondants fail-safe) et la **séquence
explicite de réarmement** du contacteur général, avec auto-test A/B. Ne gère **pas** les
protections mouvement métier (`FB_Safety_Winch` / `FB_Safety_Translation`) : il **consomme**
leur demande `PowerCutOff` agrégée.

### Composition POO & Schéma CFC

<div style="display:flex; flex-direction:column; align-items:stretch; width:100%; margin:12px 0;">
  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #f43f5e; padding:8px 12px; border-radius:4px; font-size:12px;">
    🛡️ &nbsp;<b>FB_Safety_EmergencyManagement</b> &nbsp;(Composite Parent — Façade Publique)
  </div>
  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#f43f5e" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic;">Composition & Délégation d'exécution</span>
  </div>
  <div style="display:flex; gap:8px; width:100%;">
    <div style="flex:1; background:#1e293b; color:#f8fafc; border-left:4px solid #38bdf8; padding:8px 10px; border-radius:4px; font-size:12px;">
      🧠 &nbsp;<b>Logic : FB_Safety_EmergencyManagementLogic</b><br/>
      <span style="color:#cbd5e1; font-size:11px;">Machine d'état, fronts Reset/Arm & calcul ErrorId</span>
    </div>
    <div style="display:flex; align-items:center; justify-content:center;">
      <svg width="24" height="16" viewBox="0 0 24 16" fill="none"><path d="M0 8H18M18 8L12 4M18 8L12 12" stroke="#fbbf24" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    </div>
    <div style="flex:1; background:#1e293b; color:#f8fafc; border-left:4px solid #4ade80; padding:8px 10px; border-radius:4px; font-size:12px;">
      🔒 &nbsp;<b>Output : FB_Safety_EmergencyManagementOutput</b><br/>
      <span style="color:#cbd5e1; font-size:11px;">Pilote physique fail-safe MaintainA/B_RQ</span>
    </div>
  </div>
</div>

---

### 🧱 Fiches Composants & Cartouches ST (`CODE/AU/`)

#### 🛡️ `FB_Safety_EmergencyManagement` *(Composite Façade)*
- **Fichier Source** : [`FB_Safety_EmergencyManagement.st`](../../../../CODE/AU/FB_Safety_EmergencyManagement.st)
- **🎯 Cartouche ST (`🎯 Rôle`)** : `Façade publique, instance unique ; câblage interne Logic/Output & exposition des bus d'état`
- **Responsabilité** : Point d'entrée unique de la boucle d'arrêt d'urgence, encapsule les sous-instances privées `Logic` et `Output`.

#### 🧠 `FB_Safety_EmergencyManagementLogic` *(Décision & Machine d'État)*
- **Fichier Source** : [`FB_Safety_EmergencyManagementLogic.st`](../../../../CODE/AU/FB_Safety_EmergencyManagementLogic.st)
- **🎯 Cartouche ST (`🎯 Rôle`)** : `Machine d'état, fronts Reset/Arm, calcul ErrorId & consignes logiques`
- **Responsabilité** : Gère les étapes d'auto-test, les fronts `Reset`/`ArmRequest`, et produit le bus interne `ST_Safety_Emergency_InternalCmd`.

#### 🔒 `FB_Safety_EmergencyManagementOutput` *(Pilote Physique Fail-Safe)*
- **Fichier Source** : [`FB_Safety_EmergencyManagementOutput.st`](../../../../CODE/AU/FB_Safety_EmergencyManagementOutput.st)
- **🎯 Cartouche ST (`🎯 Rôle`)** : `Enable gate + copie consignes logiques vers sorties physiques`
- **Responsabilité** : Barrière physique finale pour les signaux `MaintainA_RQ` et `MaintainB_RQ` (polarité maintien, `TRUE` = voie saine).

#### 🧩 `ST_Safety_Emergency_InternalCmd` *(DUT Bus Interne)*
- **Fichier Source** : [`ST_Safety_Emergency_InternalCmd.st`](../../../../CODE/AU/ST_Safety_Emergency_InternalCmd.st)
- **🎯 Cartouche ST (`🎯 Rôle`)** : `Transporte les ordres logiques entre le bloc de décision et le bloc de sortie`
- **Responsabilité** : Structure d'échange interne à 3 champs `BOOL` reliant `Logic` et `Output`.

Profil AF03 : **barrière puissance / safety transverse** — pas de `StartStop` ni `SafeStop`.
`Reset` sur front. Pas de redémarrage auto après défaut.

---

## 2. Contrats d'interface

### Entrées

| Port | Producteur actuel | Sémantique |
|---|---|---|
| `Enable` | `Outputs` = TRUE fixe | Active surveillance ; FALSE = neutralisation totale |
| `Reset` | `Supervision.FaultMachineReset_IHM` ← `BtnFaultReset` | Front acquittement défauts FB |
| `ArmRequest` | `GVL_IHM.Modes.Cmd.BtnEmergencyArming` | Front demande réarmement |
| `EmergencyChainClosed` | `Acquisition.EmergencyChainClosed` ← `EmergencyChainClosed_DI` | Boucle AU fermée |
| `PowerContactorEngaged` | `Acquisition.PowerContactorEngaged` ← `PowerContactorEngaged_DI` | Contacteur engagé |
| `PowerCutOffRequest` | OR local M1/M2/M3 `.PowerCutOff` dans `Outputs` | Coupure demandée par safety domaine |
| `BtnEmergencyCutOff` | `GVL_IHM.Modes.Cmd.BtnEmergencyCutOff` | **Coupure IHM maintenue** : bouton IHM (ou supervision) qui force l'ouverture des deux canaux A/B tant que maintenu — **pas** un bouton physique AU (celui-ci est dans la boucle hardware). Ne déclenche **pas** de séquence de réarmement. |

### Sorties logiques / diag

| Port | Sémantique |
|---|---|
| `Ready` | `= Enable AND NOT StartupFail` |
| `Busy` | Séquence active ou lockout en cours |
| `Done` | `= PowerContactorEngaged` |
| `Error` / `ErrorId` | bit0=Redundancy, bit1=ArmFailed, bit3=StartupFail |
| `ArmingSeqStep` | 0…6 diagnostic |
| `RedundancyTestFailed` | Latch auto-test |
| `EmergencyArmingFailed` | Latch non-confirmation contacteur |
| `EmergencyArmingLockoutActive` | Fenêtre 5 s anti-réessai |

### Bus d'état et diagnostic (structurés, depuis composite)

| DUT | Champs | Rôle |
|---|---|---|
| `ST_Safety_Emergency_State` | `ChainOk`, `ContactorOk`, `Step`, `Armable`, `ArmingBusy` | État public chaîne AU — consommé par Supervision, Troubleshooting |
| `ST_Safety_Emergency_Diag` | `Error`, `ErrorId`, `RedundancyTestFailed`, `ArmFailed`, `LockoutActive` | Diagnostic chaîne AU — consommé par Supervision, IHM State |

**Producteur unique** : `FB_Safety_EmergencyManagement` (sorties `State`/`Diag`).
Mappés dans `GVL_IHM.Modes.State.*` par Supervision (L2, ✅ fait).

### Sorties vers actionneurs (via Output)

| Port FB | Q physique actuelle | Polarité |
|---|---|---|
| `PowerCutOff_A_RQ` | `PowerKeepAlive_A_RQ` | TRUE = maintien voie A |
| `PowerCutOff_B_RQ` | `PowerKeepAlive_B_RQ` | TRUE = maintien voie B |
| `EmergencyArming_RQ` | `EmergencyArming_RQ` | TRUE = impulsion réarmement |

### DUT interne

```text
ST_Safety_Emergency_InternalCmd
  MaintainA_Cmd : BOOL   // TRUE = maintien canal A (ex-PowerCutOff_A_Cmd)
  MaintainB_Cmd : BOOL   // TRUE = maintien canal B (ex-PowerCutOff_B_Cmd)
  ArmPulse_Cmd : BOOL   // TRUE = pulse réarmement (ex-EmergencyArming_Cmd)
```

🏷️ Renommage 2026-07-30 : `PowerCutOff_*` → `Maintain*` (polarité maintien explicite,
conforme règle C1 : le nom répond à « que signifie TRUE ? »).

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

> ⚠️ **REX 2026-08** : la règle initiale ("Reset **et** `PowerContactorEngaged=TRUE`") créait une
> impasse opérateur — le contacteur ne peut justement pas s'engager tant que le défaut est actif,
> donc le Reset restait bloqué en boucle. Corrigée par le pattern `Cause`/`Ack`
> (`DOC/STDS/CODE_QUALITY_STANDARDS.md §9`) : le Reset **acquitte toujours**, sans condition.

| Défaut | Catégorie | Condition d'effacement |
|---|---|---|
| `RedundancyTestFailed` | Fault | Front `Reset` (toujours effectif) ; re-latch si un nouvel échec d'auto-test survient |
| `EmergencyArmingFailed` | Fault | Front `Reset` (toujours effectif, **non conditionné** par `PowerContactorEngaged`) ; re-latch si une nouvelle tentative échoue à nouveau |

**Ce qui débloque reellement une tentative echouee** : ce n'est pas le Reset, c'est un nouveau
front `ArmRequest` (§3.4bis) — le Reset acquitte seulement l'affichage IHM/diag du defaut passé.

**Comportement code retenu** : après expiration du lockout 5 s, un nouvel `ArmRequest` peut
toujours relancer la séquence, que `EmergencyArmingFailed` ait été acquitté ou non —
l'acquittement n'est jamais une condition de redémarrage (§3.4bis, `CODE_QUALITY_STANDARDS.md §9`).

### 3.4bis Pattern Cause / Ack appliqué à ce composant

Application concrète du pattern général (`CODE_QUALITY_STANDARDS.md §9`) aux deux Fault de ce FB :

- `EmergencyArmingFailedCause` : latch brut de l'échec de confirmation contacteur (positionné à
  l'étape 6, jamais effacé par Reset — seulement par une nouvelle tentative reussie).
- `EmergencyArmingFailedAck` : accusé opérateur, mis à `TRUE` sur front `Reset` (toujours), remis
  à `FALSE` automatiquement au prochain échec (nouveau front de `EmergencyArmingFailedCause`).
- Affiché/expose en diagnostic (`ErrorId` bit1) : `Cause OR NOT Ack`.
- L'interlock de sécurité (blocage nouvel armement pendant le lockout 5s) reste basé sur
  `EmergencyArmingLockoutActive`, jamais sur `Ack` — l'acquittement n'ouvre aucun interlock.
- Même construction pour `RedundancyTestFailedCause`/`RedundancyTestFailedAck`.
- Affichage IHM : lissage anti-clignotement optionnel via `TON` court (`CST_FaultDisplayDebounce`,
  `T#0ms`…`T#500ms`) sur la sortie affichée uniquement — l'action de sécurité (blocage,
  `SafeStop`, coupure) reste instantanée sur la `Cause` brute, jamais retardée.

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

Filtre acquisition : anti-rebond 20 ms à confirmer sur le matériel ; sinon filtrage équivalent à
porter dans `PRG_02_Acquisition`. `FB_Input`/`PRG_01_Inputs_LD` sont en retrait et ne doivent plus
être cités comme producteur cible.

---

## 5. Intégration programme (architecture cible)

> ⚠️ **Architecture en cours de migration** : le code actuel utilise encore des PRG séquentiels
> (`Acquisition`…`Outputs`). L'architecture cible (AF02 v3) prévoit des **pages CFC** avec chargeurs :
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
| Acquisition DI | `PRG_02_Acquisition` | Produit les faits `HwIn` et diagnostics ; filtrage à prouver |
| `FB_Input` | Retrait contrôlé | Aucun nouveau consommateur |
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
| Demande safety métier | `PowerCutOff` / `ST_Safety_PowerCutOffRequest` (futur bus) | « Je demande la **coupure** » |
| Entrée composite | `PowerCutOffRequest` | Idem |
| Sortie logique interne | `MaintainA/B_Cmd` (ex-`PowerCutOff_A/B_Cmd`) | **Maintien** fail-safe (TRUE = maintien sain) |
| Q physique device | `PowerKeepAlive_A/B_RQ` | **Maintien** (TRUE = relais excité) — nom matériel clair |

Cohérence rétablie : `Maintain*` porte la polarité réelle (maintien), `PowerKeepAlive_*_RQ`
reste le nom matériel historique (identique).

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
| `PowerContactorEngaged` | `Acquisition` (mappé) |
| `EmergencyChainOk` | `Acquisition.EmergencyChainClosed` |
| `PowerContactorOk` | miroir contacteur |
| `PowerCutOffActive` | OR safety domaines (polarité alarme) |
| `EmergencyArmable` | chain OK ∧ step0 ∧ ¬lockout ∧ ¬RedundancyFail ∧ ¬PowerContactorEngaged |
| `EmergencyArmingBusy` | Busy ∨ lockout |
| `RedundancyTestFailed` | sortie FB |
| `EmergencyArmingFailed` | sortie FB |

**✅ État 2026-07-30** : les 7 champs manquants de `ST_ModesState` sont désormais alimentés
depuis `ST_Safety_Emergency_State`/`ST_Safety_Emergency_Diag` (via `PRG_SUPERVISION_CFC`). Écart résolu.

---

## 7. Simulation

`FB_Sim_Safety` (via `FB_SimBench`) :

- `SimChainOk := PowerCutOff_A AND PowerCutOff_B AND NOT BtnEmergencyStop`
- Latch contacteur sur `EmergencyArming` ; retombée immédiate si chain ouverte

**Correctif L1 appliqué** dans `Acquisition` → `instSimBench` :

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
5. DUT interne Logic→Output conserve `ST_Safety_Emergency_InternalCmd` (privé composite).

### 8.2 DUT proposés (noms à figer)

| DUT | Producteur | Contenu minimal | Lecteurs |
|---|---|---|---|
| `ST_Safety_PowerCutOffRequest` | `PRG_SAFETY_CFC` (agrégateur) | `Request : BOOL`, optionnel masque sources | `PRG_OUTPUTS_LD` → `PowerCutOffRequest` |
| `ST_HwMachine` (sous-image de `ST_HardwareImage`) | Acquisition | DI chain + contactor déjà dans `ST_HwMachine` | FB via Acquisition qualifiée |
| `ST_Safety_Emergency_State` | Outputs / composite | Step, Busy, Armable, ChainOk, ContactorOk | Supervision, troubleshooting |
| `ST_Safety_Emergency_Diag` | Outputs / composite | Error, ErrorId, RedundancyFail, ArmingFail, Lockout | Supervision, IHM State |

### 8.3 Lots d'implémentation — état courant

| Lot | Contenu | Risque | État |
|---|---|---|---|
| **L0 Doc** | Cette spec + extraction + liens AF01/02/03 | Nul | ✅ Fait |
| **L1 Sim** | Corriger câblage `FB_SimBench` KeepAlive/Arming | Faible | ✅ Fait |
| **L2 IHM map** | Alimenter tous les champs `ST_ModesState` armement depuis FB | Faible | ✅ Fait |
| **L3 DUT State/Diag** | Introduire `ST_Safety_Emergency_State`, `ST_Safety_Emergency_Diag` ; retirer dépendance `GVL_Global` armement | Moyen | ✅ Fait (code + bus) |
| **L4 Agrégat PowerCutOff** | DUT `ST_Safety_PowerCutOffRequest` depuis Safety ; OR hors Outputs anonyme | Moyen | ⬜ Planifié (dépend CFC Safety) |
| **L5 Noms polarité** | Renommage partiel `PowerCutOff_A/B_Cmd` → `MaintainA/B_Cmd`, `EmergencyArming_Cmd` → `ArmPulse_Cmd` | Moyen | ✅ Fait (ST_Safety_Emergency_InternalCmd + code) ; reste `PowerKeepAlive_*_RQ` côté Q (nom matériel conservé) |

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
| Extraction | `DOC/TESTS/CHECKLISTS/EXTRACTIONS/FB_Safety_EmergencyManagement_Extraction_Code_v1.0.md` |

Fichiers code de référence :

- `CODE/AU/FB_Safety_EmergencyManagement.st`
- `CODE/AU/FB_Safety_EmergencyManagementLogic.st`
- `CODE/AU/FB_Safety_EmergencyManagementOutput.st`
- `CODE/AU/ST_Safety_Emergency_InternalCmd.st` (interne Logic→Output)
- `CODE/AU/ST_Safety_Emergency_State.st` (bus état public)
- `CODE/AU/ST_Safety_Emergency_Diag.st` (bus diagnostic)
- `ARCHIVES/Code/SUPERVISION/ST_Safety_Emergency_HmiCmd.st` (bus commande IHM, test archivé T99)
- `ARCHIVES/Code/SUPERVISION/ST_Safety_Emergency_HmiState.st` (bus état IHM, test archivé T99)
- `ARCHIVES/Code/SUPERVISION/GVL_IHM_AU.st` (interface IHM archivée T99)
- `CODE/MAIN/PRG_02_Acquisition.st` (ST pur)
- `CODE/MAIN/PRG_06_Outputs_LD.st` (sorties)
- `ARCHIVES/Code/TESTS/PRG_AU_TestBench.st` (banc de test manuel, archivé 2026-08-01 — voir `DOC/WFLOW/PLAN_TASK.md`)
- `CODE/MAIN/Outputs (Ladder).st` (cible)
- Cible de migration : `PRG_02_Acquisition.st` (ST pur, dans `CODE/MAIN`)
- `CODE/SIMULATION/FB_Sim_Safety.st`
