# Extraction code — FB_Safety_EmergencyManagement (v1.0)

> Source : `CODE/AU/*`, `CODE/MAIN/PRG_00_Inputs.st`, `PRG_10_Outputs_LD.st`, `PRG_09_Supervision.st`,
> `CODE/SIMULATION/FB_Sim_Safety.st`, DUT IHM `ST_ModesCmd` / `ST_ModesState`.
> Statut : fiche de travail **code → doc**. Ne remplace pas AF01 ni la spec FB.
> Objectif : inventorier fonctionnalités, interfaces, liaisons et écarts avant normalisation bus/DUT.

---

## Règle d'utilisation

| Statut | Sens |
|---|---|
| `VERIFIE` | Lu dans le code actif ; doit survivre sauf décision explicite. |
| `ECART` | Incohérence code↔code, code↔DUT IHM, ou code↔archi cible AF02/03. |
| `CIBLE` | Alignement proposé sur architecture CFC/DUT ; **pas encore décidé**. |
| `TBD` | Besoin de validation humaine. |

---

## 1. Composition (POU)

| POU | Fichier | Rôle |
|---|---|---|
| `FB_Safety_EmergencyManagement` | `CODE/AU/FB_Safety_EmergencyManagement.st` | Composite parent : appelle Logic puis Output, propage sorties. |
| `FB_Safety_EmergencyManagementLogic` | `CODE/AU/FB_Safety_EmergencyManagementLogic.st` | Décision, machine d'état armement, latches défaut, consignes logiques. |
| `FB_Safety_EmergencyManagementOutput` | `CODE/AU/FB_Safety_EmergencyManagementOutput.st` | Pilote physique : copie `Cmd` → sorties `*_RQ` ; fail-safe si `Enable=FALSE`. |
| `ST_EmergencyManagementCmd` | `CODE/AU/ST_EmergencyManagementCmd.st` | DUT interne Logic → Output (3 BOOL). |
| `FB_Sim_Safety` | `CODE/SIMULATION/FB_Sim_Safety.st` | Sim boucle AU + latch contacteur (consommateur des sorties). |

Instance unique : `PRG_10_Outputs_LD.instSafetyEmergencyManagement`.

Commentaire header de `ST_EmergencyManagementCmd.st` dit encore `ST_EmergencyChainCmd` → **ECART** nom/commentaire.

---

## 2. Interface publique composite

### VAR_INPUT

| Signal | Type | Sens vérifié |
|---|---|---|
| `Enable` | BOOL | Gate : `FALSE` ⇒ Logic neutralise + Output force sorties `FALSE`. Instance : `TRUE` fixe. |
| `Reset` | BOOL | Front interne (`R_TRIG`) : acquitte `RedundancyTestFailed` ; acquitte `EmergencyArmingFailed` **seulement si** `PowerContactorEngaged=TRUE`. |
| `ArmRequest` | BOOL | Front interne : démarre séquence si preconditions. Source : `GVL_IHM.Modes.Cmd.BtnEmergencyArming`. |
| `EmergencyChainClosed` | BOOL | Boucle AU saine (précondition armement + critère auto-test). Source : `PRG_00_Inputs.EmergencyChainClosed`. |
| `PowerContactorEngaged` | BOOL | Contacteur engagé (portail maître + confirmation armement). Source : `PRG_00_Inputs.PowerContactorEngaged`. |
| `PowerCutOffRequest` | BOOL | Demande coupure métier agrégée. Source : OR des 3 `FB_Safety_*.PowerCutOff` dans `PRG_10`. |
| `BtnEmergencyCutOff` | BOOL | Coupure IHM maintenue (ouvre A et B). Source : `GVL_IHM.Modes.Cmd.BtnEmergencyCutOff`. |

### VAR_OUTPUT

