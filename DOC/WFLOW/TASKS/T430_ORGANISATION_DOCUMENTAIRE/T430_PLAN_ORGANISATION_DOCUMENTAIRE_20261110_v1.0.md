# T430 — Terminer la migration documentaire

**État : GO reçu le 2026-11-11, corrections appliquées ; réception finale et revue du garde-fou en cours.**

| Élément | Cadrage |
|---|---|
| Responsable | CDX04, coordination et seul écrivain du lot |
| Criticité / voie | C2, patch d’outillage documentaire ; aucun PLC |
| Convention maintenue | TACHE_TYPE_DESIGNATION_DATE_vX.Y ; T majuscule, suffixe version compatible |
| Dossier courant | DOC/WFLOW/TASKS/T_TEMP (A TRIIER)/ |
| Référence | [Contrat T430](T430_CONTRAT_ORGANISATION_DOCUMENTAIRE_20261110_v1.0.yaml) |

## 1. But et limites

Réparer l’organisation déjà appliquée pour que les fichiers soient retrouvés par le catalogue et les contrôles. Le relevé historique portait sur394 fichiers. Au GO, le snapshot retrouve391 fichiers (AUDITS157, CONTRACTS189, REVIEWS34, TESTS11) : les trois sauvegardes .bak étaient déjà absentes avant T430. Aucune restauration automatique n’a été faite ; leurs copies du snapshot antérieur sont présentes et vérifiées. Ce lot ne classe pas tout T_TEMP dans des dossiers de tâches et ne résout pas les collisions d’identité par déduction.

T384 est distinct : réconciliation historique sans renommage/déplacement. T426 est absorbée par T427, attribuée à CC01. Le dossier TXXX est exclusivement l’exemple de structure. Les modifications concurrentes du Supervisor sont hors scope.

## 2. Constats de départ vérifiés

- G340 ne reconnaît aucun des33 suffixes _VX_Y comme version ; sa découverte est bien récursive, mais son extraction de chemins ignore aussi les espaces/parenthèses.
- G530 ne collecte que le catalogue, aucun contrat du dossier déplacé ; son extraction du nouveau chemin T_TEMP retourne un ensemble vide. Le dossier CONTRACTS contient121 YAML :118 avec section contract:, T273 legacy, T262 contexte et T401 catalogue de signaux. Ce ne sont pas121 contrats équivalents.
- La revue a retrouvé95 références catalogue dont le successeur exact existe dans CONTRACTS. Ce nombre est une baseline de revue, pas un nombre à imposer si un autre acteur fait évoluer le catalogue avant application.
- G525 échoue sur l’ancien GEL ; son code retour ne prouve pas la conformité des transitions.
- T356 écrit par défaut dans un ancien répertoire historique ; rediriger cette sortie vers les annexes conservées risquerait d’écraser des preuves datées. Il génère sept CSV et un JSON ; le neuvième fichier qualifié est une annexe distincte.
- Le manifeste AUDITS mélange racine historique et emplacement courant ; plusieurs liens actifs restent cassés.

## 3. Challenge expert avant implémentation

Deux reviewers indépendants, lecture seule, révision examinée3469b7eddffb2119b420b5fc49714d1f7a949269 : challenge_plan_doc_compat et challenge_plan_doc_organisation. Le coordinateur a confronté les avis aux scripts et au catalogue.

| Proposition initiale | Objection / fait vérifié | Arbitrage retenu |
|---|---|---|
| Restaurer seulement les suffixes | G340 LINK reste aveugle aux chemins avec espaces ; exclusions de versions incohérentes | Traiter découverte, extraction et tests CLI réels, au-delà de la regex |
| Rechercher les fichiers _CONTRAT_ seulement | Perte possible de T273 legacy et des autres sources du corpus historique | Déclarer le corpus et contrôler sa couverture, avec rôles distincts |
| Repointage T356 vers annexes conservées | Remplacerait une mesure ancienne par un run courant | Exiger une sortie explicite neuve, tester hors dépôt, neuf annexes immuables |
| Corriger par numéro de tâche | Six collisions d’objet ; le bon ancien nom est plus discriminant | Mapper le chemin complet exact, refus des correspondances ambiguës |
| Nettoyer toutes les anciennes chaînes | Les citations historiques ne sont pas des liens opératoires | Préserver provenance et qualification historique ; pas de remplacement global |
| Utiliser T384 ou T427 | Périmètres et responsables différents, T384 interdit renommages | T430 dédiée, réservée via API Task Manager |
| Ajouter des rapports de revue séparés | Prolifération documentaire déjà signalée par l’utilisateur | Deux fichiers seulement : PLAN unique et CONTRAT |

## 4. Étapes et points d’arrêt

| # | Étape | Terminé quand |
|---|---|---|
| 0 | Cadrage et challenge | Avis intégrés, contrat contrôlé ; **GO humain avant modifications des gates** |
| 1 | Snapshot et baseline ciblée | Mapping exact, empreintes, sources contrôlées et erreurs actuelles figés ; changements concurrents identifiés |
| 2 | Compatibilité noms/versions et découverte | Suffixes restaurés ; G340/G530 voient réellement les chemins actifs et les versions ; aucun sas exclu aveuglément |
| 3 | Consommateurs | G525 trouve un GEL unique et sort un inventaire ; T356 exige une sortie de nouveau run sans écraser l’histoire |
| 4 | Liens et catalogue | Correspondances exactes appliquées aux liens opératoires ; sauvegardes API avec verrous/révisions ; aucune réaffectation métier |
| 5 | Preuves et réception | Tests positifs/négatifs, empreintes et diff relus, revue indépendante ; dette résiduelle explicitée |

