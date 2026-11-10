# 🧪 Étude / Review / Challenge — T260 : Step de pré-validation fermeture benne (cycle homing)

> **Statut** : ÉTUDE — aucune modification de code. Décisions à valider avant implémentation.
> **Contrat** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T260_HOMING_PREVALIDATION_BENNE.yaml`
> **Contexte** : session 2026-09-06 (diagnostic HX2 bloqué + revert complet à `5b2df2c7`).
> **FB concerné** : `CODE/G_CYCLE/FB_CycleMachineHoming.st` (GRAFCET HX0..HXF).

---

## 1. 🎯 Besoin exprimé

Avant la montée couplée M1+M2 vers le capteur haut (référencement), l'opérateur doit :
1. pouvoir **ouvrir / fermer la benne** (palier 1, **sans FDC logiciel** — machine non référencée),
2. **confirmer visuellement** « benne fermée » par un geste explicite,
3. **ensuite seulement** le cycle autorise la montée (HX2).

Raison métier : la référence machine est prise **benne fermée** (AF-09 §5, offset `Close`). Sans
homing, aucune position n'est fiable → **seul l'opérateur** peut valider l'état benne.

---

## 2. 🔍 État actuel (baseline `5b2df2c7`)

GRAFCET `FB_CycleMachineHoming` :

```
HX0_REPOS → HX1_CHOICE → HX2_CLIMB → HX2N_NEUTRAL → HX3_HOME_AXES
          → HX3N_PAUSE → HX4_BUCKET_ADJUST → HX5_BUCKET_COMMIT → HX6_HOMED → (HX0)
                                                          HXF_FAILED (sur défaut, sortie Reset)
