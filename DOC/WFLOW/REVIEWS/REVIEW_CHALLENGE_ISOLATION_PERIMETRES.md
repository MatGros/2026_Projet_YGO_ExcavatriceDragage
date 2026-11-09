# Verdict exécutif

**En l’état, le parallélisme B2 / B3 / C1 / C2 est refusé.** Ces quatre lots écrivent dans `scripts/supervisor_service.py`, et B2 écrit aussi dans `scripts/supervisor_server.py`. Git ne détecte que les conflits textuels : il ne protège ni les écrasements sémantiques, ni les régressions d’état en mémoire, ni les tests qui se marchent dessus.

**Stratégie recommandée :** contrat d’interface d’abord, puis extraction de *seams* minimaux dans des modules neufs, puis seulement parallélisation sur des fichiers disjoints. Ne pas scinder tout le monolithe de 2 100 lignes d’un coup.

**Décision structurante :** fusionner B3 et C2 en un seul lot « Contexte & Mission State », ou les sérialiser strictement. Ils touchent la même politique de dimensionnement et le même point d’entrée du juge.

> Limite de cette revue : je n’ai pas exécuté de commande d’audit dans cette session. Le tableau ci-dessous conclut à partir des chemins fournis. Les usages exacts du port 8082, de `%TEMP%/supervision-backups` et des fichiers de tests partagés restent à confirmer par `grep` avant verrouillage.

---

## 1. Audit des collisions

| Lot | Fichiers annoncés | Collision | Sévérité | Conclusion |
|---|---|---|---|---|
| **B1** | `ui/index.html`, `tests/test_ui.mjs`, `tests/ui_layout_check.mjs` | Aucune écriture backend. Dépend du contrat B2. Risque test port/temp. | Moyenne | Isolable dès que le contrat est gelé. |
| **B2** | `scripts/supervisor_server.py`, `scripts/supervisor_service.py`, tests API | `supervisor_service.py` avec B3/C1/C2 ; `supervisor_server.py` unique mais partagé avec l’intégration. | **Critique** | Ne pas paralléliser tel quel. |
| **B3** | `scripts/supervisor_service.py`, `tests/test_recovery.py` | `supervisor_service.py` avec B2/C1/C2 ; couplage fort avec C2. | **Critique** | À fusionner avec C2 ou sérialiser. |
| **C1** | `scripts/supervisor_service.py`, tests associés | `supervisor_service.py` avec B2/B3/C2 ; tests juge possiblement partagés avec C2. | **Critique** | Seam `judge_prompt.py` obligatoire. |
| **C2** | `scripts/supervisor_service.py`, tests Mission State | `supervisor_service.py` avec B2/B3/C1 ; logique contexte avec B3. | **Critique** | À fusionner avec B3. |
| **Tous** | Port 8082, `%TEMP%/supervision-backups`, serveurs de test | Collision d’exécution et de répertoires. | Élevée | Ports dynamiques, `tmp_path`, identifiants uniques. |

**Point Git important :** deux worktrees ne peuvent pas checkout la même branche simultanément. La branche cible `work/carte-flux-troubleshooting` doit rester la branche d’intégration, pas le checkout de travail des deux agents.

---

## 2. Stratégie d’isolation absolue

### 2.1 Principe

**Zéro conflit = zéro écriture concurrente sur un même fichier.** Ce n’est pas un problème de résolution de merge ; c’est un problème d’ownership et de séquencement.

### 2.2 Contrat d’interface d’abord

Avant B1 et B2, geler un contrat JSON versionné :

- `GET /api/collector/trace`
- `GET /api/judge/telemetry`

Contenu minimal du contrat :

```json
{
  "schema_version": "1.0",
  "generated_at": "ISO-8601",
  "trace_id": "string|null",
  "events": [
    {
      "ts": "ISO-8601",
      "level": "debug|info|warn|error",
      "component": "string",
      "event": "string",
      "message": "string",
      "data": {}
    }
  ],
  "next_cursor": "string|null"
}
```

Pour la télémétrie juge :

```json
{
  "schema_version": "1.0",
  "generated_at": "ISO-8601",
  "window": {
    "from": "ISO-8601",
    "to": "ISO-8601",
    "duration_s": 900
  },
  "judge": {
    "calls": 0,
    "errors": 0,
    "latency_ms": {"p50": 0, "p95": 0, "max": 0},
    "tokens": {"prompt": 0, "completion": 0},
    "decisions": {"allow": 0, "deny": 0, "review": 0}
  },
  "missions": []
}
```

Règles :

