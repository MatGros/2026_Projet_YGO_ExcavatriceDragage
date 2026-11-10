# 🪝 DESIGN T181-01 — Protocole §3bis résolu + autorité des 2 interlocks · v0.1

> **Statut** : proposition pour **ARRÊT VALIDATION HUMAINE** (contrat `TASK_CONTRACT_T181-01`).
> Rien n'est codé tant que ce document n'est pas signé.
> Sources : `PLAN_GEL_TREUIL_T181_v0.1.md` §5 · contrat T181-01 (AC1–AC15) ·
> `MEMO_deepseek_T181-01_16_prepa.md` (options A/B/C) · audit C4 Codex 2026-08-30 (gel).

---

## 1 · Le blocage, formulé exactement

### 1.1 Contradiction §3bis
La règle §3bis veut : **quand `RequestedStep` retombe à 0 mais `RequestedRelayFwd/Rev` reste TRUE**
(chute de palier transitoire portée par FB_Winch), la barrière `FB_WinchOutputInterlock` **NE force
PLUS** `RelayFwd/Rev := FALSE` immédiatement — elle **tient** le contacteur de sens jusqu'à
confirmation `FwdRevSpeedFeedbackOff` OU `T_max`.

**Problème mécanique** : dans le code actuel de FB_Winch, `RequestedStep = 0` **implique**
`RequestedRelayFwd = RequestedRelayRev = FALSE` (le sens est dérivé du palier). La condition
d'entrée du §3bis (`RequestedStep=0 ET RelayFwd/Rev=TRUE`) **ne peut jamais être vraie**.

### 1.2 Feedback incompatible
`Mx_ContactorsReleased_DI` (entrée `FwdRevSpeedFeedbackOff`) est un retour **simple voie** de
l'ensemble des contacteurs. Pendant un maintien du sens (contacteur de sens fermé), ce retour
reste `FALSE` → il ne peut pas servir seul de critère C4 pour ouvrir le sens.

---

## 2 · Décision d'architecture (option C du mémo)

> **FB_Winch devient producteur explicite de l'intention de maintien.** La barrière n'infère plus.

### 2.1 Nouveau signal producteur — `FB_Winch`
| Signal | Type | Sémantique | Producteur |
|---|---|---|---|
| `SenseHoldRequest` | `BOOL` (sortie FB_Winch) | `TRUE` = FB_Winch demande de **tenir le contacteur de sens** alors que le palier est déjà retombé à 0 (chute de palier transitoire, inertie moteur). `FALSE` = plus aucune raison de tenir. | FB_Winch |

- `SenseHoldRequest := TRUE` **uniquement** quand : palier temporisé `StepNumber` vient de passer à 0
  **ET** le sens précédent était non nul **ET** aucune coupure dure active (voir §3).
- `SenseHoldRequest` retombe `FALSE` dès que : `Enable=FALSE` **OU** `SafeStop` **OU** `PowerCutOff`
  **OU** `Fault` dure **OU** `T_hold_internal` écoulé (garde interne FB_Winch, ≤ `T_max`).
- **Interface** : ajout **additif** d'une sortie `SenseHoldRequest` à `FB_Winch` + d'une entrée
  `SenseHoldRequest` à `FB_WinchOutputInterlock`. Les 2 sites PRG_04 + PRG_06 câblés au même commit.

### 2.2 Barrière `FB_WinchOutputInterlock` — §5 restructuré
Nouvelle logique du maintien borné (remplace le forçage `RelayFwd:=FALSE dès NOT MotorRequest`) :

```
SenseHoldActive := SenseHoldRequest
                   AND NOT Error_dur          (* §3 : liste dure *)
                   AND NOT (NOT Enable)
                   AND NOT (NOT PowerContactorEngaged)
                   AND NOT ContactorStuckLatched ;

IF SenseHoldActive THEN
    (* on TIENT RelayFwd/Rev à leur valeur courante, on ne les force pas à FALSE *)
    (* fin du maintien : *)
    IF   FwdRevSpeedFeedbackOff confirmé, debounce DropConfirmDelay (défaut 100 ms)
      OR SenseHoldTimer.ET >= MaxSenseHoldTime (T_max, défaut 1 s)
    THEN
        RelayFwd := FALSE ; RelayRev := FALSE ;
        IF timeout T_max sans confirmation ContactorsAllOff THEN
            ContactorStuck := TRUE ;      (* latché via FB_Safety_Winch *)
            SafeStopEscalation := TRUE ;
        END_IF
    END_IF
ELSE
    (* comportement nominal inchangé : NOT MotorRequest -> RelayFwd/Rev := FALSE *)
END_IF
```

### 2.3 Paramètres dédiés (AC8 — jamais réutiliser DeadTime*/DirectionInterlockDelay*)
| Paramètre | Défaut | Rôle | Ordre garanti |
|---|---|---|---|
| `DropConfirmDelay` | `T#100ms` | Debounce du retour `FwdRevSpeedFeedbackOff` avant d'ouvrir le sens | `DropConfirmDelay` **<** `MaxSenseHoldTime` |
| `MaxSenseHoldTime` (T_max) | `T#1s` | Filet : maintien indéfini INTERDIT → chute forcée + latch | — |

---

## 3 · Liste des coupures DURES (exemptées du maintien — AC9)