| Signal | Type | Sens / polarité |
|---|---|---|
| `Ready` | BOOL | `= Enable` (pas de notion Ready métier riche). |
| `Busy` | BOOL | `ArmingSeqStep <> 0`. |
| `Done` | BOOL | `= PowerContactorEngaged` (contacteur engagé). |
| `Error` | BOOL | `ErrorId <> 0`. |
| `ErrorId` | WORD | bit0 `RedundancyTestFailed`, bit1 `EmergencyArmingFailed`. |
| `PowerCutOff_A_RQ` | BOOL | **Fail-safe maintien** : `TRUE` = voie A maintenue/OK ; `FALSE` = ouverture. |
| `PowerCutOff_B_RQ` | BOOL | Idem canal B. |
| `EmergencyArming_RQ` | BOOL | Impulsion réarmement pendant étape 5 (durée timer 1 s). |
| `ArmingSeqStep` | INT | 0=IDLE … 6=Confirm (voir §4). |
| `RedundancyTestFailed` | BOOL | Latch auto-test A ou B échoué. |
| `EmergencyArmingFailed` | BOOL | Latch : pas de confirmation contacteur sous 2 s. |
| `EmergencyArmingLockoutActive` | BOOL | Verrouillage 5 s après échec armement. |

### DUT interne `ST_EmergencyManagementCmd`

| Champ | Polarité |
|---|---|
| `PowerCutOff_A_Cmd` | TRUE = maintien OK |
| `PowerCutOff_B_Cmd` | TRUE = maintien OK |
| `EmergencyArming_Cmd` | TRUE = pulse actif |

---

## 3. Fonctionnalités extraites (checklist)

| ID | Fonction | Statut | Détail code |
|---|---|---|---|
| F01 | Neutralisation `Enable=FALSE` | VERIFIE | Sorties A/B/Arming à FALSE ; latches et step remis à 0 dans Logic. |
| F02 | Maintien fail-safe A/B | VERIFIE | `Cmd.PowerCutOff_* := NOT PowerCutOffRequest AND NOT ForceTest* AND NOT BtnEmergencyCutOff AND NOT RedundancyTestFailed`. |
| F03 | Coupure métier `PowerCutOffRequest` | VERIFIE | Ouvre A **et** B tant que TRUE. |
| F04 | Coupure IHM `BtnEmergencyCutOff` | VERIFIE | Ouvre A **et** B tant que TRUE (niveau, pas front). |
| F05 | Auto-test redondance A puis B | VERIFIE | Étapes 1–4, 200 ms chacune ; si `EmergencyChainClosed` reste TRUE pendant coupe d'un canal ⇒ `RedundancyTestFailed`. |
| F06 | Impulsion réarmement 1 s | VERIFIE | Étape 5 : `EmergencyArming_Cmd` TRUE pendant `T#1s`. |
| F07 | Confirmation contacteur 2 s | VERIFIE | Étape 6 : succès si `PowerContactorEngaged` ; sinon latch fail + lockout. |
| F08 | Lockout 5 s après fail armement | VERIFIE | `TonArmingLockout` ; bloque nouveau départ séquence. |
| F09 | Déclenchement armement sur front seulement | VERIFIE | `ArmReqEdge` + step=0 + `EmergencyChainClosed` + NOT lockout + NOT `PowerContactorEngaged`. |
| F10 | Pas d'auto-réarmement | VERIFIE | Aucun chemin sans front `ArmRequest`. |
| F11 | Reset `RedundancyTestFailed` sur front | VERIFIE | Sans condition contacteur. |
| F12 | Reset `EmergencyArmingFailed` conditionnel | VERIFIE | Front Reset **et** `PowerContactorEngaged=TRUE`. |
| F13 | Agrégation demandes PowerCutOff domaines | VERIFIE | `PRG_10` : OR M1/M2/M3 safety — **hors** FB (câblage appelant). |
| F14 | Publication sorties physiques | VERIFIE | `PowerKeepAlive_A/B_RQ := PowerCutOff_A/B_RQ` ; `EmergencyArming_RQ`. |
| F15 | Publication GVL_Global états armement | VERIFIE | Pulse, Lockout, ArmingSeqStep (pas Failed/Redundancy). |
| F16 | Simulation chaîne + contacteur | VERIFIE | `FB_Sim_Safety` : chain = A AND B AND NOT BtnAU ; latch contacteur sur pulse arming. |
| F17 | Filtrage E/S acquisition | VERIFIE | `PRG_00` : `PowerContactorEngaged_DI` → `PowerContactorEngaged` ; `EmergencyChainClosed_DI` → `EmergencyChainClosed` (anti-rebond 20 ms). |
| F18 | Portail `PowerContactorEngaged` vers métiers | VERIFIE | Consommé par Modes, Cycle, Safety domaines, Winch, Translation, Encoders, Joystick, interlocks finaux. |
| F19 | Mapping IHM States armement complets | ECART | `ST_ModesState` définit `EmergencyArmable/Busy/Failed/…` mais `PRG_09` ne mappe que `PowerContactorEngaged` (lu à date). |
| F20 | Câblage SimBench KeepAlive / Arming | CORRIGE | `PRG_00` : A/B ← `PowerKeepAlive_*_RQ`, Arming ← `EmergencyArming_RQ` (Q FB, scan N-1). |

