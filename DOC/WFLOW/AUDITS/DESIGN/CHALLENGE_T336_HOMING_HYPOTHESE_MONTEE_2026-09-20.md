# 🥊 CHALLENGE T336 Phase 2 — Hypothèse « référencer à la MONTÉE » (front montant)

> **Mission** : T336 Phase 2 — challenge expert du cycle homing actuel (Graphe 7) + évaluation de l'hypothèse
> de simplification proposée par l'utilisateur.
> **Persona** : expert senior automatisme industriel / treuils synchronisés + benne · variateurs · codeurs ·
> référencement · sécurité machine (ISO 13849). **Posture anti-yes-man : rien n'est validé par défaut,
> y compris l'hypothèse utilisateur.**
> **Périmètre** : ⛔ **LECTURE SEULE** — aucun fichier `CODE/` modifié, aucun commit, aucune écriture hors ce livrable.
> **Date** : 2026-09-20 · **HEAD** : `e011036b`
> **Sources lues** : fiche `TROUBLESHOOTING_T336_CycleHoming_Graphe7_2026-09-20.md` · `CODE/G_CYCLE/FB_CycleMachineHoming.st`
> (685 l.) · `CODE/E_CODEURS/FB_Encoder_Homing.st` · `CODE/M_MAIN/PRG_02/03/04/05/07` · `CODE/H_TREUILS_BENNE/*`
> · `CODE/GVL_PERSISTENT.st` · `DOC/AF/AF_Partie-09_v2.4` · `DOC/AF/AF_Partie-10` · `DOC/WFLOW/AUDITS/GEL_GRAFCET_HOMING_CYCLE_20260903.md`
> · `CADRAGE_T330_INVARIANT_HAUT_v1.0.md` · contrats T185/T198/T199/T226/T260/T330 · `DECISIONS_T146_ARBITRAGE_ISO13849.md`
> · `CADRAGE_T175-01_M2_SLIP_SAFETY.md` · `CHALLENGE_T175-01_02_M2_BUCKET_SAFETY.md`

---

## 🚦 0 · Verdict en 5 lignes

1. ✅ **L'intuition « à la montée les câbles sont tendus donc c'est prévisible » est vraie… mais elle ne
   distingue RIEN** : la montée « en aveugle » existe **déjà** dans le cycle actuel (`HX2_CLIMB`, `:476-488`).
   Ce que l'hypothèse change n'est pas *où l'on monte*, c'est ***l'instant de capture du datum***.
2. 🔴 **En l'état, « référencer au vol au front MONTANT » est très probablement NON FONCTIONNEL** : la
   transaction preset n'accepte que **10 mm de déplacement dans les 50 ms** qui suivent le déclenchement
   (`FB_Encoder_Homing.st:109-110, 241-249`). Le cycle actuel ne passe que parce que le front est franchi
   **depuis un arrêt confirmé** (`HX2N`), à très basse vitesse. Un front montant est franchi **en fin de
   montée, à vitesse de croisière** : **20 mm** (palier 1, référence perdue) à **100 mm** (palier 5,
   référence encore valide — cf. §1.2bis) ⇒ **2 à 10 × la tolérance**.
3. 🔴🔴 **Mais l'hypothèse met le doigt sur un défaut MAJEUR du design actuel** : le cycle actuel **n'est pas
   exécutable « n'importe où »** — sa descente `HX3` est **interdite** si M3 n'est pas stable à P1/Maintenance
   (T249-A) **et M3 est elle-même bloquée quand les codeurs sont perdus** (interlock hauteur, insensible à
   `Bypass.Global`) ⇒ **la seule direction disponible est la MONTÉE** ⇒ impasse → `HXF_FAILED` (§1.3 + §1.3bis).
   **C'est l'argument le plus fort en faveur d'un référencement à la montée — plus fort que celui invoqué.**
4. 🔴 **La simplification « HX4/HX5 no-op » est à rejeter en l'état** : elle casse la qualification
   `MachineHomed` (`:465` vs `:594`) et **contredit T185 AC3/AC10/AC11 (C4 APPROVED)** — le datum benne
   n'est pas un « contrôle visuel », c'est une **capture géométrique dérivée des positions** (`FB_Bucket.st:419-436`).
5. ⚠️ **L'hypothèse ne contourne pas le conflit AF-09 : elle le rend BLOQUANT.** « Référencer M1/M2/**benne**
   au même franchissement » exige soit la cible dynamique M2 (supprimée après un REX de SafeStop synchro,
   `FB_CycleMachineHoming.st:412-420`), soit une valeur commune M1=M2 — et une valeur commune **rend
   `Delta = 0`**, ce que `FB_Bucket` classe **« benne OUVERTE »** (`OffsetOpenM = 0.0`, `GVL_PERSISTENT.st:66`).

**Synthèse des 6 verdicts** (détail §2→§7, options §8) :

| # | Sous-point | Verdict | Effort si retenu |
|---|---|---|---|
| 1 | Référencer **au vol au front montant** | 🔴 **REJETER tel quel** · 🟠 **ACCEPTER MODIFIÉ** (2 variantes, §8-A/B) | S (capture simple) → **L** (si refonte transaction preset) |
| 2 | Supériorité du design actuel (descente) | 🟢 **CONFIRMÉ pour la capture** · 🔴 **INFIRMÉ pour l'exécutabilité** (T249-A) | — |
| 3 | Cas dégradé sans translation | 🟠 **ACCEPTER MODIFIÉ** — l'intuition est **juste**, la mise en œuvre ne l'est pas | M |
| 4 | HX4/HX5 rendus no-op | 🔴 **REJETER** (code mort + qualification cassée) · 🟢 alternative : **fusion** | S (no-op) / M (fusion propre) |
| 5 | Articulation AF-09 (cible M2) | ⚠️ **PRÉALABLE BLOQUANT** — arbitrage humain requis avant toute implémentation | — |
| 6 | Montée en aveugle (risque propre) | 🟠 **RISQUE RÉEL, IDENTIQUE dans les 2 designs** — non couvert par l'hypothèse | M (mesure) |

---

## 1 · Le code actuel — 3 mécanismes que l'hypothèse percute (et qui n'étaient pas dans l'état des lieux T336)

> Ces trois mécanismes sont **la matière du challenge** : ils ne sont pas visibles dans le tableau d'étapes du Graphe 7.

### 1.1 🔴 Mécanisme A — la transaction preset ne tolère que **10 mm / 50 ms**

