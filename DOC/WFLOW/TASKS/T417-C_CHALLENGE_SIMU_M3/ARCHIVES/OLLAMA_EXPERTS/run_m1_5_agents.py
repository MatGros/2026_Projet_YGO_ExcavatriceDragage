import concurrent.futures
import subprocess
import time
from pathlib import Path

OUT_DIR = Path("DOC/WFLOW/TASKS/T417-C_CHALLENGE_SIMU_M3/ARCHIVES/OLLAMA_EXPERTS")
OUT_DIR.mkdir(parents=True, exist_ok=True)

PROMPTS = {
    "M1_AGENT1_CHAINE_M3": (
        "deepseek-v4.1-flash:cloud",
        """# MISSION AGENT 1 — AUDIT CHAÎNE D'ARRÊT M3 AU 1er TROU (MANU vs SEMI_AUTO) & 3 SOLUTIONS ST

## Contexte Code Vérifié
1. En `MANU` (`MAINT_N1`), l'opérateur pousse le joystick (`M3_ReqTremie_Active = TRUE`). Au 1er trou capteur (`M3_PosTremie_DI = TRUE` ou `M3_PosP1_DI`), l'opérateur maintient encore le joystick ~0,3-0,5 s :
   - Dans `FB_Translation.st:291` : `EffectiveSafeStop := SafeStop OR (ReqTremie AND NOT EffectivePermitM3_Tremie) ...` reste `TRUE` -> `SpeedRamp` décélère sur `CfgRampDecelFastRate` (rampe rapide).
   - Dans `PRG_06_Outputs.st:438` : `M3_TremieHardStopActive := M3_TremieHardStopLatched AND ReqTremieSemantic` reste `TRUE` -> coupe immédiatement `DriveControlWord := 0` et `BrakeRelease_RQ := FALSE`.
   - Dans `PRG_05_Translation.st:439` : `M3_TargetCodeSel` reste actif -> `CaptorDebounceTon` (100 ms) dans `FB_Translation.st:192` aboutit et arme `ArrivalLock := TRUE`.
2. En `SEMI_AUTO` (`FB_CycleSemiAuto.st:985` AX2 et `:1490` AX14) :
   - Dès que `Translation_At_P1` (`M3_AtP1Stable`) ou `Translation_At_Tremie` (`M3_AtTremieStable`) passe à `TRUE`, au scan suivant (+10 ms) `FB_CycleSemiAuto` écrit :
     `TranslationCmd.ReqStart := FALSE; TranslationCmd.PositionTgt := 0;`
   - Conséquence dès +10 ms :
     a) `M3_ReqTremie_Active` (`ReqTremieSemantic`) tombe à `FALSE`.
     b) `EffectiveSafeStop` retombe à `FALSE` -> `SpeedRamp` décélère sur `CfgRampDecelNormalRate` (rampe lente).
     c) `M3_TremieHardStopActive` dans `PRG_06` retombe à `FALSE` après 10 ms -> le frein ne tombe plus par `PRG_06`, mais attend `FB_Translation.Brake` (`SpeedRamp.Current <= 0.1` + `DelayMotorDecel`).
     d) En `AX2` (`P1`), `PositionTgt := 0` fait tomber `M3_PositionSensorTarget` après 10 ms avant la fin du `CaptorDebounceTon` (100 ms) -> `ArrivalLock` ne s'arme jamais !

## Objectif Évaluable
1. Dresser la chronologie exacte Scan N / Scan N+1 / Scan N+2..N+50 entre `MANU` et `SEMI_AUTO`.
2. Proposer **3 solutions ST distinctes (S1, S2, S3)** (ou leur combinaison optimale) pour que `SEMI_AUTO` bloque et freine dès le 1er trou exactement comme `MANU` (sur Trémie ET sur P1).
3. Fournir les snippets ST exacts pour chaque solution.
"""
    ),
    "M1_AGENT2_REDTEAM_M3": (
        "glm-5.3-flash:cloud",
        """# MISSION AGENT 2 — CHALLENGER RED TEAM (CHALLENGE B) SUR L'ARRÊT M3 AU 1er TROU

## Contexte
On cherche à bloquer le mouvement M3 en `SEMI_AUTO` dès le 1er trou capteur (`M3_PosTremie_DI` et `M3_PosP1_DI`) exactement comme en `MANU`, via 3 approches candidates :
- **S1 (`FB_CycleSemiAuto.st`) :** Maintenir `TranslationCmd.PositionTgt` (`1` en AX14, `3` en AX2) pendant que `TranslationStopTimer` tourne (ne mettre que `ReqStart := FALSE`).
- **S2 (`FB_Translation.st`) :** Dès que `PositionSensorTarget` (qui est déjà alimenté par le bistable `M3_AtTremieStable` / `M3_AtP1Stable` de `PRG_05`) passe à `TRUE` dans le sens du mouvement (`LastMoveDirection`), armer `ArrivalLock := TRUE` immédiatement, utiliser `CfgRampDecelFastRate` si `ArrivalLock` est actif, et couper `MovementRequested := FALSE` dès que `ArrivalLock` (ou `LimitSwitchTremie` / `LimitSwitchMaintenance`) est atteint dans le sens commandé.
- **S3 (`PRG_06_Outputs.st`) :** Maintenir `M3_TremieHardStopActive` tant que `M3_TremieHardStopLatched` est vrai et qu'aucun mouvement inverse (`ReqMaintenanceSemantic`) n'est demandé (ou tant que l'axe n'est pas arrêté).

## Objectif Évaluable (4 Cas Pièges Obligatoires)
Analyser et challenger S1, S2, S3 face à :
1. **Piège 1 (Trou mécanique dans le rail `1 -> 0 -> 1`) :** Le capteur passe à 1 au début du trou, puis tombe à 0 dans le trou, puis repasse à 1 après. Que fait chaque solution ?
2. **Piège 2 (Dégagement sens opposé `AX18 -> AX2` vers P1 ou `AX2` vers Trémie) :** La solution risque-t-elle de bloquer le départ dans le sens opposé ?
3. **Piège 3 (Défauts `ErrorId=16` Méca B ou `ErrorId=64` ou `FB_Brake` ContactorCheck) :** Couper `MovementRequested` ou `BrakeReleaseRequest` dès le 1er trou à 20 Hz déclenche-t-il un défaut dans `FB_Safety_Translation` (`CauseMecaB`, `PostRampTimeout = 3s`) ou dans `FB_Brake` ?
4. **Verdict B :** Quelle combinaison exacte de S1 / S2 / S3 est 100 % sûre et sans effet de bord ?
"""
    ),
    "M1_AGENT3_CYCLE_T417F": (
        "deepseek-v4.1-flash:cloud",
        """# MISSION AGENT 3 — CONCEPTION ST DES OPTIONS T417-F (PAUSE AX14/AX15 & OUVERTURE ANTICIPÉE EN ZONE PV)

## Contexte Code (`FB_CycleSemiAuto.st` & `PRG_03_Modes_Cycle.st` & `FB_Modes.st`)
Dans `FB_CycleSemiAuto.st` :
- `AX14_TRANSLATE_DUMP` (lignes 1475-1501) : commande `TranslationCmd.PositionTgt := 1; TranslationCmd.ReqStart := TranslationTremiePermit;`. Quand `Translation_At_Tremie` est `TRUE` et `TranslationStopTimer.Q` (500 ms sous `0,5 Hz`), passe à `AX15A_DUMP_ARRIVE`.
- `AX15A_DUMP_ARRIVE` (lignes 1503-1534) : attend `SeenNeutralAfterArrival` puis `DeadmanArmed AND JoystickPush` pour passer à `AX15B_DUMP_OPEN`.
- `AX15B_DUMP_OPEN` (lignes 1536-1565) : `BucketCmd.ReqOpen := DeadmanArmed AND JoystickPush;`. Quand `Benne_Done AND Benne_IsOpen`, passe à `AX18_DONE_SYNC`.

## Exigences Exploitant à Intégrer Simplement par Bits/Paramètres IHM
1. **Demande F1 (`CfgPauseBeforeDump_S : REAL := 0.0`) :**
   - Pause réglable IHM entre l'arrêt en `AX14` et l'ouverture benne (`AX15B`). Si `0.0 s` : transparent. Si `> 0.0 s` (ex. `0.5 s`) : impose ce délai supplémentaire à l'arrêt avant d'autoriser l'ouverture en `AX15A/B`.
2. **Demande F2 (`TglAllowDumpInPV : BOOL := FALSE`) :**
   - Quand `TglAllowDumpInPV = TRUE`, dès que le chariot est en zone PV (`Translation_PosPV = TRUE`) en `AX14` :
     - L'opérateur peut déjà ouvrir la benne (tout en continuant ou en finissant la translation vers Trémie),
     - Et dès que la benne est ouverte (`Benne_IsOpen = TRUE`), le cycle autorise le passage vers `AX18_DONE_SYNC` (et donc le retour vers `P1` en `AX2`) **même si le capteur `M3_PosTremie_DI` (`Translation_At_Tremie`) n'a pas été atteint** !
   - Vérifier aussi l'interaction avec `PRG_04_Treuils_Benne.st:1083` (`WinchDescentAuth_M3` exempte déjà `ReqProgram.ReqBucket.ReqOpen`) et `FB_Modes.st:372` (`M3AtTremie`).

## Objectif Évaluable
Proposer **2 variantes d'implémentation ST propres** (Variante A et Variante B) pour F1 et F2, avec le code ST exact et l'analyse des transitions joystick (Axe X translation vs Axe Y ouverture benne).
"""
    ),
    "M1_AGENT4_AX1_ET_MAINT_N2": (
        "glm-5.3-flash:cloud",
        """# MISSION AGENT 4 — ASSOUPLISSEMENT `AX1_INIT` (F3) & CONTRÔLE CODE `MAINT_N2` INCONDITIONNEL (`T395`)

## Partie 1 : `AX1_INIT` (`PRG_03_Modes_Cycle.st:174-182` & `FB_CycleSemiAuto.st:915-960`)
Actuellement :
```iecst
CycleWinchesAtTopOk :=
    (PRG_04_Treuils_Benne.Data.WinchM1Safety.CableLimitAscent
     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.CableLimitAscent
     OR (ABS(PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM - _CommunCfgPersist.CfgCableLimitAscent_M) <= CST_CycleInitWindowM))
    AND (PRG_04_Treuils_Benne.Data.BucketState.MechState.IsClosed OR PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen);
CycleInitPositionOk := NOT PRG_05_Translation.Data.M3_AtMaintenanceStable AND CycleWinchesAtTopOk;
```
Et dans `FB_CycleSemiAuto.st:952` :
`OperatorAction := 'AX1 - Posture depart incorrecte (M3, FDC haut M1 ou benne).';`
**Objectif Partie 1 :**
1. Remplacer ce message opaque par 3 messages distincts (< 70 caractères chacun pour le gate `G408`) indiquant exactement quelle condition bloque (`M3 en Maintenance`, `M1/M2 hors zone haute`, `Benne non qualifiée ouverte/fermée`).
2. Ajouter un bit IHM `TglRelaxSemiAutoStart : BOOL := FALSE` qui, lorsqu'il est à `TRUE`, assouplit le départ `AX1_INIT` (fenêtre haute élargie et/ou dispense de qualification stricte `IsOpen/IsClosed` si les treuils sont en zone haute).

## Partie 2 : Contrôle Code `MAINT_N2` — Commande Inconditionnelle Contacteurs & Treuils Ensemble ou Séparément
Exigence exploitant : *"Il faut qu'en MAINT_N2 on puisse commander les contacteurs et les treuils ensemble (`WinchSel=0`) ou séparément (`WinchSel=1` ou `2`) de façon inconditionnelle."*
Or voici 3 verrous trouvés dans le code actuel :
1. `FB_Modes.st:364-396` :
   ```iecst
   IF (Auth.Mode = E_Mode.MAINT_N2) OR (Auth.Mode = E_Mode.MAINT_N1) THEN
       IF M3AtTremie AND NOT AllowWinchMoveAtTremie THEN
           Auth.JoystickWinchSelectArbitrated := 2;
           BucketSeqSatisfied := FALSE;
       ELSIF CoupledBucketSeqEnable AND (JoystickWinchSelectRequest = 0) AND (JoystickPull XOR JoystickPush) THEN
           ...
           Auth.JoystickWinchSelectArbitrated := 2;
   ```
   -> En `MAINT_N2`, `M3AtTremie` et `CoupledBucketSeqEnable` écrasent `JoystickWinchSelectRequest` et forcent `2` (M2 seul) !
2. `PRG_03_Modes_Cycle.st:511-516` :
   `WinchDescentAuth_M3` bloque la descente M1 (et M1+M2 couplés) si M3 n'est pas à P1/Maintenance, même en `MAINT_N2` !
3. `PRG_04_Treuils_Benne.st:771-799` :
   `ProcessPermitM1_Descend` / `ProcessPermitM2_Descend` peuvent être bloqués par `KoboldBottomTouchLatched` ou `ManualBucketLimitsActive` même en `MAINT_N2` !
**Objectif Partie 2 :**
Vérifier ces 3 points (et tout autre verrou dans `PRG_04` / `PRG_06`) et donner les patchs ST exacts pour qu'en `MAINT_N2`, les treuils (ensemble `0` ou séparément `1`/`2`) et leurs contacteurs soient commandables sans blocage process.
"""
    ),
    "M1_AGENT5_TRACE_ET_SIMU": (
        "deepseek-v4.1-flash:cloud",
        """# MISSION AGENT 5 — RECLASSEMENT TRACE CODESYS M3 PAR ÉCHELLE / TYPE DE DONNÉES

## Contexte
Le fichier `Suivi_97_SIMU_M3_Translation_M3_manu_auto_20261116.trace` contient 30 variables M3, mais :
- Toutes les variables ont la même échelle `Min=-12, Max=12`, ce qui écrase les booléens (`0..1`) et fait déborder les fréquences/pourcentages (`0..100` ou `0..5000`).
- 5 variables clés sont masquées (`Visible=False` : `DeadmanArmed`, `Error`, `PositionReached`, `ActiveTremie`, `ActiveMaintenance`).
- Il manque `M3_PosPV_DI`, `TranslationState.ErrorId`, `TranslationState.EstimatedPosM3_M`, et `GVL_Simulation.SimM3ObsPositionTrue_M`.

## Objectif Évaluable
Définir l'ordre exact et les bornes `[Min..Max]` optimales de chaque variable pour générer une trace CODESYS `.trace` 100 % orientée M3, classée par groupe de type de donnée et d'échelle :
1. Groupe A : Booléens de commande, capteurs et frein M3 (`0/1`)
2. Groupe B : Positions M3 et cible (`m` et code cible)
3. Groupe C : Consignes vitesse (`%` / `Hz`), étape `Step` et `ErrorId`
4. Groupe D : Fréquence brute variateur (`ActualFrequencyHz` en `0.01 Hz`, soit `0..5000`)
"""
    ),
}


def run_one(name: str, model: str, prompt_text: str):
    t0 = time.time()
    prompt_path = OUT_DIR / f"PROMPT_{name}.md"
    result_path = OUT_DIR / f"RESULT_{name}.md"
    prompt_path.write_text(prompt_text, encoding="utf-8")
    cmd = [
        "python",
        "TOOLS/AGENT_WORKFLOW/scripts/ollama_subagent.py",
        "--file", str(prompt_path),
        "--model", model,
        "--output", str(result_path),
        "--num-ctx", "16384",
        "--timeout", "180",
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    dt = time.time() - t0
    return name, model, proc.returncode, dt, result_path.exists() and result_path.stat().st_size or 0


if __name__ == "__main__":
    print("Launching 5 Ollama subagents in parallel...")
    t_start = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as ex:
        futs = [ex.submit(run_one, k, v[0], v[1]) for k, v in PROMPTS.items()]
        for f in concurrent.futures.as_completed(futs):
            name, model, rc, dt, sz = f.result()
            print(f"[DONE] {name} ({model}) | rc={rc} | {dt:.1f}s | {sz} bytes")
    print(f"All 5 agents finished in {time.time() - t_start:.1f}s")
