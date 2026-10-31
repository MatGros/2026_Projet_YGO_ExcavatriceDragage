# 🔎 Contre-audit T423 — Bannières IHM, alarmes et banc de test

| Champ | Valeur |
|---|---|
| Date | 2026-10-31 |
| Objet | Contrôle et challenge du rapport agent T422/T423 (banc `T423_AUDIT_DYNAMIC_BENCH.py`, 26 cas « 100 % PASS ») |
| Périmètre code | `FB_Hmi_BannerFormatter.st`, `PRG_07_Supervision.st`, `FB_CycleSemiAuto.st`, `FB_Translation.st`, `FB_Safety_Translation.st` + banc `TOOLS/PLC_CSV_SNAPSHOT/codesys_console/T423_IHM/` + `AUDIT_T422_DEVICES_ALARMS_20261030.yaml` |
| ⚠️ Version | **Arbre de travail** : `FB_Hmi_BannerFormatter.st` et `PRG_07_Supervision.st` sont **modifiés non commités**. Les numéros de ligne valent pour cet état. Confirmer la version présente sur la machine avant toute action. |
| Méthode | 2 agents Claude aveugles (chaîne code / banc) + DeepSeek-v4.1 et GLM-5.3 (Ollama cloud) sous contrat d'exhaustivité (liste fermée, ligne de contrôle X/Y) + 2 agents de challenge (messages / condition réelle). **Chaque constat 🟢 a été relu dans le code par l'orchestrateur.** |
| Statut | Lecture seule. **Aucune modification de code.** Les propositions sont à valider avant toute implémentation (workflow C2+). |
| Suite | **T424** (sous-tâche de T423) : volet 1, banc d'affichage et bandeau — contrat `TASK_CONTRACT_T424_BANC_AFFICHAGE_VOLET1.yaml` · **T425** (indépendante) : volet 2, CI source des défauts — contrat `TASK_CONTRACT_T425_CI_SOURCE_DEFAUTS.yaml` |

---

## 📖 Légende

| Criticité | Sens |
|---|---|
| 🔴 **C-HAUTE** | Défaut réel non visible, faux vert de test, ou fonction de surveillance inopérante |
| 🟠 **C-MOYENNE** | Message trompeur, doublon, masquage partiel, diagnostic dégradé |
| 🟡 **C-BASSE** | Cohérence, lisibilité, dette, code mort sans impact direct |

| Difficulté | Sens |
|---|---|
| **S** | < 1 h, 1 objet, aucun impact fonctionnel |
| **M** | ½ à 1 j, plusieurs objets ou décision de conception |
| **L** | > 1 j, nouvel outillage ou décision fonctionnelle (AF) |

| Vérification | Sens |
|---|---|
| 🟢 | Relu ligne à ligne par l'orchestrateur |
| 🔵 | Convergence ≥ 2 agents indépendants, non relu par l'orchestrateur |
| ⚪ | Un seul agent — hypothèse à confirmer |

---

## 🎯 1. Synthèse en 30 secondes

1. **Le banc prouve l'affichage, pas la détection.** 0 cas sur 26 vérifie la vraie condition de défaut et l'arrêt qui en découle. 11 cas forcent directement un latch de sortie. Les causes process du cycle (états AX, timers, vitesses) ne sont jamais exercées.
2. **Le « 100 % PASS » est surévalué** : copies aval forcées, repli silencieux du forçage, 3 cas sans stimulus, 1 cas sur une cause qui ne peut jamais exister, 0 test négatif.
3. **Le code d'affichage a de vrais trous** : un défaut réel du cycle (`0x0800`, AX7) s'affiche « cause inconnue #2048 » ; le timeout d'étape est désactivé (`IN := FALSE`) ; une perte codeur fait disparaître les alarmes qu'elle provoque.
4. **L'audit T422 n'est pas exhaustif** : 124 des 194 défauts annoncés ne sont pas listés nommément (6 devices sur 10 ont `defauts: []`).

---

## 🗺️ 2. Matrice criticité × difficulté

| | **S** (rapide) | **M** | **L** |
|---|---|---|---|
| 🔴 **HAUTE** | A1 · B2 · B3 · B5 | A2 · A3 · E1 | B1 |
| 🟠 **MOYENNE** | A6 · A7 · A9 · B4 · B6 · C1 · D1 · D2 · E2 | A4 · A5 · A8 · A10 · B7 | — |
| 🟡 **BASSE** | A11 · A12 · A13 · A14 · A15 · C2 · C3 · D3 | A16 · D4 | — |

(D et E : seuils / spec et CI, voir §7.2)