| Fait | Source |
|---|---|
| Au déclenchement : `PendingHomingRefRaw := RawPos − TargetPoints` · `PresetValue := RawPos` | `FB_Encoder_Homing.st:229-232` |
| 50 ms après : `CandidateRawDiff := RawPos − PendingHomingRefRaw` ⇒ `CandidateCablePosM = Cible + DÉPLACEMENT depuis le trigger` | `FB_Encoder_Homing.st:241-248` |
| Validation : `ReadbackOk := ABS(CandidateCablePosM − TargetPositionM) <= CST_HomingVerifyToleranceM` | `FB_Encoder_Homing.st:249` |
| `CST_PresetVerifyTime = T#50MS` · `CST_HomingVerifyToleranceM = 0.010 m` | `FB_Encoder_Homing.st:109-110` |
| Donc : **vitesse implicite max au moment du trigger = 0,010 / 0,050 = 0,20 m/s** | calcul |
| Échec ⇒ `HomingSuspect := TRUE`, `PresetConfirmationFailed := TRUE`, `PresetFailError := TRUE` | `FB_Encoder_Homing.st:271-276` |
| ⇒ `Homed := Calib.Homed AND NOT Calib.HomingSuspect` ⇒ **axe non `HomedAndReliable`** | `FB_Encoder_Homing.st:290` |

> ⛔ **Conséquence directe** : le déclencheur « au vol » n'est viable **que si la machine est quasi à l'arrêt
> au franchissement**. Le design actuel l'obtient **par construction** : `HX2N` exige
> `WinchesMechanicallyStopped` + `SeenNeutral` + capteur actif **avant** `HX3` (`:498-502`), et le front
> descendant est franchi **au tout début** de la descente (bande d'hystérésis du capteur), donc **pendant la
> rampe de démarrage**, à très basse vitesse. C'est exactement ce que dit le gel 2026-09-03 :
> « `F_TRIG(TopPositionActive)` (front descendant = sortie du capteur, **basse vitesse → répétable**) »
> (`GEL_GRAFCET_HOMING_CYCLE_20260903.md:89, 162`).
> ⚠️ **À mesurer** : la vitesse réelle au franchissement n'est **pas instrumentée** — constat déjà posé par T330
> (« la distance d'arrêt réelle au palier 1 n'est PAS instrumentée », `CADRAGE_T330…:179-187, P7`).

### 1.2 🟢 Mécanisme B — « petite vitesse » est **garanti** hors référencement (pas une intention)

| Fait | Source |
|---|---|
| `IF NOT (HomedAndReliable M1 AND M2) THEN CommonMaxStepAscent := 1; CommonMaxStepDescent := 1` | `PRG_04_Treuils_Benne.st:1220-1230` |
| Commentaire : « **SECURITE ISO 13849 — posture fail-safe** … sans ce garde-fou, palier 5 accessible non référencé » | `PRG_04:1220-1225` |
| Doctrine actée AF-10 §7.7 + décision T146 (visa humain **absent**, `validated_by: ""`) | `AF_Partie-10…:594-616` · `DECISIONS_T146…:43, 60-64, 106-123` |

> ✅ **Bonne nouvelle pour l'hypothèse** : « montée petite vitesse » **n'est pas une hypothèse opérateur**, c'est
> un garde-fou actif (plafond palier 1, montée **et** descente, M1 **et** M2) tant que les codeurs ne sont pas
> fiables. ⚠️ **Mais c'est aussi ce qui tue la capture au front montant** : palier 1 = vitesse de **croisière**
> en fin de montée, alors que c'est une vitesse de **démarrage** au début de la descente (§1.1).
> ⚠️ Le palier 1 n'est **pas** une valeur absolue : `SpeedBandMaxMps := [0.4, 0.8, 1.2, 1.6, 2.0]` (`GVL_PERSISTENT.st:27`)
> ⇒ plafond mesuré palier 1 ≈ **0,4 m/s** ⇒ 20 mm en 50 ms. **Toute la conclusion §2-1 en dépend** (mesure requise).

#### 1.2bis 🔴 Le plafond palier 1 **ne protège PAS le cas nominal de l'hypothèse**

> ⛔ **Le garde-fou est conditionné** : `IF NOT (HomedAndReliable M1 AND M2) THEN plafond := 1` (`PRG_04:1226-1230`).
> Il ne s'applique donc **que lorsque la référence est déjà perdue**.

| Cas | Référence machine | Plafond palier | Montée vers le capteur TOP |
|---|---|---|---|
| **Datum perdu** (le cas « normal » du homing) | `HomedAndReliable = FALSE` | ✅ **palier 1** (protection active) | ✅ libre (butée logicielle **inerte** sans référence, `PRG_04:840-844`) |
| **Datum encore valide** ⚠️ = **cas NOMINAL de l'hypothèse utilisateur** (« benne fermée confirmée, on monte référencer ») | `HomedAndReliable = TRUE` | 🔴 **palier 1 NON appliqué** ⇒ l'opérateur peut monter **jusqu'au palier 5** (`SpeedBandMaxMps[5] = 2,0 m/s`) | 🔴 **montée BLOQUÉE à 7,5 m** par `AscentPermit` (`CablePosM >= TopLimitM`, `FB_Safety_Winch.st:581`) sauf **bypass latché** `Bypass.TopLimitSoftware` (`PRG_04:855-861, 872-877`) |

| Fait | Source |
|---|---|
| `InReferencingMode` (= `HomingLifecycle.Busy` = fenêtre preset **50 ms**) exempte `AscentPermit` du FDC **et** du capteur — **pendant 50 ms seulement** | `FB_Safety_Winch.st:576, 581` · `FB_Encoder_Homing.st:289` · `PRG_04:933, 1002` |
| `SelHomingApproachEnable` (case IHM « autorise le dépassement butée haute pour homing ») **ne l'autorise PAS** : son effet réel est un **plafond palier 1** (`FB_Winch.st:190-191`) ⇒ **placebo** au regard de son libellé | `ST_CommunCfg.st:13` vs `FB_Modes.st:344` · `CADRAGE_T330:379` |
| Sur machine **déjà référencée**, « le **seul** chemin de montée vers le TOP est le **bypass IHM latché** `Bypass.TopLimitSoftware` » (l'override relève la butée mais exige **MAINT_N1**, alors que le homing exige **MAINT_N2**) | `CADRAGE_T330:366, 378` |

> 🧨 **Conséquence pour l'hypothèse — son cas « nominal » est en réalité le PIRE cas** :
> 1. la montée vers le capteur n'est possible **que** par un **bypass de sécurité latché** (dérogation tracée,
>    `PRG_04:830-833`) — donc **pas un chemin nominal** ;
> 2. le plafond palier 1 **ne s'applique pas** ⇒ la montée peut se faire **jusqu'à 2,0 m/s** ⇒ à ce régime, le
>    déplacement pendant les 50 ms de vérification atteint **100 mm = 10 × la tolérance** ⇒ **échec certain**
>    de la transaction preset ;
> 3. `InReferencingMode` ne couvre que **50 ms** : la décélération depuis 2,0 m/s est **beaucoup plus longue**,
>    et se déroule **sur la barrière dure** ⇒ fenêtre d'escalade **Méca D** (SafeStop + **PowerCutOff** après
>    `PostRampTimeout`) largement ouverte.
> ⇒ **Le scénario « benne fermée → montée → référencement au franchissement » est, en l'état du code, à la fois
> difficile à engager (bypass requis) et peu fiable à capturer (vitesse non maîtrisée).**

