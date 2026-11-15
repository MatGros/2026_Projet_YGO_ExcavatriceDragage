🟡 **ADVISORY**

**Verdict :** T427 v0.2 corrige les 10 points de revue annonceés et est publiable comme proposition, mais 4 contradictions internes restantes interdisent sa promotion dans `AGENTS.md` en l'état.
**Impact :** l'objectif affiché du §1 (« toute absence → trace + échéance ») n'est pas atteint pour les signalements §2 ni pour `miss_log` en écriture concurrente.
**Durée/Horodatage :** non mesurables depuis cette session (aucun accès horloge) ; à consigner par l'orchestrateur à la réception.

**Note courte (une fois, non bloquante) :** aucun accès dépôt ni horloge depuis cette session — revue strictement textuelle, aucun verdict ci-dessous ne repose sur exécution. Les champs de mission du gabarit étant génériques, le rôle appliqué est *reviewer indépendant*, lecture seule, sur le texte fourni.

---

## Niveau 1 — Invariants

1. Distinction solliciter/signaler opposée et sans ambiguïté (§2) — `[✅ PASS]`
2. Format d'échange unique avec échéance obligatoire (§3) — `[✅ PASS]`
3. Clause de silence couvre toute absence de réponse attendue — `[❌ FAIL]` (« sans accusé **ni** réponse » : accusé donné + réponse jamais venue = aucun déclenchement)
4. Toute absence produit trace + échéance (objectif §1) — `[❌ FAIL]` (signalements §2 sans échéance ni clause ; `miss_log` non sérialisé)
5. Registre de verrous exploitable par un délégué (§5) — `[❌ FAIL]` (conflit croisé avec le gabarit de délégation)
6. Preuve = triplet + code retour + sortie brute (§4) — `[✅ PASS]`
7. Invalidation de preuve détectable (UC-12, §4) — `[❌ FAIL]` (aucun hash conservé au moment de la citation)
8. Autorité fail-closed, réaction à l'homonymie définie (§6) — `[✅ PASS]`
9. Détection de l'homonymie (comment repérer deux réf. identiques) — `[⚪ N/A]` (réaction oui, détection non)
10. GO verbal non copié n'autorise rien (§7) — `[✅ PASS]` (réserve : copiste non spécifié)
11. Idempotence UC-11 testable — `[❌ FAIL]` (ID canonique de consigne absent)
12. Échéances avec fuseau explicite (UC-15) — `[✅ PASS]` (réserve : horloge de référence pour juger l'échéance non désignée)
13. Suite d'essais bornée par compteur `xfail` (§8) — `[✅ PASS]` (réserve : contrôle asymétrique, cf. plan §10)

## Niveau 1 bis — Argumentaire

**A. Clause de silence incomplète (§3).** « À l'échéance, sans accusé ni réponse » (négation : *ni… ni*) ne déclenche rien si `RECU` a été envoyé sans réponse ensuite. L'accusé introduit de plus une seconde échéance (« ce qui sera fait + quand ») non arbitrée avec celle de la consigne. Correctif minimal : échéance effective = date promise dans `RECU`, sinon échéance de consigne ; le déclenchement porte sur l'absence de réponse.

**B. L'objectif §1 n'est pas atteint pour les signalements.** Le signalement §2 est obligatoire mais n'a ni échéance (champ conçu pour les consignes), ni clause de silence — un blocage signalé peut attendre indéfiniment. Par ailleurs `miss_log.record(...)` écrit par plusieurs agents en parallèle reproduit exactement le défaut B2 (écritures concurrentes, entrées perdues) *dans le remède lui-même*. Le journal chaîné garantit l'ordre, pas la non-perte — le §5 le dit, le §3 l'oublie.

**C. Conflit croisé §5 ↔ gabarit de délégation.** T427 déclare `TASKS.yaml` registre de verrous ; le gabarit joint interdit aux exécutants/reviewers d'y écrire. Résultat : un délégué ne peut pas prendre le verrou qui lui est demandé. Sans procédure de demande (à qui, quel délai, quelle clause de silence), c'est soit contournement, soit blocage — les deux récidivent B2.

**D. Idempotence et preuve invalidée non mécaniques.** UC-11 (« même consigne reçue deux fois ») exige un ID canonique : sans hash des 8 champs §3, « même consigne » est indéterminable (même problème de canonicalisation que UC-08, le doc le reconnaît pour l'un et pas pour l'autre). UC-12 exige de comparer l'état présent à l'état cité : sans hash stocké avec la preuve, l'invalidation est indétectable — « re-citer après relecture » n'a rien contre quoi comparer.

## Niveau 2 — Plan d'action chirurgical

**Priorité 🔴 (bloquant la promotion dans `AGENTS.md`) :**

1. **§3, clause de silence** — Ancre : « sans accusé ni réponse ». Action : reformuler « à l'échéance effective sans réponse ; échéance effective = date promise dans `RECU`, sinon échéance de consigne » ; l'accusé seul ne clôt rien. Outil : cas pytest dédié (RECU-sans-réponse). Risque si ignoré : échange bloqué à l'infini malgré accusé.
2. **§2/§3, signalements** — Ancre : « sur un seul canal et dans un seul format ». Action : nommer le canal ; définir la variante du format (preuve attendue = preuve du blocage ; échéance = date de revue attendue) ; écrire chaque signalement dans la trace durable dès création. Outil : script de rapprochement signalements ↔ journal (lot 2). Risque si ignoré : signalement sans échéance = trou sans fond contraire à l'objectif §1.
3. **§5 + gabarit** — Ancre : « le registre des verrous est `TASKS.yaml` ». Action : arbitrer — verrou demandé à l'orchestrateur (qui écrit), ou clause du gabarit amendée avec autorisation explicite ; documenter la procédure de demande et son délai (rattachée à la clause de silence §3). Outil : grep croisé des fichiers concernés + revue humaine. Risque si ignoré : récidive B2 (20 écritures, 13 entrées).
4. **§3, `miss_log`** — Ancre : « `miss_log.record(...)` ». Action : sérialisation par écrivain unique, ou écriture dans le dossier de tâche de l'émetteur puis fusion par le coordinateur, avec numéro de séquence par écrivain et détecteur de trous. Outil : script vérificateur de séquences (lot 2). Risque si ignoré : perte d'entrées en écriture concurrente.

**Priorité 🟠 :**

5. **§3, relais** — Ancre : « copie durable dans `PREUVES/` au moment du `CLOS` ». Action : consigner hash + horodatage du relais dès sa création, avant TTL/purge. Outil : sha256 enregistré à l'écriture. Risque : relais purgé avant `CLOS`, échange sans trace durable.
6. **UC-12/§4** — Ancre : « Re-citer après relecture ». Action : hash du fichier cité stocké avec la preuve ; re-lecture = recalcul + comparaison ; divergence = invalidation. Outil : script de recalcul de hashes sur les citations d'une tâche (lot 2). Risque : preuve morte restée valable.
7. **UC-11** — Ancre : « une seule exécution (idempotence) ». Action : ID de consigne = hash des 8 champs §3 (canonicalisation commune à UC-08) ; seconde occurrence référencée comme doublon tracé. Outil : script d'empreinte de consigne (lot 2). Risque : double exécution ou refus arbitraire.
8. **UC-15** — Ancre : « horodatage avec fuseau, jamais local implicite ». Action : désigner l'horloge de référence (émetteur, ISO 8601, fuseau explicite) pour l'appréciation de toute échéance. Outil : test pytest sur le champ `échéance`. Risque : deux sessions jugent des échéances différentes.
9. **§6, homonymie** — Ancre : « pause, question au désignateur, trace ». Action : ajouter le mécanisme de détection — empreinte de session (horodatage de démarrage + identité hôte) annexée à la réf. ; collision ⇒ fail-closed §6. Outil : script de détection de doublons de réf. en lecture seule. Risque : deux sessions croisées sous une même réf.
10. **§8** — Ancre : « dépasse le compteur déclaré ». Action : contrôle bidirectionnel — nombre de `xfail` == entrées du manifeste (ni plus, ni moins). Outil : collecte pytest + parsing du manifeste (lot 2). Risque : dérive silencieuse suite ↔ manifeste dans les deux sens.

**Priorité 🟡 :**

11. **§7** — Ancre : « copie datée dans le dossier de tâche ». Action : préciser le copiste (émetteur du GO ; à défaut transcription de l'agent marquée « transcription, non signée ») et le nom de fichier normalisé. Risque : GO auto-écrit par l'agent = preuve faible.
12. **§9, juge** — Ancre : « un juge enregistré listé ». Action : nommer l'emplacement du registre des juges et le format d'entrée (datée, motivée, réf. de tâche). Risque : arbitrage non rattachable.

## Faits / inconnues / limites

- **Fait :** le texte T427 v0.2 et le gabarit de délégation sont fournis intégralement dans l'entrée ; les verdicts ci-dessus portent sur leur cohérence interne et croisée.
- **Inconnu (non vérifiable ici, aucune preuve mécanique possible) :** existence de `PREUVES/20261115_ECHANGES_CHALLENGE/AGENT_A_COUVERTURE.md` et `AGENT_B_REDTEAM.md` ; contenu de `AGENTS.md`, `TASKS.yaml`, `MANIFESTE_CAS_NON_IMPLANTES.md` ; existence et état de `miss_log` et des scripts G-xxx.
- **Hypothèse structurante :** le gabarit de délégation joint fait foi comme texte normatif parallèle — l'invariant n°5 tombe si le gabarit est amendé en même temps que T427 (option b du point 3 du plan).
- **Effet de bord assumé :** cette revue n'exécute rien ; les 4 points 🔴 sont des défauts de spécification, non des régressions de code.

## Décision recommandée

**ADVISORY — promotion conditionnelle.** Publier v0.2 comme proposition telle quelle ; **ne pas** l'inscrire dans `AGENTS.md` avant correction des points 1–4 (clause de silence, échéance des signalements, arbitrage `TASKS.yaml`/gabarit, sérialisation de `miss_log`). Les points 5–12 entrent au lot 2 avec les scripts déterministes associés ; tant qu'ils ne sont pas outillés, ils restent des conventions (§10, cohérent avec le statut affiché).