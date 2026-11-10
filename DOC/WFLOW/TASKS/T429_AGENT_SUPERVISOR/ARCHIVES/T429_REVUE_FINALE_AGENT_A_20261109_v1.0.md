# Rapport d’audit T429 — Revue indépendante, lecture seule

## 0. Limite de session et portée du verdict

Je n’ai pas accès dans cette session aux fichiers du dépôt ni à un terminal d’exécution. Je n’ai donc **ouvert aucun fichier** et **exécuté aucun test**. Les éléments « 43 tests PASS », « 171 tests PASS », « PASS à 1440/390/360 px » sont des **déclarations fournies**, pas des preuves que j’ai pu vérifier.

Conséquence directe : **aucun critère d’acceptation ne peut être formellement validé par cette revue**. Un compte de tests ou une affirmation de PASS ne remplace pas :

- l’inspection des assertions ;
- l’exécution reproductible avec code de sortie ;
- la vérification du contrat YAML ;
- la preuve du comportement réel sur le parcours concerné.

**Verdict provisoire : HOLD — refus de prononcer un PASS final en l’état de la revue.**

---

## 1. Étanchéité aux faux PASS — contre-exemple C1

### Exigence
`_remember_source` doit empêcher qu’une source contenant `NON PASS`, `NOT PASSED`, `FAILED`, `ÉCHEC`, `ERREUR` soit enregistrée ou interprétée comme un succès.

### Évaluation
**Non prouvé.** Sans le code, je ne peux pas confirmer que l’exclusion existe réellement, ni qu’elle est correctement implémentée.

Même si elle existe, un simple filtrage par mots d’échec est fragile. Il faut vérifier au minimum :

- la casse : `non pass`, `NON PASS`, `Not Passed` ;
- les accents et variantes : `échec`, `echec`, `ERREUR`, `erreur` ;
- les séparateurs : `NON-PASS`, `non_pass`, `not/passed` ;
- les formulations composées : `not passed`, `failed`, `failure`, `NOK`, `KO` ;
- le risque inverse : exclure une preuve légitime qui contient le mot `error` dans un contexte non négatif.

Un test unique ne prouve pas l’étanchéité. Le test dédié n’est probant que s’il :

1. injecte explicitement une source `NON PASS` / `NOT PASSED` / `ÉCHEC` ;
2. vérifie l’état final de la mémoire, pas seulement l’absence d’exception ;
3. vérifie qu’aucune preuve acquise ni aucun succès n’est créé ;
4. couvre plusieurs variantes orthographiques et de casse.

### Verdict C1
**INDÉTERMINÉ / NON PROUVÉ.** Le test annoncé peut être utile, mais il n’est pas suffisant comme preuve d’étanchéité sans inspection de son assertion et du code de `_remember_source`.

---

## 2. Mémoire longue terme et détection de drift — AC-F2.9

### Exigence
Le prompt du juge doit injecter conformément à `OMNI_JUDGE_SYSTEM` :

- `## CAP INITIAL GELÉ`
- `## PREUVES ACQUISES`
- `## MÉMOIRE DE SESSION`
- `[AUDIT DE TRAJECTOIRE]` selon un modulo 8 ;
- des propositions `state_update` validées avant persistance.

### Évaluation
**Non prouvé.** Trois points doivent être audités séparément.

#### 2.1 Injection des sections
Il faut vérifier :

- l’ordre exact des sections ;
- les titres exacts, y compris accents et casse ;
- l’absence de duplication ou d’écrasement du cap initial gelé ;
- le moment où la mémoire de session est injectée ;
- le comportement au premier tour et aux tours suivants.

#### 2.2 Audit de trajectoire modulo 8
Le point critique est l’off-by-one. Il faut vérifier si l’audit apparaît aux tours `1, 9, 17…`, `0, 8, 16…` ou `8, 16, 24…`, et si le contrat attendu est respecté. Un test « modulo 8 » qui ne vérifie qu’un seul tour ne suffit pas : il faut vérifier au moins le tour initial, le premier déclenchement, le tour juste avant et le tour juste après.

#### 2.3 Validation des `state_update`
La validation avant persistance doit être démontrée :

- schéma ou allowlist des clés autorisées ;
- contrôle des types ;
- contrôle de taille ;
- refus des clés inconnues ;
- impossibilité d’écraser `CAP INITIAL GELÉ` ;
- séparation entre proposition du juge et écriture réelle ;
- comportement en cas de `state_update` malformé ou partiel.

Une simple désérialisation JSON suivie d’une écriture ne constitue pas une validation.

### Verdict AC-F2.9
**NON VALIDÉ.** Les éléments annoncés sont plausibles mais non vérifiés. Il manque les extraits de code, le contrat exact attendu et les tests d’injection/validation.

---

## 3. Déverrouillage de la matrice Alarm — AC-F2.10

