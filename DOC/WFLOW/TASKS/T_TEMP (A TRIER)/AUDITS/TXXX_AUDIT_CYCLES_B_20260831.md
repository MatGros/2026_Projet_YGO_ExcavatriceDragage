# 🔁 Contre-audit indépendant — Cycles de dragage (`CYCLES_AUDIT_B`)

**Date** : 2026-08-31 · **Périmètre** : `FB_Cycle`, `FB_DiveSearch`, `FB_ExtractionAssist`,
`FB_MachineHomingCycle` + DUT, `PRG_03_Modes_Cycle`
**Référentiels** : `AF_Partie-04 v2.3`, `AF_Partie-05 v2.1`, `GUIDE_SEQUENCEUR v1.2`,
`CODE_QUALITY_STANDARDS`
**Posture** : contre-audit — relit les mêmes sources, cherche les **angles morts** de l'audit A,
challenge ses conclusions, évalue l'**impact safety réel**. Aucun audit A pré-existant trouvé dans
`DOC/WFLOW/AUDITS/` au moment de la rédaction (le fichier n'existe pas encore → ce contre-audit
déjà en posture autonome).

---

## 🧭 Synthèse générale (à lire en premier)

| # | Gravité | Verdict |
|---|---|---|
| 1 | 🟥 **HIGH / Safety** | Contournement d'un défaut latché non acquitté via `Abort` + `Start` (`FB_Cycle` X0). |
| 2 | 🟥 **HIGH / Doc+Safety** | Reprise après bascule de mode **sans** reprise consciente : `WaitingResume` est du code mort ; la doc AF-04 §4.1 n'est **pas** respectée. |
| 3 | 🟠 **MED / Robustesse** | `FB_Cycle` **duplique** la logique Diving/Extraction au lieu de réutiliser `FB_DiveSearch`/`FB_ExtractionAssist` (réutilisation sur-communiquée par AF-04). |
| 4 | 🟠 **MED / Robustesse** | Asymétrie X8 : la transition vers X9 avance sur **M1 seul** (X5 et X7 vérifient M1 **et** M2). |
| 5 | 🟠 **MED / Maintain** | Gate de repli homme-mort §4 référence **un seul** permis (`ProcessPermitM1_Ascending`) pour neutraliser tous les actionneurs. |
| 6 | 🟡 **LOW / Coherence** | `SelTarget=2` (P2) annoncé dans l'interface mais **non géré** → cul-de-sac → défaut StepMax après 60 s. |
| 7 | 🟡 **LOW / Coherence** | Sections **périmées** dans AF-04 / AF-05 / GUIDE_SEQUENCEUR (détail ci-dessous). |

> Ce qui est **sain** et que l'audit A peut confirmer sans réserve : homme-mort continu bien gaté sur
> chaque commande (`ProcessPermit*`), repli `STABILIZING` sur front `Fault.Error`, `StepAtFault`
> capturé avant bascule (D2 conforme R9), accumulateurs anti-pompage homme-mort, coupure même-scan
> des sorties `[ACT]` sur entrée `[SAFE]` (H1/H2), et le datum machine `FB_MachineHomingCycle` avec
> re-homing conscient C-1 (aucun redémarrage auto). Ces points sont bien implémentés.

---

## ✅ Ce que l'audit A peut valider (fondations solides)

- **Gate continu homme-mort** (`FB_Cycle.st:259-266` puis §4 `:655-662`) : toute commande
  d'actionneur chute dès la perte du permis opérateur, **chaque scan** — conforme D2.
- **Repli défaut** : `ErrorEdge → STABILIZING` et `CycleStepAtError := State` **avant** la bascule
  (`:275-278`) — conforme GUIDE_SEQUENCEUR R9 / §7.
- **Acquittement sur front** : `ResetEdge` (R_TRIG) partout. Pas de réarmement par niveau.
- **Anti-pompage homme-mort** : accumulateurs de temps `+= CycleTime` sous `MotionRequestActive AND
  direction` uniquement (`DiveSearch:99-107`, `ExtractionAssist:118-130`).
