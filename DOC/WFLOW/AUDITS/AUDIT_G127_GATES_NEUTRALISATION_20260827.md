# AUDIT — Gates `NOT Enable` incomplets (G127)

| | |
|---|---|
| **Date** | 2026-08-27 |
| **Tâche** | T164-1 (contrat `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T164-1_AUDIT_G127.yaml`, C3, lecture seule) |
| **Source** | `python TOOLS/AGENT_WORKFLOW/scripts/G127_check_neutralization_completeness.py .` (35 FB avec gate `NOT Enable`, 19 complets, **16 incomplets**) |
| **Périmètre** | Les 16 FB signalés — aucun ajout, aucun oubli |
| **Référence correctif** | `git show 0b0a2785 -- CODE/E_CODEURS/FB_Encoder.st` (gate `NOT Enable` : sorties HW → 0, référence reprise depuis `Calib` RETAIN) |
| **Portée** | Audit documentaire **pur**. Aucun `CODE/*.st`, `TOOLS/*`, `TASKS.yaml` ni contrat modifié. Correctifs **proposés**, non appliqués. |

## Barème de verdict

| Verdict | Définition |
|---|---|
| **BUG** | Le gate laisse publier une valeur périmée hors `Enable` : la sortie est écrite dans le corps depuis une logique qui ne tourne plus, et **rien** ne la remet à une valeur sûre dans le gate. |
| **OK-ALIM** | La sortie **est** réaffectée dans le gate ; G127 ne l'a pas vue (ici : toujours parce qu'elle partage une ligne `A := …; B := …;` que le parseur G127 ne découpe pas). Prouvé fichier:ligne. |
| **OK-FIGE** | Valeur laissée figée **volontairement**, justifiée par la spec AF ou un commentaire code explicite (latch de défaut, référence persistante). Source citée. |

> Sévérité indiquée pour chaque BUG : **[ACT/SAFE]** (pilote un actionneur / interlock), **[STAT]** (état consommé par séquenceur/interlock aval), **[DIAG]** (synoptique IHM / diagnostic — pas de décision machine directe), **[SIM]** (brique de banc, jamais sur machine réelle).

---

# SECTION C4 — 4 FB prioritaires

Les 4 FB listés `criticité : C4` par le contrat, traités en premier.

---

## 1. FB_Safety_Winch — `criticité : C4`

`CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` · Gate : lignes 126-155 (`IF NOT Enable THEN … RETURN; END_IF;`).
Le gate neutralise correctement les sorties maîtresses : `SafeStop := TRUE` (137), `DescendPermit := FALSE` (138), `AscentPermit := FALSE` (139), `PowerCutOff := FALSE` (140). Il ne touche **pas** les 3 sorties DIAG signalées.

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_Safety_Winch | MecaADriftM | **BUG** [DIAG] | Écrite `:= DriftGuardA.DriftM` ligne 296. Dans le gate, `DriftGuardA(Arm := FALSE …)` est appelé (146) mais `MecaADriftM` n'est jamais réaffectée → conserve la dérive du dernier scan actif. |
| FB_Safety_Winch | MecaBElapsedTime | **BUG** [DIAG] | Écrite `:= TonMecaB.ET` ligne 318. Dans le gate `TonMecaB(IN := FALSE)` (148) ramène `.ET` à 0, mais `MecaBElapsedTime` n'est pas mise à jour → valeur périmée. |
| FB_Safety_Winch | MecaCDriftM | **BUG** [DIAG] | Écrite `:= DriftGuardC.DriftM` ligne 335. `DriftGuardC(Arm := FALSE …)` appelé dans le gate (147), mais `MecaCDriftM` non réaffectée → dérive périmée. |

**risque physique :** les 3 sorties sont [DIAG] pures (synoptique IHM / diagnostic hiérarchique). Aucune ne pilote d'actionneur ni d'interlock — `SafeStop`, `PowerCutOff`, `DescendPermit`, `AscentPermit` sont, eux, correctement forcés fail-safe dans le gate. Conséquence d'une valeur périmée : l'opérateur voit une dérive Méca A/C ou un temps Méca B figés au dernier scan actif pendant que le Safety M1/M2 est désactivé → confusion de diagnostic, risque de masquer une nouvelle indication de dérive au réarmement. **Aucun mouvement machine induit.** Sévérité faible (cosmétique diagnostic), mais à corriger pour cohérence avec le précédent `FB_Encoder` (neutralisation des sorties « oubliées »).

### Correctif proposé — FB_Safety_Winch

Dans le gate, juste avant `RETURN;` (ligne 154) :

```st
MecaADriftM := 0.0;
MecaCDriftM := 0.0;
MecaBElapsedTime := T#0ms;
```

Source de la valeur sûre : `0.0` / `T#0ms` = neutralisation (aucune mesure de dérive/temps valide quand le FB est désactivé), même forme que `FB_Encoder` gate (`Measurement.* := 0.0`).
Interface : **inchangée** — `MecaADriftM`/`MecaCDriftM : REAL` et `MecaBElapsedTime : TIME` sont déjà `VAR_OUTPUT` (94-96). Aucun nouveau `VAR`, aucun type modifié.

---

## 2. FB_WinchOutputInterlock — `criticité : C4`

`CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` · Gate : lignes 87-100 (`IF NOT Enable OR NOT PowerContactorEngaged THEN … RETURN;`).

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_WinchOutputInterlock | AuthorizedStep | **OK-ALIM** | `BrakeCmd := FALSE; AuthorizedStep := 0;` — ligne 93. |
| FB_WinchOutputInterlock | Busy | **OK-ALIM** | `Ready := FALSE; Busy := FALSE; Done := FALSE;` — ligne 95. |
| FB_WinchOutputInterlock | Contactor2 | **OK-ALIM** | `Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;` — ligne 92. |
| FB_WinchOutputInterlock | Contactor3 | **OK-ALIM** | ligne 92. |
| FB_WinchOutputInterlock | Contactor4 | **OK-ALIM** | ligne 92. |
| FB_WinchOutputInterlock | RelayRev | **OK-ALIM** | `RelayFwd := FALSE; RelayRev := FALSE;` — ligne 91. |
| FB_WinchOutputInterlock | RestartDelayElapsed | **OK-ALIM** | `BrakeTimeoutElapsed := T#0ms; RestartDelayElapsed := T#0ms; StepDelayElapsed := T#0ms;` — ligne 94. |
| FB_WinchOutputInterlock | StepDelayElapsed | **OK-ALIM** | ligne 94. |
| FB_WinchOutputInterlock | ErrorId | **OK-FIGE** | Non effacé dans le gate ; lu ligne 96 `Error := (ErrorId <> 16#0000)`. Commentaire explicite lignes 84-86 : « ErrorId, RestartInhibit et ResetRequired ne sont jamais effacés par une perte Enable/AU : celle-ci coupe uniquement les sorties. » Latch de défaut → acquittement conscient obligatoire. |
| FB_WinchOutputInterlock | RestartInhibit | **OK-FIGE** | Non touché dans le gate. Latch anti-redémarrage-auto (défaut frein) ; nommé explicitement lignes 84-86. Le mettre `FALSE` dans le gate autoriserait un redémarrage automatique après timeout frein → violation « jamais de redémarrage auto après défaut ». |
| FB_WinchOutputInterlock | StateAtError | **OK-FIGE** | Snapshot diagnostic figé sur front d'erreur (115-116). Doit survivre à la neutralisation pour rester exploitable (même doctrine qu'`ErrorId`). |
| FB_WinchOutputInterlock | Reason | **OK-FIGE** | Enum [DIAG] « Cause de neutralisation ou blocage » (40), écrite corps 129/165/238. Laissée figée en cohérence avec `ErrorId`/`RestartInhibit` qu'elle explique. Nuance : la doc lignes 84-86 nomme `ErrorId`/`RestartInhibit`/`ResetRequired` mais **pas** `Reason` (voir Devoir d'alerte §3). |

**risque physique :** **aucun BUG.** La barrière finale frein/puissance M1/M2 coupe bien tous ses ordres actionneurs à `Enable=FALSE` (`RelayFwd/Rev`, `Contactor1-4`, `AuthorizedStep`, `BrakeCmd` → 0/FALSE lignes 91-93). Les seules sorties non réaffectées sont des latches de défaut/diagnostic dont la conservation est **exigée** par la sécurité (pas de réautorisation automatique après défaut frein). RAS.

*(Pas de bloc `Correctif proposé` : aucun BUG.)*

---

## 3. FB_Winch — `criticité : C4`

`CODE/H_TREUILS_BENNE/FB_Winch.st` · Gate : lignes 103-121 (`IF NOT Enable OR NOT PowerContactorEngaged THEN … RETURN;`).
Ordres actionneurs neutralisés : `RelayFwd/RelayRev := FALSE` (104), `Contactor1..4 := FALSE` (105).

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_Winch | Contactor3 | **OK-ALIM** | `Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;` — ligne 105. |
| FB_Winch | RelayRev | **OK-ALIM** | `RelayFwd := FALSE; RelayRev := FALSE;` — ligne 104. |
| FB_Winch | ContactorsCheck | **BUG** [DIAG] | Struct `ST_ContactorCheck`. Champs écrits corps : `.Command`/`.Feedback` (318-319), `.StuckClosed` (322/324), `.StuckOpen` (326). Le gate ne touche aucun champ → `.Command`/`.Feedback` figés au dernier scan actif ; `.StuckClosed` figé (la détection `TonContactorsDropped` ne tourne plus). |
| FB_Winch | DirectionChangePending | **BUG** [DIAG] | Écrite ligne 142 `:= (Direction <> CommandedDirection) AND (CommandedDirection <> 0)`. Le gate force `CommandedDirection := 0` (111) mais ne recalcule pas `DirectionChangePending` → peut rester figée à `TRUE`. |
| FB_Winch | SpeedGuardLimited | **BUG** [DIAG] | Écrite ligne 259 `:= SpeedStep.SpeedGuardLimited`. Dans le gate, `SpeedStep(Enable := FALSE …)` est appelé (106) mais `SpeedGuardLimited` n'est pas réaffectée → statut périmé. |

**risque physique :** les 3 BUG sont [DIAG]. `ContactorsCheck` est recopiée par `PRG_04_Treuils_Benne.st:957/1014` vers `WinchM1/M2State.ContactorsCheck` (agrégation diagnostic / IHM). Les ordres actionneurs réels (`RelayFwd/Rev`, `Contactor1-4`) sont bien neutralisés. Conséquence d'une valeur périmée : `ContactorsCheck.StuckClosed` figé à `TRUE` peut faire remonter une alarme « contacteur collé » fantôme dans le diagnostic hiérarchique pendant que M1/M2 est désactivé ; figé à `FALSE` peut masquer un collage réel apparu juste avant la désactivation. `DirectionChangePending` figé à `TRUE` peut bloquer une logique IHM d'inversion. **Pas de mouvement machine directement induit** (contacteurs ouverts). Sévérité faible à moyenne (pollution du diagnostic contacteurs, brique surveillée par le diag hiérarchique).

### Correctif proposé — FB_Winch

Dans le gate, juste avant `RETURN;` (ligne 120) :

