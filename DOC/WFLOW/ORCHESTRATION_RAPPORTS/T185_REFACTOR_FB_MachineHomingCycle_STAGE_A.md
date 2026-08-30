# T185 — Refactor `FB_ReferenceCycle` · Stage A (interface) — proposition orchestrateur

> Statut : **implémentée et validée fonctionnellement** ; clôture globale en attente des gates hors périmètre T185.
> Exécutant Stage A : sous-agent py Ollama `deepseek-v4-flash:cloud`.
> Corrections de conformité : orchestrateur (Claude Code) — voir §7.
> Les arbitrages C-1/C-2/C-3 sont appliqués dans `CODE/` ; validation ciblée T185 : 18/18 tests PASS (rapport avec chronogramme).

## 0. Baseline vérifiée (2026-08-30, orchestrateur)

T185 **n'est pas** un simple fichier WIP jamais relié. Le commit `d94c2c58 wip(T185)` est une
**intégration committée de 47 fichiers (+5003 l.)** :

| Point d'intégration | État |
|---|---|
| `FB_ReferenceCycle` instancié + appelé dans `PRG_02_Acquisition` | ✅ lié (G200 L1-L7 = 100 OK) |
| Gate SEMI_AUTO dans `FB_Modes` (`instCauses[3]` + `ModeChangeAllowed AND NOT MachineReferenceReady`) | ✅ câblé |
| `ReferenceLossSafeStop` → `SafeStopM1_Raw`/`SafeStopM2_Raw` dans `PRG_04` | ✅ câblé |
| Commit benne : `FB_Bucket` reçoit `ReferenceCommitOpen/Close` (les fronts `ConfirmOpen/CloseEdge` ont été retirés de FB_Bucket, entrées `ConfirmOpen/ClosePosition` marquées « Legacy, ignore ») | ✅ routé |
| Boucle croisée `FB_Bucket.ActiveOffsetValid` ↔ `MachineReferenceReady` (l.364-368) | ⚠️ **présente et committée** (défaut C-3) |
| Diagnostic `FB_TroubleshootingView` Idx113-120 | ✅ |
| Tests `TC-T185-001..004` | ✅ **4/4 PASS** (rejoués : domaine G_CYCLE 4 FB / 4 PASS) |
| Doc AF-05 / AF-09 / AF-10 + contrat T185 | ✅ committés |
| G200 global | FAIL **pré-existant hors T185** — unique KO = `FB_WinchSpeedLearning` orphelin (T181-15) |

**Conclusion** : `IN_PROGRESS` = intégration fonctionnelle verte au CI, **mais FB cœur non conforme**
(pas de `Fault`/`Lifecycle`/enum/DUT/cartouche/régions) + 3 défauts latents (C-1/C-2/C-3).
Le refactor doit **finir la conformité sans casser l'intégration verte** ni régresser G200 L1-L7.

---

## 1. Cartouche conforme (≤ 15 lignes, emojis whitelist)

```pascal
(* =======================================================================
   🎯 FB_ReferenceCycle — Guide de referencement machine M1/M2/benne
   ───────────────────────────────────────────────────────────────
   🎯 Role : Qualifier la reference machine et guider le referencement
             conjoint M1/M2 + le commit atomique de l'etat benne.
   🔒 Securite : SEMI_AUTO interdit tant que MachineReferenceReady=FALSE.
                 Perte de reference en mouvement -> SafeStop, pas de
                 redemarrage automatique.
   🔌 Interface : contrat standard (Enable/Reset, Ready/Fault/Lifecycle).
                  N'emet AUCUN ordre de mouvement — uniquement des
                  demandes de homing et le commit benne.
   📄 Doc metier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
                   + DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md
   🧩 Dependances : FB_FaultCore, FB_Encoder (M1/M2), FB_Bucket, FB_Modes
   ======================================================================= *)
```

## 2. `E_MachineHomingStep` — nouvel enum (remplace `ReferenceStep : INT` + 12 littéraux)

Fichier : **`CODE/G_CYCLE/_TYPES/E_MachineHomingStep.st`** (le FB vit dans `G_CYCLE`, cf. `E_CycleStep`).
Syntaxe `ENUM … END_ENUM` (alignée sur `E_Mode`, `E_CycleStep`).

