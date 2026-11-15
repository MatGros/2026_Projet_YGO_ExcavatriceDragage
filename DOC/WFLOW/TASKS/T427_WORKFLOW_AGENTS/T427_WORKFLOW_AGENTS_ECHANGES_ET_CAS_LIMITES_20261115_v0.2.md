# T427 — Échanges inter-agents et cas limites · v0.2 (2026-11-15)

> **Remplace la v0.1.** Corrections issues de deux revues adverses indépendantes
> (`PREUVES/20261115_ECHANGES_CHALLENGE/AGENT_A_COUVERTURE.md`, `AGENT_B_REDTEAM.md`),
> constats convergents sur 10 points.
> **Statut : proposition.** Aucune règle n'est active tant qu'elle n'est pas inscrite dans
> `AGENTS.md` ou outillée par un script.

## 1. Objet

Plusieurs agents travaillent le même dépôt, en parallèle, sur des tâches différentes.
Le risque n'est pas le conflit visible — c'est **l'absence invisible** : un message perdu,
une session morte, une autorité ambiguë, un échange jamais clos.

Objectif : que toute absence produise une **trace** et une **échéance**, pas un silence.

## 2. Deux verbes, à ne plus confondre

C'est la correction n°1 des deux revues : la v0.1 se contredisait.

- 🚫 **Solliciter** — contacter une session de sa propre initiative pour coordonner,
  attribuer, réaffecter. **Interdit** sans désignation humaine ou de l'orchestrateur.
- ✅ **Signaler** — déclarer un blocage, un manque ou un désaccord. **Obligatoire**, sur
  **un seul canal** et dans **un seul format** (§3).

Un RT qui se tait viole la règle ; un RT qui sollicite aussi. Seul le signalement est dû.

## 3. Procédure d'échange

Format unique, une consigne = un objet :
`from` · `to` · `tâche` · `objet` · `demande` · **preuve attendue** · **échéance** · `réf. de session`.

1. **Désignation** — l'humain ou l'orchestrateur nomme émetteur et destinataire.
2. **Consigne** — le format ci-dessus, échéance **obligatoire**.
3. **Accusé** — `RECU` + ce qui sera fait + quand. Pas d'action silencieuse.
4. **Réponse** — voir §4. « Fait » sans preuve = non fait.
5. **Clôture** — `CLOS` par l'émetteur, ou arbitrage humain.

**Clause de silence (§2 des revues) :** à l'échéance, sans accusé ni réponse →
`miss_log.record(...)`, **un** relais documenté, puis escalade humaine. Un échange non clos
n'est plus un « risque ouvert » abstrait : c'est une ligne datée dans le journal.

**Relais** (quand la messagerie ne passe pas) — fichier nommé
`RELAY_<émetteur>_<destinataire>_<horodatage>.md` dans `.tmpsandbox/`, avec **TTL écrit
dans le fichier** et copie durable dans `PREUVES/` au moment du `CLOS`. `.tmpsandbox/` seul
n'est **jamais** une preuve : il est purgé par la politique de nettoyage.

## 4. Ce qui compte comme preuve

Correction n°2 : « `fichier:ligne`, sortie de commande, hash » n'était pas exploitable.

Une preuve = **triplet** : commande exacte + contexte (`commit`, date) + **code retour**,
plus la sortie brute. Sans code retour, une commande qui échoue produit une preuve valide —
donc inutile.

- Sous-agent **sans outils** : sa preuve est la **sortie d'exécution du prompt fourni** ;
  l'orchestrateur la rend durable dans `PREUVES/` avant `CLOS`. Une réponse de sous-agent
  n'est pas vérifiable par elle-même.
- Preuve **invalidée** (fichier modifié ou supprimé après citation) : elle ne vaut plus rien.
  Re-citer après relecture.

## 5. Travail en équipe — propriété

- **1 donnée = 1 producteur.** Deux agents qui calculent la même vérité finissent par diverger.
- **1 fichier = 1 écrivain à la fois.** ⚠️ **Convention non outillée** : le registre des
  verrous est `TASKS.yaml`, et le défaut **B2** (20 écritures simultanées → 13 entrées) est
  **toujours ouvert**. Un journal chaîné garantit l'ordre, **pas la non-perte**. Seule une
  sérialisation par un écrivain unique la garantit.
- **Preuves dans `PREUVES/`** — `DOC/WFLOW/TASKS/<ID>_<NOM>/PREUVES/`, jamais à la racine.
- **Aucun commit par un agent délégué.** La fusion relève du coordinateur, pas des agents.
- **Un RT reste sur sa tâche** ; sans orchestrateur joignable il **signale** (§2), il ne
  reprend pas les autres chantiers.