- `schema_version` obligatoire.
- Erreurs : code HTTP + enveloppe `{schema_version, error:{code,message,details}}`.
- Interdiction d’exposer chemins absolus, secrets, prompts complets ou données personnelles.
- Compatibilité additive uniquement en v1 ; tout retrait/renommage = v2.
- B1 code contre les fixtures du contrat, pas contre des mocks improvisés.
- B2 doit passer les tests de contrat avant que B1 soit intégré.
- Le contrat est gelé par hash ; toute modification après gel exige l’accord du coordinateur, de B1 et de B2.

### 2.3 Refactor par seams, pas big-bang

Ne pas découper les 2 100 lignes en une seule opération. Extraire uniquement les points de couture nécessaires, avec comportement inchangé :

| Seam | Module neuf | Rôle | Lot qui le remplit ensuite |
|---|---|---|---|
| Prompt juge | `scripts/judge_prompt.py` | Contient `OMNI_JUDGE_SYSTEM` et la construction de prompt. | C1 |
| Budget contexte | `scripts/context_budget.py` | Contient le seuil 6 000 et la politique de dimensionnement. | B3 |
| Mission State | `scripts/mission_state.py` | Construit le packet, puis reçoit le pré-filtrage déterministe. | C2 |
| Télémétrie | `scripts/collector_telemetry.py` | Fonctions `read_trace()` / `read_judge_telemetry()`. | B2 |
| Routes télémétrie | `scripts/supervisor_routes_telemetry.py` | `register_telemetry_routes(app)`. | B2 |

Après ces seams, `supervisor_service.py` et `supervisor_server.py` deviennent des **composition roots** en lecture seule pour les lots. Toute nouvelle couture passe par le coordinateur, pas par un lot feature.

Interfaces internes à figer :

```python
# collector_telemetry.py
def read_trace(limit: int, cursor: str | None) -> dict: ...
def read_judge_telemetry(window_s: int) -> dict: ...

# judge_prompt.py
def get_system_prompt() -> str: ...

# context_budget.py
def max_context_chars(config: dict) -> int: ...

# mission_state.py
def build_packet(mission: dict, max_chars: int) -> dict: ...
```

### 2.4 Git : même branche cible, checkouts séparés

Recommandation :

```bash
git worktree add ../as-b1 -b lot/B1-ui work/carte-flux-troubleshooting
git worktree add ../as-b2 -b lot/B2-telemetry work/carte-flux-troubleshooting
git worktree add ../as-b3c2 -b lot/B3C2-context work/carte-flux-troubleshooting
git worktree add ../as-c1 -b lot/C1-prompt work/carte-flux-troubleshooting
```

Le coordinateur intègre ensuite sur la branche cible, **après accord humain explicite**, lot par lot. Pas de push. Pas de merge automatique. Pas de résolution de conflit par `ours`/`theirs`.

Si la contrainte impose littéralement un seul checkout partagé : **un seul écrivain à la fois**, et parallélisme interdit sur `supervisor_service.py` / `supervisor_server.py`. Dans ce cas, la stratégie zéro-conflit est la sérialisation complète.

### 2.5 Tests : ports, temp, état

- Remplacer le port fixe 8082 par `SUPERVISOR_PORT=0` ou un allocateur de port libre.
- Chaque test utilise `tmp_path` / `tempfile.mkdtemp(prefix="supervisor-B2-")`.
- Remplacer `%TEMP%/supervision-backups` par `SUPERVISOR_BACKUP_DIR` unique par run.
- IDs de mission préfixés par lot + UUID.
- Ne tuer que son propre PID ; jamais de `taskkill` large.
- Tests unitaires sans vrai serveur ; tests d’intégration marqués et sérialisés.
- Si le code ne permet pas encore ces variables : le seam de configuration est un prérequis. Sinon, sérialiser les tests d’intégration.

---

## 3. Règles d’or opérationnelles

1. **Un agent = un worktree = une branche courte.**
2. **Un fichier = un seul écrivain à la fois.** Lecture partagée autorisée ; écriture non.
3. **Contrat gelé avant tout code UI/API.**
4. **Après seams, `supervisor_service.py` et `supervisor_server.py` sont interdits aux lots feature.**
5. **B3 et C2 ne sont pas parallèles** : fusion ou séquence stricte.
6. **Tests isolés** : port dynamique, temp unique, IDs uniques.
7. **Aucune suppression, déplacement ou nettoyage automatique.**
8. **Aucun commit/push sans accord humain explicite.**
9. **Intégration sérialisée par le coordinateur.** Conflit = stop, pas de résolution aveugle.
10. **Handoff obligatoire** : fichiers modifiés, commandes exécutées, résultats, risques, hash du contrat.

---

## 4. Matrice d’affectation et ordre strict