```pascal
(* =======================================================================
   ⚙️ E_MachineReferenceStep — Etapes du guide de referencement machine
   ───────────────────────────────────────────────────────────────
   🎯 Role : Etat publie du guide de referencement (IHM + interlocks)
   📄 Doc metier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
   ======================================================================= *)
TYPE E_MachineReferenceStep :
ENUM
    IDLE                 := 0,   (* Referencement indisponible (Enable=FALSE) *)
    LOSS_SAFESTOP        := 5,   (* Perte de reference en mouvement : arret controle en cours *)
    BOTH_NOT_REFERENCED  := 10,  (* Codeurs M1 et M2 non references : passer en MAINT_N2 *)
    M1_NOT_REFERENCED    := 11,  (* Codeur M1 non reference ou mesure douteuse : homer M1 *)
    M2_NOT_REFERENCED    := 12,  (* Codeur M2 non reference ou mesure douteuse : homer M2 *)
    OFFSET_UNKNOWN       := 20,  (* Offset benne inconnu : passer en MAINT_N2 *)
    NEED_TOP_POSITION    := 30,  (* Monter Both a vitesse lente jusqu au capteur haut *)
    NEED_MECHANICAL_STOP := 40,  (* Capteur haut atteint : relacher et attendre l arret *)
    CONFIRM_BUCKET       := 45,  (* Confirmer visuellement la benne : Fermee ou Ouverte *)
    HOMING_IN_PROGRESS   := 50,  (* Referencement conjoint M1/M2 en cours : ne pas manoeuvrer *)
    VALID                := 60,  (* Referencement machine valide : mode nominal disponible *)
    FAILED               := 70   (* Referencement incomplet : rester en N2 et recommencer *)
END_ENUM
END_TYPE
```

## 3. Structs DUT (fichiers dans `CODE/G_CYCLE/_TYPES/`)

### 3.1 `ST_fbRef_AxisHomingStatus` — statut homing d'un axe (entrée)
```pascal
TYPE ST_fbRef_AxisHomingStatus :
STRUCT
    HomedAndReliable : BOOL;   (* Codeur reference ET mesure jugee fiable *)
    HomingBusy       : BOOL;   (* Sequence de homing en cours sur l'axe *)
    HomingDone       : BOOL;   (* Homing termine avec succes (front/latche cote FB_Encoder) *)
    HomingError      : BOOL;   (* Homing en erreur sur l'axe *)
END_STRUCT
END_TYPE
```
*Contrat cohérent : les 4 bits décrivent un même sujet (l'état homing d'un axe). Supprime la duplication M1×/M2× à plat.*

### 3.2 `ST_fbRef_HomingDemand` — demande de homing émise vers un axe (sortie)
```pascal
TYPE ST_fbRef_HomingDemand :
STRUCT
    HomingRequest    : BOOL;   (* Demande de homing conjoint pour cet axe *)
    UseDynamicTarget : BOOL;   (* TRUE => cible = DynamicTargetM (M2 uniquement) *)
    DynamicTargetM   : REAL;   (* Cible geometrique m : CfgTopHomingTargetM + offset benne *)
END_STRUCT
END_TYPE
```
*Contrat de commande homing. M1 : `UseDynamicTarget=FALSE`. M2 : cible = top M1 configuré ± offset, jamais une position M1 live.*

### 3.3 `ST_fbRef_BucketCommit` — commit atomique de l'état benne (sortie)
```pascal
TYPE ST_fbRef_BucketCommit :
STRUCT
    CommitOpen  : BOOL;   (* Publier "benne ouverte" — impulsion 1 scan apres double succes homing *)
    CommitClose : BOOL;   (* Publier "benne fermee" — impulsion 1 scan apres double succes homing *)
END_STRUCT
END_TYPE
```
*`CommitOpen` et `CommitClose` sont mutuellement exclusifs (garanti par le corps — cf. C-2).*

## 4. Déclarations refactorées

