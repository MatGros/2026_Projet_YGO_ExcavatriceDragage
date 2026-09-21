# 🔬 DIAGNOSTIC T224 — `ArmingPermit` cohérent avec la disponibilité réelle

> **Nature** : DIAGNOSTIC SEUL — **zéro ligne de `CODE/` écrite**, zéro commit, zéro bundle, zéro gate.
> **Tâche** : T224 (C4) — Étape A du brief v2 (`DOC/WFLOW/CONTRACTS/BRIEF_T224_ARMINGPERMIT_COHERENT_v2_TRANSMISSION.md` §5).
> **Contrat** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T224_ARMINGPERMIT_ACTIONNEUR_PRET.yaml`
> **Date** : 2026-09-21 · **Porteur** : DSH28 · **Modèle** : deepseek-v4.1-flash:cloud
> **Méthode** : lecture seule stricte. Toute affirmation porte `fichier:ligne` ou un hash de commit.
> Une hypothèse non instruite est écrite comme hypothèse, jamais comme fait.

---

## 0. 🔐 ANCRAGE DE RÉVISION (AC2)

| Élément | Valeur |
|---|---|
| `HEAD` (lecture 2026-09-21, `git rev-parse --short HEAD`) | **`25101c0b`** |
| `git status --short -- CODE/` à la prise | **NON PROPRE** — 3 fichiers modifiés par un **autre lot en cours** |
| `git diff --stat -- CODE/` à la prise | `FB_CycleMachineHoming.st` +49/-…, `FB_CycleSemiAuto.st` +14, `FB_Hmi_BannerFormatter.st` +39/-… (85 insertions, 17 suppressions) |
| Tâche concurrente identifiée | **T368** (chrono de cycle dans le bandeau) — touches `FB_Hmi_BannerFormatter.st` |

⚠️ **Conséquence de méthode, à respecter par tout lecteur** : les numéros de ligne cités pour
`CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st` sont ceux **de l'arbre de travail (fichier sale)**.
Pour ce seul fichier, l'équivalent à `HEAD` est indiqué entre parenthèses (`HEAD:NNN`).
Tous les autres fichiers cités sont **identiques à `HEAD`** (non listés par `git status --short -- CODE/`).

| Fichier clé | État vs HEAD |
|---|---|
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | identique à HEAD |
| `CODE/M_MAIN/PRG_06_Outputs.st` | identique à HEAD |
| `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` | identique à HEAD |
| `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` | identique à HEAD |
| `CODE/D_JOYSTICK/FB_Joystick.st` | identique à HEAD |
| `CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st` | **SALE (T368)** — décalage de +38 lignes après `l.284` |

---

## 1. 🎯 RÉPONSE COURTE (à lire avant tout)

1. **Le défaut « commande sans mouvement » n'existe pas sous ce nom dans le code.** C'est une
   formulation de **mail client / brief** (catalogue `DOC/WFLOW/TASKS.yaml:2983-2984`). Le défaut réel
   le plus proche est **`ErrorNoMovement` = bit15 `16#8000`**, produit par `FB_Safety_Winch`
   (`CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:437-447`), affiché à l'IHM sous un **troisième** libellé :
   `'[M1] ErrorID:16 - discordance commande/retour/mouvement'` (`FB_Hmi_BannerFormatter.st:945`, `:993` / HEAD:907, 955).
2. **Le vrai trou n'est pas le défaut, c'est la fenêtre silencieuse.** Trois familles de conditions
   produisent « armé, aucun mouvement, **aucun défaut** » : tempos idle de la barrière finale
   (famille 1, 500/700 ms), refus directionnel final muet (`PermitFinalBlocked`), et permis
   **appliqué** plus restrictif que le permis **compté** par `ArmingPermit` (M2 benne, M3 trémie).
   ⚠️ **Aggravant** : le détecteur `ErrorNoMovement` est **inhibé** pendant `RefWindowActive`/`BenneBusy`
   (`FB_Safety_Winch:438`) ⇒ dans ces modes (homing, benne, pilotage unitaire, **MAINT_N1 = mode de la
   trace 67**) la fenêtre silencieuse est **non bornée**, pas limitée à 3 s.
3. **La preuve terrain la plus directe EXISTAIT DÉJÀ, dans une fiche du 2026-09-20** :
   `TROUBLESHOOTING_MAINT_COUPLE_INTERLOCK_TRACE64_20260920.md:23`/`:26` — *« Demande descente,
   `DeadmanArmed=1`, **`ArmingPermit=1`**, aucun relais, aucun ErrorId tracé »*, **répété** sur
   133-147 s, avec `:33` *« **Armement global → Éliminée** »* et `:42` *« blocage logique durable …
   **avant les sorties** »*. Confirmé par `Suivi_67_SIMU_MaintMANU_20260919_wide.csv` : 13 runs
   contigus « armé + demande > 5 % + vitesse M1 = M2 = 0 », le plus long **10 356 ms**, avec
   **`ArmingPermit = 1` et `ArmingPermitDenied = 0` sur 100 % des échantillons**.
   Le symptôme est **instrumenté** ; la chute de permis n'a **jamais** lieu.