- **Coupure même-scan** H2 : `BucketCloseRequest := AssistPermit AND NOT BucketError` ; `AscentPermit
  AND AscentControlSafe/AscentNominalSafe`.
- **Datum machine** : `FB_MachineHomingCycle` — perte de datum en mouvement → `SafeStop`
  (`HommingLossSafeStop`) **et** re-homing conscient requis (`ReHomingAckRequired`, C-1). Confirmé
  par la boucle de test `test_fb_machinehomingcycle.st` (C-1 `:230`). `PRG_02` câble correctement
  `Data.MachineHoming` → consommé par `FB_Modes` et `PRG_04`.

---

## 🟥 1 — HIGH / Safety : défaut latché contourné par `Abort` + `Start`

**Fait (vérifié)**
- `:280-285` `ResetEdge` ramène `STABILIZING → X0` **et** acquitte le socle (`instFault(Reset)`).
- `:288-292` `AbortEdge` ramène à `X0` **sans toucher au socle défaut** → `Fault.Latched` reste **TRUE**.
- `:324` transition `X0→X1` : `IF (StartEdge.Q OR DeadmanArmedEdge.Q) AND NOT Fault.Error`.
  Elle teste `Fault.Error` (**live**) et **pas** `Fault.Latched`.

**Chemin fautif**
1. Cycle en cours → défaut → `STABILIZING`, `Fault.Latched := TRUE`.
2. Cause disparue → `Fault.Error` redevient `FALSE` (le latch reste).
3. Opérateur appuie **Abort** (`BtnAbort`) au lieu de **Reset** (ex. pour « abandonner le cycle ») :
   `State := X0`, latch conservé.
4. En X0, un **Start** (`BtnStart`) ou l'armement homme-mort satisfait `NOT Fault.Error` → `X1`,
   le cycle **redémarre avec un défaut latché jamais acquitté**.

**Impact réel** : viole la règle non négociable « jamais de redémarrage automatique après défaut » et
la doctrine « `Reset` = front » (cause disparue **+** appui conscient). Ici, l'abandon remplace
l'acquittement ; une cause latente (ex. limite légale, synchro) peut repartir en mouvement sans
validation consciente du défaut.

**Correctif proposé** : transition X0 sur `NOT Fault.Latched` (ou `Ready := Enable AND NOT
Fault.Latched` en gate), et optionnellement faire que `AbortEdge` exige aussi un Reset si
`Fault.Latched`.

> 🎯 Angle mort probable de l'audit A : il vérifie « Reset = front » et « pas de reprise auto en
> STABILIZING », mais pas le **couplage Abort × latched fault × Start**.

---

## 🟥 2 — HIGH / Doc+Safety : `WaitingResume` = code mort, reprise sans geste conscient

**Fait (vérifié)**
- `:121` `WaitingResume`, `:229-232` mémorise `PausedState`/`WaitingResume` à la sortie de mode.
- `:269-272` le bloc `IF EnableEdge.Q AND WaitingResume THEN ;` est **vide** (commentaire seul).
- `:304+` le CASE exécute l'état mémorisé **directement** : `:418` X4 re-écrit
  `WinchM1Cmd.ReqStartStop := ProcessPermitM1_Descending` dès le retour.

**Fait** : à la bascule Maintenance→SemiAuto, `State` reste à l'étape intermédiaire (ex. X4) —
la porte §2 ne le ramène **pas** à X0 (seul `STABILIZING` est renvoyé à X0 par `ResetEdge`).

**Conséquence** : si l'opérateur ré-engage le manche + homme-mort à la reprise, le cycle
**reprend immédiatement à l'étape mémorisée**, sans le `BtnStart`/armement exigé par
`AF_Partie-04 §4.1` (« Un appui volontaire sur BtnStart ou armement homme-mort est exigé pour
reprendre le cycle »). Le seul gate restant est la présence opérateur continue (manche+deadman) —
moins strict que la doc.

