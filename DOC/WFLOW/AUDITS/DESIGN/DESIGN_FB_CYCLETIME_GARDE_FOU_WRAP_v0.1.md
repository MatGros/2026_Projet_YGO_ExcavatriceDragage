# ⚙️ T88 — Bouclage `TIME()` (49,7 j) dans `FB_CycleTime` : garde-fou `DeltaTimeMs > 1000`

> 📄 **ÉTUDE / DESIGN (zéro code)** · 📅 2026-08-24 · 🎯 T88 — analyser et sécuriser le calcul
> du temps de cycle face au **rebouclage** de `TIME()` (type 32 bits, ~49,7 jours).
> Source : `FB_CycleTime.st`. 🔗 Tâche : [`../TASKS.yaml`](../TASKS.yaml) → T88.

---

## 1. Constat — risque de rebouclage `TIME()`

`TIME()` en CODESYS 3.5 est un type **32 bits** : il **reboucle** tous les
`2^32 ms ≈ 49,7 jours` (4294967296 ms). `FB_CycleTime` calcule :

```
DeltaTimeMs := TIME_TO_UDINT(TimeCurrent - TimeLast);   // L42
```

Au passage du wrap :
- `TimeLast` est proche de `TIME_MAX` (≈ 49,7 j), `TimeCurrent` revient à `0` (ou petit) ;
- la soustraction IEC produit une valeur très grande / instable ;
- le **code actuel n'a pas de plafond** : il n'accepte que `DeltaTimeMs > 0` (L47), mais ne
  borne **pas par le haut** → un `CycleTimeS` aberrant peut être publié, trompant tout
  consommateur basé sur le temps de cycle (ex. vitesses, rampes).

> Contexte projet : dans un programme qui tourne en continu (dragage), le wrap ~tous les 50 jours
> est **réaliste** — il faut un garde-fou.

---

## 2. Garde-fou proposé — seuil haut `DeltaTimeMs > 1000`

> 🎯 Proposé par la tâche : tout delta > **1000 ms** est **physiquement impossible** sur une tâche
> à cycle nominal 4–10 ms (hors arrêt/redémarrage automate, déjà couvert par le 1ᵉʳ cycle).

| Cas | Condition | Comportement |
|---|---|---|
| delta nominal | `0 < DeltaTimeMs ≤ 1000` | `CycleTimeS := DeltaTimeMs / 1000.0` (normal) |
| delta nul | `DeltaTimeMs = 0` | `CycleTimeS := DefaultValueS` (secours) |
| **delta aberrant (wrap / gel)** | `DeltaTimeMs > 1000` | **`CycleTimeS := DefaultValueS` (secours)** — ne PAS publier la valeur fausse |

**Principe fail-safe** : une mesure de cycle incohérente → on retombe sur la valeur de secours
(`DefaultValueS`, ex. 4 ms) au lieu de propager un artefact de wrap. Pas d'auto-redémarrage,
pas de consigne dérivée d'un `CycleTimeS` faux.

**Modification minimale** (`§4 Conversion et secours`) :
```
IF (DeltaTimeMs > 0) AND (DeltaTimeMs <= 1000) THEN
    CycleTimeS := UDINT_TO_REAL(DeltaTimeMs) / 1000.0;
ELSE
    CycleTimeS := DefaultValueS;
END_IF;
```

> ⚠️ **Ne pas confondre** : `DeltaTimeMs > 1000` (garde-fou anti-wrap) ≠ `DeltaTimeMs > 0` actuel
> (anti-zéro). Les deux coexistent.

---

## 3. Points à trancher (avant implémentation)

| # | Question | Recommandation |
|---|---|---|
| 1 | Seuil fixe **1000 ms** (constante `CST_MaxCycleDeltaMs`) ou configurable ? | constante `CST_` (T121 anti-magique), valeur 1000 ms |
| 2 | Faut-il un **diagnostic** (flag `CycleTimeInvalid`) exposé IHM, ou silencieux ? | silencieux OK (le wrap est bénin) ; optionnel un bit diag |
| 3 | À implémenter dans `FB_CycleTime` (C2, code) — **validation humaine requise** ? | oui, c'est du code automate |

---

## 5. Documents liés

| Doc | Lien |
|---|---|
| Tâche | T88 |
| FB | `CODE/A_COMMUN/FB_CycleTime.st` |
| Contrat FB | `DOC/AF/AF_Partie-03_Contrats_Composants_v2.3.md` |
