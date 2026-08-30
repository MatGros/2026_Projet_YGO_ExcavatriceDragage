# Mémo d'analyse préparatoire — T181 « Gel du treuil » (T181-01 & T181-16)

> **Préambule obligatoire** — Toute tâche déléguée doit respecter les règles du projet. Ce mémo est une pré‑analyse, aucun code n'est produit.

---

## 1. T181‑01 — Blocage §3bis

### 1.1 Contradiction logique actuelle
La règle §3bis exige de **maintenir** le contacteur de sens quand `RequestedStep = 0` mais `RequestedRelayFwd/Rev = TRUE`. Or, la logique de la barrière, dans son état actuel, force `RelayFwd/Rev` à `FALSE` dès que `RequestedStep = 0`. Cette coupure **immédiate** est contradictoire avec le maintien temporisé exigé. Le blocage vient de cette association trop stricte : « pas de pas → pas de sens ».

### 1.2 Origine de `RequestedStep` vs `RequestedRelayFwd/Rev`
| Signal | Producteur possible | Ordre de scan |
|--------|---------------------|---------------|
| `RequestedStep` | Séquenceur de mouvement dans FB_Winch (ou FB externe) | Généré au début du cycle, avant la barrière |
| `RequestedRelayFwd/Rev` | Sortie directe du séquenceur, conditionnée aux états de sécurité | Généré dans le même bloc, mais **indépendamment** du pas (peut rester actif si le pas est 0 pour un motif de maintien, ex. inertie) |

Il est probable que `RequestedRelayFwd/Rev` soit produit **en aval** du calcul de `RequestedStep`, mais sans lien logique fort. La barrière ne peut pas déduire l'intention de maintien seule.

### 1.3 Qui doit piloter le maintien du sens ?
**Recommandation : le producteur d'intention (FB_Winch)** doit émettre un signal explicite `SenseHoldRequest` en cas de besoin de maintien. La barrière ne doit **pas** déduire elle‑même ce maintien à partir de combinaisons de signaux.

#### Options d'architecture

| Option | Description | Avantages | Risques C4 | Impact interface |
|--------|-------------|-----------|------------|------------------|
| **A** | FB_Winch sort `SenseHoldRequest` (booléen) ; la barrière l'utilise pour déclencher la temporisation. | Clarté, rôle strict de la barrière, traçabilité. | Nécessite que `SenseHoldRequest` soit fiable (pas de faille logique dans FB_Winch). | Ajout d'une sortie dans FB_Winch. |
| **B** | La barrière maintient le sens si `RequestedRelayFwd/Rev = TRUE` et `FwdRevSpeedFeedbackOff = FALSE`, indépendamment de `RequestedStep`. | Pas de changement d'interface. | Risque de maintien indéfini si `RequestedRelay` reste bloqué à TRUE ; nécessite T_max et latch de sécurité. | Aucune. |
| **C** | Hybrid : FB_Winch émet `SenseHoldRequest`, mais la barrière ajoute une condition de sécurité (ex. `FwdRevSpeedFeedbackOff` ou T_max) pour se protéger. | Robuste, redondant. | Légère complexité supplémentaire. | Ajout sortie FB_Winch + paramétrage T_max. |

**Recommandation provisoire : option C**, car elle combine la clarté (producteur) et la robustesse (garde‑fou de la barrière).

### 1.4 Feedback simple voie `Mx_ContactorsReleased_DI` : incompatibilité et parades
`Mx_ContactorsReleased_DI` est un retour du contacteur lui‑même, donc si on **maintient** le sens, le contacteur reste fermé → le retour reste **FALSE** → impossible de détecter l'arrêt mécanique. La règle §3bis exige pourtant ce maintien.

| Parade | Description | PLr contribué |
|--------|-------------|---------------|
| Debounce `DropConfirmDelay` (100 ms) | Temporisation pour ignorer les flancs transitoires du feedback | Confirme que le contacteur reste bien fermé lors du maintien |
| Filet T_max (`MaxSenseHoldTime` = 1 s) | Si le retour n'est jamais passé à TRUE après la coupure ordonnée, on force la chute | Limite le temps de maintien anormal |
| Latch `ContactorStuck` | Mémorise le défaut et déclenche SafeStop | Évite la ré‑armement intempestif |
| Feedback vitesse (`FwdRevSpeedFeedbackOff`) | Confirme l'arrêt du moteur (plus fiable que le contacteur) | Permet un maintien plus court, PLr plus élevé (PLr = e possible avec redondance des capteurs) |