**Impact** : non-conformité doc↔code documentée **et** affaiblissement du « geste conscient de
reprise » en cas de toggle de mode en pleine plongée/remontée. La présence opérateur reste exigée,
donc impact safety réel **modéré** — mais c'est exactement le type de drift qu'un contre-audit doit
signaler.

**Correctif** : rendre `WaitingResume` réel — au retour, forcer le passage par X0 (ou un état
PAUSE dédié) et n'autoriser la suite que sur `StartCycle` explicite.

---

## 🟠 3 — MED : duplication Diving/Extraction dans `FB_Cycle`

**Fait (vérifié, `PRG_03:163-167` et `:173-176`)**
- `instDiveSearch.Enable := (Mode=N1 OR N2) AND TglEnableDiveSearch`
- `instExtractionAssist.Enable := (Mode=N1 OR N2) AND TglEnableExtractionSequence`
- ⇒ en **SEMI_AUTO**, les deux assistants sont **désactivés** ; `FB_Cycle` **réimplémente** la
  plongée Kobold (X4) et la fermeture/remontée (X5-X8) en dur.

**Constat** : `AF_Partie-04 §2` (« Diving et Extraction… **réutilisés** par le cycle semi-auto »)
et §8 sur-communiquent la réutilisation. Il y a **deux** moteurs de la même logique : `FB_Cycle`
(cycle) et `FB_DiveSearch`/`FB_ExtractionAssist` (maintenance). Risque réel de **divergence** lors
de futurs réglages (seuils, timeouts, paliers).

**Impact** : pas une faille safety immédiate, mais un coût de maintenance élevé et un risque
d'écart de comportement SemiAuto vs Maintenance. Doit être assumé **ou** documenté comme « cycle
réutilise la brique » seulement au niveau des sorties publiées sur `Data.ReqProgram`.

> 🎯 Si l'audit A traite chaque FB isolément, il ne verra **pas** ce doublon inter-FB.

---

## 🟠 4 — MED : asymétrie X8 (avance sur M1 seul)

**Fait (vérifié)**
- **X5** `:459` : `... AND (M1 >= RaiseTargetM) AND (M2 >= RaiseTargetM)` → **les deux axes**.
- **X7** `:506-509` : `M1>=... AND M2>=... AND ABS(M1-M2)<=tolerance` → **les deux axes** + écart.
- **X8** `:532` : `IF CycleMotionPermit AND M1_CablePosM >= CableLimitM1AscentM` → **M1 seul**.

**Conséquence** : la remontée en charge avance vers X9 (égouttage) puis X10 (translation vers
trémie) dès que **M1** atteint la limite haute, même si **M2** est en retard dans la tolérance de
synchro (≤0,50 m critique). Le godet peut être légèrement de travers / moins haut que prévu quand
le cycle passe au vidage ; le seul garde-fou est le défaut synchro aval (`PRG_04 WInchSyncError`).

**Impact** : défaut de robustesse / marge de conception, pas une casse directe (synchro aval
sécurise). Mais l'incohérence X5/X7 (2 axes) vs X8 (1 axe) doit être **justifiée ou corrigée** :
soit ajouter `M2_CablePosM >= CableLimitM1AscentM` à la transition X8, soit documenter pourquoi
M1 est l'axe maître.

---

## 🟠 5 — MED / maintain : gate §4 sur un seul permis

**Fait** : `FB_Cycle:655` `IF Lifecycle.Busy AND NOT ProcessPermitM1_Ascending` neutralise
WinchM1, **WinchM2**, Translation et Bucket (Open/Close/Kobold). Or **tous** les
`ProcessPermit*` sont aujourd'hui identiques (`CycleMotionPermit AND DeadmanArmed`, `:259-266`).