👉 **Quick wins à fort rendement** : la case 🔴 / S (A1, B2, B3, B5).

---

## 🧩 3. Constats détaillés — A. Chaîne d'affichage (code)

### A1 🔴 S 🟢 — Défaut réel `0x0800` (AX7) affiché « cause inconnue #2048 »

Le bit est **réellement levé** en AX7 et **collecté en alarme**, mais **absent du décodeur de cause**.

`FB_CycleSemiAuto.st:537-541` — producteur actif et latché :
```iecst
instCauses[11].Active   := (State = E_AutoCycleStep.AX7_SEARCH_BOTTOM)
                           AND (DepthStopMode <> E_CycleDepthStopMode.KOBOLD_ONLY)
                           AND NOT DepthSetpointValid;
instCauses[11].Latching := TRUE;
```
`FB_Hmi_BannerFormatter.st:1192-1193` — alarme présente :
```iecst
IF ((CycleErrorId AND 16#0800) <> 16#0000) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    AlarmArray[AlarmCount] := '[CYCLE] ErrorID:12 - consigne profondeur invalide'; ...
```
`FB_Hmi_BannerFormatter.st:622-625` — le décodeur s'arrête à `0x0400` :
```iecst
    ELSIF (CycleErrorId AND 16#0400) <> 0 THEN
        CycleFaultCauseStr := 'arret meca non confirme';
    ELSE
        CycleFaultCauseStr := CONCAT('cause inconnue #', WORD_TO_STRING(CycleErrorId));
```
**Impact** : en AX7, l'opérateur voit une cause générique alors que la vraie cause est connue. Le commentaire d'en-tête (l.600-601) ignore aussi le bit 11.

---

### A2 🔴 M 🟢 — Timeout d'étape du cycle désactivé

`FB_CycleSemiAuto.st:387` — seul appel du TON :
```iecst
StepMaxTimer(IN := FALSE, PT := StepMaxTimeout);
```
`FB_CycleSemiAuto.st:487` — la cause dépend de `.Q`, donc ne peut jamais être vraie :
```iecst
instCauses[4].Active   := StepMaxTimer.Q AND (State <> E_AutoCycleStep.AX_STAB) AND NOT CycleChecksInhibited;
```
**Impact** : une étape bloquée ne passe jamais en défaut « timeout étape ». L'alarme (l.1177-1178) et le décodeur (l.610-611) existent mais sont morts. Le banc teste cette alarme (`TC_D10_03`) → **faux vert garanti** (voir B5).
**À trancher** : désactivation volontaire (REX, réglage) ou oubli ? Si volontaire, la documenter et retirer les libellés ; sinon c'est une surveillance de cycle inopérante.

---

### A3 🔴 M 🟢 — Une perte codeur supprime les alarmes qu'elle provoque

La **collecte** est gatée par la validité codeur, la **cause** ne l'est pas.

