# T431 — Complément T429 : audits spécialisés asynchrones et mémoire sourcée

**État : PLAN PROPOSÉ — réalisation non autorisée.** Préparation documentaire demandée le 2026-11-12. Coordinateur de cette préparation : CDX05. Responsable de réalisation : à désigner. Criticité C2 outillage; aucun rôle de validation de sécurité machine.

## 0. Contrat et suivi — document unique de référence

**Règle utilisateur :** cette fiche Markdown réunit contrat, objectifs, périmètre, plan, critères, arbitrages et suivi. Aucun contrat YAML parallèle. Les fichiers de PREUVES sont des annexes, pas un second suivi.

- **Tâche :** T431; parent T429; criticité C2; stratégie patch.
- **Objectif :** préparer et challenger le complément de T429 — audits spécialisés asynchrones, mémoire sourcée et visibilité des états.
- **Préparation :** terminée; deux analyses reçues et arbitrées. Correction documentaire du 2026-11-12 : contrat et suivi intégrés ici sur demande utilisateur.
- **Validation humaine du plan :** en attente. Réalisation produit non démarrée, aucun GO code.
- **Coordinateur de préparation :** CDX05. Responsable de réalisation et mainteneur des contrôles : à désigner au GO.
- **Prochaine action :** relecture humaine et arbitrages de J0, puis gel du périmètre avant réalisation.
- **Périmètre autorisé pendant la préparation :** ce dossier documentaire et la fiche T431 du catalogue par API uniquement; exclusions détaillées au §4.
- **Modèle demandé pour les deux analyses :** deepseek-v4.1-flash:cloud; identité renvoyée et couverture documentées au §10 et dans les métadonnées.

### Critères d'acceptation de la préparation

- **AC-P1 — Deux analyses DeepSeek distinctes examinent le dossier documentaire T429 et les sources actuelles; leurs couvertures et limites sont déclarées.** Vérification : Lecture des rapports A/B non vides et du manifeste SHA256; liste explicite des sources absentes.
- **AC-P2 — Le plan couvre ordonnancement, corpus spécialistes, mémoire sourcée, audit profond, états visibles et recette avec critères propres à chaque jalon.** Vérification : Relecture du plan T431, sections J0 à J7, contre les demandes utilisateur et les sources.
- **AC-P3 — La fiche T431 est enregistrée par API avec parent T429, plan et contrat; aucune implémentation produit livrée dans cette phase.** Vérification : GET /api/tasks/json pour T431 et inventaire des fichiers écrits sous le nouveau dossier.

**État des critères :** AC-P1, AC-P2 et AC-P3 vérifiés pendant la préparation par lecture des rapports non vides, du manifeste, du plan et relecture API. Cela ne valide aucun comportement produit des jalons J1 à J7. Limites et conclusions rejetées des modèles : §10.

**Preuves conservées :** analyses A/B v1.1, manifeste SHA256, métadonnées d'appel, contrôle historique de l'ancien contrat et état Git dans PREUVES/20261112_ANALYSES/. Le PASS de check_task_contract.py concerne exclusivement l'ancien YAML retiré; il ne constitue pas une validation automatique de cette fiche Markdown.

**Suivi des inconnues :** provenance des outils par plateforme; cadence et quotas runtime; compatibilité de migration; corpus accessible aux spécialistes. Modes de résolution et points d'arrêt : J0 et §9.

## 1. Besoin, décisions et continuité

T429 conserve ses responsabilités de collecte, reprise, cycle des constats, notifications et interfaces. T431 raccorde les spécialistes au service et fiabilise la mémoire qui leur est fournie. Le catalogue rattache T431 à T429; ni clôture ni revendication de livraison globale de T429.

