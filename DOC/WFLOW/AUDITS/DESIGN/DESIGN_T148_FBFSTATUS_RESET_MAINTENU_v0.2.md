# 🧩 T148 — FB_FbStatus : Reset simplement MAINTENU (sans nouveau front)

> 📄 **ÉTUDE / DESIGN (zéro code)** · **v0.2** (corrigée après revue experte 2026-08-24) ·
> 📅 2026-08-24 · 🎯 T148 — vérifier la faille « Reset maintenu » : un défaut laté peut-il être
> **acquitté silencieusement** si la cause disparaît pendant que Reset reste maintenu ?
> Source : `FB_FbStatus.st`. 🔗 Tâche : [`../TASKS.yaml`](../TASKS.yaml) → T148.

> 🟢 **v0.2 — CONCLUSION : NON REPRODUCTIBLE, comportement déjà sûr.** La faille décrite en v0.1
> ne se produit pas (erreur de trace du rédacteur). **Aucun code C4 à écrire.** Ajouter un test de
> verrou (TC-P03-014) pour figer la preuve, puis clore T148.

---

## 1. Analyse (vérifiée code + revue experte)

**Code** (`FB_FbStatus.st`) :
- §2 (L64-68) : `ResetEdge(CLK:=Reset)` ; `IF ResetEdge.Q THEN Latch[i]:=FALSE` (vide au **front**).
- §3 (L75-81) : `IF Causes[i].Active THEN Latch[i]:=TRUE` (re-lathe **à chaque scan**).
- `Latch` est une **VAR** (mémoire retenue entre scans, jamais remise à zéro implicitement).

**Séquence rejouée** :
```
Scan N   : Reset front + cause ACTIVE → §2 Latch:=FALSE puis §3 re-latch → Latch=TRUE
Scan N+1 : Reset MAINTENU (ResetEdge.Q=FALSE) + cause DISPARUE → §2 ne fait rien,
           §3 ne fait rien (cause plus active) → Latch GARDE sa valeur = TRUE
```
→ **`Error` reste TRUE** (L105 `Latch OR Active`). **Aucun acquittement silencieux.**

> 🔴 **Erreur v0.1** : j'avais écrit « Latch reste FALSE » au scan N+1. **Faux** : `Latch` est une
> VAR retenue, elle garde `TRUE` (re-latchée au scan N). Le « correctif proposé » (ne vider le
> latch au front que si cause à 0) est un **no-op** : §3 réécrit déjà `Latch[i]:=TRUE` à chaque
> scan tant que la cause est active → résultat de fin de scan identique avec ou sans correctif.

---

## 2. Conclusion

| Élément | Verdict |
|---|---|
| Faille « acquittement silencieux » | ❌ **Non reproductible** — comportement déjà sûr |
| Correctif proposé (v0.1) | ⚠️ **No-op** — ne pas coder (polluerait un FB C4 sans raison) |
| Action requise | ✅ Ajouter **TC-P03-014** (test de verrou) + clore T148 |

---

## 3. Test de verrou à ajouter (garde-fou)

| ID | Scénario | Attendu |
|---|---|---|
| TC-P03-014 | Reset **maintenu** + cause active 3 scans → puis cause **disparaît** pendant que Reset reste TRUE | `Error` doit **rester TRUE** (pas d'acquittement silencieux) — **devrait déjà passer** sur le code actuel |

> ✅ **Ajouté 2026-08-24** dans `test_fb_fbstatus.st` (TC-P03-014) : verrou de non-régression —
> si un futur refactor casse la rétention du latch, le test échoue. La preuve « non reproductible »
> repose désormais sur un **test automatisé**, pas sur un rejeu manuel.

---

## 4. Documents liés

| Doc | Lien |
|---|---|
| Tâche | T148 (et T147 — même famille, déjà corrigé) |
| FB | `FB_FbStatus` _(supprimé 2026-08-27)_ (§2/§3/§5 — historique) |
| Test | `TOOLS/TEST_AUTO_CI/RESULTS/A_COMMUN/tests/test_fb_fbstatus.st` (TC-P03-012) |
| Revue experte | revue T148 (2026-08-24) — faille non reproductible |