**Impact** : fonctionnellement **équivalent aujourd'hui**, mais le gate référence un seul permis
comme canonique. Si un permis diverge un jour (ex. `M2_Descending` avec une condition propre),
le repli §4 neutralisera à tort ou à raison selon M1-only. Fragilité de conception, à fiabiliser :
tester la somme `NOT (M1_Desc OR M2_Desc OR Bucket_Open ...)` ou neutraliser chaque commande par
son propre permis. **Robustesse > optimisation.**

---

## 🟡 6 — LOW : `SelTarget=2` (P2) = cul-de-sac

**Fait**
- Interface `:26` : `1=Tremie, 2=P2, 3=P1, 4=Maintenance`.
- X2 `:369` ne traite que `SelTarget ∈ {1,3,4}`.
- `:364` `WaitingForOperator := (SelTarget=0) OR NOT CycleMotionPermit` → pour `SelTarget=2`, le
  bloc `IF (1 OR 3 OR 4)` est **skippé** → aucune translation, aucune transition.
- Avec manche tenu, `StepMaxTimer` (`:173`, 60 s) finit par lever cause[4] « dépassement tempo »
  → `STABILIZING`.

**Conséquence** : sélectionner P2 fige le cycle puis déclenche un **défaut non pertinent** après
60 s. Le commentaire `CODE_BACKUP` (20260822) indique que P2 était un capteur de passage (petite
vitesse) et « n'est **pas** une destination » — l'interface `:26` est donc **périmée** : P2 ne
devrait pas apparaître comme cible sélectionnable dans la liste `SelTarget`.

**Correctif** : retirer « 2=P2 » du commentaire d'interface (`:26`) et/ou refuser explicitement
`SelTarget=2` en amont (message IHM) au lieu de laisser le cul-de-sac → défaut StepMax.

---

## 🟡 7 — LOW : sections périmées (doc)