Décisions utilisateur de cette conversation :
- Audits spécialisés réguliers : standards/process, skills/workflows, utilisation correcte des outils existants, nommage/rangement des fichiers, safety/PLC/testing selon le sujet.
- Échelonnement : au plus un nouvel audit spécialisé par nouveau message pertinent, sans rafale au huitième passage; plusieurs audits peuvent travailler en parallèle.
- Un résultat attendu au message N doit pouvoir être lancé plus tôt. Il ne couvre que les événements réellement reçus, jamais des messages futurs.
- États visibles : appelé/en file, en cours, réponse prête et erreurs. Afficher le rôle, sa justification, la plage examinée et le résultat disponible.
- Audit profond éphémère : question unique, lecture de l'historique disponible, réponse argumentée, fin de l'appel; déclenchement périodique ou sur doute avec limitation de fréquence.
- Aucun changement de code autorisé dans la préparation présente.

Recommandation historique à arbitrer explicitement : la revue T429 de mémoire privilégie journal en ajout seul + réducteur pur + projection bornée, et exclut le MD rédigé par le LLM comme vérité canonique. Sa présence ne prouve pas une adoption humaine intégrale. Le résumé proposé auparavant dans le chat n'est pas une décision d'architecture validée. T431 retient cette recommandation comme base proposée; les conclusions des modèles demeurent des avis sourcés, jamais des preuves acquises.

## 2. Sources et couverture

- Source d'identité et statut : entrée T429 de DOC/WFLOW/TASKS.yaml et contrat T429_AGENT_SUPERVISOR_CONTRAT_FIABILISATION_20261109_v1.0.yaml.
- Plan historique : ../T_TEMP (A TRIER)/T429_AGENT_SUPERVISOR_PLAN_REPRISE_TRANSCRIPT_ET_PLUGIN_20261108_v1.0.md (notamment chantiers C et E).
- Revue historique : ../T_TEMP (A TRIER)/REVIEWS/T429_REVUE_CHALLENGE_MEMOIRE_LONG_TERME_DRIFT.md.
- Implémentation : TOOLS/AGENT_SUPERVISOR/scripts/, interface ui/index.html, spécialistes et scripts d'appel TOOLS/AGENT_WORKFLOW/.
- Analyses indépendantes A/B et manifeste SHA256 : PREUVES/20261112_ANALYSES/. Les fichiers ARCHIVES fournis sont des preuves historiques, jamais des règles actives.
- Les deux dossiers de lecture se complètent : A parcourt historique/contrats/preuves; B parcourt implémentation/prompts/tests ciblés. Aucun avis ne prétend avoir parcouru les fichiers absents de son manifeste; tous les tests et toutes les conversations externes ne sont pas relus exhaustivement.

## 3. État initial observé et problèmes à couvrir

1. audit_interval=8 ajoute une notice de trajectoire au même juge; aucun lancement automatique des spécialistes. Compteur de passages du juge distinct d'un compteur de messages pertinents.
2. Les six personas existent. specialist_supervisor.py appelle le même mécanisme que specialist_runner.py; question et fichiers cibles explicites, aucune mémoire de session automatiquement transmise.
3. Les boutons UI copient /ask-specialist ou /challenge; les panneaux indiquent aussi /ask-specialist-supervisor. Deux skills existent : divergence d'expérience à qualifier, pas panne démontrée.
4. capture_memory_sources est importée, mais non appelée en production. validate_state_update est appelée; un échec de validation est actuellement suivi d'un ajout agent_observation sans source vérifiée.
5. Les preuves dites acquises reposent sur motifs textuels, sans contrat complet commande/révision/périmètre. Les entrées et le journal sont plafonnés, seuls les six derniers éléments sont injectés.
6. POINT_COURANT.md est une projection écrasée du point courant, pas une mémoire longue cumulative relue.
7. Une nouvelle observation peut périmer une analyse en vol. Ne pas réutiliser ce mécanisme pour annuler tous les audits spécialisés : risque de famine sous charge.
8. Les événements sont ajoutés dans le JSON de session et dédupliqués par recherche linéaire; aucune borne de croissance n'est observée dans record_event. Pas de prétention de mesurer ici l'impact en exploitation.
9. Le Superviseur observe les outils depuis des transcripts externes; aucun point d'exécution unique universel n'est garanti. Un résultat incomplet reste inconnu, jamais PASS.

