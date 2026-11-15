# T427 — Échanges inter-agents et cas limites · v0.3 (2026-11-15)

> **Remplace la v0.2.** Cycle 2 : 4 contradictions bloquantes levées, 2 points mineurs
> corrigés. Sources dans `PREUVES/20261115_ECHANGES_CHALLENGE/` :
> `AGENT_A_COUVERTURE`, `AGENT_B_REDTEAM`, `AGENT_C_VERIFICATION_V02`.
> **Statut : proposition publiée.** Rien n'est actif tant que ce n'est pas inscrit dans
> `AGENTS.md` ou outillé par un script — et les 4 parades ci-dessous ne sont **pas encore
> outillées**.

## 1. Objet

Plusieurs agents travaillent le même dépôt, en parallèle, sur des tâches différentes.
Le risque n'est pas le conflit visible — c'est **l'absence invisible** : un message perdu,
une session morte, une autorité ambiguë, un échange jamais clos.

Objectif : toute absence produit une **trace** et une **échéance**, jamais un silence.

## 2. Deux verbes, à ne plus confondre

- 🚫 **Solliciter** — contacter une session de sa propre initiative pour coordonner,
  attribuer, réaffecter. **Interdit** sans désignation humaine ou de l'orchestrateur.
- ✅ **Signaler** — déclarer un blocage, un manque ou un désaccord. **Obligatoire**.

Le signalement a **son propre canal** : la trace durable (journal) **plus** une copie
datée dans le dossier de la tâche de l'émetteur. Il a **sa propre échéance** : la date de
revue attendue. Un signalement sans échéance est un trou sans fond — c'était le défaut de
la v0.2.

## 3. Procédure d'échange

Format unique, une consigne = un objet :
`from` · `to` · `tâche` · `objet` · `demande` · **preuve attendue** · **échéance** · `réf. de session`.

1. **Désignation** — l'humain ou l'orchestrateur nomme émetteur et destinataire.
2. **Consigne** — format ci-dessus, échéance **obligatoire**, avec fuseau.
3. **Accusé** — `RECU` + ce qui sera fait + **quand**.
4. **Réponse** — §4. « Fait » sans preuve = non fait.
5. **Clôture** — `CLOS` par l'émetteur, ou arbitrage humain daté et motivé.

### Clause de silence (corrigée au cycle 2)

**Échéance effective** = la date promise dans `RECU` ; à défaut d'accusé, l'échéance de la
consigne. **Le déclenchement porte sur l'absence de réponse**, pas sur l'absence d'accusé :
un `RECU` sans réponse fait échouer l'échange exactement comme un silence total.

À l'échéance effective sans réponse → **une** relance documentée, puis escalade humaine.
Chaque étape est une ligne datée dans la trace.

### Relais (quand la messagerie ne passe pas)

`RELAY_<émetteur>_<destinataire>_<horodatage>.md` dans `.tmpsandbox/`, **TTL écrit dans le
fichier**, copie durable dans `PREUVES/` au `CLOS`. `.tmpsandbox/` seul n'est **jamais**
une preuve : il est purgé.

## 4. Ce qui compte comme preuve

Une preuve = **triplet** : commande exacte + contexte (`commit`, date) + **code retour**,
plus la sortie brute. Sans code retour, une commande qui échoue produit une preuve valide.

- **Hash conservé avec la preuve** au moment de la citation (correctif cycle 2) : sans lui,
  « preuve invalidée » (UC-12) est indétectable, faute de référence à comparer.
- Sous-agent **sans outils** : sa preuve est la sortie d'exécution du prompt fourni ;
  l'orchestrateur la rend durable dans `PREUVES/` avant `CLOS`.
- Preuve **invalidée** (fichier modifié ou supprimé après citation) → annulée, à re-citer.

## 5. Travail en équipe — propriété

- **1 donnée = 1 producteur.** Deux agents qui calculent la même vérité finissent par diverger.
- **1 fichier = 1 écrivain à la fois.**
- **Verrou : procédure de demande (corrigée au cycle 2).** Le registre des verrous est
  `TASKS.yaml` ; or le gabarit de délégation **interdit aux exécutants d'y écrire**.
  Conséquence assumée : **un délégué ne prend jamais son verrou lui-même**. Il le
  **demande** à l'orchestrateur avec la consigne §3 (objet : « verrou `<chemin>` »),
  l'échéance de la demande étant soumise à la clause de silence. Si l'orchestrateur est
  injoignable : le délégué **signale** (§2) et n'écrit pas le fichier.
  ⚠️ **Convention non outillée** : le défaut **B2** (20 écritures simultanées → 13 entrées)
  est **toujours ouvert**. Un journal chaîné garantit l'ordre, **pas la non-perte**.
- **Preuves dans `DOC/WFLOW/TASKS/<ID>_<NOM>/PREUVES/`**, jamais à la racine.
- **Aucun commit par un agent délégué.** La fusion relève du coordinateur.
- **Un RT reste sur sa tâche** ; sans orchestrateur il **signale**, il ne reprend pas les
  autres chantiers.

### Journalisation concurrente (corrigé au cycle 2)