PLr atteignable : avec feedback vitesse + T_max + latch, on peut prétendre à **PLr = d** avec une seule voie feedback, voire **PLr = e** si double voie hétérogène. La solution actuelle avec feedback `ContactorsReleased` seul plafonne probablement à **PLr = b/c**.

---

## 2. T181‑01 — Interlock de cadence `FB_WinchRateInterlock`

### 2.1 Définition mesurable de la « cadence »
Trois possibilités :
| Métrique | Définition | Avantages | Inconvénients |
|----------|------------|-----------|---------------|
| `dPalier/dt` | Nombre de changements de palier par seconde | Simple, lié à la séquence de mouvement | Ne reflète pas la vitesse réelle |
| `d\|v\|/dt` | Dérivée de la vitesse (accélération) | Détecte les variations rapides de vitesse | Nécessite un signal de vitesse fiable (T181‑10) |
| `NbPalier/Δt` | Nombre de changements de paliers dans une fenêtre glissante (ex. 5 paliers en 2 s) | Robustesse aux fluctuations, facile à implémenter | Fenêtre à calibrer |

**Recommandation** : utiliser `NbPalier/Δt`, car les paliers sont des états discrets bien définis et le treuil est à plusieurs vitesses par paliers. La dérive temporelle est moins sensible que sur la vitesse.

### 2.2 Double instance (marge vs filet)
| Instance | Emplacement | Rôle | Condition de passivité |
|----------|-------------|------|------------------------|
| **Instance principale** | FB_Winch | Marge safety+, autorise le mouvement en cas de dépassement léger | Aucune (elle est prioritaire) |
| **Instance filet** | PRG_06_Outputs | Seuils nus (valeurs plus serrées) | Doit être **passive** si l’instance principale a déjà réagi et que le mouvement est encore autorisé (par ex. `FinalInterlockGoverned` doit rester FALSE, donc le filet ne doit pas déclencher en nominal) |

**Condition de passivité** : le filet doit être désactivé si l'instance principale a traité le dépassement (ex. via un drapeau `MainRateInterlocked`). Si l'instance principale ne réagit pas (défaillance), le filet devient actif pour garantir la sécurité.

**Test au harnais** : simuler des franchissements de seuils dans les deux instances avec des valeurs différentes ; vérifier que seul l'instance principale active sa sortie, que le filet reste passif, et qu'un scénario de défaillance (instance principale bloquée) déclenche le filet.

### 2.3 Risque `FinalInterlockGoverned` TRUE à tort
Si le filet se déclenche par erreur (faux positif) ou que la logique de passivité est mal calibrée, le programme sera bridé anormalement (le diag passe TRUE). Causes possibles : seuils trop serrés, mauvaise synchronisation entre instances, ou une détection de cadence trop sensible. **Évitement** : calibrer les seuils avec des marges raisonnables, implémenter la passivité par un drapeau explicite, et ajouter une temporisation de validation (ex. 3 événements avant déclenchement).

---

## 3. T181‑16 — Survitesse unifiée

### 3.1 Marge fixe 0.5 / 1.5 m/s : risque et alternative
| Plage de vitesse | Marge 0.5 m/s | Marge 1.5 m/s |
|------------------|----------------|----------------|
| Palier lent (0.5 m/s) | Marge = 100% de la vitesse → détection tardive (seuil à 1.0 m/s) | Marge = 300% → pratiquement aucune détection (seuil à 2.0 m/s) |
| Palier rapide (3.0 m/s) | Marge = 16% → bonne sensibilité | Marge = 50% → acceptable |

**Risque** : une marge fixe sur une plage large (0.5 à 3 m/s) rend la détection inutilisable pour les vitesses lentes. Une **marge relative** est plus adaptée : `seuil = OverspeedRefMps * (1 + k)` avec `k` entre 5% et 10%, plus un minimum absolu (ex. 0.1 m/s) pour les vitesses très lentes.