`FB_Hmi_BannerFormatter.st:1165, 1168, 1180` :
```iecst
IF ((CycleErrorId AND 16#0001) <> 16#0000) AND EncM1Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
IF ((CycleErrorId AND 16#0002) <> 16#0000) AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
IF ((CycleErrorId AND 16#0020) <> 16#0000) AND EncM1Valid AND EncM2Valid AND (AlarmCount < CST_NbMaxAlarmes) THEN
```
Même motif sur M3 (`1064 … AND VarM3Valid`), benne (`1083`), synchro (`1094`), et les lignes Meca M1/M2 (`946-962 … AND EncM1Valid`).
**Impact** : pendant une perte codeur ou bus, seul « perte codeur » reste visible ; le défaut process associé disparaît du carrousel, sans entrer non plus dans `[HISTO]`. Le champ cause et le carrousel racontent deux pannes différentes.
**Note** : le gating a sans doute été voulu (éviter des alarmes parasites dérivées d'un codeur invalide). C'est une **décision de conception à réexaminer**, pas un bug évident.

---

### A4 🟠 M 🟢 — Défaut cycle latché affiché comme actif, sans `[HISTO]`

`PRG_07_Supervision.st:794` :
```iecst
CycleErrorId := GVL_IHM.CycleSemiAuto.State.ErrorId OR PRG_03_Modes_Cycle.Data.SequenceState.Fault.ErrorId
                OR PRG_03_Modes_Cycle.Data.SequenceState.Fault.LatchedId,
```
M1/M2/M3 distinguent actif et passé (`HistoM3 := TranslationSafety.LatchedId AND (NOT TranslationSafety.ErrorId);`, l.1204). Le cycle, non.
**Impact** : après disparition de la cause, l'alarme `[CYCLE]` reste affichée comme active jusqu'au Reset. L'opérateur cherche une cause qui n'existe plus.

---

### A5 🟠 M 🟢 — Doublon synchro : 1 cause, 2 alarmes, libellé trompeur

`PRG_07_Supervision.st:838` — un bit est fabriqué à partir de la discordance contacteurs :
```iecst
SyncErrorId := GVL_IHM.M1M2Sync.State.ErrorId OR PRG_04_Treuils_Benne.Data.SyncState.ErrorId
               OR SEL(PRG_04_Treuils_Benne.instWinchSync.ContactorMismatch OR PRG_06_Outputs.Data.ContactorMismatch, WORD#0, WORD#2),
```
`FB_Hmi_BannerFormatter.st:1097-1098` puis `1101-1113` :
```iecst
AlarmArray[AlarmCount] := '[SYNC] ErrorID:02 - incoherence commande';
...
IF (SyncContactorDiag.MismatchLevel >= 1) AND (AlarmCount < CST_NbMaxAlarmes) THEN
    ... CONCAT('[SYNC] discordance contacteurs M1/M2 -> arret : ', BannerSyncContactorWhich);
```
**Impact** : une discordance contacteurs consomme 2 lignes du carrousel, dont une libellée « incohérence commande » qui ne décrit pas la cause.

---

### A6 🟠 S 🟢 — Bit `0x0020` : trois libellés pour une même cause

| Endroit | Ligne | Libellé |
|---|---|---|
| Commentaire d'en-tête | 600-601 | « 5 stabilisation » |
| Décodeur de cause | 612-613 | `'stabilisation'` |
| Collecte alarme | 1180-1181 | `'[CYCLE] ErrorID:06 - ecart codeurs remontee'` |

Producteur : `instCauses[5]` = écart de vitesse confirmé en `AX11_CTRL_ASCENT` (l.493, relu par les agents). **Impact** : bannière et carrousel ne nomment pas la même chose.

---

### A7 🟠 S 🟢 — Bits `0x0040` et `0x0400` : libellés sans producteur

`FB_CycleSemiAuto.st:501-503` et `534-536` :
```iecst
instCauses[6].Active   := FALSE;
instCauses[6].Texte    := 'Reserve - synchronisme arbitre exclusivement par PRG_04';
instCauses[10].Active   := FALSE;
instCauses[10].Texte    := 'Reserve - attente arret mecanique AX3 sans defaut temporel';
```
Le décodeur les nomme pourtant (`614-615` « ecart position M1/M2 », `622-623` « arret meca non confirme »), sans ligne d'alarme. Le libellé de `0x0040` (« position ») ne correspond même pas au texte réservé (« synchronisme »). **Impact** : faible tant que les bits ne sont pas levés ; trompeur pour la maintenance qui lit le code.

---

### A8 🟠 M 🟢 — Plongée et extraction : 11 alarmes mortes

`PRG_07_Supervision.st:840-841` — seules affectations dans `CODE/` :
```iecst
DiveErrorId                 := 0,
ExtractionErrorId           := 0,
```
Les 11 lignes `[DIVE]` (1119-1137) et `[EXTRACTION]` (1140-1149) ne peuvent jamais s'afficher.
**À trancher** : fonction non implémentée (alors retirer ou marquer « réservé ») ou câblage manquant (alors brancher les FB). 🔵 Deux agents signalent aussi `DiveActive := FALSE` (l.817) et l'absence de `FB_Dive*` / `FB_Extraction*` dans `CODE/`.

---

### A9 🟠 S 🟢 — Arrêt d'urgence : bit `0x0004` jamais collecté

`FB_Hmi_BannerFormatter.st:1154-1161` — seuls `0x0001`, `0x0002`, `0x0008` sont traités ; `ErrorID:03` n'existe pas.
**À vérifier** : `0x0004` est-il produit par `FB_Safety_EmergencyManagement` ? Si oui, c'est un défaut AU invisible ; sinon, documenter la réserve.

---

### A10 🟠 M 🔵 — Joystick : défaut copié mais non transmis au bandeau

`PRG_07_Supervision.st:652` : `GVL_IHM.JOY1Joystick.State.ErrorId := PRG_02_Acquisition.Data.Joystick.Fault.ErrorId;` (🟢). L'appel du formateur (784-850) ne reçoit pas cette source (🔵 3 agents concordants : Claude A, DeepSeek, GLM). **Impact** : échec calibration joystick et défauts JOY1 hors carrousel.

---

### A11 🟡 S 🟢 — Carrousel limité à 50, perte silencieuse au-delà

`FB_Hmi_BannerFormatter.st:162` : `CST_NbMaxAlarmes : INT := 50;`. Chaque bloc est gardé par `AlarmCount < CST_NbMaxAlarmes`, sans indicateur de débordement. L'ordre de collecte place `[HISTO]` en dernier : ce sont eux qui sont perdus en premier. Risque réel faible (≈ 117 lignes théoriques au maximum), mais non tracé.

### A12 🟡 S 🟢 — Libellé vide dans la discordance contacteurs

`FB_Hmi_BannerFormatter.st:1108` : `ELSE  BannerSyncContactorWhich := '';` → message affiché « … -> arret : » sans cause identifiée.

### A13 🟡 S 🟢 — Diagnostics réseau produits jamais lus

`PRG_07_Supervision.st:657` et `664` écrivent `GVL_IHM.Network.CanErrorId` et `EcatErrorId` ; aucune lecture dans `CODE/`. Code mort ou consommateur IHM externe à confirmer.

### A14 🟡 S 🟢 — Même bit `0x0008`, deux causes selon le flux M3

| Flux | Source | Cause 3 | Libellé |
|---|---|---|---|
| Live | `FB_Translation.st:124-126` | `DriveFaultLatching` | `1065` « Defaut variateur translation AC600 » |
| Historique | `FB_Safety_Translation.st:152-154` | `BrakeThermalFault` | `1299` « [HISTO] [M3] ErrorID:04 - surchauffe frein » |

Les deux libellés sont justes dans leur flux. Le risque est la lecture croisée en maintenance.

### A15 🟡 S 🟢 — Trous de numérotation `ErrorID`

`[CYCLE]` : 07 et 11 absents · `[AU]` : 03 absent · `[HISTO] M1/M2` : masques `0x0020`, `0x0040`, `0x2000` non collectés. ⚪ `0x2000` serait l'escalade MecaE latchée (`FB_Safety_Winch.st:414-416` selon l'agent A) : si confirmé, un défaut latché disparaît de l'écran dès que la cause live retombe.

