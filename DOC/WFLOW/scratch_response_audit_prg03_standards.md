# 🔍 AUDIT ARCHITECTURE & STANDARDS — PRG_03 vs RÉFÉRENTIEL PROJET

## 1. Écarts identifiés sur `PRG_03_Modes_Cycle.st`

### 1.1 Structure interne du POU — non-conformité majeure

| Élément attendu (standard) | Constat sur PRG_03 | Criticité |
|---------------------------|--------------------|-----------|
| **Régions `{region "§N ..."}`** | Absentes. Le code est plat, sans délimitation de sections. | 🔴 MAJEUR |
| **Ordre ST imposé** (déclarations → logique → publication) | Respecté globalement, mais sans balisage explicite. | 🟡 MINEUR |
| **Variables locales** | `instModes`, `instCycleSemiAuto` correctement déclarées en `VAR` (privées). | ✅ OK |
| **Interface `VAR_OUTPUT`** | `Data : ST_ModesCycleInterPrg` présent, conforme au contrat de publication. | ✅ OK |

**Impact** : La lisibilité et la maintenabilité sont dégradées. Le standard impose des régions pour faciliter la navigation et l'audit. L'absence de régions rend le code non conforme au référentiel.

### 1.2 Encapsulation — violation directe du principe « producteur unique »

Le code accède **directement aux instances internes** de PRG_04 et PRG_05 :

```pascal
PRG_04_Treuils_Benne.instWinchSync.Fault.Error
PRG_04_Treuils_Benne.instWinchSync.SignedDeltaPosM
PRG_05_Translation.instTranslationM3.RequestedDriveFreqHz
PRG_05_Translation.instTranslationM3.TargetReached
PRG_04_Treuils_Benne.instBucket.Lifecycle.Busy
PRG_04_Treuils_Benne.instBucket.Lifecycle.Done
PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen
PRG_04_Treuils_Benne.Data.BucketState.MechState.IsClosed
```

**Analyse** :
- `instWinchSync`, `instTranslationM3`, `instBucket` sont des **instances internes** (déclarées en `VAR` dans leurs PRG respectifs). Leur accès depuis PRG_03 viole l'encapsulation.
- Seul `PRG_04_Treuils_Benne.Data` est un accès au bus public (correct), mais il est mélangé avec des accès internes.
- Le standard AF-02 impose que **toute communication inter-PRG passe par les bus publics `Data`** (ex : `PRG_04.Data`, `PRG_05.Data`). Les internals ne doivent jamais être traversés.

**Conséquences** :
- Couplage fort entre PRG_03 et l'implémentation interne de PRG_04/05.
- Toute modification interne (renommage, refactor) casse silencieusement PRG_03.
- Impossible de tester PRG_03 isolément (dépendances directes).

### 1.3 Raccordement pipeline AF-02 — partiellement conforme

Le pipeline attendu : `PRG_02 → PRG_03 → PRG_04 → PRG_05 → PRG_06 → PRG_07`.

- PRG_03 **consomme** des données de PRG_04 et PRG_05 (en aval dans le pipeline) → **inversion de flux** par rapport au pipeline unidirectionnel.
- Le standard AF-02 impose un flux **descendant** : chaque PRG ne lit que les données des PRG **précédents** (ou de son propre bus). Ici, PRG_03 lit des données de PRG_04/05 qui sont **après** lui dans le pipeline → **violation de la séquence**.