Le catalogue se modifie exclusivement via le Task Manager et son protocole work-lock/edit-flag/révision. Aucun YAML de catalogue réécrit directement. Pas de suppression ni de nettoyage de dossiers. Aucun commit/push sans demande distincte.

## 5. Politique de découverte à respecter

- Racine stable de découverte : DOC/WFLOW/TASKS, incluant le sas courant. Ne pas propager une constante universelle T_TEMP dans chaque consommateur.
- Exclure précisément le dossier exemple TASKS/TXXX, les archives et sauvegardes. Les fichiers réels préfixés TXXX restent inclus.
- G530 conserve la couverture des sources YAML qu’il contrôlait dans le corpus CONTRACTS historique ; distinguer contrats structurés, legacy, contexte et catalogue de signaux. Ajouter les contrats des dossiers de tâche actifs selon leur rôle explicite. La stratégie exacte est testée avant adaptation de la production.
- Parser les champs structurés du catalogue comme YAML ; les liens Markdown et citations libres demandent une extraction adaptée. Une extraction vide d’un chemin présent ne vaut jamais contrôle réussi.
- La qualification historique de la prose et les exclusions de versions doivent rester cohérentes après déplacement. Ne pas modifier des références d’AF historiques pour obtenir du vert.

## 6. Critères de réception

Les critères AC1..AC11 du contrat sont la référence. Ils exigent notamment :391 fichiers du snapshot au GO retrouvés ;33 versions réellement reconnues ; corpus G530 couvert ; chemin avec espaces extrait ; mutation de cible/source détectée ; références exactes migrées avec les autres champs métier préservés ; G525 non vide ; T356 en destination externe neuve ; neuf annexes historiques inchangées ; aucune baseline élargie pour masquer le problème.

Les contrôles globaux peuvent conserver des dettes déjà présentes. Le verdict distinguera correction prouvée, dette préexistante et non vérifié. Pas de validation machine revendiquée.

## 7. Fichiers du dossier

| Fichier | Rôle |
|---|---|
| T430_PLAN_ORGANISATION_DOCUMENTAIRE_20261110_v1.0.md | Ce document unique : plan, décisions, challenge, vérifications et journal |
| T430_CONTRAT_ORGANISATION_DOCUMENTAIRE_20261110_v1.0.yaml | Objectif, périmètre et critères vérifiables |

Aucun autre fichier ou sous-dossier ajouté ici. Les outputs temporaires vont au temp système hors dépôt ; les preuves de réception pertinentes seront synthétisées ici.

## 8. Vérifié / non vérifié et journal

- Vérifié : intégrité des394 fichiers lors de la review précédente ; deux challenges experts ; sources des défauts inspectées ; tâche T430 réservée via API avec work-lock CDX01.
- Non vérifié à ce stade : aucune correction ni preuve de réparation ; les gates ne sont pas annoncés verts.
- 2026-11-10 : reprise demandée, challenge indépendant réalisé, plan corrigé et contrat préparé ; attente du GO avant l’implémentation.

### Prise en charge régularisée — 2026-11-11

- Responsable : **CDX04**, identifiant distinct de CDX01/CDX02/CDX03 déjà cités.
- Session Codex : `01a1c3c8-aebe-7fd1-aeb7-28e5ff83efa6`. Chat : **T430-CDX04 — Organisation documentaire**.
- Autorisation utilisateur : « ok prend et renome chat ... faut faire le dossier dans task », puis « reprend » après interruption.
- Attribution et work-lock T430 régularisés via le Task Manager ; edit-flag libéré après sauvegarde.
- Dossier existant repris : PLAN unique + CONTRAT ; aucun doublon de dossier ou rapport ajouté.
- Étape actuelle : petite étude ciblée avant réparation ; les réparations de gates ne sont pas déclarées commencées.

### Exécution et amendement factuel du 2026-11-11

- GO utilisateur reçu ; responsable/session CDX04 inchangés.
- Le contrat AC1/AC11 a été précisé pour refléter le snapshot réel au GO :391 fichiers, et non394. Trois .bak déjà absents, cause non attribuée. Leurs copies de `contracts_rename_snapshot_7b92i7rb` hors dépôt sont vérifiées ; cela ne signifie ni présence dans le corpus courant ni sauvegarde Git.
- Snapshot d’exécution : `C:/Users/ZEDVIC~1/AppData/Local/Temp/t430_execution_zltl5z5w` (état avant, mappings, migrations API, contrôles avant/après).
- 33 suffixes _vX.Y rétablis ;95 champs contrat migrés par API (seuls contrat/date changent).
- 74 blocs YAML contract actifs :109 références exactes corrigées ; sections execution/validation historiques et identités inchangées. 12 documents : liens opératoires exacts corrigés. Racines historique/courante séparées dans le manifeste.
- Deux défauts du garde-fou détectés par revue indépendante sont corrigés avant réception : destination déclarée invalide et titre Markdown optionnel. Un faux chemin absorbé par G340 a également été corrigé et testé.
