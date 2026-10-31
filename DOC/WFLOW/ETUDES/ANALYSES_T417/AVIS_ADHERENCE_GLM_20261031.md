# T417 — Investigation lecture seule : passage par zéro, branche `ObsCartFree`

## ⚖️ Verdict

**BUG CONFIRMÉ — le passage par zéro n'est jamais détecté à l'intérieur d'un pas.** Une force < seuil statique peut inverser le mouvement, non pas via la branche statique (elle est correcte), mais parce qu'un pas d'intégration **saute par-dessus zéro** et re-signalise le chariot comme « en mouvement » dans l'autre sens — sans jamais re-tester l'adhérence.

```text
Auto-vérification liaison : hors applicable — mission lecture seule, aucun fichier modifié
Heartbeat : non émis (session sans accès repo fourni, analyse 100 % textuelle)
```

## 🔍 Chaîne du défaut (3 lignes)

1. Garde statique = `ABS(VelocityTrue_Mps) < 0.001` évaluée **au début du scan** uniquement (bande de 0,002 m/s).
2. Branche mobile : `FreeVelocity` est intégré **sans test de croisement de signe** ; `MAX/MIN` ne borne que l'effet du frottement, pas le franchissement de zéro par la force.
3. Une fois `v` ressorti négatif avec `|v| ≥ 0.001`, la branche statique est **définitivement inaccessible** (le pas suivant éloigne de la bande).

## 📊 Simulation — code vs attendu

Hypothèse : `FreeAccel_Mps2 = −0.2` net (pendule + pente combinés), `ObsCartFree = TRUE`, `CycleTimeS = 0.1`.

| Scan | v code (m/s) | v attendu, adhésion au zéro (m/s) |
|---|---|---|
| 0 | +0,004 | +0,004 |
| 1 | **−0,006** ❌ inversion en 1 pas | **0,000** (arrêt à t* ≈ 13,3 ms : (0,2+0,1)·t = 0,004) |
| 2 | −0,016 | 0,000 — scan 2 : \|a\| = 0,2 ≤ 0,35 → branche statique : maintien |
| 3 | −0,026 | 0,000 |
| n | −0,006 − 0,01·(n−1) | 0,000 permanent |

- **Code** : `FreeVelocity = 0,004 − 0,02 = −0,016` → `MIN(0, −0,016 + 0,01) = −0,006`. Ensuite, |a| net arrière = 0,2 > roulement 0,1 → **accélération inverse continue, divergence** (le chariot repart vers Tremie).
- **Attendu** : décélération mobile 0,2 + 0,1 = 0,3 m/s² → arrêt à 13,3 ms ; redémarrage exigerait |a| > 0,35 ; 0,2 < 0,35 → **immobilisé**.

**Condition de déclenchement** (compacte, pour les scenarios L4) :
```text
inversion indue ⟺ (|a_externe| − f_roulement) × dt > |v0| + 0,001
ici : (0,2 − 0,1) × 0,1 = 0,01 > 0,004 + 0,001 = 0,005 ✔ déclenchée
```

## ❓ Réponse à la question

| Plan | Force < statique peut-elle inverser ? |
|---|---|
| Physique | **NON** — le corps reste collé (0,2 < 0,35) |
| Code, branche statique | NON — garde correcte |
| **Code, branche mobile** | **OUI — par dépassement de pas** (le zéro est franchi *entre* deux scans, le test statique est contourné, jamais ré-armé) |

Le commentaire du code (« le frottement ne peut que réduire sa vitesse, au plus jusqu'à zéro ») est vrai pour le frottement seul, mais rien ne borne la **force** au zéro — trou documentaire mineur en sus.

## 🛠️ Correction algorithmique minimale (description, sans édition)

**Un seul point de modification** — détection de croisement dans la branche mobile, en réutilisant la branche statique existante :

```text
Dans IF ObsCartFree, branche ELSE (mobile), après le calcul de FreeVelocity_Mps :
  CroisementZero := (VelocityTrue_Mps > 0 ET FreeVelocity_Mps < 0)
                 OU (VelocityTrue_Mps < 0 ET FreeVelocity_Mps > 0)
  SI CroisementZero ET ABS(FreeAccel_Mps2) <= MAX(0, StaticFriction_Mps2) ALORS
      VelocityTrue_Mps := 0.0        (* le pas a franchi zéro : l'adhérence retient *)
  SINON
      ... logique MAX/MIN existante inchangée ...
```

- **Minimal viable** : sur croisement avec \|a\| ≤ statique → `v := 0`. Au scan suivant, `|v| < 0.001` fait ré-entrer **la branche statique existante**, qui gère déjà correctement maintien **et** décollage (seuil statique consommé). Zéro logique de redémarrage dupliquée.
- **Option précision** (si besoin de rejouer une trace finement) : après croisement légitime (\|a\| > statique), ré-intégrer le reste du pas depuis l'arrêt : t* = \|v₀\|/\|a\|, reste = dt − t*, appliquer (a − statique) sur le reste. Le fix minimal y renonce : perte ≤ (|a|−statique)·dt ≈ 15 mm/s max — négligeable pour le banc.
- Cas \|a\| > statique (benne qui pousse vraiment, ex. 0,5) : inchangé, l'inversion reste licite — la garde ne mord que là où la physique l'exige.

## 🚨 Devoir d'alerte — hors scope du croisement, même branche

1. **Signe du frottement durant le pas de croisement** : appliqué selon la vitesse *post-intégration* (il s'oppose à la nouvelle direction, pas au mouvement réel du pas). Ne crée pas le bug mais module l'amplitude du dépassement ; à traiter dans la même correction (frottement de roulement sur la portion avant croisement seulement).
2. Rien d'autre : la position intègre `v` sans garde aval, la réaction charge est bien exclue en mode libre (`IF NOT ObsCartFree`) — aucun second filet n'existe. Confirmé : le garde-fou statique est l'unique, et il est contournable.

## 📋 Restitution contractuelle

- **Périmètre** : respecté — analyse de la branche `ObsCartFree` exclusivement, aucune calibration, aucun essai machine, aucune édition.
- **Résultat code** : v₁ = −0,006 m/s, puis −0,01 m/s par scan, accélération inverse non bornée (jusqu'à butée Tremie).
- **Résultat attendu** : v = 0,000 m/s dès le scan 1, maintien permanent (adhérence 0,35 > 0,2).
- **Contre-exemple fourni** : les valeurs du contrat déclenchent l'inversion en **un seul pas**.
- **Correction** : détection de croisement → arrêt → délégation à la branche statique existante (1 point de modification, pas de duplication).
- **Fichiers modifiés** : aucun (lecture seule).
- **Hors scope constaté** : les 2 points ci-dessus, signalés, non corrigés.