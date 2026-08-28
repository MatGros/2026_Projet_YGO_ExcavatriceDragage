## 🔍 Audit T166 — Verdict CONDITIONAL

### 1. Inversion de dépendance — ⚠️ Dépendance circulaire résiduelle

| Flux | Sens | Statut |
|------|------|--------|
| PRG_02 → PRG_03 | Lecture acquisition | ✅ OK |
| PRG_03 → PRG_04 | Lecture état benne (`BucketState`, `BucketBusy`, etc.) | ⚠️ Couplage direct |
| PRG_04 → PRG_03 | Lecture demandes (`ReqProgram`, `SequenceState`) | ✅ OK |

**Problème** : PRG_03 lit `PRG_04_Treuils_Benne.Data.*` directement. Cela crée une **dépendance circulaire** entre les deux POU.  
**Impact** : maintenabilité réduite, testabilité difficile, risque de régression lors de modifications futures.  
**Recommandation** : passer par un bus de données partagé (ex. `GVL_Sequence`) ou injecter ces états via les entrées des FB (déjà partiellement fait pour `instDiveSearch`/`instExtractionSequence`).  
**Non-bloquant** si documenté et accepté par l'orchestrateur.

---

### 2. Calcul `CoupledUserRequest` — ✅ Aucun décalage de scan

- Calcul direct à partir de `GVL_IHM` et `PRG_02_Acquisition` dans le même scan.
- Pas de dépendance sur des valeurs précédentes.
- Utilisation séquentielle dans le même programme → cohérent.

---

### 3. Bus `ST_SequencePublicState` — ✅ Cohérent et productif

- **Producteur unique** : PRG_03 écrit `Data.SequenceState.*` et `Data.ReqProgram.*`.
- **Consommateur** : PRG_04 lit ces champs.
- Pas de double écriture détectée.
- ⚠️ Vérifier que tous les champs sont initialisés (ex. `DiveState`, `ExtractionState`) avant première exécution.

---

### 4. Sécurité physique & comportement treuils — ⚠️ Points à valider

| Élément | Analyse | Risque |
|---------|---------|--------|
| `ReqClose` | Forcé par `instExtractionSequence.BucketCloseRequest` | ✅ Logique interne FB à vérifier |
| `DescendPermitDiveBucketOpen` | Bloque descente si benne non ouverte pendant plongée | ✅ Logique correcte |
| Write-back `TglBucketAtBottomConfirmed` | Écrit FALSE dans une commande IHM | ⚠️ Conflit potentiel avec opérateur si action simultanée |
| `BypassKoboldBottomTouched` | Activé sur front montant de `M1_M2_KoboldBottomTouch_DI` | ✅ Front correct |

**Point critique** : le write-back de `TglBucketAtBottomConfirmed` doit être **exclusif** avec l'action opérateur. Vérifier que l'IHM ne peut pas réécrire cette commande pendant le même scan (risque de course).

---

### 5. Verdict formel

**CONDITIONAL** — Les points suivants doivent être clarifiés avant validation finale :

1. **Dépendance circulaire** PRG_03 ↔ PRG_04 : documenter ou refactorer.
2. **Write-back IHM** : vérifier l'arbitrage avec l'opérateur (pas de course).
3. **Initialisation** des champs `Data.SequenceState.*` au démarrage.

**Preuves** :  
- `G200_check_linkage.py` non exécuté (diff non fourni) → à lancer.  
- Gates non vérifiées → à exécuter.

---

## 📋 Actions requises avant PASS

- [ ] Exécuter `G200_check_linkage.py` et `run_all_gates.py`
- [ ] Confirmer l'absence de course sur `TglBucketAtBottomConfirmed`
- [ ] Décision orchestrateur sur la dépendance circulaire (acceptation ou refactor)

**Rappel** : ce verdict est basé sur les extraits fournis, pas sur le diff complet. Une revue du diff réel est indispensable.