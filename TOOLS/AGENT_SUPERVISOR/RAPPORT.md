# Veilleur — rapport courant

## Plan principal actualisé — 8 novembre 2026

Cette actualisation complète J2 (interface), J3 (cycle des constats) et J4 (preuve réelle)
du plan J0–J4. Elle ne clôture pas les réserves précédentes. Le point 5 du 6 novembre,
fondé sur les messages CLI avec ACK et choix séquentiels, décrit l'approche précédente :
le nouveau canal de notification doit informer sans attendre une décision sur une autre alerte.

**Retour utilisateur acquis :** cloche et compteur par session, couleurs des étiquettes et des
avertissements visuellement validés sur son essai. Cela ne valide pas la livraison au chat.

**Travaux liés à conserver au plan :** distinguer non-lu et à suivre ; montrer lecture active,
pause et échec d'envoi dans le menu et les cartes repliées ; rendre cohérentes clôture et file
d'attente ; réexaminer et requalifier les constats avec nouvelles citations, historique et
décisions humaines ; regrouper les répétitions ; ajouter la famille « Changement de cadrage »
sans assimiler automatiquement lot et jalon. Ces évolutions restent à implémenter et vérifier.

### Mini-lot intégré : notifications VS Code indépendantes des CLI

**But :** une entrée Veilleur dans la barre du bas, un clic pour consulter les détails,
et des notifications non modales pour les nouveaux événements pertinents. Le format de bilan
commun couvre les sessions Claude, Antigravity, Codex et DSH présentes dans Veilleur ; cela
ne constitue pas une validation de leur collecte réelle ni de l'injection dans leurs chats.

| Étape | Livrable / périmètre | Preuve attendue | Avancement |
|---|---|---|---|
| N1 — Étude et challenge | API VS Code officielles, deux revues indépendantes, sémantique des comptes, frontière des actions et identité plateforme + UUID + affectation Veilleur | Proposition compacte et limites documentées ; distinguer notification utilisateur et contexte fourni au modèle | Recherche et challenge faits ; périmètre v1 proposé ci-dessous |
| N2 — Implémentation | Extension autonome sous `TOOLS/AGENT_SUPERVISOR/poc/vscode-notifier/`, lecture du service local, barre d'état et liste de détails, ouverture ciblée de l'IHM, réglages propres de notification | Statuts et comptes cohérents avec une projection commune du service ; erreur de connexion explicite ; aucun appel de CLI ou modèle | Non démarrée |
| N3 — POC isolé | Extension Development Host, sans installation globale ; instantané réel T428 et événements synthétiques clairement TEST pour les quatre plateformes | Compte et session corrects, clic vers la bonne destination, zéro faux événement écrit dans les sessions réelles | Non démarré |
| N4 — Test réel et livraison | Une courte campagne sur l'Extension Host : affichage, notification et clic ; changements répétés ; panne puis retour du service | Trois scénarios ci-dessous, résultat observé et limites ; revue du diff et du rendu ; paquet utilisable et notice | Non démarrée |

**Actions v1 proposées après challenge :** consulter les sessions et leurs constats, ouvrir
Veilleur au bon endroit, actualiser, régler ou tester les notifications du plugin.
Les décisions « Vu », « Traité », « Reporter », « Faux positif » restent dans l'IHM pour ce
premier lot ; leur ajout au plugin dépend de la cohérence du cycle et de l'API commune.
Fermer un toast ou consulter un détail n'acquitte ni ne clôture une alerte. Le plugin ne pilote
pas les agents. Une notification visuelle ne signifie pas que le modèle a reçu le bilan.

**Trois scénarios de recette, définis avant implémentation :**

1. **État et navigation :** T428 réelle, lecture active puis état de pause synthétique ; comptes
   à suivre visibles même avec zéro non-lue ; clic depuis la barre/notification vers la bonne
   session. Vérifier aussi deux UUID identiques sur deux plateformes dans les données TEST.
2. **Nouvel événement :** notification VS Code observée, détail accessible, même instantané
   répété sans doublon ; avertissement/alarme identifiables ; aucun tour LLM, aucune commande
   CLI et aucune action sur les conversations pendant ces notifications.
3. **Disponibilité :** source TEST interrompue puis rétablie ; état « indisponible / données
   périmées », sans faux zéro ni nouvelle alerte métier ; reprise propre. Documenter que les
   notifications cessent lorsque VS Code ou l'extension est fermé.

Vérifier les fichiers modifiés avant/après chaque étape ; conserver le travail préexistant.
Les sources du plugin restent dans l'outil ; les scratchs vont au temp système, les preuves
durables éventuelles sous `DOC/WFLOW/`. Aucun changement PLC, hooks, skills ou configuration
des CLI ; aucun commit/push ni installation globale dans ce mini-lot sans accord correspondant.

