# T427 — Échanges inter-agents et cas limites · v0.1 (2026-11-15)

> Livrable de T427 : procédures d'échange d'information et de travail en équipe, cas
> problématiques et parades. **Statut : proposition**, à challenger puis à verser en v1.0.
> Aucune règle de ce document n'est active tant qu'elle n'est pas intégrée à `AGENTS.md`
> ou à une skill.

## 1. Objet

Plusieurs agents travaillent le même dépôt, en parallèle, sur des tâches différentes.
Constat mesuré : deux sessions portant le même nom `T000-CC10` coexistent, `TASKS.yaml`
bouge sous les pieds des sessions, quatre chantiers écrivent en même temps.

Objectif : **qu'un désaccord, une absence ou une collision se voie et se règle**, au lieu
de produire un silence.

## 2. Canaux disponibles (état réel, pas une intention)

- 🗣️ **`SendMessage` / `ListAgents`** — session ↔ session, local, texte brut. Liste
  **partielle** : seules les sessions joignables apparaissent ; le nom peut être
  ambigu (deux entrées `T000-CC10` observées le 2026-11-15, réf. `[27b657]` / `[db4cd4]`).
- 🛡️ **Superviseur `127.0.0.1:8082`** — état des sessions, tâche, criticité, alertes.
  L'agent **lit** ; il ne s'auto-attribue jamais un état.
- 🗂️ **`DOC/WFLOW/TASKS.yaml`** — catalogue. **Un seul écrivain** : le coordinateur désigné.
- 📁 **`DOC/WFLOW/TASKS/<ID>_<NOM>/` + `PREUVES/`** — preuves durables, versionnées.
- 🧪 **`.tmpsandbox/`** — échanges volatils, jamais une preuve.
- 🤖 **`ollama_subagent.py`** — délégation **sans outils** : le contenu doit être fourni
  dans le prompt (`--file`), l'agent ne va jamais lire le dépôt lui-même.
- 📓 **`trace_log.py` / `miss_log.py`** — journal d'événements et manquements constatés.
- 🔒 **`task_scope.py`** — périmètre de tâche, périmètre épinglé, dérogations.

## 3. Procédure d'échange — 5 étapes

1. **Désignation.** L'exploitant (ou l'orchestrateur désigné) nomme émetteur et
   destinataire. ❌ Aucun agent ne contacte une session de sa propre initiative.
2. **Consigne.** Format court, une consigne = un objet :
   `from` · `to` · `tâche` · `objet` · `demande` · **preuve attendue** · échéance.
3. **Accusé.** Le destinataire répond d'abord `RECU` + ce qu'il va faire + quand.
   ❌ Pas d'action silencieuse.
4. **Réponse.** Verdict **et** preuve (`fichier:ligne`, sortie de commande, hash).
   « Fait » sans preuve = non fait.
5. **Clôture.** L'émetteur écrit `CLOS`, ou l'humain tranche. Un échange non clos est
   un risque ouvert, pas un détail.

## 4. Travail en équipe — règles de propriété

- **1 donnée = 1 producteur.** Deux agents qui calculent la même vérité finissent par
  diverger.
- **1 fichier = 1 écrivain à la fois.** Verrou porté par le catalogue (colonne agent).
- **Preuves dans `PREUVES/`**, jamais à la racine ni dans `.tmpsandbox/`.
- **Aucun commit par un agent délégué** ; aucun `push` sans relecture humaine du diff.
- **Un agent RT reste sur sa tâche.** Sans orchestrateur joignable, il ne reprend pas
  les chantiers des autres : il signale **en une ligne**.

## 5. Cas d'usage — tests orientés usage

Convention : un test par cas, dans `TOOLS/AGENT_WORKFLOW/tests/test_workflow_backlog.py`.
Un cas non réalisé = `xfail(strict=True)` — il devient rouge dès qu'il passe.

- **UC-01 · Reprise après mort de session** — la session tombe ; une nouvelle relit le
  dossier de tâche et la dernière preuve, et **reprend sans rejouer** ce qui est prouvé.
- **UC-02 · Deux agents sur le même fichier** — le second est refusé ou averti, pas
  écrasé en silence.
- **UC-03 · Orchestrateur indisponible** — le RT continue sa tâche, signale l'absence,
  **ne prend pas le relais** des autres chantiers.
- **UC-04 · Désaccord de preuve** — émetteur et destinataire citent chacun leur sortie ;
  l'arbitrage revient à l'humain, jamais au plus bavard.
- **UC-05 · Demande hors périmètre** — refus motivé, chemin du périmètre en réponse,
  procédure de dérogation proposée.
- **UC-06 · Agent qui répond « OK » sans agir** — l'absence de preuve vaut non-réalisation.
- **UC-07 · Message perdu / pair non listé** — relais par fichier daté dans
  `.tmpsandbox/` + nouvelle tentative ; trace obligatoire.
- **UC-08 · Élargissement de périmètre en session** — l'empreinte du contrat diverge :
  refus, pas de rattrapage tacite.
- **UC-09 · Tâche sans contrat** — pas de périmètre produit : l'agent écrit **rien**
  hors documents de tâche, et le dit.
- **UC-10 · Fin de sprint concurrente** — plusieurs agents rendent en même temps :
  l'ordre de fusion est décidé, pas subi.

## 6. Cas problématiques et parades

- 🟠 **Messagerie non fiable** (liste partielle, homonymes) — désambiguïser par la réf.,
  relais fichier, accusé obligatoire. *Résiduel : un message peut se perdre sans bruit.*
- 🔴 **Écriture concurrente** — verrou + journal chaîné. *Résiduel : défaut B2 mesuré
  (20 écritures simultanées → 13 entrées). Non corrigé.*
- 🔴 **Auto-validation** — la clôture revient à l'humain ou à un juge enregistré.
  *Résiduel : un humain pressé valide sans lire.*
- 🟠 **Preuve fabriquée** — exiger la commande reproductible, pas le résultat raconté.
  *Résiduel : une sortie recopiée d'un autre tour peut passer.*
- 🟠 **Dérive de périmètre** — garde de périmètre + deny-list. *Résiduel : les écritures
  par commande shell ne sont pas encore branchées (lot 2, hook à raccorder par l'exploitant).*
- 🟠 **Orchestrateur absent** — le RT reste sur sa tâche. *Résiduel : les tâches qui
  attendaient une attribution restent bloquées, et personne ne le voit.*
- 🟡 **Contexte saturé** — écrire l'état dans le dossier de tâche, pas dans la mémoire vive.
- 🟡 **Doublon de session** — deux sessions du même nom : la réf. est obligatoire dans
  tout message ; sinon la consigne peut partir au mauvais agent.
- 🟡 **Superviseur lent ou en erreur** — la barre de statut réutilise la dernière valeur
  connue. *Résiduel : un statut faux peut être lu comme vrai.*
- 🔴 **GO non tracé** — un « GO » verbal se perd. *Registre des GO avec identifiant de
  message : constat de revue n°2, **non livré**.*

## 7. Ce que ce document ne couvre pas

- Aucun mécanisme **imposé** par le code : ce sont des conventions tant qu'elles ne sont
  pas outillées ou inscrites dans `AGENTS.md`.
- Aucune protection contre un agent **délibérément** hors cadre : le garde ferme la
  négligence, pas la malveillance.
- Aucune réponse au **conflit d'autorité** entre deux sessions qui se croient toutes deux
  orchestratrices — cas observé, non tranché.
