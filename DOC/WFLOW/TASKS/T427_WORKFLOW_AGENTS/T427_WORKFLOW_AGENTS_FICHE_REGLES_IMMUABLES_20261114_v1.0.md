# 📘 Fiche de règles immuables — T427 (v1.1, 2026-11-14)

**Principe :** une règle est immuable seulement si **un mécanisme de code l'impose** et que ce mécanisme est **vérifié**. Sinon, c'est une consigne, et elle est contournable.

**Légende :** ✅ en place et vérifié · ⚠️ partiel · ❌ absent · 🔧 à faire

> **v1.1 — corrections du 2026-11-14** (revue par l'agent T429 après une journée de travail réel sur le Supervisor) :
> 1. **P2 / `onFailure` : la clé n'est PAS confirmée localement.** Sur le CLI installé (2.1.325), la chaîne `onFailure` n'apparaît que comme symbole interne du moteur V8/JSC — pas comme clé de configuration de hook. La source citée reste à confirmer sur la doc officielle ; en attendant, **le seul mécanisme vérifié est `exit 2`**.
> 2. **P2 : fail-closed partout est un danger.** Un hook d'**observation** qui plante ne doit pas bloquer le travail. Proposition : **fail-closed pour les hooks de sécurité** (périmètre, garde-fous), **fail-open + marqueur « dégradé »** pour les hooks d'observation (attestation, couverture). Sans cela, une erreur d'outillage arrête la session.
> 3. **P3 / règle 15 : la clôture par l'agent via l'API du service est une auto-validation.** Fait constaté le 2026-11-14 : l'agent a clos 3 constats du Superviseur depuis la session elle-même. La règle doit viser **toute** clôture dont l'agent est l'initiateur, y compris via l'API du service qu'il pilote.
> 4. **P4 : « l'agent ne modifie pas ses garde-fous » est aujourd'hui inatteignable.** L'agent a les mêmes droits que l'humain (il écrit en `Bash`) : la règle ne peut être posée qu'avec un registre hors de sa portée, ou **réduite à « toute modification est constatée et traçable »** (fait : le cross-check `git status` vs journal le détecte et le consigne comme écriture non tracée).
> 5. **Règle 7 : le trou `Bash` est désormais VÉRIFIÉ** (et non plus « signalé par l'expert ») : le hook `PreToolUse` ne couvre que `Edit|Write`, une écriture passée en shell ne déclenche aucun refus. La compensation existante est la **visibilité** (cross-check), pas la prévention.
> 6. **Règle 18 : « ce qui est hors fenêtre n'est pas considéré comme vu » est désormais MÉCANISÉ** : provenance du constat (source + `event_id` + `event_index`) et **archive des preuves en mémoire longue** → une provenance ne peut plus devenir « introuvable » au mouvement de la fenêtre.

---

## 🧭 1. Principes de base

- **P1 — Le code bloque, le LLM propose.** Toute règle de sécurité ou d'ordre passe par un script ou un hook. ⚠️
- **P2 — Fail-closed : une erreur de contrôle arrête le travail.** Sur un hook `command` ou `http`, la clé `"onFailure": "block"` est annoncée par la doc officielle (v2.1.295+) mais **non vérifiée localement** : sur le CLI installé, `onFailure` n'existe que comme symbole moteur. Le mécanisme **vérifié** reste `exit 2`. ⚠️ → fail-closed pour la **sécurité**, fail-open **+ marqueur « dégradé »** pour l'observation.
- **P3 — Un agent ne valide jamais son propre travail.** Le validateur est un humain, ou un outil séparé enregistré par le code. Un LLM du même type seul ne suffit pas. ⚠️ *Nuance à écrire : la clôture demandée par l'agent via l'API du service qu'il pilote est une auto-validation.*
- **P4 — L'agent ne modifie pas ses garde-fous.** Hooks, settings, scripts de contrôle et registres sont hors de sa portée d'écriture, avec empreinte vérifiée. ❌ 🔧 *Réduction réaliste : « toute modification est constatée et traçable » (cross-check) ; l'exclusion stricte exige un registre hors de portée de l'agent.*

## 🔒 2. Règles de code (immuables)

**Étapes**
- **4 — Ordre fixe** : cadrage → étude → réalisation → test → restitution. Un saut est refusé par script. ⚠️ *L'étape existe (7 valeurs fermées, refusées hors liste) ; la **précondition** n'est pas vérifiée.*
- **5 — Passage d'étape** : un script vérifie la précondition avant de faire avancer l'étape. ⚠️ *Idem : le passage est enregistré, pas conditionné.*
- **5 bis — Socle exigé à l'attachement** *(ajout 2026-11-14)* : à la connexion d'une session, une liste de documents à lire est **exigée** ; la lecture est **constatée par relecture du transcript** (une règle « se lire » ne se déclare pas) ; l'écart est visible (barre de statut, IHM). ✅ *Mécanique en place : `task_socle.py` + `hook_workflow_attest.py`.*

**Périmètre et écriture**
- **7 — Écriture hors périmètre bloquée**, sauf dérogation enregistrée. ⚠️ *Écriture `Edit|Write` bloquée (exit 2) ; `Bash` non couvert — **vérifié** ; compensé par la visibilité (cross-check `git status` vs journal).* 🔧
- **8 — Pas d'écriture en production sans validation humaine enregistrée**, dans un registre que l'agent ne peut pas écrire. ❌ 🔧 *Point dur : aujourd'hui le registre des dérogations est écrit par l'agent lui-même. Piste : le registre est écrit par le **service** à partir d'une **décision humaine tracée dans le chat** → l'agent déclenche, il ne forge pas.*
- **9 — Pas de commit ni de push sans accord humain explicite.** Le pre-push est aujourd'hui informatif et non bloquant : à corriger. ❌ 🔧

**Attente et clôture**
- **14 — Si l'agent attend une réponse, il ne peut pas conclure le tour.** ❌ *Le Stop hook actuel ne contrôle que la liaison rouge et le bundle périmé. Il faut un contrôle d'**état** (registre « j'attends »), pas une lecture du texte.* 🔧
- **15 — La clôture d'un constat ou d'une tâche est réservée à l'humain ou au juge.** Un état verrouillé, pas une phrase. ❌ 🔧 *Auto-validation constatée le 2026-11-14 (3 constats clos par l'agent via l'API) → rouverts.*

**Mémoire**
- **17 — Toute décision s'appuie sur une source localisable** (fichier, identifiant, horodatage). ⚠️ *Provenance des constats (source + `event_id` + `event_index`) et archive des preuves en mémoire longue : en place.*
- **18 — Ce qui est hors fenêtre n'est pas considéré comme vu.** ✅ *Mécanisé : provenance + archive (cf. v1.1 § 6).*

**Dégradation**
- **19 — Un contrôle en erreur, en timeout ou en sortie invalide bloque l'étape** (voir P2). ❌ 🔧 *Faute constatée le 2026-11-14 : le hook d'attestation plantait (`NameError`) et sortait en 1 → non bloquant, et le travail a continué.*

**Garde-fous supplémentaires**
- **Intégrité** : l'agent ne peut pas modifier hooks, settings ni scripts de contrôle. ❌ 🔧 *La deny-list protège déjà ces chemins **pour les outils `Edit|Write`** ; le contournement `Bash` reste ouvert (cf. règle 7).*
- **Réinjection** : les règles immuables sont réinjectées après compaction du contexte. ❌ 🔧

## 📜 3. Consignes (déclarées contournables)

Ces règles reposent sur la bonne volonté de l'agent. Elles ne sont pas immuables.

- **3 — Pas d'auto-attribution de rôle ou de tâche.** Le rôle se lit dans l'état enregistré. *Partiel : le badge lit l'état ; l'agent peut encore s'auto-attribuer dans son texte.*
- **6 — Une étape n'est finie qu'après acceptation par un juge.** Tant que le juge n'est pas défini par code, c'est une consigne.
- **10 — Ne jamais réécrire un choix de l'humain** (titre, nom, décision) sans demande. *Appliqué : le renommage est passé par le script dédié, jamais par édition directe.*
- **11 — Un résultat annoncé est accompagné de la sortie brute**, dans le même message. *Partiel : le format de restitution l'impose, et le Superviseur l'a signalé le 2026-11-13 (« bilan de preuves non étayé »).*
- **12 — Aucun chiffre repris d'un tour précédent** sans nouvelle exécution. *Idem : signalé le 2026-11-13 sur un rapport de session.*
- **13 — Un échec se signale tel quel**, avec sa sortie. *Idem.*
- **16 — Toute affirmation sur ce que l'humain a dit est citée** avec l'identifiant du message. ⚠️ *Partiel : le Superviseur cite la source, mais l'agent peut encore reformuler.*
- **18 — Ce qui est hors fenêtre n'est pas considéré comme vu.** *Passé en règle mécanique (cf. v1.1).*
- **20 — Un doute est une hypothèse étiquetée**, jamais une certitude. ⚠️ *Le Superviseur dispose d'une catégorie `uncertain` ; l'usage côté agent reste une consigne.*

⚠️ Les règles **11, 12, 13, 16, 18 et 20** n'ont été confirmées par aucune source externe. Ce sont des choix de projet, à assumer comme tels — sauf **18**, désormais adossée à un mécanisme (v1.1).

## 🔎 4. Ce qui est vérifié, et ce qui ne l'est pas

✅ **Vérifié dans la doc officielle des hooks** (`code.claude.com/docs/en/hooks`), **mais non reproductible sur le CLI local 2.1.325** (cf. v1.1 § 1) :
- Par défaut, un hook en erreur **ne bloque pas** l'action.
- `onFailure: "block"` existe sur `command` et `http`, à partir de v2.1.295 — *clé non retrouvée dans le binaire local*.
- `exit 1` est un piège : non bloquant, sauf avec `onFailure`.
- Sur `PreToolUse`, un hook expiré ne bloque pas par défaut.
- `PreToolUse`, `UserPromptSubmit` et `Stop` peuvent bloquer avec `exit 2`.

✅ **Vérifié dans `AGENTS.md`** : le Stop hook ne contrôle que la liaison et le bundle.

✅ **Vérifié par l'agent T429 le 2026-11-14** (fait, pas déduction) :
- le hook `PreToolUse` ne couvre que `Write`/`Edit` ; `Bash` n'est pas couvert → une écriture shell échappe au refus, et le cross-check `git status` vs journal la détecte ;
- un hook qui plante sort en **1** → **non bloquant** → le travail continue (constaté sur le hook d'attestation) ;
- la clôture d'un constat par l'agent, via l'API du service, est une auto-validation (3 constats rouverts) ;
- l'implémentation « lecture prouvée » fonctionne : socle de 5 documents, 0 lus → voyant rouge, sans intervention humaine ;
- le garde de périmètre a bien **bloqué** une écriture hors périmètre (dossier d'une autre tâche) et a proposé la dérogation.

## 📚 Sources

- [Hooks reference, Claude Code Docs](https://code.claude.com/docs/en/hooks)
- [OWASP, LLM Prompt Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html)
- Mesures et preuves : `DOC/WFLOW/TASKS/T429_AGENT_SUPERVISOR/T429_AGENT_SUPERVISOR_NOTE_WORKFLOW_POINT_ENTREE_20261113_v1.0.md` · journal interne `%LOCALAPPDATA%\ExcavatriceDragage\trace\trace.jsonl`
