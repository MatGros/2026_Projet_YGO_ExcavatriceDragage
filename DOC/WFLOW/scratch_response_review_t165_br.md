# Rapport de Revue Indépendante — T165-BR (Audit Read-Only PRG_02 B1/B2)

**Date :** 2026-07-29  
**Réviseur :** Expert Senior Automatisme & Sécurité (Agent IA)  
**Portée :** Lots T165-B1 (publication `PRG_02.Data`) et T165-B2 (remappage consommateurs PRG_03/04/05/07)  
**Références :**  
- `DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG02_QUALIFIED_DATA_v1.0.md`  
- `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T165-BR_REVIEW_PRG02.yaml`

---

## 1. Méthodologie et limites

Cette revue est **read-only** et s’appuie exclusivement sur le **résumé des modifications** fourni par l’orchestrateur, ainsi que sur les **contrats de référence** cités (non consultés directement – accès non fourni dans le prompt).  
Aucune vérification directe du code, des fichiers ou des résultats de gates n’a été possible dans cet environnement de revue.  
Par conséquent, les conclusions ci-dessous sont **conditionnelles** à la véracité des informations fournies et doivent être confirmées par une vérification automatisée réelle (G200, gates, lecture de fichiers) avant tout passage en production.

---

## 2. Verdict global

> **⚠️ Verdict proposé : PASS sous conditions**  
> (à confirmer après vérification effective des critères mécaniques)

**Justification :** Le résumé décrit une évolution conforme aux principes d’encapsulation et de contrat inter-PRG. Les modifications annoncées (publication structurée, remappage complet, suppression des accès directs) respectent la philosophie du projet. Cependant, l’absence de preuves tangibles (logs G200, diff de fichiers) ne permet pas de certifier un PASS inconditionnel.  
Si une des vérifications ci-dessous échoue, le verdict deviendra **BLOCK**.

---

## 3. Évaluation des critères d’acceptation (AC1–AC4)

Les critères n’étant pas explicitement détaillés dans le prompt, je les déduis du contexte et du contrat `INTERPRG_CONTRACT_PRG02_QUALIFIED_DATA`. Voici l’évaluation :

| Critère | Description supposée | Évaluation (sur la base du résumé) | Confirmation nécessaire |
|---------|----------------------|------------------------------------|--------------------------|
| **AC1** | Publication structurée des données `Joystick`, `Network`, `EncoderM1/M2`, `DataValid` sous forme de DUT dédiés | ✅ **Conforme** – Le résumé liste explicitement les types `ST_AcquisitionJoystickQualified`, `ST_AcquisitionNetworkDiagnostics`, `ST_AcquisitionEncoderQualified` et la variable `DataValid`. | Vérifier que les DUT sont déclarés dans `PRG_02` et accessibles en `PUBLIC` (pas `PRIVATE`). |
| **AC2** | Remappage complet des consommateurs (PRG_03/04/05/07) vers `PRG_02.Data.*` | ✅ **Conforme** – Le résumé affirme : « Tous les accès directs... ont été remappés » et « 0 accès externe direct à `PRG_02_Acquisition.inst*` ne subsiste ». | Vérifier par une recherche globale (`grep -R "PRG_02_Acquisition.inst"`) qu’aucune référence résiduelle n’existe, y compris dans les commentaires ou les chaînes. |
| **AC3** | Maintien des variables de compatibilité pour ne pas casser d’anciennes références internes | ✅ **Conforme** – Le résumé indique « Maintien des variables de compatibilité ». | S’assurer que ces variables sont marquées `DEPRECATED` et ne sont plus utilisées par de nouveaux développements. |
| **AC4** | Validation mécanique (gates, liaison, bundle) | ✅ **Conforme (annoncé)** – Le résumé mentionne « gates G200 et 22 gates = 100% PASS ». | Exiger la **preuve** (sortie console G200, rapport de gates) dans la restitution finale. |

---

## 4. Vérification de l’encapsulation

### 4.1 Zéro accès externe direct à `inst*`

- **Annoncé :** « 0 accès externe direct à `PRG_02_Acquisition.inst*` ne subsiste dans tout le code. »  
- **Analyse :** C’est le point **critique** de la revue. L’accès direct à une instance privée depuis un autre PRG viole l’encapsulation et peut créer des couplages fragiles.  
- **Vérification nécessaire :** Exécuter une recherche récursive sur tout le projet (y compris dans les fichiers `.exp`, `.xml`, `.txt`) pour exclure toute occurrence de `PRG_02_Acquisition.inst` (ou `instJoystick`, `instDiag*`, `instEncoder*`).  
- **Recommandation :** Si une seule occurrence est trouvée, le lot est **BLOCK** immédiatement.

### 4.2 Producteur unique

