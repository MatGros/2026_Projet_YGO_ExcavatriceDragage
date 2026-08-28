# T167-CR — Rapport brut omniroute codex/gpt-5.6-terra-high

> Revue READ-ONLY (2e avis independant). Analyse orchestrateur + passe de durcissement H1-H5 : voir T167-CR_REVUE_INDEPENDANTE_CYCLES.md §5.

---

## Écarts relevés

### 🔴 CRITIQUE — Contacteur Kobold maintenu alimenté sans demande de mouvement
**Réf.** `FB_DiveSearch.st`, `SEARCHING_IMMERSION` / `SEARCHING_BOTTOM`

```st
KoboldContactorCmd := TRUE;
```

Cette commande reste à `TRUE` même lorsque :

```st
MotionRequestActive = FALSE
```

Or les accumulateurs timeout n’avancent eux-mêmes que si la demande de descente est active :

```st
... AND MotionRequestActive AND (MotionDirection = -1)
```

**Conséquence :** si l’opérateur relâche la demande de descente avant immersion/fond, le contacteur Kobold peut rester alimenté indéfiniment, sans progression et sans timeout. Cela viole :

- l’autorisation positive courante pour une sortie `[ACT]` ;
- l’exigence anti-chauffe du contacteur Kobold ;
- le principe de mise en état sûr en cas d’absence de mouvement utile.

---

### 🔴 CRITIQUE — Non-redémarrage après défaut latché non démontré / structurellement dépendant de `FB_FaultCore`
**Réf.** `§2 Gate neutralisation`, `§3 Machine état`

Le gate remet l’état interne à `WAIT_PRECONDITIONS` lors de `Enable := FALSE` :

```st
DiveState := E_DiveSearchState.WAIT_PRECONDITIONS;
```

Puis la machine d’état n’est bloquée que par :

```st
IF Fault.Error THEN
    DiveState := E_DiveSearchState.ERROR_HOLD;
ELSE
    CASE DiveState OF
```

Elle ne teste jamais explicitement `Fault.Latched`.

De plus, dans `READY_TO_DESCEND`, elle réactive explicitement `Ready`, sans garde sur le latch :

```st
Ready := TRUE;
```

**Scénario dangereux si `Fault.Error` représente seulement une cause active, distincte de `Fault.Latched` :**

1. Défaut de paramétrage actif → défaut latché.
2. Paramètre corrigé, sans front `Reset` → la cause active disparaît.
3. `Enable := FALSE` → état forcé à `WAIT_PRECONDITIONS`.
4. `Enable := TRUE` → progression possible vers `READY_TO_DESCEND`.
5. `Ready := TRUE`, puis descente possible malgré `Fault.Latched = TRUE`.

La conformité dépend donc d’un comportement non fourni de `FB_FaultCore` : il faudrait prouver que `Fault.Error` reste à `TRUE` tant que `Fault.Latched` est à `TRUE`.

⚠️ L’extrait seul ne prouve pas le non-redémarrage automatique exigé.

---

### 🔴 CRITIQUE — Sorties de commande conservées pendant un scan après défaut Palier 5 / séquence
**Réf.** `§1 Causes & Socle Défaut`, puis `SEARCHING_IMMERSION` / `SEARCHING_BOTTOM`

`instFault` est exécuté **avant** la détection des défauts de séquence et Palier 5, qui surviennent dans la machine d’état :

```st
instFault(...);
Fault := instFault.Fault;
...
KoboldContactorCmd := TRUE;
...
IF CurrentSpeedStep > 4 THEN
    Palier5ForbiddenFault := TRUE;
END_IF;
```

Même phénomène pour `SeqErrorFault`.

**Conséquence :**

- le défaut est posé après l’évaluation de `Fault`;
- `Fault.Error` ne sera visible qu’au scan suivant ;
- durant le scan de détection, `DescendPermit` et `KoboldContactorCmd` peuvent déjà être à `TRUE`.

C’est contraire à l’exigence de coupure déterministe dès détection du défaut, notamment pour le garde-fou Palier 5 déclaré « strictement actif même sous bypass ».

---

### 🟠 MAJEUR — `StepAtFault` peut capturer le mauvais état
**Réf.** `§1 Capture ordonnée`, `§3 SEARCHING_*`, fin de scan

La capture est correctement placée avant le passage explicite en `ERROR_HOLD` :

```st
ErrorEdge(CLK := Fault.Error);
IF ErrorEdge.Q THEN
    StepAtFault := PrevState;
END_IF;
```