### Exigence
Le passage à `priority="alarm"` doit être préservé pour toutes les catégories sans rétrogradation arbitraire vers `warning`. `alert_basis` doit autoriser `other` et les actions imminentes.

### Évaluation
**Non prouvé.** Il faut une matrice explicite catégorie → priorité, et des tests par catégorie. Un test global qui vérifie seulement qu’un cas produit `alarm` ne prouve pas que les autres catégories ne sont pas rétrogradées.

Points à contrôler :

- aucune branche conditionnelle ne force `warning` par défaut ;
- `alarm` n’est pas écrasé par une normalisation ultérieure ;
- `alert_basis="other"` est accepté par le schéma/contrôleur ;
- les actions imminentes sont bien reconnues ;
- les catégories inconnues ont un comportement défini et non silencieusement dégradé ;
- les tests couvrent toutes les catégories du contrat, pas seulement quelques exemples.

### Verdict AC-F2.10
**NON VALIDÉ.** Sans la matrice réelle et les tests associés, le « déverrouillage » annoncé n’est pas démontrable.

---

## 4. Sécurité déconnexion IHM — AC-F3.10

### Exigence
Le menu latéral gauche `app-sidebar` doit refléter visuellement et de manière persistante au défilement vertical la déconnexion lors d’un `Failed to fetch`.

### Évaluation
**Non prouvé.** Les tests DOM à 1440, 390 et 360 px peuvent valider la mise en page, mais **pas** la persistance d’un état de déconnexion après échec réseau et défilement.

Il faut vérifier :

- un état applicatif explicite `disconnected` / `offline` ;
- l’application d’une classe ou d’un attribut stable sur `app-sidebar` ou son ancêtre ;
- un style `position: fixed` ou `sticky` réellement effectif ;
- le maintien de l’indicateur après re-render ;
- le maintien après défilement vertical ;
- un test qui simule `fetch` en rejet avec `Failed to fetch`, puis vérifie l’état visuel et le défilement ;
- si possible, un libellé textuel ou `aria` en plus de la couleur, pour ne pas dépendre uniquement du visuel.

Un test de layout sans simulation de rejet réseau ne prouve pas AC-F3.10.

### Verdict AC-F3.10
**NON VALIDÉ.** Le PASS responsive ne couvre pas le comportement fonctionnel demandé.

---

## 5. Persistance et continuité

### Exigence
`acquired_proofs`, `session_journal` et `judge_turn_count` doivent être sauvegardés dans `agent-supervision.json` et restaurés au redémarrage.

### Évaluation
**Non prouvé.** Il faut démontrer :

- présence des trois champs dans le schéma persisté ;
- écriture atomique ou au moins robuste ;
- valeurs par défaut pour les anciens fichiers ;
- restauration après redémarrage ;
- absence de perte de `acquired_proofs` lors d’une mise à jour de session ;
- incrément cohérent de `judge_turn_count` ;
- comportement en cas de fichier absent, corrompu ou partiellement ancien.

Un test de sérialisation simple ne suffit pas : il faut un test de type round-trip « écrire → relire → reconstruire le service → vérifier l’état ».

### Verdict persistance
**NON VALIDÉ.** La continuité après redémarrage n’est pas prouvée par les éléments fournis.

---

## 6. Verdict global T429

### Critères formellement validés
**Aucun.** Dans cette session, je n’ai pu vérifier ni le code, ni les tests, ni le contrat. Les PASS annoncés sont des déclarations, pas des preuves auditées.

### Réserves bloquantes
1. Absence de preuve exécutée et reproductible pour C1.
2. Absence de preuve d’injection conforme des sections mémoire et du modulo 8.
3. Absence de preuve de validation des `state_update` avant persistance.
4. Absence de matrice alarm complète et de tests par catégorie.
5. Absence de test fonctionnel `Failed to fetch` + persistance visuelle au scroll.
6. Absence de test de round-trip/redémarrage pour `agent-supervision.json`.
7. Les comptes de tests et les PASS responsive ne constituent pas, en eux-mêmes, une preuve de conformité contractuelle.

### Décision recommandée
**NE PAS PRONONCER LA LIVRAISON FINALE T429 en l’état.** Statut recommandé : **HOLD / RE-AUDIT NÉCESSAIRE**.

Pour lever le HOLD, fournir au minimum :

- extraits ligne par ligne de `_remember_source`, `judge_prompt.py`, validation `state_update`, persistance ;
- extrait du contrat YAML pour AC-F2.9, AC-F2.10, AC-F3.10 ;
- commandes exactes et sorties complètes des tests, avec codes de sortie ;
- test C1 avec assertions sur l’état final ;
- test matrice Alarm par catégorie ;
- test DOM avec rejet `Failed to fetch`, vérification de l’état `app-sidebar` et défilement ;
- test de redémarrage avec restauration des trois structures.

Tant que ces preuves ne sont pas fournies, un verdict positif serait un **PASS de complaisance**. Je ne le signe pas.