## 4. Périmètre et autorisations

**Phase présente autorisée** : ce dossier documentaire et ses preuves; fiche T431 exclusivement via API Task Manager; aucune modification de T429.

**Réalisation future proposée, après GO** : service/serveur/adaptateurs/prompts/tests/UI de TOOLS/AGENT_SUPERVISOR; appel et contrats de spécialistes dans TOOLS/AGENT_WORKFLOW/scripts et specialists; skills ciblées seulement après extension explicite du périmètre; documentation active correspondante. Les fichiers précis sont gelés après J0 et coordination avec le responsable T429. Un seul écrivain par fichier.

**Exclusions** : CODE/, CODE_XML/, machine réelle, Device.export, CODESYS, hooks, configurations CLI globales, redémarrages de services personnels sans besoin autorisé, injection automatique invisible dans les chats, changement des modèles sans autorisation applicable, déplacements/suppressions de documents existants. Pas de modification métier PLC ni certification safety par un avis LLM.

## 5. Architecture proposée

Service permanent = propriétaire des événements, verrous, files, budgets, état des audits et projections. Juge courant = observation réactive à contexte borné. Spécialiste = appel éphémère dédié à un domaine; entrées et sorties explicites. Audit profond = appel distinct qui traite une question sur un historique figé; aucun contexte de modèle conservé après sa réponse.

Entrée d'audit : audit_id, assignment_id/native_id, rôle, motif, plage seq_start/seq_end, révision mission, hashes sources/prompt/corpus, modèle, deadline indicative et budget. Le spécialiste reçoit le cap initial et actif, le lot de messages utile, les références de preuves, son corpus et une consigne lecture seule. Aucun corpus nécessaire ne reste implicitement supposé chargé.

Résultat : constats et limites sourcés, event_id exacts, fichier/révision si applicable, documents consultés, couverture, données manquantes. Un nouveau message ne détruit pas la validité historique du rapport. Réévaluation complémentaire si changement matériel de mission/source/périmètre; aucune présentation du rapport comme couvrant des événements futurs.

Mémoire canonique : journal en ajout seul adressé par IDs; corps des preuves séparés; réducteur déterministe et projection compacte. POINT_COURANT.md peut conserver son rôle public de vue régénérée, sans suppression ni rupture de consommateurs. Les synthèses éventuelles des modèles sont des annotations non canoniques et explicitement attribuées. La validité d'une preuve est calculée selon ses dépendances et son périmètre, pas invalidée par toute modification étrangère.

## 6. Jalons de réalisation, tests et livrables

### J0 — Réconcilier et figer le contrat d'architecture
- Livrables : matrice demande/contrat/source/état; carte des consommateurs; données de reprise; liste exacte de fichiers autorisés; arbitrages corpus, cadence, mémoire, provenance, consentement.
- Critère : chaque exigence reçoit un objectif testable et un propriétaire; aucune recommandation historique promue silencieusement en décision; coordination avec responsable T429 actée.
- Challenge : A défend réutilisation de l'existant; B cherche pertes de preuve, complexité et hypothèses incompatibles avec observation externe. Arbitrage écrit avant J1.

### J1 — Journal sourcé et migration non destructive
- Livrables : événements versionnés avec origine/ID/date/source/hash, index de déduplication, stockage durable et reprise; migration idempotente du JSON existant; conservation de l'ancien état sans nettoyage automatique.
- Critères : même événement ingéré deux fois produit une seule entrée; erreur d'attribution rejetée ou mise en quarantaine, jamais réparée en observation acquise; séquences monotones et isolation entre sessions.
- Tests : arrêt entre append et checkpoint, ligne partielle, source réécrite, événement dupliqué, état illisible, restauration; ancien état présent après migration; rejeu byte-identique de la projection à sources identiques.
- Preuve d'outil : collecter identifiant appel, résultat lié, sortie brute référencée, commande et statut réellement disponibles. Champs absents = unknown. Pas de PASS par simple citation du mot passed.

