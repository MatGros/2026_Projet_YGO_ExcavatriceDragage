# 🧩 T148 — FB_FbStatus : Reset simplement MAINTENU (sans nouveau front)

> 📄 **ÉTUDE / DESIGN (zéro code)** · 📅 2026-08-24 · 🎯 T148 — faille « Reset maintenu » :
> un défaut laté peut être **acquitté silencieusement** si la cause disparaît pendant que Reset
> reste maintenu (sans nouveau front). Source : `FB_FbStatus.st`. 🔗 Tâche : [`../TASKS.yaml`](../TASKS.yaml) → T148.

---

## 1. Constat (vérifié code + test)

**Code** (`FB_FbStatus.st`) :
- §2 (L65-68) : `ResetEdge.Q` → `Latch[i] := FALSE` (vide le latch au **front** Reset).
- §3 (L79) : `IF Causes[i].Active THEN Latch[i] := TRUE` (re-lathe **à chaque scan**).
- §5 (L105) : `IF Latch[i] OR (Causes[i].Active AND NOT IsWarning)` → Error.

**Faille (séquence)** :
```
Scan N   : Reset front + cause ACTIVE → Latch:=FALSE puis re-latch (L79) → Error=TRUE
Scan N+1 : Reset MAINTENU (pas de front) + cause DISPARUE → L79 ne relathe pas,
           Latch reste FALSE → L105 = FALSE → Error retombe à FALSE
```
→ **acquittement silencieux** : la cause disparaît pendant le maintien du Reset, aucun nouveau
geste conscient n'a lieu à l'instant de la résolution → le défaut s'efface sans confirmation.

**Preuve** : le test `TC-P03-012` couvre « Reset maintenu + cause persistante » (PASS) mais **ne
teste PAS** « cause disparaît pendant Reset maintenu » — le scénario de la faille n'est pas couvert.

---

## 2. Correctif proposé (design — à valider)

Ne vider le latch sur front Reset **que si la cause brute est à 0 à cet instant** :
```
IF ResetEdge.Q THEN
    FOR i := 0 TO 15 DO
        IF NOT Causes[i].Active THEN Latch[i] := FALSE; END_IF;
        // cause encore active → on NE vide pas le latch (l'interlock sur la cause brute le garde)
    END_FOR;
END_IF;
```
Ainsi, seul un **nouveau front Reset survenant après disparition de la cause** peut acquitter —
cohérent avec « Reset = front conscient, jamais de réarmement accidentel » (AGENTS.md).

> ⚠️ Impact : si la cause est encore active au front Reset, le latch n'est pas vidé → `Error`
> reste TRUE (l'interlock sur la cause brute le garantit déjà, L105). La modification est
> **minimale** et ne change pas le comportement « Reset acquitte la cause disparue ».

---

## 3. Tests à ajouter (garde-fou)

| ID | Scénario | Attendu |
|---|---|---|
| TC-P03-014 | Reset **maintenu** + cause active 3 scans → puis cause **disparaît** pendant que Reset reste TRUE | `Error` doit **rester TRUE** (pas d'acquittement silencieux) |
| TC-P03-015 | cause disparue + **nouveau** front Reset → acquitté | `Error=FALSE` |

---

## 4. Points à valider (avant implémentation)

| # | Question |
|---|---|
| 1 | Correctif « ne vider le latch que si cause à 0 » validé ? (option retenue T147/T148) |
| 2 | Ajouter TC-P03-014/015 au test CI ? |
| 3 | Implémentation (code + test) → **validation humaine** (C4) |

---

## 6. Documents liés

| Doc | Lien |
|---|---|
| Tâche | T148 (et T147 — même famille) |
| FB | `CODE/A_COMMUN/FB_FbStatus.st` (§2/§3/§5) |
| Test | `TOOLS/TEST_AUTO_CI/RESULTS/A_COMMUN/tests/test_fb_fbstatus.st` (TC-P03-012) |
| Standard | `DOC/STDS/CODE_QUALITY_STANDARDS.md §3bis` |