### A16 🟡 M 🟢 — Fenêtre aveugle de 3 s après sortie de bypass (M3)

`FB_Safety_Translation.st:119-120` :
```iecst
IF NOT BypassGlobal THEN
    TonStartupWarmup(IN := Enable, PT := T#3s);
```
Les causes 0 (perte com opérateur) et 1 (perte EtherCAT variateur) ne sont évaluées qu'après `TonStartupWarmup.Q` : elles sont aveugles 3 s à chaque sortie de bypass. Probablement voulu (anti-parasite au démarrage) ; à confirmer pour la sortie de bypass.

---

## 🧪 4. Constats détaillés — B. Banc de test `T423_AUDIT_DYNAMIC_BENCH.py`

### B1 🔴 L 🟢 — Aucun cas ne vérifie la vraie condition de défaut

Les variables écrites par le banc (liste exhaustive des champs `"var"`) :

| Type d'écriture | Cas | Exemples |
|---|---|---|
| **Latch de sortie forcé** (détection sautée) | 6 | `instSafetyWinchM1.EncoderFaultLatched`, `OverspeedFaultLatched`, `instSafetyWinchM2.EncoderFaultLatched`, `instBucket.M1SlipFaultLatched`, `OffsetMaxFaultLatched`, `instTranslationM3.DriveFaultLatching` |
| **ErrorId / état forcé** | 5 | `PRG_03….SequenceState.Fault.ErrorId` (×3), `GVL_IHM.M1M2Sync.State.ErrorId`, `GVL_IHM.M3Translation.State.AtP1` |
| **Entrée de diagnostic bus** | 6 | `instDiagEthercat.Device*.Operational` (×4), `instDiagCanOpen.Device*.Operational` (×2) |
| **Entrée simulation / commande** | 9 | `GVL_IHM.Modes.Cmd.SelJoystickWinch` (×3), `SelMode`, `GVL_IHM.Network.Bypass.Global`, `GVL_Simulation.SimChainOk`, `SimPhaseRotationOk`, `SimJoystickRawButton` (×2) |

Le banc n'écrit **aucune variable d'état du séquenceur** : les causes process du cycle (heartbeat IHM, timers, écart de vitesse, FDC, paliers, consigne profondeur) ne sont jamais déclenchées par leur condition. Classement GLM (relu sur la liste ci-dessus) : **11 cas niveau 1** (bit/latch forcé), **15 niveau 2** (entrée réelle), **0 niveau 3** (condition + arrêt vérifié).

### B2 🔴 S 🟢 — Copies aval forcées : la liaison n'est pas testée