| Source | Élément périmé | Pourquoi |
|---|---|---|
| `AF-04 §2/§8` | « Diving/Extraction réutilisés par le cycle semi-auto » | Contredit par le câblage `Enable` N1/N2-only (voir #3). |
| `GUIDE_SEQUENCEUR §7` | « ⚠️ Chantier différé : ajouter `DiveStateAtError`/`ExtractionStateAtError` » | Déjà implémenté (`StepAtFault`) dans `DiveSearch`, `ExtractionAssist`, `MachineHomingCycle`, et `CycleStepAtError` dans `FB_Cycle`. La note « pas touché, lot dédié » est obsolète. |
| `AF-05 §4bis / §4.4` | Référence `FB_ReferenceCycle` | Le FB réel s'appelle `FB_MachineHomingCycle` (confirmer le renommage dans AF-05 §4bis « référencement benne guidé »). |
| `AF-04 §3bis (1)(2)` | Facteurs cités en `VAR CONSTANT` (`CST_DiveSpeedMin_Mps`…) | Dans `FB_DiveSearch` ils vivent dans le DUT `ST_fbDiveSearch_Config` (avec repli runtime) ; ce n'est que `FB_ExtractionAssist` qui porte des `CST_*`. Doc à aligner. |
| `FB_Cycle:26` + `E_CycleStep` doc | « 2=P2 » cible sélectionnable | P2 n'est pas une destination gérée (voir #6). |

---

## 🧰 Autres points d'ergonomie / robustesse signalés (ni bloquants, ni graves)

- **`FB_Cycle` X1 (homing semi-auto)** : remontée lente vers `TopPositionSensor` **sans** contrôle
  `CableLimitAscentM` ni `LimitLegal` dans l'étape ; la montée dépend de l'appui `BtnHome` et du
  backstop `StepMaxTimer` (60 s) + sécurité top aval (`PRG_04`). Acceptable car sécurité aval,
  mais à documenter explicitement pour les futurs lecteurs.
- **`FB_ExtractionAssist` `AscentNominalSafe`** (`:223`) exclut `M1MeasuredSpeedValid`/`M2...`
  (contrairement à `AscentControlSafe` `:222`). Justifiable en nominal, mais l'écart de critère
  entre les deux paliers mérite une note.
- **`FB_DiveSearch`** : le front d'armement du cycle X0 via `DeadmanArmedEdge` fait démarrer sur
  l'**armement seul** (avant déflexion). Cohérent D2 mais à garder intentionnel.
- **Reset conditionné** : `DiveSearch:109` et `ExtractionAssist:135` exigent « pas de mouvement /
  pas immergé » pour acquitter — **bon** comportement (empêche d'acquitter en mouvement), à
  conserver et à faire vérifier par l'audit A.
- **`X9_DRAIN_PAUSE`** : le TON `DrainingTimer(IN:=TRUE)` continue de compter si l'opérateur
  relâche le manche (la transition seule est gatée par `CycleMotionPermit`) → un relâchement/reprise
  peut « skipper » la durée d'égouttage perçue. Mineur (X9 est une attente procédé sans mouvement).

---

## 🗺️ Verdict

Le socle des cycles est **globalement bien conçu et sûr** (homme-mort continu, repli défaut,
capture d'étape, datum machine re-homing conscient). Le contre-audit identifie **2 points safety
réels** (🟥 #1 et #2), **3 points de robustesse/maintenance** (🟠 #3, #4, #5) et **2 incoherences
doc** (🟡 #6, #7).

**Priorisation**
1. Corriger **#1** (gate X0 sur `NOT Fault.Latched`) — obligatoire, coût faible, enlève un
   contournement de défaut latché.
2. Rendre **#2** réel (reprise consciente de mode) — aligner le code sur `AF_Partie-04 §4.1`.
3. Troncer le commentaire interface **#6** (P2) et arbitrer **#4** (X8 M1/M2).
4. Traiter **#3/#5** en dette documentée (non bloquant) ; **#7** = simple mise à jour doc.

**Choses à ne PAS considérer comme des défauts** (écart d'interprétation possible avec l'audit A) :
- L'homme-mort « fenêtre 3 s » décrit dans `AF-04 §2 D2` — aucune contrainte de fenêtre temporelle
  n'existe réellement (armement = niveau `DeadmanArmed` re-évalué chaque scan). La « fenêtre 3 s »
  est de la doc descriptive, pas un timer implémenté. Ne pas le signaler comme régression.
- `GUIDE_SEQUENCEUR R5` préconise un `TON` par transition ; `FB_Cycle` utilise des TON par bloc
  (`Draining/Stabilization/SpeedMismatch/StepMax`) → **écart acceptable**, pas un non-respect.

---

## 👣 Actions recommandées (négociables, à confirmer)

- [ ] **#1** `FB_Cycle:324` : remplacer `NOT Fault.Error` par `NOT Fault.Latched` dans la
      transition `X0→X1` ; option : exiger Reset si `Fault.Latched` sur `Abort`.
- [ ] **#2** `FB_Cycle` : faire que `WaitingResume` force réellement un passage par X0 / état PAUSE
      au retour de mode + reprise sur `BtnStart` explicite (aligner `AF-04 §4.1`).
- [ ] **#6** retirer « 2=P2 » du commentaire d'interface `FB_Cycle:26` et bloquer `SelTarget=2`
      avec message IHM.
- [ ] **#4** justifier ou corriger X8 (ajouter `M2 >= CableLimitM1AscentM` ou documenter M1 axe
      maître).
- [ ] **#3/#5** traiter en dette : soit appeler les briques en semi-auto, soit documenter la
      duplication et fiabiliser le gate §4.
- [ ] **#7** mettre à jour AF-04/AF-05/GUIDE_SEQUENCEUR (référence `FB_ReferenceCycle` → `FB_MachineHomingCycle`, lever la note « chantier différé », aligner `CST_*` vs `Config`).

---

📚 **Méthode** : relecture intégrale des 4 FB + DUT + `PRG_03`, puis vérification croisée des
lignes citées via lecture directe (pas de Device.export). Aucun `Device.export` n'a été utilisé.
