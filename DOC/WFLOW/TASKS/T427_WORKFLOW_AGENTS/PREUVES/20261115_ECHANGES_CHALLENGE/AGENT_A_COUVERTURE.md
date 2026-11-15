🟡 **ADVISORY** — Verdict : v0.1 recevable comme proposition de travail, **non versable en v1.0 en l'état**.
Impact : 3 incohérences normatives internes et un protocole sans clause de silence — précisément les « absences invisibles » que §1 déclare vouloir faire disparaître.
Durée/Horodatage : revue papier, lecture seule, aucun accès dépôt ni horloge ; version revue : v0.1 (2026-11-15).

*Note courte (unique) : le gabarit de délégation joint est arrivé non complété (aucun champ rempli) — mission inférée du statut « à challenger » de l'en-tête. Aucun test exécuté (G200/G521/G340/pytest non lancés) : le verdict est limité à la revue documentaire, non à la vérification mécanique.*

## Niveau 1 — Invariants

1. [✅ PASS] Protocole 5 étapes typé et clos — preuve : T427 §3.1–3.5.
2. [✅ PASS] Règle de preuve (« Fait sans preuve = non fait ») — preuve : §3.4 ; alignée au standard de restitution.
3. [✅ PASS] Propriété des écritures (1 donnée = 1 producteur, preuves en `PREUVES/`, pas de commit délégué) — preuve : §4.
4. [✅ PASS] Gouvernance des tests (`xfail(strict=True)`) — preuve : §5.
5. [✅ PASS] Résiduels déclarés honnêtement (B2 13/20, GO non livré, hook non raccordé) — preuve : §6.
6. [❌ FAIL] §3.1 ↔ UC-07 — « aucun agent ne contacte une session de sa propre initiative » vs « nouvelle tentative » : ni auteur ni autorisation du retry définis.
7. [❌ FAIL] §2 ↔ §3.4 — un sous-agent sans outils ne peut produire ni `fichier:ligne` ni sortie de commande : la preuve exigée est structurellement indisponible sur ce canal, cas non traité.
8. [❌ FAIL] §2 ↔ UC-07 — `.tmpsandbox/` déclaré volatile et « jamais une preuve », retenu comme canal de relais sans carve-out ni TTL : le relais est purgable selon `STRUCTURE_AND_CLEANUP.md`.
9. [❌ FAIL] Silences non outillés — aucune échéance ni traitement de l'absence de RECU/réponse/CLOS : contredit l'objectif §1.
10. [❌ FAIL] GO non tracé — parade rouge admise non livrée, sans aucun mécanisme intérimaire.
11. [⚪ N/A] Inventaire UC-01..10 (implémentées vs xfail) — non vérifiable sans dépôt ; absent du document lui-même.

## Niveau 1 bis — Argumentaire technique

Faits = citations § ci-dessus. Inférences : UC-07 prescrit une initiative de recontact que §3.1 interdit sans les nommer ; le canal `ollama_subagent` ne peut satisfaire §3.4 que par re-citation du contenu fourni (preuve circulaire) ; UC-07 place un transport important dans le seul volume déclaré volatile. Le verrou de §4 est présenté comme règle alors que §6 mesure son échec (20 écritures → 13 entrées) : à réétiqueter « convention non outillée » tant que B2 est ouvert — §7 le dit en général, §4 ne le fait pas localement. Deux risques de silence subsistent : aucune clause d'échéance dans le protocole, et aucun intérim pour le GO verbal. Reste une faiblesse mineure non traitée : comportement en cas d'homonymie détectée en cours d'échange.

Inconnues : inventaire réel des UC (pytest requis), état courant de B2, existence d'un « juge enregistré » (§6 auto-validation) et de sa liste.

## Niveau 2 — Plan d'action chirurgical

1. §3, étape 4 « Verdict et preuve » — Ajouter : « Sous-agent sans outils : preuve = sortie d'exécution du prompt fourni ; l'orchestrateur la rend durable en `PREUVES/` avant CLOS. » · Outil : `trace_log.py` · Risque : clôtures sur preuve impossible = faux PASS généralisé (UC-06).
2. §3.1, ancre « Aucun agent ne contacte… » — Autoriser explicitement un retry unique post-échéance via relais UC-07 + trace ; au-delà, escalade. · Outil : `miss_log.py` · Risque : retries illégaux ou silences sans issue.
3. §3, étapes 3 et 5 — Échéance obligatoire ; à déchéance : manquement loggé, un relais, puis arbitrage humain. · Outil : `miss_log.py` · Risque : l'absence ne se voit jamais (objectif §1 manqué).
4. UC-07 — Nommage imposé `RELAY_<emetteur>_<dest>_<horodatage>`, TTL écrit dans le fichier, trace comme enregistrement durable, carve-out cleanup. · Outil : `trace_log.py` · Risque : relais purgé → UC-07 muet.
5. §6, puce « GO non tracé » — Intérim : GO = message formaté `GO <tâche> <réf. émetteur> <périmètre>` + copie datée dans le dossier de tâche, en attendant le registre. · Outil : dossier de tâche · Risque : GO verbal perdu, état actuel prolongé.
6. §4, ligne « 1 fichier = 1 écrivain » — Réétiqueter « convention non outillée tant que B2 est ouvert », renvoi §6. · Outil : texte seul · Risque : faux sentiment de verrou effectif.
7. UC-04 — Geler l'artefact contesté pendant l'arbitrage humain ; continuer ailleurs et tracer. · Outil : `trace_log.py` · Risque : arbitrage par le plus rapide, contraire à « jamais au plus bavard ».
8. UC-01 — Note de reprise obligatoire en tête de dossier : fait/prouvé/restant, réfs `fichier:ligne` de `PREUVES/`. · Outil : gabarit de note · Risque : reprise rejoue le prouvé ou rate le restant.
9. UC-10 — Désigner le décideur (orchestrateur joignable, sinon humain) ; départage : criticité superviseur → ID → horodatage. · Outil : superviseur (lecture) · Risque : ordre de fusion subi.
10. §7 — Règle intérimaire d'autorité : le superviseur (lecture seule) fait foi sur l'état ; désaccord d'orchestratrices → gel des écritures contestées + escalade humaine. · Outil : superviseur · Risque : double écriture d'orchestrateurs, cas déjà observé.
11. §6 « Doublon de session » — Sur ambiguïté détectée : pause, question au désignateur, log ; interdiction de choisir « la session qui répond le plus vite ». · Outil : `miss_log.py` · Risque : consigne livrée au mauvais agent.
12. §3.4 — Renvoi explicite au format de restitution `AGENT_OUTPUT_STANDARD.md` pour toute réponse d'étape. · Outil : texte seul · Risque : verdicts illisibles d'un coup d'œil.

**Décision recommandée :** traiter les items 1–6 comme prérequis de versement en v1.0 ; 7–12 en v1.1. Recommandation de versement : **non, en l'état** (`[🟡 ADVISORY]`). Ne pas verser ce compte-rendu dans `TASKS.yaml` ni modifier le document de sa propre initiative — écritures à orchestrer.