```pascal
FUNCTION_BLOCK PUBLIC FB_ReferenceCycle
VAR_INPUT
    // === CONTRAT STANDARD (Enable + Reset) ===
    Enable                      : BOOL;                      // --> [CMD] Autorisation generale (FALSE => sorties sures, retour IDLE)
    Reset                       : BOOL;                      // --> [CMD] Acquittement defaut (front, jamais conditionne)

    // === MODE ARBITRE ===
    Mode                        : E_Mode;                    // --> [CMD] Mode machine arbitre (confirmation benne : MAINT_N2 seul)

    // === PERMIS SECURITE ===
    TopPositionActive           : BOOL;                      // --> [SAFE] Capteur haut commun au contact (precondition confirmation)
    WinchesMechanicallyStopped  : BOOL;                      // --> [SAFE] M1 ET M2 arret mecanique confirme (contacteurs+frein+vitesse)

    // === ACQUISITION HOMING (M1 / M2) ===
    M1Status                    : ST_fbRef_AxisHomingStatus; // --> [HW] Statut homing axe M1 (Retenue)
    M2Status                    : ST_fbRef_AxisHomingStatus; // --> [HW] Statut homing axe M2 (Benne)

    // === ETAT BENNE ===
    BucketOffsetValid           : BOOL;                      // --> [HW] Offset benne actif valide (produit par FB_Bucket)

    // === COMMANDES OPERATEUR (IHM) ===
    ConfirmOpenPosition         : BOOL;                      // --> [CMD] Confirmation visuelle "benne ouverte" (niveau, front interne)
    ConfirmClosePosition        : BOOL;                      // --> [CMD] Confirmation visuelle "benne fermee" (niveau, front interne)

    // === REGLAGES & CONFIGURATION ===
    CfgTopHomingTargetM         : REAL;                      // --> [CFG] Cible haute configuree M1 (m) — base de la cible dynamique M2
    CfgOffsetOpenM              : REAL;                      // --> [CFG] Ecart geometrique benne ouverte (m)
    CfgOffsetCloseM             : REAL;                      // --> [CFG] Ecart geometrique benne fermee (m)
END_VAR
VAR_OUTPUT
    // === CONTRAT STANDARD (Ready + Fault) ===
    Ready                       : BOOL;                              // <-- [STAT] FB actif (Enable ET NOT Fault.Latched)
    Fault                       : ST_Fault;                          // <-- [SAFE] Socle defaut (rempli par FB_FaultCore)
    Lifecycle                   : ST_Lifecycle;                      // <-- [STAT] Cycle transaction (Busy = homing conjoint en cours)

    // === QUALIFICATION MACHINE ===
    MachineReferenceReady       : BOOL;                              // <-- [SAFE] Reference machine valide (gate SEMI_AUTO)
    ReferenceStep               : E_MachineReferenceStep := E_MachineReferenceStep.IDLE; // <-- [STAT] Etape du guide
    ReferenceStepAtError        : E_MachineReferenceStep := E_MachineReferenceStep.IDLE; // <-- [DIAG] Etape figee a l'apparition du defaut (R9)
    ReferenceInstruction        : STRING(120);                       // <-- [DIAG] Consigne operateur en clair (ASCII)
    ReferenceTransactionActive  : BOOL;                              // <-- [STAT] Transaction de referencement en cours (= Lifecycle.Busy)
    ReferenceLossSafeStop       : BOOL;                              // <-- [SAFE] Demande d'arret controle suite perte de reference en mouvement
    ReferenceFailed             : BOOL;                              // <-- [STAT] Derniere transaction abandonnee (miroir Fault.Latched partiel)

    // === DEMANDES HOMING (M1 / M2) ===
    M1Demand                    : ST_fbRef_HomingDemand;             // <-- [ACT] Demande de homing conjoint axe M1
    M2Demand                    : ST_fbRef_HomingDemand;             // <-- [ACT] Demande de homing conjoint axe M2 (cible dynamique)

    // === COMMIT BENNE ===
    BucketCommit                : ST_fbRef_BucketCommit;             // <-- [ACT] Publication atomique de l'etat benne (vers FB_Bucket)
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    instFault                   : FB_FaultCore;                      // * [INST] Socle defaut transverse
    ResetEdge                   : R_TRIG;                            // * [INST] Front montant Reset
    ConfirmOpenEdge             : R_TRIG;                            // * [INST] Front montant ConfirmOpenPosition
    ConfirmCloseEdge            : R_TRIG;                            // * [INST] Front montant ConfirmClosePosition

    // === TABLE DES CAUSES DE DEFAUT ===
    instCauses                  : ARRAY[0..15] OF ST_FaultCause;     // . [LOC] Causes en clair pour FB_FaultCore

    // === ETATS INTERNES TRANSACTION ===
    PendingOpen                 : BOOL;                              // . [LOC] Confirmation "ouverte" en attente de commit
    PendingClose                : BOOL;                              // . [LOC] Confirmation "fermee" en attente de commit
    HomingStarted               : BOOL;                              // . [LOC] Transaction homing conjoint armee
    HomingBusyObserved          : BOOL;                              // . [LOC] Au moins un Busy observe depuis le debut de la transaction
    CommitPublished             : BOOL;                              // . [LOC] Commit benne deja publie sur cette reference
    ReferenceWasReady           : BOOL;                              // . [LOC] Memorise une reference valide (detection de perte)
    ReferenceLossLatched        : BOOL;                              // . [LOC] Perte de reference en mouvement latchee jusqu'a l'arret
    ReQualificationRequired     : BOOL;                              // . [LOC] Bloque MachineReferenceReady apres une perte (cf. C-1)
END_VAR
VAR CONSTANT
    // === INDICES DE CAUSES (instCauses[]) ===
    CAUSE_REF_LOST_IN_MOTION    : INT := 0;                          // Perte de reference valide pendant un mouvement (Latching)
    CAUSE_TX_ABORT_TOP_LOST     : INT := 1;                          // Capteur haut perdu pendant la transaction (Latching)
    CAUSE_TX_ABORT_MOTION       : INT := 2;                          // Mouvement detecte pendant la transaction (Latching)
    CAUSE_HOMING_ERROR_M1       : INT := 3;                          // FB_Encoder M1 signale une erreur de homing (Latching)
    CAUSE_HOMING_ERROR_M2       : INT := 4;                          // FB_Encoder M2 signale une erreur de homing (Latching)
    CAUSE_DOUBLE_CONFIRM        : INT := 5;                          // ConfirmOpen ET ConfirmClose au meme scan (Latching) — cf. C-2
END_VAR
```

