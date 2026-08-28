## 🧠 Analyse & Spécification Formelle — Séquences Grafcet `FB_DiveSearch` & `FB_ExtractionSequence`

### 1. Contexte & Données de Terrain

Les mesures réelles fournies décrivent une plongée typique avec Kobold. Elles confirment le comportement attendu : activation du capteur, descente bridée, détection du fond, coupure.  
Cependant, **deux points critiques** doivent être signalés avant toute implémentation :

| # | Constat | Impact | Action requise |
|---|---------|--------|----------------|
| 1 | **Activation Kobold à +7.00 m** (hors eau) alors que la règle thermique impose une activation conditionnée à `CfgKoboldActivationDepthM` (défaut ~0.0 m). | Surchauffe possible du capteur dans l'air, non-respect de la règle thermique. | **Clarifier** : s'agit-il d'un scénario de test ? La valeur paramétrée doit être cohérente avec le plan d'eau. Proposer de régler `CfgKoboldActivationDepthM` à +7.00 m si le capteur est conçu pour fonctionner hors eau, sinon corriger. |
| 2 | **Vitesse nominale -3.5 m/s** pendant la descente. La contrainte impose Palier ≤ 4 (3 contacteurs). Il faut définir la correspondance vitesse ↔ palier. | Risque de dépassement du palier autorisé si la consigne n'est pas bridée. | **Définir** une table de correspondance (ex. Palier 4 = 3.5 m/s max). Vérifier que la régulation respecte cette limite. |

**Devoir d'alerte** : ces points sont hors scope de la spécification pure, mais ils conditionnent la sécurité. Ils doivent être remontés à l'orchestrateur.

---

### 2. Modélisation Grafcet `FB_DiveSearch`

#### 2.1 Énumération des états (`E_DiveSearchState`)

| État | Code | Description |
|------|------|-------------|
| Idle | `DS_IDLE` | Repos, attente commande opérateur. |
| PreCheck | `DS_PRE_CHECK` | Vérifications préalables (vitesse ≤ Palier 4, altimétrie ≥ seuil, DI=0). |
| ActivateKobold | `DS_ACTIVATE_KOBOLD` | Mise sous tension contacteur, attente T081, qualification DI=1. |
| Descent | `DS_DESCENT` | Descente bridée Palier ≤ 4, surveillance contact fond. |
| BottomDetected | `DS_BOTTOM_DETECTED` | Contact fond avéré, coupure contacteur, stabilisation. |
| SafeReentry | `DS_SAFE_REENTRY` | Remontée benne fermée jusqu'à `CfgSafeReentryDepthM` (repli après interruption). |
| Abort | `DS_ABORT` | Arrêt d'urgence, alarme, retour à Idle après acquittement. |

#### 2.2 Grafcet détaillé (étapes, actions, réceptivités)

```text
[DS_IDLE] --(Commande opérateur "DiveSearchStart" ET conditions initiales OK)--> [DS_PRE_CHECK]
[DS_PRE_CHECK] --(Vitesse ≤ Palier4 ET Altimétrie ≥ CfgKoboldActivationDepthM ET DI=0)--> [DS_ACTIVATE_KOBOLD]
[DS_ACTIVATE_KOBOLD] --(T081 écoulé ET DI=1)--> [DS_DESCENT]
[DS_DESCENT] --(Front descendant DI (1→0) OU (Timeout descente))--> [DS_BOTTOM_DETECTED]
[DS_BOTTOM_DETECTED] --(Stabilisation atteinte (vitesse ≈ 0) ET contacteur coupé)--> [DS_IDLE]
[DS_SAFE_REENTRY] --(Altimétrie ≥ CfgSafeReentryDepthM)--> [DS_IDLE]
[DS_ABORT] --(Acquittement opérateur)--> [DS_IDLE]
```

**Détail des étapes :**