### J2 — Projection de mémoire et validité des preuves
- Livrables : cap initial conservé, cap actif et pivots datés, index de preuves, propositions/jalons distingués, accès au corps sur demande; projection MD/API compatible.
- Critères : budget explicite mesuré avec le tokenizer réellement utilisé, cible proposée de 1000 tokens à challenger; corps évincé du prompt récupérable par ID; aucune perte silencieuse d'objectif.
- Tests : PASS à N-15 encore référencé à N; NON PASS jamais promu en PASS; sortie de test avec code non zéro; corpus incomplet; changement de fichier dépendant rend la preuve périmée, changement extérieur la conserve; pivot ultérieur n'autorise pas rétroactivement une action.
- Challenge : les scores de drift produits à partir de classifications LLM ne deviennent pas des mesures mécaniques garanties. Pas de seuil 0,20/K=3 copié sans calibration et scénario contradictoire.

### J3 — Corpus et appel d'un spécialiste en lecture seule
- Livrables : registre rôles/domaines/corpus obligatoires/prompt versions; assemblage des entrées; schéma strict de réponse; références de fichiers lues et récupérations bornées de documents/outils existants.
- Critères : chaque appel recharge ses consignes et les versions de documents choisies; pas de mémoire cachée entre appels; absence d'un corpus requis = unavailable; lecture seule appliquée au niveau technique si des outils d'exploration sont accordés.
- Tests : refus des écritures/exécutions hors liste, document manquant, prompt injecté dans un transcript ou une cible, mauvais rôle/schéma, fichier modifié pendant lecture, document dépassant le budget; retour vide non traité comme réussite.
- Cas métier : brouillon dans mauvais dossier, nom non conforme, nouveau script doublonnant un outil documenté existant, mauvais usage de l'outil, gate oublié, règles Reset/front et interlocks à examiner sur corpus synthétique. L'audit safety n'autorise aucune modification machine.

### J4 — Ordonnanceur asynchrone échelonné
- Livrables : file persistante, compteur d'événements pertinents, routage selon domaine + rotation anti-famine, quotas et cooldown, états d'appel et reprise.
- Critères : au plus un lancement déclenché par nouveau message pertinent; pas de rafale au modulo8; maximum de concurrence configurable <=4 Ollama; limites par session et globale partagée explicitement distinctes du budget de délégation de la présente conversation (20 appels).
- Tests : deux sessions actives, rafale de 100 événements, spécialiste lent, timeout, demande prioritaire, service redémarré en cours d'appel; aucun doublon, file bornée/coalescée avec couverture conservée; aucune famine du collecteur ou d'un domaine utile.
- Le message pertinent et sa déduplication sont définis avant implémentation : un résultat d'outil n'est pas automatiquement compté comme une nouvelle demande humaine. Pas d'avance fictive sur messages futurs; cible N est une échéance indicative, pas une garantie de temps modèle.

### J5 — Audit profond éphémère sur question
- Livrables : déclencheur manuel/signal de doute/cadence optionnelle; snapshot complet normalisé, protocole de découpage si hors contexte, réponse argumentée et preuve de couverture; terminaison de l'appel.
- Critères : intervalle minimal et un seul audit profond en vol par session; audit finalise son snapshot même si le chat continue; pas de lecture de l'historique antérieur au consentement/rattachement sans choix explicite.
- Tests : conversation plus grande que contexte modèle, étape manquante, branche de chat, arrêt/reprise, pivot autorisé vs dérive non autorisée, spécialiste indisponible. Lecture incomplète signalée; aucune mention tout lu sans identité/compteurs de couverture.

### J6 — États visibles et retour exploitable
- Livrables : états appelé/en file/en cours/réponse prête/indisponible/annulé, horodatages, rôle/motif, plage couverte, version de mission, réponse consultable et indication besoin de réévaluation.
- Critères : réponse prête ne signifie jamais verdict PASS; un message nouveau seul ne marque pas le rapport périmé; résultats dangereux ou indisponibles restent visibles; pas d'injection asynchrone invisible. Pull existant préservé.
- Tests : cohérence API/UI/plugin et rechargement, réponse longue, échec réseau, deux sessions même alias; recette visuelle obligatoire bureau 1440px et mobile 390/360px; captures et observations réelles associées au même snapshot.