### 1.3 🔴 Mécanisme C — le cycle actuel dépend d'une **descente interdite** hors P1/Maintenance (T249-A)

| Fait | Source |
|---|---|
| `WinchDescentAuth_M3 := NOT TglEnableWinchDescentLock_M3 OR M3.AtP1 OR M3.AtMaintenance OR bypass` | `PRG_03_Modes_Cycle.st:363-368` (MAINT) · `:457-468` (MAINT_N1/N2) |
| `TglEnableWinchDescentLock_M3 := TRUE` **par défaut** | `GVL_PERSISTENT.st:146` · `ST_CommunCfg.st:32` |
| Consommé : `IF NOT WinchDescentAuth_M3 THEN ProcessAndSafetyPermitM1_Descend := FALSE` (+ M2 hors jog/programme benne) | `PRG_04_Treuils_Benne.st:1057-1074` |
| `M3Locked := CycleRunning` (HX2..HX6) ⇒ M3 en **SafeStop**, **sans bypass** | `FB_CycleMachineHoming.st:580-586` · `PRG_05_Translation.st:474-481` |
| `HX3` commande une **descente** M1+M2 | `FB_CycleMachineHoming.st:504-509` |
| Timeout HX3 ⇒ `TransactionAbort` ⇒ `HXF_FAILED` | `FB_CycleMachineHoming.st:214-215, 516-518` |

> 🚨 **Impasse mécanique et logique** : hors `P1`/`Maintenance`, `HX3` ne peut pas descendre (permis coupé),
> et `M3Locked` **empêche de repositionner M3** pour débloquer ⇒ `HomeAxesTimedOut` (60 s) ⇒ `HXF_FAILED`,
> sortie uniquement par `Reset` conscient. **Le cycle G7 actuel n'est donc exécutable que dans 2 positions de
> translation** (ou avec un bypass armé). ⚠️ Ce point est **absent** de l'état des lieux T336 Phase 1.

#### 1.3bis 🔴🔴 Aggravant — la translation M3 est **elle-même bloquée** quand les codeurs sont perdus

| Fait | Source |
|---|---|
| `M3_HeightInterlockOk := Bypass.MinHeight OR (HomedAndReliable M1 AND M2 AND CablePosM1 >= 6,0 AND CablePosM2 >= 6,0)` | `PRG_05_Translation.st:134-138` |
| Commentaire de conception : « **hauteur non confirmée = interlock actif** (comme une hauteur insuffisante), sauf bypass » | `PRG_05:128-130` |
| 🔒 **`Bypass.Global` ne lève PAS cet interlock** (considéré trop grave) — seul `Bypass.MinHeight` (dédié) le lève | `PRG_05:131-133` |
| Seuil `_TranslationMinHeightM1M2_M := 6.0` | `GVL_PERSISTENT.st:93` |
| Doctrine : « Interlock hauteur M3 strict `HomedAndReliable` M1∧M2 … ✅ conforme, **ne pas assouplir** » | `DECISIONS_T146_ARBITRAGE_ISO13849.md:100` |

> 🧨 **Chaîne de blocage complète après une perte de datum** (le cas même qui motive le homing) :
> ```
> codeurs NON HomedAndReliable
>   ⇒ M3 bloquée  (interlock hauteur, insensible à Bypass.Global)
>   ⇒ M3 jamais « stable à P1/Maintenance »
>   ⇒ WinchDescentAuth_M3 = FALSE  (T249-A)  ⇒ DESCENTE M1/M2 INTERDITE
>   ⇒ seule direction disponible : LA MONTÉE
>   ⇒ or le cycle G7 exige une descente (HX3) ⇒ HomeAxesTimedOut ⇒ HXF_FAILED
> ```
> ✅ **Conséquence majeure, favorable à l'intuition de l'utilisateur** : après une perte de datum, la seule
> ressource mécanique disponible est **la montée**. Un cycle de référencement qui **exige une descente** est
> donc **structurellement inadapté** à la situation qu'il est censé résoudre. C'est **l'argument le plus fort
> trouvé en faveur** d'un référencement « à la montée » — **plus fort que celui invoqué par l'utilisateur**
> (tension des câbles), et il n'apparaît **pas** dans l'état des lieux T336 Phase 1.
> 🎯 **Piste probable du « cycle buggué »** (T311/T336 §5.3) : cycle lancé hors `P1`/`Maintenance` ⇒ blocage en
> `HX3` ⇒ `HXF_FAILED`, sans que l'opérateur puisse repositionner M3 (bloquée elle aussi).
> ⚠️ **Exception** : si `Bypass.MinHeight` (ou un bypass de FdC M3) est armé, M3 redevient mobile ⇒ l'impasse
> est levée **par une dérogation tracée**, pas par le design.

---

## 2 · Q1 — Évaluer la SÉCURITÉ de référencer à la montée plutôt qu'à la descente

### 2.1 L'argument « câbles tendus à la montée = prévisible » — ce qu'il couvre et ce qu'il ne couvre pas

| Cas | Analyse | Verdict |
|---|---|---|
| **Câbles tendus à la montée** | ✅ **Vrai** : le poids de la benne + l'accélération ⇒ tension maximale. MAIS l'encodeur mesure **la rotation du tambour**, pas la longueur de câble (`FB_Encoder_Scale`, `CableM_PerRev = 2.0`). L'élasticité du câble n'entre **pas** dans la mesure ⇒ l'argument « tendu » **ne sécurise rien de plus** côté datum. | ⚠️ **Non discriminant** |
| **Montée « en aveugle »** | 🔴 **Elle existe déjà** dans le design actuel : `HX2_CLIMB` monte sans référence (`:476-488`). Les protections de position (butée logicielle + zone de ralentissement) sont **neutralisées** sans référence fiable — le code le dit noir sur blanc (`PRG_04:840-844`). Reste : palier 1 (§1.2) + capteur physique. | 🟠 **Risque existant, non créé par l'hypothèse** |
| **Charge dans la benne** | ⚠️ La charge **ne fausse pas la mesure** mais **allonge la distance d'arrêt** ⇒ **sur-course au-delà du capteur** d'autant plus grande que la charge est lourde. | 🟠 **Défavorable à la montée** (voir 2.2) |
| **Benne partiellement remplie / non assise** | 🔴 **Non détectable** : il n'existe **aucun** capteur d'état benne — `IsClosed`/`IsOpen` sont **dérivés de `Delta = M2 − M1`** comparé aux offsets calibrés (`FB_Bucket.st:419-436`). Une benne « visuellement fermée » mais non assise (débris entre les mâchoires) est **indiscernable** d'une benne assise. | 🔴 **Le « contrôle visuel » opérateur n'est pas une mesure** |
| **Glissement M1/M2 avant référencement** | 🔴 **Aucune détection possible**, et c'est un **trou documenté du projet** : « Il ne détecte **PAS** un glissement de M2 … **C'est le trou central de T175-01** », « **Aucun FB** ne produit le fait "M2 bouge sans consigne" » (`CADRAGE_T175-01_M2_SLIP_SAFETY.md:13, 43`). Aggravant : pendant le homing, la surveillance d'écart croisé est **coupée à la source** (`SyncOperationPermit := … AND NOT MachineHoming.Active`, `PRG_04:415-435`) ⇒ **MecaE inactif** pendant tout le cycle. Et comme **les deux axes reçoivent le même preset au même front**, une divergence réelle devient **invisible pour toujours** (les deux affichent 8.5). | 🔴 **Trou structurel, identique dans les 2 designs** |

