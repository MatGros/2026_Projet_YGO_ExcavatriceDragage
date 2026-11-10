## 0. Cadre de la réponse

Aucun agent secondaire n'a été mobilisé : la mission est traitée directement, donc pas de fiche de délégation à remplir.

- **Faits observés (donnés par la demande)** : fenêtre glissante de 12 messages ; deux défaillances reproductibles (ré-alerte « aucune sortie brute » sur un test réussi à N-15 ; dérive de 100 % sur ~50 tours invisible localement).
- **Inférences** : le juge est *stateless* et ne dispose que du transcript brut ; il n'existe pas de point de passage unique des outils capable de tracer de façon fiable ; le cap initial n'est pas un artefact persisté mais un message qui sort de la fenêtre.
- **Inconnues à lever avant implémentation** : où est construit le prompt juge (fichier/ligne), existe-t-il un *choke point* unique de dispatch des outils, quel tokenizer est utilisé pour le budget, le format de sortie du juge est-il structuré, un `git HEAD + dirty` est-il disponible dans l'environnement d'exécution.

**Thèse d'architecture** : les deux défaillances n'ont pas la même cause et ne se résolvent pas par « un fichier md de mémoire ». La perte de preuve est un problème de **référence** (l'index doit rester dans le contexte, les corps restent sur disque). Le drift lent est un problème de **différentiel contre un référentiel gelé** (le cap), pas de résumé. Un fichier md rédigé par un LLM aggrave les deux : il est non déterministe, non rejouable et hallucinable. La solution est un **journal d'événements append-only + un réducteur pur + une projection à budget fixe**.

---

## 1. Structure du Registre de Contexte Long-Terme (≤ 1 000 tokens)

### Principe : deux couches, pas une

| Couche | Emplacement | Contenu | Coût contexte |
|---|---|---|---|
| **Index** (toujours injecté) | prompt juge | ids + statuts + compteurs, ≤ 1 000 tok | fixe |
| **Corps** (à la demande) | disque, `art/` | stdout/stderr bruts, adressés par id | 0 tant que non demandé |

C'est le seul moyen de tenir 1 000 tokens **sans** réintroduire l'amnésie : si la projection tronque, l'id reste, et le juge peut réclamer le corps via un protocole déterministe (`FETCH_EVIDENCE <id>`, servi par le harnais, pas par un LLM).

### Format : Markdown à sections bornées, rendu par un compilateur

Le md est une **sortie de rendu**, jamais édité à la main ni écrit par le modèle. Source de vérité = `session/events.jsonl`.

```md
## CAP (gelé) — hash c7f1e2 — epoch 3f9a
obj: livrer X vérifié sur Y
done: [D1 E2E PASS, D2 doc, D3 zéro régression]
scope_out: refonte UI
## RECADRAGES
t41 "stabilité > features" (supersede t12) · t12 "ne pas toucher migrations"
## PREUVES (index — corps: art/<id>.log)
E:a1f9 pytest tests/e2e -q   exit0 PASS  t47  e3f9a  → D1
E:b2c3 ruff check .          exit0 PASS  t45  e3f9a
E:c4d5 make build            exit1 FAIL  t44  e3f9a
Σ 47 · 41 PASS · 6 FAIL · 2 STALE
## JALONS
[✓]M1 schéma [✓]M2 tap [~]M3 reducer [ ]M4 juge   (2/4)
## TRAJECTOIRE
drift: t38 .05 → t44 .10 → t47 .25 (seuil .20 ; 2 tours = ALERTE)
dernier recadrage: t41 (6 tours)
## RÈGLES
PASS valide ssi epoch == courante ET postérieur au recadrage invalidant ; sinon STALE.
Preuve absente de l'index = non étayée. Ne jamais redemander une preuve listée PASS valide.
```

≈ 180 tokens : le budget est un **plafond**, pas une cible.

### Budget et politique de troncature (déterministe, pas « au mieux »)

| Section | Plafond | Règle de repli si dépassement |
|---|---|---|
| CAP | 120 | jamais tronqué (immuable) |
| RECADRAGES | 150 | 3 derniers + `Σ n, plus ancien t12` |
| PREUVES | 350 | 1 ligne par `check_id` (dernier statut) + compteurs ; corps sur disque |
| JALONS | 120 | 3 prochains non clos + `(2/4)` |
| TRAJECTOIRE | 100 | 5 derniers points + seuil |
| RÈGLES | 80 | jamais tronqué |
| marge | 80 | — |

Deux garanties : (a) la troncature suit un ordre fixe et est testée par golden files ; (b) **toute preuve tronquée reste atteignable par son id** → la troncature dégrade la verbosité, jamais la traçabilité.

---

## 2. Enregistrement déterministe des preuves (zéro LLM)

**Méthode : event sourcing au point de passage unique des outils + réducteur pur.**

### 2.1 Le tap (écriture)

Toute exécution d'outil passe par un seul *shim* de dispatch qui append une ligne :

```json
{"seq":128,"ts":"2026-02-10T10:00:03Z","kind":"tool","tool":"bash",
 "call_id":"01JQ...","argv":["pytest","tests/e2e","-q"],"argv_sha":"a1f9c2",
 "cwd":"/repo","exit":0,"dur_ms":4210,"stdout_sha":"9f31","stdout_path":"art/128.log",
 "epoch":"3f9a","check_id":"D1"}
```

Contraintes non négociables : append-only, `fsync`, `seq` monotone, **horodatage fourni par le tap** (jamais par le modèle), `epoch` = hash(`git HEAD` + contenus des fichiers modifiés) capturé au moment de l'appel.

### 2.2 PASS/FAIL (dérivation, pas jugement)

`status = f(exit, assertion)` où `assertion` est **déclarée** dans `checks.yaml` — regex sur stdout, code de sortie attendu, JSONPath — jamais interprétée :

```yaml
D1: {cmd_sig: "pytest tests/e2e*", pass_if: {exit: 0, stdout_matches: "\\d+ passed"}}
```

`check_id` est ainsi relié mécaniquement à un critère `done` du CAP. C'est ce lien qui dispense le juge de tout rapprochement sémantique.

### 2.3 Le réducteur (lecture)

```python
ledger = render(fold(events), cap)   # fold pur : ni horloge, ni I/O, ni réseau
```

`fold` produit `{by_check: dernier statut, by_epoch, counts, stale, milestones}`. Propriétés obtenues gratuitement :
- **rejouable** : mêmes events → même ledger, byte pour byte → test golden ;
- **auditables** : `LEDGER_HASH` injecté dans le prompt et recopié dans la sortie du juge ⇒ on sait exactement quelle projection il a vue ;
- **infalsifiables** : seul le tap écrit ; le juge est en lecture seule ; une affirmation de preuve absente de l'index est *unsupported* par construction.

### 2.4 Validité temporelle — le piège symétrique

Une preuve PASS ne doit pas être éternelle. Règle : `valid = (evidence.epoch == current_epoch) AND (evidence.seq > last_invalidating_recadrage.seq)`. Si `epoch` diffère, la ligne passe `STALE` → le juge **a le droit** de demander une ré-exécution. Sans cette règle, vous échangez l'amnésie contre le rejeu d'un PASS obsolète, ce qui est pire (faux positif de succès).

---

## 3. Ce que `OMNI_JUDGE_SYSTEM` doit faire du registre

Trois ajouts, formulés comme des règles opérationnelles et non des recommandations.

### 3.1 Résolution de preuve (anti-ré-alerte)

> Avant toute alerte « aucune sortie brute observable » : (1) recherche `check_id` ou `argv_sha` dans PREUVES ; (2) si une ligne `PASS` existe avec `epoch == courante` et `seq > dernier recadrage invalidant` → **la preuve est acquise**, citer `E:<id>`, ne pas ré-exécuter, ne pas redemander ; (3) si `STALE` ou absente → alerte autorisée, en nommant le `check_id` manquant ; (4) si le corps brut est nécessaire, émettre `FETCH_EVIDENCE <id>` et attendre l'injection au tour suivant — ne pas conclure en son absence.

Sortie : `PREUVE RÉFÉRENCÉE: E:a1f9 (→ D1)` au lieu de l'alerte.

### 3.2 Détection du drift (diff contre référentiel gelé)

Le juge ne compare **pas** le tour N au tour N-12 (c'est précisément ce qui rend le drift lent invisible). Il produit, pour chaque item du CAP, une classification ancrée :

```json
{"drift":[{"cap":"D1","state":"servi","evidence":"E:a1f9"},
          {"cap":"scope_out:UI","state":"contredit","evidence":"E:c4d5"}]}
```

Le harnais calcule ensuite `drift_t = 1 - Σ poids(servi)/Σ poids` et conserve la série. **L'alerte ne vient pas du juge mais du calcul** :

```
ALERTE si ∃ item "contredit"            (drift dur, immédiat)
       ou drift_t > 0.20 ET pente > 0 sur K=3 tours   (drift lent, hystérésis)
```

Deux propriétés décisives : `contredit` est un signal **absolu** (aucune fenêtre ne peut le diluer), et la pente sur 3 points rend visible une dérive de +0,03/tour que chaque fenêtre locale juge « normale ».

### 3.3 Ré-ancrage périodique

Tous les N tours (ou dès que `drift_t` monte), réinjecter le bloc CAP **verbatim**, en tête, comme rappel système — pas un résumé, le texte gelé. Coût ~120 tokens, effet mesureable sur l'ancrage, et indépendant de toute intelligence du juge.

---

## 4. Recommandation immédiate pour T429

Découpage en 5 incréments, chacun livrable et testable seul, dans cet ordre (les deux premiers suffisent à tuer la défaillance n°1) :

| # | Livrable | Critère d'acceptation |
|---|---|---|
| T429-1 | Tap `session/events.jsonl` au dispatch unique + `epoch` + `checks.yaml` | 100 % des exécutions tracées ; rejeu d'events → ledger identique (golden) |
| T429-2 | `render(fold(...), cap)` avec budgets du §1 | test CI : ledger ≤ 1 000 tokens sur un cas à 200 events ; CAP jamais tronqué |
| T429-3 | Injection dans `OMNI_JUDGE_SYSTEM` + règles 3.1 | scénario reproduit : test réussi à N-15 ⇒ **zéro** ré-alerte à N, sortie contient `PREUVE RÉFÉRENCÉE` |
| T429-4 | `FETCH_EVIDENCE` servi par le harnais | preuve tronquée récupérable en 1 tour, sans ré-exécution |
| T429-5 | Série `drift_t` + seuils + ré-ancrage | simulation 50 tours → alerte au plus tard 3 tours après le premier `contredit` |

**Explicitement hors périmètre T429** : embeddings, base vectorielle, résumé sémantique par LLM, « mémoire » éditable par l'agent. Aucun des deux symptômes ne les requiert, et ils réintroduisent le non-déterminisme que vous cherchez à supprimer.

---

## Risques résiduels et points de vigilance

1. **Dérive registre/réalité** : si un outil contourne le shim, le registre ment par omission. Mitigation : test d'intégrité qui vérifie que le nombre d'appels du shim égale le nombre d'entrées.
2. **Empoisonnement** : le ledger ne doit être inscriptible que par le tap ; le juge ne doit jamais pouvoir l'éditer ni s'auto-attribuer un `check_id`.
3. **Faux PASS persistant** : couvert par `epoch`, à vérifier impérativement — un `epoch` mal calculé (ex. ignorant les fichiers non suivis) invalide tout le dispositif.
4. **Budget token** : à mesurer avec le tokenizer réel du modèle juge, pas une estimation `len()/4`.
5. **Décision à prendre avant T429-1** : le point de passage unique des outils existe-t-il réellement, ou faut-il l'introduire (ce qui élargit le périmètre) ? C'est le seul point bloquant du plan.