`T423_AUDIT_DYNAMIC_BENCH.py:380-386` (cas `TC_D10_01`, idem `TC_D10_02/03`) :
```python
"extra_writes": [
    ("PRG_03_Modes_Cycle.Data.SequenceState.Fault.LatchedId", "2", "0", True),
    ("PRG_03_Modes_Cycle.Data.SequenceState.Fault.Latched", "TRUE", "FALSE", True),
    ("GVL_IHM.CycleSemiAuto.State.ErrorId", "2", "0", True),
    ("PRG_07_Supervision.instHmiBannerFormatter.CycleErrorId", "2", "0", True),
],
```
L'entrée du formateur est forcée directement : le OR de `PRG_07:794` est court-circuité. Même motif sur `TC_D09_01` (3 copies) et `TC_D06_01` (4 copies). **Une liaison cassée passerait en PASS.**

### B3 🔴 S 🟢 — Un forçage peut échouer sans que le banc le sache

`T423_engine.py:120-138` :
```python
online_app.set_prepared_value(path, value_str)
if force:
    forced = False
    for method_name in ("force_prepared_values", "ForcePreparedValues", "force_values"):
        if hasattr(online_app, method_name):
            try:
                getattr(online_app, method_name)(); forced = True; break
            except Exception:
                pass
    if forced:
        return True
online_app.write_prepared_values()   # repli : écriture simple, non forcée
return True
```
Si aucune méthode de forçage n'existe ou si toutes échouent, le cas « forcé » tourne **en écriture simple** et `safe_write` renvoie quand même `True`. `safe_unforce` (l.144-151) renvoie `False` sans que l'appelant le traite.

### B4 🟠 S 🟢 — 3 cas sans stimulus (valeur injectée = valeur restaurée)

| Cas | Lignes | `inject` | `restore` |
|---|---|---|---|
| Couplage nominal M1+M2 | 66-69 | `"0"` | `"0"` |
| Progression homing HX0 | 80-83 | `"1"` | `"1"` |
| Guidage opérateur au repos | 109-112 | `"FALSE"` | `"FALSE"` |

Ces valeurs sont déjà posées à l'initialisation (l.453-455). Ces cas ne peuvent pas échouer à cause de leur stimulus.

### B5 🔴 S 🟢 — `TC_D10_03` teste une alarme qui ne peut jamais exister

Le cas attend « timeout etape » (`bench:411-425`) en forçant `ErrorId = 16`. La cause réelle est morte (A2 : `StepMaxTimer(IN := FALSE)`). **Faux vert garanti** : le test valide l'affichage d'une surveillance inopérante.

### B6 🟠 S 🟢 — Aucun test négatif

0 occurrence de vérification « ce texte NE DOIT PAS apparaître ». Le verdict (`bench:593`) est PASS dès que le texte attendu est présent **n'importe où** dans le tableau d'alarmes. Un message masqué, un doublon ou un message parasite ne sont pas détectables.

### B7 🟠 M 🔵 — Attendus trop génériques

`"[M1]"` (`TC_D09_03`), `"SYNC"` (`TC_D06_01`), `"urgence"` (`TC_D07_02`) matchent d'autres alarmes du même organe. Une alarme préexistante suffit à faire passer le cas (🔵 Claude B + DeepSeek).

---

## 📄 5. Constats détaillés — C. Audit T422 et rapport agent

### C1 🟠 S 🟢 — 124 des 194 défauts ne sont pas listés

`AUDIT_T422_DEVICES_ALARMS_20261030.yaml` : `defauts: []` pour **D01, D02, D03, D04, D05, D07**. Seuls D06, D08, D09, D10 ont des items nommés (64 identifiants). Défauts déclarés sans identifiant : 24 + 24 + 18 + 22 + 25 + 11 = **124**.

| Device | Déclarés | Nommés | Cas banc |
|---|---|---|---|
| D01 Treuil M1 | 24 | 0 | 2 |
| D02 Treuil M2 | 24 | 0 | 1 |
| D03 Benne | 18 | 0 | 2 |
| D04 Translation | 22 | 0 | 1 |
| D05 Codeurs | 25 | 0 | **0** |
| D06 Synchro | 12 | 12 | 1 |
| D07 AU | 11 | 0 | 2 |
| D08 Joystick | 18 | 12 | 1 |
| D09 Bus/IO | 20 | 20 | 5 |
| D10 Cycle | 20 | 20 | 3 |

### C2 🟡 S 🟢 — Synthèses par device incohérentes

Total global cohérent (194 = 71 + 53 + 36 + 34), mais pas par device : D01 = 11 + 4 + 4 + 3 = **22 ≠ 24** ; D02 = 10 + 4 + 5 + 2 = **21 ≠ 24**.