4. **Le correctif « rendre lisible l'état de la barrière » est DÉJÀ CADRÉ dans le dépôt depuis le
   2026-09-05** — `TROUBLESHOOTING_BenneOuverture_BlocageCouplage_20260905.md:53-54`, `:60` décrit déjà
   le masquage (`:53` « la barrière finale masque donc l'action »), le défaut de diagnostic (`:54`) et
   la liste exacte à publier (`:60`, *« à planifier C4 »*). **L'option A n'est pas une proposition
   nouvelle : c'est un cadrage existant jamais planifié.**
4. **Le seul outil d'explication de l'opérateur affiche un FAUX VERT dans ces cas** :
   `ST_MotionChecklist.st:30` conclut *« TOUTES LES CONDITIONS SONT REMPLIES, LES RELAIS DOIVENT
   COLLER ! »* alors que les branches `PermitFinalBlocked` (`FB_WinchOutputInterlock:393-404`) et
   `WAIT_RESTART_DELAY` (`:424-430`) ne posent **ni `Reason` ni `Fault.Error`** ⇒ `Step8_OutputInterlockOk`
   (`FB_TroubleshootingView.st:577`) reste TRUE. **Pire qu'un silence : une fausse piste.**
5. **`ArmingPermit` ≈ toujours 1 est structurel**, pas un effet de T228 : l'agrégat est un **OR sur
   6 axes×sens** (`PRG_04:1175-1177`) → à l'arrêt il est quasi toujours VRAI. Le contrat T224 le
   savait (« rendre `ArmingPermit` inutile est un échec », brief v2 §6 A7) : ce n'est pas un
   accident de plomberie, c'est **la forme X mal servie par son agrégat**.
6. **`Data.ArmingAvailability` est écrit et lu par PERSONNE** (14 affectations `PRG_04:1192-1214`,
   + le DUT + la déclaration `ST_WinchInterPrg.st:80` : **0 consommateur**, grep re-vérifié).
   **Le diagnostic existe, il n'est pas branché.**
7. **Le « Défaut 2 » du cadrage T325 est CORRIGÉ à HEAD** (`657be973`, ancêtre de HEAD vérifié).
   Le brief v2 §3.4 et le cadrage `CADRAGE_T325_D18_INTERLOCK_DIRECTION_v1.0.md:46-70` sont **périmés**
   sur ce point : ne pas re-scoper une famille 2 déjà traitée.

---

## 2. 🗺️ CARTOGRAPHIE EXHAUSTIVE DES CONDITIONS (Étape A, §2.1 du brief)

### 2.0 Définitions de travail (pour que la table soit lisible)

| Terme | Définition retenue, prouvée |
|---|---|
| **Famille 1** | Commande **émise** (ou émise à un étage amont) puis **refusée par un interlock aval** — périmètre T224. |
| **Famille 2** | Commande **jamais formée** parce que bloquée **en amont** (T325 / D18) — `RampTargetStep := 0` avant tout calcul d'ordre contacteur. |
| **Famille 3** | Autre. Nommée et prouvée : **3a** = état local du geste joystick · **3b** = cause safety latcheé (`FB_Safety_Winch`) · **3c** = condition de base / verrou métier amont · **3d** = garde d'arbitrage. |
| **Couvert par `ArmM*Avail`** | La condition apparaît-elle dans `PRG_04:1164-1173` (calcul de `ArmM*Avail`) — directement, ou via `EffectivePermitM*_*` (l.1111-1114) / `ProcessAndSafetyPermitM*_*` (l.1070-1096) ? Ligne de preuve donnée à chaque fois. |
| **État concerné** | `pause volontaire` (relâchement, `ArmingPermit` **inchangé**) ≠ `SafeStop` (perte de permis, coupure dure **sans défaut**) ≠ `PowerCutOff` (perte de permis, neutralisation **+ `RestartRequired` armé**). Voir §5. |
| **Risque de désarmement abusif** | Quel axe×sens **réellement disponible** serait désarmé à tort (AC5). « Aucun » = la condition ne touche que l'axe concerné et il est réellement indisponible. |

### 2.1 Table unique — une ligne par condition (47 conditions)

| # | Condition (nom exact) | Fichier:ligne (PREUVE) | Producteur | Famille | Couvert par `ArmM*Avail` ? (pourquoi) | État concerné | Risque de désarmement abusif |
|---|---|---|---|---|---|---|---|
| **C01** | `ArmModeDisabled := (Auth.Mode = E_Mode.DISABLE)` | `PRG_04:1186`, motif `:1191-1192`, agrégat `:1205` | `PRG_04_Treuils_Benne` | **3c** | **OUI** — terme explicite de l'agrégat `:1205` | n/a (mode) | Aucun. Effet de bord : sa priorité de motif (`:1191`) **masque** toutes les autres causes dans `BlockedReason`. |
| **C02** | `ArmContactorOff := NOT HwIn.Machine.PowerContactorEngaged_DI` | `PRG_04:1187`, `:1193-1194` | `PRG_04` (DI ← `PRG_02:446` `SEL`) | **3c** | **OUI** — terme `:1205` | AU non réarmé (≠ movement) | ⚠️ **Fondé sur un DI**. Si figé FALSE → `ArmingPermit` FALSE permanent (même classe que la leçon T228-A2). Bypass possible : `HwSim` via `MachineInputSourceSimulated := SimulationModeActive AND SimSafetyActive` (`PRG_02:138`, `:446`). |
| **C03** | `ArmPowerCutOff := PowerCutOff M1 OR M2 OR M3` | `PRG_04:1188-1189`, motif `:1195-1196`, agrégat `:1205` | `PRG_04` (agrège `instSafetyWinchM1/M2`, `PRG_05`) | **3c** | **OUI** — terme `:1205` | **PowerCutOff** | Désarmement **global** (3 axes) : légitime, mais **non distingué de `SafeStop` côté IHM** (aucun champ affiché — cf. C42/G2). |
| **C04** | `ArmBucketBusy := (instBucket.Lifecycle.Busy OR BenneBusyFallEdge.Q) AND (Mode <> SEMI_AUTO) AND NOT ReqOpen AND NOT ReqClose` | `PRG_04:1182-1185`, `:1197-1198` | `PRG_04` (`instBucket`, `PRG_03`) | **3c** | **OUI** — terme `:1206` | **pause** de fin d'action benne (1 scan) | **OUI, assumé** : désarmement **global** pendant un cycle benne, y compris M3 réellement disponible. C'est le seul désarmement croisé explicitement voulu (AC1) et il **n'est pas nommé** pour l'opérateur. ⚠️ **Variante PERMANENTE (risque rapporté, non revérifié par DSH28)** : `instBucket.Lifecycle.Busy` est posé par front (`FB_Bucket:509-515`) et n'est relâché que sur les branches d'atteinte de fin de manœuvre (`:517-524`, `:637-660`) ⇒ si la manœuvre benne n'atteint jamais sa condition de fin, `ArmBucketBusy` reste TRUE **indéfiniment** ⇒ **plus aucune commande treuil possible au joystick**. Risque d'exploitation relevé par `TROUBLESHOOTING_T354…:282` (`FB_Bucket:230`, `:242-245`, `:476-480`, `:493-501`) — **à confirmer**, puis à croiser avec G2 (aucun motif affiché). |
| **C05** | `ArmAnyAxisAvail := OR des 6 dispos` | `PRG_04:1175-1177`, motif `:1199-1200`, agrégat `:1206` | `PRG_04` | **3c** | **OUI** — c'est le terme | n/a | ⚠️ **C'est la cause racine de « ArmingPermit ≈ 1 (inutile) »** : un OR large rend l'agrégat quasi toujours VRAI à l'arrêt. Aucun désarmement abusif ; **échec d'informativité** (A7). |
| **C06** | `instSafetyWinchM1.Fault.Latched` | `PRG_04:1164-1165` | `FB_Safety_Winch` (socle `FB_FaultCore`) | **3b** | **OUI** — terme explicite | faute latcheé (dont C43 bit15) | Non : M2/M3 préservés (sauf couplage C07). Conforme AC5. |
| **C07** | `SafeStopM1_Active := SafeStopM1_Raw OR (CoupledBoth AND SafeStopM2_Raw)` | `PRG_04:1105`, propagé `:1111`, `:1113` ; `CoupledBoth` `:1103` | `PRG_04` | **3b** | **OUI** — via `EffectivePermitM1_*` `:1113` | **SafeStop** | **OUI, assumé** : en couplage (synchro OU both), le SafeStop d'un treuil retire le permis de l'autre→ M2 sain désarmé. Anti-télescopage, doctrine explicite `:1098-1102`. |
| **C08** | `instSafetyWinchM2.Fault.Latched` | `PRG_04:1166-1167` | `FB_Safety_Winch` | **3b** | **OUI** — terme explicite | faute latcheé | Non (symétrique C06). |
| **C09** | `SafeStopM2_Active := SafeStopM2_Raw OR (CoupledBoth AND SafeStopM1_Raw)` | `PRG_04:1106`, `:1112`, `:1114` | `PRG_04` | **3b** | **OUI** — via `EffectivePermitM2_*` `:1114` | **SafeStop** | Idem C07, symétrique. |
| **C10** | `WinchDescentAuth_M3 = FALSE` → `ProcessAndSafetyPermitM1_Descend := FALSE` | `PRG_04:1083-1084` | `PRG_03_Modes_Cycle.Data.SequenceState` | **3c** | **OUI** — via `:1070` → `:1111` | verrou métier trémie | **OUI, borné** : retire la **descente** M1 seulement. Mais si M1-descente est le seul dispo, `ArmingPermit` tombe → désarmement de M2/M3 pourtant disponibles. Effet croisé via C05. |
| **C11** | … `ProcessAndSafetyPermitM2_Descend := FALSE` (hors exemption benne) | `PRG_04:1085-1089` | `PRG_03` | **3c** | **OUI** — via `:1071` → `:1112` | verrou métier trémie | Idem C10 pour M2-descente. |
| **C12** | **`M2AscentPermitApplied`** (défense en profondeur benne) vs `ArmM2AscentAvail` | appliqué `PRG_04:1131-1132` + câblé `:1529` et `:1628` · **compté** `PRG_04:1166` | `PRG_04` | **1** | ❌ **NON** — `:1166` ne porte que `EffectivePermitM2_Ascent AND NOT Fault.Latched` ; le terme `(NOT instBucket.M2_RunRequest OR EffectivePermitBucket_Close)` de `:1131-1132` **n'y est pas** | pause volontaire / indispo benne | ⚠️ **OUI — le cas le plus net.** Si `instBucket.M2_RunRequest = TRUE` et `EffectivePermitBucket_Close = FALSE`, `FB_Winch` M2 reçoit le permis **appliqué** (`:1529`) → `EffectiveSafeStop` (`FB_Winch:169-171`) → `RampTargetStep := 0` (`FB_Winch:217`) → **aucun ordre, aucun défaut** ; et `ArmingPermit` reste **TRUE** si un autre axe est dispo. |
| **C13** | **`M2DescendPermitApplied`** vs `ArmM2DescendAvail` | appliqué `PRG_04:1133-1134` + `:1528` / `:1629` · compté `PRG_04:1167` | `PRG_04` | **1** | ❌ **NON** — même écart que C12 | pause volontaire / benne | ⚠️ OUI, symétrique C12. |
| **C14** | `EffectivePermitBucket_Close` (condition de C12) | `PRG_04:1123-1127` | `PRG_04` | **1** | ❌ **NON** — n'entre dans `ArmM*Avail` que par C12, absent | benne fermée / codeurs non référencés / faute benne | OUI : `EncoderM1.Homed` / `EncoderM2.Homed` (`:1119-1120`, `:1124-1125`) insuffisants ⇒ permis benne FALSE ⇒ C12. |
| **C15** | `EffectivePermitBucket_Open` (condition de C13) | `PRG_04:1118-1122` | `PRG_04` | **1** | ❌ **NON** — idem | benne benne ouverte / faute benne | OUI, symétrique C14. |
| **C16** | `instBucket.M2_RunRequest` (déclencheur du gate benne) | `FB_Bucket.st:552`, `:556`, `:560` | `FB_Bucket` | **1** | ❌ **NON** | benne en pilotage automatique | OUI : c'est lui qui active le terme benne de C12/C13. |
| **C17** | **`TraceM2.FinalPermitBlocked`** (diagnostic IHM) — calculé sur le permis **effectif** | `PRG_04:1887-1888` (vs `:1885` qui publie l'appliqué) · miroir `PRG_07:822` | `PRG_04` | **1** (diagnostic) | ❌ **NON** — le diagnostic est bâti sur `EffectivePermitM2_*`, pas sur le permis appliqué | benne | ⚠️ **OUI — aggrave C12** : `GVL_IHM.Permits.M2FinalPermitBlocked` reste **FALSE** alors que M2 est refusée. L'opérateur n'a **aucun** signal. (Pour M1 le diagnostic est correct : `:1838` appliqué = `:1837` effectif.) |
| **C18** | **`M3_PosTremie_DI`** — terme **ajouté par la barrière** M3 | barrière `PRG_06:439-440` · **compté** `PRG_04:1168` | `PRG_06_Outputs` | **1** | ❌ **NON** — `:1168` lit `EffectivePermitM3_Tremie` **nu**, sans `AND NOT M3_PosTremie_DI` | M3 arrivé en trémie | ⚠️ **OUI.** À l'arrêt en trémie, `ArmM3TremieAvail = TRUE` mais le permis final est FALSE ⇒ `PermitFinalBlocked` (`FB_TranslationOutputInterlock:85-86`) ⇒ `DriveControlWord := 0` (`:146-151`) : **silencieux**, `Reason` non posé, aucun défaut. |
| **C19** | `M3_TremieHardStopActive` (`M3_PosTremie_DI AND ReqTremieSemantic`) | `PRG_06:431-432`, forcé `:442-450` | `PRG_06` | **1** | ❌ **NON** | M3 en trémie, demande trémie | ⚠️ OUI : la demande est annulée **avant** la barrière ⇒ `MovementRequested = FALSE` ⇒ `State` inchangé, **aucun motif**, aucun défaut. |
| **C20** | `TranslationSafety.SafeStop` / `.PowerCutOff` (M3) | `PRG_04:1169-1170`, `:1172-1173` ; producteur `PRG_05:769-770` | `PRG_05_Translation` / `FB_Safety_Translation` | **3b** | **OUI** — termes explicites | **SafeStop** / **PowerCutOff** M3 | Non : M1/M2 préservés. Conforme AC3. |
| **C21** | `M3_TremieProcessBlock` (inclus dans le permis effectif M3) | `PRG_05:541-544` | `PRG_05` | **3c** | **OUI** — inclus dans `EffectivePermitM3_Tremie` lu par `:1168` | verrou métier | Aucun (M3 seulement). **Contre-exemple utile** : M3 est mieux couvert que M2 parce que son verrou métier est **dans** le permis effectif. |
| **C22** | `RestartRequired` → `WAIT_RESTART_DELAY` (`AuthorizedStep := 0`) | `FB_WinchOutputInterlock:71`, armé `:170`, `:222` ; purgé `:226-228` ; état `:424-430` | `FB_WinchOutputInterlock` (appelé `PRG_06:149`) | **1** | ❌ **NON** — `PRG_04:1164-1173` ne porte **aucun** terme de tempo ni de `Ready` de la barrière | **pause volontaire** (relâchement puis ré-appui) | ⚠️ **OUI — cœur de G1.** `ArmingPermit` reste TRUE pendant que `AuthorizedStep := 0` : aucune commande de palier. Le geste reste armé, rien ne bouge, **aucun défaut**. |
| **C23** | `DeadTimePending` → `WAIT_RESTART_DELAY` | `:110`, armé `:246-248`, purgé `:252-254`, `:256-270` ; PT `:250` ; état `:424-430` ; valeurs `DeadTimeSameDir = T#500ms`, `DeadTimeOppositeDir = T#700ms` `:35-36` | `FB_WinchOutputInterlock` | **1** | ❌ **NON** | **pause volontaire** / inversion de sens | ⚠️ OUI : **500 ms** (même sens) ou **700 ms** (inversion) d'impossibilité muette. |
| **C24** | `RestartInhibit` → `State := FAULT`, `Reason := RESTART_INHIBITED` | `:70`, `:202-212`, posé `:502-509`, état `:357-363` ; acquitté `:510-514` (`ResetEdge`) | `FB_WinchOutputInterlock` | **1** | ❌ **NON** — le `Fault.Latched` lu en `PRG_04:1164` est celui de **`FB_Safety_Winch`**, pas de la barrière | faute latchée (timeout frein barrière) | ⚠️ OUI : axe **définitivement** indisponible (exige `Reset`), `ArmingPermit` TRUE. |
| **C25** | `ContactorStuckLatched` → `Reason := SENSE_DROP_TIMEOUT` | `:115`, `:80`, posé `:314-318`, état `:364-373`, acquitté `:513` | `FB_WinchOutputInterlock` | **1** | ❌ **NON** | latch §3bis (retour contacteurs de sens absent) | ⚠️ OUI : latch à acquitter, **invisible** côté arming. |
| **C26** | **`PermitFinalBlocked`** → coupure **muette** | `:87` (VAR **privée**), `:186-187`, branche `:393-404` | `FB_WinchOutputInterlock` | **1** | ❌ **NON** — variable locale non publiée, donc **structurellement** hors de portée de `PRG_04` | refus directionnel final | ⚠️ **OUI, le plus grave en diagnostique** : `State := READY` (`:404`), **`Reason` n'est PAS posé** dans cette branche, `RelayFwd/Rev` coupés. L'axe est refusé et la barrière se déclare **saine**. |
| **C27** | `Fault.Error` bit0 barrière (`BrakeTimeout` 500 ms) | `:53`, `:494-519`, `:540-548` ; `instCauses[0]` `:528-532` | `FB_WinchOutputInterlock` | **1** | ❌ **NON** | faute finale frein | ⚠️ OUI : la barrière coupe, `ArmingPermit` TRUE. Escalade safety seulement après `PostRampTimeout = T#3s` (`FB_Safety_Winch:49`, `:340-343`) → **3 s d'écart**. |
| **C28** | `BrakeFeedback` (DI) — **condition de purge** de `RestartDelay` et `DeadTime` | `:224`, `:250` ; source `PRG_04:1601` (`M1_BrakeIsOpen_DI`) | DI (hardware) | **1** (aggravant) | ❌ **NON** | dépend d'un DI | ⚠️ **OUI, sous condition inverse d'une première lecture** — les deux temporisations ne décomptent que si `NOT BrakeFeedback`, c'est-à-dire **frein confirmé FERMÉ** (`:216-220` : *« le frein est physiquement confirmé fermé (NOT BrakeFeedback = bobine retombée, mâchoires serrées) »*). Donc : un DI qui lit **FALSE** (= « frein pas ouvert ») **autorise** la purge (cas normal au repos) ; le blocage survient si le DI reste **TRUE en permanence** (frein lu « ouvert » alors qu'il ne l'est pas) ⇒ `RestartRequired`/`DeadTimePending` **jamais purgés** ⇒ mouvement définitivement impossible, **aucun défaut**, `ArmingPermit` TRUE. **État réel du DI sur machine : NON PROUVÉ** (aucune trace ne porte ce signal ; `REGISTRE_Suivi_MiseEnService_20260902.md:130` ne force que les 2 DI `ContactorsReleased`). |
| **C29** | `FwdRevSpeedFeedbackOff` (DI) → maintien §3bis | `:283`, `:309-318` ; source `PRG_04:1602` (`M1_ContactorsReleased_DI`) | DI (hardware) | **1** (même classe que C28) | ❌ **NON** | dépend d'un DI | Figé TRUE ⇒ `SenseHoldFeedbackTimer.Q` immédiat ⇒ chute **normale** du sens (pas de latch) ; figé FALSE ⇒ `ContactorStuckLatched` au bout de `MaxSenseHoldTime = T#400ms` (`:43`) ⇒ **C25**. C'est **exactement** le DI du chemin rapide cassé par T228 (`§4 G3`). |
| **C30** | Sortie couple M3 : `MovementRequested AND NOT PermitFinalBlocked` **ET** `BrakeReleaseRequest AND BrakeCommandOpenConfirmed` | `FB_TranslationOutputInterlock:146-150`, `:85-86` | `FB_TranslationOutputInterlock` (appelé `PRG_06:434`) | **1** | ❌ **NON** — `PRG_04:1168-1173` ne porte aucun terme frein | frein M3 non confirmé | ⚠️ OUI : permis OK, `DriveControlWord := 0` **silencieux**, `Reason` non posé. |
| **C31** | `RestartInhibit` M3 → `Reason := RESTART_INHIBITED` | `:41`, `:90`, `:102-108`, `:144-145` | `FB_TranslationOutputInterlock` | **1** | ❌ **NON** | faute latchée frein M3 | ⚠️ OUI : indisponibilité **durable** (exige `Reset`), `ArmM3*Avail` TRUE. |
| **C32** | `Fault.Error` M3 (timeout frein 500 ms) | `:95-99`, `:115-120`, `:140-141` | `FB_TranslationOutputInterlock` | **1** | ❌ **NON** | faute finale frein M3 | ⚠️ OUI : idem C31, non latcheé mais durable tant que la cause persiste. |
| **C33** | `DirectionChangePending` → `RampTargetStep := 0` | `FB_WinchDirectionInterlock:143`, `:154`, `:158` · consommé `FB_Winch:216-217` | `FB_WinchDirectionInterlock` | **2** | ❌ **NON** | inversion / reprise de sens | **OUI** : aucun ordre formé, **aucun défaut** — famille 2 historique (trace 67). |
| **C34** | `DeadTimeArmed` (D18) | `FB_WinchDirectionInterlock:106-107`, `:140-143` ; `EnableRising` ← `FB_Winch:198-199` | `FB_WinchDirectionInterlock` | **2** | ❌ **NON** | front `Enable` avec sens maintenu | **⚠️ PÉRIMÉ : corrigé à HEAD.** L'ordre est désormais `ELSIF DirectionChangeDelay.Q` (`:132`) **AVANT** `ELSIF DeadTimeArmed` (`:140`) — commit **`657be973`** (2026-09-20), ancêtre de HEAD vérifié (`git merge-base --is-ancestor 657be973 HEAD` → 0). Le « Défaut 2 » du cadrage T325 v1.0 (`:46-70`) est **obsolète** ; voir aussi `TASKS.yaml:316` (dette documentaire déjà cataloguée). |
| **C35** | `RequestConflict := ReqAscent AND ReqDescend` → `RequestActive := FALSE` | `FB_WinchDirectionInterlock:70-71` ; `FB_Winch:168` | `FB_WinchDirectionInterlock` / `FB_Winch` | **2** | ❌ **NON** | geste ambigu | OUI : double demande explicitement refusée (`:126-127`), sans défaut. |
| **C36** | **`EffectiveSafeStop := SafeStop OR DirectionConflict OR (Req AND NOT Permit)`** → `RampTargetStep := 0` | `FB_Winch:169-171` → `:216-217` | `FB_Winch` | **2** — **c'est le terme qui MASQUE la famille 1** | ❌ **NON** | permis absent pendant une demande | ⚠️ **OUI, et c'est structurant** : un permis manquant est consommé **avant** la barrière (`RampTargetStep := 0`) ⇒ **aucun ordre n'est jamais émis** ⇒ `PermitFinalBlocked` (C26) devient **inatteignable** ⇒ les cas C12/C18/C22-C25 ne produisent **ni commande, ni défaut, ni raison**. C'est le mécanisme exact de « armé, rien ne bouge, rien d'affiché ». |
| **C37** | `NOT WinchRequest.RunRequest` (garde d'arbitrage) — **asymétrie M1/M2** | `FB_WinchCmdArbitrationM1:116-118` **porte** `AND NOT Context.BucketBusy` · `FB_WinchCmdArbitrationM2:143-144` **ne le porte pas** | `FB_WinchCmdArbitrationM1/M2` | **3d** — **asymétrie d'arbitrage** | ❌ **NON** | benne occupée (M1 seul bloqué) | **OUI** : M1 ne forme aucune commande pendant que la benne est *busy*, sans défaut. Déjà documenté par T351 §6.4-A2 / §10-4 et instruit par **T354** (`TROUBLESHOOTING_T354_ASYMETRIE_GARDE_M1_M2_20260921.md:36-37`, atteignabilité **prouvée** en MAINT_N1/N2 unitaire). |
| **C38** | `Enable := (StepNumber = 0) AND Sensors.ContactorsAllOff` → `EnableRising` → `DeadTimeArmed` | `FB_Winch:198-199` ; effet `FB_WinchDirectionInterlock:106-107` | `FB_Winch` | **2** | ❌ **NON** | transition d'arrêt de l'axe | OUI : déclencheur de C34 (désormais purgé). |
| **C39** | `NeutralHoldTimer.Q` (neutre tenu **100 ms** après grâce **3 s**) → `DeadmanArmed := FALSE` | `FB_Joystick:247-249` ; valeurs `ST_fbJoystick_Cfg.st:15` (`T#100MS`), `:17` (`T#3S`) | `FB_Joystick` | **3a** | ❌ **NON** — et **`ArmingPermit` n'est PAS touché** | **pause volontaire** (pur geste) | ⚠️ **OUI, mais inversé** : le geste se désarme **tout seul** sans que `ArmingPermit` bouge. La ré-armement exige un **nouveau front bouton** (`:225-227`) ⇒ si l'opérateur **garde le bouton pressé** et repousse le manche, **rien ne part** et le bandeau affiche `'[JOYSTICK] Appuyer homme-mort au neutre'` (`FB_Hmi_BannerFormatter:828-829` / **HEAD:791-792**) alors que le bouton **est** pressé. Message trompeur. |
| **C40** | `InversionLockActive` (`FlipX` OR `FlipY` sans permis) → désarmement | `FB_Joystick:216-220`, armement bloqué `:226` | `FB_Joystick` | **3a** | ❌ **NON** | inversion directe du geste | OUI : geste désarmé, `ArmingPermit` inchangé → aucune explication affichée. |
| **C41** | `DeadmanArmHoldTime` (**100 ms**) non écoulé | `FB_Joystick:230-234` ; valeur `ST_fbJoystick_Cfg.st:16` | `FB_Joystick` | **3a** | ❌ **NON** | appui bref | OUI : geste non armé, indistinguable d'un bouton mort. |
| **C42** | **`ArmingPermitDenied`** (appui refusé, warning non latché F08.08) | produit `FB_Joystick:244` · publié `PRG_02:495` · DUT `ST_AcquisitionJoystickQualified.st:16` | `FB_Joystick` | **3a** (diagnostic) | ❌ **NON** | appui sous `ArmingPermit = FALSE` | ⚠️ **AUCUN CONSOMMATEUR.** `PRG_07` miroite `DeadmanArmed` (`:620`, `:697`, `:756`, `:907`) et `AtNeutralXY` (`:621`, `:701`, `:757`, `:908`) mais **jamais** `ArmingPermitDenied` (grep exhaustif : 4 occurrences seulement, toutes producteur/DUT). Le seul avertissement « pourquoi je n'arme pas » **n'atteint jamais l'IHM**. Corrobore AF-08 `:316` (`TC-P08-060` = GAP déclaré). |
| **C43** | **`ErrorNoMovement` / `NoMovementFaultLatched` (bit15 `16#8000`)** ← **le défaut réel** | `FB_Safety_Winch:437-447` (`TonNoMovement`, `PT := NoMovementTimeout = T#3s` `:59`), agrégat SafeStop `:521`, miroir `:509` · projection `FB_WinchStateProjection:249`, `:277` · IHM `FB_Hmi_BannerFormatter:944-945` (HEAD:906-907), `:992-993` | `FB_Safety_Winch` | **3b** | **OUI au-delà de 3 s** (via `CauseNoMovementActive` → `CausesSafeStopActive:521` → `instSafetyWinchM1.SafeStop` → `SafeStopM1_Raw:1062` → `:1111-1114`) — **NON pendant les 3 premières secondes** (`NoMovementTimeout`) | défaut mouvement (latcheé, acquittée par `Reset`) | **OUI** : désarme M1 (et M2 si couplé, C07) alors que M3 est disponible. Acq. : `FaultMachineReset_IHM` `PRG_07:123-127` → `PRG_04` `Reset`. |
| **C43-bis** | **Inhibition du détecteur C43** : `NOT RefWindowActive AND NOT BenneBusy AND EncoderAvailable AND BrakeFeedback` dans la condition de `TonNoMovement` | `FB_Safety_Winch:437-443` (termes `NOT RefWindowActive`, `NOT BenneBusy`) ; `RefWindowActive` `:248-249` (`InReferencingMode OR BenneBusy OR PosStepDetected OR NOT TonRefSettle.Q OR NOT CrossCheckEnable`, settle `T#2s` `:247`) | `FB_Safety_Winch` | **3b** (aggravant) | ❌ **NON** — et **aucun autre défaut ne prend le relais** | homing / manipulation benne / saut de position / pilotage unitaire | ⚠️ **OUI — la fenêtre silencieuse devient NON BORNÉE.** Pendant `RefWindowActive` ou `BenneBusy`, le seul détecteur du symptôme est **inhibé** ⇒ « armé, rien ne bouge, **aucun défaut, indéfiniment** ». Documenté : `DOC/WFLOW/TROUBLESHOOTING/TROUBLESHOOTING_T338_PositionM2_Figee_2026-09-20.md:183`. **C'est le mode de la trace 67 (MAINT_N1) et du cas d'usage réel « changement de câble ».** À noter : `EncoderAvailable` et `BrakeFeedback` sont des **DI**. |
| **C44** | `ErrorOppositeDir` (bit14) | `FB_Safety_Winch:422-429`, `:521` | `FB_Safety_Winch` | **3b** | **OUI** — via `CausesSafeStopActive:521` | sens opposé à la commande | OUI (couplage C07 si both). |
| **C45** | `ErrorMecaB` / `ContactorStuck` — absence de confirmation d'arrêt contacteurs/frein | `FB_Safety_Winch:340-350`, `:484`, `:523-525` ; `PostRampTimeout = T#3s` `:49` | `FB_Safety_Winch` | **3b** | **OUI** — `CausesSafeStopActive:521` + `CausesPowerCutOffActive:523-525` | **PowerCutOff** (discordance contacteurs) | ⚠️ **OUI, global** : escalade en `PowerCutOff` ⇒ désarme **les 3 axes**. C'est le périmètre **T370**. |
| **C46** | `ErrorMecaE` + escalade (écart de synchronisation M1/M2) | `FB_Safety_Winch:394-409`, `:521`, `:525` ; `TonMecaE` `:403-407` | `FB_Safety_Winch` | **3b** | **OUI** | **PowerCutOff** (écart synchro) | ⚠️ OUI, global. |

### 2.2 Décompte (pour la restitution)

| Famille | Nombre | Détail |
|---|---|---|
| **1 — aval / T224** | **19** | C12-C19 (M2 benne : 6, M3 barrière : 2), C22-C29 (tempos & états barrière M1/M2 : 8), C30-C32 (barrière M3 : 3) |
| **2 — amont / D18** | **5** | C33, C34 (périmé/corrigé), C35, C36, C38 |
| **3 — autre (nommée)** | **23** | 3a geste joystick : C39-C42 (**4**) · 3b cause safety : C06-C09, C20, C43, **C43-bis**, C44-C46 (**10**) · 3c base / verrou métier : C01-C05, C10, C11, C21 (**8**) · 3d arbitrage : C37 (**1**) — *4+10+8+1 = 23 ✓* |
| **TOTAL** | **47** | |
| **NON PROUVÉ** | **1 élément** | État **réel** du DI `M1/M2_BrakeIsOpen_DI` (C28) et `M1/M2_ContactorsReleased_DI` (C29) sur la machine : aucune trace ne porte ces signaux (voir §6). La **condition** est prouvée par ligne ; seule sa **valeur en exploitation** ne l'est pas. |

---

## 3. 🔎 PRODUCTEUR DU DÉFAUT « commande sans mouvement » (§2.2 du brief)

**Verdict : le libellé « commande sans mouvement » N'EXISTE PAS comme identifiant de code.**
Il vient d'une note de fusion de tâche :

**Source directe (mail client GCAM, vérifiée)** — `DOC/WFLOW/REGISTRES/REGISTRE_MES_Rapport_Mail_GCAM_20260915.md:33` :

> *« Armement joystick : le permit d'armement est parfois incohérent avec les autorisations réelles de
> mouvement. L'utilisateur peut voir le joystick armé alors que le mouvement est interdit, ce qui
> génère ensuite des défauts « commande sans mouvement ». À corriger pour que l'état d'armement
> reflète réellement les permis de déplacement. »*

Ligne de suivi associée : `:59` — *« Joystick | Armement (`ArmingPermit`) cohérent avec permis |
Éviter le faux état armé qui génère "commande sans mouvement". | `T224` »*.
**Second relais** (note de fusion de tâche) : `DOC/WFLOW/TASKS.yaml:2983-2984` — *« …le joystick s'arme
alors que les moteurs/mouvement ne sont pas réellement prêts, ce qui pousse à piloter les contacteurs
dans un état incohérent et génère des défauts "commandes sans mouvement" »* (fusion du doublon T157).

### 3.1 Le défaut réel le plus proche — `ErrorNoMovement` (bit15)

| Élément | Preuve |
|---|---|
| **Variable** | `NoMovementFaultLatched` (interne) → `instCauses[15].Active` → `Fault.ErrorId` bit15 `16#8000` → `WinchM1Safety.ErrorNoMovement` |
| **Producteur (pose du défaut)** | `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:437-447` — `TonNoMovement(IN := NOT BypassProcess AND NOT RefWindowActive AND NOT BenneBusy AND EncoderAvailable AND MovementCommanded AND BrakeFeedback AND NOT InReferencingMode AND NOT PositionMovementDetected, PT := NoMovementTimeout)` ; `IF TonNoMovement.Q THEN NoMovementFaultLatched := TRUE;` |
| **Durée** | `NoMovementTimeout : TIME := T#3s` (`FB_Safety_Winch.st:59`) |
| **Détection du mouvement** | `PositionMovementDetected := MovementCommanded AND (ABS(CablePosM - NoMovementReferencePosM) >= CST_NoMovementPositionDeltaM)` (`:240-241`) avec `CST_NoMovementPositionDeltaM : REAL := 0.02` (`:174`) — **delta de position**, pas vitesse |
| **Texte source** | `instCauses[15].Texte := 'Absence mouvement malgre commande treuil'` (`:447`) |
| **Projection** | `FB_WinchStateProjection.st:249` / `:277` — `WinchM1/2Safety.ErrorNoMovement := (SafetyMx.Fault.ErrorId AND 16#8000) <> 0` |
| **Effet** | `CausesSafeStopActive` inclut `CauseNoMovementActive` (`FB_Safety_Winch.st:521`) ⇒ **`SafeStop`** ⇒ `EffectivePermitM*` FALSE ⇒ **`ArmingPermit` tombe ⇒ geste désarmé** |
| **Affichage IHM** | `FB_Hmi_BannerFormatter.st:944-945` (**HEAD:906-907**) : `'[M1] ErrorID:16 - discordance commande/retour/mouvement'` (idem M2 `:992-993` / **HEAD:954-955**) |
| **Acquittement** | Latch (`instCauses[15].Latching := TRUE` `:446`) ; effacé par `Reset` (`:195`, `:214`) ← `FaultMachineReset_IHM` (`PRG_07:123-127` : 5 boutons reset IHM) → entrée `Reset` de `FB_Safety_Winch` (`PRG_04`) |

### 3.2 Ce que ça change pour l'opérateur (traduction du symptôme)

| Symptôme dit | Variable réelle | Fenêtre |
|---|---|---|
| « j'ai armé et la commande part mais rien ne bouge, **sans alarme** » | **aucun défaut** — C22/C23/C26/C36 : `AuthorizedStep := 0` ou `RampTargetStep := 0` | **500 / 700 ms** (tempos barrière) — ou **permanent** (C12/C18/C26) |
| « j'ai armé, la commande part, rien ne bouge, **puis une alarme au bout de quelques secondes** » | `ErrorNoMovement` (bit15) | **3 s** (`NoMovementTimeout`) |
| « la commande d'arrêt ne remonte pas » | `ErrorMecaB` (bit8) — **T370** | **3 s** (`PostRampTimeout`) |
| « la benne / M2 part seule ou pas du tout » | `M2AscentPermitApplied` (C12) + asymétrie d'arbitrage (C37) | permanent |

⚠️ **Collision de libellés à signaler** : l'IHM affiche `ErrorNoMovement` (bit15) sous le mot
**« discordance commande/retour/mouvement »** (`FB_Hmi_BannerFormatter.st:945`) tandis que **T370** est
intitulée « discordance commande/**retour contacteurs** puissance » (`TASKS.yaml:33`). **Deux mécanismes
distincts partagent le mot « discordance commande/retour »** — risque réel de confusion en maintenance.

---

## 4. 🕳️ LES 3 TROUS G1 / G2 / G3

### 4.1 G1 — Tempos idle de la barrière finale : fenêtre RÉELLE et conflit de scan

**Conditions exactes, durées réelles (constantes et valeurs, prouvées à HEAD) :**

| Terme | Où | Valeur réelle | Ce qui bloque |
|---|---|---|---|
| `RestartRequired` | `FB_WinchOutputInterlock:71` (VAR_OUTPUT), armé `:170`, `:222`, purgé `:226-228` | `RestartDelay(PT := T#500ms)` (`:151`, `:224`) | `AuthorizedStep := 0`, `State := WAIT_RESTART_DELAY` (`:424-430`) |
| `DeadTimePending` | `:110` (loc.), armé `:246-248`, purgé `:252-254` / `:267-269` | `DeadTimeSameDir = T#500ms`, `DeadTimeOppositeDir = T#700ms` (`:35-36`) ; `PT := DeadTimeOppositeDir` (`:250`) | idem |
| `RestartInhibit` | `:70`, posé `:504` | latch — exige `ResetEdge` (`:510-514`) | `State := FAULT`, `Reason := RESTART_INHIBITED` (`:357-363`) |
| `ContactorStuckLatched` | `:115`, posé `:317` | `SenseHoldTimer PT := MaxSenseHoldTime = T#400ms` (`:43`) | `State := FAULT`, `Reason := SENSE_DROP_TIMEOUT` (`:364-373`) |
| `CST_StepRampFloorDelay` | `:136` | `T#400ms` | plancher de cadence de montée de palier (ne bloque pas, bride) |

**Fenêtre RÉELLE d'armement trompeur : `max(500 ms, 500 ms) = 500 ms` en reprise même sens, et
`max(500 ms, 700 ms) = 700 ms` en inversion de sens — MESURÉE dans le code, pas déduite.**
`DeadTimeSameDir`/`DeadTimeOppositeDir` **ne sont pas surchargés** à l'appel : la liste complète des
arguments passés est en `PRG_06:149-165` (M1) et `:215-231` (M2) — aucun des trois paramètres de tempo
n'y figure ⇒ **valeurs par défaut du FB**.

> ❌ **CONTREDIT LA DOCUMENTATION — 3 fois.** Le contrat T224 (`l.76`) écrit *« RestartInhibit
> transitoire **1,5 s** »*, le contrat T228 (`l.87`) *« anti-court-cycle **RestartDelay 1,5 s** »*, et
> **`DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md:384`** *« anti-court-cycle `RestartRequired`/
> `RestartDelay` **~1,5 s** après chaque arrêt »*. Le code dit **500 ms**. Le cadrage T325
> (`CADRAGE_T325_D18_INTERLOCK_DIRECTION_v1.0.md:22-24`) avait déjà relevé que l'AF-10 v2.1 annonce
> `RestartDelay=1500ms` quand le code porte `500ms` : **la valeur fausse a essaimé dans les
> contrats et dans l'AF-08**. À corriger AVANT tout chiffrage de lot (le facteur d'erreur est ×3).

**Conflit de scan — PROUVÉ (avec sa limite) :**

| Preuve | Contenu |
|---|---|
| `DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md:521-527` | Ordre d'appel **MainTask 10 ms** : `03. PRG_04_Treuils_Benne` → `04. PRG_05_Translation` → `05. PRG_06_Outputs` (`:526`) → `06. PRG_07_Supervision`. **PRG_06 s'exécute APRÈS PRG_04.** |
| `AF_Partie-02:575` | Doctrine : *« Aucun programme ne doit lire une donnée produite par un programme exécuté plus tard dans le même cycle, sauf retard d'un scan documenté »*. |
| `AF_Partie-02:384`, `:390-391` | `N-1` = 1 cycle MainTask = **10 ms** typiques. `PRG_05 ↔ PRG_06` déjà en N-1 documenté. |
| `CODE_XML/CODE_Bundle.xml:57908` | Commentaire de code : *« PRG_02_Acquisition s'exécute avant ce POU dans la MainTask (rang 01 < 05) »* |
| `PRG_04:1168-1173` | `ArmingPermit` lit déjà `PRG_05_Translation.Data…` ⇒ **N-1 de fait**, accepté par la doctrine. |
| `PRG_06:52-54` + `:149` | C'est **PRG_06** qui détient `instWinchOutputInterlockM1/M2` et `instTranslationOutputInterlockM3`. |

⚠️ **LIMITE HONNÊTE** : l'ordre est prouvé par la **documentation d'architecture** + les commentaires
du code, **pas par un artefact mécanique**. `AF_Partie-02:610` l'admet lui-même
(`TC-P02-004`, *« aucun gate n'existe pour vérifier l'ordre inter-programmes »*), et `:532` précise que
*« la tâche CODESYS en ligne reste à confirmer »*. Le bundle PLCopenXML ne contient **pas** la
configuration de tâche (`CODE_XML/CODE_Bundle.xml` : 4 occurrences de `MainTask`, toutes en
commentaire/description, aucune table de tâches). `Device.export` **n'a pas été lu** (interdit par
`AGENTS.md` : toujours périmé, export frais à demander à l'humain).

**Conséquence pour G1** : toute disponibilité sourcée depuis la barrière finale serait lue au
**scan N-1 (10 ms)**. C'est le conflit de scan **prouvé** que le contrat T224 flaguait (`l.69-79`).

### 4.2 G2 — `Data.ArmingAvailability` : produit, jamais consommé

**Preuve d'absence de consommateur (grep exhaustif `ArmingAvailability` sur `CODE/`) :**

| Fichier:ligne | Nature |
|---|---|
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1192, 1194, 1196, 1198, 1200, 1202` | **écriture** `BlockedReason` |
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1208-1214` | **écriture** des 7 champs de disponibilité |
| `CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_ArmingAvailability.st:2, 11` | déclaration du type |
| `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_WinchInterPrg.st:80` | déclaration du champ inter-PRG |

⇒ **16 occurrences, toutes en écriture ou en déclaration. ZÉRO lecture.** Le champ est même **publié
sur le bus inter-programmes** (`ST_WinchInterPrg.st:80`) et le commentaire `:77-79` annonce des
lecteurs qui **n'existent pas** : *« Lecteurs : PRG_02 (ArmingPermit), FB_TroubleshootingView / IHM »* —
`PRG_02` ne lit que `Data.ArmingPermit` (`PRG_02:464`), pas la disponibilité.

**Ce qui manque exactement pour que l'opérateur voie axe / sens / motif :**

| Maillon | État réel | Preuve |
|---|---|---|
| Miroir du booléen | **présent** | `PRG_07_Supervision.st:804` — `GVL_IHM.Permits.ArmingPermit := PRG_04_Treuils_Benne.Data.ArmingPermit;` |
| Champ de disponibilité par axe×sens dans le DUT IHM | **ABSENT** | `ST_PermitVisibilityHMI.st` (39 l., 33 champs) : `ArmingPermit : BOOL` `:4`, permis directionnels `:5-33`, `M1/M2FinalPermitBlocked` `:13`/`:22` — **aucun** `ArmM*Avail` |
| Champ de motif dans le DUT IHM | **ABSENT** | idem : aucun champ de type `E_ArmingBlockReason` dans `ST_PermitVisibilityHMI.st:1-39` |
| Producteur IHM unique | `PRG_07_Supervision` (déclaré `ST_PermitVisibilityHMI.st:1` : *« Tableau public, lecture seule, des permis canoniques. Producteur : PRG_07 »*) ; assignations `PRG_07:804-831` | |
| Vue troubleshooting | `GVL_Troubleshooting` alimenté par `FB_TroubleshootingView.st` (ex. `:205`, `:284`) — **aucun** champ d'armement | grep `ArmingAvailability` = 0 dans `FB_TroubleshootingView.st` |
| Bandeau | `FB_Hmi_BannerFormatter` — branche `ELSIF NOT DeadmanArmed` → `'[JOYSTICK] Appuyer homme-mort au neutre'` (`:828-829` / **HEAD:791-792**). **Aucune** lecture de `ArmingPermit`, `BlockedReason` ou `ArmingPermitDenied` | grep `ArmingPermit` dans ce fichier = **0 occurrence** |
| Warning de refus d'appui | **produit, publié, jamais lu** | `FB_Joystick:244` → `PRG_02:495` → `ST_AcquisitionJoystickQualified.st:16` ; **0 lecture** (cf. C42) |

**Producteur unique attendu** : **`PRG_07_Supervision`** (il est déjà le producteur canonique de
`GVL_IHM.Permits`, doctrine `AF_Partie-02:452`/`:462`, et alimente déjà `GVL_Troubleshooting` via
`FB_TroubleshootingView`). **Fichiers à toucher — sans les modifier ici** :
`CODE/J_SUPERVISION/_TYPES/8_BANDEAU_ET_IHM/ST_PermitVisibilityHMI.st` (DUT) et/ou
`CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_MotionChecklist.st`,
`CODE/M_MAIN/PRG_07_Supervision.st` (miroir), `CODE/J_SUPERVISION/FB_TroubleshootingView.st` (vue),
et pour le motif côté bandeau `CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st` + son câblage
`PRG_07`. `PRG_02`/`PRG_04` **ne devraient pas** changer : `Data.ArmingAvailability` est déjà publié.
**Exception** : `PermitFinalBlocked` est une `VAR` **privée** (`FB_WinchOutputInterlock:87`) — la rendre
visible exige un **changement d'interface** de la barrière. C'est le seul point qui touche un fichier de
barrière, et il resterait **read-only** (publication), jamais un patch de logique de sécurité.

> 🔎 **G2 bis — affiné après vérification : un outil d'explication EXISTE, et il affiche un FAUX VERT
> exactement dans les cas de G1.**
>
> **Ce qui existe déjà** : `ST_MotionChecklist.st` (35 l.) — *« Permet de voir en un coup d'œil pourquoi
> un ordre de mouvement ne fait pas coller les relais »* (`:4`), rempli en `FB_TroubleshootingView.st:564-586`
> (M1), `:596-618` (M2), `:628-653` (M3), publié dans `GVL_Troubleshooting.N_MotionM1/O_MotionM2/P_MotionM3`.
> Autres signaux de disponibilité **déjà publiés** : `Idx401_MotionAllowed := WinchMx.State.Ready`
> (`FB_TroubleshootingView.st:218`, `:297`, `:414`), `Idx406_FinalInterlockReason` (`:223`, `:302`),
> `Idx405_FinalInterlockReason` (`:418`), `Idx208_MotionBlockedByBucket` (`:353` ← **le blocage benne
> COUPLÉ**, `ST_ChainBucket.st:32` — il ne couvre donc **pas** le terme `M2AscentPermitApplied` de C12).
>
> **Le trou, prouvé par les lignes d'assignation** : `Reason` n'est assigné qu'à **4 endroits** dans
> `FB_WinchOutputInterlock.st` — `:210` (`NONE`), `:362` (`RESTART_INHIBITED`), `:372`
> (`SENSE_DROP_TIMEOUT`), `:508` (`BRAKE_COMMAND_NOT_CONFIRMED`). **La branche `PermitFinalBlocked`
> (`:393-404`) et la branche `WAIT_RESTART_DELAY` (`:424-430`) ne posent AUCUN `Reason` et AUCUN
> `Fault.Error`** — elles ne posent que `State`. Or `Step8_OutputInterlockOk := NOT FinalInterlockError`
> (`FB_TroubleshootingView.st:577`, `:609`, `:644`, avec `FinalInterlockError := InterlockMx.Fault.Error`,
> `FB_WinchStateProjection.st:114`) et `Idx401_MotionAllowed` lit le `Ready` du **process** (`FB_Winch:164`).
> **Conséquence** : pendant C22/C23 (`WAIT_RESTART_DELAY`) **et** pendant C12/C18/C26 (`PermitFinalBlocked`),
> la checklist affiche ses 8 étapes **vertes** et conclut — littéralement —
> *« 🟢 TRUE = TOUTES LES CONDITIONS SONT REMPLIES, LES RELAIS DOIVENT COLLER ! »* (`ST_MotionChecklist.st:30`),
> alors qu'**aucun relais ne colle**. Le technicien est envoyé sur une fausse piste **par l'outil même
> destiné à le guider** : c'est pire qu'une absence de diagnostic.
>
> **Nuance honnête (correction d'une première lecture)** : le diagnostic des barrières **n'est pas
> entièrement mort** — `Reason` **et** `Fault.Error` **sont** publiés (`FB_WinchStateProjection.st:113-115`,
> `:180-182` ; `PRG_05:756-758`), et `Fault.ErrorId` M3 remonte même au bandeau
> (`FB_Hmi_BannerFormatter.st:63`, `:1038`). Ce qui manque n'est donc **pas un câblage** mais **une
> information qui n'existe pas** : les deux branches muettes ci-dessus ne renseignent ni `Reason` ni
> `Fault`. Contre-exemple de patron réutilisable : `Data.M1AscentStartReady` (`PRG_06:178-181`) **est**
> consommé, mais une seule fois et par le cycle (`PRG_03:267`), **jamais par l'armement** ; M2 n'a pas
> d'équivalent (grep `M2AscentStartReady` = **0 occurrence**).

### 4.3 G3 — Mécanisme exact de la régression banc (revert `263fae18`)

**Message de commit vérifié** (`git log -1 --format='%h %ad %s' --date=short 263fae18` → `263fae18 2026-09-02`),
texte intégral du corps relu via `git show 263fae18` :

> *« Regression : impossible de monter, ArmingPermit quasi toujours a 1 (inutile), et des blocages banc
> lies au chemin rapide NoMovement (M1_ContactorsReleased_DI fige TRUE sans DI reel). 3 rounds de
> correctifs sur des FB SECURITE -> retour a la baseline stable pre-T228 (7e46d6d7), demande operateur. »*

`git show --stat 263fae18` → 26 fichiers, **36 insertions / 1245 suppressions**, dont **12 fichiers
`CODE/`** restaurés (`FB_Safety_Winch.st`, `FB_WinchOutputInterlock.st`, `FB_WinchStateProjection.st`,
`FB_TranslationOutputInterlock.st`, `FB_Hmi_BannerFormatter.st`, `ST_ChainWinchSync.st`,
`ST_OutputsInterPrg.st`, `ST_SafetyWinch.st`, `E_ArmingBlockReason.st`, `PRG_04`, `PRG_06`, `PRG_07`).

> 🚨 **FAIT DÉTERMINANT — la fenêtre annulée contient 11 commits, dont 4 HORS T228.**
> `git log --oneline 7e46d6d7..263fae18` (baseline `7e46d6d7` = *« backup code »* 17:35, ancêtre de
> HEAD confirmé) :
> `c9665355` · `44187804` · `b96a8988` · `e2f5b9dc` = **4 commits T228** ;
> `b9e9402a` = **T225** (remontée décodée discordance contacteurs) ;
> `67972e1d` · `72ce5eec` = **2 commits T228** (total **6**, conforme au contrat) ;
> `18edd8a5` = **chemin rapide `TonNoMoveContactor`** (`feat(safety): contacteur de sens commande mais
> retour "tous retombes" -> NoMovement rapide [NON TESTE]`) ;
> `2a1b3c58` = décodeur de bandeau « contacteur de sens non engagé » ;
> `5a531d38` = gate `ContactorFeedbackTrusted`.
> **Le chemin rapide NoMovement N'EST PAS un commit T228** — c'est un lot safety **intercalé**.
> Vérifié : `git show --stat 18edd8a5` ne touche que `FB_Safety_Winch.st` (+2 XML), et **aucun commit
> T228 ne touche `FB_Safety_Winch.st`**. Le revert a donc emporté **deux lots** indistinctement, en plus
> de T225 — ce qui rendait tout retour arrière chirurgical impossible.
> Confirmation de restauration : `git diff --name-only 7e46d6d7 263fae18 -- CODE/` ne renvoie **qu'un
> seul fichier** (`CODE/B_AU_SECURITE/FB_Safety_EmergencyManagement.st`, lot AU concurrent conservé
> volontairement) ⇒ les 12 fichiers annoncés sont bien restaurés à l'identique.

#### (a) « ArmingPermit quasi toujours à 1 (inutile) » → **PARTIELLE / mal attribuée**

Le calcul annulé (`git show 72ce5eec:CODE/M_MAIN/PRG_04_Treuils_Benne.st`), lignes **988-990** :

```st
ArmingPermit := NOT ArmModeDisabled AND NOT ArmContactorOff AND NOT ArmPowerCutOff
             AND NOT ArmBucketBusy AND ArmAnyAxisAvail
             AND NOT ArmMovementInhibitedAny;
```

Le terme **ajouté par T228** est `AND NOT ArmMovementInhibitedAny` (`:961-963`, `:990`). Un terme en
`AND NOT` **ne peut que restreindre** l'agrégat : il n'a **pas pu créer** « quasi toujours à 1 ».

La cause de l'informativité est **structurelle et antérieure** : `ArmAnyAxisAvail` est un **OR sur
6 axes×sens** (`:954-956` @72ce5eec ; `PRG_04:1175-1177` @HEAD). À l'arrêt, au moins un axe×sens est
disponible → `ArmingPermit = TRUE`. **Verdict : l'observation de l'opérateur est exacte, son
attribution à T228 est fausse.** Elle **reste une exigence de conception** (brief v2 A7) : c'est
précisément le trou **G2** qui rend le booléen inutile (l'opérateur ne voit ni axe, ni sens, ni motif).

#### (b) « chemin rapide NoMovement » → **VRAIE et prouvée** — ⚠️ mais **hors T228** (attribution corrigée)

**CORRECTION D'UNE PREMIÈRE LECTURE** : `git diff 7e46d6d7 72ce5eec -- CODE/H_TREUILS_BENNE/FB_Safety_Winch.st`
montre bien le chemin rapide comme **le seul ajout de fond dans ce fichier sur cet intervalle** — mais il
a été introduit par **`18edd8a5`**, commit safety **intercalé** (*« feat(safety): contacteur de sens
commande mais retour "tous retombes" -> NoMovement rapide [NON TESTE] »*, `git show --stat 18edd8a5` =
`FB_Safety_Winch.st` + 2 XML). **Aucun commit T228 ne touche `FB_Safety_Winch.st`.** Le présenter comme
un ajout de T228 était **faux** : c'est un **second lot** emporté par le même revert.
Extrait du code annulé (`git show 72ce5eec:…FB_Safety_Winch.st`, lignes **404-412**) :

```st
TonNoMoveContactor(
    IN := NOT BypassProcess AND MovementCommanded AND NOT InReferencingMode
          AND FwdRevSpeedFeedbackOff,
    PT := CST_ContactorConfirmDelay
);
IF TonNoMoveContactor.Q THEN
    NoMovementFaultLatched := TRUE;
    NoMovementContactorSuspectLatched := TRUE;
END_IF;
```

avec `CST_ContactorConfirmDelay : TIME := T#500ms` (ajouté au même commit). La sortie
`NoMovementContactorSuspect` est déclarée `FB_Safety_Winch.st:100` @72ce5eec.

**Mécanisme, maillon par maillon :**
1. `TonNoMoveContactor.IN` = `MovementCommanded AND FwdRevSpeedFeedbackOff` (avec `NOT InReferencingMode`, `NOT BypassProcess`).
2. `FwdRevSpeedFeedbackOff` est câblé au **DI** `M1_ContactorsReleased_DI` / `M2_ContactorsReleased_DI` — prouvé @72ce5eec `PRG_04:756`, `:818`, `:1254`, `:1271` (et @HEAD `:1602`, `:1619`).
3. Sur banc, ce DI est **forcé TRUE manuellement** : `REGISTRE_Suivi_MiseEnService_20260902.md:125`
   (*« Banc (EtherCAT + modules DI absents) »*) et **`:130`** (*« Force `M1_ContactorsReleased_DI` +
   `M2_ContactorsReleased_DI := TRUE` → lève MecaB (`FwdRevSpeedFeedbackOff`), `Step4` homing,
   `ModeChangeAllowed` »*).
4. Donc dès qu'une commande de sens existe : `IN` = TRUE pendant 500 ms → `NoMovementFaultLatched := TRUE`.
5. `instCauses[15]` est **latcheé** (`Latching := TRUE`, `:415` @72ce5eec) et alimente
   `CausesSafeStopActive` (`FB_Safety_Winch.st:521` @HEAD) → **`SafeStop`**.
6. `SafeStop` → `SafeStopM1_Raw` (`PRG_04:1062`) → `EffectivePermitM1_*` FALSE (`:1111`, `:1113`) →
   `ArmM1AscentAvail` FALSE (`:1164`) → **`ArmingPermit` FALSE / permis refusés ⇒ « impossible de monter ».**

**Verdict (b) : VRAIE.** Le chemin rapide était **logiquement faux sur banc** : il interprétait un DI
**forcé** comme une mesure fiable (« contacteur retombé »), alors que ce forçage est un
**contournement de mise en service**. ⚠️ **Nuance** : à la révision **finale** de la fenêtre, ce chemin
était de fait **neutralisé** par le gate `ContactorFeedbackTrusted` (défaut **FALSE**, introduit par
`5a531d38`) — mais ce gate **n'est pas câblé** dans les appels `instSafetyWinchM1/M2` et ce build est
resté `[NON TESTE]`. La correction a donc été annulée **sans avoir été testée**.

#### (b-bis) **CAUSE B — « impossible de monter » par T228 lui-même** (2ᵉ mécanisme, distinct)

Un second mécanisme, **celui-ci bien issu de T228**, a produit le même symptôme entre `e2f5b9dc`
(18:13) et `72ce5eec` (18:50) :

1. `e2f5b9dc` remet dans l'agrégat les termes `OR RestartRequired OR DeadTimePending`.
2. Or `RestartRequired` est **ré-armé à CHAQUE scan au repos** (`FB_WinchOutputInterlock:221-223`,
   `IF NOT MotorRequest THEN RestartRequired := TRUE;`) — au **HEAD actuel** comme à la révision annulée.
   Sa purge dépend de `RestartDelay`, dont le `PT` avait été porté à **`T#1500ms` par T228**
   (vérifié : `git show 72ce5eec:…FB_WinchOutputInterlock.st:227` → `PT := T#1500ms`, contre
   **`T#500ms` à HEAD** `:224` ; la branche de gate porte même `T#1000ms` `:153` @72ce5eec).
3. Agrégat (`72ce5eec:…FB_WinchOutputInterlock.st`, l'ayant été à cette étape) : `MovementInhibited`
   incluant `RestartRequired` → `PRG_06:408-410` publie `Data.M1/M2/M3MovementInhibited` →
   `PRG_04:961-963` `ArmMovementInhibitedAny` → `:988-990` **`ArmingPermit` = FALSE à l'arrêt,
   tout vert** (état constaté par l'auteur sur snapshot 184754, cité dans le message de `72ce5eec`).
4. `72ce5eec` « corrige » en ne gardant que `State = WAIT_RESTART_DELAY` — vérifié, forme **finale**
   (`:564-568` @72ce5eec) : `MovementInhibited := NOT Ready OR RestartInhibit OR ContactorStuck
   OR (State = WAIT_RESTART_DELAY) OR (State = FAULT)`. Au repos `State = READY` ⇒ le terme redevient
   **inactif** ⇒ **c'est ce qui a produit le grief (a)** : le permit ne tombe plus jamais, y compris
   dans la fenêtre qu'il devait couvrir.

➡️ **Les deux causes sont indépendantes** et produisent le **même** symptôme opérateur. Le message de
revert les fond en une seule phrase, ce qui est **trompeur pour une reprise** : corriger le DI ne
suffirait pas, et corriger l'agrégat ne suffirait pas.

> 🔬 **Découverte datée : le « ~1,5 s » des contrats vient de la révision annulée.** T228 avait porté
> `RestartDelay` de **500 ms à 1500 ms** (`72ce5eec:227`). Le revert a restauré **500 ms** (`HEAD:224`).
> Les documents qui annoncent « ~1,5 s » (contrat T224 `l.76`, contrat T228 `l.87`, `AF-08:384`)
> décrivent donc **l'état T228, aujourd'hui annulé** — ce n'est pas une coquille mais un **reliquat du
> lot reverté** (voir AL-01/AL-02, fusionnées).

#### (c) « `M1_ContactorsReleased_DI` figé TRUE sans DI réel » → **VRAIE, avec la preuve terrain manquante au message de commit**

`REGISTRE_Suivi_MiseEnService_20260902.md:125` + `:130` **documentent le forçage** — le message de
commit ne le mentionne pas et laisse croire à un DI « figé » spontané. C'est un **forçage opérateur
assumé**, pas un défaut de câblage : la distinction est essentielle pour une reprise.

#### Verdict global sur l'explication du message de commit

| Affirmation | Verdict | Preuve |
|---|---|---|
| (a) `ArmingPermit` quasi toujours à 1 (inutile) | ⚠️ **PARTIELLE — attribuée à tort à T228** | `72ce5eec:PRG_04:988-990` (terme `AND NOT`) vs `:954-956` (OR structurel) ; auto-diagnostic de l'auteur dans `b96a8988` : *« RESTE (F1) : ArmingPermit est un OR global des 6 axes -> ne tombe que si TOUS en tempo »* |
| (b) blocages banc liés au chemin rapide NoMovement | ✅ **VRAIE — mais le chemin rapide n'est PAS un commit T228** | `72ce5eec:FB_Safety_Winch.st:404-412` + `CST_ContactorConfirmDelay T#500ms` ; **auteur = `18edd8a5`** (`git show --stat` : `FB_Safety_Winch.st` seul) |
| (b-bis) **cause non citée** : « impossible de monter » par l'agrégat T228 lui-même | ➕ **OMISE par le message** | `e2f5b9dc` (termes `RestartRequired`/`DeadTimePending`) + `RestartRequired` ré-armé au repos `:221-223` + `RestartDelay PT := T#1500ms` `72ce5eec:227` |
| (c) `M1_ContactorsReleased_DI` figé TRUE sans DI réel | ✅ **VRAIE**, cause = **forçage MES** non citée | `REGISTRE_Suivi_MiseEnService_20260902.md:125`, `:130` |
| « 3 rounds de correctifs sur des FB SÉCURITÉ » | ⚠️ **Approximatif** | On en compte **4 à 5** (`b96a8988`, `e2f5b9dc`, `67972e1d`, `72ce5eec`, `5a531d38`), et **2 des mécanismes incriminés ne sont pas T228** |
| « retour à la baseline `7e46d6d7` » | ✅ Exact | `git merge-base --is-ancestor 7e46d6d7 263fae18` → 0 ; `git diff --name-only 7e46d6d7 263fae18 -- CODE/` = 1 seul fichier (lot AU) |
| Fenêtre réellement annulée = **6 commits T228** | ❌ **Sous-estimée : 11 commits** | `git log --oneline 7e46d6d7..263fae18` → 6 T228 + `b9e9402a` (T225) + `18edd8a5` + `2a1b3c58` + `5a531d38` (hors T228) |

➡️ **La cause racine de la régression banc est le point (c) combiné à (b)** : **une logique de
disponibilité fondée sur un DI de mise en service forcé**. Toute reprise doit donc interdire
structurellement (et pas seulement par convention) qu'un signal de disponibilité dépende d'un DI
bypassé — c'est la leçon A2 du brief v2, ici **démontrée sur pièces**. **S'y ajoute la cause (b-bis)** :
un agrégat de disponibilité keyé sur un terme **ré-armé à chaque scan au repos** (`RestartRequired`
`:221-223`) **fige** le voyant — un second piège, indépendant du DI.

**Fausses pistes écartées / corrigées (pour ne pas les reprendre) :**
- ❌ **Le contrat T228 `l.89` (« bypass MES groupe du treuil levant le terme `MovementInhibited`) est PÉRIMÉ — FAIT ÉTABLI, plus une hypothèse** (statut relevé après vérification des révisions) :
  le gate `ArmMxMoveInhibited := PRG_06_Outputs.Data.MxMovementInhibited AND NOT GVL_IHM.MxTreuil*.Bypass.Global`
  **existait dans `44187804`** (`git show 44187804:CODE/M_MAIN/PRG_04_Treuils_Benne.st` → `ArmM1MoveInhibited`,
  `ArmM2MoveInhibited`, `ArmM3MoveInhibited` avec `AND NOT GVL_IHM.…Bypass.Global`) et a été **retiré par
  `b96a8988`** (`git show b96a8988:…PRG_04_Treuils_Benne.st` → **0 occurrence** de ces 3 lignes).
  Le contrat — relu à la révision finale — porte donc une décision de conception **abandonnée**.
  De plus le `design_decisions` `l.87` décrit la version `e2f5b9dc`, elle aussi abandonnée avant la fin
  du lot : **le contrat décrit un état intermédiaire, pas l'état livré.**
  ⚠️ **Piège à retenir** : le bypass `BypassProcess` (`FB_Safety_Winch:405` `IN := NOT BypassProcess AND …`)
  empêche le latch de **se poser** mais **ne l'efface pas** — seuls `Reset` (`:183`) ou `BypassGlobal`
  (`:181`) le font. Un « bypass » supposé neutre peut donc laisser un défaut **latcheé actif**.
- ✅ Le « Défaut 2 » T325/D18 (C34) est **déjà corrigé** à HEAD (`657be973`) : **ne pas le remettre au scope.**

---

## 5. 🧭 ÉTATS `pause volontaire` / `SafeStop` / `PowerCutOff` — DISTINCTS ?

**Verdict : DISTINCTS dans le code (prouvé 3 fois), INDISTINGUABLES à l'IHM (constat).**

| Critère discriminant | **Pause volontaire** | **`SafeStop`** | **`PowerCutOff`** |
|---|---|---|---|
| `ArmingPermit` | **INCHANGÉ** (reste TRUE) | **FALSE** (`PRG_04:1205`) | **FALSE** (`PRG_04:1205`) |
| `BlockedReason` | `NONE` (`PRG_04:1202`) | **PAS de valeur dédiée** — retombe sur `ALL_AXES_BLOCKED` (`:1199-1200`) si tous les axes tombent | `POWER_CUTOFF` (`:1195-1196`) |
| Mécanisme du désarmement | **local au geste** : `NeutralHoldTimer.Q` (neutre 100 ms après grâce 3 s) → `DeadmanArmed := FALSE` (`FB_Joystick:247-249`) | **externe** : `IF NOT ArmingPermit THEN DeadmanArmed := FALSE` (`FB_Joystick:238-240`) | **externe**, même ligne `FB_Joystick:238-240` |
| Barrière finale M1/M2 | tempos `RestartRequired`/`DeadTimePending` (500/700 ms), **purgeables** | coupure dure `SafeStop OR PermitFinalBlocked` (`FB_WinchOutputInterlock:393-404`) — **ni défaut, ni latch, ni Reset** (commentaire `:394-396`) | `Enable := FALSE` (`PRG_06:128-129`) → branche `:148-175` → **`RestartRequired := TRUE` (`:170`)** + `RETURN` |
| Reprise | ré-appui bouton (nouveau front, `FB_Joystick:225-227`) | idem | idem **+ purge obligatoire** (`RestartRequired`) |
| Défaut latché ? | non | non | **oui** si cause `CausesPowerCutOffActive` (`FB_Safety_Winch:523-525`) |

**Preuves les plus compactes pour l'AC5/A5 :**
- `pause volontaire ≠ SafeStop` : `FB_Joystick:247-249` (désarmement **sans** toucher `ArmingPermit`)
  **vs** `FB_Joystick:238-240` (désarmement **par** `ArmingPermit`).
- `SafeStop ≠ PowerCutOff` : `FB_WinchOutputInterlock:394-396` (« SafeStop n'est PAS un défaut : pas de
  FAULT, pas de latch, pas de Reset ») **vs** `PRG_06:128-129` + `:170` (`PowerCutOff` ⇒ `Enable=FALSE`
  ⇒ `RestartRequired := TRUE`).
- `SafeStop ≠ pause` côté barrière : `:393-404` (coupure immédiate) **vs** `:424-430` (attente de tempo).

⚠️ **Confusion trouvée (à signaler, non corrigée)** : **`SafeStop` n'a pas de motif propre dans
`E_ArmingBlockReason`** (`E_ArmingBlockReason.st:10-15` : `NONE`, `MODE_DISABLE`, `POWER_CUTOFF`,
`CONTACTOR_OFF`, `BUCKET_BUSY`, `ALL_AXES_BLOCKED`). Un `SafeStop` global et un « aucun axe
disponible » produisent **le même motif** `ALL_AXES_BLOCKED`. **Les trois états sont distincts dans le
code mais l'IHM ne peut en afficher que deux** (`POWER_CUTOFF` et `ALL_AXES_BLOCKED`), et **aucun des
deux n'est affiché** (G2). L'exigence A5 du brief v2 est donc **satisfaite dans le code, non satisfaite
dans la boucle opérateur**.

---

## 6. 📊 TRACES TERRAIN ET FICHES EXISTANTES

### 6.1 🚨 PREUVE MANQUANTE — la trace invoquée par le contrat T228 N'EXISTE PAS

`DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T228_ARMINGPERMIT_TEMPOS_INTERLOCK.yaml:87` fonde une décision de
conception sur une trace nommée **« Suivi_JOY_permit_bug_13 »** :

> *« Corrige apres trace Suivi_JOY_permit_bug_13 : la version initiale (DeadTime.IN AND NOT DeadTime.Q)
> ratait RestartRequired … »*

**Verdict : ABSENTE sous ce nom.** Recherche par nom de fichier **et** par contenu sur tout le dépôt :
aucune trace de ce nom. **Nuance importante (vérifiée)** : une trace **du lot T228 existe bien**, mais
sous un nom **horodaté** et rangé dans les archives —
`TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/archives/Suivi_JOY_permit_bug_20260902_13.trace`, **ajoutée par
le commit `44187804`**. Elle ne suit que `instJoystick.ArmingPermit`, `ArmingPermitDenied` et des canaux
`M1_*` (séries non dépouillées, cf. §9 point 12).
➡️ **La preuve existe donc matériellement, mais elle est introuvable par la référence citée** : le
contrat T228 `l.87` la nomme « `Suivi_JOY_permit_bug_13` », nom qui ne correspond à **aucun** fichier.
C'est un **défaut de traçabilité** (référence non résoluble), pas une absence de données — et cette
distinction change la réponse à l'Étape B : l'argument peut être **re-fondé** en dépouillant cette
trace, au lieu d'être abandonné.

### 6.2 🥇 PREUVE TERRAIN LA PLUS DIRECTE — elle existait DÉJÀ, dans une fiche de 2026-09-20

`DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_MAINT_COUPLE_INTERLOCK_TRACE64_20260920.md`
(trace 64 = `Suivi_64_SIMU_Interlock_20260919_wide.csv`, 1 511 lignes, 288 Ko) — **c'est le document qui
décrit le mieux le symptôme T224, et il a été écrit avant le brief** :

| Ligne | Contenu (verbatim) |
|---|---|
| `:23` | *« 116–119 s — Demande descente, `DeadmanArmed=1`, **`ArmingPermit=1`**, **aucun relais, aucun ErrorId tracé**. »* (colonne « Force » : **Forte**) |
| `:26` | *« 133–147 s — Plusieurs demandes de descente restent sans relais malgré `DeadmanArmed=1`, **`ArmingPermit=1`**, ErrorId=0. »* ⇒ **répétition, ce n'est pas un transitoire** |
| `:32` | Arbre des causes — *« Joystick / homme-mort → **Éliminée** pour les blocages longs »* |
| `:33` | Arbre des causes — *« **Armement global → Éliminée** — `PRG_04.Data.ArmingPermit=1` »* |
| `:42` | *« La trace révèle en plus un **blocage logique durable sur certaines demandes de descente** ; il se situe **avant les sorties** et ne peut pas être attribué à D18 seul. »* |

➡️ **Ce que ça prouve, et pourquoi c'est la pièce maîtresse** : un cas **réel et tracé** où l'homme-mort
est armé, `ArmingPermit = 1`, la demande de mouvement existe, **aucun relais ne colle et aucun ErrorId
n'est levé**, pendant **plusieurs secondes et à plusieurs reprises**. La fiche **élimine explicitement**
l'armement global et le joystick comme causes, et **localise le blocage « avant les sorties »** — c'est
la définition même de la fenêtre silencieuse de **G1 / famille 1** (C22, C23, C26). Elle **écarte aussi
D18 seul** comme explication (`:35`, `:42`), ce qui **confirme mon décompte** : la famille 2 est un
contributeur **minoritaire**.

⚠️ **Limite déclarée par la fiche elle-même** (`:37`, `:54-57`) : les *« bits internes »* manquent dans
sa propre trace — les 4 variables qu'elle réclame (`EffectivePermitM1/M2_Descend`,
`instWinchM1/M2.DirectionChangePending`) **ne sont pas dans `Suivi_64…wide.csv`**. Le symptôme est donc
**prouvé**, la **cause exacte ne l'est pas** : c'est **le même trou d'instrumentation** que partout
ailleurs dans ce dossier.

### 6.2 bis Preuve complémentaire — le symptôme EST instrumenté (trace 67)

`TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_67_SIMU_MaintMANU_20260919_wide.csv` :

| Mesure | Valeur |
|---|---|
| Runs contigus « armé + demande > 5 % + vitesse M1 = M2 = 0 » | **13** |
| Le plus long | **10 356 ms** (t = 56 061 → 66 417 ms), position M1/M2 **strictement gelée** |
| `ArmingPermit` | **1 sur 100 % des échantillons** |
| `ArmingPermitDenied` | **0 sur 100 % des échantillons** |
| `DirectionChangeDelayElapsed` max | **2 174 ms** à t = 73 355 ms — **identique** au chiffre publié par le brief v2 (`:299`) ⇒ reproductible |

➡️ **Ce que ça prouve** : le symptôme « armé, demande présente, aucun mouvement » est **réel et
mesuré** ; **et `ArmingPermit` ne chute jamais** pendant ces fenêtres ⇒ le défaut n'est **pas** une
chute de permis, c'est bien une **fenêtre silencieuse** (§4.1/G1, C22/C23/C36).
➡️ **Ce que ça ne prouve pas** : la cause exacte de chaque run (les termes `RestartInhibit`,
`RestartRequired`, `DeadTimePending`, `MovementInhibited`, `SafeStop`, `PowerCutOff`,
`ContactorStuck`, `ArmingAvailability`, `NoMovement` **n'apparaissent dans AUCUNE des 81 traces** du
dépôt — mesuré fichier par fichier). **Aucune trace ne porte les 5 termes de l'agrégat T228.**

**Hypothèses réfutées en route (à ne pas reprendre) :**
- ❌ **Mode non discriminant** : `SelJoystickWinch = 0` partout, **y compris** quand le mouvement a
  lieu (t = 43 079 ms, contacteur M2 collé, 1,25 m/s) ⇒ ce signal ne sépare pas les cas.
- ❌ **La famille 2 n'explique pas le gros du symptôme** : seuls **45 des 368** échantillons de
  `Suivi_67` sont sous `DirectionChangePending` ⇒ D18 est un contributeur **minoritaire** sur cette trace.
  *(Cohérent avec C34 désormais corrigé, et avec la conclusion de la fiche TRACE64 `:35`/`:42` qui
  écarte aussi D18 seul.)*

**⚠️ LIMITE STRUCTURELLE À CONNAÎTRE (elle conditionne toute l'Étape B)** :
`RampTargetStep` — **la** variable qui reçoit `0` en famille 2 selon `CADRAGE_T325…:11-12` — **n'est
tracée dans AUCUNE des 81 traces**. La distinction **famille 1 (aval) / famille 2 (amont) n'est donc
PAS mesurable** sur les preuves existantes : elle est **déclarée** (`CADRAGE_T325…:8-14`,
`BRIEF_T224…v2:299`), jamais **mesurée**. Idem `ArmingAvailability`, `BlockedReason`,
`MovementInhibited`, `RestartInhibit`, `RestartRequired`, `DeadTimeArmed`, `DeadTimePending`,
`NoMovement`, `SafeStop`, `PowerCutOff`, `ContactorStuck` : **0 occurrence chacun sur l'intégralité de
`TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/`** (mesuré fichier par fichier). Seules variables de tempo
réellement capturées : `WinchM1/M2State.DirectionChangePending` et `.DirectionChangeDelayElapsed`
(`Suivi_66/67/68/69/70/71`) — **la direction M1-M2 est la seule famille instrumentée** ;
`instWinchOutputInterlockM1.StepDelayElapsed` n'existe que dans `archives/` (donc non invocable).

**Preuve complémentaire de famille 2 (avec `ArmingPermit = 1`)** :
`Suivi_68_SIMU_MaintMANU_20260919_wide.csv` — **97 échantillons** sur 281 (35 %) en « armé + demande
> 5 % + vitesse 0 », plage t = 29 724 → 41 591 ms, **97 avec `DirectionChangePending = 1`** et
`DirectionChangeDelayElapsed` comptant de 74 à **1 889 ms**, `ArmingPermit = 1` / `Denied = 0` partout.
⇒ Le symptôme famille 2 est **tracé**, **avant** le correctif D18 (`657be973`), **avec le permis à 1**.

### 6.3 Fiches et registres pertinents déjà présents

| Document | Apport |
|---|---|
| `DOC/WFLOW/REGISTRES/REGISTRE_Suivi_MiseEnService_20260902.md:124-138` (MES-034) | **Preuve du forçage DI au banc** (`:125`, `:130`) — clé de G3. Signale aussi `BypassCommunGlobal` **orphelin** (`:129`). |
| `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T354_ASYMETRIE_GARDE_M1_M2_20260921.md:36-37`, `:18-24` | Asymétrie de garde M1/M2 (C37), atteignabilité **prouvée** en MAINT_N1/N2 unitaire ; rappelle la correction de prémisse sur les modes (`E_Mode.st:9-12` : `DISABLE / MAINT_N1 / MAINT_N2 / SEMI_AUTO`). |
| 🥇 **`DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_BenneOuverture_BlocageCouplage_20260905.md:53-54`, `:60`** | **ANTÉCÉDENT DIRECT DE TOUT CE DIAGNOSTIC, daté 2026-09-05 (16 jours avant le brief).** `:53` décrit déjà le mécanisme de **C26** : *« le snapshot montre une demande amont M2 (`RelayRevActive=TRUE`, palier 1), mais un **frein final non commandé (`BrakeCmd=FALSE`) sans erreur, SafeStop ni permis final refusé**. **La barrière finale masque donc l'action** »*. `:54` décrit déjà **G2/quasi-AL-05** : *« **Défaut de diagnostic** : `GVL_Troubleshooting` publie le relais amont, mais pas `FB_WinchOutputInterlock.State`, `Reason`, `RestartRequired`, `RestartInhibit`, `DeadTimePending` ni ses temps écoulés. **La cause finale n'est pas lisible** »*. Et **`:60` porte déjà le correctif cadré en C4** : *« **Définitif (à planifier C4)** : publier `FinalInterlockState`, `Reason`, `RestartRequired`, `RestartInhibit`, `DeadTimePending`, `RestartDelayElapsed` et `DeadTimeElapsed`, puis corriger uniquement la branche prouvée, avec test MAINT/SEMI_AUTO »*. ⇒ **Mon Option A/B n'est pas une invention : c'est un cadrage déjà écrit, jamais planifié.** |
| `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_AX10B_CONTINUITE_TRACE65_20260920.md:32` | **Le manque d'instrumentation reconnu et écrit** : *« Les variables `DirectionChangePending`, `M1AscentStartReady`, `RestartRequired` et `DeadTimePending` ne sont toutefois pas présentes ; elles resteraient nécessaires »*. |
| `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_AX10_AX11_AX12_TRACE62_20260919.md:46` | **Gabarit prêt à l'emploi** pour la trace à produire : liste de variables à ajouter (dont `DirectionChangePending` M1/M2, `RestartRequired` M1/M2, **`Reason` des 2 `FB_WinchOutputInterlock`**) ⇒ **la preuve manquante est comblable sans inventer de méthode**. |
| `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md` (T351) §6.4-A2, §10-4 | Source initiale de l'asymétrie C37. |
| `DOC/WFLOW/AUDITS/DESIGN/CADRAGE_T325_D18_INTERLOCK_DIRECTION_v1.0.md:8-14` | Les **2 familles** (§2.0 de ce livrable) — toujours valide comme distinction. |
| `…/CADRAGE_T325_D18_INTERLOCK_DIRECTION_v1.0.md:36-70` | **PÉRIMÉ** : « Défaut 2 » corrigé par `657be973` (C34). |
| `DOC/WFLOW/TASKS.yaml:316` | Dette documentaire **déjà cataloguée** : catalogue T325 périmé (commits `6f708b22`, `657be973`, `e638308f`). Confirme indépendamment ma lecture de C34. |
| `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T370_DISCORDANCE_CONTACTEURS_20260921.md` **existe** (`:84-85`, `:205`, `:207`) | **Corrobore indépendamment C25 et C45**, et **prouve la distinction T370/T224** : `:84` — `Meca B` détecte un contacteur **collé** (qui ne retombe pas), *« Sens **inverse** : détecte un contacteur **collé**, pas un contacteur qui **ne ferme pas** »* ; `:85`/`:207` — `ContactorStuck` de la **barrière** = latch T_max **400 ms**, `Reason := SENSE_DROP_TIMEOUT`. **Deux `ContactorStuck` homonymes dans deux FB différents** (`FB_Safety_Winch:484` = `MecaBFaultLatched` **vs** `FB_WinchOutputInterlock:80`/`:324` = `ContactorStuckLatched`) — **ne pas les confondre**, et **aucun des deux n'est publié** (AL-05). |
| `DOC/WFLOW/REGISTRES/REGISTRE_Suivi_MiseEnService_20260915.md:12` | **Preuve terrain de la chaîne C43** : *« sous commande sans mouvement, avec retour collectif « tous contacteurs au repos », une alarme unique `ErrorID:16` est levée puis le **SafeStop** agit après 3 s. Aucun PowerCutOff ajouté. »* ⇒ confirme `ErrorID:16` → SafeStop → 3 s, et le **retour collectif forcé** (même famille que la leçon G3). |
| `DOC/WFLOW/REGISTRES/REGISTRE_MES_Rapport_Mail_GCAM_20260915.md:33`, `:59` | **Source client d'origine** de T224 et du littéral « commande sans mouvement ». |
| `DOC/WFLOW/TASKS.yaml:2-23` (T228) | Contrat orphelin **régularisé** le 2026-09-21 comme **sous-tâche de T224** (`parent_id: T224`) — l'alerte A2 du brief v2 est **déjà traitée**. |
| `DOC/WFLOW/TASKS.yaml:2982-2985` | Origine du libellé « commande sans mouvement » (fusion doublon T157). |
| `DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md:384` | **⚠️ Spécifie comme actuel un comportement absent du code** (voir §7, alerte AL-01). |
| `DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md:582-583`, `:590-591` | Décrit correctement l'agrégat `ArmingPermit` et la reprise **B** — conforme au code. |
| `DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md:316` | `TC-P08-060` : GAP déclaré sur `ArmingPermitDenied` (corrobore C42). |
| `DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md:521-527`, `:575`, `:610` | Ordre `MainTask` (conflit de scan G1) + aveu d'absence de gate d'ordonnancement. |

### 6.4 T370 vs T224 — recoupement ?

**Recoupement de PÉRIMÈTRE : NON. Recoupement de SOURCE et d'ARTEFACT : OUI (3 termes).**

| Critère | **T370** | **T224 / T228** |
|---|---|---|
| Entrée catalogue | `TASKS.yaml:24-35` — `parent_id: T288`, C2, `SECURITE_ET_AU / TREUILS_M1_M2` | `TASKS.yaml:2962-2990` (T224) · `:2-23` (T228, `parent_id: T224`) |
| Objet | *« Investigation seule (zero code) — Etat actuel **discordance commande/retour contacteurs puissance** »* (`:33`) | *« `ArmingPermit` cohérent avec disponibilité réelle des actionneurs »* (`:2970`) |
| Symptôme décrit | *« l'automate envoie une commande, mais les contacteurs **ne bougent pas physiquement** »* (`:34`) ; *« alarme + SafeStop apres 3s »* (`:34`) | *« le joystick s'arme alors que les moteurs/mouvement ne sont pas réellement prêts »* (`:2983`) |
| Moment du défaut | **APRÈS** émission de l'ordre (retour d'état contacteur) | **AVANT** / pendant la formation de la commande (disponibilité) |
| Termes partagés (prouvés) | ① **mail client GCAM 2026-09-15** (T370 `:34` ↔ brief v2 §3.2) ② littéral **« commande sans mouvement »** (T370 `:34` ↔ T224 `:2983`) ③ artefact **`ContactorStuck`** (T224 `:14` ↔ `TROUBLESHOOTING_T370…:85`) | idem |
| Mécanisme partagé | `FB_Safety_Winch.ErrorMecaB` / `ContactorStuck` (C45) — *« Absence confirmation arret contacteurs/frein »* `:350`, `PostRampTimeout = T#3s` `:49` | `FB_Safety_Winch.ErrorNoMovement` (C43) — `NoMovementTimeout = T#3s` `:59` |
| Sens de la discordance | **Joystick AU NEUTRE** (le contacteur ne **retombe** pas) — fiche T370 `:84` | **Mouvement COMMANDÉ** (le contacteur **n'agit** pas / l'axe ne bouge pas) — `FB_Safety_Winch:439` (`MovementCommanded AND BrakeFeedback`) |

➡️ **Conclusion** : les deux tâches **ne se recouvrent pas fonctionnellement** (l'une regarde le
**retour** des contacteurs de puissance, l'autre la **disponibilité avant** commande), mais elles
**partagent le même mail client, le même vocabulaire et le même FB** (`FB_Safety_Winch`), et **deux
timers de 3 s distincts** y produisent deux défauts confondus par l'IHM (`FB_Hmi_BannerFormatter.st:945`
affiche `ErrorNoMovement` sous le mot « discordance commande/retour/mouvement »). **À sérialiser**
(ne pas lancer les deux lots en parallèle sur `FB_Safety_Winch`), et à **désambiguïser dans le
bandeau**.

---

## 7. 🚨 DEVOIR D'ALERTE — HORS SCOPE, SIGNALÉ, NON CORRIGÉ

| # | Alerte | Preuve | Gravité |
|---|---|---|---|
| **AL-01** | 🔴 **`AF_Partie-08` SE CONTREDIT ELLE-MÊME à 210 lignes d'intervalle.** ① `:384` affirme que `ArmingPermit` *« passe aussi à `FALSE` tant qu'une temporisation d'attente de la barrière finale (anti-court-cycle `RestartRequired`/`RestartDelay` ~1,5 s, temps mort directionnel `DeadTimePending`, `RestartInhibit`, contacteur collé) interdit un redémarrage… **Levé par le bypass groupe du treuil en mise en service** »* — **c'est le lot T228 REVERTÉ** (terme tempo ajouté `c9665355`/`e2f5b9dc` ; `RestartDelay PT := T#1500ms` `72ce5eec:227` ; bypass `44187804`, retiré par `b96a8988`). ② `:594-596` affirme **l'inverse** : *« ⚠️ **Non couvert (arbitré T224, voie a)** : `RestartInhibit` / `WAIT_RESTART_DELAY` transitoires de la barrière finale (`FB_WinchOutputInterlock`, exécutée en `PRG_06` hors périmètre) — armement trompeur bref (~1,5 s) accepté »* — **c'est l'état réel à HEAD**. ⇒ Un lecteur reçoit **deux réponses opposées selon la ligne qu'il lit**, dans la **même fiche de sécurité v2.5**. | AF-08 `:384` **vs** `:594-596` ; `PRG_04:1164-1173`, `:1205-1206` ; `E_ArmingBlockReason.st:10-15` ; `git show 72ce5eec:…FB_WinchOutputInterlock.st:227` ; `git show 44187804` / `b96a8988` | 🔴 **C4 — contradiction interne d'une spec de sécurité.** `:594` dit vrai et **décrit G1 comme un trou assumé** ; `:384` dit faux et **laisse croire G1 traité et livré**. C'est `:384` qui doit être réaligné. |
| **AL-02** | **Le « ~1,5 s » n'est pas une coquille : c'est la valeur du lot annulé**, restée dans **3 documents** (contrat T224 `l.76`, contrat T228 `l.87`, `AF-08:384`) alors que le code porte **500 ms** (`FB_WinchOutputInterlock:151`, `:224`) et `DeadTimeSameDir/OppositeDir = 500/700 ms` (`:35-36`). | idem AL-01 ; `CADRAGE_T325…:22-24` (relevait déjà l'écart AF-10) | 🟠 Majeur — **fusionnée avec AL-01** : les deux ont la même cause (doc non réalignée après le revert). Tout chiffrage de G1 sur cette base est faux d'un facteur ×3. |
| **AL-03** | **`CADRAGE_T325_D18_INTERLOCK_DIRECTION_v1.0.md:36-70` est PÉRIMÉ** : le « Défaut 2 » (purge `DeadTimeArmed` inatteignable) est **corrigé** (`657be973`), ordre `:132` avant `:140`. Le brief v2 §3.4 et sa question 1 (« ajouter le Défaut 2 T325/D18 ») reposent sur un état de code dépassé. | `FB_WinchDirectionInterlock.st:132-143` · `git merge-base --is-ancestor 657be973 HEAD` → **0** · `TASKS.yaml:316` | 🟠 Majeur — risque de re-scoper un travail déjà fait. |
| **AL-04** | **Preuve manquante invoquée par un contrat** : trace `Suivi_JOY_permit_bug_13` **absente** du dépôt (`TASK_CONTRACT_T228…:87`). | §6.1 | 🟠 Majeur — décision de conception non traçable. |
| **AL-05** | **Le diagnostic de mouvement de l'opérateur est AVEUGLE aux conditions de G1** (et non « tout est mort » — correction après vérification). **EST lu et publié** : `Reason` → `FB_WinchStateProjection.st:113`, `:180` (`WinchM1/M2State.FinalInterlockReason`) et `PRG_05:756` (M3) → `FB_TroubleshootingView.st:223`/`:302` (`Idx406_FinalInterlockReason`), `:418` (`Idx405`) ; `Fault.Error` → `:577`, `:609`, `:644` (`Step8_OutputInterlockOk`) ; M3 `ErrorId` → alarme bandeau `FB_Hmi_BannerFormatter.st:63`, `:1038`. **N'EST PAS lu** : `State`, `RestartInhibit`, `ContactorStuck`, `DeadTimePending`, `SenseHoldActive` (grep : 0 consommateur) ; `PermitFinalBlocked` est une **VAR privée** (`FB_WinchOutputInterlock:87`). **Cause structurelle de l'aveuglement** : `Reason` n'est assigné qu'à **4 endroits** (`:210` NONE, `:362` RESTART_INHIBITED, `:372` SENSE_DROP_TIMEOUT, `:508` BRAKE_COMMAND_NOT_CONFIRMED) — **aucune assignation dans la branche `PermitFinalBlocked` `:393-404`, ni dans la branche `WAIT_RESTART_DELAY` `:424-430`** (qui ne posent que `State`). Or `Step8_OutputInterlockOk := NOT FinalInterlockError` et `Idx401_MotionAllowed := WinchMx.State.Ready` (`FB_TroubleshootingView.st:218`, `:297`, `:414` — `Ready` = **process**, `FB_Winch:164`). | §4.2 / G2 bis · `FB_WinchOutputInterlock.st:210/362/372/508` · `FB_WinchStateProjection.st:113-115` · `FB_TroubleshootingView.st:218/577` | 🔴 **C4 — pire qu'un silence : un faux vert.** Le seul outil qui affiche « pourquoi un ordre ne colle pas les relais » (`ST_MotionChecklist.st:4`, `:30` : *« 🟢 TRUE = TOUTES LES CONDITIONS SONT REMPLIES, LES RELAIS DOIVENT COLLER ! »*) affiche **TOUT VERT** pendant `PermitFinalBlocked` et pendant `WAIT_RESTART_DELAY` — c'est-à-dire exactement pendant les cas C12/C18/C22/C23/C26. |
| **AL-06** | **`ArmingPermitDenied` (warning F08.08) n'a AUCUN consommateur** : produit `FB_Joystick:244`, publié `PRG_02:495`, typé `ST_AcquisitionJoystickQualified.st:16` — jamais miroité (`PRG_07` miroite `DeadmanArmed`/`AtNeutralXY`, pas ce champ). | grep exhaustif (4 occurrences) + AF-08 `:316` (`TC-P08-060`) | 🟠 Majeur — le seul message « pourquoi je n'arme pas » n'atteint pas l'opérateur. |
| **AL-07** | **Collision de libellés IHM** : `ErrorNoMovement` (bit15) est affiché sous le mot **« discordance commande/retour/mouvement »** (`FB_Hmi_BannerFormatter.st:945`, `:993`), tandis que **T370** traite de la *« discordance commande/retour contacteurs puissance »* (`TASKS.yaml:33`). Deux défauts distincts, un seul vocabulaire. | `FB_Hmi_BannerFormatter.st:945` vs `TASKS.yaml:33` | 🟠 Majeur (maintenance). |
| **AL-08** | **`ArmingPermit` dépend déjà d'un DI** : `ArmContactorOff := NOT PowerContactorEngaged_DI` (`PRG_04:1187`) — exactement la classe de risque qui a cassé le banc (leçon A2). Mitigation existante : `HwSim` via `MachineInputSourceSimulated` (`PRG_02:138`, `:446`). | §2.1 C02 | 🟡 Mineur (mitigé). |
| **AL-09** | **Asymétrie M1/M2 de la garde d'arbitrage** : `FB_WinchCmdArbitrationM1.st:117` porte `AND NOT Context.BucketBusy`, absent de `FB_WinchCmdArbitrationM2.st:143-144`. | §2.1 C37 + fiche T354 | 🟡 Déjà instruit par T354 — **signalé pour mémoire**, hors scope T224. |
| **AL-10** | **`TOOLS/AGENT_WORKFLOW/.tmp/g390_freshness_*`** : **423 répertoires** contenant chacun une copie complète de l'arborescence `CODE/` (relevé par `glob` sur `**/ST_PermitVisibilityHMI.st` et `**/E_WinchFinalInterlockReason.st`). Non listés par `git status --short` (donc ignorés). Aucune suppression effectuée (règle : le nettoyage est humain). | `glob` (spill : `…\dsh-spill-Tgr9Mb\session-1cf6ade748cd\*.txt`) | 🟡 Mineur (hygiène / risque de lecture d'une copie périmée). |
| **AL-11** | **`git status` non propre à la prise** : 3 fichiers `CODE/` modifiés par le lot **T368**. Toute preuve `fichier:ligne` sur `FB_Hmi_BannerFormatter.st` doit préciser la révision (fait dans ce livrable). | §0 | 🟡 Méthode. |
| **AL-12** | **`BypassCommunGlobal` orphelin** (restauré/miroité, lu par aucun interlock) — remonté par le registre MES ; **non revérifié** dans ce diagnostic. | `REGISTRE_Suivi_MiseEnService_20260902.md:129` | ⚪ À vérifier ailleurs. |
| **AL-13** | **Le contrat T228 décrit un état INTERMÉDIAIRE, jamais livré, pour 2 de ses 3 décisions de conception.** ① `l.89` (bypass MES groupe) = `44187804`, **retiré par `b96a8988`** (`git show b96a8988:…PRG_04` → 0 occurrence des 3 lignes `ArmMxMoveInhibited AND NOT … Bypass.Global`) ; ② `l.87` décrit l'agrégat de `e2f5b9dc`, **abandonné avant la fin du lot** (forme finale `72ce5eec:564-568` = `State` seul). Un contrat qui porte des décisions abandonnées **ne peut pas servir de référence de reprise** en l'état. | `TASK_CONTRACT_T228…l.87`, `l.89` **vs** `git show 44187804` / `git show b96a8988` / `git show 72ce5eec:…FB_WinchOutputInterlock.st:564-568` | 🟠 Majeur — décision de reprise possible sur une base fausse (le brief v2 §4 reprend d'ailleurs cette ligne 89 comme un acquis). |
| **AL-14** | **Snapshots cités par les messages de commit introuvables** : `184754` et `185521` (2026-09-02) ne sont dans aucun fichier du dépôt (`git grep "185521" 5a531d38` = 0 résultat). Leur contenu n'est connu que par les messages de commit. | §4.3 (b-bis) | 🟡 Mineur — n'invalide pas le mécanisme, prouvé par le code. |
| **AL-15** | **La simulation ne peut pas voir les bugs de ce type** : `FB_SimBench.st:448-450` (M1) et `:473-475` (M2) — `Winch.M1_ContactorsReleased_DI := NOT (M1_RelayFwd OR M1_RelayRev OR M1_SpeedContactor_1..4)` — donc **en simulation le signal retombe automatiquement dès qu'un sens est commandé** ⇒ le chemin rapide NoMovement était **indéclenchable en simu/CI** (à la révision annulée : `git show 5a531d38:CODE/L_SIMULATION/FB_SimBench.st` → `:206`/`:212`, même expression). Tout terme gaté par un DI **forcé au banc** échappe mécaniquement aux 21 gates. | **VÉRIFIÉ par DSH28** : `FB_SimBench.st:448-450`, `:473-475` @HEAD ; `5a531d38:…FB_SimBench.st:206`, `:212` | 🟠 Majeur — angle mort de la CI : une reprise doit prévoir un test de **banc** ou un forçage de simu dédié, pas seulement des gates. |

---

## 8. 🛠️ OPTIONS DE CORRECTIF — SANS UNE LIGNE DE CODE

> ⚠️ **Périmètre correctif NON arbitré ici.** Le brief v2 §5 impose un **arrêt humain (Étape B)** avant
> toute écriture. Les options ci-dessous décrivent **quoi** et **quel risque**, jamais **comment coder**.

### Option A — **G2 seul** : rendre visible l'existant (aucun terme nouveau)
> 📌 **Cette option n'est PAS nouvelle : elle est déjà cadrée dans le dépôt depuis le 2026-09-05**
> (`TROUBLESHOOTING_BenneOuverture_BlocageCouplage_20260905.md:60` : *« **Définitif (à planifier C4)** :
> publier `FinalInterlockState`, `Reason`, `RestartRequired`, `RestartInhibit`, `DeadTimePending`,
> `RestartDelayElapsed` et `DeadTimeElapsed`, puis corriger uniquement la branche prouvée, avec test
> MAINT/SEMI_AUTO »*). Le diagnostic de `:53-54` décrit déjà **C26** et **G2**. ⇒ **À reprendre, pas à
> réinventer** — et cela justifie de la traiter comme un **lot déjà justifié**, pas comme une idée d'agent.
- **Contenu** — deux volets, dans cet ordre de valeur :
  **① corriger le FAUX VERT** (le plus rentable) : faire renseigner `Reason` et/ou un `Fault` par les
  branches muettes `PermitFinalBlocked` (`FB_WinchOutputInterlock:393-404`, dont la variable est
  **privée** `:87`) et `WAIT_RESTART_DELAY` (`:424-430`), et/ou faire porter à `Step8_OutputInterlockOk`
  (`FB_TroubleshootingView.st:577`, `:609`, `:644`) l'état réel de la barrière au lieu de `NOT Fault.Error` ;
  **② brancher `Data.ArmingAvailability`** (`PRG_04:1192-1214`) et `ArmingPermitDenied` sur
  l'IHM/troubleshooting via `PRG_07`. `Reason` est **déjà** publié (`Idx406`/`Idx405`) — rien à câbler
  pour lui, contrairement à une première lecture.
  **③ (variante recommandée par l'antécédent de 2026-09-05)** : publier aussi `RestartRequired`,
  `RestartInhibit`, `DeadTimePending`, `RestartDelayElapsed`, `DeadTimeElapsed` — c'est **la liste
  exacte** du cadrage existant, et elle couvre l'ensemble de G1 sans toucher à la logique.
- **Coût** : faible. **Fichiers concernés** : `FB_WinchOutputInterlock.st` (**publication seule**, pas de
  logique de sécurité), `FB_WinchStateProjection.st`, `FB_TroubleshootingView.st`,
  `ST_PermitVisibilityHMI.st` et/ou `ST_MotionChecklist.st`, `PRG_07_Supervision.st`,
  `FB_Hmi_BannerFormatter.st` (+ câblage `PRG_07`). **Aucune logique de mouvement modifiée.**
- **Risque** : **quasi nul** sur la machine — n'ajoute aucun terme de disponibilité, donc **aucun
  risque de désarmement abusif nouveau** et **aucun risque de rejouer le revert** (aucune logique de
  sécurité touchée ; la seule modification dans un FB de barrière est une **publication d'état**).
  Traite la demande client GCAM (`REGISTRE_MES_Rapport_Mail_GCAM_20260915.md:33`, `:59`).
- **Limite honnête** : ne **corrige** pas la fenêtre silencieuse (G1) — il la rend **lisible**. C'est
  un gain d'explicabilité, pas de disponibilité. `ArmingPermit ≈ 1` reste vrai (A7 non satisfait).

### Option B — **G2 + G1 « vue amont »** : disponibilité enrichie sans toucher PRG_06
- **Contenu** : G2 **plus** l'ajout, dans le calcul de disponibilité (`PRG_04:1164-1177`), des termes
  **déjà disponibles en amont** : `M2AscentPermitApplied`/`M2DescendPermitApplied` (C12/C13),
  `M3_PosTremie_DI` (C18), et les états de la barrière **lus au scan N-1** si un relais est retenu
  (`Data.M1AscentStartReady`, `PRG_06:178-181`, en est le patron existant — mais il est consommé par
  le cycle, `PRG_03:267`).
- **Coût** : moyen. **Fichiers** : ceux de A + `PRG_04_Treuils_Benne.st` (+ `PRG_06_Outputs.st` si
  l'on publie `RestartRequired`/`DeadTimePending`/`Reason`).
- **Risque** : 🟠 **moyen, et c'est ici que se joue la non-régression** :
  ① un terme N-1 (10 ms) peut **clignoter** le voyant d'armement ;
  ② gater l'armement sur un terme de tempo **désarme un axe réellement disponible** (AC5) si le terme
  n'est pas **strictement par axe×sens** ;
  ③ **interdiction absolue** de fonder un terme sur un DI bypassable (C28/C29 — leçon G3) ;
  ④ toute perte de dispo transitoire désarme le geste **entier** (reprise = B, `FB_Joystick:238-240`)
  ⇒ une tempo de 500 ms **fait perdre le geste** à chaque arrêt : c'est **exactement** la plainte
  « impossible de monter » du banc si le seuil est mal placé. **À arbitrer explicitement par l'humain.**
- **Gain** : ferme **C12/C13/C18** (désarmement trompeur **permanent**, non transitoire) — les cas les
  plus solides, sans toucher aux tempos.

### Option C — **G2 + G1 complet + G3 (reprise du chemin T228)**
- **Contenu** : B **plus** les tempos idle de la barrière (C22-C27) exposés **et** consommés par la
  disponibilité.
- **Coût** : élevé (touche `PRG_04`, `PRG_06`, DUT de bus, IHM, tests).
- **Risque** : 🔴 **maximal.** C'est **le lot annulé** (`263fae18`). Les **3 leçons** sont désormais
  **prouvées sur pièces** (§4.3) : ① ne pas obtenir une information de disponibilité en **patchant un
  FB de sécurité** ; ② ne **jamais** fonder un terme sur un DI bypassable ; ③ un terme qui rend
  `ArmingPermit` « inutile » est un échec. S'y ajoute le **conflit de scan prouvé** (PRG_06 après
  PRG_04 ⇒ N-1 sur une logique de sécurité temporelle).
- **Condition de faisabilité non satisfaite à ce jour** : **`Suivi_JOY_permit_bug_13` est introuvable**
  (AL-04) et **aucune trace du dépôt ne porte `RestartInhibit`/`RestartRequired`/`DeadTimePending`**
  (§6.2) ⇒ **le dimensionnement d'un seuil de tempo ne peut pas être validé sur preuve**. Un lot C4
  de ce type devrait **d'abord** instrumenter ces 5 termes (trace dédiée) **avant** de coder.

### Recommandation technique (non décisionnelle)

Par **rapport risque/gain** et cohérence avec le revert documenté : **A immédiatement** — en commençant
par le **faux vert** de `ST_MotionChecklist` (AL-05 : un outil de diagnostic qui dit « les relais
doivent coller » alors qu'ils ne collent pas est **plus dangereux** qu'une absence d'outil, car il
oriente la maintenance vers une fausse cause) — **puis B restreint aux cas permanents (C12/C13/C18)** —
**jamais** les tempos. **C est à refuser en l'état** sans instrumentation préalable.
Ce n'est qu'un **avis d'ingénierie** : l'arbitrage est humain (Étape B), et le périmètre reste ouvert.

---

## 9. ❓ PREUVES MANQUANTES ET RESTE À INSTRUIRE

| # | Manque | Impact |
|---|---|---|
| 1 | **Trace `Suivi_JOY_permit_bug_13` ABSENTE** (référencée par `TASK_CONTRACT_T228…:87`) | La justification du lot annulé n'est pas vérifiable. **Bloquant pour l'option C.** |
| 2 | **Aucune trace ne porte `RestartInhibit`, `RestartRequired`, `DeadTimePending`, `MovementInhibited`, `ArmingAvailability`, `NoMovement`, `SafeStop`, `PowerCutOff`, `ContactorStuck`** (81 traces examinées, fichier par fichier) | Le dimensionnement de G1 ne peut pas être validé sur preuve ; une instrumentation est nécessaire. |
| 3 | **État réel des DI** `M1/M2_BrakeIsOpen_DI` (C28) et `M1/M2_ContactorsReleased_DI` (C29) sur machine : **non tracé** | Deux conditions de blocage **permanent** restent **non prouvées** (`NON PROUVÉ`, §2.2). Seul le forçage au banc est documenté (`REGISTRE…20260902:130`). |
| 4 | **Ordre de tâche CODESYS en ligne** non prouvé par artefact : `AF_Partie-02:532` exige une confirmation humaine, `:610` admet l'absence de gate. `Device.export` **volontairement non lu** (périmé, export frais requis). | Le conflit de scan G1 est prouvé **par documentation**, pas mécaniquement. |
| 5 | **Câblage `BypassProcess` vs `BypassGlobal` à la révision annulée** : la clause `IN := NOT BypassProcess AND …` (`72ce5eec:405`) et l'affirmation de bypass du contrat T228 `l.89` n'ont pas été confrontées ligne à ligne. | **HYPOTHÈSE** présentée comme telle en §4.3 — à trancher en Étape B si l'option C est retenue. |
| 6 | **`M2AscentStartReady`** n'existe pas (grep = 0) alors que `M1AscentStartReady` est publié (`PRG_06:178`) | À considérer dans toute option publiant la disponibilité barrière. |
| 7 | **`ST_OutputsInterPrg.st:23`** ne déclare que `M1AscentStartReady` — non relu intégralement. | Mineur. |
| 8 | **Chaîne `FB_SyncContactor`** (`Data.ContactorMismatch` → SafeStop après debounce 500 ms, puis `ContactorMismatchEscalated` → MécaE/`PowerCutOff`) : **prouvée par ses consommateurs** (`PRG_06:336-338`, `:363-364`) mais **non recopiée dans sa condition exacte** — le FB lui-même n'a pas été lu ligne à ligne. | La condition exacte de la discordance de synchronisme M1/M2 reste à confirmer si l'option B/C touche le couplage. **HYPOTHÈSE de chaîne, pas fait établi.** |
| 9 | **`FB_FaultCore.st`** lu partiellement (front `/Reset` et latch) — logique interne complète non auditée. | Mineur : n'invalide aucune conclusion (les latches sont prouvés par leurs sites d'appel). |
| 10 | **Snapshots `184754` / `185521`** (cités par les messages de commit de la fenêtre annulée) **introuvables** dans le dépôt (`git grep "185521" 5a531d38` = 0). | Leur contenu n'est connu que par des messages de commit ⇒ **non utilisables comme preuve** (cf. AL-14). |
| 11 | **Valeur exacte des DI sur le banc** à l'instant de la panne, notamment `M1_BrakeIsOpen_DI` : **non prouvée**. `MES-034:130` ne liste que les 2 forçages `ContactorsReleased` — ce qui **suppose** `M1_BrakeIsOpen_DI = FALSE` et **contredit** l'hypothèse « retour frein figé » avancée par le message de `72ce5eec`. | Le mécanisme de **C28** est prouvé par le code ; sa **condition d'apparition en exploitation** ne l'est pas. À trancher par un snapshot frais. |
| 12 | **Trace `Suivi_JOY_permit_bug_20260902_13.trace`** (ajoutée par `44187804`) : ne suit que `instJoystick.ArmingPermit`, `ArmingPermitDenied` et des canaux `M1_*` — **séries temporelles non dépouillées**. | L'affirmation « `ArmingPermit = 1` pendant `WAIT_RESTART_DELAY` » n'est **pas vérifiée** : citée par un message de commit, pas mesurée. |
| 13 | **`RampTargetStep` n'est tracé dans AUCUNE des 81 traces** — or c'est la variable qui reçoit `0` en famille 2 (`CADRAGE_T325…:11-12`). | **La distinction famille 1 / famille 2 n'est PAS mesurable** sur les preuves existantes : elle est **déclarée**, jamais **mesurée** (§6.2 bis). Conséquence directe pour l'Étape B : tout arbitrage « G1 vs D18 » repose aujourd'hui sur une lecture de code, pas sur une trace. |
| 14 | **`Suivi_71_SIMU_M1M2_CycleMD_Bug_20260920.trace`** (12,4 Mo) — la trace la plus riche en `ArmingPermit` + `DirectionChangePending` — **n'a pas d'export `_wide.csv`** (idem `Suivi_72` 3,4 Mo, `Suivi_73` 4,2 Mo). | Non exploitable sans conversion : **la meilleure trace disponible n'est pas lisible**. |
| 15 | **`Suivi_67` et `Suivi_68` n'ont pas de `_meta.json`** (seuls `Suivi_74_meta.json` et `Suivi_TranslationM3bug_20260904_27_meta.json` existent) ; et les 4 variables réclamées par la fiche TRACE64 (`:54-57`) **ne sont pas dans sa propre trace** `Suivi_64…wide.csv`. | Aucune métadonnée de session (fréquence, build, mode) sur les 2 traces les plus utiles ; les fiches réclament des signaux qu'elles n'ont pas. |

---

## 10. ✅ CONFORMITÉ DE LA MISSION

| Interdit | Respecté |
|---|---|
| Écriture dans `CODE/**`, `CODE_XML/**`, `TOOLS/TEST_AUTO_CI/**`, `PRJ_CODESYS/**`, `Device.export`, `DOC/AF/**`, `TOOLS/AGENT_WORKFLOW/scripts/**` | ✅ **aucune écriture** |
| Commit / push / `git checkout` / `restore` / `reset` | ✅ **aucun** — seuls `git show`, `git log`, `git blame`, `git diff <rev> <rev>`, `git merge-base`, `git status` (lecture) |
| Modification de `TASKS.yaml` / `TASK_LOCKS.json` / `TASKS_ORCHESTRATOR.yaml` | ✅ **aucune** |
| Proposition de patch / diff / code ST | ✅ **aucune** — §8 ne contient que des options et leurs risques |
| Chaîne AU ou FBs de sécurité modifiés | ✅ **aucun** |
| Scratch racine / fichier temporaire / redirection shell hors dépôt | ✅ **aucun** (les 179 entrées `git status` étaient **préexistantes**, cf. §0) |
| Fichiers écrits | ✅ `DOC/WFLOW/AUDITS/DESIGN/DIAGNOSTIC_T224_ARMINGPERMIT_20260921.md` + heartbeats `TOOLS/AGENT_WORKFLOW/status/task-T224-DIAG.log` |

**Sous-agents read-only mobilisés** (contexte frais, aucune écriture) : 3 — localisation du défaut
`NoMovement`, archéologie du revert `263fae18`, inventaire des traces terrain. **Toute conclusion
reprise d'un sous-agent a été re-vérifiée sur pièces par DSH28** (les lignes du §2.1, §3, §4.3 et §6.2
ont été relues directement dans le code et le Git). **Deux apports tardifs de sous-agent ont été
intégrés après vérification indépendante** : ① l'existence de `ST_MotionChecklist` et des index
`Idx401`/`Idx405`/`Idx406`/`Idx208` (→ **G2 bis**, faux vert prouvé) ; ② l'inhibition de
`ErrorNoMovement` par `RefWindowActive`/`BenneBusy` (→ **C43-bis**).
**Trois points issus des sous-agents ont été corrigés après vérification, dont UNE ERREUR DE MA PART** :
① « tout le diagnostic des barrières est mort » est **faux** — `Reason` et `Fault.Error` **sont** publiés
(`FB_WinchStateProjection.st:113-115`), l'aveuglement vient des **deux branches muettes** de la barrière
(AL-05, G2 bis) ; ② le **chemin rapide NoMovement n'est pas un commit T228** mais `18edd8a5`
(§4.3 (b)) ; ③ **erreur corrigée en C28** : j'avais inversé la polarité de la condition de purge —
`NOT BrakeFeedback` = frein confirmé **fermé**, donc un DI à FALSE **autorise** la purge, et le blocage
vient d'un DI figé **TRUE**. Enfin la citation `FB_SimBench.st:206-208` d'un sous-agent était **exacte
au fond mais fausse en numéros de ligne** (206/212 valent pour `5a531d38` ; à HEAD :
`448-450`/`473-475`) — re-vérifiée et rectifiée (AL-15).
**Un 3ᵉ apport tardif (inventaire des traces) a fait apparaître la pièce maîtresse du dossier et un
antécédent décisif, tous deux re-vérifiés sur pièces par DSH28** : ① la fiche
`TROUBLESHOOTING_MAINT_COUPLE_INTERLOCK_TRACE64_20260920.md:23`, `:26`, `:33`, `:42` — **la preuve
terrain la plus directe** (`ArmingPermit=1`, `DeadmanArmed=1`, demande présente, **aucun relais, aucun
ErrorId**, sur plusieurs secondes et de façon répétée, avec le blocage localisé *« avant les sorties »*) ;
② la fiche `TROUBLESHOOTING_BenneOuverture_BlocageCouplage_20260905.md:53-54`, `:60` — **le diagnostic de
C26 et de G2, ET le correctif C4 déjà cadré, datés du 2026-09-05** ⇒ l'option A n'est pas une
proposition nouvelle, c'est un **cadrage existant jamais planifié**.
⚠️ **Aucune des trois missions de sous-agent n'a écrit dans le dépôt** : les 179 entrées `git status`
sales étaient **préexistantes** (vérifié par DSH28 au début et à la fin).

---

*Fin du diagnostic T224 — Étape A. **Aucun code écrit · aucun commit.** La suite (Étape B : arbitrage
du périmètre G1/G2/G3) requiert un GO humain explicite.*
