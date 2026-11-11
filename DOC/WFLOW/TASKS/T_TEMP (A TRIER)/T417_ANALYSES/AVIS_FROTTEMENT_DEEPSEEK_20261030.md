## Verdict : ❌ formule actuelle non conforme aux 2 critères

Deux défauts distincts dans `v := v + (a∓f)*dt` :
1. **Pas de clamp à zéro** → le frottement peut inverser `v` (interdit).
2. **Branchement sur le signe de `v` avant update** → le frottement est appliqué sur toute la durée du pas, même quand la force externe fait déjà traverser zéro (double comptage).

### Contre-exemple 1 — frottement seul inverse le mouvement (C1 violé)
`v=0.004 ; a=0 ; f=0.1 ; dt=0.1`

| Pas | Formule actuelle | Attendu |
|---|---|---|
| 1 | `0.004 + (0−0.1)·0.1 = −0.006` | `0` (arrêt) |
| 2 | `v<0 → −0.006 + (0+0.1)·0.1 = +0.004` | `0` |
| 3 | `−0.006` … | `0` |

➡️ **Cycle limite** `+0.004 / −0.006`, période 0.2 s → **clignotement de signe à 5 Hz** pour `dt=0.1`. Toute logique dépendante du sens (interlocks, fins de course, comptage position) clignote. Amplitude parasite 0.01 m/s > vitesse réelle 0.004 m/s.

### Contre-exemple 2 — force opposée suffisante (C2 OK, mais mal quantifiée)
`a = −0.5 ; v=0.004 ; f=0.1 ; dt=0.1`

| Méthode | v obtenu |
|---|---|
| Actuelle | `0.004 + (−0.5−0.1)·0.1 = −0.056` ❌ (frottement compté 2×) |
| Clamp | `v_pred=−0.046 ; |v_pred|>f·dt → −0.046+0.01 = −0.036` ✅ |
| Événement | `t* = 0.004/0.6 = 6.7 ms` puis `−0.4·0.0933 = −0.037` ✅ |

Inversion bien obtenue → **C2 satisfait**, mais l'actuelle surestime la décélération de 0.02 m/s.

### Correction — intégration séparée + clamp (recommandé)
```
v_pred := v + a*dt;                    // 1) force externe seule
dvv    := f*dt;                       // 2) budget frottement cinétique
IF ABS(v_pred) <= dvv THEN
    v := 0.0;                         // le frottement annule, jamais n'inverse
ELSE
    v := v_pred - SIGN(v_pred)*dvv;   // ⚠ SIGN(0)=0 en CODESYS → cas |v_pred|<=dvv déjà traité
END_IF
```
Résultat : C1 = `0.000` ✅ · C2 = `−0.036` ✅

### Comparaison clamp vs événement d'arrêt

| Critère | Clamp (1 pas) | Événement d'arrêt |
|---|---|---|
| C1 (pas d'inversion) | ✅ | ✅ |
| C2 (inversion par force) | ✅ −0.036 | ✅ −0.037 (référence) |
| Erreur | ≤ `f·dt²/2` ≈ 5e-4 m/s | nulle |
| Complexité | 5 lignes, sans état | sous-pas + instant `t*` + état `xAtRest` |
| Cas couvert | `a` constant sur le pas | `a` variant dans le pas |

➡️ **Clamp suffisant** pour `dt=0.1` et `a` échantillonné par pas. L'événement n'apporte que 1e-3 m/s — non justifié ici.

### Points à clarifier (signalement, non résolus)
⚠️ **Unité du seuil statique 0.35 non spécifiée** → le code actuel ne contient **aucune masse**, donc interprétable seulement en **m/s²** (`|a| ≤ 0.35 → v=0`). Si c'est un effort en N, le modèle est incomplet (il manque `m`). **Critère non vérifiable en l'état → à préciser avant tout code.**
⚠️ `0.35 > f=0.1` → au démarrage, saut de vitesse à `(0.35−0.1)·0.1 = 0.025 m/s` en un pas. Vérifier que les consommateurs tolèrent ce saut.
⚠️ Le signe du frottement déduit de `v` seul est **mal conditionné près de zéro** : un booléen d'état `xAtRest` avec hystérésis est nécessaire pour éviter le rebond (racine du défaut 1).

**Aucune cause terrain déduite** (conforme au contrat) — analyse purement numérique.