### C3 🟡 S 🟢 — Erreurs dans le rapport agent

- Tableau des « 26 cas » : 28 lignes, doublons #5, #9, #10, #13 absent.
- « Bit 6 (64) non utilisé » : faux, il est décodé (`614-615`).
- « 100 % de concordance » : faux, voir A1, A6, A7.

---

## 🛠️ 6. Plan d'action proposé

> Ordre = rendement / effort. Chaque lot est indépendant. **Rien n'est engagé sans validation.**

### Lot 1 — Corrections d'affichage rapides (S, bandeau seul, aucun effet machine)

| # | Action | Traite | Gain |
|---|---|---|---|
| 1.1 | Créer **une table unique bit → libellé** pour le cycle, utilisée par le décodeur **et** la collecte (source unique) | A1, A6, A7, A15 | Supprime 4 incohérences d'un coup et empêche leur retour |
| 1.2 | Ajouter un contrôle automatique : chaque bit collecté a un libellé de cause, et inversement | A1, A6, A7 | Garde-fou `guard:` exigé par la règle `fix:` + `guard:` |
| 1.3 | Libellé de repli « contacteur non identifié » au lieu de `''` | A12 | Message toujours lisible |
| 1.4 | Indicateur « +N alarmes non affichées » quand le carrousel déborde | A11 | Perte tracée |

### Lot 2 — Fiabiliser le banc d'affichage (S, outillage seul)

| # | Action | Traite |
|---|---|---|
| 2.1 | Supprimer les écritures sur copies aval : injecter **à la source** uniquement | B2 |
| 2.2 | Rendre un forçage échoué **bloquant** (FAIL explicite, pas de repli silencieux) ; traiter le retour de `safe_unforce` | B3 |
| 2.3 | Retirer `TC_D10_03` tant que A2 n'est pas tranché, ou le marquer « surveillance inactive » | B5 |
| 2.4 | Remplacer les 3 cas sans stimulus par une vraie transition (valeur A → valeur B) | B4 |
| 2.5 | Attendus précis (texte complet) et vérification « absent avant / présent pendant / absent après » | B6, B7 |
| 2.6 | 1 cas de superposition (2 défauts simultanés : les deux visibles, ordre vérifié) | A3, A5 |

### Lot 3 — Décisions fonctionnelles (M, à trancher avec toi)

| # | Question | Constat |
|---|---|---|
| 3.1 | Timeout d'étape du cycle : désactivé volontairement ? | A2 |
| 3.2 | Gating des alarmes par validité codeur : le garder, ou afficher le défaut process avec mention « codeur invalide » ? | A3 |
| 3.3 | Défauts cycle latchés : ajouter un préfixe `[HISTO]` comme M1/M2/M3 ? | A4 |
| 3.4 | Discordance contacteurs : supprimer le bit fabriqué `WORD#2` ou renommer « incohérence commande » ? | A5 |
| 3.5 | Plongée / extraction : retirer les 11 libellés ou brancher les FB ? | A8 |
| 3.6 | AU bit `0x0004` et joystick : à collecter ? | A9, A10 |

### Lot 4 — Vérifier les sources des défauts (L, voir §7)

| # | Action | Traite |
|---|---|---|
| 4.1 | Matrice de traçabilité défaut (AF) → condition / seuil (code) → réaction → test existant | B1, C1 |
| 4.2 | Tests CI ciblés sur la vraie condition de défaut pour les familles à plus forte valeur (Meca treuils, cycle) | B1 |

---

## 🧭 7. Cadrage de la suite : séparer « affichage » et « source »

| | **Volet 1 — Affichage** | **Volet 2 — Source du défaut** |
|---|---|---|
| Question | Le texte s'affiche-t-il, sans être écrasé, et s'efface-t-il au bon moment ? | Le bit se lève-t-il **pour la bonne raison**, au bon seuil, avec la bonne réaction, et **pas** hors condition ? |
| Outil | Banc T423 existant, fiabilisé (Lot 2) | Tests CI au niveau FB (`TOOLS/TEST_AUTO_CI/`) + matrice AF ↔ code |
| Entrée | Bit ou ErrorId injecté **à la source** du formateur | Entrées physiques du FB (position, vitesse, timer, état) |
| Preuve | Texte visible, unique, effacé après Reset | Défaut levé au seuil, non levé sous le seuil, réaction (SafeStop / arrêt) vérifiée |