```st
ContactorsCheck.Command := FALSE;
ContactorsCheck.Feedback := FALSE;
ContactorsCheck.StuckClosed := FALSE;
ContactorsCheck.StuckOpen := FALSE;
DirectionChangePending := FALSE;
SpeedGuardLimited := FALSE;
```

Source de la valeur sûre : `FALSE` = neutralisation (aucun contacteur commandé, aucune inversion en attente, aucune limitation garde-fou quand le FB ne tourne pas). `ContactorsCheck.StuckClosed` : à `FALSE` sans condition — contrairement à `FB_Brake`/`FB_WinchOutputInterlock`, ce FB efface déjà `Status.ErrorId` dans son gate (119), il n'y a donc **aucun** latch de défaut à préserver ici, la mise à `FALSE` est cohérente.
Interface : **inchangée** — champs de `ST_ContactorCheck` déjà déclarés, `DirectionChangePending`/`SpeedGuardLimited : BOOL` déjà `VAR_OUTPUT` (72/78). Aucun nouveau `VAR`, aucun type modifié.

---

## 4. FB_Translation — `criticité : C4`

`CODE/I_TRANSLATION/FB_Translation.st` · Gate : lignes 106-125 (`IF NOT Enable OR NOT PowerContactorEngaged THEN … RETURN;`).
Ordre actionneur neutralisé : `RequestedDriveControlWord := 0; RequestedDriveFreqHz := 0.0;` (107).

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_Translation | RequestedDriveFreqHz | **OK-ALIM** | `RequestedDriveControlWord := 0; RequestedDriveFreqHz := 0.0;` — ligne 107. |
| FB_Translation | TargetReached | **BUG** [STAT] | Écrite ligne 145 `:= CaptorDebounceTon.Q`. Le gate ne la touche pas et n'entretient pas `CaptorDebounceTon` → `TargetReached` conserve la valeur du dernier scan actif. |

**risque physique :** `RequestedDriveFreqHz` (consigne fréquence variateur AC600, arbitrée par `FB_TranslationOutputInterlock`) est bien neutralisée à `0.0`. `TargetReached` est [STAT] : recopiée par `PRG_05_Translation.st:416` vers `TranslationState.PositionReached` (consommée séquenceur / IHM). Conséquence d'un `TargetReached` périmé à `TRUE` pendant que M3 est désactivé : un séquenceur ou un interlock utilisant `PositionReached` comme précondition pourrait croire M3 arrivé sur sa cible alors qu'il a pu dériver. L'entraînement M3 étant neutralisé, **pas de mouvement non commandé** ; le risque est une décision de séquencement / un permissif fondé sur une position fausse. Sévérité moyenne (dépend de l'usage aval de `PositionReached`, non tracé intégralement — voir Devoir d'alerte §7).

### Correctif proposé — FB_Translation

Dans le gate, juste avant `RETURN;` (ligne 124) :

```st
TargetReached := FALSE;
```

Source de la valeur sûre : `FALSE` = aucune cible confirmée quand le FB est neutralisé (le debounce `CaptorDebounceTon` n'est pas entretenu dans le gate ; publier `FALSE` est le fail-safe pour un permissif de position).
Interface : **inchangée** — `TargetReached : BOOL` déjà `VAR_OUTPUT` (70). Aucun nouveau `VAR`, aucun type modifié.

---

# SECTION AUTRES — 12 FB (hors C4)

---

## 5. FB_Brake

`CODE/A_COMMUN/FB_Brake.st` · Gate : lignes 52-59 (`IF NOT Enable THEN … RETURN;`). Neutralise `BrakeCmd := FALSE` (55). Ne touche pas `Status.ErrorId` (latch implicite par omission).

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_Brake | BrakeCommandOpenConfirmed | **BUG** [STAT] | Écrite corps §7 lignes 143/145 (`:= BrakeCmd` ou `:= ContactorFeedback`). Le gate ne la touche pas → figée. `BrakeCmd` est forcé `FALSE` dans le gate (frein commandé collé) : un « ouverture confirmée » périmé à `TRUE` fait croire à un verrou aval que le frein est desserré. |
| FB_Brake | ContactorCheck | **BUG (partiel)** [DIAG] | Struct. `.Command` (96) / `.Feedback` (97) : figés au dernier scan actif → **BUG**. `.StuckClosed` / `.StuckOpen` (105-106/109-110/114-115) : latch de défaut effacé uniquement sur front `Reset` (108-110), cohérent avec `Status.ErrorId` bit0 que le gate n'efface pas non plus → **OK-FIGE** (non documenté au gate, voir Devoir d'alerte §3). |

**risque physique :** [STAT]/[DIAG]. `BrakeCommandOpenConfirmed` de `FB_Translation`/`FB_Winch` (instances composées de `FB_Brake` ou logique équivalente) alimente des verrous d'autorisation de mouvement ; un `TRUE` périmé pendant `Enable=FALSE` est un permissif fondé sur une information fausse. Physiquement, la bobine frein suit la sortie DQ réelle (dé-énergisée hors `Enable`), donc pas de desserrage réel — le risque est logique (verrou aval trompé). Sévérité moyenne.

### Correctif proposé — FB_Brake

Dans le gate, juste avant `RETURN;` (ligne 58) :

```st
ContactorCheck.Command := FALSE;
ContactorCheck.Feedback := ContactorFeedback;
BrakeCommandOpenConfirmed := FALSE;
```

