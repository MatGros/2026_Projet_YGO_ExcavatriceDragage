# 🗺️ PLAN DE TÂCHE T146 — Arbitrage bridage hors homing + interlocks + garde-fou vitesse

> **C4 SÉCURITÉ** · machine réelle · ISO 13849.
> Source : `DOC/WFLOW/TASKS.yaml` → T146 (REQUALIFIÉE 2026-08-31) + `CONTRACTS/TASK_CONTRACT_T146.yaml`.
> Statut : **BRUINE DE PLAN** — ARRÊT VALIDATION HUMAINE obligatoire AVANT toute écriture (décision de posture ISO 13849).
> Date : 2026-09-01.

---

## 1 · Objectifs testables (repris du contrat)

| ID contrat | Objectif testable (résultat machine/artefact) |
|---|---|
| AC1 | Posture ISO 13849 tranchée + documentée (`DECISIONS_T146_ARBITRAGE_ISO13849.md`, visa humain) |
| AC2 | Aucun bridage fondé sur la vitesse armé tant que garde-fou non opérationnel (`SpeedGuardEnable=FALSE` documenté) |
| AC3 | `TremieFull_OR_GateRaised_DI` consommé dans le permis M3→Trémie (blocage Direction=+1, sortie -1 libre) |
| AC4 | Règle « capteur TOP haut ⇒ position connue ⇒ levée du bridage » définie + implémentée |
| AC5 | État de `FB_WinchRateInterlock` décidé (créé OU dette S5 datée/maintenue) |
| AC6 | Interlock hauteur M3 strict inchangé (`HomedAndReliable` M1∧M2, non assoupli) |
| AC7 | Struct CODE/M_MAIN : nom fichier = nom POU, ST pur |
| AC8 | Bundle + G200 + palier C PASS |

---

## 2 · Découpage en phases (séquenciel / parallèle) + dépendances

```
P0  (GATE HUMAIN)  ARBITRAGE POSTURE ISO 13849        [bloque TOUT]
     ⛔ ARRÊT VALIDATION HUMAINE C4 : trancher
        POSTURE-A = bridage plafond palier réduit hors homing
        POSTURE-B = repos capteur physique TOP assumé & documenté
        + règle TOP/lever + sort statut FB_WinchRateInterlock
     ├── Décision consignée (DECISIONS_T146_ARBITRAGE_ISO13849.md)
     └── GATE : visa humain `validated_by` rempli

P1  (docs, parallèle possible après P0)  SPECS & REGISTRES
     ├── AF_Partie-09 (arbitrage hors homing, règle TOP)     [bloque_par: P0]
     ├── AF_Partie-10 (§7.3 apprentissage, §9bis garde-fou)   [bloque_par: P0]
     ├── AF_Partie-11 (interlock trémie M3→Trémie)            [bloque_par: P0]
     └── NAMING_CONVENTION consultée (NC-100 polarité) — PAS modifiée

P2  (code, séquence de sécurité)  IMPLÉMENTATION     [bloque_par: P1]
     └── P2a GARDE-FOU EN PREMIER (non bloquant bridage vitesse)
            ├── décider état FB_WinchRateInterlock (créer OU dette S5 datée)   [AC5]
            └── s'assurer SpeedGuardEnable=FALSE si table non validée           [AC2]
     └── P2b INTERLOCK TRÉMIE → PERMIS M3→TRÉMIE (PRG_05 §1ter/§2)              [AC3]
     └── P2c RÈGLE TOP + POSTURE BRIDAGE (PRG_04 / FB_SpeedStep / FB_Safety_Winch) [AC4]
     └── P2d GATE hauteur M3 strict conservé (PRG_05:111-115)                   [AC6]

P3  (validation)  GATES MÉCANIQUES & TC      [bloque_par: P2]
     ├── bundle + G200 + palier C
     └── TC-P09 / TC-P10 / TC-P11 étendus
```
DAG :
```
P0 ──► P1 ──► P2(a→b→c→d) ──► P3
            P2a ──► P2d (l'ordre de sécurité impose le garde-fou avant le bridage)
```

---

## 3 · Plan de TEST

### Cas à couvrir
| # | Cas | Attendu | TC cible |
|---|---|---|---|
| T1 | `TremieFull_OR_GateRaised_DI=TRUE`, commande M3 vers Trémie (`Direction=+1`) | bloqué (permit Trémie FALSE), sortie `-1` libre | TC-P11 nouveau |
| T2 | `TremieFull_OR_GateRaised_DI=FALSE` : trajet Trémie normal | permit Trémie TRUE | TC-P11 régression |
| T3 | Capteur TOP haut actif (`TopPositionSensor`) hors homing | position considérée connue → bridage levé (posture B) OU plafond réduit retombe dès Homed (posture A) | TC-P09/TC-P10 |
| T4 | Hors homing, pas de capteur TOP, posture bridée | palier réduit (plafond plancher) ; protections positions actives | TC-P10 bridage |
| T5 | Interlock hauteur M3 : une hauteur non confirmée | `M3_HeightInterlockOk=FALSE` (strict, non assoupli) | TC-P11 existant |
| T6 | `SpeedGuardEnable` non opérationnel | aucun bridage fondé sur la vitesse armé ; dette S5 documentée | gate + revue |
| T7 | Structure CODE/M_MAIN | nom fichier = POU, ST pur | G310 |