> ⚠️ **Contrainte de conception à connaître avant toute parade** : « **AUCUN bit libre** dans `ErrorId` (WORD
> 16 bits) » ⇒ ajouter une surveillance « M2 bouge sans consigne » **impose d'élargir l'interface ou une sortie
> dédiée** (visa V5) — `CHALLENGE_T175-01_02_M2_BUCKET_SAFETY.md:15, 46, 143`. À intégrer au chiffrage de toute
> option qui prétendrait couvrir le glissement.

### 2.2 L'asymétrie réelle montée/descente — **l'inverse de l'intuition**

| Critère | Référencement à la **MONTÉE** (hypothèse) | Référencement à la **DESCENTE** (actuel) |
|---|---|---|
| Vitesse au moment du front | 🔴 **Croisière** en fin de montée — **palier 1** (0,4 m/s ⇒ 20 mm/50 ms) si la référence est perdue, **jusqu'à palier 5** (2,0 m/s ⇒ 100 mm/50 ms) si la référence est encore valide (§1.2bis) | ✅ **Rampe de démarrage** depuis un arrêt confirmé (`HX2N`) ⇒ quelques mm |
| Déplacement pendant les 50 ms de vérification | ≈ **20 mm** > tolérance **10 mm** ⇒ 🔴 **échec probable** | ≈ quelques mm ⇒ ✅ **passe** (c'est le seul mode qui « marche » aujourd'hui) |
| Direction **après** le front | 🔴 **Vers la barrière dure** : la machine est **au capteur**, en montée, à pleine charge ⇒ sur-course + **escalade Méca D** (`FB_Safety_Winch.st:372-387`, latché ⇒ **SafeStop + PowerCutOff** après `PostRampTimeout` si l'arrêt n'est pas confirmé au TOP) | ✅ **S'éloigne** de la barrière : `DescendPermit` **n'utilise jamais** le capteur TOP ni `TopLimitM` (`FB_Safety_Winch.st:563-572`) |
| Tension du câble | Maximale (poids + accélération) ⇒ arrêt le plus « dur » | Minimale (poids − décélération) ⇒ arrêt le plus doux |
| Fenêtre de neutralisation Méca D | ⚠️ `InReferencingMode` ne couvre que **50 ms** (`NOT InReferencingMode` dans `FB_Safety_Winch.st:378` + `Lifecycle.Busy := PresetVerificationActive`, `FB_Encoder_Homing.st:289`) — or la décélération palier 1 dure **plus longtemps** que 50 ms | Neutre (le capteur est déjà relâché) |
| Répétabilité du point | Front **montant** = point d'enclenchement du capteur | Front **descendant** = point de relâchement — **hystérésis différente** de quelques mm/cm, mais **aussi répétable** |

> 🎯 **Ce que l'hypothèse apporte réellement** (à sa décharge, honnêtement) : le front montant est le **nominal
> historique documenté** — « Front `Home` **ET front capteur haut** (capture au front, **pas après arrêt
> confirmé** — la vitesse d'accostage doit rester constante) » (`AF-09 v2.4:394`) et le contrat T226 décrivait
> « au **front montant** … les deux treuils sont stoppés immédiatement (**arrêt dur**) » (`TASK_CONTRACT_T226…:45, 158-160`).
> Le choix actuel (front descendant) est un **gel du 2026-09-03**, assumé pour la répétabilité.
> ⚠️ **Ironie à traiter** : AF-09 **exige** une « vitesse d'accostage **constante** » — précisément la condition
> que le front montant **ne peut pas garantir** (vitesse = croisière, dépendante du palier opérateur, de la
> charge et de la rampe), alors que le départ depuis l'arrêt en `HX2N` la garantit mieux.

### 2.3 Verdict Q1

**🔴 REJETER la forme « au vol au front montant » telle que décrite** (capture pendant la montée à vitesse de
croisière) : elle viole la contrainte de vérification preset (§1.1), place la capture **au pire instant
physique** (contre la barrière, à tension maximale, avec escalade Méca D possible), et **n'apporte aucune
garantie supplémentaire** sur les cas que l'utilisateur invoque (charge, benne partiellement remplie,
glissement M1/M2 — non détectables dans les **deux** designs).
**🟠 ACCEPTER MODIFIÉ** si l'objectif réel est de **s'affranchir de la descente HX3** (§1.3) : voir options
**§8-A** (capture sur front montant **machine arrêtée**) ou **§8-B** (conserver le front descendant et
supprimer la dépendance T249-A).

---

## 3 · Q2 — Comparaison : ce que chaque design gère (et ne gère pas)

| Question | Design **actuel** (descente, front descendant) | Hypothèse **utilisateur** (montée, front montant) |
|---|---|---|
| Capture du datum d'axe M1/M2 | ✅ au front capteur, **depuis un arrêt confirmé** (répétable, vérification preset crédible) | 🔴 au front capteur **en mouvement** ⇒ vérification preset 10 mm **non tenue** (§1.1) |
| **Exécutabilité hors P1/Maintenance** | 🔴 **NON** — `HX3` (descente) bloquée par T249-A + `M3Locked`, et **M3 elle-même bloquée** si les codeurs sont perdus (§1.3bis) ⇒ **impasse `HXF_FAILED`**, récupération **par la montée seulement** | ✅ **OUI** — plus de descente ⇒ **l'hypothèse corrige un défaut réel et bloquant** |
| Datum benne (état ouvert/fermé) | ✅ établi **après** le homing des axes, en `HX4`/`HX5`, machine **arrêtée** | 🔴 **non établi** — « confirmé visuellement » ≠ mesure (§2.1) |
| Capacité à **fermer** la benne pendant le homing | ✅ `HX4` le permet **parce que** les axes sont déjà homés : `EffectivePermitBucket_Open/Close` **exigent** `EncoderM1.Homed AND EncoderM2.Homed` (`PRG_04:1102-1111`) ⇒ **l'ordre HX3→HX4 est structurel** | ⚠️ l'hypothèse rend `HX4` inutile ⇒ **perte de la seule voie de fermeture** disponible quand la benne est ouverte et le datum perdu |
| État **indéterminé** au départ (datum perdu en pleine exploitation) | ✅ le cycle part de n'importe quel état (montée → front → descente → fermeture → commit) | 🔴 **exige** une prémisse « benne fermée » **avant** la montée — impossible à garantir si le datum est perdu et la benne ouverte |
| Interaction barrière dure / Méca D | ✅ front franchi **loin** de la barrière, en s'en éloignant | 🔴 front franchi **sur** la barrière, avec escalade latchée possible |
| Neutralité vis-à-vis du sync M1/M2 | ⚠️ écart croisé coupé pendant le homing (choix assumé, `PRG_04:391-405`) | ⚠️ **identique** |
| Conformité documentaire | ⚠️ **déviation** vs AF-09:394 (le nominal est le front capteur) — l'implémentation utilise le trigger **unitaire** (`UnitaryHomingTrigger`, `FB_Encoder_Homing.st:209`), pas le nominal | 🟢 **conforme** à AF-09:394 et à T226:45 |

