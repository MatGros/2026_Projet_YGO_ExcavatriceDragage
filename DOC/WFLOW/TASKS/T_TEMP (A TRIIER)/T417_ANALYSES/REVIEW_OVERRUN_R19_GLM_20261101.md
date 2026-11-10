## 📊 Bornes idéales (calculs à partir des faits fournis)

Vitesse initiale : gain .02 m/(Hz·s) × 20 Hz = **0.40 m/s** (0.41 si capturé à 20.5 Hz — tolérance capteur, FB_Sim_Translation.st:294-348).

| Scénario | Décél. brute | Distance idéale | Durée |
|---|---|---|---|
| (a) Rampe 25 Hz/s → 0 | gain×25 = **0.5 m/s²** | 0.40²/(2×0.5) = **0.16 m** | 0.8 s |
| (b) Frein 2 m/s² immédiat | 2 m/s² | 0.40²/4 = **0.04 m** | 0.2 s |
| (c) Délai .09 s + frein | 2 m/s² | 0.4×0.09 + 0.04 = **0.076 m** | 0.29 s |

## 🎯 Delta observé

Position vraie finale 5.27417 m, snapshot dans 5.0±.04 → delta ∈ **[0.234 ; 0.314] m** (snapshot exact non fourni : incertitude ±.04 à reporter sur tout diagnostic).

**Confrontation** : (b) et (c) sont **exclus** (0.04–0.076 m ≪ 0.23). (a) pur = 0.16 m, **sous** la bande. Aucun scénario isolé ne couvre l'observation.

## 🔍 Diagnostic mécanisme plausible

Combinaison **rampe variator + pente défavorable** : si la pente (-0.20 m/s², FB_Sim_Translation.st:294-348) s'oppose à la décélération, net = 0.5 − 0.20 = 0.3 m/s² → d = 0.16/0.6 = **0.267 m** (0.28 m depuis 20.5 Hz). Le roulement (.10 m/s², même extrait) module entre 0.20 et 0.28 m — **recouvre la bande observée 0.234–0.314**. 

⚠️ **Hypothèse, pas fait** : le signe effectif pente/sens de marche n'est pas fourni ; la loi de couplage pendulaire (ratio .5, L=1.5 m → période dérivée ≈ 2.46 s) n'est pas spécifiée dans les extraits.

**Exclus par ordre de grandeur** : frein seul, délai+frein. La chaîne event→AtP1 (PRG_05:268-283) → ReqStart retiré (FB_CycleSemiAuto:980-1005) → réduction à P1 (FB_Translation:350-360) est likely no-op à 20 Hz déjà atteint ; latence cycle 10 ms × 0.4 m/s = 4 mm, négligeable.

## 🧪 Test unique discriminant

**Tracer la fréquence/vitesse simulée à chaque cycle 10 ms, de l'événement P1 à l'arrêt complet**, et mesurer dv/dt par segments :

| Signature | pente dv/dt | Diagnostic |
|---|---|---|
| Linéaire ≈ −0.5 m/s² constante | rampe seule (a) |
| Linéaire ≈ −0.3 à −0.4 m/s² | **rampe + pente** (diagnostic attendu) |
| Plateau puis −2 m/s² brutal ~90 ms après | frein (b/c) |
| Oscillation période ≈ 2.5 s, dv/dt non monotone | poussée pendulaire |

Trois régimes, une seule courbe, critères non ambiguës. C'est le test à coût minimal dans l'existant (sim déjà instrumentée : métrique M3ObsOvershootLast_M, sensor ID=3).

## 📏 Critères dérivés et limites

- **Critère passage** : delta final ∈ P1±.04 m exige d ≤ .04 + |snapshot−5.0| → décél. nette ≥ ~2 m/s² depuis 0.4 m/s → **incompatible avec rampe 25 Hz/s** : le test ne peut passer qu'avec un freinage mécanique actif **avant** 0.4 m/s, ou une consigne zéro immédiate à l'événement (aucune n'est décrite dans les extraits fournis).
- **Limites** : snapshot exact manquant (±.04) ; condition de déclenchement du frein (ordre d'arrêt vs seuil fréquence) absente de FB_Sim_Translation.st:294-348 tel que fourni ; le double front AtP1 (PRG_05:268-283) pourrait retarder la prise en compte — non prouvé, à vérifier si la trace montre un plateau à 0.4 m/s > 100 ms avant décélération.
- **Non interprétable** : interaction précise pente/pendule/frottement dans la sim (l'extrait couvre les trois mais pas leur combinaison).

**Verdict** : mécanisme dominant = rampe variateur ralentie par pente ; frein quasi non-contributif ; confirmation en un cycle d'essai instrumenté.