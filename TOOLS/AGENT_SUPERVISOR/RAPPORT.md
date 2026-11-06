# Veilleur — rapport courant

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
4. Redemarrer le Veilleur seulement apres validation du diff; le processus actif sur 8082 ne
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