> **Conclusion Q2** : ce n'est pas « l'un est sûr et l'autre pas ». Le design actuel **gagne sur la qualité de la
> capture** et **perd sur l'exécutabilité** (verrou translation). L'hypothèse **gagne sur l'exécutabilité** et
> **perd sur la capture** + sur l'établissement du datum benne. **Aucun des deux ne couvre** le glissement
> M1/M2 (§2.1, T175-01).

---

## 4 · Q3 — Cas dégradé : benne au sol, gueule ouverte, synchronisé, **sans translation**

### 4.1 « On peut monter n'importe où » — que dit réellement le code ?

| Fait | Source |
|---|---|
| ✅ **Aucune contrainte de position M3 ne conditionne la MONTÉE M1/M2** | `PRG_04:1079-1098`, `FB_Safety_Winch.st:574-582` |
| ❌ **Aucune notion d'obstacle / zone / collision** dans `CODE/` : grep `Obstacle` = **0 occurrence** ; pas de géométrie benne ↔ structure | relevé |
| ❌ `TremieFull_OR_GateRaised_DI` : **non câblé** (`AF-06:472`), consommé **uniquement** pour bloquer M3 **vers** la trémie — **aucun effet sur M1/M2** | `PRG_05:168-181` |
| ❌ **Aucune contrainte « M3 doit être à X pour MONTER »** dans AF-10/AF-11 | relevé |
| 🔴 **Mais la DESCENTE, elle, est contrainte** : T249-A (§1.3) | `PRG_03:457-468` · `PRG_04:1057-1074` |
| 🔴 Le cycle **gèle M3** ⇒ impossible de corriger | `FB_CycleMachineHoming.st:580-586` · `PRG_05:479-481` |

> 🎯 **Verdict factuel** : l'affirmation « on peut monter **n'importe où** » est **exacte pour la montée** — mais
> elle est **fausse pour le cycle G7 actuel**, qui contient obligatoirement une **descente** (`HX3`) interdite
> hors P1/Maintenance. **L'intuition de l'utilisateur est donc fondée, pour une raison qu'il n'a pas énoncée.**
> ⚠️ **En revanche, l'absence de contrainte dans le code ≠ absence de risque physique** : si un obstacle
> mécanique existe (benne ouverte plus large, mur de carrière, trémie, structure du ponton), **rien dans le
> code/AF ne l'exprime** ⇒ ce point **reste une validation humaine/mécanique**, pas une validation logicielle.

### 4.2 Le cas dégradé est **dangereux aujourd'hui**, indépendamment de l'hypothèse

