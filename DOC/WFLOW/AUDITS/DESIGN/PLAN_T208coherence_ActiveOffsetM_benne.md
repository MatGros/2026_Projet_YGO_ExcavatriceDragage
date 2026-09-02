# PLAN T208 — Cohérence ActiveOffsetM / état benne (faux MecaE)

> Tâche : **T208** · criticité **C2** · domaine **TREUILS / SÉCURITÉ** · stratégie **patch**.
> Chapô : préparer le livrable *non-code* (contrat + plan) → puis implémentation ST en phase 2.
> Contrat : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T208.yaml` (ce plan le reflète).
> Date : 2026-09-01 (préparation contrat + plan).

---

## 0 · Cause racine (synthèse du diagnostic)

```
ActiveOffsetM ← dépend de l'état benne MEMORISÉ (latched), jamais de la position physique :
  FB_Bucket.st : CloseReq OR IsClosed → ActiveOffsetM := OffsetCloseM (=15m)
  IsOpen/IsClosed = états purement latched, JAMAIS reconciliés avec la position.

Cas observé : CablePosM(M1)=1.31m · ExpectedOtherWinchPosM=-13.7m → ActiveOffsetM=15m
  alors que 2 treuils à 1.31m (benne ouverte, offset attendu 0m).
  ABS(M1 - M2 + ActiveOffsetM) = 15m > 2.5m → FAUX MecaE.

Cas d'incohérence : cycle benne interrompu, jog manuel M2 hors FB_Bucket, boot RETAIN
  périmé (F08) → IsClosed=TRUE périmé → ActiveOffsetM=15m.
```

**Décision de design validée (2 challenges MAJOR)** : ne **PAS** réconcilier
`IsOpen`/`IsClosed` depuis `DeltaPosition_M` (= raisonnement circulaire qui masque une
vraie désynchronisation). Détecter la contradiction état<->position → `StateIncoherent`,
adresser une sortie dédiée `BucketStateCoherent := NOT StateIncoherent`, gater la
**COMMANDE** (StartStop, PAS SafeStop), geler plutôt que forcer `ActiveOffsetM`, et
re-qualifier l'état via l'opérateur (IHM).

---

## 1 · Objectifs testables (repris du contrat)

| ID | Objectif testable (machine-observable) | Vérifié par |
|---|---|---|
| GT1 | Au boot, position M2 hors fenêtres `[LastPosM2Open/Close ± CoherenceLimitM]` → `StateIncoherent=TRUE`, `ActiveOffsetValid=FALSE`, IsOpen/IsClosed non modifiés | TC boot hors-fenêtres (AC1) |
| GT2 | Au boot `IsOpen=TRUE ET IsClosed=TRUE` → `StateIncoherent=TRUE` | TC-P10-047.2 (AC2) |
| GT3 | `BucketStateCoherent := NOT StateIncoherent` gage StartStop (PAS SafeStop), MecaE reste armé, ActiveOffsetM jamais forcé | grep + TC (AC3) |
| GT4 | Gate commande = `HomedM1 AND HomedM2 AND BucketStateCoherent` | inspection (AC4) |
| GT5 | `IsOpen`/`IsClosed` jamais affectés depuis `DeltaPosition_M` (invariant circulaire) | grep 0 affectation (AC5) |
| GT6 | `M2_LimitShift` gagé sur `BucketStateCoherent` | inspection PRG_04 (AC6) |
| GT7 | FB_Cycle X3/X6 ne progresse pas quand `BucketStateCoherent=FALSE` | inspection FB_Cycle (AC7) |
| GT8 | Message IHM StateIncoherent + re-confirmation opérateur ouvert/fermé | AF-14 + BannerFormatter (AC8) |
| GT9 | En état cohérent (1.31m/1.31m, benne ouverte) : ActiveOffsetM=0, `ABS(M1-M2+ActiveOffsetM)=0 ≤ 2,5m`, **aucun faux MecaE** | TC non-régression (AC9) |
| GT10 | Non-régression synchro/cycle en état cohérent (TC-P10-023..048.1, T196-001/002) | gates palier C + G200 (AC10) |
| GT11 | Fichier POU = nom POU ; suffixe = langage ST du bundle (structurel) | bundle/gate (AC11) |

---

## 2 · Découpage en phases (séquencées / parallèles) — DAG

![DAG](texte)
```
P0  Cadrage & point bloquants doc          [bloque tout]
   ├─ P0a  Mapping ErrorId AF-10 FAUX     → corriger AF-10
   ├─ P0b  CoherenceLimitM 3 valeurs      → viser 1.0 unique (visa V2)
   ├─ P0c  Boot RETAIN périmé (F08)       → décision de gestion boot
   ├─ P0d  Doctrine d'arrêt M1_Busy (V4)  → décision
   └─ GATE : ARRÊT VALIDATION HUMAINE (contrat validé) AVANT P1
