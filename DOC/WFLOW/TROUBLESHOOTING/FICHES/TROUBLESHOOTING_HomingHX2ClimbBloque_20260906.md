# 🕵️ Troubleshooting — Cycle homing machine bloqué en HX2 (montée impossible)

- **Date** : 2026-09-06
- **Situation** : site/simu — MAINT_N2, cycle `FB_CycleMachineHoming` en `HX2_CLIMB`
- **Symptôme** : instruction IHM = « HX2 - RefHoming Tirer JOY palier 1 vers FDC haut ».
  Joystick tiré (Y+ 70 %), homme‑mort armé, mais **aucune montée treuil**. ErrorID:05
  « codeurs treuils non référencés » actif. L'opérateur ne peut jamais atteindre le
  capteur haut → ne peut jamais référencer.
- **Canal d'acquisition** : snapshot CSV `Snapshot_Troubleshooting_20260906_134450.csv` (528/528 var).

---

## 1. Contexte figé (snapshot)

| Domaine | Variable | Valeur |
|---|---|---|
| Mode | `A.Idx101_ModeActive` | `MAINT_N2` |
| Joystick | `D.DeflectionY_Pct` / `DirectionY` / `DeadmanArmed` | `70` / `1` / `TRUE` |
| Capteur haut phys. | `B.Winch.M1M2_TopPositionFree_DI` | `TRUE` (= **pas** au capteur haut) |
| Réf. codeurs | `K.Idx116_M1ReferenceMissing` / `Idx117_M2ReferenceMissing` | `TRUE` / `TRUE` |
| Homing lifecycle | `E.HomingBusy` / `F.HomingBusy` | `FALSE` / `FALSE` |
| Position câble M1 / M2 | `H.Idx101` / `H.Idx102` | `≈ 4097 m` / `≈ 4111 m` (**fantôme**, codeur non référencé) |
| Limite haute soft | `I/J.Idx321_CfgTopLimitM` | `7.5 m` |
| Top‑limit atteint | `I/J.Idx323_TopLimitReached` / `Idx324_AscentBlockedByTopLimit` | `TRUE` / `TRUE` (M1 **et** M2) |
| Permis montée M1 | `T.M1SafetyAscentPermit` / `M1ProcessAscentPermit` / `EffectivePermitM1_Ascent` | `TRUE` / `TRUE` / `TRUE` |
| Permis montée M2 | `T.M2SafetyAscentPermit` / `M2ProcessAscentPermit` / `EffectivePermitM2_Ascent` | **`FALSE`** / **`FALSE`** / **`FALSE`** |
| Barrière finale M2 | `T.M2FinalPermitBlocked` / `R.FinalPermitBlocked` | **`TRUE`** / **`TRUE`** (`FinalInterlockReason = NONE`) |
| Levage synchro | `H.Idx401_SyncMotionAllowed` / `Idx203_ArbitratedSpeed_Pct` | **`FALSE`** / `0` |
| Demande arbitrée lane M1 / M2 | `I.Idx208` / `J.Idx208` (+ `J.Idx209 dir`) | `0 %` / **`80 %` dir 1** |
| Sorties moteur | `H.Idx501/502_CmdRelayFwd_DQ`, `N/O.RelayFwdActive` | `FALSE` partout |
| FB_Bucket | `K.Idx106_FBState` / `Idx302_BucketFaultActive` / `Idx306_ErrorIdRaw` | **`ERROR`** / **`TRUE`** / `WORD#16` |

---

## 2. Chaîne de blocage (tracée du symptôme vers la source)

1. Montée treuil couplée HX2 → passe par **`FB_WinchSync` / lane synchro** (`H_LevageSynchroniseM1M2`).
   `SyncMotionAllowed` exige les **deux** permis de montée. `M2_AscentPermit = FALSE`
   ⇒ `SyncMotionAllowed = FALSE` ⇒ `ArbitratedSpeed = 0` ⇒ **aucun treuil ne part**.
2. `EffectivePermitM2_Ascent = FALSE` alors que M1 est `TRUE` : asymétrie M2. Pistes,
   toutes conditionnées à un état que le homing est justement censé produire :
   - `M2AscentPermitApplied := EffectivePermitM2_Ascent AND (NOT instBucket.M2_RunRequest OR EffectivePermitBucket_Close)`
     — `EffectivePermitBucket_Close` (PRG_04 ~1053) exige `EncoderM1.Homed AND EncoderM2.Homed` → **FALSE** (non référencés).
   - `FB_Bucket` est **latché en ERROR** (`ErrorIdRaw 16`) et peut porter `M2_RunRequest`/bloquer le permis benne.
   - `T.M2FinalPermitBlocked = TRUE` avec `FinalInterlockReason = NONE` → **incohérence** (barrière finale coupe M2 sans raison nommée) — à élucider.
