## 1. Hypothèse de calcul (à valider)
Loi linéaire vitesse/fréquence : `v = 0,02·f` → **0,40 m/s à 20 Hz** (0,41 à 20,5 Hz), d'où `d = v²/(2a)`. La linéarité et le traitement pente/charge/frottement sont ceux de `FB_Sim_Translation.st:294-348`, non détaillés dans les extraits → **supposés**, pas prouvés.

## 2. Bornes idéales (v = 0,40 m/s, f front ≤ 20,5 Hz)

| Scénario | a (m/s²) | t arrêt | d (m) | d max à 20,5 Hz |
|---|---|---|---|---|
| (a) rampe variateur 25 Hz/s | 0,50 | 0,80 s | **0,160** | 0,168 |
| (b) frein 2 m/s² immédiat | 2,00 | 0,20 s | **0,040** | 0,042 |
| (c) 0,09 s neutre + frein 2 m/s² | — | 0,09+0,20 | **0,076** | 0,080 |
| *réf.* pente+roulement seuls | 0,20+0,10 = 0,30 | 1,33 s | *0,267* | 0,280 |

Observé : `5,27417 − 5,0 = 0,274 m` ; snapshot non fourni à ±0,04 → **Δ ∈ [0,234 ; 0,314] m**.

## 3. Diagnostic (sans surinterprétation)
- **Rampe variateur exclue seule** : borne max 0,168 m < borne basse 0,234 m. Cette exclusion tient même à 20,5 Hz → indépendante de l'incertitude snapshot.
- **Frein exclu seul** : 0,042–0,080 m, un ordre de grandeur en dessous.
- **Poussée pendulaire non nécessaire** : une décélération de 0,29 m/s² suffit (`v²/(2Δ) = 0,16/0,548`), soit ~0,30 m/s² = pente 0,20 + roulement 0,10 (`FB_Sim_Translation.st:294-348`). La coïncidence numérique (0,267 vs 0,274) est suggestive, **pas une preuve** : le signe de la pente (−0,20) et la contribution de la charge suspendue (ratio 0,5) ne sont pas visibles dans les extraits.
- **Mécanisme le plus plausible** : à la mise à 0 de la commande (front P1), la chaîne simulée ne produit pas la rampe 25 Hz/s ; l'axe décélère quasi uniquement par pente + roulement, frein d'effet négligeable. Si `FB_Translation.st:350-360` maintient `ApproachSpeedP1 = 20 Hz`, cela aggrave le constat.
- ⚠️ **Contradiction de spec à remonter** : la bande ±0,04 m est **structurellement inatteignable** — le seul délai de 0,09 s consomme 0,036 m (90 % du budget), soit 0,076 m même avec un frein parfait.
- ⚠️ `PRG_05_Translation.st:268-283` (token sur fronts **montants ET descendants**) : si la position oscille autour de P1, le token se ré-établit et `FB_CycleSemiAuto.st:980-1005` retire à nouveau `ReqStart` → risque de verrouillage/relance. À vérifier, non conclu.

## 4. Test unique discriminant
Un seul run instrumenté, trace 10 ms (période cycle) sur les 2 s suivant le front P1 : **fréquence de consigne/retour** (issue de `294-348`) + **position**. On en tire la décélération moyenne `ā = Δv/Δt` et la **monotonie** de la vitesse :

| Signature | Mécanisme |
|---|---|
| ā ≈ 0,5 m/s², f décroît à 25 Hz/s, arrêt ~0,8 s | rampe variateur |
| ā ≈ 2 m/s², arrêt ~0,2 s, position finale < 0,09 m | frein |
| ā ≈ 0,3 m/s², arrêt ~1,3 s, **vitesse monotone** | pente + roulement |
| ā ≈ 0,3 m/s² **avec inversion de signe** de la vitesse | poussée pendulaire |

La **monotonie de v** sépare frottement/pente de la poussée pendulaire ; la **magnitude de ā** sépare rampe et frein. Un seul enregistrement suffit.

## 5. Critères dérivés
1. Mesure de `ā` et non de la position seule (bande ±0,04 non informative).
2. Si variateur : Δ attendu 0,16 m (tolérance ±20 %). Si frein : 0,04–0,08 m. Si côte : 0,27 m.
3. Pour rendre la bande ±0,04 atteignable : `v²/4 + 0,09·v ≤ 0,04` → **v ≤ 0,259 m/s**, soit **ApproachSpeedP1 ≤ 12,9 Hz** ; sinon élargir la bande à ≥ 0,08 m.

## 6. Limites / informations manquantes
Snapshot P1 exact (seulement ±0,04) ; valeur de `ApproachSpeedP1` (`FB_Translation.st:350-360`) ; convention de signe de la pente et effet du ratio 0,5 ; modèle de montée en couple du frein ; point de savoir si `294-348` applique réellement la rampe 25 Hz/s ; période pendulaire non calculable en l'état (L=1,5 m seul donnerait ~2,45 s, hypothèse non fournie).