## 5. Tableau de correspondance ancien → nouveau (non-régression appelants)

| Ancien (`instReferenceCycle.…`) | Nouveau | Type | Impact appelant |
|---|---|---|---|
| `M1HomedAndReliable` (in) | `M1Status.HomedAndReliable` | BOOL | PRG_02 : remplir un `ST_fbRef_AxisHomingStatus` avant l'appel |
| `M1HomingBusy` / `M1HomingDone` / `M1HomingError` (in) | `M1Status.HomingBusy` / `.HomingDone` / `.HomingError` | BOOL | idem |
| `M2Homed*` (in, ×4) | `M2Status.*` | BOOL | idem, axe M2 |
| `HomingRequestM1` (out) | `M1Demand.HomingRequest` | BOOL | PRG_02 l.408-409 : `… OR instReferenceCycle.M1Demand.HomingRequest` |
| `HomingRequestM2` (out) | `M2Demand.HomingRequest` | BOOL | PRG_02 l.457-458 |
| `M2UseDynamicTarget` (out) | `M2Demand.UseDynamicTarget` | BOOL | PRG_02 l.463 |
| `M2DynamicTargetM` (out) | `M2Demand.DynamicTargetM` | REAL | PRG_02 l.464 |
| `CommitOpenPosition` (out) | `BucketCommit.CommitOpen` | BOOL | consommateur FB_Bucket / PRG_04 |
| `CommitClosePosition` (out) | `BucketCommit.CommitClose` | BOOL | idem |
| `ReferenceStep` (out) | `ReferenceStep` | **INT → `E_MachineReferenceStep`** | tout `= 10/20/60…` → `= E_MachineReferenceStep.XXX` (PRG_02, FB_TroubleshootingView, tests) |
| `ReferenceInstruction`, `ReferenceFailed`, `ReferenceTransactionActive`, `ReferenceLossSafeStop`, `MachineReferenceReady` | inchangés | — | RAS |
| — | `Ready`, `Fault`, `Lifecycle`, `ReferenceStepAtError` | nouveaux | à publier/consommer (Supervision) |
| `Enable`, `Reset`, `Mode`, `TopPositionActive`, `WinchesMechanicallyStopped`, `BucketOffsetValid`, `ConfirmOpen/ClosePosition`, `Cfg*` | inchangés | — | RAS |

