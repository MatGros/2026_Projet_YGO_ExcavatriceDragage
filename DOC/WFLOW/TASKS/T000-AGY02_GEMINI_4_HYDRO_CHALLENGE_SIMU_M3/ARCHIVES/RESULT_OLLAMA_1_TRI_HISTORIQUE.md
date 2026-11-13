🟡 **ADVISORY — Tri historique partiel, faux verts non tranchés**

**Verdict :** Les extraits établissent le mécanisme nominal d’arrêt en SEMI_AUTO et contredisent la coupure instantanée du frein au capteur pour la run `Suivi_93`, mais aucune preuve fournie ne couvre la petite vitesse 5–10 Hz, la butée électrique, le choc mécanique ni la position simulée.  
**Impact :** Ne pas conclure que « la simulation s’arrête proprement » valide le comportement réel ; lancer l’échantillonnage ciblé avant toute correction.  
**Durée/Horodatage :** analyse documentaire sur extraits ; horodatage non disponible, artefacts datés 2026-10-30/2026-11-01.

---

## Niveau 1 — Invariants

1. [✅ PASS] Lecture seule respectée : aucune modification, aucun commit, aucune exécution machine réelle.
2. [✅ PASS] Les catégories ci-dessous séparent preuve citée, hypothèse et contradiction.
3. [❌ FAIL] Audit direct des 74 artefacts non réalisé : aucun JSON/MD complet n’est fourni ; le verdict « faux vert » n’est pas établi.
4. [❌ FAIL] Le symptôme « petite vitesse → choc butée » n’est couvert par aucune preuve fournie : pas de position simulée, pas de modèle de butée, pas d’essai 5–10 Hz.
5. [✅ PASS] Le mécanisme nominal d’arrêt SEMI_AUTO est documenté : `PRG_05:400-405`, `PRG_05:715-721`, `FB_CycleSemiAuto:363-367`.
6. [✅ PASS] La coupure instantanée du frein au capteur est contredite pour `Suivi_93` : Trémie à 70,27 s, `BrakeReleaseRequest` 1→0 à 71,22 s.
7. [❌ FAIL] La cause du dépassement n’est pas départagée : frottement, chariot libre, délai frein 2 s, coupure dure neutralisée restent candidats.
8. [✅ PASS] Plan d’échantillonnage proposé : 5 fichiers sur 27, soit 18,5 %, dans la fourchette 10–20 %.

---

## Niveau 1 bis — Argumentaire technique

La preuve la plus forte est la trace `Suivi_93` : elle établit une chronologie, pas un comportement général. Le code explique le serrage du frein à la sortie X14, pas le choc mécanique réel. Les essais dynamiques couvrent l’intégration du frottement, pas l’approche à 5–10 Hz ni la butée. Les séries `INTEGRATION_M3_CYCLE_REJEU_R4` à `R21` et les `REVIEW_*` ne sont pas recevables sans lecture directe de leurs preuves.

---

## 1. Tri des pistes déjà testées

### A. Vérifié avec preuve citée — non rejoué

- Chronologie `Suivi_93` : `Step` 18→14 à 58,15 s ; frein demandé à 61,14 s ; frein ouvert à 61,24 s ; consigne 50→5 Hz à 66,65 s ; Trémie à 70,27 s avec `ReqTremieSemantic` et `EffectivePermitM3_Tremie` à 0 au même scan ; variateur coupé à 70,37 s ; `Step` 14→15 et `BrakeReleaseRequest` 1→0 à 71,22 s ; contact frein 1→0 à 71,33 s. Réf. `PASSATION_T417`, §4 lignes 65-79.
- En SEMI_AUTO, M3 n’est autorisé qu’en AX2 et AX14 ; hors de ces étapes, `BrakeReleaseRequest := FALSE`. Réf. `REPRISE_PREUVES`, lignes 119-123 ; `PRG_05_Translation.st:400-405` et `715-721`.
- `TranslationStopTimer` = `AT_Tremie AND NOT Busy`, 500 ms ; `Busy` = vitesse > 0,5 Hz. Réf. `PASSATION_T417`, lignes 91-93 ; `REPRISE_PREUVES`, lignes 119-120.
- Coupure dure neutralisée si `ReqTremieSemantic` tombe au même scan que le capteur : `M3_TremieHardStopActive := DI AND ReqTremieSemantic`. Réf. `PASSATION_T417`, lignes 70-71 et 93 ; `PRG_06_Outputs.st:431-443`.
- Coupure variateur au scan capteur : permission `AND NOT DI` ; trace `DriveFreqCmd_Hz=0` et `DriveControlWord=0` à 70,37 s. Réf. `PASSATION_T417`, ligne 97.
- Configuration simulation : `PhysicalBrakeActive` et `CartFreeActive` à TRUE via `GVL_Simulation.st:79/84`, passés par `FB_SimBench.st:697`, malgré les défauts FB à FALSE. Réf. `PASSATION_T417`, lignes 43-46.
- CI `L_SIMULATION` : 6 PASS / 6 FAIL sur la base et après `0990a225`, mêmes échecs ; `FB_Sim_Translation` ne compile pas à cause de `FullTravelTimeS`. Réf. `PASSATION_T417`, lignes 132-139.
- Gates palier C : 8 échecs sur 61, identiques à la base sauf G390 qui passe après régénération. Réf. `PASSATION_T417`, lignes 141-144.
- Correction dissipative : `M3-DYN-030` passe après frottement borné ; 13/14 PASS ; `M3-DYN-100` reste rouge. Réf. `REPRISE_PREUVES`, lignes 109-111.
- Incohérence historique `M3-DYN-100` : test `555327be` attend un PDO indépendant du balancement ; `6cce0c93` ajoute le droop ; aucune sémantique validée par trace qualifiée. Réf. `REPRISE_PREUVES`, lignes 125-127.