P1  DUT/état : ST_fbBucket_State (+ StateIncoherent, BucketStateCoherent)   [bloque P2]
   └─ GATE : CI iso (interface déclarée, 0 régression)
P2  FB_Bucket : détection incohérence + gate commande                       [bloque P3, P5]
   ├─ boot-hors-fenêtres, TRUE/TRUE, non-forçage ActiveOffsetM
   ├─ sortie BucketStateCoherent, gate StartStop (PAS SafeStop), MecaE armé
   ├─ invariant : IsOpen/IsClosed jamais depuis DeltaPosition_M
   └─ GATE : TC bloquants test_fb_bucket.st verts + AC1..AC5
P3  PRG_04 : gate M2_LimitShift sur BucketStateCoherent                      [bloque P6]
   └─ GATE : G200 liaison + TC M2_LimitShift
P4  FB_Cycle : X3/X6 ne progressent pas si non-cohérent                     [bloque P6] (parallèle P3)
   └─ GATE : TC cycle benne
P5  IHM : message StateIncoherent + re-confirmation ouvert/fermé           [bloque P6] (parallèle P3/P4)
   └─ GATE : AF-14 + BannerFormatter
P6  INTÉGRATION + AUTO-VÉRIFICATION                                        [bloque CLOTURE]
   ├─ bundle régénéré + G200 liaison PASS + run_all_gates --palier C
   └─ GATE : restitution bandeau conformité → VALIDATION HUMAINE
```

**Dépendances (`bloque_par`)**
- P1 `bloque_par` : P0.
- P2 `bloque_par` : P1.
- P3/P4/P5 `bloque_par` : P2 (en parallèle entre elles).
- P6 `bloque_par` : P3, P4, P5.
- Clôture `bloque_par` : P6.

> P3/P4/P5 sont **parallélisables** (fichiers indépendants) — séquencer uniquement
> l'interface : d'abord le DUT (P1) puis FB_Bucket (P2), ensuite les consommateurs.

---

## 3 · Plan de TEST

### 3.1 Cas unitaires à couvrir (STruCpp CI, `test_fb_bucket.st`)
| Cas | Vecteur | Attendu |
|---|---|---|
| Boot hors-fenêtres | position M2 hors `[±CoherenceLimitM]` autour de LastPosM2Open *et* Close | `StateIncoherent=TRUE`, `ActiveOffsetValid=FALSE`, IsOpen/IsClosed inchangés |
| Boot TRUE/TRUE | `IsOpen=TRUE ET IsClosed=TRUE` | `StateIncoherent=TRUE` (déja TC-P10-047.2) |
| Non-forçage | état inconnu → commande benne demandée | ActiveOffsetM non réécrit ; gate StartStop bloqué ; SafeStop NON activé ; MecaE armé |
| Invariant circulaire | forcer `DeltaPosition_M` | 0 affectation vers IsOpen/IsClosed |
| M2_LimitShift | benne incohérente + butée haute M2 | M2_LimitShift gagé (pas de dépassement) |
| Cycle X3/X6 | `BucketStateCoherent=FALSE` | pas de progression du cycle benne |
| Non-régression | état cohérent benne ouverte/fermée | ActiveOffsetM 0/15 cohérent ; synchro/M2PositionCorrected inchangées |

### 3.2 Tests existants à conserver (non-régression)
- `TC-P10-023..048.1` (synchro / benne / MecaE)
- `TC-P10-047.2` (boot TRUE/TRUE)
- `T196-001/002` (bucket state)
- `TC-P10-030`, `TC-P10-046.1` (confirm MAINT / timeouts benne) — ne pas casser

### 3.3 Auto-vérification mécanique (obligatoire)
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py . # bundle PLCopenXML
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report    # liaison PASS 0 erreur
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C       # gates palier C
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py                  # TOUS les gates (fin)
```