Sources d'étude : [API VS Code](https://code.visualstudio.com/api/references/vscode-api),
[barre d'état](https://code.visualstudio.com/api/ux-guidelines/status-bar),
[notifications](https://code.visualstudio.com/api/ux-guidelines/notifications).
Le mod UI natif Claude reste une option spécifique distincte du socle commun VS Code.

## État au 6 novembre 2026 — intégration en cours

| Axe | Réalisation | État vérifié / limite |
|---|---|---|
| Commande de chat | `/connect-session-supervisor` pour Claude Code, Antigravity et DSH ; connecteur local exigeant une référence `T###` ou confirmation sans tâche | Tests unitaires passés. Essai dans les trois interfaces non démontré ; la revue DSH confirme une skill utilisateur dans le menu `/`, pas une commande native enregistrée. |
| DSH | Lecteur Zstandard Node.js, suivi des nouvelles trames, historique borné, résolution par ID exact | Tests synthétiques passés ; watcher attaché en lecture seule à l'ID fourni, état `active`, curseur 453 455 octets. Seul l'en-tête a été vérifié ; aucune ligne de conversation n'a été affichée ni envoyée au modèle. |
| Modularité | Normalisation et sélection du lecteur isolées dans `scripts/platform_adapters.py` ; service conserve l'orchestration | Refactor minimal fondé sur revue indépendante. Les transports de modèles et le pipeline d'analyse restent à séparer. |
| Trajet des messages | Détails repliables, étapes cliquables, état collecteur et juge actualisés depuis l'API | Test DOM existant passé ; revue visuelle navigateur non réalisée. Le challenge A/B est une revue ponctuelle hors boucle : un seul juge LLM tourne en production. |

Vérifications : suite `TOOLS/AGENT_SUPERVISOR/tests` : **40 pass** ; `test_ui.mjs` : **pass**.
Le connecteur refuse les URL hors loopback et une deuxième session Veilleur avec le même
`T###`. Cette collision n'est contrôlée que parmi les affectations Veilleur : l'outil ne
vérifie pas les verrous externes du Task Manager.

Les commandes `/connect-session-supervisor` n'ont pas encore été lancées
dans les chats réels ; ne pas considérer ce lot comme livré avant ces trois essais et leur
confirmation dans Task Viewer.
Sur le transcript DSH de 453 Ko, 10 cycles locaux ont pris en moyenne 107 ms (maximum 119 ms)
par cycle, démarrage Node compris. Ce petit échantillon ne prédit pas le coût de gros historiques
ni de nombreuses sessions simultanées.

## État au 4 novembre 2026

| Phase | Preuve | Résultat / limite |
|---|---|---|
| J0 — Référence | État Git initial et revues indépendantes | Modifications préexistantes conservées ; aucun nettoyage. |
| J1 — Service | Tests de verrou, accès local, port occupé et relais Task Manager | Réussis sur processus isolés. Service utilisateur v2 actif sur `127.0.0.1:8082`. |
| J2 — Affectation et interface | Tests DOM de l'interface servie, ID absent/ambigu, collage invalide | Réussis en simulation DOM. Revue visuelle navigateur non réalisée : accès à la fenêtre refusé par l'environnement. |
| J3 — Mémoire et alertes | Tests de citations, reprise, isolation, pivots et résultats périmés | Réussis avec juges simulés. Le sens d'une alerte reste à vérifier humainement. |
| J4 — Scénarios synthétiques | `tests/run_scenarios.py --model qwen3:8b` | Dernier passage : 6 résultats attendus sur 7 et 1 indéterminé. Cela ne mesure pas une fiabilité générale. |
| J4 — Claude réel | `tests/run_claude_live.py`, session synthétique explicite | Lecture active, réponse détectée, aucune alerte injustifiée ; 18,36 s de bout en bout. Un seul scénario réel. |

La dernière campagne automatisée regroupée a donné **82 tests réussis**. Le modèle réel
et les scénarios à juge simulé sont distingués ci-dessus. Une première exécution du
modèle réel avait détecté l'absence de preuve avec une citation inexacte ; elle était
refusée par le service. Une seule nouvelle tentative de citation a été ajoutée, sans
convertir automatiquement une alerte non citée en absence d'anomalie.

## Coût mesuré de l'intégrité

Sur des fichiers JSONL synthétiques, lectures du préfixe après mise en cache : environ
1,1 ms pour 1 Mo, 9,3 ms pour 10 Mo et 51 ms pour 50 Mo. Ces chiffres dépendent de la
machine et du stockage. Le contrôle d'intégrité complet reste actif.

## Réserves et suite

- La conversation CC-T217 a été retrouvée par correspondance avec le bloc exact fourni
  par l'utilisateur puis suivie. Un extrait partiel a été vérifié et des alertes ont été
  produites. Elle n'était plus affectée à la dernière relance ; la cause reste à confirmer.
  Une sauvegarde antérieure de ses données existe ; aucune restauration n'a été imposée.
- Le service utilisateur actuellement actif charge la version indiquée par `/health`.
  Une modification du code après son lancement nécessite un redémarrage du Veilleur.
- L'historique d'une session se lit à la demande ; la collecte temps réel commence à
  l'attachement. Le chat par carte s'adresse au Veilleur, jamais automatiquement à
  l'agent observé. La destination d'un éventuel envoi direct reste à clarifier.
- Une vue locale de la dernière requête tentée vers Ollama, y compris messages et
  consigne système, est implémentée et testée. La précédente version ne permet pas de
  reconstituer exactement les requêtes antérieures à son installation.
- Le chat de l'ancien service a été sauvegardé avant migration ; l'instantané au moment
  de l'opération contenait zéro message. La sauvegarde est conservée dans
  `%LOCALAPPDATA%/ExcavatriceDragage/supervision-backups/`.
- Les changements préexistants hors périmètre restent présents, notamment dans les
  gates et les documents de pilotage. Aucun commit ni push n'a été fait.


## Suite priorisee (2026-11-06)

1. Elargir le corpus francais depuis des echanges reellement observes : cas normaux difficiles,
   pivots utilisateur, repetition apres recadrage, recommandations prematures, validations sans
   preuve et actions hors permissions. Annoter deux classes par cas (attendu et source exacte),
   mesurer faux positifs, non-detections, citations, doublons, latence et cout; separer les cas
   vus pendant le reglage des cas gardes pour contre-epreuve.
2. Stabiliser le juge OmniRoute NVIDIA a cote d'Ollama. Ne pas activer automatiquement un modele
   avant comparaison sur les deux groupes; utiliser warning/alarme avec ancrage mecanique.
3. Etudier puis rendre accessibles les parametres modeles pertinents (provider, ID, temperature,
   limite de sortie, delai, contexte) dans la configuration/interface. Distinguer parametres
   supportes par chaque provider, valeurs effectives envoyees, valeurs par defaut et consentement
   cloud. Ajouter l'implementation apres mesure des modeles et validation du comportement.
4. Revoir la presentation des sessions sans augmenter l'encombrement de la page : chaque session
   doit avoir un carre ou symbole colore distinct, repris a l'identique dans sa ligne du menu gauche
   pour relier visuellement la carte et l'entree correspondantes. La session selectionnee reste
   clairement identifiable ; les sessions non selectionnees sont fortement compactees pour eviter
   les confusions, tout en gardant leur identite et leurs alertes visibles. Le repere ne doit pas
   reposer uniquement sur la couleur.
5. Etudier le cycle d'alerte injectee dans le chat exact de l'agent. Message compact :
   `⚠️ Avertissement —<titre court> — <une ligne sur le point a verifier>`, avec criticite.
   Dire explicitement a l'agent dans ce premier message : « Reponds en une seule ligne, sans analyse
   detaillee ni action; attends le choix de l'utilisateur. » Inviter l'utilisateur a repondre `1`,
   `2` ou `3`; pour `1` et `3`, une justification d'une ligne au plus. Pas de long developpement ni
   d'action automatique a cette etape. Ne laisser qu'un seul
   choix en attente par session pour que le chiffre seul identifie l'alarme.
   `1` = ne pas traiter ce signal (motif requis; ne le classe pas automatiquement faux positif);
   `2` = examiner maintenant en contestant l'hypothese et en verifiant les preuves;
   `3` = reporter avec une condition de reprise. La reponse spontanee de l'agent n'est pas une
   decision et ne change pas le statut de l'alerte : seul le choix explicite de l'utilisateur compte.
   Etudier si ce choix est donne dans l'IHM ou dans le chat cible, avec un statut unique et tracable.
   Si l'utilisateur choisit `2`, le Veilleur prepare un second message court, adresse a l'agent,
   avec une pre-etude critique et une demande de proposition de resolution ou conseil - jamais un GO
   de modification. Pour `3`, consigner le report et sa condition, puis reprendre l'etude a ce moment.
   Le motif de `1` supprime les rappels identiques jusqu'a un fait nouveau ou un pivot, sans cacher
   une nouvelle anomalie. Distinguer dans l'IHM livraison/reponse de l'agent et statut utilisateur
   (`Vu`, `Traitee`, `Faux positif`). Tester reception, bon ciblage, choix utilisateur et anti-boucle
   dans les chats reels de chaque plateforme avant activation automatique.
6. Redemarrer le Veilleur seulement apres validation du diff; le processus actif sur 8082 ne
   charge pas les modifications presentes sur disque.

Une recherche locale retrospective par agent a produit 10 candidats resumes (9 Claude, 1 AGY),
avec contre-exemples de corrections, pivots, diagnostics normaux et propositions hors cadrage.
Les extraits ne sont pas encore tous verifies sur le contexte complet et ne comptent pas comme
labels definitifs. Voir `poc/retro_candidates_fr_v1.md`. La source AGY detaillee disponible est
trop courte pour inventer un lot equilibre; les resumes restants n'ont pas de citations sources.

Etat courant : le POC Bolt v4 a detecte le cas M3 via l'adaptateur de production (un appel reel,
7,6 s) et le classifie warning; citation exacte, mais le premier controle de source de contexte
etait invalide car le modele avait omis le champ de citation mission. L'ancrage mecanique de
repli est ajoute et couvert par le test unitaire. Cela reste un seul cas et ne mesure pas les taux
FP/FN. Aucun commit/push; changements preexistants et suppressions restent preserves.

Redemarrage du 6 novembre : `upgrade_legacy.py` a sauvegarde et verifie le chat avant relance.
Le service v2 charge le build `90fef02bb4f9`, `update_available=false`, collecte en marche,
1 affectation conservee en pause et 4 messages de chat conserves. La sauvegarde reste sous
`%LOCALAPPDATA%/ExcavatriceDragage/supervision-backups/`. Preference UI a retenir : menu lateral
plus moderne/agreable; harmoniser les panneaux avec cette direction lors de la prochaine revue visuelle.

## État de la demande alerte/chat — 7 novembre 2026

| Élément | État |
|---|---|
| Repères de session | Implémentés : même symbole coloré dans la carte et le menu ; les cartes non sélectionnées sont repliées. |
| Titre de la vue | Corrigé : « 🛡️ Veilleur — Supervision des conversations ». |
| Trajet dynamique | Le détail de l’étape Résultat affiche la session sélectionnée, la livraison, le choix utilisateur et la réponse courte de l’agent. |
| Message d’alerte | Implémenté : criticité, titre court, description, citation, consigne de réponse en une ligne et attente du choix utilisateur. |
| Choix utilisateur | Implémenté dans l’IHM et par réponse 1, 2 ou 3 dans le chat observé. Le choix 1 demande un motif, le 3 une condition. Une seule alerte attend un choix par session. |
| Choix 2 | Implémenté : demande une contre-analyse courte, sans outils ni modification ; réponse affichée séparément de la décision utilisateur. |
| Envoi CLI | Adaptateurs Claude Code et Antigravity ajoutés. UUID ciblé et réponse du CLI vérifiés. Cela confirme l’ajout d’un tour à l’historique, pas le rafraîchissement de la fenêtre déjà ouverte. |
| DSH et Codex | DSH reporté ; aucun adaptateur d’envoi validé pour DSH ou Codex. |

**Encore à valider sur de vrais chats synthétiques :** réception dans le bon UUID Claude et AGY, choix 1/2/3 par le chat et l’IHM, visibilité dans le CLI actif, pause/reprise et absence de doublon. Aucun message n’a été envoyé à une conversation réelle pendant cette phase.

**Limites fonctionnelles restantes :** le Veilleur ne déclenche pas encore la reprise de l’analyse au moment où la condition du choix 3 devient vraie. Les envois en attente sont restaurés après redémarrage lorsque la session est reprise ; un envoi interrompu devient « résultat incertain » et demande une relance manuelle pour éviter un doublon. La déduplication anti-boucle après pivot utilisateur reste à challenger. Le marqueur commun de favicon pour Task Viewer et Veilleur reste à faire.

**Contrôles exécutés :** 54 tests Python Veilleur PASS ; test DOM/UI PASS ; py_compile PASS ; git diff --check PASS. Les aides des CLI Claude et Antigravity confirment les options de session utilisées, mais ne remplacent pas l’essai de réception dans une session synthétique.

Redemarrage du 7 novembre : build bb35ac048550 actif sur 8082, update_available=false. Deux affectations en pause, l alerte T428 et les 4 messages du chat sont conserves. Sauvegarde verifiee : C:\Users\ZEDVICTUS\AppData\Local\ExcavatriceDragage\supervision-backups\legacy_chat_20261107T015325_988080Z.json. Le premier controle a releve a tort le champ workflow ajoute aux anciennes alertes ; le comparateur est corrige et couvert par un test.