### B. Hypothèse non prouvée

- Le chariot libre est la seule voie où le frottement agit ; son effet sur le dépassement Auto n’est pas démontré. Réf. `PASSATION_T417`, lignes 55 et 108-109.
- « Le frottement cause le dépassement » : seul le chemin frein serré est testé ; le chemin chariot libre ne l’est pas. Réf. `PASSATION_T417`, lignes 107-108.
- « Maintenir le frein jusqu’à l’arrêt est plus sûr mécaniquement » : non démontré. Réf. `PASSATION_T417`, ligne 107.
- La coupure dure neutralisée est un bug de séquencement ou un choix : non tranché. Réf. `PASSATION_T417`, ligne 93.
- Le délai frein de 2 s est causal : source citée mais non départagée des trois autres mécanismes. Réf. `PASSATION_T417`, ligne 95.
- Le −0,45 m n’est pas reproduit ; `SimM3ObsPositionTrue_M` n’est pas publié dans `GVL_Troubleshooting`. Réf. `PASSATION_T417`, ligne 109.
- `ActualFrequencyHz` à l’échelle ×100 : déduit des valeurs, à confirmer. Réf. `PASSATION_T417`, ligne 110.
- Import CODESYS du bundle et du template de trace : non testé. Réf. `PASSATION_T417`, lignes 155 et 163.
- G518 : réécriture des 19 tests non faite, laissée en attente. Réf. `PASSATION_T417`, lignes 139-143.
- Les verdicts `INTEGRATION_M3_CYCLE_REJEU_R4` à `R21` et `REVIEW_*` sont non lus et non vérifiés dans cette session : toute mention « PASS » y reste une hypothèse documentaire.

### C. Contredit / obsolète

- « `BrakeReleaseRequest` tombe instantanément au capteur Trémie » : contredit pour `Suivi_93` ; chute à 71,22 s, pas à 70,27 s. Réf. `PASSATION_T417`, lignes 13 et 105.
- « La run est forcée donc inutilisable » : obsolète ; seule l’entrée en X14 est forcée, le déplacement dans X14 est normal. Réf. `PASSATION_T417`, ligne 82.
- « Une seule trace ne suffit pas » : formulation corrigée ; la simulation est répétable, trois runs identiques sont proposés. Réf. `PASSATION_T417`, ligne 83.
- « AUTO » : contredit ; `E_Mode` ne contient que DISABLE, MAINT_N1, MAINT_N2, SEMI_AUTO. Réf. `PASSATION_T417`, ligne 111.
- « Le frottement est refuté » : trop fort ; seul le chemin frein serré est testé. Réf. `PASSATION_T417`, ligne 108.
- « `CODE_DiffBundle.xml` contient 3 objets » : faux ; il en contient 13. Réf. `PASSATION_T417`, ligne 156.
- « G390 échoue » : obsolète après régénération du bundle ; G390 passe. Réf. `PASSATION_T417`, ligne 141.
- « `PhysicalBrakeActive` / `BrakePhysicalActive` à TRUE dans les FB » : corrigé à FALSE ; la valeur TRUE vient de la GVL. Réf. `PASSATION_T417`, lignes 24 et 45.
- Contrat AC2 à 200 ms d’ouverture contre code à 100 ms / 90 ms : contradiction documentaire ouverte. Réf. `PASSATION_T417`, ligne 51 ; `REPRISE_PREUVES`, ligne 129.
- `DecelRate_HzPerS` 20 et `TimeConstant_S` 0,03 présentés comme décrivant le banc intégré : contredit par E01 ; `SimBench` ne les transmet pas, `FB_Sim_Translation` transmet 25 Hz/s et 0,15 s. Réf. `PASSATION_T417`, lignes 49-50 ; `REPRISE_PREUVES`, ligne 22.
- `M3-DYN-050` avec seuil statique implicite historique : attente devenue incompatible avec le défaut 0,35 ; le test déclare désormais 0,1. Réf. `REPRISE_PREUVES`, lignes 25 et 103.