Source de la valeur sûre : `ContactorCheck.Command := FALSE` = miroir de `BrakeCmd := FALSE` (55). `ContactorCheck.Feedback := ContactorFeedback` = miroir véridique de l'entrée HW (reste significatif hors `Enable`). `BrakeCommandOpenConfirmed := FALSE` = frein commandé collé → ouverture non confirmée (fail-safe pour un permissif).
`ContactorCheck.StuckClosed` / `.StuckOpen` **volontairement non touchés** (latch, cohérent avec `Status.ErrorId` bit0 également conservé par omission).
Interface : **inchangée** — champs de `ST_ContactorCheck` et `BrakeCommandOpenConfirmed : BOOL` déjà déclarés (35-36). Aucun nouveau `VAR`, aucun type modifié.

---

## 6. FB_Encoder_Abs

`CODE/E_CODEURS/FB_Encoder_Abs.st` · Gate : lignes 70-79 (`IF NOT Enable THEN … RETURN;`). Neutralise `EncoderAvailable := FALSE` (71), `PresetTriggerCmd := 16#0000; CodeSeqTriggerCmd := 16#0000; PresetValueOut := 0;` (74).

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_Encoder_Abs | CodeSeqTriggerCmd | **OK-ALIM** | `PresetTriggerCmd := 16#0000; CodeSeqTriggerCmd := 16#0000; PresetValueOut := 0;` — ligne 74. |
| FB_Encoder_Abs | PresetValueOut | **OK-ALIM** | ligne 74. |
| FB_Encoder_Abs | RawPos | **OK-FIGE** | Écrite ligne 105 sous `IF EncoderAvailable`. Gel documenté : commentaire §4 lignes 101-103 (« GELER SUR DOUTE (Partie10 §6) … RawPos/AngleRaw/TurnCount conservent leur dernière valeur ») + commentaire sortie ligne 39 (« Position brute gelée si non disponible »). Publier `0` serait pire (position câble = 0 pour les consommateurs). Même logique que `FB_Encoder` (`Homed := Calib.Homed`). |
| FB_Encoder_Abs | AngleRaw | **OK-FIGE** | Ligne 106, même bloc / même doctrine que `RawPos`. |
| FB_Encoder_Abs | TurnCount | **OK-FIGE** | Ligne 107, même bloc / même doctrine que `RawPos`. |
| FB_Encoder_Abs | PresetAck | **BUG** [STAT] | Impulsion 1 cycle : `PresetAck := FALSE` chaque scan (117) puis `:= TRUE` (135). Le gate ne la remet pas à `FALSE` : si `Enable` tombe sur le scan où `PresetAck = TRUE`, l'impulsion reste figée à `TRUE` → un consommateur peut la relire comme « preset réussi ». |
| FB_Encoder_Abs | PresetNak | **BUG** [STAT] | Même sémantique impulsion (117/141). Figée à `TRUE` possible → « preset refusé » fantôme. |

**risque physique :** [STAT]. Les ordres HW vers le PDO (`PresetTriggerCmd`, `CodeSeqTriggerCmd`, `PresetValueOut`) sont bien neutralisés (74). `PresetAck`/`PresetNak` sont des impulsions consommées par la logique de référencement / IHM ; une impulsion figée fausse un enchaînement de séquence de preset. Pas d'action machine directe. Sévérité faible (probabilité faible, fenêtre 1 scan) mais sémantique d'impulsion cassée.

### Correctif proposé — FB_Encoder_Abs

Dans le gate, juste avant `RETURN;` (ligne 78) :

```st
PresetAck := FALSE;
PresetNak := FALSE;
```

Source de la valeur sûre : `FALSE` = pas d'impulsion quand le FB est désactivé (cohérent avec l'init d'impulsion ligne 117).
`RawPos` / `AngleRaw` / `TurnCount` **volontairement non touchés** (doctrine « geler sur doute », §4 lignes 101-103).
Interface : **inchangée** — `PresetAck` / `PresetNak : BOOL` déjà `VAR_OUTPUT` (45-46). Aucun nouveau `VAR`, aucun type modifié.

---

## 7. FB_Cycle

`CODE/G_CYCLE/FB_Cycle.st` · Gate : lignes 125-148 (`IF NOT Enable OR NOT PowerContactorEngaged THEN … RETURN;`). Neutralise toutes les demandes actionneurs (`WinchM1Cmd`/`WinchM2Cmd`/`TranslationCmd`/`BucketCmd` → 0/FALSE, 126-139), `State`/`CycleStep` → X0, `Ready`/`Busy`/`Done := FALSE`.

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_Cycle | Error | **OK-FIGE** | Non touché dans le gate. Effacé uniquement sur front `Reset` (§2 ligne 184 `IF ResetEdge.Q THEN Error := FALSE`). Latch de défaut → acquittement conscient, doctrine AGENTS.md « jamais de redémarrage auto après défaut ». |
| FB_Cycle | ErrorId | **OK-FIGE** | Idem, effacé ligne 185 sur front `Reset` seulement. Bitmask apparié à `Error`. |
| FB_Cycle | CycleStepAtError | **OK-FIGE** | Écrit sur front d'erreur (§2 lignes 160-162). Snapshot diagnostic « étape au moment du défaut » — doit survivre pour rester exploitable. |
| FB_Cycle | SpeedMismatchMps | **BUG** [DIAG] | Calculée chaque scan §2 ligne 168 (`:= ABS(M1_MeasuredSpeedMps - M2_MeasuredSpeedMps)`). Non recalculée dans le gate → écart vitesse périmé publié. |
| FB_Cycle | SpeedMismatchActive | **BUG** [DIAG] | Calculée §2 lignes 169-173 (dépend de `State = X7_CTRL_ASCENT`). Non recalculée dans le gate (où `State := X0`) → peut rester figée à `TRUE`. |
| FB_Cycle | SpeedMismatchConfirmed | **BUG** [DIAG] | `:= SpeedMismatchTimer.Q` (§2 ligne 175). Le gate n'entretient pas `SpeedMismatchTimer` → `.Q` figé, `SpeedMismatchConfirmed` non réaffectée. Alimente le latch `Error` (§2 ligne 207). Mitigation constatée : §2 recalcule tout au 1er scan actif **avant** la consommation §3 → pas de faux défaut au réarmement, mais valeur périmée publiée pendant toute la fenêtre désactivée (voir Devoir d'alerte §5). |