| Étape | Actions commandées | Réceptivités de transition | Temporisations |
|-------|--------------------|----------------------------|----------------|
| **DS_PRE_CHECK** | - Vérifier `Speed <= Palier4`<br>- Vérifier `Alt >= CfgKoboldActivationDepthM`<br>- Vérifier `DI == 0` (pas de collage) | Toutes conditions OK | - |
| **DS_ACTIVATE_KOBOLD** | - `KoboldContactorCmd := TRUE`<br>- Lancer T081 | T081 écoulé ET `DI == 1` | T081 = 150-300 ms (paramétrable) |
| **DS_DESCENT** | - Consigne descente bridée Palier ≤ 4<br>- Surveillance `DI` | Front descendant `DI` (1→0) | Timeout descente (paramétrable, ex. 60 s) |
| **DS_BOTTOM_DETECTED** | - `KoboldContactorCmd := FALSE`<br>- Arrêt treuil<br>- Stabilisation | Vitesse ≈ 0 ET contacteur coupé | - |
| **DS_SAFE_REENTRY** | - Remontée benne fermée<br>- Consigne montée Palier nominal | Altimétrie ≥ `CfgSafeReentryDepthM` | - |
| **DS_ABORT** | - Arrêt immédiat treuils<br>- Alarme explicite | Acquittement opérateur | - |

#### 2.3 Arbre des causes de blocage & repli

| Cause | Détection | Repli |
|-------|-----------|-------|
| Vitesse > Palier 4 au moment de l'activation | Vérification `DS_PRE_CHECK` | Blocage + alarme "Mesure Kobold impossible : vitesse trop élevée / Palier 5 interdit" → `DS_ABORT` |
| DI ne passe pas à 1 après T081 | Timeout T081 | Défaut alimentation/capteur → `DS_ABORT` |
| Interruption opérateur (relâchement joystick) | Détection front montant sur `JoystickReleased` | Arrêt immédiat → si après activation Kobold ou altimétrie < `CfgSafeReentryDepthM` → `DS_SAFE_REENTRY` (remontée benne fermée) sinon retour `DS_IDLE` |
| Timeout descente sans détection | Timeout | `DS_ABORT` + alarme "Fond non détecté" |
| Collage contact (DI reste à 1) | Vérification `DS_PRE_CHECK` | Blocage + alarme "Contact Kobold collé" → `DS_ABORT` |

---

### 3. Modélisation Grafcet `FB_ExtractionSequence`

#### 3.1 Énumération des états (`E_ExtractionSequenceState`)

| État | Code | Description |
|------|------|-------------|
| Idle | `ES_IDLE` | Repos, attente commande. |
| CloseBucket | `ES_CLOSE_BUCKET` | Fermeture benne en fond de fouille. |
| LiftOff | `ES_LIFT_OFF` | Décollage maîtrisé à basse vitesse. |
| ControlPalier | `ES_CONTROL_PALIER` | Palier de contrôle : vérification stabilisation, centrage, écart codeurs. |
| NominalRise | `ES_NOMINAL_RISE` | Remontée nominale vers la surface. |
| Abort | `ES_ABORT` | Arrêt d'urgence, alarme. |

#### 3.2 Grafcet détaillé

```text
[ES_IDLE] --(Commande "ExtractionStart" ET conditions initiales)--> [ES_CLOSE_BUCKET]
[ES_CLOSE_BUCKET] --(Fermeture terminée (effort atteint OU temps max))--> [ES_LIFT_OFF]
[ES_LIFT_OFF] --(Décollage confirmé (vitesse > 0 ET charge stable))--> [ES_CONTROL_PALIER]
[ES_CONTROL_PALIER] --(Vérifications OK (stabilisation, centrage, écart codeurs < seuil))--> [ES_NOMINAL_RISE]
[ES_NOMINAL_RISE] --(Altimétrie ≥ surface)--> [ES_IDLE]
[ES_ABORT] --(Acquittement)--> [ES_IDLE]
```

**Détail des étapes :**

| Étape | Actions commandées | Réceptivités de transition | Temporisations |
|-------|--------------------|----------------------------|----------------|
| **ES_CLOSE_BUCKET** | - Commande fermeture benne<br>- Surveillance effort moteur | Effort de fermeture atteint OU timeout (ex. 10 s) | Timeout fermeture |
| **ES_LIFT_OFF** | - Consigne montée lente (ex. 0.5 m/s)<br>- Surveillance charge | Vitesse > 0 ET charge stable (pas de surtension) | - |
| **ES_CONTROL_PALIER** | - Maintien à altitude fixe (ex. +0.5 m)<br>- Vérifier écart codeurs M1/M2 < seuil<br>- Vérifier centrage (charge symétrique) | Toutes vérifications OK | Tempo stabilisation (ex. 2 s) |
| **ES_NOMINAL_RISE** | - Consigne montée nominale (ex. 3.5 m/s) | Altimétrie ≥ surface | - |