Mais pour les défauts produits dans le `CASE`, le front `Fault.Error` apparaît seulement au scan suivant.

Exemple reproductible :

1. État `SEARCHING_IMMERSION`.
2. `CurrentSpeedStep > 4` → `Palier5ForbiddenFault := TRUE`.
3. Durant le même scan, un front Kobold valide peut faire :

```st
DiveState := E_DiveSearchState.SEARCHING_BOTTOM;
```

4. Fin de scan :

```st
PrevState := DiveState; // SEARCHING_BOTTOM
```

5. Scan suivant : `Fault.Error` apparaît ; `StepAtFault` capture `SEARCHING_BOTTOM`.

**Étape réelle au défaut :** `SEARCHING_IMMERSION`.  
**Étape mémorisée :** potentiellement `SEARCHING_BOTTOM`.

Même risque entre `SEARCHING_BOTTOM` et `BOTTOM_CONFIRMED`.

➡️ La règle D2 « capture de l’étape en défaut avant bascule » n’est donc pas satisfaite pour les défauts levés dans la machine d’état.

---

### 🟠 MAJEUR — Robustesse numérique insuffisante sur conversion `REAL → UDINT → TIME`
**Réf.** calcul des `CalculatedImmersionTimeout` et `CalculatedBottomTimeout`

```st
CalculatedImmersionTimeout := UDINT_TO_TIME(REAL_TO_UDINT(
    ImmersionCourse_M / CST_DiveSpeedMin_Mps
    * CST_TimeoutMarginFactor
    * CST_SecToMs));
```

Points positifs :

- ✅ diviseur constant non nul (`0.15`) ;
- ✅ plancher de course présent via `MAX(...)` ;
- ✅ valeurs incohérentes de seuil détectées partiellement.

Écart :

- ❌ aucune validation de plage maximale des configurations ;
- ❌ aucune saturation avant `REAL_TO_UDINT` ;
- ❌ aucune garantie que la valeur convertie est représentable par `TIME` ;
- ❌ aucune gestion explicite d’un `REAL` non représentable / hors plage.

Une profondeur légale ou une limite câble extrême peut générer un overflow ou un comportement dépendant de l’implémentation CODESYS lors de la chaîne de conversions. Un timeout de garde ne doit jamais dépendre d’un overflow silencieux.

---

### 🟡 RÉSERVE — Reset sur front : cohérent localement, mais contrat `FB_FaultCore` indispensable
**Réf.** `§1`

Les latches locaux sont acquittés sur front :

```st
IF ResetEdge.Q
   AND NOT ErrorCausePresent
   AND NOT KoboldImmersed
   AND NOT MotionRequestActive THEN
```

✅ Les gardes portent sur le contenu du reset : cause de paramétrage absente, machine hors immersion, absence de demande de mouvement. C’est cohérent avec la règle projet autorisant des gardes de réarmement.

⚠️ Mais le socle reçoit le niveau brut :

```st
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
```

La conformité stricte « un front Reset conscient » pour les défauts gérés directement par `FB_FaultCore`, notamment `ErrorCausePresent`, dépend entièrement du contrat interne non fourni de `FB_FaultCore`.

---

## Synthèse par axe

| Axe demandé | Résultat |
|---|---|
| 1. Sécurité ISO 13849 / autorisation positive / anti-chauffe | ❌ Échec : contacteur maintenu sans demande active ; coupure retardée d’un scan pour certains défauts |
| 2. Non-redémarrage automatique | ❌ Non démontré et structurellement fragile : état réinitialisé par `Enable`, absence de garde explicite sur `Fault.Latched` |
| 3. Reset non conditionné avec gardes de contenu | ⚠️ Logique locale cohérente ; conformité globale non vérifiable sans contrat `FB_FaultCore` |
| 4. Ordre de scan / `StepAtFault` | ❌ Échec pour défauts produits dans le `CASE` |
| 5. Commandes résiduelles sur `NOT Enable` / `ERROR_HOLD` | ✅ Neutralisation correcte dans ces deux états ; ❌ non suffisante lors du scan de détection de certains défauts |
| 6. Robustesse numérique | ❌ Échec : absence de bornage/saturation avant conversions |

# VERDICT = REJETÉ

Le bloc ne peut pas être certifié sur les axes demandés en l’état, principalement à cause du maintien potentiellement indéfini du contacteur Kobold, de la coupure tardive après certains défauts, et de la non-garantie du verrouillage par `Fault.Latched` après un cycle `Enable OFF → ON`.