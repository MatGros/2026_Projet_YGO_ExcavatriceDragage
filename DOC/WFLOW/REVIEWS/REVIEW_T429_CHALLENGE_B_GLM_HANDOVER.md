# Rapport de review — Challenge B — AC-F1.7 (Handover / Collision de tâche / Validation canonique)

## 0. Cadre et limites de cette review

- **Rôle :** reviewer technique indépendant, lecture seule, aucune exécution.
- **Matériaux réellement disponibles :** uniquement le contenu du brief de délégation, qui cite le pattern verbatim : `ALIAS_PATTERN = r"^T\d+(-[0-9A-Z]+)?-(CC|AGY|CDX|DSH|OPC)\d{2}\s+.+$"` et décrit (sans le montrer) le code de `reassign` et des tests.
- **Conséquence :** le critère C1 est auditable par analyse du pattern cité. Les critères C2 et C3 dépendent de code que je n'ai pas sous les yeux : ils sont marqués **NON ÉVALUABLE** plutôt que PASS. Aucune vérification indirecte n'est comptée comme PASS.
- Étiquettes : **OBSERVÉ** = présent tel quel dans le brief ; **INFÉRENCE** = déduit par analyse du pattern (non exécuté ici) ; **INCONNU** = dépend du code non fourni.

## 1. C1 — Audit de `ALIAS_PATTERN`

### 1.1 Structure du pattern (OBSERVÉ)

