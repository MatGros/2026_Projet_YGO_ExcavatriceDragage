# T167-CR — Rapport brut omniroute codex/gpt-5.6-sol-max : FB_ExtractionSequence (code durci)

> 3e revue independante, sur le code apres passe H1-H5. Analyse orchestrateur + F1/F2/F3 : voir T167-CR_REVUE_INDEPENDANTE_CYCLES.md §4bis.

---

# 🛑 Verdict final : **REJETÉ**

**Verdict reviewer : `BLOCK`**

Le durcissement est réel, mais **deux exigences obligatoires sont encore violées**, dont une directement sur une sortie `[ACT]`. Un troisième écart affecte la robustesse du backstop.

> Les lignes ci-dessous sont comptées sur l’extrait fourni.

## Écarts restants

### 🔴 BLOCK — `ForceMinSpeedStep` actif sans permis positif

📍 `CODE/G_CYCLE/FB_ExtractionSequence.st:258-269`

```st
AscentPermit := AssistPermit AND AscentControlSafe;
ForceMinSpeedStep := TRUE;
```

#### Contre-exemples déterministes

En état `CONTROL_ASCENT` :

- `MotionRequestActive = FALSE` → `AssistPermit = FALSE`
- ou `MotionDirection <> 1`
- ou `Mode` différent de `MAINT_N1/N2`
- ou `AscentControlSafe = FALSE`

Résultat du scan :

```text
AscentPermit      = FALSE
ForceMinSpeedStep = TRUE   ❌
```

En cas de perte d’une entrée sûre, le défaut local n’est latché qu’après l’appel de `instFault`, donc `ERROR_HOLD` n’est pris qu’au scan suivant. Pendant le scan de détection, `ForceMinSpeedStep` reste actif.

➡️ Violations :

- sortie `[ACT]` active sans permis positif ;
- coupure même-scan incomplète ;
- commande résiduelle lors du relâchement de la demande ou d’un défaut détecté dans le `CASE`.

Même si cette sortie n’autorise pas seule le mouvement en aval, **ce comportement viole le contrat strict du FB**. Un interverrouillage aval non fourni ne peut pas servir de preuve.

---

### 🟠 MAJOR — Reset accepté alors que la cause physique persiste

📍 `FB_ExtractionSequence.st:129-138`, appel du socle `:161`

La condition de reset ne vérifie que :

```st
NOT ErrorCausePresent AND NOT MotionRequestActive
```

Or `ErrorCausePresent` ne couvre que le paramétrage. Elle ne couvre pas notamment :

- `BucketError`
- `WinchSyncError`
- `NOT PositionsValid`
- `NOT M1MeasuredSpeedValid`
- `NOT M2MeasuredSpeedValid`

#### Contre-exemple

Préconditions :

```text
BucketErrorFault = TRUE
BucketError      = TRUE  (cause toujours présente)
MotionRequestActive = FALSE
ErrorCausePresent = FALSE
Reset : front montant
```

Le code :

1. efface `BucketErrorFault` ;
2. efface `StepAtFaultCaptured` ;
3. replace l’état en `WAIT_BOTTOM_CONFIRMATION` ;
4. présente ensuite `instCauses[1].Active = FALSE` au `FB_FaultCore` ;
5. transmet bien `Reset := Reset` brut.

Le latch peut donc être acquitté alors que `BucketError` reste actif, car cette entrée n’est pas réévaluée en `WAIT_BOTTOM_CONFIRMATION`.

Même défaut pour les causes treuil/capteurs.

➡️ La liaison brute du Reset vers `FB_FaultCore` est conforme, mais **la garde “cause disparue” de la machine d’état est incomplète**. De plus, les latches locaux sont eux aussi effacés sous cette garde : il n’est donc pas exact que seul le reset de la machine d’état soit conditionné.

---

### 🟠 MAJOR — Overflow possible du backstop benne

📍 `FB_ExtractionSequence.st:103-106` et `:115-118`

```st
BucketCloseTimerAcc := BucketCloseTimerAcc + CycleTime;

IF BucketCloseTimerAcc >= CfgBucketCloseTimeout THEN
```