| Ordre | Phase / lot | Propriétaire | Écriture exclusive | Dépend de | Sortie attendue |
|---|---|---|---|---|---|
| 0 | Baseline + verrou | Coordinateur | Note de coordination autorisée | Humain | Base commit, tests baseline, matrice verrouillée |
| 1 | Contrat télémétrie v1 | B2 rédige, B1 review, Coordinateur gèle | `docs/contracts/telemetry_v1.*`, fixtures contrat | 0 | Contrat gelé + tests de schéma |
| 2 | Seam prompt | Coordinateur | `scripts/judge_prompt.py`, `scripts/supervisor_service.py`, test de seam | 0 | Ancienne suite PASS, import stable |
| 3 | Seam contexte / Mission State | Coordinateur | `scripts/context_budget.py`, `scripts/mission_state.py`, `scripts/supervisor_service.py`, tests seam | 2 | Ancienne suite PASS |
| 4 | Seam télémétrie | Coordinateur | `scripts/collector_telemetry.py`, `scripts/supervisor_routes_telemetry.py`, `scripts/supervisor_server.py`, `scripts/supervisor_service.py`, tests seam | 3 | Routes chargées, contrat vide/501 explicite, suite PASS |
| 5 | B2 Télémétrie API | Agent A | `scripts/collector_telemetry.py`, `scripts/supervisor_routes_telemetry.py`, `tests/test_collector_trace_api.py`, `tests/test_judge_telemetry_api.py` | 1, 4 | Tests contrat + API PASS |
| 6 | B1 IHM | Agent B | `ui/index.html`, `ui/telemetry_client.js`, `tests/test_ui.mjs`, `tests/ui_layout_check.mjs`, `tests/fixtures/ui/*` | 1 | Tests UI sur fixtures PASS |
| 7 | B3 + C2 Contexte | Agent B | `scripts/context_budget.py`, `scripts/mission_state.py`, `tests/test_recovery.py`, `tests/test_context_budget.py`, `tests/test_mission_state.py` | 3 | Tests contexte/recovery PASS |
| 8 | C1 Prompt | Agent A | `scripts/judge_prompt.py`, `tests/test_judge_prompt.py`, `tests/test_alarm_matrix.py` | 2 | Tests prompt/matrice PASS |
| 9 | Intégration | Coordinateur | Branche cible uniquement | 5, 6, 7, 8 | Full suite PASS + diff review + accord humain |

**Fenêtres de parallélisme autorisées :**

- B1 peut démarrer **dès la phase 1**, en parallèle des seams, car ses fichiers sont disjoints.
- Après les seams : Agent A fait B2 puis C1 ; Agent B fait B3+C2 après B1.
- Si un seul agent d’exécution est disponible, tout est séquentiel ; l’isolation reste correcte.

**Ordre d’intégration recommandé :** B2 → B1 → B3+C2 → C1. B2 fournit le contrat réel, B1 le consomme, puis les lots contexte et prompt.

---

## 5. Critères d’acceptation

- `git diff --name-only` de chaque lot ne contient que ses chemins exclusifs.
- Aucun lot feature n’a modifié `supervisor_service.py` ou `supervisor_server.py` après les seams.
- Les tests de contrat échouent si un champ requis manque ou change de type.
- B2 passe avec port dynamique et backup dir temporaire.
- B1 passe sur fixtures gelées, puis un test d’intégration passe contre B2 réel.
- B3+C2 prouvent : seuil paramétrable, pré-filtrage déterministe, cas limites, absence de dépendance à l’horloge/random.
- C1 passe la matrice de prompts sans modifier le service.
- Full suite sur branche d’intégration après merge sérialisé.
- Aucun commit/push sans validation humaine.

---

## 6. Risques résiduels

1. **Le seam refactor lui-même peut régresser.** Mitigation : PR de comportement inchangé, ancienne suite PASS avant features.
2. **Tests partagés non identifiés.** À vérifier par `grep` avant verrouillage ; au moindre doute, créer un nouveau fichier de test plutôt que modifier un fichier commun.
3. **Import circulaire / état global Python.** Les modules neufs doivent recevoir leurs dépendances, pas importer le service.
4. **Contrat qui dérive.** Hash gelé + tests de schéma + review B1/B2.
5. **Contrainte « même branche » interprétée littéralement.** Elle rend le parallélisme impossible sur les fichiers chauds ; il faut l’expliciter avec l’humain.

**Décision recommandée :** Go conditionnel pour le parallélisme uniquement après contrat gelé + seams réalisés + B3/C2 fusionnés. Sinon, sérialiser tous les lots touchant `supervisor_service.py`.