Ces chemins coupent `RelayFwd/Rev` **immédiatement**, sans passer par `SenseHoldActive` :
- `NOT Enable`
- `NOT PowerContactorEngaged` (perte chaîne puissance / AU)
- `SafeStop = TRUE` (rampe rapide métier — le sens tombe avec)
- `Fault.Error` **dure** = sous-liste : `ContactorStuck`, `BrakeWatchdog`, `RedundancyTestFailed`,
  incohérence codeur bloquante. *(La sous-liste exacte est à figer avec toi — voir §6 Q2.)*
- `RestartInhibit`

Un `DirectionDropBlocked` **transitoire** (≤ quelques cycles, fenêtre §3bis normale) **n'est PAS**
une gouvernance : `FinalInterlockGoverned` reste `FALSE` (AC4, clause compagnon).

---

## 4 · Interlock de cadence `FB_WinchRateInterlock` (D01, décision Q6)

| Élément | Décision |
|---|---|
| **Métrique de cadence** | `NbChangementsDePalier` dans une **fenêtre glissante** (ex. > 4 crans en 2 s). Pas la dérivée de vitesse (moins sensible, palier = état discret propre). |
| **Instance FB_Winch** | Seuils **safety + marge** (constantes en dur, source config A). Gouverne en premier. |
| **Instance PRG_06 (filet)** | Seuils **safety nus** (constantes en dur, source config B, disjointe de A). |
| **Passivité du filet** | L'instance PRG_06 reste passive (`Busy interne = FALSE`) tant que l'instance FB_Winch gouverne (marge active). Drapeau `MainRateInterlocked` publié par FB_Winch, lu par le filet. |
| **Non-bypassable** | L'instance interne FB_Winch **n'est PAS** neutralisée par `GVL_IHM.MxTreuil*.Bypass.Global`. |
| **Valeurs cadence montée** | **PROVISOIRES / TODO essai site** (base physique : thermique résistances rotoriques + choc de couple). Commentaire obligatoire `PROVISOIRE essai site` sur les constantes. |

---

## 5 · Critères d'acceptation sans HIL (rappel contrat, inchangés)

1. CI `FB_WinchOutputInterlock` **7/7** sur interface **additive contrôlée** (TC-012/013/021/022 verts,
   aucun TC vert ne repasse rouge — vecteur figé par T181-00).
2. `FinalInterlockGoverned = FALSE` sur **100 %** des vecteurs nominaux du harnais T181-00.
3. Injection « cadence > safety en contournant l'instance FB_Winch » → l'instance PRG_06 coupe.
4. Pas de double-freinage : instance FB_Winch gouverne (marge) → instance PRG_06 passive.
5. Nouveau TC « sens maintenu après chute vitesse jusqu'à ContactorsAllOff » + TC « T_max atteint
   sans confirmation → chute sens forcée + latch ».
6. Coupures dures : `Enable=FALSE` en marche → `RelayFwd=FALSE` au cycle suivant.
7. Gates : `G200` PASS · palier C PASS · `WINCH_INTEG` ne régresse pas · `MAIN_EndToEnd` vert.
8. Gardes nouvelles : `G4xx_check_direction_after_speed` (exemptions dures codées),
   `G4xx_check_rateinterlock_independence` (sources seuils disjointes),
   `G4xx_check_final_interlock_governed_false`.

---

## 6 · Questions à trancher AVANT écriture (ta signature)

| # | Question | Défaut proposé |
|---|---|---|
| **Q1** | `SenseHoldRequest` produit par FB_Winch : OK sur le principe (option C) ? Ou tu préfères option B (barrière déduit seule, sans changement d'interface FB_Winch, mais PLr plafonné b/c) ? | **Option C** |
| **Q2** | Sous-liste « Fault.Error dure » exacte (§3) : `ContactorStuck` + `BrakeWatchdog` + `RedundancyTestFailed` + incohérence codeur ? Autre ? | ces 4 |
| **Q3** | `T_max` = `T#1s` et `DropConfirmDelay` = `T#100ms` : valeurs OK pour signature, ou à ajuster ? | 1 s / 100 ms |
| **Q4** | Métrique cadence = `NbCrans/fenêtre` ( > 4 crans / 2 s) : OK ? Valeurs provisoires assumées ? | oui, provisoires |
| **Q5** | Argument PLr : fonction = « empêcher le maintien indéfini du stator sous tension ». PLr visé **d** (feedback simple voie + T_max + latch). Acceptable, ou exigence PLr e (double voie hétérogène à câbler) ? | **PLr d**, e = évolution site |
| **Q6** | Séquencement : ce lot APRÈS T181-05 (sous-FB extraits) et T181-02/03 (TC-011). `bloque_par` conservé : T181-00, T175, T181-05. Confirmé ? | oui |

---

## 7 · Une fois signé — plan d'implémentation (indicatif)

1. `FB_Winch` : ajout sortie `SenseHoldRequest` + garde interne `T_hold_internal`. Interface additive.
2. `FB_WinchOutputInterlock` : entrée `SenseHoldRequest` + `DropConfirmDelay` + `MaxSenseHoldTime` ;
   §5 restructuré (`SenseHoldActive`), chemin `ELSIF NOT MotorRequest` retravaillé.
3. `FB_WinchRateInterlock` (nouveau FB) : 2 jeux de constantes disjointes. Instancié FB_Winch + PRG_06.
4. `FB_Safety_Winch` : entrée de déclenchement `ContactorStuck` sur T_max.
5. PRG_04 + PRG_06 : câblage `SenseHoldRequest` + instance filet, **même commit**.
6. TC CI + 3 gardes G4xx.
7. `G200` + palier C + `WINCH_INTEG` + `MAIN_EndToEnd` + bundle.