**Exemple concret** : `PRG_03` utilise `PRG_04.instWinchSync.Fault.Error` pour décider du mode. Or PRG_04 est exécuté **après** PRG_03 dans la tâche. Cela crée une **dépendance de données inversée** et un risque de **lecture de valeurs non actualisées** (décalage d'un cycle).

### 1.4 Contrat de publication `Data : ST_ModesCycleInterPrg`

- Le type est correctement utilisé en `VAR_OUTPUT`.
- La publication est conditionnelle (`IF instModes.Auth.Mode = SEMI_AUTO`), avec neutralisation déterministe sinon. C'est **conforme** à l'esprit du standard (pas de valeurs indéterminées).
- **Point d'attention** : la neutralisation doit être **exhaustive** (tous les champs de `Data.ReqProgram` et `Data.SequenceState` remis à zéro/valeur neutre). À vérifier dans le code complet.

---

## 2. Conformité des autres PRG (PRG_02, PRG_04, PRG_05, PRG_06, PRG_07)

**Hypothèse** : Nous n'avons pas le code source de ces PRG dans la mission. L'audit se base sur les patterns observés et les standards.

| PRG | Conformité estimée | Points de vigilance |
|-----|-------------------|---------------------|
| **PRG_02** | 🟡 Partielle | Doit publier `Data` (bus amont) et ne pas accéder aux internals de PRG_03. Vérifier que ses sorties sont uniquement via `Data`. |
| **PRG_04** | 🟡 Partielle | Expose `Data` (correct) mais **laisse ses internals accessibles** (`instWinchSync`, `instBucket`). Le standard exige que les internals soient **privés** (déclarés en `VAR` et non exposés). |
| **PRG_05** | 🟡 Partielle | Même constat que PRG_04 : `instTranslationM3` est accessible. |
| **PRG_06** | 🟢 Probablement conforme | S'il consomme uniquement `PRG_05.Data` et publie `PRG_06.Data`, il respecte le pattern. |
| **PRG_07** | 🟢 Probablement conforme | Idem, en bout de chaîne. |

**Risque systémique** : Si PRG_04/05 exposent leurs internals, **tous les PRG en aval** peuvent être tentés de les utiliser directement, perpétuant le couplage. Il faut une **revue globale** de l'encapsulation.

---

## 3. Actions correctives pour aligner PRG_03 à 100%

### 3.1 Restructuration interne (obligatoire)

1. **Ajouter les régions** conformément au standard :
   ```pascal
   {region "§1 ARBITRAGE DES MODES"}
   instModes(...);
   {endregion}

   {region "§2 SÉQUENCEUR DE CYCLE"}
   instCycleSemiAuto(...);
   {endregion}

   {region "§3 PUBLICATION DU BUS INTER-PRG"}
   Data.Auth := instModes.Auth;
   ...
   {endregion}
   ```

2. **Réordonner les appels** pour respecter le pipeline : PRG_03 ne doit **jamais** lire des données de PRG_04/05. Il doit **uniquement** :
   - Lire `PRG_02.Data` (amont)
   - Publier `Data` (aval)

### 3.2 Correction de l'encapsulation — refonte des flux

**Problème** : PRG_03 a besoin d'informations de PRG_04/05 (erreurs, positions, états). Or le pipeline est descendant.

**Solution conforme** : **Inverser la dépendance** en déplaçant la logique de décision dans le PRG **propriétaire** des données, ou en **remontant** les informations nécessaires via le bus amont.

**Deux options** :

| Option | Description | Effort | Risque |
|--------|-------------|--------|--------|
| **A. Remonter les données** | Ajouter dans `PRG_04.Data` et `PRG_05.Data` les champs nécessaires (ex : `WinchSyncError`, `TranslationBusy`). PRG_03 lit ces bus publics. | Moyen | Faible — nécessite d'étendre les DUT et de mettre à jour les producteurs. |
| **B. Déplacer la logique** | Transférer l'arbitrage des modes dans un FB dédié appelé par PRG_04 (qui a accès à ses internals) et publier le résultat via `PRG_04.Data`. PRG_03 ne fait que router. | Élevé | Moyen — change l'architecture. |

**Recommandation** : **Option A** — plus simple, respecte le pipeline, et améliore la testabilité.

### 3.3 Mise en conformité du contrat de publication

- Vérifier que `Data.ReqProgram` et `Data.SequenceState` sont **entièrement** neutralisés dans le `ELSE`.
- Ajouter un **commentaire de traçabilité** indiquant la source des données (ex : `// Données issues de PRG_04.Data`).

### 3.4 Vérifications mécaniques après correction

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py
```

**Critère de succès** : `G200_check_linkage.py` doit montrer que PRG_03 ne référence **aucune** instance interne de PRG_04/05, uniquement leurs bus `Data`.

---

## 🚨 Devoir d'alerte

- **Risque fonctionnel immédiat** : La dépendance inversée (PRG_03 lit PRG_04/05) peut provoquer des **incohérences de cycle** (données d'un cycle précédent). À corriger en priorité.
- **Non-conformité globale** : Si PRG_04/05 exposent leurs internals, **tous les PRG** doivent être audités. Proposer une **revue systématique** de l'encapsulation.
- **Impact sur la sécurité** : Toute erreur de synchronisation entre PRG_03 et PRG_04/05 peut affecter les modes machine (ex : passage en semi-auto avec des données obsolètes). **Criticité haute**.

---

## Verdict final

| Critère | Statut |
|---------|--------|
| Structure interne (régions) | ❌ NON CONFORME |
| Encapsulation | ❌ NON CONFORME (accès directs) |
| Pipeline AF-02 | ❌ NON CONFORME (dépendance inversée) |
| Contrat de publication | ✅ PARTIELLEMENT CONFORME |
| **Conformité globale** | **🔴 MAJEUR — correction obligatoire avant mise en service** |

**Prochaine étape** : Valider l'option A (remontée des données via bus publics) avec l'orchestrateur, puis implémenter les correctifs.