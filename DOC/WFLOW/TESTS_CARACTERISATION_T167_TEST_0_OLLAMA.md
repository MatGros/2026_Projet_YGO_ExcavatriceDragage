## 🎯 Mission : Ajout de cas de tests unitaires formels

**Contexte** : Je rédige les cas de tests à ajouter dans `test_fb_divesearch.st` et `test_fb_extractionsequence.st`. Je n'ai **pas** accès aux interfaces exactes des FB dans ce contexte. Je fournis donc des **blocs de tests formels** basés sur les conventions projet (`AF_Partie-03`, `NAMING_CONVENTION.md`), avec des **hypothèses explicites** à valider avant intégration.

---

### ⚠️ Devoir d'alerte préalable (non négociable)

1. **Impossibilité d'exécution des gates** : Je ne peux pas exécuter `G200_check_linkage.py`, `generate_codesys_bundle.py` ni `run_all_gates.py` dans cet environnement. La vérification mécanique est **PENDING** et doit être exécutée par l'humain avant intégration.
2. **Dépendance aux interfaces FB** : Les noms de variables (`FaultInjection`, `BottomContact`, `KoboldCmd`, `CurrentStep`) sont des **hypothèses**. Le contrat `AF_Partie-03` doit être consulté pour vérifier les noms exacts. Sans cela, les tests sont des **gabarits** à adapter, pas du code final.

---

### 📝 Cas de tests proposés

#### 1. Propagation exacte de `Fault.ErrorId` (FB_DiveSearch & FB_ExtractionSequence)

