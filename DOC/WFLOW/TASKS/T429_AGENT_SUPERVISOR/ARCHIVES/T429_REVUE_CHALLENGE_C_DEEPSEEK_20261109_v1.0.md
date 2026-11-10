## Constat immédiat — blocage d'exécution

Je ne dispose d'**aucun accès fichier ni outil d'exécution** dans cette session : je ne peux ni lire `TOOLS/AGENT_SUPERVISOR/`, ni ouvrir le contrat `TASK_CONTRACT_T429_...yaml`, ni exécuter `check_task_contract.py`, ni lancer pytest, ni inspecter `%LOCALAPPDATA%/ExcavatriceDragage/supervision-backups/`. Aucun contenu de fichier ne m'a été fourni dans le brief non plus (seulement des chemins).

Or les règles du brief et `AGENTS.md` § Discipline de session sont explicites : **on n'annonce pas PASS sur une vérification indirecte ou non exécutée**. Je ne vais donc pas fabriquer de verdict à partir de la description de la mission — la description *affirme* des résultats (133 tests OK, sessions intactes), elle ne les *prouve* pas.

**Verdict : NON EXÉCUTÉ** (ni PASS, ni FAIL, ni même PARTIEL revendiqué). Le PASS/PARTIEL revient à l'exécutant outillé qui produira les preuves ci-dessous ; je fournis le plan de vérification falsifiable.

---

## Plan de vérification falsifiable (à exécuter par un agent avec accès disque/shell)

### Critère 1 — Immuabilité des sessions en pause (AC-X.1)

- Localiser le store d'état (probablement un JSON sous `%LOCALAPPDATA%/ExcavatriceDragage/`, à confirmer dans `supervisor_server.py`).
- **Preuve attendue** : pour `d4f1bcd5…` → `status == paused` **et** exactement **6 alertes** ; pour `4819768b…` → `status == paused` **et** **0 alerte**.
- **Test de non-mutation** : snapshot hash (SHA-256) du store avant/après un cycle superviseur nominal → hash identique pour ces deux sessions.
- **Audit code** : grep dans `TOOLS/AGENT_SUPERVISOR/` de tout `write`/`update`/`save` sur l'état session ; vérifier la présence d'un garde `if status != paused` (ou équivalent) sur chaque chemin d'écriture. Absence de garde = risque de dérive silencieuse → FAIL sur AC-X.1.
- **Ce qui invaliderait** : un chemin de code qui réécrit `status`, `alerts` ou le compteur d'alertes d'une session en pause sans garde explicite.

### Critère 2 — Sauvegarde / restauration (AC-X.2)

- **`upgrade_legacy.py`** : vérifier que la migration est *read-modify-write* atomique, qu'elle ne « réveille » pas une session en pause, et qu'elle préserve le compteur d'alertes (6 / 0). Chercher tout `default status=active` ou reset d'alertes.
- **`supervisor_server.py`** : vérifier qu'aucune écriture de session n'est déclenchée par un simple GET / heartbeat / reload.
- **Preuve de restauration** : restaurer une sauvegarde dans un répertoire isolé (jamais sur les données réelles — cf. règle « aucun essai sur machine réelle sans autorisation ») et comparer bit-à-bit / sémantiquement le résultat à l'état source.
- **Ce qui invaliderait** : migration qui change `paused`→`active`, perte d'alertes, ou restauration non idempotente.

### Critère 3 — Conformité du contrat

- `python check_task_contract.py DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T429_AGENT_SUPERVISOR_FIABILISATION.yaml` (adapter le nom d'argument réel) → **code de sortie attendu 0**. Preuve = sortie brute de la commande, pas une paraphrase.

### Critère 4 — Pytest et absence d'effet de bord sur TASKS.yaml

- Hash SHA-256 de `TASKS.yaml` **avant** et **après** la suite pytest complète → identiques. 133 tests OK **ne suffit pas** : il faut la preuve que le test run n'écrit pas dans le Task Manager partagé (les tests doivent utiliser un fixture/tempdir).
- Vérifier aussi absence de fichiers orphelins créés dans `TASKS.yaml` ou le registre d'orchestration.

---

## Ce qu'il me faut pour rendre un vrai verdict

1. La sortie brute de `check_task_contract.py` (stdout+exit code).
2. Le log pytest complet (133 passed) + les deux hashes de `TASKS.yaml`.
3. Les extraits pertinents de `upgrade_legacy.py` et `supervisor_server.py` (chemins de code touchant l'état session).
4. L'état sérialisé des deux sessions (ou son hash avant/après cycle).

Avec ces éléments je peux émettre PASS/FAIL/PARTIEL motivé par critère. Sans eux, je reste sur **NON EXÉCUTÉ** — c'est la seule position honnête et conforme à la discipline de session. Merci à l'orchestrateur AGY01 de router ces preuves ou de m'accorder un accès en lecture au périmètre.