---

## 4. Machine d'état armement (`ArmingSeqStep`)

```text
0 IDLE
  | ArmReq front + EmergencyChainClosed + NOT lockout + NOT PowerContactorEngaged
1 TestA     (ForceTestA, 200 ms) — si EmergencyChainClosed encore TRUE → RedundancyTestFailed → 0
2 RestoreA  (200 ms) — si EmergencyChainClosed FALSE → 0 ; si TRUE → 3
3 TestB     (ForceTestB, 200 ms) — idem fail redondance → 0
4 RestoreB  (200 ms) — si chain OK → 5 else → 0
5 Pulse     EmergencyArming_Cmd = TRUE, 1 s → 6
6 Confirm   si PowerContactorEngaged → 0 succès
            si timeout 2 s → EmergencyArmingFailed + Lockout 5 s → 0
```

Timers nommés : `TonTestA/B`, `TonRestoreA/B`, `TonArmingPulse`, `TonArmingConfirm`, `TonArmingLockout`.

**Note VERIFIE** : pendant étapes 1–4, `RedundancyTestFailed` n'est **pas** re-testé comme frein de départ ; le départ exige seulement step=0, chain, not lockout, not contactor. Un `RedundancyTestFailed` encore latche ouvre toutefois A et B (F02) tant que non acquitté.

**Note VERIFIE** : `EmergencyArmingFailed` latche **n'interdit pas** un nouvel `ArmRequest` après fin de lockout (seul lockout + preconditions). Reset conditionnel pour lever le latch.

---

## 5. Cartographie des liaisons (état actuel)

```text
[Physique DI]
  EmergencyChainClosed_DI ──FB_Input──► PRG_00.EmergencyChainClosed ──► FB.EmergencyChainClosed
  PowerContactorEngaged_DI ──FB_Input──► PRG_00.PowerContactorEngaged ──► FB + tous métiers

[Safety domaines]
  FB_Safety_Winch M1/M2.PowerCutOff ──┐
  FB_Safety_Translation.PowerCutOff ──┼─ OR (PRG_10 local) ──► FB.PowerCutOffRequest
                                      │
[IHM Cmd]
  BtnEmergencyArming ─────────────────┼─► FB.ArmRequest
  BtnEmergencyCutOff ─────────────────┼─► FB.BtnEmergencyCutOff
  BtnFaultReset ──PRG_09──► FaultMachineReset_IHM ──► FB.Reset

[FB sorties]
  PowerCutOff_A/B_RQ ──► PowerKeepAlive_A/B_RQ (Q physiques)
  EmergencyArming_RQ ──► EmergencyArming_RQ (Q physique)
  états ──► PRG_10 VAR_OUTPUT + partiel GVL_Global

[IHM State]  (ECART mapping incomplet)
  ST_ModesState.Emergency*  … non tous écrits dans PRG_09
```

---

## 6. Écarts vs architecture cible (AF02/AF03 + synthèse bus)