### J7 — Recette et challenge final
- Livrables : corpus français versionné séparant cas synthétiques et réel autorisé; métriques par domaine/modèle et faux positifs/négatifs; migration/reprise, coût/latence et limites; note d'exploitation.
- Critères : exigences AC reliées à leurs preuves; rapport partiel si plateforme ou événement non vérifiable; aucun feu vert général déduit de tests unitaires seuls.
- Deux reviewers indépendants examinent le diff réel et les scénarios, sans leurs rapports réciproques avant remise; l'orchestrateur arbitre chaque divergence. Aucune recette machine dans cette tâche.
- Réel : Claude Code, Codex, Antigravity et DSH; contrôle fichiers et tools adapté aux capacités effectivement exposées; le manque de provenance bloque seulement la conclusion correspondante.

## 7. Contrôles prévus, sans les déclarer exécutés

- Fiche de cadrage Markdown : relecture de AC-P1 à AC-P3, des jalons et de la référence API. Aucun contrôle YAML appliqué à ce document. Le contrôle antérieur de l’ancien YAML est une preuve historique uniquement.
- Réalisation future : py -3.13 -m pytest TOOLS/AGENT_SUPERVISOR/tests -q; node TOOLS/AGENT_SUPERVISOR/tests/test_ui.mjs; tests pertinents des commandes spécialistes et de l'extension VS Code.
- Documentation/skills : sélectionner G340/G440/G530 ou leurs commandes courantes en fonction des fichiers effectivement modifiés; ne pas annoncer un gate obsolète ni exécuter toute la CI PLC pour ce plan.
- Avant/après chaque test ou gate : git status --short. Les résultats antérieurs de T429 ne sont pas les résultats de T431.

## 8. Conditions d'acceptation et points d'arrêt

Le GO humain porte d'abord sur J0 et le périmètre de réalisation gelé. Avant GO : documents et fiche tâche uniquement. Toute extension vers skills/hook/config globale nécessite autorisation spécifique. Travail concurrent T429 : responsable AGY01 affiché au catalogue lors de la préparation, à revérifier avant écriture de code.

Critères de livraison produit : journal rejouable; preuve valide et récupérable; entrées non validées non acquises; spécialistes réellement invoqués avec corpus; couverture asynchrone visible; audit profond honnête sur ses limites; reprise sans doublons; parcours réels observés; revue indépendante arbitrée.

## 9. Arbitrages restant à confirmer au GO

- Adopter formellement journal/réducteur/projection et le statut exclusivement consultatif des résumés LLM.
- Fixer cadence par domaine, plafond file, quotas, modèle et budget; ne pas assimiler huit messages à huit analyses.
- Déterminer les opérations de lecture réellement disponibles au spécialiste pour rechercher outils et normes; aucune capacité agentique implicite via simple requête de texte.
- Définir provenance disponible par plateforme; pas de point de dispatch unique inventé.
- Décider si corpus complet/relecture profonde est autorisé pour historiques pré-rattachement, et conserver le consentement cloud selon les données transmises.

## 10. Analyses de préparation

Les rapports A/B sont des avis du modèle à confronter aux sources; leur présence n'est ni une acceptation humaine de ce plan ni une validation produit. Leur synthèse et les limites de couverture sont ajoutées après remise.

### Arbitrage des rapports A/B — préparation du 2026-11-12