---

## 2. Angles morts sur la petite vitesse et le choc butée

1. **Position et butée non instrumentées.** Aucune preuve fournie de `SimM3ObsPositionTrue_M` dans la trace ou la GVL ; aucun modèle de butée électrique ni de contact mécanique. Le simulateur peut s’arrêter proprement sans représenter le choc. Réf. `PASSATION_T417`, lignes 109 et 164.
2. **Petite vitesse 5–10 Hz non testée.** `Suivi_93` contient une consigne 50→5 Hz, mais pas d’approche stabilisée à 5 ou 10 Hz. Les répliques citées utilisent 20 Hz et 40 Hz. Réf. `PASSATION_T417`, lignes 70 et 121-126.
3. **Auto vs Manu mélangé.** Le mode réel est SEMI_AUTO ; l’arrêt manuel réel ≈10 cm n’est pas reproduit ni comparé à SEMI_AUTO/MAINT_N1/N2. Réf. `PASSATION_T417`, lignes 12 et 111.
4. **Commande de frein, état mécanique et contact confondus.** La trace contient `BrakeReleaseRequest`, `M3_BrakeIsOpen_DI` et `TranslationState.BrakeCmd`, mais pas courant bobine, force ou couple. Le délai 2 s n’est pas départagé. Réf. `PASSATION_T417`, lignes 45 et 95.
5. **Chariot libre non instrumenté.** `CartFreeActive=TRUE` en simulation ; c’est la seule branche où le frottement agit, mais son effet à basse vitesse n’est pas mesuré. Réf. `PASSATION_T417`, lignes 46 et 55.
6. **Coupure dure possiblement morte au scan capteur.** Si `ReqTremieSemantic` tombe au même scan que `M3_PosTremie_DI`, `M3_TremieHardStopActive` reste faux et la coupure dure est inopérante. Ce scénario n’est pas testé à 5–10 Hz. Réf. `PASSATION_T417`, lignes 70-71 et 93.
7. **Seuil `Busy` absolu à 0,5 Hz.** À 5 Hz, le seuil représente 10 % de la consigne ; à 10 Hz, 5 %. Le démarrage du timer 500 ms varie donc avec la vitesse. Aucun essai ne quantifie cet effet. Réf. `PASSATION_T417`, lignes 91-93.
8. **Résolution temporelle insuffisante pour le choc.** Trace `Suivi_93` à pas ~100 ms ; l’ancienne trace 27 a un minimum 47 ms, médiane 100 ms, maximum 153 ms. Un contact de butée peut être plus court. Réf. `PASSATION_T417`, ligne 61 ; `REPRISE_PREUVES`, ligne 61.
9. **Clamp fréquentiel seulement.** `M3_ActualFreqHz` est borné en fréquence, pas en position ; un dépassement de position peut rester invisible. Réf. `PASSATION_T417`, ligne 52.
10. **Faux vert possible dans la chaîne R4–R21.** Les séries `INTEGRATION_M3_CYCLE_REJEU_*` et `REVIEW_*` ne sont pas auditées ; un PASS déclaré sans test exécuté, sans position et sans scénario basse vitesse serait un faux vert.

---

## 3. Plan d’échantillonnage 10–20 %

Population : 19 fichiers `INTEGRATION_M3_CYCLE_REJEU_*` + 8 fichiers `REVIEW_*` = 27.  
Cohorte prioritaire : 5 fichiers, soit 18,5 %.

1. `INTEGRATION_M3_CYCLE_REJEU_R21_20261101.json` — état cumulatif le plus récent. À auditer pour vérifier que le PASS final est adossé à des tests exécutés, des IDs, un exit code et une couverture AX14/AX15, basse vitesse, frein et position.
2. `INTEGRATION_M3_CYCLE_REJEU_R19_20261101.json` — pivot direct des revues `OVERRUN_R19`. À comparer à R21 pour détecter une régression masquée ou un PASS sans preuve.
3. `REVIEW_OVERRUN_R19_DEEPSEEK_20261101.md` — revue directe du dépassement. À mapper claim par claim vers les données R19 ; toute affirmation sans test ID, trace ou fichier:ligne est à rejeter.
4. `REVIEW_OVERRUN_R19_GLM_20261101.md` — seconde revue indépendante du même objet. Le désaccord DeepSeek/GLM est un détecteur de faux vert ; le consensus non prouvé reste non prouvé.
5. `REVIEW_STOP_P1_GLM_20261101.md` — revue directe de l’arrêt P1. À vérifier sur la séparation commande frein / contact / position et sur la chronologie 500 ms / 2 s.

