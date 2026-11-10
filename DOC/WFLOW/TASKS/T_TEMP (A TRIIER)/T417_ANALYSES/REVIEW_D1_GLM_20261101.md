# T417 — Revue read-only : correctif passage par zéro (`FB_Sim_Translation`, mode L4)

> ⚙️ **Conformité contrat** : aucune commande lancée, aucun fichier touché → pas de heartbeat ni G200 (le contrat interdit explicitement les deux ; l'analyse est 100 % statique). Format restitution : sections Gates/Bundle = **N/A** (read-only).

## 🎯 Verdict global : `PASS` avec `MINOR`
Le correctif zéro-crossing est **mathématiquement conforme sur toute la matrice demandée** (v0 ±, force sous/égale/supérieure au seuil, frottement roulant, pas dt). Un **contre-exemple de bord existe** (v_pred = 0 exact, effet ≤ 1 scan) + 1 alerte hors-scope (signe pendule, non vérifiable).

## 1. 🔍 Bloc analysé
Identifié par variables (`FreeVelocity_Mps`, `FrictionStep_Mps`, `StaticFriction_Mps2`, `RollingFriction_Mps2`), déclenché par `ObsCartFree := CartFreeActive AND BrakeMechanicallyOpen AND NOT DriveTorqueActive`. Le correctif = séparation stricte **poussée externe** (`FreeAccel_Mps2`) / **frottement** (`FrictionStep_Mps` appliqué après, avec clamp) — c'est exactement ce qui empêche l'inversion de vitesse par le seul frottement. ✅ architecture saine.

## 2. 📐 Faits calculés (défauts : f_s=0,35 / f_r=0,30 / r=0,5)
Défs : `aₑ = FreeAccel_Mps2` = (r/(1−r))·9,81·θ + `Slope_Mps2` = 9,81·θ + Slope (r LIMITÉ [0 ; 0,9] → pas de division par 0 ✅) ; `d = CycleTimeS` ∈ [0,001 ; 0,100] ; `v_p = v₀ + aₑ·d` ; `Δf = f_r·d = 0,0030 m/s` @10 ms.

| # | Cas | Branche | v sortie | Physique | ✓ |
|---|---|---|---|---|---|
| 1 | v₀>0 ou <0, sans croisement | MAX/MIN | v₀ + (aₑ − f_r·sign(v₀))·d | décél. force+frottement, signes corrects | ✅ |
| 2 | croisement, \|aₑ\| < f_s | arrêt | **0** | adhérence statique | ✅ |
| 3 | croisement, \|aₑ\| = f_s | `<=` inclusif | **0** | équilibre marginal, déterministe — conforme au commentaire « ne decolle que si la poussee depasse » | ✅ |
| 4 | croisement, \|aₑ\| > f_s | inversion | v₀ − (\|aₑ\|−f_r)·d | redémarrage inversé, net \|aₑ\|−f_r ✅ (défauts f_r<f_s) ; croisement marginal → \|v_inv\| ≈ Δf = 0,003 m/s | ✅ |
| 5 | v₀<0 miroir | — | symétrique exact de #2–#4 | conditions miroirs vérifiées ligne à ligne | ✅ |
| 6 | aₑ=0, v₀≠0 | MAX/MIN | →0 en ⌈v₀/Δf⌉ pas (0,05 m/s → 17 pas), jamais négatif | conforme « au plus jusqu'a zero » | ✅ |
| 7 | **v_p = 0 exact**, \|aₑ\| > f_s | ELSE : MIN(0, Δf) | **0 pendant 1 scan** | devrait inverser ce pas | ⚠️ |

**Stabilité** : cas frottement seul, \|v\| monotone décroissante, aucune oscillation pour tout d ∈ [0,001 ; 0,100] ✅. Position perdue au scan d'arrêt ≤ v₀·d/2 ≤ 0,25 mm (vs `SensorHysteresis_M`=0,02 m → 1,2 %, négligeable).

## 3. ⚠️ Contre-exemple indépendant (MINOR, quantifié)
- **Instance** : `Slope_Mps2` = −1,0 (θ=0) → aₑ = −1,0 ; d = 0,010 ; v₀ = +0,01 → v_p = 0 exactement en IEEE (représentation identique, soustraction exacte). Condition de croisement vraie mais \|aₑ\| > f_s → `ELSIF v_p > 0` faux → ELSE : v = MIN(0, 0+0,003) = **0**. Reprise au scan suivant via branche repos : (1,0−0,35)·0,01 = 0,0065 m/s inversé.
- **2ᵉ déclencheur, non marginal** : frottement seul achève l'arrêt (v_p>0 mais v_p−Δf<0 → clamp 0) alors que \|aₑ\|>f_s → même pause 1 scan avant redémarrage.
- **Impact** : retard de reprise ≤ 1 cycle (~10 ms), jamais une vitesse de mauvais signe persistante. Non bloquant — mais contredit la lecture naïve de « force superieure → poursuit ». À trancher : geler par test ou corriger.

## 4. 🧱 Limites
- **L2** discretisation : friction signée sur vitesse **fin de pas** → sous-décélération au croisement ≤ 2·f_r·d = 0,006 m/s (défauts).
- **L3** discontinuité d'accélération au seuil 0,001 m/s : net = \|aₑ\|−f_s (repos) vs \|aₑ\|−f_r (dynamique), Δ=0,05 m/s² — conforme stick-slip, à documenter.
- **L4** aucune contrainte f_r ≤ f_s dans le code (valeurs libres) → config f_r>f_s : sur-amorti, pauses supplémentaires, pas de divergence.
- **L5** au-delà de 100 ms, croisements multiples par pas non modélisés (reconnu par le commentaire de borne `CycleTimeS`).
- **L6** valeurs L4 = hypothèses sans mesure terrain (commentaires « Valeurs = HYPOTHESES ») → tout test valide la **cohérence du modèle**, pas le réel.

## 5. 🧪 Matrice de tests manquants (aucun ID de test croisement cité dans la source ; seuls TC-T300-MEC-030 et traces 2026-09-04/G360 apparaissent, hors sujet)

| ID | Cas | Attendu | Réf code |
|---|---|---|---|
| T1 | arrêt adhérence, \|aₑ\|=0,20 | v=0 permanent, position gelée | `StaticFriction_Mps2` ; cmt « l'adherence interdit un redemarrage » |
| T2 | frontière \|aₑ\|=f_s exact | stick (inclusif) | `<=` croisement + branche repos |
| T3 | force>f_s (`Slope`=0,40) | inversion continue, net \|aₑ\|−f_r | cmt « La force externe peut inverser le mouvement » |
| T4 | miroir v₀<0 | symétrie T1–T3 | conditions miroirs |
| T5 | frottement seul, aₑ=0 | →0 en 17 pas, jamais <0 | MAX/MIN clamps |
| T6 | v=±0,0009/0,0010, aₑ opposé | bascule repos/dynamique sans saut | seuil `ABS(...)<0,001` |
| T7 | stick-slip pendule (θ~0,036 rad) | dérive bornée, zéro pompage | cmt « anti-pompage pendulaire » |
| T8 | d=0,001/0,010/0,100 sur T1–T3 | verdicts identiques ± discretisation | `LIMIT(0.001,…,0.100)` |
| T9 | f_r=0,40 > f_s=0,35 | comportement documenté, borné | frictions sans contrainte |
| T10 | croisement × butée (RecoilMax=0) | position ∈ [EndStopTremie_M ; EndStopMaintenance_M] | bloc EndStop |
| T11 | v_p=0 exact (instance §3) | geler le comportement actuel ou corriger | ELSE + `FrictionStep_Mps` |

## 6. 🚨 Devoir d'alerte (hors scope, non corrigé)
1. **Signe pendule non vérifiable** : `aₑ = +9,81·θ` (`instSuspendedLoad.Angle_Rad`) — la convention d'angle de `FB_Sim_SuspendedLoad` est absente de la source fournie. Signe inverse = réaction dans le mauvais sens → anti-amortissement. **Action : fournir le contrat de ce FB.**
2. **Double poussée potentielle** en recul de butée (`EndStopRecoilMax_M`>0) : poussée déjà intégrée via aₑ en phase libre **ET** `instSuspendedLoad.VelocityReaction_Mps` ajouté dans la branche recul.
3. **Commentaire imprécis** : « …+ pente - frottement oppose au mouvement » — le frottement n'est **pas** dans `FreeAccel_Mps2` (il est appliqué séparément, ce qui est justement le cœur du correctif : bonne décision, texte à aligner).