## 6. Autorité — règle fail-closed

Correction n°3 : la v0.1 laissait « non tranché » le cas le plus dangereux.

- **Ambiguïté d'autorité ⇒ arrêt des écritures hors dossier de tâche + trace immédiate +
  escalade humaine.** Aucune session ne s'attribue l'autorité par sa propre lecture.
- **Homonymie de session** (deux `T000-CC10` observées) : la **réf. de session est
  obligatoire** dans tout message. En cas de doute : pause, question au désignateur, trace.
  ❌ Jamais « la session qui répond le plus vite ».
- Le Superviseur fait foi **sur l'état** (lecture seule). Il ne tranche pas les désaccords.

## 7. GO tracé — intérim

Aucun registre des GO n'existe (constat de revue n°2, non livré). Intérim obligatoire :

`GO <tâche> <réf. émetteur> <périmètre>` **+ copie datée** dans le dossier de tâche.
Un « GO » verbal non copié n'autorise rien.

## 8. Cas d'usage — tests orientés usage

⚠️ Correction n°4 : `xfail(strict=True)` sur 10 cas rend la suite **verte à 0 %
d'implémentation**. Un cas non réalisé sort donc de la suite normative : il vit dans un
**manifeste séparé** (`MANIFESTE_CAS_NON_IMPLANTES.md`), et la suite échoue si le nombre de
`xfail` **dépasse le compteur déclaré**.

| Cas | Attendu |
|---|---|
| UC-01 Reprise après mort de session | note de reprise (fait / prouvé / restant) relue, pas de rejeu |
| UC-02 Deux agents, même fichier | **un seul** comportement : le second est **refusé** (pas « refusé ou averti »), verrou orphelin repris par la même règle qu'UC-01 |
| UC-03 Orchestrateur indisponible | le RT continue sa tâche et **signale** ; aucun relais d'autrui |
| UC-04 Désaccord de preuve | artefact contesté **gelé**, arbitrage humain daté et motivé |
| UC-05 Demande hors périmètre | refus motivé + chemin du périmètre + procédure de dérogation |
| UC-06 « OK » sans action | absence de preuve = non-réalisation |
| UC-07 Message perdu | relais nommé + TTL + copie durable avant `CLOS` |
| UC-08 Élargissement en session | empreinte divergente → refus (champs et canonicalisation à spécifier) |
| UC-09 Tâche sans contrat | écriture **uniquement** dans son dossier de tâche ; le reste refusé |
| UC-10 Fin de sprint concurrente | décideur nommé (orchestrateur, sinon humain) ; départage criticité → ID → horodatage |
| UC-11 Livraison double | même consigne reçue deux fois = **une seule** exécution (idempotence) |
| UC-12 Preuve invalidée | fichier modifié ou supprimé après citation → preuve annulée |
| UC-13 Reprise d'une tâche déjà clôturée | refus explicite, pas de réouverture silencieuse |
| UC-14 Ordres contradictoires de deux coordinateurs | fail-closed (§6) |
| UC-15 Horloge et fuseau des échéances | horodatage avec fuseau, jamais local implicite |
| UC-16 Verrou orphelin | TTL + reprise tracée, pas de déblocage manuel non journalisé |

## 9. Cas problématiques et parades

- 🟠 **Messagerie non fiable** — réf. obligatoire, relais nommé, accusé. *Résiduel : perte silencieuse possible.*
- 🔴 **Écriture concurrente (B2)** — seul écrivain unique. *Résiduel : non corrigé.*
- 🔴 **Auto-validation** — clôture par l'humain ou un juge enregistré **listé**. *Un arbitrage non daté et non motivé n'est pas une preuve.*
- 🟠 **Preuve fabriquée** — triplet §4. *Résiduel : une sortie recopiée d'un autre tour peut passer.*
- 🟠 **Dérive de périmètre** — garde + deny-list. *Résiduel : écritures shell non branchées (lot 2).*
- 🟠 **Orchestrateur absent** — signalement obligatoire, reprise interdite.
- 🟡 **Contexte saturé** — état dans le dossier de tâche, pas en mémoire vive.
- 🟡 **Doublon de session** — réf. obligatoire, jamais de choix implicite.
- 🟡 **Superviseur lent/en erreur** — dernière valeur connue, mention explicite. *Résiduel : statut faux lu comme vrai.*
- 🔴 **GO non tracé** — intérim §7.

## 10. Ce que ce document ne couvre pas

- Rien n'est **imposé par le code** : conventions tant qu'elles ne sont pas outillées.
- Aucune protection contre un agent **délibérément** hors cadre.
- Aucun SLA d'arbitrage humain : le défaut « humain pressé » est **reconnu**, pas résolu.