Si R19 et R21 divergent sans explication, ajouter en réserve `INTEGRATION_M3_CYCLE_REJEU_R4_20261101.json` pour retrouver le point de départ de la série. Si le fichier 5 ne cite pas R19/R21, remplacer par `REVIEW_STOP_P1_DEEPSEEK_20261101.md` pour obtenir une paire appariée.

---

## Niveau 2 — Plan d’action chirurgical

1. **Localisation :** `INTEGRATION_M3_CYCLE_REJEU_R21_20261101.json`.  
   **Ancre :** champs de verdict, tests, timestamps, commit, exit code, couverture.  
   **Action exacte :** charger le JSON, vérifier que chaque PASS possède un ID de test, une commande exécutée, un exit code 0 et une preuve non vide ; vérifier la présence des scénarios AX14/AX15, 5–10 Hz, frein et position.  
   **Outil déterministe :** `python -m json.tool` puis script Python d’assertions ; rejouer les tests cités avec `run_tests.py` et les gates avec `run_all_gates.py`.  
   **Risque si ignoré :** accepter un faux vert final et calibrer le modèle sur un scénario non couvert.

2. **Localisation :** `INTEGRATION_M3_CYCLE_REJEU_R19_20261101.json`.  
   **Ancre :** IDs de tests, résultats, dates, commit, liens vers revues.  
   **Action exacte :** comparer R19 à R21 ; lister les tests supprimés, ajoutés ou passés de FAIL à PASS sans justification ; vérifier que la revue OVERRUN_R19 porte bien sur les mêmes données.  
   **Outil déterministe :** script Python de diff JSON ; `git diff --no-index` ou `diff -u` ; `sha256sum`.  
   **Risque si ignoré :** une régression antérieure peut être masquée par le dernier état vert.

3. **Localisation :** `REVIEW_OVERRUN_R19_DEEPSEEK_20261101.md`.  
   **Ancre :** phrases contenant PASS, validé, vérifié, preuve, test, trace, commit.  
   **Action exacte :** extraire chaque affirmation et exiger un fichier:ligne, un ID de test ou une trace ; marquer sans preuve comme hypothèse.  
   **Outil déterministe :** `rg -n "PASS|valid|vérifi|preuve|test|trace|commit"` puis table de correspondance générée par script Python.  
   **Risque si ignoré :** une revue narrative peut être prise pour une validation mécanique.

4. **Localisation :** `REVIEW_OVERRUN_R19_GLM_20261101.md`.  
   **Ancre :** mêmes claims que DeepSeek, plus désaccords explicites.  
   **Action exacte :** comparer les deux revues ; tout point où l’une valide et l’autre conteste devient un point de contrôle obligatoire contre R19.  
   **Outil déterministe :** `diff -u` après normalisation ; `rg -n` ; script Python de rapprochement des claims.  
   **Risque si ignoré :** un consensus apparent peut masquer une preuve manquante.

5. **Localisation :** `REVIEW_STOP_P1_GLM_20261101.md`.  
   **Ancre :** `BrakeReleaseRequest`, `BrakeIsOpen_DI`, `BrakeCmd`, `PosTremie_DI`, butée, P1, 500 ms, 2 s.  
   **Action exacte :** vérifier que la revue ne confond pas commande, contact et position ; exiger une chronologie mesurée et non une conclusion de code.  
   **Outil déterministe :** `rg -n` ciblé ; script Python de parsing des timestamps si des traces sont citées.  
   **Risque si ignoré :** répéter l’erreur « coupure instantanée au capteur » ou valider un arrêt sans mesure de position.

---

## Décision recommandée

Ne pas modifier le code ni calibrer le modèle sur la seule affirmation « la simulation s’arrête proprement ». Auditor d’abord R21, R19 et les revues OVERRUN/STOP_P1. Tout PASS sans test exécuté, sans position simulée ou sans scénario 5–10 Hz doit être classé **faux vert potentiel** et bloquer la conclusion mécanique. Ensuite seulement, instrumenter la position et la butée, puis rejouer des approches stabilisées à 5 et 10 Hz.