### TC existants réutilisés
`TC-P09-0xx` (Encoder/Homing) · `TC-P10-055/060` (survitesse/apprentissage, AF10) ·
`TC-P11-0x` (Translation, anti-collision hauteur) · gates paliers (GUIDE_GATES_ET_TESTS_v1.2).

### Exécution
```
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report    # TremieFull + TopPositionSensor consommés
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
python TOOLS/TEST_AUTO_CI/scripts/run_tests.py ...                     # TC spécifiques selon domaine
```

---

## 4 · Plan CI

| Étape | Gate | Palier | Commande | Objectif |
|---|---|---|---|---|
| Fin P1 (docs) | G340 liens doc | A/C | `run_all_gates.py --palier C` | références AF/AF09..11 cohérentes |
| P2a | G200 liaison + code style | B/A | G200 `--report` + `--palier A` | garde-fou, câblage |
| P2b | G200 + G360 interlock sens | B/C | G200 + `--palier C` | TremieFull consommé, direction bloquée |
| P2c | G200 + G370 position calibrée | B/C | G200 + `--palier C` | règle TOP câblée |
| Fin lot | G200 + palier C complet + TC | C | `generate_codesys_bundle.py` + `G200 --report` + `run_all_gates.py --palier C` | preuve finale AC8 |

**Palier A/B/C** : A = bloc isolé (style), B = liens/dépendances (G200), C = fin de lot (structure +
bundle + TC). Voir `DOC/STDS/GUIDES/GUIDE_GATES_ET_TESTS_v1.2.md` §2.

---

## 5 · Prévision d'assignation AGENT

| Rôle | Acteur | Périmètre |
|---|---|---|
| Implémentation (P2) | Agent implémenteur (`AGY-01`, après visa P0) | PRG_04/05, FB_SpeedStep, FB_Safety_Winch, FB_EncoderReliability, FB_WinchRateInterlock (si créé) |
| Revue indépendante (double avis A/B — SAFETY_POLICY) | Agent A + Agent B indépendants | lecture read-only : arbitrage, polarité NC-100, non-assouplissement hauteur M3 |
| Décision posture (P0) | **HUMAIN / automaticien** | visa ISO 13849, choix POSTURE-A/B, règle TOP, sort FB_WinchRateInterlock |
| Validation finale | Orchestrateur (lecture `git diff` réel) | non-régression + AC remplis |

> 🛡️ **SAFETY_POLICY.md** : revue C4 en double avis parallèle A/B obligatoire ; validation finale
> jamais par l'agent qui a écrit le code ; statut `human-validated` jamais auto-attribué.

---

## 6 · Modifications DOC à prévoir

| Doc | Modification |
|---|---|
| `DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md` | §7/§11 : arbitrage hors homing, règle capteur TOP ⇒ levée du bridage |
| `DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md` | §7.3 / §9bis : état garde-fou vitesse, sort `FB_WinchRateInterlock` |
| `DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md` | §3bis/§3ter : interlock `TremieFull_OR_GateRaised_DI` dans permis M3→Trémie |
| `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T146.yaml` | cycle de vie (`status`, `execution`, `validation`) |
| `DOC/WFLOW/AUDITS/DESIGN/DECISIONS_T146_ARBITRAGE_ISO13849.md` | **à créer** : décision de posture + visa humain |
| `DOC/VERSION_HISTORY.md` | une ligne par jalon T146 |
| `NAMING_CONVENTION.md` | **NON modifié** (forbidden) — consulté pour polarité NC-100 |

---

## 7 · Arrêts de validation humaine

| Arrêt | Phase | Motif | Mention |
|---|---|---|---|
| **ARRÊT VALIDATION HUMAINE C4** | P0 | décision métier ISO 13849 (POSTURE-A/B), règle TOP, sort `FB_WinchRateInterlock` — avant toute écriture | ⛔ bloquant, visa obligatoire |
| **ARRÊT VALIDATION HUMAINE** | P2 fin | revue de sécurité du câblage TremieFull + TOP avant application CODESYS | visa orchestrateur/automaticien |
| **ARRÊT VALIDATION HUMAINE** | P3 | recettage + visa final avant de proclamer C4 conforme | SAFETY_POLICY advisory-only |

---

## 8 · Risques & garde-fous

| Risque | Mitigation |
|---|---|
| Levée du bridage TOP assouplit l'interlock hauteur M3 | AC6 : gate strict conservé, TC-P11 anti-collision rejoué |
| Bridage fondé sur la vitesse armé sans table validée | AC2 : `SpeedGuardEnable=FALSE` tant que la table SpeedBandMaxMps n'est pas prouvée en charge |
| Polarité `TremieFull_OR_GateRaised_DI` ambigüe (TRUE=bloqué vers Trémie, NC-100) | devoir d'alerte + vérif G200, blocage directionnel uniquement (sortie -1 libre) |
| `FB_WinchRateInterlock` créé par erreur sans contrat | AC5 : son sort est DÉCIDÉ en P0 (créé OU dette datée), pas créé hors contrat |
| Agent s'auto-valide C4 | SAFETY_POLICY : double avis A/B + visa humain + validation orchestrateur |