| Segment | Rôle | Exemples acceptés |
|---|---|---|
| `T\d+` | ID de tâche | `T429`, `T428`, `T0429` ⚠️ |
| `(-[0-9A-Z]+)?` | variante optionnelle | `-1`, `-42`, `-A`, `-CC01` ⚠️ |
| `-` | séparateur obligatoire | |
| `(CC\|AGY\|CDX\|DSH\|OPC)\d{2}` | code agent + n° 01–99 | `CC01`, `AGY07`, `OPC99` |
| `\s+.+$` | label libre (≥1 espace, ≥1 n'importe quel caractère sauf `\n`) | |

### 1.2 Couverture des formes demandées

- **Agents (CC, AGY, CDX, DSH, OPC) :** les cinq sont présents, sans ambiguïté de préfixe (`T429-CDS01` est bien rejeté). **INCONNU** : si cette liste est la source de vérité du système ou une copie codée en dur (risque de divergence avec `supervisor_service.py` / IHM à l'ajout d'un 6ᵉ agent).
- **Variantes citées (`T429`, `T428-1`) :** couvertes — `(-[0-9A-Z]+)?` accepte les variantes numériques et alphanumériques majuscules, et est optionnelle.

**Sous-verdict fonctionnel : PASS** sur la base du pattern cité. **Sous-verdict robustesse : PARTIEL**, pour les findings ci-dessous.

### 1.3 Findings

| ID | Sévérité | Description |
|---|---|---|
| F1-01 | **MOYEN (conditionnel)** | `$` (au lieu de `\Z`/`fullmatch`) accepte un `\n` final : `T429-CC01 X\n` matcherait si le pattern est appliqué via `re.match`/`re.search`. Alias validé ≠ alias stocké → risque de lookup raté / doublon. **INCONNU** : le call-site `re.*` réel. Une ligne suffit à trancher. |
| F1-02 | **MOYEN** | Le pattern **ne garantit pas l'unicité canonique** : espaces multiples (`\s+`), label pur espaces, NBSP, casse différente produisent des alias distincts au sens chaîne mais identiques au sens « carte ». Si la dédup de l'IHM compare des chaînes exactes, le besoin d'origine (« sans doublon de carte ») n'est couvert que partiellement — sauf normalisation amont (**INCONNU**). |
| F1-03 | FAIBLE | Casse strictement sensible (`t429`, `T429-cc01` rejetés). Voulu (« format canonique strict ») probablement, mais à verrouiller par un test explicite. |
| F1-04 | MOYEN | Liste d'agents **codée en dur** dans le regex → maintenance couplée ; recommandation : construire le pattern depuis une constante partagée + test paramétré sur cette source. |
| F1-05 | FAIBLE | `\d{2}` plafonne à 99 instances par type (`AGY100` rejeté). Limite latente à documenter. |
| F1-06 | FAIBLE/MOYEN | Zéros initiaux acceptés : `T0429-CC01 X` match. Si l'ID canonique est `T429`, deux alias désignent la même tâche. **INCONNU** si normalisation numérique amont. |
| F1-07 | INFO | Variante libre : `T429-CC01-CC01 A` est valide (variante = « CC01 », agent = CC01). Acceptable si la variante est opaque — sinon contraindre. |
| F1-09 | FAIBLE | Label « vide » possible : `T429-CC01␣␣` (≥2 espaces de fin) match, car `.` matche aussi les espaces après backtrack de `\s+`. `T429-CC01␣` seul est rejeté. |
| F1-08 | INFO (négatif) | Pas de ReDoS identifié : pas de quantificateurs imbriqués sur alphabets chevauchants, backtracking borné. Analyse statique du pattern cité. |

**Preuves vérifiables en une commande** (INFÉRENCE — non exécuté dans ce contexte ; à lancer par le coordinateur) :

```
python -c "import re; p=r'^T\d+(-[0-9A-Z]+)?-(CC|AGY|CDX|DSH|OPC)\d{2}\s+.+$'; print(bool(re.match(p,'T429-CC01 X\n')), bool(re.match(p,'T429-CC01  ')), bool(re.match(p,'T0429-CC01 X')))"
# attendu d'après analyse : True True True
```

## 2. C2 — Audit de l'action `reassign` — **NON ÉVALUABLE (bloqué)**

Aucun code de `reassign` disponible. Je ne peux ni confirmer ni infirmer l'absence d'écrasement sur `transcript_path` / `checkpoint` / `alerts` / `comments` / `decisions`. Checklist d'audit à mener dès réception du code :

1. **Validation avant mutation** : le pattern est-il appliqué avant toute écriture ?
2. **Alias inexistant** : erreur explicite ou création implicite (= source première de doublons de carte) ?
3. `transcript_path` : ancien chemin archivé ou écrasé (perte d'historique si réassignation ultérieure) ?
4. `checkpoint` : transporté, invalidé ou dupliqué ? Compatible cross-plateforme sinon fausse confiance.
5. `alerts` : garde historique levée par `handover: True` — les alertes restent-elles actives et **ré-attribuées** au nouvel agent, ou orphelines ? Fenêtre de ré-émission ?
6. `agent_id` : écrasement scalaire (l'historique « qui a fait quoi » est perdu) vs ajout à une liste ; l'événement `session_handover` porte-t-il old_agent + new_agent + timestamp + raison ?
7. **Concurrence/atomicité** : read-modify-write verrouillé ? Retry du même handover → double événement / double carte (idempotence) ?
8. Journal écrit **avant** ou **après** la mutation (cohérence en cas d'échec partiel) ?

## 3. C3 — Erreur réseau / timeout — **NON ÉVALUABLE (bloqué)**

**INCONNU** si le handover est purement local (édition d'un fichier d'état) ou implique un appel distant. Deux scénarios à départager dans le code :
- **Local** : la vraie question est l'erreur IO/interruption — écriture atomique (fichier temporaire + `os.replace`) ?
- **Distant** : timeout → état intermédiaire visible ? Retry idempotent (clé `alias + timestamp`) ? Pas d'effet partiel observable ?

## 4. Verdict consolidé

| Critère | Verdict | Motif |
|---|---|---|
| C1 — regex | **PARTIEL** | Couverture fonctionnelle confirmée sur le pattern cité ; 2 findings à trancher (F1-01 call-site, F1-02 unicité canonique) + dépendances non observées. |
| C2 — `reassign` | **NON ÉVALUABLE** | Code non fourni. |
| C3 — réseau/timeout | **NON ÉVALUABLE** | Code non fourni. |
| C4 — verdict global | **PARTIEL / NE PAS SCHELLER** | AC-F1.7 ne peut pas être certifié conforme ; l'audit regex est fait, l'audit service est en attente de matériaux. |

**Décision recommandée** : ne pas clore AC-F1.7 en PASS. Fournir au coordinateur : (a) la fonction `reassign` complète de `supervisor_service.py` avec le call-site du regex (`re.match` vs `re.fullmatch`), (b) la gestion IO/atomicité de l'écriture d'état, (c) la liste des noms de tests des 42 pour vérifier la couverture de la matrice ci-dessous.

## 5. Matrice de tests recommandée (extension de `test_connect_session.py`)

| # | Alias | Résultat actuel attendu (analyse) | À trancher |
|---|---|---|---|
| 1 | `T429-CC01 Session A` | accepté | — |
| 2 | `T428-1-AGY01 Session B` | accepté | — |
| 3 | `T429-CC01` (sans label) / `T429-CC01␣` | rejeté | — |
| 4 | `t429-cc01 Session` | rejeté (casse) | intent confirmé par test |
| 5 | `T429-CC01 X\n` | match via `re.match`, rejet via `fullmatch` | **F1-01** |
| 6 | `T429-CC01␣␣` | match (label = espaces) | **F1-09** |
| 7 | `T429-CC01␣␣X␣␣Y` | match (espaces internes) | normalisation F1-02 |
| 8 | `T0429-CC01 X` / `T0-CC01 X` | match | **F1-06** |
| 9 | `T429-CDS01 X` / `T429--CC01 X` | rejeté | — |
| 10 | `T429-AGY100 X` / `T429-CC1 X` | rejeté (n° agent) | F1-05 documenté |
| 11 | `T429-CC01-CC01 A` | match | **F1-07** |
| 12 | `T429-CC01 T-430-AGY01 X` | match (label contient un faux alias) | dédup par égalité exacte uniquement |

## 6. Recommandations prioritaires

1. **P1 — Unicité canonique** (F1-02) : couche de normalisation (strip, collapse `\s+`→1 espace, NFKC, UPPER) *avant* validation, clé de dédup sur la forme normalisée ; ou regex plus contraignante (label ` \S.*\Z`, un seul espace).
2. **P1 — Matcher** (F1-01) : utiliser `re.fullmatch` + `\Z` plutôt que `^…$`.
3. **P2 — Source de vérité** (F1-04) : pattern généré depuis une constante partagée `("CC","AGY","CDX","DSH","OPC")` + test paramétré.
4. **P2** : trancher F1-06 (zéros initiaux) : `T(?:[1-9]\d*)` si le format est strict.
5. **P3** : compléter la matrice §5 dans les tests et documenter F1-05/F1-07 comme limites assumées.

—
*Reviewer : GLM 5.3 (challenge B), lecture seule, aucune modification de périmètre effectuée. Restitution au responsable : AGY01 (Orchestrateur Antigravity).*