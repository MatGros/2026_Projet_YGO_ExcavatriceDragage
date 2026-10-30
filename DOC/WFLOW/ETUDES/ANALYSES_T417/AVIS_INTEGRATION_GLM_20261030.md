**T417 — Lecture seule** ✅ aucun fichier consulté, aucune écriture, aucun code produit.

## ⚠️ Diagnostic

Le frottement est traité comme une **force active** : son impulsion `−f·dt·sign(v)` est appliquée en entier, même quand elle dépasse la quantité de mouvement disponible. `+0,004 + (−0,010) = −0,006` : le frottement « crée » une vitesse inverse. Physiquement c'est une **force contrainte** : elle peut au plus annuler v, jamais inverser seule. Le bug est structurel (impulsion non bornée), pas une mauvaise valeur de f.

## 🧮 Algorithme minimal (événement exact, 3 branches)

Notations : σ = sign(v), ε = 0,001 (détection repos conservée).

**B0 — Repos** (|v| < ε) :
- |a| ≤ s → **v := 0** (statique tient)
- |a| > s → **v := sign(a)·(|a| − s)·dt** (démarrage)

**B1 — Mouvement** : Δ := (a − f·σ)·dt ; v' := v + Δ
- v'·σ ≥ 0 → **v := v'** (aucun croisement ce pas)
- sinon croisement :
  - **Cas A — a ne s'oppose pas à v** (a=0 ou sign(a)=σ) : le frottement seul a provoqué l'arrêt → **v := 0**. Exact, pas d'artifice : un croisement impose |a| < f < s, donc B0 confirmera le repos au pas suivant.
  - **Cas B — a opposé à v** : arrêt à t_stop = |v|/(|a|+f) < dt (garanti par le croisement) ; τ := dt − t_stop ; puis re-test statique : si |a| ≤ s → **v := 0** ; sinon → **v := sign(a)·(|a| − s)·τ**. **Inversion réelle possible uniquement ici.**

**Invariant** : le frottement dissipe sans excéder ce qui mène à zéro ; l'inversion exige |a| > s mesuré après passage à zéro. Convention de démarrage = branche repos → **s et f restent distincts**. Le zéro du Cas A est physiquement exact (f < s), celui du Cas B est la loi statique — aucun clamp arbitraire.

Simplification assumée (à tracer) : si v' tombe exactement à 0 en B1 sans croisement strict, la reprise éventuelle se traite au pas suivant.

## 📊 5 cas numériques attendus (dt = 0,1 s)

| # | v₀ (m/s) | a (m/s²) | f | v attendu | Justification |
|---|----------|----------|------|-----------|---------------|
| 1 | 0 | +0,20 | 0,30 | **0** | 0,20 ≤ s=0,35 : statique tient |
| 2 | 0 | +0,60 | 0,30 | **+0,025** | démarrage : (0,60−0,35)·0,1 |
| 3 | +0,004 | 0 | 0,10 | **0** | ✔ **passage zéro** — croisement par frottement seul → Cas A (au lieu de −0,006 aujourd'hui) |
| 4 | +1,000 | 0 | 0,30 | **+0,970** | 1,0 − 0,30·0,1 : dissipation normale, aucun clamp intempestif |
| 5 | +0,100 | −1,00 | 0,30 | **−0,0150** | ✔ **zéro franchi** — t_stop = 0,10/1,30 = 0,077 s ; τ = 0,023 s ; |a| = 1,00 > s → inversion réelle : −(1,00−0,35)·0,023 |

## ✅ Propriétés

- **Aucune inversion artificielle** : Cas A exact, Cas B traité en sous-événement (t_stop), pas d'impulsion résiduelle fantôme.
- **Dissipation bornée, indépendante de dt** (0,01–0,1 s) : le zéro n'est jamais dépassé par le frottement.
- **Cas 3 = référence de régression** du test ST existant (résultat attendu change de −0,006 → 0).
- Cas 1–2/3–5 exercent respectivement le seuil statique distinct et le frottement cinétique.
- Convergence : repos exact en ≤ 2 pas dès que |a| ≤ s.

⚠️ **Devoir d'alerte** : conflit préambule/contrat — le checkpoint heartbeat impose une écriture fichier, le contrat T417 l'interdit. Je n'ai pas journalisé ; arbitrage orchestrateur requis.