| # | Écart | Impact | Proposition `CIBLE` (à valider) |
|---|---|---|---|
| E1 | Agrégation `PowerCutOff` en OR local `PRG_10`, pas de DUT safety agrégé | CFC illisible ; producteur de l'OR anonyme | DUT `ST_Safety_PowerCutOffRequest` (ou champ dans bus safety machine) produit par `PRG_SAFETY_CFC` |
| E2 | Double nom `PowerCutOff_*_RQ` (FB) vs `PowerKeepAlive_*_RQ` (E/S) | Confusion polarité | Garder E/S device `PowerKeepAlive_*` ; alias doc clair ; éventuellement renommer sorties FB en `PowerKeepAlive_*` **TBD** |
| E3 | États armement via `GVL_Global` + VAR_OUTPUT PRG_10 | Contredit « GVL ≠ bus commande interne » | DUT `ST_State_Emergency` / `ST_Diag_Emergency` producteur unique Outputs/Emergency |
| E4 | IHM : champs `ST_ModesState` non mappés | IHM aveugle sur armable/busy/fail | Mapping Supervision depuis sorties FB (ou bus State) |
| E5 | SimBench câble mal KeepAlive/Arming | Tests sim non représentatifs de la chaîne | Brancher A/B sur `PowerKeepAlive` réels + pulse sur `EmergencyArming_RQ` FB |
| E6 | Composite dans Outputs_LD uniquement | Conforme AF02 (« AU dans chaîne sortie ») | **Conserver** instance dans `PRG_OUTPUTS_LD` ; pas de page CFC parallèle |
| E7 | Profil contrat : pas `SafeStop`/`StartStop` (OK) | Conforme AF03 brique non-mouvement | Documenter profil « barrière puissance / safety transverse » |
| E8 | `Ready`/`Done` sémantique faible | Peu utiles pour tests | Option : `Ready=Enable AND NOT Error`, `Done` = armement réussi pulse — **TBD** |
| E9 | Commentaire `ST_EmergencyChainCmd` | Bruit doc | Corriger header |
| E10 | `EmergencyArmingFailed` ne bloque pas un nouvel essai après lockout | Comportement retenu AF01 ; à confirmer métier | Rester code actuel sauf décision contraire |

---

## 7. Consommateurs de `PowerContactorEngaged` / `EmergencyChainClosed` (hors FB)

| Signal | Producteur | Consommateurs principaux |
|---|---|---|
| `PowerContactorEngaged` | `PRG_00_Inputs` | Safety M1/M2/M3, Modes, Cycle, Winch×2, Translation, Encoders, Joystick, Dive/Extraction, interlocks finaux, Kobold enable, IHM `Modes.State` |
| `EmergencyChainClosed` | `PRG_00_Inputs` | FB Emergency, Kobold enable, troubleshooting, preflight |
| `PowerCutOff` domaine | `FB_Safety_*` | OR → FB Emergency ; IHM safety ; troubleshooting |

---

## 8. Points de validation déjà liés (AF01)

| TC | Couvre |
|---|---|
| TC-P01-001 | AU physique (SITE) |
| TC-P01-002 | Perte maintien A/B |
| TC-P01-003 | Front armement + pulse 1 s |
| TC-P01-004 | Latch `EmergencyArmingFailed` + Reset conditionnel |
| TC-P01-005 | Acquittement ≠ réarmement |
| TC-P01-006 | Auto-test A/B + `RedundancyTestFailed` |
| TC-P01-007 | Lockout 5 s |

Manques tests AUTO suggérés (non encore dans AF01) : F03 PowerCutOffRequest, F04 BtnCutOff, F01 Enable, E5 non-régression sim.

---

## 9. Livrables doc dérivés

| Document | Rôle |
|---|---|
| Spec FB AU (annexe P01, racine DOC) | Constitution, séquence, contrats, TC-P01, plan normalisation bus. |
| AF01 §5 | Reste propriétaire métier chaîne électrique ; pointe la spec FB. |
| AF02 / AF03 | Renvois bus / profil sans dupliquer la séquence. |

---

## 10. Décisions requises avant code

1. Valider comportement F12/E10 (Reset conditionnel + nouvel essai avec latch fail encore actif).
2. Choisir noms sorties FB : garder `PowerCutOff_*_RQ` ou aligner `PowerKeepAlive_*`.
3. Valider DUT cibles : `ST_Safety_PowerCutOffAggregate`, `ST_State_Emergency`, `ST_Diag_Emergency` (noms exacts).
4. Priorité correctifs : E5 SimBench + E4 mapping IHM vs refonte DUT complète.
5. Confirmer instance unique reste dans `PRG_OUTPUTS_LD`.