**Sécurités :**  
- Si écart codeurs > seuil pendant `ES_CONTROL_PALIER` → `ES_ABORT` + alarme "Écart codeurs excessif".  
- Si surtension pendant `ES_LIFT_OFF` → `ES_ABORT` + alarme "Surtension détectée".  
- Toute interruption opérateur → arrêt immédiat, retour `ES_IDLE` (sauf si benne non fermée → maintien fermeture).

---

### 4. Interfaces IHM & Diagnostic

#### 4.1 Messages bandeau IHM

| `OperatorActionId` | `OperatorAction` | `WaitingForOperator` | `WaitingForProcess` |
|--------------------|------------------|----------------------|---------------------|
| `DS_ACTIVATE` | "Activation Kobold en cours" | FALSE | TRUE |
| `DS_DESCENT` | "Descente vers fond" | FALSE | TRUE |
| `DS_BOTTOM` | "Contact fond détecté" | FALSE | TRUE |
| `DS_ABORT` | "Séquence interrompue - Acquitter" | TRUE | FALSE |
| `DS_SAFE_REENTRY` | "Remontée de sécurité - Attendre altitude" | FALSE | TRUE |
| `ES_CLOSE` | "Fermeture benne" | FALSE | TRUE |
| `ES_LIFT_OFF` | "Décollage en cours" | FALSE | TRUE |
| `ES_CONTROL` | "Palier de contrôle" | FALSE | TRUE |
| `ES_RISE` | "Remontée nominale" | FALSE | TRUE |
| `ES_ABORT` | "Extraction interrompue - Acquitter" | TRUE | FALSE |

#### 4.2 Champs pour vue dépannage

**`ST_ChainDiveSearch`** (à définir dans le code) :

| Champ | Type | Description |
|-------|------|-------------|
| `State` | `E_DiveSearchState` | État courant |
| `KoboldContactorCmd` | BOOL | Commande contacteur |
| `KoboldBottomTouch` | BOOL | Signal DI |
| `CurrentSpeed` | REAL | Vitesse actuelle |
| `CurrentAltitude` | REAL | Altimétrie |
| `LastError` | WORD | Code erreur |
| `T081Elapsed` | BOOL | Tempo écoulée |
| `TimeoutDescent` | BOOL | Timeout dépassé |
| `SafeReentryActive` | BOOL | Repli actif |

**`ST_ChainExtractionSequence`** :

| Champ | Type | Description |
|-------|------|-------------|
| `State` | `E_ExtractionSequenceState` | État courant |
| `BucketCloseCmd` | BOOL | Commande fermeture |
| `BucketCloseEffort` | REAL | Effort mesuré |
| `LiftOffSpeed` | REAL | Vitesse décollage |
| `EncoderDiffM1M2` | REAL | Écart codeurs |
| `LoadCentering` | REAL | Indicateur centrage |
| `LastError` | WORD | Code erreur |
| `ControlPalierOK` | BOOL | Validation palier |

---

### 5. Vérification & Validation

- **Grafcet** : chaque transition doit être testée unitairement (simulation ST) avec les cas nominaux, dégradés et de repli.
- **Liaison** : après implémentation, exécuter `G200_check_linkage.py` pour vérifier que les instances sont déclarées/appelées correctement.
- **Gates** : respecter `CODE_QUALITY_STANDARDS.md` (déclaration, liaison, POO, non-régression).
- **Tests** : ajouter des tests unitaires pour chaque état et transition (ex. `pytest`).

---

### 6. Points de vigilance & Devoir d'alerte

- **Activation Kobold hors eau** : à clarifier avec l'orchestrateur (voir §1).
- **Correspondance Palier ↔ vitesse** : à définir précisément dans la spec technique (ex. Palier 4 = 3.5 m/s max). Vérifier que la régulation ne dépasse jamais cette limite.
- **Séquence d'extraction** : le palier de contrôle doit être obligatoire avant remontée nominale, même si les conditions sont bonnes (sécurité).
- **Interruption opérateur** : le repli `DS_SAFE_REENTRY` doit être prioritaire sur toute autre action.

---

### 7. Conclusion

La spécification ci-dessus fournit une base formelle pour l'implémentation des deux FB. Elle respecte les contraintes de sécurité (palier, thermique, repli) et intègre les diagnostics IHM.  
**Avant de coder**, il est impératif de lever les deux points d'ambiguïté signalés (activation hors eau, correspondance palier/vitesse) et de valider cette spec avec l'orchestrateur.