**Principe d'efficacité** : viser 80 % de certitude solide plutôt que 100 % théorique.
1. Partir de la liste des défauts de l'AF (ce qui doit exister), la confronter au code (ce qui existe : la vérité terrain reste le code déployé).
2. Ne tester en CI que les défauts à plus forte valeur sécurité (Meca A-E treuils, survitesse, perte codeur, causes cycle), avec **un cas positif et un cas négatif** par défaut.
3. Réutiliser l'outillage CI existant ; pas de nouvel outil si un cas de test FB suffit.

### 7.1 Ce que disent les deux inventaires (agents Explore, lecture seule)

**Matrice AF → code** : 45 défauts spécifiés · 41 trouvés dans le code (38 actifs, 3 inertes) · 4 non trouvés · 6 dans le code mais absents de l'AF · **15 écarts de seuil, condition ou réaction**.

**Outillage CI existant** (`TOOLS/TEST_AUTO_CI/`, ST compilé en C++ via STruCpp, temps virtuel `ADVANCE_TIME`) : il **sait déjà tester la vraie condition de défaut au niveau FB**, et le fait pour la plupart des causes treuils et translation (cas positif et souvent négatif, vérification de la réaction SafeStop / PowerCutOff).

| FB | Cas CI | Causes testées / total | Dernier résultat (index.html) |
|---|---|---|---|
| FB_Safety_Winch | 21 | 13 / 16 (manquent : rotation phases, thermique frein, codeur en direct) | ⚠️ 14/21 FAIL |
| FB_Safety_Translation | 6 | 8 / 8 | ⚠️ 5/6 FAIL |
| FB_Translation | 43 | 2 / 3 | ⚠️ 37/43 FAIL |
| FB_CycleSemiAuto | 43 | 3 / 12 | ⚠️ 38/43 FAIL |
| FB_Bucket | 41 | 4 / 5 | ✅ 41/41 |
| FB_WinchSync | 5 | 3 / 3 | ✅ 5/5 |

Global : **63 composants, 40 PASS / 23 FAIL**. 46 résultats datent du **2026-09-28** (non relancés depuis). Coût d'ajout d'un cas sur un FB déjà couvert : **25 à 40 lignes de `.st`**, rien côté Python.

### 7.2 Constats complémentaires (D, E)

| ID | Crit. | Diff. | Vérif. | Constat | Preuve |
|---|---|---|---|---|---|
| D1 | 🟠 | S | 🟢 | **L'AF est en retard sur les seuils réglés à la MES** (le code est la vérité terrain). Méca A : AF 2,0 m → code 5,0 m. Méca E : AF 2,5 m → code 7,0 m. Synchro : AF 0,8 / 2,0 m → code 3,0 / 6,0 m. | `FB_Safety_Winch.st:48` : `UncommandedDriftToleranceM : REAL := 5.0; // ... MES 2026-09-04 : 2.0 -> 5.0` · `GVL_PERSISTENT.st:58-59` : `CfgSyncTolerance_M := 3.0, CfgSyncCriticalTolerance_M := 6.0` ; `_WinchCriticalSyncTolerance_M : REAL := 7.0; // Méca E : dernier recours au-delà des seuils synchro 3m/6m` |
| D2 | 🟠 | S | 🟢 | Écart de vitesse du cycle **désactivé volontairement** (documenté), à refléter dans l'AF et le bandeau | `PRG_03_Modes_Cycle.st:247` : `SpeedMismatchTimeout := T#0ms, // Désactivé ; protections FB_WinchSync conservées` |
| D3 | 🟡 | S | 🟢 | Survitesse : latch booléen **hors ErrorId**, donc absente de `[HISTO]`. Elle reste affichée en live via un booléen dédié, gaté par `EncM1Valid` (même motif que A3) | `FB_Safety_Winch.st:453-455` (latch) · `FB_Hmi_BannerFormatter.st:970` : `IF WinchM1Safety.ErrorOverspeed AND EncM1Valid ...` |
| D4 | 🟡 | M | ⚪ | Écarts de condition (pas seulement de seuil) : Méca B treuil sans branche « perte CAN », Méca D sans limite logicielle, Méca F 0,10 m/s / 1 s vs 0,02 m/s / 500 ms, Méca A translation 7 s vs 1 s | Agent AF (`FB_Safety_Winch.st:341, 377, 427` ; `FB_Safety_Translation.st:76`) |
| E1 | 🔴 | M | ⚪ | **La CI existante est rouge et périmée** sur les FB de sécurité : 14/21 FAIL sur FB_Safety_Winch (« SAFESTOP expected TRUE, got FALSE » sur TC-P10-001, 005, 007, 008, 009). Cause inconnue : tests non mis à jour après les réglages MES, ou régression réelle. | `TOOLS/TEST_AUTO_CI/index.html` (2026-10-31 06:36, résultats FB du 2026-09-28) |
| E2 | 🟠 | S | ⚪ | Test contradictoire : T386 attend PowerCutOff sur rotation de phases M3, SAF-002 attend son absence | Agent CI |