Deux retours indépendants DeepSeek v4.1 ont été obtenus sans partage réciproque des rapports. Les premiers appels v1.0 sont vides et ne valent aucune revue; les appels v1.1 avec think=false sont non vides. Les métadonnées du fournisseur indiquent 151227 et 177187 tokens d'entrée, 5590 et 4765 tokens de sortie; le modèle renvoyé est deepseek-v4.1-flash pour l'identifiant demandé deepseek-v4.1-flash:cloud. Les corpus sont intégralement joints aux requêtes; cela ne prouve pas une attention exhaustive du modèle à chaque fichier. A indique à tort 26 sources, le manifeste en contient 37; B reçoit 33 fichiers. L'étude complète résulte de la confrontation du catalogue, des documents historiques et des sources, pas d'un verdict automatique des deux modèles.

Conclusions retenues après vérification des sources :
- Le service n'appelle pas automatiquement les spécialistes; corpus, file, contrats et visibilité restent à raccorder.
- Le cas state_update invalide est un défaut réel de contrat d'attribution : rejet/quarantaine traçable à prévoir; un simple renommage agent_observation ne suffit pas.
- capture_memory_sources est importée mais pas appelée en production; l'absence d'appel est confirmée. Réutiliser ou adapter cette fonction seulement après définition du schéma d'événements; son branchement seul ne construit pas la mémoire longue.
- Les sources d'outils externes n'offrent pas un point de dispatch unique garanti. Le plan doit supporter unknown et couverture partielle plutôt qu'inventer une provenance.
- Les retours périmés au moindre nouveau message peuvent affamer les analyses. T431 conserve une plage de couverture et ne remplace pas tous les contrôles de cohérence par generation.
- L'historique T429 contient des qualifications différentes selon les dates et périmètres. J0 doit réconcilier leur portée avec l'état courant, sans déclarer T429 entièrement validée ou défaillante à partir d'une archive.

Conclusions corrigées ou rejetées :
- A exige de clore/rouvrir T429 avant tout T431 : non retenu. T429 est déjà en cours; pas de blocage global ajouté. Coordination et contrôles des interfaces réellement réutilisées suffisent, sauf risque critique démontré.
- A qualifie de circulaire la baseline reconstruite du lot2 : non démontré. Une reconstruction déclarée des changements préexistants peut être le comparateur pertinent du lot; un HEAD nu différent n'est pas automatiquement une meilleure preuve. Conserver la limitation historique sans inventer une régression.
- A attribue un FAIL notification actuel à un code cité dans des revues de novembre9 : non retenu comme preuve actuelle. La recette et le code courant doivent trancher; les rapports ne suffisent pas.
- A propose de durcir encore la regex comme solution probante : non retenu. La cible est la provenance et les contrats d'exécution, une heuristique textuelle ne certifie pas une preuve.
- B affirme capture_memory_sources non importée : faux, imports présents dans supervisor_service.py. L'absence d'appel est le seul écart établi.
- B nomme POINT_CURRENT.md : faux; le code construit POINT_COURANT.md. Aucun renommage produit dérivé de cette erreur.
- B cite 6000 caractères comme défaut courant : obsolète; DEFAULT_JUDGE_SETTINGS et UI indiquent 12000. Une valeur legacy en test n'est pas la valeur active par défaut.
- B présente snapshot >1Mo comme défaut démontré de contexte : non retenu sans contrat de taille ni mesure du chemin consommateur; l'API paginée existe. Surveiller croissance/latence sans confondre snapshot et prompt du juge.
- B transpose 800x480, règle IHM cabine PLC, à cette interface Web : non retenu; recette 1440/390/360 proposée pour la présente interface.
- A/B transposent le budget 20 appels de la conversation au runtime de chaque session surveillée : pas une décision utilisateur pour le produit. Les quotas runtime sont à configurer et arbitrer; maximum4 simultanés retenu comme plafond utilisateur de cette préparation et cible de concurrence proposée.
- La reconnaissance du drift reste une analyse sémantique; ajouter un calcul déterministe à un jugement LLM ne rend pas toute la détection déterministe.

Aucun test produit, recette visuelle ou parcours réel n'a été exécuté pendant cette préparation. Les rapports bruts sont conservés sans correction silencieuse. Les critères des jalons sont des vérifications futures, pas des PASS annoncés.