**Objectif** : Vérifier que le code défaut injecté est propagé sans corruption (pas d'OR binaire, pas de décalage).

```st
// ============================================================================
// TC_DS_FAULT_001 : Propagation exacte de Fault.ErrorId (FB_DiveSearch)
// ============================================================================
// Hypothèse : entrée de test FaultInjection (DINT) pour forcer un défaut.
// Critère : ErrorId = FaultInjection exactement.
FB_DiveSearch_Test.Enable := TRUE;
FB_DiveSearch_Test.FaultInjection := 16#A1;
FB_DiveSearch_Test();
IF FB_DiveSearch_Test.Fault.ErrorId <> 16#A1 THEN
    TEST_FAIL('TC_DS_FAULT_001: ErrorId corrompu. Attendu 16#A1, obtenu %x', FB_DiveSearch_Test.Fault.ErrorId);
END_IF;

// ============================================================================
// TC_ES_FAULT_001 : Propagation exacte de Fault.ErrorId (FB_ExtractionSequence)
// ============================================================================
FB_ExtractionSequence_Test.Enable := TRUE;
FB_ExtractionSequence_Test.FaultInjection := 16#B2;
FB_ExtractionSequence_Test();
IF FB_ExtractionSequence_Test.Fault.ErrorId <> 16#B2 THEN
    TEST_FAIL('TC_ES_FAULT_001: ErrorId corrompu. Attendu 16#B2, obtenu %x', FB_ExtractionSequence_Test.Fault.ErrorId);
END_IF;
```

#### 2. Validation du permis de descente `DescendPermit` (FB_DiveSearch)

**Objectif** : Vérifier les conditions de validation (pas de défaut, pas de contact fond, enable actif).

```st
// ============================================================================
// TC_DS_PERMIT_001 : DescendPermit actif si conditions OK
// ============================================================================
FB_DiveSearch_Test.Enable := TRUE;
FB_DiveSearch_Test.BottomContact := FALSE;
FB_DiveSearch_Test.FaultInjection := 0;
FB_DiveSearch_Test();
IF NOT FB_DiveSearch_Test.DescendPermit THEN
    TEST_FAIL('TC_DS_PERMIT_001: DescendPermit doit être TRUE');
END_IF;

// ============================================================================
// TC_DS_PERMIT_002 : DescendPermit inactif si contact fond actif
// ============================================================================
FB_DiveSearch_Test.Enable := TRUE;
FB_DiveSearch_Test.BottomContact := TRUE;
FB_DiveSearch_Test.FaultInjection := 0;
FB_DiveSearch_Test();
IF FB_DiveSearch_Test.DescendPermit THEN
    TEST_FAIL('TC_DS_PERMIT_002: DescendPermit doit être FALSE sur contact fond');
END_IF;

// ============================================================================
// TC_DS_PERMIT_003 : DescendPermit inactif si défaut actif
// ============================================================================
FB_DiveSearch_Test.Enable := TRUE;
FB_DiveSearch_Test.BottomContact := FALSE;
FB_DiveSearch_Test.FaultInjection := 16#A1;
FB_DiveSearch_Test();
IF FB_DiveSearch_Test.DescendPermit THEN
    TEST_FAIL('TC_DS_PERMIT_003: DescendPermit doit être FALSE sur défaut');
END_IF;
```

#### 3. Coupure de sécurité du contacteur Kobold (FB_DiveSearch)

**Objectif** : Vérifier que `KoboldCmd` passe à FALSE immédiatement sur contact fond ou défaut.

```st
// ============================================================================
// TC_DS_KOBOLD_001 : Coupure Kobold sur contact fond
// ============================================================================
// Précondition : descente active (KoboldCmd = TRUE)
FB_DiveSearch_Test.Enable := TRUE;
FB_DiveSearch_Test.BottomContact := FALSE;
FB_DiveSearch_Test.FaultInjection := 0;
FB_DiveSearch_Test();
IF NOT FB_DiveSearch_Test.KoboldCmd THEN
    TEST_FAIL('TC_DS_KOBOLD_001: Précondition échouée, KoboldCmd doit être TRUE');
END_IF;
// Injection du contact fond
FB_DiveSearch_Test.BottomContact := TRUE;
FB_DiveSearch_Test();
IF FB_DiveSearch_Test.KoboldCmd THEN
    TEST_FAIL('TC_DS_KOBOLD_001: KoboldCmd doit être FALSE sur contact fond');
END_IF;

// ============================================================================
// TC_DS_KOBOLD_002 : Coupure Kobold sur défaut
// ============================================================================
FB_DiveSearch_Test.Enable := TRUE;
FB_DiveSearch_Test.BottomContact := FALSE;
FB_DiveSearch_Test.FaultInjection := 0;
FB_DiveSearch_Test();
IF NOT FB_DiveSearch_Test.KoboldCmd THEN
    TEST_FAIL('TC_DS_KOBOLD_002: Précondition échouée, KoboldCmd doit être TRUE');
END_IF;
FB_DiveSearch_Test.FaultInjection := 16#A1;
FB_DiveSearch_Test();
IF FB_DiveSearch_Test.KoboldCmd THEN
    TEST_FAIL('TC_DS_KOBOLD_002: KoboldCmd doit être FALSE sur défaut');
END_IF;
```

#### 4. Continuité de séquence d'extraction sous intention maintenue (FB_ExtractionSequence)

**Objectif** : Vérifier que la séquence progresse sans régression tant que `Enable` est maintenu.

```st
// ============================================================================
// TC_ES_SEQ_001 : Progression sans régression sous intention maintenue
// ============================================================================
FB_ExtractionSequence_Test.Enable := TRUE;
FB_ExtractionSequence_Test.FaultInjection := 0;
FB_ExtractionSequence_Test();
INT_Step_1 := FB_ExtractionSequence_Test.CurrentStep;
FB_ExtractionSequence_Test();
INT_Step_2 := FB_ExtractionSequence_Test.CurrentStep;
IF INT_Step_2 < INT_Step_1 THEN
    TEST_FAIL('TC_ES_SEQ_001: Séquence a reculé (régression)');
END_IF;
// Vérification que la séquence n'est pas bloquée (progression ou fin)
IF (INT_Step_2 = INT_Step_1) AND (INT_Step_2 < INT_MaxStep) THEN
    TEST_FAIL('TC_ES_SEQ_001: Séquence bloquée sans progression');
END_IF;
```

---

### 🔬 Vérification mécanique (PENDING — exécution humaine requise)

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py
```

⛔ **Je ne peux pas exécuter ces commandes** dans cet environnement. Le bloc `Auto-vérification liaison` est donc **PENDING** et doit être fourni par l'humain après exécution.

---

### 📋 Format de restitution

```text
Auto-vérification liaison (G200_check_linkage.py) — PENDING (non exécutable par l'agent)
Gates : structure / style / liaison / persistance / bundle / pytest = PENDING
Fichiers modifiés : test_fb_divesearch.st, test_fb_extractionsequence.st (ajouts proposés)
Hors scope constaté (devoir d'alerte) :
  - Interfaces FB non vérifiées (FaultInjection, BottomContact, KoboldCmd, CurrentStep) : nécessite consultation AF_Partie-03.
  - Exécution des gates impossible dans cet environnement.
```

---

### 🛡️ Verdict critique

Les tests proposés couvrent les 4 points demandés, mais **ne peuvent pas être validés sans** :
1. La vérification des noms d'interfaces exacts dans `AF_Partie-03`.
2. L'exécution des gates par l'humain.

**Je recommande un BLOCK temporaire** jusqu'à ce que ces deux conditions soient levées.