> ⚠️ **Valeurs persistantes** : `GVL_PERSISTENT` donne les valeurs **initiales**. Sur la machine, les valeurs retenues peuvent différer : confirmer avec les registres MES avant de conclure sur D1.

### 7.3 Cadrage proposé (80/20)

**Constat clé** : l'outil pour le volet 2 **existe déjà** et couvre la majorité des défauts treuils et translation. Le meilleur rendement n'est pas d'écrire de nouveaux tests, c'est de **remettre au vert ceux qui existent**.

| Étape | Action | Effort | Résultat attendu |
|---|---|---|---|
| **1. Baseline fraîche** | Relancer `run_fb.bat` sur 4 FB : Safety_Winch, Safety_Translation, Translation, CycleSemiAuto (pas `run_all_tests.bat`, qui nettoie les scratchs) | 30 min | Savoir si les FAIL du 2026-09-28 sont toujours là |
| **2. Tri des FAIL** | Pour chaque FAIL : test périmé (seuil MES, ex. Méca A 5,0 m) **ou** régression réelle | ½ j | Liste courte « test à corriger » / « code à analyser » |
| **3. Remise au vert** | Corriger les attendus périmés (aligner sur le code MES, source unique) | ½ à 1 j | Socle CI fiable sur les défauts Méca |
| **4. Compléter les trous à forte valeur** | Rotation phases et thermique frein treuil ; causes cycle 2, 4, 10 (tester l'état choisi : désactivé volontairement) ; 1 cas négatif par Méca A-G | ~10 cas × 30 lignes | Couverture des défauts Méca et cycle avec positif + négatif |
| **5. Vérifier le bit, pas seulement la réaction** | Ajouter 1 `ASSERT` sur le bit `ErrorId` dans les cas existants | 1 ligne par cas | Ferme le lien avec le volet 1 (affichage) |

**Hors périmètre volontaire** : PRG complets (harnais réécrits, risque de divergence), IHM visuelle, chaîne PRG_04 → PRG_06 → AU (renvoyée à l'essai site TC-P10-051.1).

**Décision attendue** : feu vert pour l'étape 1 (exécution locale de 4 FB, écrit seulement dans `TOOLS/TEST_AUTO_CI/RESULTS/`).

---

## ⚠️ 8. Non vérifié / limites

| Point | Statut |
|---|---|
| Version déployée sur la machine vs arbre de travail modifié | À confirmer |
| Producteurs des causes cycle 0, 1, 2 (`.Active` avant l.480) | Non lus |
| Production effective du bit AU `0x0004` | Non lue |
| Escalade MecaE `0x2000` latchée (`FB_Safety_Winch.st:414-416`) | ⚪ agent A seul |
| Décodeur de cause treuil (l.643-662) : bits `0x0004`, `0x0010`, `0x0400` non décodés | ⚪ agent A seul |
| Rotation carrousel 1 s (`PRG_07:848`) | 🔵 non relu |
| Cas MODE : texte issu de la commande et non de l'état réel du couplage (`PRG_07:788-789`) | ⚪ agent B seul |
| Aucun run du banc exécuté pendant ce contre-audit | — |

---

## 🧾 9. Traçabilité des agents

| Agent | Modèle | Périmètre | Fiabilité observée |
|---|---|---|---|
| A | Claude (aveugle) | Chaîne code `CODE/` | Élevée ; 2 chiffres non relus |
| B | Claude (aveugle) | Banc + audit YAML | Élevée ; recalculs justes |
| Pilote cycle | DeepSeek-v4.1 / GLM-5.3 | 12 bits, contrat fermé | 12/12 chacun, verdicts identiques |
| Lot M3/AU/plongée | DeepSeek-v4.1 / GLM-5.3 | 26 items, contrat fermé | 26/26 ; **2 erreurs communes** (`HistoM3` « jamais écrit », faux) ; DeepSeek confond deux FB M3 |
| Challenge messages | DeepSeek-v4.1 | 90 messages, effets de bord | Bon ; a trouvé A12 |
| Challenge condition | GLM-5.3 | Niveaux 1/2/3 | Bon ; **1 erreur** (arrêt FdC « instantané » : faux, corrigé par `FB_Translation.st:128-141`) |

📌 Leçon : les modèles sans accès fichiers se trompent sur les liens **hors de leur extrait**. Tout constat de chaîne amont doit être relu dans le code avant d'être retenu.