3. Position câble **fantôme** (`≈ 4100 m` vs limite `7.5 m`) car codeurs non référencés →
   `AscentBlockedByTopLimit = TRUE` sur les deux axes (diag ; la butée soft `FB_Safety_Winch §3`
   ligne 574 est bien neutralisée car `NOT Homed`, donc pas la cause directe du permis M1,
   mais elle pollue le diagnostic et peut alimenter d'autres gardes).
4. Mismatch d'arbitrage : lane M1 `0 %`, lane M2 `80 %` dir 1 — les deux lanes ne voient pas
   la même consigne HX2 (attendu : 20 % montée sur les deux). Origine du `80 %` sur M2 non
   identifiée (extraction ? benne ?).

## 3. Cause racine (hypothèse — dépendance circulaire)

Le **palier HX2 de `FB_CycleMachineHoming`** commande une montée couplée M1+M2 pour aller
chercher le capteur haut. Mais le **permis de montée M2 dépend d'un état « machine déjà
référencée / benne référencée »** (`EncoderM2.Homed`, `EffectivePermitBucket_Close`), et
`FB_Bucket` est en ERROR. → Impossible de monter tant qu'on n'est pas référencé, impossible
de se référencer sans monter. **Deadlock.**

M1 échappe au piège (permis `TRUE`) ; M2 non → la lane synchro bloque tout.

## 4. À capturer pour trancher (hors GVL_Troubleshooting actuel)

Variables à ajouter au snapshot / lire en trace CODESYS :
- `instBucket.M2_RunRequest`, `instBucket.Fault.*`, cause exacte `ErrorIdRaw=16` de `FB_Bucket`
- `ProcessPermitM2_Ascent`, `SafetyPermitM2_Ascent` (sorties brutes `instSafetyWinchM2`)
- `PRG_03_Modes_Cycle.Data.Auth.InhibitM2`, `.SyncEnable`, `.SyncOperationPermit`
- `WinchM2FinalInterlockRequest.*` + sortie `FB_WinchOutputInterlock` M2 (pourquoi `Blocked` avec `Reason=NONE`)
- lane M1 vs M2 : d'où vient `ArbitratedSpeed 80 %` sur M2

## 5. Piste de correction (À VALIDER — criticité ≥ C2, interlock sécurité)

- Le permis de montée M2 pendant **`HX2_CLIMB` / `HX2N`** ne doit pas dépendre de
  `EncoderM2.Homed` ni de `EffectivePermitBucket_Close` : pendant l'approche capteur haut
  du cycle homing, seuls doivent compter le **FDC haut matériel**, le homme‑mort et le
  joystick maintenus, la vitesse lente palier 1.
- Router un signal « approche référencement machine active » (nouveau champ de sortie
  `FB_CycleMachineHoming`, vrai en HX2/HX2N) via PRG_03 → PRG_04 vers un point de
  relaxation dédié du permis M2 (analogue à `InReferencingMode`, aujourd'hui vrai
  seulement quand `HomingLifecycle.Busy`, donc seulement en HX3).
- Traiter l'ERROR `FB_Bucket` (ErrorIdRaw 16) : soit acquittable avant homing, soit
  exclu du calcul de permis pendant le cycle homing machine.
- `guard:` gate mécanique : « `SeqStep=HX2_CLIMB` + homme‑mort + JoystickPull maintenus,
  sous capteur haut ⇒ `EffectivePermitM1_Ascent` **et** `EffectivePermitM2_Ascent` = TRUE
  et `SyncMotionAllowed` = TRUE ».

## 6. Journal

- 2026-09-06 : analyse statique + snapshot. Chaîne tracée jusqu'aux permis treuil.
  Blocage opérationnel confirmé : `SyncMotionAllowed=FALSE` via `M2_AscentPermit=FALSE`.
  Asymétrie M1/M2 non totalement résolue (barrière finale M2 `Blocked` / `Reason NONE`,
  arbitrage 0 % vs 80 %) → 2e acquisition nécessaire (§4). Aucun code modifié.