**risque physique :** les 3 BUG sont [DIAG] (synoptique IHM). Toutes les demandes d'actionneurs (`WinchM*Cmd`, `TranslationCmd`, `BucketCmd`) sont neutralisées dans le gate. Conséquence d'une valeur périmée : affichage IHM d'un écart / d'une confirmation de désynchro vitesse figés pendant que le séquenceur est désactivé. Pas de décision machine (le séquenceur ne tourne pas). Sévérité faible.

### Correctif proposé — FB_Cycle

Dans le gate, juste avant `RETURN;` (ligne 147) :

```st
SpeedMismatchTimer(IN := FALSE, PT := SpeedMismatchTimeout);
SpeedMismatchMps := 0.0;
SpeedMismatchActive := FALSE;
SpeedMismatchConfirmed := FALSE;
```

Source de la valeur sûre : `0.0` / `FALSE` = neutralisation ; reset explicite du `TON` interne pour que `.Q` ne reste pas figé (sinon `SpeedMismatchConfirmed` ré-alimenterait `Error` si l'ordre §2/§3 changeait un jour).
`Error` / `ErrorId` / `CycleStepAtError` **volontairement non touchés** (latch défaut, effacés seulement sur front `Reset` §2 — doctrine « jamais de redémarrage auto après défaut »).
Interface : **inchangée** — `SpeedMismatchTimer : TON` déjà `VAR` interne (110), `SpeedMismatchMps : REAL` / `SpeedMismatchActive` / `SpeedMismatchConfirmed : BOOL` déjà `VAR_OUTPUT` (71-73). Aucun nouveau `VAR`, aucun type modifié.

---

## 8. FB_DiveSearch

`CODE/G_CYCLE/FB_DiveSearch.st` · Gate : lignes 60-70 (`IF NOT Enable OR NOT PowerContactorEngaged THEN … RETURN;`).

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_DiveSearch | KoboldMeasureEnable | **OK-ALIM** | `DescendPermit := FALSE; KoboldMeasureEnable := FALSE;` — ligne 62. |
| FB_DiveSearch | OperatorAction | **OK-ALIM** | `OperatorActionId := 0; OperatorAction := '';` — ligne 67. |

Aucun BUG. Faux positifs G127 (affectations multiples sur une ligne, voir Devoir d'alerte §1).

---

## 9. FB_ExtractionSequence

`CODE/G_CYCLE/FB_ExtractionSequence.st` · Gate : lignes 64-73 (`IF NOT Enable OR NOT PowerContactorEngaged THEN … RETURN;`).

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_ExtractionSequence | AscentPermit | **OK-ALIM** | `BucketCloseRequest := FALSE; AscentPermit := FALSE; ForceMinSpeedStep := FALSE;` — ligne 66. |
| FB_ExtractionSequence | ForceMinSpeedStep | **OK-ALIM** | ligne 66. |
| FB_ExtractionSequence | OperatorAction | **OK-ALIM** | `OperatorActionId := 0; OperatorAction := '';` — ligne 71. |

Aucun BUG. Faux positifs G127.

---

## 10. FB_Bucket

`CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` · Gate : lignes 87-103 (`IF NOT Enable OR NOT PowerContactorEngaged THEN … RETURN;`). Neutralise `M2_StartStop := FALSE` (94), `M2_Direction := 0` (95), `M2_ForceSlowSpeed := FALSE` (96), `M1SlipDetected := FALSE` (98), `CloseReq`/`OpenReq := FALSE` (100-101).

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_Bucket | DeltaPosition_M | **BUG** [DIAG] | Calculée chaque scan ligne 496 (`:= CablePosM2 - CablePosM1`). Non recalculée dans le gate → écart périmé publié. |
| FB_Bucket | RemainingTravelM | **BUG** [DIAG] | Écrite seulement dans le `CASE Status.State` (READY 322, BUSY 356/358/360, DONE 480). Le `CASE` n'est pas atteint dans le gate → figée à la dernière valeur en mouvement si `Enable` tombe pendant `BUSY`. |
| FB_Bucket | ActiveOffsetM | **BUG** [DIAG-annoncé / en réalité alimente la synchro sécurité] | Écrite §7 lignes 507-518. Non recalculée dans le gate → **offset benne du dernier scan actif figé**. Câblée sans conditionnement dans `PRG_04_Treuils_Benne.st` : `:540` → `instWinchSync.ActiveOffsetM` ; `:701` / `:757` → `FB_Safety_Winch.ExpectedOtherWinchPosM` (Méca E, écart synchro critique M1/M2 → `SafeStop`/`PowerCutOff`) ; `:1119`/`:1123` → IHM. Une valeur périmée injecte un offset benne fantôme dans la comparaison de synchronisme M1/M2. |

**risque physique :** `DeltaPosition_M` et `RemainingTravelM` sont [DIAG] pures (IHM). `M2_*` (ordres vers le treuil M2) sont neutralisés (94-96).
`ActiveOffsetM` est le point le plus sensible de la section non-C4 : `SignedDeltaPosM = CablePosM1 - CablePosM2 + ActiveOffsetM` dans `FB_SyncDeviation` (ligne 67), et `ExpectedOtherWinchPosM` de `FB_Safety_Winch` (Méca E, bits 12/13 → `SafeStop` puis `PowerCutOff`). Selon le sens de l'écart réel M1/M2 au moment de la désactivation : soit un **faux** défaut synchro (nuisance `SafeStop`, direction sûre), soit un **masquage** d'un désynchronisme réel (offset fantôme qui compense l'écart → défaut non levé → risque télescopage / mou de câble). Mitigation partielle constatée (voir Devoir d'alerte §2) ; risque résiduel réel. **Sévérité élevée pour cette sortie** — à traiter comme C4-adjacente.

### Correctif proposé — FB_Bucket

Dans le gate, juste avant `RETURN;` (ligne 102) :

```st
DeltaPosition_M := 0.0;
RemainingTravelM := 0.0;
IF BucketState.IsClosed THEN
    ActiveOffsetM := Config.OffsetCloseM;
ELSIF BucketState.IsOpen THEN
    ActiveOffsetM := Config.OffsetOpenM;
ELSE
    ActiveOffsetM := 0.0;
END_IF;
```

Source de la valeur sûre : `DeltaPosition_M` / `RemainingTravelM` → `0.0` (aucun mouvement / mesure en cours). `ActiveOffsetM` → repris de l'état benne au repos, miroir exact de la logique corps §7 hors `BUSY` (lignes 509-514) — évite d'injecter un offset de trajet périmé dans la synchro sécurité.
Alternative plus simple, si validée contre `AF_Partie-10` : `ActiveOffsetM := 0.0;` seul (plus conservateur : produit un écart synchro visible plutôt qu'un masquage ; nuisance `SafeStop` possible si la benne est physiquement ouverte).
Interface : **inchangée** — `BucketState : ST_fbBucket_State` est `VAR_IN_OUT` (62), `Config : ST_fbBucket_Config` est `VAR_INPUT` (35), les 3 sorties déjà `VAR_OUTPUT` (56-58). Aucun nouveau `VAR`, aucun type modifié.

---

## 11. FB_SyncDeviation

`CODE/H_TREUILS_BENNE/FB_SyncDeviation.st` · Gate : lignes 55-60 (`IF NOT Enable THEN … RETURN;`).

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_SyncDeviation | SignedDeltaPosM | **OK-ALIM** | `DeltaPosM := 0.0; SignedDeltaPosM := 0.0;` — ligne 56. |
| FB_SyncDeviation | SyncDeviationFault | **OK-ALIM** | `SyncDeviationWarn := FALSE; SyncDeviationFault := FALSE;` — ligne 57. |

Aucun BUG. Faux positifs G127. FB entièrement propre.

---

## 12. FB_WinchSync

`CODE/H_TREUILS_BENNE/FB_WinchSync.st` · Gate : lignes 79-87 (`IF NOT Enable THEN … RETURN;`).

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_WinchSync | SignedDeltaPosM | **OK-ALIM** | `DeltaPosM := 0.0; SignedDeltaPosM := 0.0;` — ligne 82. |
| FB_WinchSync | SyncDeviationFault | **OK-ALIM** | `SyncWarn := FALSE; SyncDeviationWarn := FALSE; SyncDeviationFault := FALSE;` — ligne 84. |
| FB_WinchSync | SyncDeviationWarn | **OK-ALIM** | ligne 84. |

Aucun BUG. Faux positifs G127. FB entièrement propre.

---

## 13. FB_Safety_Translation

`CODE/I_TRANSLATION/FB_Safety_Translation.st` · Gate : lignes 84-104 (`IF NOT Enable THEN … RETURN;`). Neutralise `SafeStop := FALSE` (88), `PowerCutOff := FALSE` (89), les 8 `Error*` décapsulés → `FALSE` (90-97).

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_Safety_Translation | Ready | **OK-ALIM** | `Status.Busy := FALSE; Status.Done := FALSE; Ready := FALSE;` — ligne 103. |

Aucun BUG. Faux positif G127 (3ᵉ affectation de la ligne 103). FB de sécurité M3 audité au même niveau d'exigence — voir Devoir d'alerte §6.

---

## 14. FB_Translation_PositionEstimator

`CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st` · Gate : lignes 62-66 (`IF NOT Enable THEN … RETURN;`). Neutralise `Recalibrated := FALSE` (63), `RecalibratedSensorId := -1` (64).

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_Translation_PositionEstimator | PositionEstimatedM | **OK-FIGE** | Odométrie continue (intégration §3 ligne 132). En-tête lignes 34-38 : l'appelant recopie en continu `PositionEstimatedM`/`Initialized` vers `GVL_PERSISTENT` et réinjecte au redémarrage « pour ne pas perdre l'estimation odométrique à chaque coupure ». Zéroter dans le gate ferait croire M3 à la Trémie (0.0 m). Même doctrine que `FB_Encoder_Abs.RawPos` et `FB_Encoder` (`Homed := Calib.Homed`). |
| FB_Translation_PositionEstimator | Initialized | **OK-FIGE** | Flag latché « référence absolue acquise » (§3 lignes 119-126), persisté via l'appelant (en-tête 34-38, commentaire sortie ligne 43). Le remettre `FALSE` à chaque désactivation détruirait la référence odométrique — anti-pattern exact du REX `FB_Encoder`. |

Aucun BUG. Réserve : le gel est documenté dans le **bandeau d'en-tête**, pas au niveau du gate → voir Devoir d'alerte §4.

---

## 15. FB_TranslationOutputInterlock

`CODE/I_TRANSLATION/FB_TranslationOutputInterlock.st` · Gate : lignes 71-84 (`IF NOT Enable OR NOT PowerContactorEngaged THEN … RETURN;`). Neutralise `DriveControlWord := 0` (73), `DriveFreqCmd_Hz := 0.0` (74), `DriveFreqCmdWord := 0` (75), `BrakeCmd := FALSE` (76), `Reason := NONE` (83).

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_TranslationOutputInterlock | RestartInhibit | **OK-FIGE** | Non touché dans le gate. Commentaire explicite lignes 69-70 : « RestartInhibit et ResetRequired sont volontairement conservés : un changement Enable/AU ne doit jamais réautoriser automatiquement le mouvement après timeout. » Latch de sécurité — le mettre `FALSE` autoriserait un redémarrage auto après timeout desserrage frein. |

Aucun BUG. Barrière finale M3 : tous les ordres actionneurs (`DriveControlWord`, `DriveFreqCmd_Hz`, `DriveFreqCmdWord`, `BrakeCmd`) correctement coupés dans le gate. FB de sécurité audité au même niveau — voir Devoir d'alerte §6.

---

## 16. FB_Sim_Joystick

`CODE/L_SIMULATION/FB_Sim_Joystick.st` · Gate : lignes 88-95 (`IF NOT Enable THEN … RETURN;`). Neutralise `State := CST_ST_IDLE` (90), `RawX/RawY := NeutralRaw` (91-92), `RawButton := FALSE` (93).

| FB | sortie | verdict | preuve (corps + comportement) |
|---|---|---|---|
| FB_Sim_Joystick | ReturningActive | **BUG** [SIM] | Écrite ligne 229 `:= (State = CST_ST_FALL) OR (State = CST_ST_OVERSHOOT)`. Le gate force `State := CST_ST_IDLE` (90) mais ne recalcule pas `ReturningActive` → peut rester figée à `TRUE`, faisant continuer `FB_SimBench` à émettre la sortie du modèle après coupure de la simulation. |

**risque physique :** **nul** — brique de simulation de banc (Partie3 §1bis, « outil de banc, pas du métier machine »), jamais exécutée sur la machine réelle. Cosmétique.

### Correctif proposé — FB_Sim_Joystick

Dans le gate, juste avant `RETURN;` (ligne 94) :

```st
ReturningActive := FALSE;
```

Source de la valeur sûre : `FALSE`, cohérent avec `State := CST_ST_IDLE` fixé ligne 90.
Interface : **inchangée** — `ReturningActive : BOOL` déjà `VAR_OUTPUT` (55). Aucun nouveau `VAR`, aucun type modifié.

---

# TABLEAU DE SYNTHÈSE

Comptage à la granularité **sortie signalée par G127** (58 sorties sur 16 FB).

| FB | criticité | BUG | OK-ALIM | OK-FIGE | sorties |
|---|:---:|:---:|:---:|:---:|---|
| FB_Safety_Winch | **C4** | **3** | 0 | 0 | MecaADriftM, MecaBElapsedTime, MecaCDriftM |
| FB_WinchOutputInterlock | **C4** | 0 | 8 | 4 | — |
| FB_Winch | **C4** | **3** | 2 | 0 | ContactorsCheck, DirectionChangePending, SpeedGuardLimited |
| FB_Translation | **C4** | **1** | 1 | 0 | TargetReached |
| FB_Brake | — | **2** | 0 | 0¹ | BrakeCommandOpenConfirmed, ContactorCheck (partiel) |
| FB_Encoder_Abs | — | **2** | 2 | 3 | PresetAck, PresetNak |
| FB_Cycle | — | **3** | 0 | 3 | SpeedMismatchMps, SpeedMismatchActive, SpeedMismatchConfirmed |
| FB_DiveSearch | — | 0 | 2 | 0 | — |
| FB_ExtractionSequence | — | 0 | 3 | 0 | — |
| FB_Bucket | — | **3** | 0 | 0 | ActiveOffsetM ⚠️, DeltaPosition_M, RemainingTravelM |
| FB_SyncDeviation | — | 0 | 2 | 0 | — |
| FB_WinchSync | — | 0 | 3 | 0 | — |
| FB_Safety_Translation | — | 0 | 1 | 0 | — |
| FB_Translation_PositionEstimator | — | 0 | 0 | 2 | — |
| FB_TranslationOutputInterlock | — | 0 | 0 | 1 | — |
| FB_Sim_Joystick | — | **1** | 0 | 0 | ReturningActive [SIM] |
| **TOTAL** | | **21** | **24** | **13** | 58 |

¹ `FB_Brake.ContactorCheck` : verdict global **BUG** (champs `.Command`/`.Feedback` périmés) ; sous-champs `.StuckClosed`/`.StuckOpen` = OK-FIGE (latch). Compté 1 BUG dans le total.

**Counts :** 21 BUG · 24 OK-ALIM · 13 OK-FIGE.
**BUG sur FB C4 : 7** (FB_Safety_Winch 3, FB_Winch 3, FB_Translation 1 — tous [DIAG]/[STAT], aucun n'est un ordre actionneur ; les sorties [ACT/SAFE] des 4 FB C4 sont toutes correctement neutralisées).
**BUG hors C4 : 14**, dont **1 à sévérité élevée** : `FB_Bucket.ActiveOffsetM` (alimente Méca E de `FB_Safety_Winch` → `SafeStop`/`PowerCutOff` via PRG_04).
**OK-ALIM : 24 sur 24 = faux positifs de parsing G127** (affectations multiples sur une même ligne).

---

# DEVOIR D'ALERTE

### §1 — G127 : faux positifs de parsing (candidat `fix:` + `guard:`)
Le parseur de `G127_check_neutralization_completeness.py` ne découpe pas les affectations multiples d'une même ligne (`A := FALSE; B := FALSE;`). **24 des 58 sorties signalées (100 % des OK-ALIM) sont en réalité déjà neutralisées.** 5 FB signalés `[WARN]` sont entièrement propres : **FB_SyncDeviation, FB_WinchSync, FB_DiveSearch, FB_ExtractionSequence, FB_Safety_Translation**. Recommandation : durcir G127 (découper chaque ligne sur `;` avant de chercher les identifiants affectés) pour que le rapport reflète les vrais manques et ne noie pas les BUG réels.

### §2 — FB_Bucket.ActiveOffsetM : tag [DIAG] trompeur, chemin vers un FB de sécurité C4
`ActiveOffsetM` est déclarée `[DIAG]` mais câblée sans conditionnement dans `PRG_04_Treuils_Benne.st` vers `FB_WinchSync` (`:540`) et les **deux** instances `FB_Safety_Winch` (`:701`/`:757`, Méca E → `SafeStop` puis `PowerCutOff`). `instBucket.Enable := NOT PRG_03_Modes_Cycle.Auth.InhibitM2` (PRG_04:341) → le FB est désactivé dès que M2 est inhibé.
Mitigation partielle **constatée** : `instWinchSync.Enable` est aussi coupé sur `InhibitM1/M2` (PRG_04 §4), et Méca E de `FB_Safety_Winch` est supprimé par l'entrée `OtherWinchInhibited` (FB_Safety_Winch ligne 380).
Risque résiduel : la sûreté repose sur la cohérence de **trois** conditionnements séparés. Toute évolution du câblage `Enable` de `instBucket` (ou du gating de `FB_Safety_Winch`) qui les découplerait ré-ouvrirait un chemin « offset benne fantôme » dans la comparaison synchro M1/M2 → **masquage possible d'un désynchronisme réel** (télescopage / mou de câble). À valider contre `AF_Partie-10` : **quelle valeur d'offset un `FB_Bucket` désactivé doit-il publier ?** (0.0 vs offset de repos de la benne). Non tranchable en lecture seule.

### §3 — FB_Brake / FB_WinchOutputInterlock : latches non documentés au gate
`FB_Brake` : le gate ne préserve pas explicitement `Status.ErrorId` (bit0) ni `ContactorCheck.StuckClosed`/`.StuckOpen` — ils survivent **par omission** (latch implicite). Comportement probablement voulu (cohérent avec le pattern latch d'autres FB), **non documenté**. `FB_WinchOutputInterlock` : le commentaire lignes 84-86 nomme `ErrorId`/`RestartInhibit`/`ResetRequired` mais **pas** `Reason`, qui est pourtant laissée figée avec eux. Recommandation : commentaire explicite au gate listant toutes les sorties volontairement conservées + trancher (usage aval réel) si `BrakeCommandOpenConfirmed` doit valoir `FALSE` (permissif fail-safe) ou miroir `ContactorFeedback` (diagnostic véridique) — non décidable en lecture seule.

### §4 — FB_Encoder_Abs / FB_Translation_PositionEstimator : gel volontaire documenté loin du gate
`RawPos`/`AngleRaw`/`TurnCount` (geler sur doute) et `PositionEstimatedM`/`Initialized` (persistance odométrique) sont figés **volontairement** — mais la justification vit dans le **bandeau d'en-tête**, sans aucun commentaire au niveau du gate. Un futur contributeur peut le lire comme un oubli (exactement le piège du REX `FB_Encoder` 2026-07-29). Recommandation : ajouter une ligne de commentaire au gate (`// XXX volontairement conservé — voir §en-tête / AF09 §6`).

### §5 — FB_Cycle : TON internes non réinitialisés dans le gate
Le gate ne réinitialise aucun `TON` interne (`SpeedMismatchTimer`, `StabilizationTimer`, `StepMaxTimer`, `DrainingTimer`). Seul `SpeedMismatchTimer` produit un chemin potentiellement fautif (`SpeedMismatchConfirmed` figé → ré-alimente le latch `Error` §2 ligne 207). **Non exploité aujourd'hui** : §2 recalcule `SpeedMismatch*` au 1ᵉʳ scan actif **avant** la consommation §3 (les autres TON sont neutralisés par leur condition `IN` avec `State := X0`). Fragilité si l'ordre des régions §2/§3 change un jour. Le correctif proposé reset `SpeedMismatchTimer` explicitement.

### §6 — FB de sécurité hors liste C4 du contrat
`FB_Safety_Translation` et `FB_TranslationOutputInterlock` ne figurent pas dans la liste C4 du contrat T164-1, mais ce sont des FB de **sécurité** (Safety M3 + barrière finale M3). Audités au même niveau d'exigence : **aucun BUG** (1 faux positif OK-ALIM, 1 OK-FIGE `RestartInhibit` justifié par commentaire). Signalé pour visa orchestrateur.

### §7 — Consommateurs non intégralement tracés (lecture seule)
Faute de budget de traçage exhaustif des PRG : usage aval précis de `FB_Translation.TargetReached` (`TranslationState.PositionReached`), de `FB_Winch.ContactorsCheck` et des sorties [DIAG] de `FB_Safety_Winch` dans le diagnostic hiérarchique / le séquenceur. Les **verdicts BUG restent valides** (valeur périmée effectivement publiée hors `Enable`) ; la **sévérité « risque physique »** de chacun mérite confirmation par l'orchestrateur avec la vue PRG complète.

### §8 — Structure des gates : rien hors couverture G127
Les 16 gates ont la même structure : `IF NOT Enable [OR NOT PowerContactorEngaged] THEN … RETURN; END_IF;` — **un seul** `RETURN`, **aucune** neutralisation sans `RETURN`, **aucun** `RETURN` multiple dans le gate. Aucune structure de gate non couverte par G127 constatée.