**Recommandation** : utiliser `seuil = OverspeedRefMps * 1.05 + 0.05 m/s` (marge combinée).

### 3.2 Anti‑calage passage de palier
Méthode : à chaque transition `PalierChanged` (signal fourni par la table T181‑15), activer une temporisation `OverspeedMaskTime` (ex. 100 ms) pendant laquelle la comparaison de survitesse est masquée, ou élargir la marge (multiplier la marge par un facteur 2 pendant cette fenêtre). On peut aussi comparer la vitesse à un seuil dérivé du palier cible plutôt que du palier courant.

### 3.3 Ordre de dépendance avec T181‑15 et T181‑10
| Dépendance | Objet | Condition |
|------------|-------|-----------|
| T181‑15 | Table vitesse apprise `OverspeedRefMps` (table {sens, charge}) | **Obligatoire** : sans table, pas de référence pour la marge |
| T181‑10 | Agrégateur de vitesse `MeasuredSpeedMps` | **Obligatoire** : la survitesse se compare à la vitesse mesurée, donc nécessite un signal fiable |

**Aucune implémentation de T181‑16 ne peut débuter avant que T181‑15 et T181‑10 soient livrés et validés.**

### 3.4 Interaction T181‑01 ↔ T181‑16
| Point partagé | Description | Risque de collision |
|---------------|-------------|---------------------|
| `ContactorStuck` | Latch levé par T181‑01 (maintien anormal) et potentiellement par T181‑16 (si survitesse provoque un maintien ?) | Double déclenchement possible ; il faut une logique de priorité (`ContactorStuck` doit rester un défaut majeur unique) |
| `SafeStop` | Demande d'arrêt d'urgence des deux | Doit être fusionné : si l'un déclenche, les deux doivent arrêter, pas d'écrasement |

**Recommandation** : centraliser dans FB_Safety_Winch la cause du latch et l'ordre de SafeStop ; chaque FB remonte des événements qualifiés (bitmap de causes), et FB_Safety_Winch applique la priorité (ex. survitesse > contacteur collé).

---

## 4. Séquencement recommandé

| Sous‑tâche | Prérequis durs | Peut démarrer maintenant ? | Justification |
|------------|----------------|---------------------------|----------------|
| **T181‑01 – Analyse §3bis** | Aucun | **OUI** – analyse seule | Pas de dépendance, peut être menée en parallèle |
| **T181‑01 – Conception FB_WinchRateInterlock** (définition cadence) | Décision sur la métrique de cadence (section 2.1) | **OUI** – analyse | La définition est purement conceptuelle |
| **T181‑01 – Implémentation §3bis / RateInterlock** | Décision architecture (section 1.3) + validation humaine | **NON** | Nécessite la validation de l'approche |
| **T181‑16 – Étude de marge relative** | Aucun | **OUI** – analyse | Peut être documenté en parallèle |
| **T181‑16 – Implémentation** | T181‑15 (table), T181‑10 (agrégateur) | **NON** | Prérequis matériels indispensables |

---

## 5. Questions ouvertes pour l'humain

1. **Quelle est la plage réelle des vitesses du treuil (min/max)** ? Pour dimensionner la marge relative.
2. **Existe‑t‑il un signal `PalierChanged` déjà disponible** dans FB_Winch (pour l'anti‑calage) ?
3. **Quelle est la fiabilité du feedback `FwdRevSpeedFeedbackOff`** (capteur vitesse redondant ?) pour le PLr visé ?
4. **Comment gérer le mode manuel/test** : la barrière doit‑elle être inhibée ou les seuils élargis ?
5. **Le patch non committé dans FB_WinchOutputInterlock.st** : doit‑il être conservé comme référence pour le redesign, ou totalement ignoré ?
6. **Quelle est la politique de priorité entre `ContactorStuck` et `OverspeedHardTrip`** en cas de simultanéité ?
7. **Le `FinalInterlockGoverned` doit‑il être utilisé comme critère de déclenchement d'un diagnostic** ou uniquement comme indicateur de surveillance ?