`miss_log` écrit par plusieurs agents reproduit B2 **dans le remède lui-même**. Règle :

1. chaque émetteur écrit **son** journal dans **son** dossier de tâche, avec un numéro de
   séquence propre à l'émetteur ;
2. le coordinateur **fusionne** et détecte les trous de séquence ;
3. une écriture directe au journal global par un agent non coordinateur est un manquement.

## 6. Autorité — règle fail-closed

- **Ambiguïté d'autorité ⇒ arrêt des écritures hors dossier de tâche + trace immédiate +
  escalade humaine.** Aucune session ne s'attribue l'autorité par sa propre lecture.
- **Homonymie de session** (deux `T000-CC10` observées) : la **réf. de session est
  obligatoire** dans tout message. En cas de doute : pause, question au désignateur, trace.
  ❌ Jamais « la session qui répond le plus vite ».
- Le Superviseur fait foi **sur l'état** (lecture seule). Il ne tranche pas les désaccords.

## 7. GO tracé — intérim

Aucun registre des GO n'existe. Intérim obligatoire :
`GO <tâche> <réf. émetteur> <périmètre>` **+ copie datée** dans le dossier de tâche.
Un « GO » verbal non copié n'autorise rien. **Qui copie** : l'émetteur du GO, à réception.

## 8. Cas d'usage — tests orientés usage

Un cas non réalisé **sort de la suite normative** : il vit dans
`MANIFESTE_CAS_NON_IMPLANTES.md`, et la suite échoue si le nombre de `xfail` dépasse le
compteur déclaré. Un `xfail` n'est pas une preuve de conformité.

| Cas | Attendu |
|---|---|
| UC-01 Reprise après mort de session | note de reprise (fait / prouvé / restant), pas de rejeu |
| UC-02 Deux agents, même fichier | **un seul** comportement : le second est **refusé** ; verrou orphelin repris comme UC-01 |
| UC-03 Orchestrateur indisponible | le RT continue sa tâche et **signale** ; aucun relais d'autrui |
| UC-04 Désaccord de preuve | artefact contesté **gelé**, arbitrage humain daté et motivé |
| UC-05 Demande hors périmètre | refus motivé + chemin du périmètre + procédure de dérogation |
| UC-06 « OK » sans action | absence de preuve = non-réalisation |
| UC-07 Message perdu | relais nommé + TTL + copie durable avant `CLOS` |
| UC-08 Élargissement en session | empreinte divergente → refus (canonicalisation à spécifier) |
| UC-09 Tâche sans contrat | écriture **uniquement** dans son dossier de tâche |
| UC-10 Fin de sprint concurrente | décideur nommé ; départage criticité → ID → horodatage |
| UC-11 Livraison double | **ID canonique de consigne = hash des 8 champs §3** ; même hash = une seule exécution |
| UC-12 Preuve invalidée | hash stocké à la citation (§4) ; divergence → preuve annulée |
| UC-13 Reprise d'une tâche clôturée | refus explicite, pas de réouverture silencieuse |
| UC-14 Ordres contradictoires de deux coordinateurs | fail-closed (§6) |
| UC-15 Horloge et fuseau | horodatage avec fuseau ; horloge de référence = Superviseur |
| UC-16 Verrou orphelin | TTL + reprise tracée, pas de déblocage manuel non journalisé |

## 9. Cas problématiques et parades

- 🟠 **Messagerie non fiable** — réf. obligatoire, relais nommé, accusé. *Résiduel : perte silencieuse possible.*
- 🔴 **Écriture concurrente (B2)** — seul écrivain unique. *Résiduel : non corrigé.*
- 🔴 **Auto-validation** — clôture par l'humain ou un juge enregistré **listé**. *Un arbitrage non daté et non motivé n'est pas une preuve.*
- 🟠 **Preuve fabriquée** — triplet §4 + hash. *Résiduel : une sortie recopiée d'un autre tour peut passer.*
- 🟠 **Dérive de périmètre** — garde + deny-list. *Résiduel : écritures shell non branchées (lot 2, hook à raccorder).*
- 🟠 **Orchestrateur absent** — signalement obligatoire, reprise interdite.
- 🟡 **Contexte saturé** — état dans le dossier de tâche, pas en mémoire vive.
- 🟡 **Doublon de session** — réf. obligatoire, jamais de choix implicite.
- 🟡 **Superviseur lent/en erreur** — dernière valeur connue, mention explicite. *Résiduel : statut faux lu comme vrai.*
- 🔴 **GO non tracé** — intérim §7.

## 10. Ce que ce document ne couvre pas

- Rien n'est **imposé par le code** : conventions tant qu'elles ne sont pas outillées.
- Les **4 parades du cycle 2** (échéance effective, canal des signalements, demande de
  verrou, journalisation par émetteur) sont **écrites, non outillées**.
- Aucune protection contre un agent **délibérément** hors cadre.
- Aucun SLA d'arbitrage humain : le défaut « humain pressé » est **reconnu**, pas résolu.
- La **canonicalisation** des champs (UC-08, UC-11) reste à spécifier avant outillage.