## 6. Fichiers touchés (scope T185, déjà autorisé par le contrat)

| Fichier | Nature |
|---|---|
| `CODE/G_CYCLE/FB_MachineHomingCycle.st` | refactor interface + corps (Stage B) |
| `CODE/G_CYCLE/_TYPES/E_MachineHomingStep.st` | **nouveau** |
| `CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_AxisHomingStatus.st` | **nouveau** |
| `CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_HomingDemand.st` | **nouveau** |
| `CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_BucketCommit.st` | **nouveau** |
| `CODE/M_MAIN/PRG_02_Acquisition.st` | adapter l'appel (structs in/out) + splitter `WinchesMechanicallyStopped` (N-8) |
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | lecture `BucketCommit.*` |
| `CODE/M_MAIN/PRG_07_Supervision.st` | publier `Fault`/`Lifecycle`/`ReferenceStep` |
| `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` | casser la boucle croisée (cf. C-3) — **si arbitrage le demande** |
| `CODE/J_SUPERVISION/FB_TroubleshootingView.st` | comparaisons `ReferenceStep` → enum |
| `TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_machinehomingcycle.st` | réécriture AC1-AC12 (Stage C) |

## 7. Corrections orchestrateur apportées au retour Ollama

| Retour Ollama | Correction |
|---|---|
| Cartouche inchangé (non conforme) | Cartouche complet `═`/emojis whitelist, `📄` chemin versionné + `F09.08` |
| Enum en syntaxe `( … )` | `ENUM … END_ENUM` (cf. `E_Mode`) ; valeurs en `SCREAMING_SNAKE` cohérentes `E_CycleStep` |
| Enum dans `A_COMMUN/_TYPES` | déplacé `G_CYCLE/_TYPES` (le FB y vit) |
| `Fault` taggé `[STAT]` | `[SAFE]` (aligné `FB_Cycle.st`) |
| Commentaires de fin de ligne supprimés | rétablis (rôle / unité / polarité) — §2 |
| Pas de `ReferenceStepAtError` | ajouté (R9) |
| Pas d'init sur `ReferenceStep` | `:= E_MachineReferenceStep.IDLE` |
| Cause `DOUBLE_CONFIRM` absente | ajoutée (couvre C-2) ; `ReQualificationRequired` ajouté (couvre C-1) |
| `CommitOpen/Close` sans garantie d'exclusivité | note explicite + cause dédiée |

---

## 8. ⛔ Arbitrages requis avant Stage B (corps métier)

| Id | Question | Reco orchestrateur |
|---|---|---|
| **C-1** | Après `ReferenceLossSafeStop`, faut-il une re-confirmation consciente (Reset ou re-`BtnConfirm`) avant que `MachineReferenceReady` puisse revenir TRUE ? | **OUI** — `ReQualificationRequired` latché, levé par front `Reset` uniquement. Cause `CAUSE_REF_LOST_IN_MOTION` (Latching). Conforme AF-05 « aucun redémarrage automatique ». |
| **C-2** | `ConfirmOpen` ET `ConfirmClose` au même scan : rejet total ou priorité ? | **Rejet total** — aucune transaction, cause `CAUSE_DOUBLE_CONFIRM` (Latching), guide reste en `CONFIRM_BUCKET`. |
| **C-3** | Casser la boucle `FB_ReferenceCycle.MachineReferenceReady` ↔ `FB_Bucket.ActiveOffsetValid` ? | **OUI** — `FB_ReferenceCycle` = producteur unique de la qualification ; `FB_Bucket.ActiveOffsetValid` ne référence plus `MachineReferenceReady` (il consomme `BucketCommit` + son propre `IsOpen XOR IsClosed`). Retire le terme croisé l.367 de `FB_Bucket.st`. |

**Sans décision explicite sur C-1/C-2/C-3, le Stage B n'est pas lancé** (workflow §3, criticité C4).