```

- `HX1_CHOICE` : annonce + choix. Transition → HX2/HX2N sur `ExplicitValidationPulse` (motif 3
  appuis JOY) en MAINT_N2. **Aucune manœuvre benne possible en HX1.**
- `HX4_BUCKET_ADJUST` : ajustement benne **APRÈS** montée + homing au vol, avant le commit HX5.
- La benne (`CmdBucketOpen/Close`) n'est commandée par le cycle qu'en **HX4**.

### Verrou chicken-egg (cause du blocage HX2 diagnostiqué)

| Permis | Condition bloquante pré-homing |
|---|---|
| `EffectivePermitBucket_Open/Close` (PRG_04:1075-1084) | `AND EncoderM1.Homed AND EncoderM2.Homed` → FALSE |
| `M2AscentPermitApplied` (PRG_04:1088) | `AND (NOT instBucket.M2_RunRequest OR EffectivePermitBucket_Close)` |
| `FB_Bucket` cause 4 « codeurs non référencés » | latchée dès le 1er scan sous puissance |
| Butée haute soft `FB_Safety_Winch` | position codeur fantôme (~4100 m) → `AscentBlockedByTopLimit` |
| `FB_Safety_Winch.InReferencingMode` | = `HomingLifecycle.Busy` → vrai ~1 scan en HX3 seulement, **jamais en HX2** |

→ Pour référencer il faut monter ; pour monter il faut des permis qui exigent d'être référencé.

---

## 3. 🧱 Conception proposée

### Option A (retenue pour l'étude) — étape GRAFCET dédiée `HX1B_BUCKET_PRECHECK`

```
HX0 → HX1 (aiguillage) → HX1B_BUCKET_PRECHECK → HX2_CLIMB → …
```

- **Enum** : `HX1B_BUCKET_PRECHECK := 10` (valeur hors séquence → **zéro renumérotation** HX2..HXF,
  donc zéro ripple sur les tests HX2..HXF, le force-step 0..9, `E_MachineHomingStep`).
- **HX1** devient un aiguillage transitoire : en MAINT_N2 → HX1B directement (l'entrée consciente
  a déjà eu lieu en HX0 : StartRequest / motif 3 appuis / auto-armement). En N1 → rester, guider vers N2.
- **HX1B** :
  - `IF BucketPermit AND JoystickPull THEN CmdBucketClose := TRUE; ELSIF BucketPermit AND JoystickPush THEN CmdBucketOpen := TRUE;`
  - treuils M1/M2 à 0 (RAZ tête de scan)
  - transition → HX2 (ou HX2N si `TopPositionSensor`) sur **geste de validation** (voir Challenge Q3),
    joystick au neutre, `WinchesMechanicallyStopped`
  - abort : `Mode <> MAINT_N2` → HX0 ; `AxisHomingError OR MotionOutOfPhase` → HXF
  - `SettleGraceTimer` armé sur HX1B (garde dérive treuil pendant manœuvre benne)
- **Guide §10** : nouveau libellé (réutiliser `E_MachineHomingStep.AWAIT_BUCKET_CONFIRM`, pas de
  nouvelle valeur enum guide).
- **Force-step §4bis** : `LIMIT(0, …, 10)` + `10: SeqStep := HX1B_BUCKET_PRECHECK`.

### Option B — sous-état de HX1 (pas de nouvelle valeur enum)

HX1 porte lui-même les actions benne + la validation. Moins de ripple enum/tests, mais HX1
n'est plus « annonce pure » → sémantique diluée, `CycleRunning`/`M3Locked` à revoir. **Non retenue** :
mélange responsabilités, viole R1/R3 (GUIDE_SEQUENCEUR).

---

## 4. ⚠️ Le point dur — rendre la benne physiquement mobile en HX1B

**Constat REX 2026-09-06** : la tentative « rapide » a cassé MAINT_N1.

| Modif tentée | Effet de bord observé |
|---|---|
| `ManualBucketJogActive := … AND NOT MachineHoming.Active` | En **MAINT_N1**, le cycle auto-arme jusqu'à HX1 → `MachineHoming.Active` (élargi à HX1) devient TRUE → jog benne N1 **bloqué**. Régression. |
| `MachineHomingActive := (SeqStep <> HX0)` (vrai dès HX1) | Élargit **toutes** les relaxations PRG_04 à HX1, y compris en N1 (auto-arm). Fuite de périmètre. |
| `EffectivePermitBucket_* := … OR MachineHoming.Active` | Lève le gate `Homed` trop largement (HX1..HX6, N1 inclus si auto-arm). |

**Règle qui en découle (dans le contrat, AC5/AC6)** :
> Toute relaxation de permis benne pour HX1B est **gardée par `SeqStep = HX1B_BUCKET_PRECHECK`
> exactement** — jamais par `MachineHoming.Active`, jamais par `>= HX1`, jamais par un flag qui
> vit en N1.

### Relaxation minimale à étudier (PRG_04)

Publier depuis le FB un flag **`BucketPrecheckActive`** (nouvelle sortie, `:= SeqStep = HX1B`),
consommé par PRG_04 **uniquement** pour :
- `EffectivePermitBucket_Open/Close` : `… AND (BucketPrecheckActive OR (EncoderM1.Homed AND EncoderM2.Homed))`
- `M2AscentPermitApplied` / `M2DescendPermitApplied` : bypass de la défense-en-profondeur benne
  quand `BucketPrecheckActive`
- **NE PAS** toucher `ManualBucketJogActive` (le jog manuel n'est pas le chemin HX1B : la benne y
  est pilotée par le cycle via `CmdBucketOpen/Close` → `ReqProgram.ReqBucket`).

À vérifier en analyse statique **avant code** : la chaîne
`FB_CycleMachineHoming.CmdBucketClose → PRG_03:356-360 (override) → ReqBucket.ReqClose → instBucket → M2_ReqAscent → M2AscentPermitApplied → FB_Winch M2` est bien complète et fermée par `BucketPrecheckActive` seul.

---

## 5. 🥊 Challenge — questions à trancher AVANT de coder

| # | Question | Enjeu | Reco étude |
|---|---|---|---|
| Q1 | Nouvelle valeur enum (Option A) vs sous-état HX1 (Option B) ? | ripple tests / lisibilité GRAFCET | **A** (`:= 10`, hors séquence) |
| Q2 | HX1B accessible en **N1** ou **N2 uniquement** ? | l'auto-armement atteint HX1 en N1 | **N2 uniquement** : HX1→HX1B seulement si `Mode = MAINT_N2` ; en N1 rester HX1 |
| Q3 | Validation par **bouton IHM dédié** (`ST_CycleMachineHomingCmd.BtnValidate` seul, nouvel input FB) ou **motif 3 appuis JOY** (`ExplicitValidationPulse`, déjà là) ? | UX + surface de modif (input FB + câblage PRG_02) | à trancher avec l'opérateur — **3 appuis** = zéro ajout d'interface ; **bouton** = plus clair mais +1 input |
| Q4 | HX4_BUCKET_ADJUST **conservé** (ajustement fin post-homing) ou **fusionné** dans HX1B ? | double manip benne | **conservé** — HX1B = pré-verif grossière avant montée ; HX4 = calage fin avant commit sur datum établi |
| Q5 | En HX1B, la benne peut-elle rester **ouverte** si l'opérateur le décide (bloc rocheux, cf. AF-10 §7.5 / RES-004) ? | monter benne ouverte = risque géométrique | **fermeture requise** avant validation OU alerte explicite « validé BENNE OUVERTE » tracée ; RES-004 reste ouverte, ne pas trancher ici |
| Q6 | Périmètre exact de la relaxation permis (§4) : nouveau flag `BucketPrecheckActive` vs réutiliser un existant ? | fuite de périmètre = régression N1 | **nouveau flag dédié**, garde `SeqStep = HX1B` stricte |
| Q7 | Fail-safe « benne SANS FDC » : qu'est-ce qui arrête la sur-course ? | intégrité mécanique | butée mécanique physique + `TonTimeout` benne (`FB_Bucket` cause 2) + relâchement joystick opérateur. Documenter que c'est **assumé** (comme HX4 aujourd'hui). |
| Q8 | Bandeau IHM « machine non référencée, benne sans FDC » : niveau (info / warning) et persistance ? | clarté opérateur | warning non bloquant, actif tant que `SeqStep = HX1B` |
| Q9 | `M3Locked` / `Lifecycle.Busy` en HX1B ? | translation M3 pendant manip benne | `M3Locked := TRUE` en HX1B (pas de translation pendant une séquence homing engagée) ; `Lifecycle.Busy := TRUE` |
| Q10 | Interaction avec la perte de datum en mouvement (§3 du FB) et l'auto-armement HX0→HX1 ? | HX1B ne doit pas s'armer tout seul | HX1B n'est atteignable que depuis HX1 sous `Mode = MAINT_N2` ; jamais cible de l'auto-arm |

---

## 6. 🛡️ Matrice de non-régression (à cocher avant restitution)

| Domaine | Vérification | Preuve |
|---|---|---|
| MAINT_N1 benne | jog WinchSel=2 ouvre/ferme la benne comme avant T260 | diff PRG_04 (ManualBucketJogActive inchangé) + essai site |
| MAINT_N2 benne hors homing | jog + boutons IHM inchangés quand `MachineHoming.Active = FALSE` | diff PRG_04 (gardes = `SeqStep = HX1B` strict) |
| SEMI_AUTO benne | cycle AX* inchangé | `run_tests.py --fb FB_CycleSemiAuto` |
| Homing HX2..HXF | montée, HX3 au vol, HX5 commit, tempos, gardes | `run_tests.py --fb FB_CycleMachineHoming` (après MAJ transitions HX1) |
| WINCH_INTEG | scénarios treuils couplés | `run_tests.py --fb WINCH_INTEG` |
| Gates | G494 (liste steps), G300/G400 | `run_all_gates.py --palier C` |
| Liaison | producteur unique `BucketPrecheckActive` | `G200_check_linkage.py --report` |

---

## 7. 🧪 Plan de test (à écrire avec le code)

Nouveaux cas `test_fb_cyclemachinehoming.st` :
- `TC-P09-H013` : HX1 (MAINT_N2) → **HX1B** automatique (pas de 3 appuis pour ce saut).
- `TC-P09-H014` : HX1B + `BucketPermit AND JoystickPull` → `CmdBucketClose`, `CmdWinchM1/M2.RunRequest = FALSE`.
- `TC-P09-H015` : HX1B + `BucketPermit AND JoystickPush` → `CmdBucketOpen`.
- `TC-P09-H016` : HX1B, geste de validation (Q3) + joystick neutre + treuils arrêtés → HX2 (ou HX2N si capteur).
- `TC-P09-H017` : HX1B, `Mode <> MAINT_N2` → HX0 ; `AxisHomingError` → HXF.
- `TC-P09-H018` : force-step MES cible 10 → HX1B.
- MAJ `TC-P09-H010` / `TC-P09-H090` : la transition HX1→HX2 devient HX1→HX1B→HX2.

Nouveau CI intégration (`test_winch_integ.st`) `HARN-90` :
- démarrage à froid, codeurs NON référencés, MAINT_N2 → homing → HX1B ferme benne → valide → HX2 :
  `EffectivePermitM1_Ascent` ET permis M2 appliqué = TRUE, montée couplée effective, `instBucket.Fault.Latched` non bloquant.

---

## 8. 📋 Synthèse décision

| Élément | Décision proposée | À valider |
|---|---|---|
| Structure | Étape enum dédiée `HX1B_BUCKET_PRECHECK := 10` | ☐ |
| Accès | HX1 → HX1B seulement en `MAINT_N2` | ☐ |
| Validation HX1B → HX2 | **à trancher** : bouton dédié vs 3 appuis JOY (Q3) | ☐ |
| HX4 | conservé (calage fin post-homing) | ☐ |
| Benne ouverte autorisée en HX1B | non — fermeture requise + alerte (RES-004 non tranchée) | ☐ |
| Relaxation PRG_04 | flag `BucketPrecheckActive` (= `SeqStep = HX1B`), garde stricte | ☐ |
| `ManualBucketJogActive` | **NON touché** | ☐ |

➡️ Rien n'est codé tant que ces 7 cases ne sont pas cochées par l'orchestrateur/opérateur.