---

## 4 · Plan CI (gates à chaque étape, palier A/B/C)

| Étape | Palier | Gate | Commande |
|---|---|---|---|
| P0 | — | Contrat valide | `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T208.yaml` |
| P1 | A | Interface iso | `run_all_gates.py --palier A` |
| P2 | A | TC bloquants FB_Bucket | `run_all_gates.py --palier A` + test_fb_bucket vert |
| P3 | B | G200 liaison | `G200_check_linkage.py --report` |
| P4 | B | TC cycle | `run_all_gates.py --palier B` |
| P5 | B | AF-14 + BannerFormatter | `run_all_gates.py --palier B` |
| P6 | **C** | Bundle + G200 + gates C | `generate_codesys_bundle.py` → `G200_check_linkage.py --report` → `run_all_gates.py --palier C` |
| Fin | **C** | Tous gates | `run_all_gates.py` (21 gates) |

Bandeaux de restitution obligatoires (bundle frais + gates verts, cf. AGENTS.md).

---

## 5 · Prévision d'assignation AGENT

| Rôle | Acteur | Périmètre |
|---|---|---|
| **Implémentation** | agent de détail (petits increments) | P1→P5, code ST + notes d'application |
| **Revue indépendante** | orchestrateur / second agent (lecture du `git diff` réel, JAMAIS l'implémenteur) | valide chaque phase avant P6 ; valide la non-régression et l'invariant anti-circulaire |
| **Challenge design (déjà réalisé)** | 2 challenges experts MAJOR | design corrigé validé (state, gate, invariant) |
| **Validation humaine finale** | humain / orchestrateur | P0 (avant code) et clôture (P6 après gates) |

> Règle AGENTS.md : la validation finale reste à l'orchestrateur/humain (lecture du
> `git diff` réel), jamais à l'agent qui a produit le code.

---

## 6 · Modifications DOC à prévoir

| Fichier | Contenu |
|---|---|
| `DOC/AF/AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md` | Description `StateIncoherent` / `BucketStateCoherent`, **correction mapping ErrorId (FAUX actuellement)**, `CoherenceLimitM` unique (viser 1.0, visa V2) |
| `DOC/AF/AF_Partie-14_Fonction_Troubleshooting_v1.4.md` + `FB_TroubleshootingView_v1.2.md` | Message IHM StateIncoherent + action re-confirmation ouvert/fermé |
| `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md` | Gating FB_Cycle X3/X6 sur l'état benne cohérent |
| `DOC/STDS/NAMING_CONVENTION.md` | **Lecture seule** (norme transverse, ne pas modifier par la tâche) — vérifier le vocabulaire `StateIncoherent`/`BucketStateCoherent` (PascalCase, NC-xxx) |
| Registres | `DOC/WFLOW/TASKS.yaml` (T208 : statut, date ISO) ; éventuel registre des décisions `DOC/WFLOW/AUDITS/DESIGN/` (fichier design T208 à créer si besoin) |
| Contrat | `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T208.yaml` (ce document) |

---

## 7 · Arrêts de validation humaine

- **ARRÊT VALIDATION HUMAINE (C0, bloquant)** — à la fin de **P0** : point bloquants doc
  (mapping ErrorId AF-10, `CoherenceLimitM`=1.0 visa V2, boot RETAIN F08, doctrine M1_Busy V4)
  + validation du contrat **avant** toute écriture ST.
- **ARRÊT VALIDATION HUMAINE (clôture)** — à la fin de **P6** : bundle + G200 + gates palier C
  verts, avant intégration CODESYS manuelle et clôture `T208`.

> Criticité C2 → contrat obligatoire (fait). Tout écart en cours de route remonte
> IMMÉDIATEMENT (devoir d'alerte, cf. contrat §7).