- Les données publiées sont produites par `PRG_02_Acquisition` (scan séquentiel). Le résumé confirme que `DataValid` est calculé en fin de scan.  
- **Conformité :** ✅ Aucun autre PRG ne doit écrire dans `Data.*` (producteur unique). Vérifier que les DUT sont en lecture seule pour les consommateurs (pas de `VAR_OUTPUT` ou de `VAR_IN_OUT` sur ces données).  
- **Point de vigilance :** Le résumé mentionne `DataValid` = TRUE si `InputModuleFault=FALSE` ET `instDiagCanOpen.Ready` ET `instDiagEthercat.Ready`. Il faut s’assurer que ces diagnostics sont **fiables** et ne masquent pas une panne réelle. Sinon, `DataValid` pourrait être un faux positif.

### 4.3 GVL-canal-caché

- Aucun GVL supplémentaire n’a été introduit pour « transférer » des données entre PRG. Les données restent dans le PRG producteur.  
- **Conformité :** ✅ conforme à l’esprit du projet.

---

## 5. Respect de la sécurité machine

### 5.1 `ArmingPermit` documenté en stub

- Le résumé mentionne `ArmingPermitDenied` dans le DUT `ST_AcquisitionJoystickQualified`.  
- **Analyse :** Si `ArmingPermit` est un **stub** (toujours FALSE ou non implémenté), il ne doit **jamais** être utilisé comme condition de sécurité. La documentation doit le préciser.  
- **Recommandation :** Vérifier que la documentation du contrat `INTERPRG_CONTRACT_PRG02_QUALIFIED_DATA` indique explicitement que `ArmingPermitDenied` est **purement informatif** et que la validation réelle de l’armement est gérée par le FB de mouvement (ex. `FB_CraneAxis`) avec ses propres conditions.

### 5.2 Deadman et `DeadmanArmed`

- Le résumé publie `DeadmanArmed` et `AtNeutralXY`. Ces signaux sont essentiels pour la sécurité (validation de l’opérateur).  
- **Analyse :** La publication ne change pas la logique de sécurité, mais elle étend la visibilité. Il faut s’assurer que les consommateurs (PRG_03/04/05/07) utilisent ces signaux **uniquement** dans les conditions de validation et ne les modifient pas.  
- **Recommandation :** Vérifier que `DeadmanArmed` est bien une **entrée** des FBs de mouvement et non une sortie pilotable par un autre PRG.

### 5.3 Pas de régression de la logique existante

- Le remappage des accès ne doit pas modifier les valeurs ou les timings.  
- **Risque :** Si les DUT publiés sont des **copies** et non des **alias**, un délai de mise à jour pourrait apparaître (copie en fin de scan vs accès direct).  
- **Recommandation :** Vérifier que les variables publiées sont bien les **mêmes** objets mémoire (adresse partagée) et non des copies. Sinon, un double buffer peut entraîner des incohérences de données entre PRG.

---

## 6. Recommandations pour la famille T165-C (PRG_03)

1. **Validation des preuves** : Avant de lancer T165-C, exiger de l’orchestrateur la sortie complète de `G200_check_linkage.py --report` et le rapport des 22 gates, avec les fichiers modifiés en diff.  
2. **Audit ciblé de `DataValid`** : Vérifier que la logique de `DataValid` couvre tous les cas de défaut (pas seulement `InputModuleFault` et diag réseaux, mais aussi défauts de capteurs individuels). Si ce n’est pas le cas, T165-C devra gérer les données non valides explicitement.  
3. **Test d’intégration** : Prévoir un test de non-régression sur les scénarios de sécurité (deadman relâché, joystick hors neutre, défaut réseau) pour confirmer que le remappage ne modifie pas les comportements temporels.  
4. **Documentation** : Mettre à jour les schémas d’architecture pour montrer la nouvelle interface `PRG_02.Data.*` et supprimer toute référence aux `inst*` externes dans les commentaires.  
5. **Nettoyage** : À terme, supprimer les variables de compatibilité après validation complète (plan de dépréciation).

---

## 7. Conclusion

La modification décrite est **structurellement saine** et va dans le bon sens (amélioration de l’encapsulation). Elle respecte les principes fondamentaux du projet (producteur unique, suppression des accès directs).  
Cependant, en l’absence de preuves mécaniques vérifiables dans ce cadre, je **ne peux pas** certifier un PASS définitif. Je recommande de :

- **BLOCK** si une seule référence externe à `inst*` est trouvée.  
- **PASS** si toutes les vérifications automatisées sont confirmées et si la logique `DataValid` est jugée robuste.  
- **MAJOR** si les DUT sont des copies au lieu d’alias (risque de désynchronisation).

**En l’état, je considère que le lot est PRÊT pour T165-C sous réserve de la production des preuves mentionnées.**

---

**Réviseur :** Expert Senior Automatisme & Sécurité  
**Signature :** (IA) — revue read-only, aucune modification effectuée.