| Fait | Source | Conséquence |
|---|---|---|
| En `HX4`, la validation pose `PendingClose := TRUE` **sans aucune condition d'état benne** | `FB_CycleMachineHoming.st:547-551` | 🔴 Le cycle **publie `CommitClose` même si la benne est restée OUVERTE** |
| `BucketCommit.CommitClose := PendingClose` puis `CommitPublished := TRUE` | `FB_CycleMachineHoming.st:553-561` | 🔴 Datum **faux** (« benne fermée » alors qu'elle est ouverte) |
| `FB_CycleMachineHoming` **ne reçoit AUCUNE entrée d'état benne** (`VAR_INPUT :15-52` — seule `BucketOffsetValid` en lecture) | `FB_CycleMachineHoming.st:15-52` | 🔴 Aucune garde possible dans l'état actuel |
| `M2_LimitShift := instBucket.ActiveOffsetM` alimente la butée M2 | `PRG_04:824, 875-877` | 🔴 Un offset faux de 15 m **décale la limite haute réelle de M2** |
| L'état benne est **dérivé** : `IsClosed := \|Delta − OffsetCloseM\| <= CoherenceLimitM` | `FB_Bucket.st:419-436` (Coh = 1.0 m, `GVL_PERSISTENT.st:70`) | 🔴 Le commit est **écrasé au scan suivant** par la classification continue dès que `ClassCanRun` |
| RES-004 : « Une variante "benne ouverte" … **n'est plus implémentée** … **Non tranché — ne pas décider ici** » | `AF-09 v2.4:461-467, 633-636` | ⚠️ Le cas dégradé **n'a pas de représentation** dans le cycle actuel |

> ⚠️ **Bonne nouvelle partielle** : avec une benne **non fermée**, la montée est **plafonnée au palier 1**
> (`BucketNotClosedAscentCapStep1`, `PRG_04:386-389` + `:1243-1245`) — le cas dégradé est donc **le plus lent**,
> ce qui est favorable. ⚠️ Mais ce garde-fou repose sur `NOT _BucketState.IsClosed`, donc sur la
> **classification positionnelle** : si le datum est perdu, `IsClosed` est forcé `FALSE` (`FB_Bucket.st:443-444`)
> ⇒ le plafond s'applique bien (favorable), **mais par accident** (état inconnu classé « pas fermé »).

### 4.3 Verdict Q3

**🟠 ACCEPTER MODIFIÉ**, sous **3 conditions cumulatives** :
1. **Aucune publication de `CommitClose`** en cas de benne ouverte : soit `CommitOpen` (à implémenter — aujourd'hui
   `HX5` ne connaît que `CommitClose`), soit **pas de commit** (voir §5 pour la conséquence sur `MachineHomed`).
2. **Débloquer la descente** : soit M3 effectivement positionnée à **P1/Maintenance avant** le cycle (donc
   *la translation n'est **pas** facultative pour la route actuelle* — elle l'est seulement pour la route
   « référencement à la montée »), soit découpler l'accès `T249-A` du cycle — **décision humaine C4**.
3. **Valider mécaniquement** « monter n'importe où » (obstacle benne ouverte ↔ structure) : **le code ne peut pas
   répondre**, et il ne l'exprime pas.

---

## 5 · Q4 — « Une fois référencé à la montée, HX4/HX5 deviennent no-op » : simplification ou dette ?

### 5.1 Pourquoi c'est **faux** : ce n'est pas le même datum

| Fait | Source |
|---|---|
| Le datum **axe** vient du capteur haut (`CfgTopSensorPosM` écrit sur les 2 codeurs) | `FB_Encoder_Homing.st:216-236` · `PRG_02:607-611, 661-665` |
| Le datum **benne** est **géométrique** : `Delta = M2 − M1` comparé à `OffsetCloseM` / `OffsetOpenM` | `FB_Bucket.st:419-436` · `ST_fbBucket_State.st:9-17` |
| Les offsets sont calibrés/confirmés **quand M1 **ET** M2 sont fiables** : `IF BucketRefRequest AND … HomedAndReliableM1 AND HomedAndReliableM2 THEN BucketReferenced := TRUE` | `FB_Bucket.st:382-398` |
| La commande benne (ouvrir/fermer) **exige** que les deux axes soient référencés | `PRG_04:1102-1111` |
| Un offset n'est utilisable en conduite nominale que **si `HomedAndReliable` + état visuel committé après homing conjoint** | `AF_Partie-10…:468` (note T184) |

> 🎯 **Le référencement à la montée ne référence QUE les axes.** La « benne référencée au franchissement »
> n'est possible que si l'opérateur a **déjà** confirmé un état (`BtnConfirmClosePos`) — or cette confirmation
> **ne survit pas** à l'absence de référence : `IF ClassCanRun THEN … ELSE IsClosed := FALSE; IsOpen := FALSE`
> (`FB_Bucket.st:428-448`) — tant que `HomedM1/HomedM2` sont faux, l'état est **écrasé à « inconnu »**.

### 5.2 Le piège mécanique : « no-op » **casse la qualification `MachineHomed`**

| Fait | Source | Conséquence |
|---|---|---|
| `HX1` efface le commit à l'entrée du cycle : `CommitPublished := FALSE` | `FB_CycleMachineHoming.st:464-466` | Le commit précédent est **perdu** dès qu'on relance un homing |
| `MachineHomed := BothAxesHomed AND (CommitPublished OR BucketOffsetValid) AND …` | `FB_CycleMachineHoming.st:594-596` | 🔴 Si `HX5` devient no-op, la qualification repose **entièrement** sur `BucketOffsetValid` |
| `BucketReferenced` **retombe** si `HomingSuspect` persiste ≥ 2 s | `FB_Bucket.st:400-410` | 🔴 …et `HomingSuspect` est **précisément** la cause typique du re-homing ⇒ `BucketOffsetValid` souvent faux |
| ⇒ cycle terminé, **axes référencés**, mais `MachineHomed = FALSE` | chaîne ci-dessus | 🔴 **SEMI_AUTO reste bloqué** : le cycle « réussit » et la machine reste inutilisable |

**Autres coûts du no-op** :
- 🔴 **Code mort actif** : `HX4`/`HX5` restent dans le CASE, alimentent le **guide opérateur** (`§10`, `:631-637` :
  « HX4 - RefHoming **Fermer benne puis valider** ») ⇒ **l'IHM demanderait un geste qui ne fait plus rien**.
- 🔴 **Le datum réel resterait celui de la descente** : si `HomeReq` n'est pas retiré de `HX3` (`:511-515`), le
  référencement de la montée est **écrasé** par celui de la descente (même valeur `8.5`, donc sans effet
  numérique — mais la « simplification » n'en est plus une, et la dépendance T249-A **demeure**).
- 🔴 **Contrats** : `T185 AC3` (commit atomique après les deux homings), `T185 AC10/AC11` (choix ouvert/fermé),
  `T260 AC7` + `must_survive` (« **HX2..HXF, HX4_BUCKET_ADJUST, commit benne HX5** … **inchangés** »)
  ⇒ le no-op **casse des critères d'acceptation existants** (dont un contrat **C4 APPROVED**).

### 5.3 Verdict Q4

**🔴 REJETER le no-op.** Ce n'est pas une simplification, c'est **du code mort qui conserve un guide opérateur
actif et une qualification cassée**. 🟢 **Alternative honnête** : **fusionner `HX4`+`HX5` en une seule étape
« confirmation explicite de l'état benne »** (geste unique, sans jog obligatoire) — cela **réutiliserait** la
route existante `ConfirmOpenPosition`/`ConfirmClosePosition` (`FB_Bucket.st:339-357`) et **résoudrait RES-004**
en donnant enfin le choix ouvert/fermé. **Effort M**, **contrat à réécrire** (T185/T260).

---

## 6 · Q5 — Conflit AF-09 (cible dynamique M2 forcée à FALSE)

### 6.1 Le conflit, tel qu'il est codé

| Source | Affirmation | Réalité |
|---|---|---|
| `AF-09 v2.4:359, 429-436, 459` | cible dynamique M2 active = `M1 ± OffsetCloseM`, « M2 reçoit sa **PROPRE** cible … **jamais** la config M1 » ; les 2 homings **committés atomiquement** | ⚠️ **Contredit** par M2 = miroir M1 (`PRG_07:154-155`) **et** par `UseDynamicTarget := FALSE` en dur |
| `FB_CycleMachineHoming.st:412-420` | « M1 et M2 montent liés au même capteur haut → **M2 se référence à la MÊME position que M1** … Cible dynamique (top + offset ~23 m) **supprimée** : elle créait un écart apparent M1/M2 de ~15 m au preset → **`FB_WinchSync` SafeStop → `Fault.Latched`** » | ✅ **c'est le code**, et le motif est un **REX de sécurité** |
| `T198 AC3` / `T199 alert_duty` | référencement dynamique M2 **prioritaire** ; « toute **cible M2 non dérivée de M1 et de l'état ouvert/fermé choisi** impose l'arrêt de la livraison » | ⚠️ **non satisfait** par l'état actuel |
| `RES-004` | variante « benne ouverte » **non implémentée**, **non tranchée** | ⚠️ ouverte |
| 🔴 `T199` **alert_duty** | « Toute confirmation benne qui rehome M1, ou **toute cible M2 non dérivée de M1 et de l'état ouvert/fermé choisi**, impose l'**arrêt de la livraison** » | 🚨 **déjà violé** par `UseDynamicTarget := FALSE` ⇒ **tout lot touchant la cible M2 doit passer ce gate** |
| 🔴 `T198` **alert_duty** | « Toute cible de preset **différente de la cote explicitement choisie par l'opérateur** est un **risque de positionnement** » | 🚨 toute variante « cible dynamique » doit être justifiée contre ce gate |
| ⚠️ Pointeur documentaire **périmé** | `FB_CycleMachineHoming.st:431` renvoie à « AF-09 (**F09.08** — cycle de homing machine) », alors qu'en v2.4 **F09.08 = « centrer le compteur au référencement »** (`AF-09:148-156`) | ⇒ **AF-09 n'est PAS la source de vérité du GRAFCET** : la carte des étapes fait foi dans `GEL_GRAFCET_HOMING_CYCLE_20260903.md` + la fiche T336 |

> 📌 **Corollaire méthodologique** : toute évolution du cycle doit se référer au **GEL 2026-09-03** (carte des
> étapes) **et** aux contrats T185/T198/T199/T226/T260 (exigences), **pas** à AF-09 §F09.08 qui ne décrit plus
> ce cycle. Le pointeur du code (`:431`) est à corriger (livrable documentaire `fix:`, hors T336).

### 6.2 🔴 Conséquence **structurelle** — l'hypothèse **atterrit en plein sur le conflit**

> **Fait établi par le code** : les deux axes reçoivent **le même preset, au même scan** (`M1Demand.HomeReq` et
> `M2Demand.HomeReq` émis ensemble, `:511-515`, sans cible dynamique) ⇒ **juste après le homing, `Delta = M2 − M1 = 0`**.
> Or `OffsetOpenM := 0.0` (`GVL_PERSISTENT.st:66`) et `CoherenceLimitM := 1.0` (`:70`) ⇒
> `NearOpen := |0 − 0.0| <= 1.0` ⇒ **`IsOpen := TRUE`, `IsClosed := FALSE`** (`FB_Bucket.st:419-436`).
> ⇒ **la machine homée est déclarée « benne OUVERTE »**, alors que `HX5` vient de publier `CommitClose`.
> ⚠️ Cette inférence est **à confirmer par trace** (elle dépend de `OffsetOpenM` réellement en NVRAM et de la
> cinématique de mouflage), mais elle est **directement déductible du code** et expliquerait une partie du
> « cycle actuellement buggué » (T336 §5.3).

**Conséquences pour l'hypothèse** :

| Variante de l'hypothèse | Ce qu'elle exige réellement | Risque |
|---|---|---|
| « M1/M2/**benne fermée** référencés au même franchissement » | Soit **cible dynamique** M2 = top + `OffsetCloseM` ⇒ 🔴 **réintroduit la régression documentée** (SafeStop synchro latché) ; soit **valeurs égales** ⇒ `Delta = 0` ⇒ 🔴 **classé « benne ouverte »** | 🔴 **Incohérent dans les deux branches** |
| « benne fermée confirmée visuellement » | Confirmation **opérateur** = `BucketRefRequest` ⇒ `BucketReferenced` **seulement quand M1&M2 fiables** (`FB_Bucket.st:394-398`) | 🟠 **Faisable** mais ne remplace pas le commit ; et le contrôle visuel n'est pas une mesure |

### 6.3 Verdict Q5

**⚠️ PRÉALABLE BLOQUANT.** L'hypothèse **ne contourne pas** AF-09 : elle **impose** de trancher, dans l'ordre :
1. **RES-004** — le cycle référence-t-il « fermée », « ouverte », ou **les deux au choix** (T185 AC11) ?
2. **Doctrine cible M2** — valeur commune (⇒ `Delta = 0` ⇒ « ouverte ») **ou** cible dynamique (⇒ REX synchro) ?
3. **Qui porte le datum benne** — commit `HX5` (à conserver/fusionner) ou confirmation séparée `T199` ?
**Aucune ligne de `CODE/` ne doit être écrite avant ces 3 arbitrages** (le §6.2 montre qu'on tombe sinon dans un
état **incohérent par construction**).

---

## 7 · Synthèse des verdicts

| # | Sous-point | Verdict | Argument décisif | Source |
|---|---|---|---|---|
| 1 | Référencer **au vol au front montant** | 🔴 **REJETER** tel quel · 🟠 MODIFIÉ possible | 10 mm / 50 ms ⇒ échec probable **et** capture au pire instant physique | `FB_Encoder_Homing.st:109-110, 241-249` |
| 2 | Design actuel (descente) supérieur en sécurité | 🟢 **OUI pour la capture** · 🔴🔴 **NON pour l'exécutabilité** | `HX3` bloquée par T249-A + `M3Locked` **et M3 bloquée** si codeurs perdus ⇒ **récupération par la MONTÉE seulement** | `PRG_03:457-468` · `PRG_05:134-138` · `FB_CycleMachineHoming.st:580-586` |
| 3 | Cas dégradé sans translation | 🟠 **ACCEPTER MODIFIÉ** (3 conditions) | montée libre ✅ / descente bridée 🔴 / commit faux 🔴 | `PRG_04:1057-1074` · `FB_CycleMachineHoming.st:547-561` |
| 4 | HX4/HX5 no-op | 🔴 **REJETER** · 🟢 fusionner | qualification `MachineHomed` cassée + code mort actif | `:464-466` vs `:594` · `:631-637` |
| 5 | Conflit AF-09 | ⚠️ **PRÉALABLE BLOQUANT** | `Delta = 0` classé « ouverte » vs cible dynamique = REX | `GVL_PERSISTENT.st:66` · `FB_Bucket.st:419-436` · `:412-420` |
| 6 | Risque propre à la montée « en aveugle » | 🟠 **RÉEL, identique aux 2 designs** | protections de position inertes ; glissement M2 **indétectable** (trou T175-01) | `PRG_04:840-844` · `CADRAGE_T175-01:13, 43` |

---

## 8 · Options proposées (risques / efforts) — **aucune n'est tranchée ici**

> Rappel de posture : je propose, je ne décide pas. Chaque option est chiffrée en effort (`S` < 1 j, `M` 1-3 j,
> `L` > 3 j de travail agent, **hors campagne de mesure**) et en risque résiduel.

### 🅰 Option A — « Front montant **machine arrêtée** » (référencement à l'arrêt au capteur, pas au vol)

Principe : `HX2` monte **jusqu'au capteur** (comme aujourd'hui), **s'arrête**, puis émet `HomeReq` **à l'arrêt**
— la capture n'est plus « au vol » mais **après arrêt confirmé**.

| | |
|---|---|
| ✅ Avantages | Supprime la contrainte 10 mm/50 ms (vitesse nulle) ; supprime la descente `HX3` ⇒ **supprime la dépendance T249-A** ; supprime l'escalade Méca D en mouvement |
| 🔴 Risques | **Le datum n'est plus au front du capteur mais à la position d'arrêt** = front **+ sur-course** (variable : vitesse, charge, rampe) ⇒ **répétabilité dégradée de plusieurs cm** ; contredit AF-09:394 (« capture **au front**, pas après arrêt confirmé ») ; **T235** rappelle que la vérification preset après délai est « transactionnelle » et fragile |
| 🎯 Condition de validité | **Campagne de mesure obligatoire** : sur-course d'arrêt au palier 1 (charge pleine / à vide / benne ouverte) — non instrumentée aujourd'hui (T330 P7) |
| Effort | **M** (code) + **campagne de mesure** |
| Verdict | 🟠 **ACCEPTABLE seulement si la dispersion mesurée est compatible** avec `ReserveTop ≥ 1,00 m` (décision humaine T330 Q1) |

### 🅱 Option B — **Conserver le front descendant** et **supprimer la dépendance T249-A** dans le cycle

Principe : garder la doctrine actuelle (capture répétable à basse vitesse) et **rendre le cycle exécutable
partout** : soit `WinchDescentAuth_M3` n'est **pas** appliqué pendant le cycle de homing (exemption encadrée),
soit le cycle ne gèle plus M3 tant que `HX3` n'est pas atteint.

| | |
|---|---|
| ✅ Avantages | **Aucun changement de datum** (zéro régression métrologique) ; corrige le **vrai** défaut (impasse `HXF` hors P1/Maintenance) ; effort faible ; compatible avec les contrats T185/T260 |
| 🔴 Risques | 🚨 **Exemption d'un verrou de sécurité** (T249-A est là pour éviter de payer du câble avec le pont en transit) ⇒ **exige une analyse Safety + visa humain C4** ; risque de **payer du câble** au-dessus d'une zone non prévue |
| 🎯 Cadre | Exemption **uniquement** sous `MachineHomingActive AND MAINT_N2` + arrêt mécanique confirmé + palier 1 imposé (déjà garanti, §1.2) + traçabilité IHM (précédent de dérogation tracée : `PRG_04:830-833`) |
| 🚫 **Ne pas confondre 2 interlocks** | **(a) T249-A** = descente treuil interdite hors P1/Maint. (`PRG_03:457-468`) — **c'est celui-ci qu'on viserait** ; **(b) interlock hauteur M3** = M3 bloquée si câbles < 6 m ou codeurs non fiables (`PRG_05:134-138`) — ⛔ **« ne pas assouplir »** (`DECISIONS_T146:100`), **hors périmètre de l'option B**. L'option B **n'exempte que (a)** : c'est suffisant pour `HX3` (l'interlock (b) bloque **M3**, pas la descente des treuils) |
| ⚠️ Limite résiduelle | Si `HX3` doit descendre **profondément** (ce n'est **pas** le cas : quelques cm sous le capteur, `:498-522`), d'autres permis interviendraient (`CfgCableLimitDescent_M`, `LimitLegalReached`). À vérifier **si** une variante élargit la descente |
| 🎯 Bonus | Corrige aussi l'impasse **côté M3** : le cycle ne gèle plus M3 **avant** `HX2` (`:580-586`) ⇒ l'opérateur peut repositionner le pont **avant** d'engager le cycle |
| Effort | **S** (code) + **analyse Safety** |
| Verdict | 🟢 **LE MOINS RISQUÉ techniquement** — mais touche un interlock de sécurité : **décision humaine obligatoire** |

### 🅲 Option C — **Front montant avec refonte de la transaction preset** (l'hypothèse utilisateur, rendue viable)

Principe : implémenter le front **montant** (donc conforme AF-09:394) **et** adapter `FB_Encoder_Homing` :
nouveau mode de confirmation compatible avec une capture en mouvement (tolérance **proportionnelle à la vitesse
mesurée**, fenêtre de vérification **raccourcie/alignée front**, ou validation par le bit de statut du codeur).

| | |
|---|---|
| ✅ Avantages | Supprime la descente `HX3` **et** la dépendance T249-A ; **conforme au nominal AF-09 + T226** ; capture **au front** (répétable, pas de sur-course dans le datum) |
| 🔴 Risques | **Refonte d'une transaction de sécurité** (T235 : « suppression du délai sans refonte risquait une validation erronée ») ; **élargir une tolérance = affaiblir la vérification** ⇒ **arbitrage C4** ; ne résout **rien** du datum benne (Q5 reste bloquant) ; interaction Méca D au TOP (fenêtre `InReferencingMode` 50 ms < temps de décélération) à re-qualifier |
| Effort | **L** (code + specs AF-09/AF-10 + campagne de mesure + gates) |
| Verdict | 🟠 **Faisable mais c'est un projet, pas une simplification** — et **subordonné** à l'arbitrage §6.3 |

### 🅳 Option D (transverse) — **Mesurer avant de décider** (recommandée, quelle que soit l'option)

Instrumenter une campagne de trace (T311 est déjà ouverte exactement pour ça : « reproduction réelle ou SimBench
et **cause exacte** du bug homing avant toute correction », `TASK_CONTRACT_T311…:6-23`) :

| Grandeur à tracer | Pourquoi |
|---|---|
| `CablePosM1/M2` + vitesse signée **au front** `TopPositionActive` (montée **et** descente) | Trancher §1.1 (10 mm vs vitesse réelle) |
| Sur-course d'arrêt au palier 1 (front → arrêt mécanique) | Trancher l'Option A (T330 P7) |
| `M3.AtP1` / `M3.AtMaintenance` au lancement du cycle | Confirmer l'impasse T249-A (§1.3) |
| `Delta = M2 − M1` après `HX3` + `IsClosed/IsOpen` après `HX5` | **Trancher §6.2** (incohérence commit/classification) |
| `PresetConfirmationFailed` / `HomingSuspect` / `MachineHomingSeqStep` | Expliquer le « cycle buggué » (T336 §5.3) |
| Effort | **S** (outil de trace) + **campagne terrain** |

---

## 9 · Questions à trancher par l'humain (aucune réponse décidée ici)

| # | Question | Bloque |
|---|---|---|
| **Q-A** | Le cycle doit-il référencer **fermée**, **ouverte**, ou **au choix opérateur** (RES-004) ? | Q5 + toute implémentation |
| **Q-B** | Doctrine cible M2 : **valeur commune** (⇒ `Delta = 0` ⇒ « ouverte ») ou **cible dynamique** (⇒ REX synchro à re-qualifier) ? | Q5 |
| **Q-C** | Peut-on **exempter T249-A** pendant le cycle de homing (Option B), et sous quelles gardes ? | Q3 + sécurité |
| **Q-D** | Accepte-t-on de **dégrader la répétabilité du datum** (Option A, sur-course variable) au profit d'un cycle exécutable partout ? | Q1/Q2 |
| **Q-E** | Sur le site : **la benne est-elle visible** de la cabine pendant le homing (hors d'eau) ? Un « contrôle visuel » est-il réellement praticable ? | Q1/Q4 |
| **Q-F** | Existe-t-il un **obstacle mécanique réel** à la montée M1/M2 selon la position de M3 (mur de carrière, trémie, structure du ponton) ? | Q3 (le code ne l'exprime pas) |
| **Q-G** | Le projet accepte-t-il **2 datums différents** (axe = capteur, benne = confirmation) explicitement documentés, ou veut-on un datum unique ? | Q4 |

---

## 10 · Contrôle de périmètre

| Élément | État |
|---|---|
| Fichiers `CODE/` écrits par T336 Phase 2 | ❌ **AUCUN** |
| Fichiers `CODE/` modifiés **préexistants** (hors périmètre de ce lot, non touchés) | `FB_CycleSemiAuto.st`, `FB_Hmi_BannerFormatter.st`, `PRG_02_Acquisition.st`, `PRG_07_Supervision.st` + `CODE_XML/` + divers `DOC/`/`TOOLS/` — **état antérieur**, non modifié par ce lot |
| Commit / push / revert / suppression | ❌ **AUCUN** |
| Livrable écrit | ✅ `DOC/WFLOW/AUDITS/DESIGN/CHALLENGE_T336_HOMING_HYPOTHESE_MONTEE_2026-09-20.md` |
| Sous-agents | 2 analyses déléguées, **lecture seule**, aucun fichier écrit |

> 🧭 **Ce livrable n'est pas une décision.** Les verdicts §2→§7 sont des **évaluations techniques sourcées** ;
> toute implémentation reste **subordonnée** : (1) à l'arbitrage RES-004 / cible M2 (§6.3), (2) à la campagne de
> mesure (§8-D), (3) à un contrat C3/C4 et à une validation humaine explicite (AGENTS.md).
