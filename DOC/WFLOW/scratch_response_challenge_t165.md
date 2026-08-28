## Analyse critique du lot T165 — Architecture & Refactor

Avant toute chose : ce lot est **architecturalement sain** sur le papier, mais il cache trois pièges de sécurité et de synchronisation cyclique qui, s'ils ne sont pas traités, **feront régresser la machine en production**. Mon analyse se concentre sur le risque réel, pas sur la conformité formelle.

---

### 1️⃣ T165-B1 — Publication `PRG_02.Data` : faisable, mais la rigueur dépend de la sémantique, pas de la syntaxe

**Faisabilité :** Oui, sans régression mécanique. C'est un refactor de structure de données classique. Le risque n'est **pas** dans la publication, mais dans **ce que publie `PRG_02`**.

**Points de vigilance critiques :**

| Risque | Analyse critique |
|--------|------------------|
| **Miroir ou traitement ?** | Si `ST_AcquisitionInterPrg` est un **simple miroir** des `HwIn`/`Joystick`, la publication est un non-événement (utile pour l'encapsulation, mais zéro valeur ajoutée). Si `PRG_02` **traite** les données (scaling, filtres, qualification codeur D-09), alors **le traitement doit être strictement identique à celui des consommateurs actuels**. **Où est la preuve d'équivalence ?** Il faut un vecteur de test comparatif (entrées connues -> sorties attendues) avant/après. |
| **Producteur unique** | Règle d'or : **personne d'autre que `PRG_02` n'écrit dans `Data`**. Si un consommateur (ex: `PRG_04`) écrit encore dans un champ pour "corriger" une valeur, on recrée un GVL canal caché. Il faut un `PROTECTED`/`PRIVATE` sur le champ ou une gate de compilation qui interdit l'écriture extérieure. |
| **Validité des données** | Il manque un **heartbeat / timestamp** dans `ST_AcquisitionInterPrg`. Si `PRG_02` est en faute (watchdog, blocage), les consommateurs vont lire des **données périmées** sans le savoir. **Ajoutez un `DataValid` ou un compteur de cycle** dans la structure. C'est non négociable pour la sécurité. |
| **Stub `ArmingPermit` (D-01)** | Publier un `TRUE` en dur dans `Data` est un **drapeau rouge sécurité** (ISO 13849). Il est **temporaire**, mais il sera consommé par les séquenceurs. **Il doit être isolé** dans un champ dédié, documenté `STUB`, et **toute logique de sécurité qui s'appuie dessus doit être bloquée par une gate** tant que la qualification réelle n'est pas faite. |

**Verdict B1 :** Faisable sans régression mécanique. **Bloquant si** : pas de preuve d'équivalence du traitement, pas de protection contre l'écriture externe, et pas de flag `DataValid`.

---

### 2️⃣ T165-B2 — Migration des consommateurs : les pièges sont cycliques, pas syntaxiques

La migration des consommateurs (PRG_03/04/05/07) vers `PRG_02.Data` est **le moment où le bug N-1/N va se glisser**.

**Pièges à identifier chirurgicalement :**

- **Décalage de cycle (D-05) :** L'ordre des POU est `PRG_02 -> PRG_03 -> ...`. Si `PRG_02` écrit `Data` à la fin de son cycle, `PRG_03` qui tourne juste après lit les données **du cycle précédent** (N-1). Pour `PRG_03` (Auth), c'est acceptable. **Mais pour `PRG_04` (Winch) qui pilote la puissance (D-08), un délai d'un cycle peut être inacceptable** si le Deadman est relâché. **Il faut définir explicitement si les consommateurs utilisent les données du cycle courant ou du cycle N-1.** C'est un choix d'arbitrage, pas un détail d'implémentation.
- **Front du Deadman (D-02) :** Si le front montant du Deadman est détecté dans `PRG_02` et publié dans `Data`, les consommateurs doivent utiliser **ce front publié** et non re-détecter un front sur la valeur booléenne. **Double détection = double déclenchement** (risque de coupure intempestive ou de redémarrage).
- **Contournement des entrées directes :** Les consommateurs qui lisent encore `HwIn` ou `Joystick` directement bypassent la façade. **La migration doit être atomique** : soit on lit `PRG_02.Data`, soit on lit les entrées. Le mélange des deux provoque des incohérences de scaling.
- **Changement de type (D-03) :** Passer de `SpeedStep` (entier) à `%` (réel) est un **changement de contrat**. Une erreur de conversion (ex: `SpeedStep=100` = 10% physique) provoquera une **vitesse inattendue**. Il faut un test de conversion unitaire, pas juste un changement de variable.
- **Séquenceurs réutilisables (D-04) :** Si `DiveSearch` et `ExtractionSequence` sont extraits de `PRG_04` pour être réutilisables, leur signature doit être **indépendante** de `PRG_02.Data` (passer les valeurs en paramètre, pas lire la GVL globale). Sinon, on recouple fortement les sous-cycles au POU d'acquisition.

---

### 3️⃣ Plan de checkpoint et d'isolation — garantir zéro bug

Le plan proposé est **séquentiel et non régressif**, mais il doit être **implacablement exécuté** :

**Étape 1 : Gel de l'interface (contrat contractuel)**
- Définir `ST_AcquisitionInterPrg` et `ST_ModesCycleInterPrg` **en mode verrouillé**. Aucune modification de champ après le début de T165-B1.
- Documentation du contrat dans `AF_Partie-03` (ou équivalent) avec la sémantique de chaque champ (unité, plage, validité).

**Étape 2 : Tests d'équivalence en simulation (avant migration consommateurs)**
- Capturer un **vecteur de test** (ex: joystick mi-course, codeur en faute, réseau down) sur le code actuel.
- Rejouer ce vecteur sur le code refactoré (B1).
- **Les sorties doivent être bit-à-bit identiques** (ou tolérance défini). C'est le seul moyen de prouver la non-régression du traitement.

**Étape 3 : Migration séquentielle (B2) — jamais en parallèle**
- Ordre imposé : `PRG_03` (Modes) d'abord, puis `PRG_07` (Supervision), puis `PRG_04` (Winch), puis `PRG_05` (Translation).
- **Pourquoi cet ordre ?** `PRG_03` et `PRG_07` sont des consommateurs passifs (ils lisent, ne pilotent pas la puissance). Si un bug survient, la machine peut rester à l'arrêt (safe state).
- Après chaque migration, **recompiler, exécuter les gates (G200, bundle, pytest)** et rejouer le vecteur de test.

**Étape 4 : Isolation du stub (D-01)**
- Le stub `ArmingPermit` doit être **physiquement dans un FB dédié** (ex: `FB_JoystickStub`), pas en dur dans `PRG_02`. Il doit être remplaçable par un `FB_JoystickSafety` sans toucher au reste du code.
- Une **gate de compilation** doit vérifier que le stub est encore présent (si quelqu'un le supprime accidentellement, la gate échoue).

**Étape 5 : Checkpoint final**
- `G200_check_linkage.py --report` doit montrer **toutes** les instances reliées. Pas de `PRG_04` qui lit encore `HwIn` directement.
- Vérifier qu'aucun POU n'écrit dans `PRG_02.Data` (sauf `PRG_02`).

---

### 4️⃣ Arbitrages à remonter impérativement à l'orchestrateur

Je refuse de valider ce lot sans réponse explicite à ces questions :

| # | Question / Arbitrage | Pourquoi c'est bloquant |
|---|----------------------|-------------------------|
| **Q1** | **D-01 (ArmingPermit) :** Qui qualifie les conditions de sécurité réelles ? Quand ? Quel est le plan de retrait du stub ? | Un `TRUE` en dur dans une chaîne de sécurité est une **violation ISO 13849**. La machine peut démarrer sans condition de sécurité. C'est le **risque majeur** de ce lot. |
| **Q2** | **D-05 (Auth N-1) :** Est-il accepté que `PRG_04` (Winch) agisse sur une Auth du cycle précédent ? | Si oui, il faut le documenter comme **tolérance de conception**. Si non, il faut **réordonner les tâches** ou utiliser une mémoire double-buffer (ce qui complexifie le code). |
| **Q3** | **D-03 (Vitesse %) :** Qui définit le mapping 0-100% ? Est-ce linéaire ? Y a-t-il une zone morte ? | Une erreur de scaling = vitesse physique inattendue = **accident potentiel**. Le contrat doit être chiffré, pas intuitif. |
| **Q4** | **D-08 (Entrée puissance) :** Quelle est la définition de "puissance" ? Est-ce un signal matériel (contacteur) ou logique (mode) ? | Si c'est un signal matériel, il doit passer par `PRG_06` (Outputs) et non par `PRG_02`. Sinon, on court-circuite la chaîne de sécurité. |
| **Q5** | **Scope des T165-C0/C1/C2 :** Quelles sont exactement les tâches "C" ? Sont-elles liées à la migration ou indépendantes ? | Sans cette clarté, je ne peux pas juger de la cohérence globale du lot. |
| **Q6** | **Validité des données :** Ajoute-t-on un `DataValid` dans `ST_AcquisitionInterPrg` ? | Sans lui, `PRG_04` peut piloter le treuil avec des données périmées si `PRG_02` plante. C'est un **défaut de sécurité non couvert**. |

---

### 🎯 Verdict final

| Aspect | Évaluation |
|--------|------------|
| **T165-B1** | ⚠️ Faisable, mais **BLOCK** si pas de test d'équivalence de traitement et pas de `DataValid`. |
| **T165-B2** | ⚠️ **BLOCK** si le décalage N-1 pour `PRG_04` n'est pas arbitré, et si le stub `ArmingPermit` n'est pas isolé. |
| **Architecture 7 POU** | ✅ Cohérente, le refactor est une bonne direction. |
| **Sécurité (ISO 13849)** | ❌ Le stub D-01 et l'absence de heartbeat `DataValid` sont des **failles de sécurité** à corriger avant toute mise en production. |

**Recommandation finale :** Le lot est **architecturalement valide mais non déployable en l'état**. Je recommande de **bloquer la validation finale** jusqu'à ce que les arbitrages Q1, Q2 et Q6 soient tranchés par l'orchestrateur, avec une preuve documentée (décision tracée) pour chacun. La rigueur de l'exécution (tests d'équivalence) est le seul rempart contre une régression silencieuse qui se manifesterait en conditions réelles de dragage.