`CfgBucketCloseTimeout` et `CycleTime` sont contrôlés uniquement contre zéro et pour leur ordre relatif. Aucun plafond ni ajout saturé n’est prévu.

Sur un `TIME` CODESYS 32 bits, par exemple :

```text
CycleTime = T#10ms
CfgBucketCloseTimeout = TIME maximal
```

L’accumulateur peut atteindre `4 294 967 290 ms`, puis déborder avant d’atteindre une valeur supérieure ou égale au timeout maximal. Le backstop peut alors ne jamais déclencher. Si le runtime traite l’overflow par exception plutôt que par rebouclage, aucune réaction sûre n’est spécifiée non plus.

➡️ La temporisation de contrôle calculée est correctement bornée, mais **le backstop benne n’est pas robuste sur tout le domaine accepté par son interface `[CFG]`**.

---

## Matrice des six critères

| # | Critère | Verdict |
|---:|---|---|
| 1 | Sorties `[ACT]` uniquement avec permis positif, coupure même-scan | ❌ **FAIL** — `ForceMinSpeedStep` |
| 2 | Pas de redémarrage automatique sans front Reset | ⚠️ **Conforme dans ce FB sous contrat `FB_FaultCore`** ; son implémentation n’est pas fournie |
| 3 | Reset brut vers `FB_FaultCore`, état réarmé seulement cause disparue | ❌ **FAIL** — Reset brut conforme, mais garde des causes incomplète |
| 4 | `StepAtFault` capturé avant `ERROR_HOLD` | ✅ **PASS** — captures au site avant latch et capture §1 avant le gate défaut |
| 5 | Commandes nulles sur `NOT Enable` / `ERROR_HOLD` | ⚠️ **PASS en état établi**, mais coupure du scan de détection incomplète à cause de `ForceMinSpeedStep` |
| 6 | Division, plancher/plafond, conversion et robustesse numérique | ❌ **FAIL global** — calcul REAL conforme, overflow du backstop non exclu |

## Points conformes constatés

- `Reset := Reset` est bien transmis brut au `FB_FaultCore`.
- Les défauts issus du `CASE` capturent `StepAtFault` avant le latch local.
- Les défauts calculés en §1 capturent l’étape avant le passage en `ERROR_HOLD`.
- `BucketCloseRequest` chute le scan même sur `BucketError`.
- `AscentPermit` chute le scan même sur ses conditions `Ascent*Safe`.
- Les sorties sont neutralisées sur `NOT Enable`, perte du contacteur et en `ERROR_HOLD` établi.
- Le calcul de `CalculatedControlAscentTimeout` protège la division par constante positive et borne la valeur avant `REAL_TO_UDINT`.

## Conditions minimales avant nouvelle revue

1. Garantir que `ForceMinSpeedStep` reste faux sans demande, mode autorisé et conditions sûres.
2. Définir et appliquer une condition de reset couvrant la cause physique encore présente, sans casser le contrat de Reset brut de `FB_FaultCore`.
3. Borner `CfgBucketCloseTimeout` ou rendre l’accumulation saturante.
4. Fournir le contrat ou l’implémentation de `FB_FaultCore` pour prouver formellement :
   - reset sur front ;
   - conservation du latch pendant `Enable = FALSE` ;
   - absence d’effacement sur un Reset maintenu.

---

```text
Auto-vérification liaison (G200_check_linkage.py) — FAIL
  Non exécutée : revue réalisée sur l’extrait fourni, aucune preuve mécanique de liaison disponible.

Gates : structure / style / liaison / persistance / bundle / pytest = NON EXÉCUTÉS
Fichiers modifiés : aucun — revue READ-ONLY
Hors scope constaté (devoir d’alerte) :
  - Implémentation de FB_FaultCore non fournie.
  - Consommateur aval de ForceMinSpeedStep non fourni.
  - Bornes amont des paramètres TIME non fournies.
```

Une **certification ISO 13849 normative** ne peut par ailleurs pas être délivrée sur ce seul FB sans preuves PLr, architecture, DCavg/MTTFd/CCF, matériel Safety, temps de réaction et essais de validation. Ici, le **rejet est déjà acquis au niveau du contrat logiciel**.