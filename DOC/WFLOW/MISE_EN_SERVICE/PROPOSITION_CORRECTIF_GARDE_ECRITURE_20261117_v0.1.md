# Proposition de correctif — garde d'écriture `task_scope.py` : faux positifs sur les noms commençant par `code`

> **PROPOSITION, non appliquée.** `TOOLS/AGENT_WORKFLOW/scripts/task_scope.py` est lui-même dans la deny-list d'écriture des agents : seul l'exploitant (ou la tâche C4 désignée) peut l'appliquer. Rédigée par TORC-CC10 le 2026-11-17 après audit dialectique A / B / C.

## 1. Défaut constaté
`_matches_anywhere` (`task_scope.py:223-250`) teste `"/" + motif in chemin` : une **sous-chaîne**. Tout chemin contenant `/code…` est refusé comme s'il s'agissait de `CODE/`.
- Refusés à tort : `TOOLS/PLC_CSV_SNAPSHOT/codesys_console/x.py`, `…/codesys_snapshot_persistent.py`, `…/codex_notes.md`, `DOC/AF/code_review/x.md`.
- Acceptés : `variable_lists/snapshot_persistent.py`, `note_codebook.md`, `README.md`.

## 2. Audit dialectique (agents Ollama + vérification à la source par TORC-CC10)
- **A** (`glm-5.3-flash:cloud`, innovation) : comparer des **composants de chemin** entiers. Son correctif et ses 26 cas : 25 conformes à son attente ; le 26ᵉ (`CODE/../DOC/x.md`) était mal attendu : `matches()` le refuse avant `_matches_anywhere` (refus sûr, déjà présent).
- **B** (`deepseek-v4.1-flash:cloud`, red team) : la comparaison par composants **exacts** perd des refus utiles sur les alias Windows (`CODE.`, `CODE `, `CODE_X~1`, flux `settings.json::$DATA`).
- **Vérification (exécution en mémoire, `task_scope.py` non modifié)** : sur 10 alias **imbriqués**, le correctif d'A introduit **9 régressions de sécurité** (refusé avant, accepté après). B avait raison sur le fond. Sur les alias en **premier composant** (`CODE./x.st`, `CODE~1/x.st`, `CODE::$DATA/x.st`), l'ancien code les **acceptait déjà** : lacune préexistante, pas une régression.
- **C** (arbitrage) : composants entiers **après canonisation** : minuscules, suffixe de flux (`:…`) et points/espaces finaux retirés, alias 8.3 (`~N`) refusés par préfixe du motif protégé.

## 3. Candidat retenu (testé en mémoire : 44 cas, 0 échec, 0 régression de sécurité)

```python
def _canon(component):
    """Composant -> forme canonique Windows : minuscules, flux ADS (':...') et points/espaces finaux retires."""
    c = component.lower().split(":")[0]
    return c.rstrip(". ")


def _matches_anywhere(relative, prefixes):
    """Motif present comme SUITE DE COMPOSANTS entiers, canonises, quel que soit le racine.
    Un chemin ABSOLU hors depot (C:/autre/CODE/x.st) tombe dans la meme deny-list qu'un chemin relatif.
    Remplace l'ancienne sous-chaine ('marker in lowered'), cause des faux positifs
    ('/codesys_console', '/codex_notes', '/code_review')."""
    import fnmatch
    parts = []
    for raw in str(relative or "").replace("\\", "/").split("/"):
        if raw in ("", "."):
            continue
        if raw == "..":
            if parts and parts[-1] != "..":
                parts.pop()
            else:
                parts.append("..")
            continue
        parts.append(raw)
    for prefix in prefixes:
        clean = str(prefix).replace("\\", "/").rstrip("/")
        if not clean:
            continue
        base = clean[:-3] if clean.endswith("/**") else clean
        pattern = [p.lower() for p in base.split("/") if p]
        size = len(pattern)
        for start in range(len(parts) - size + 1):
            ok = True
            for offset, piece in enumerate(pattern):
                comp = parts[start + offset]
                canon = _canon(comp)
                alias83 = ("~" in comp and piece.startswith(comp.lower().split("~")[0])
                           and len(comp.split("~")[0]) >= 2)
                if "*" in piece:
                    if not fnmatch.fnmatchcase(canon, piece):
                        ok = False
                        break
                elif not (canon == piece or alias83):
                    ok = False
                    break
            if ok:
                return True
    return False
```

## 4. Matrice de tests (44 cas ; `True` = doit être REFUSÉ)
- **Protégés voulus :** `CODE/GVL_PERSISTENT.st`, `PRJ_CODESYS/x.py`, `.claude/settings.json`, `C:/autre/CODE/x.st`, `c:\autre\code_xml\a.xml`, `D:\autre\Code_Xml\a.xml`, `C:/Autre/Code/GVL_PERSISTENT.st`, `C:/autre/TOOLS/AGENT_WORKFLOW/scripts/task_scope.py`, `//srv/share/CODE/x.st`, `./CODE/x.st`, `a/../CODE/x.st`, `a/b/CODE/x.st`, `Tools/code/gvl_persistent.st`.
- **Faux positifs à lever (doivent passer) :** `TOOLS/PLC_CSV_SNAPSHOT/codesys_console/x.py`, `…/20261117_OUTILS/codesys_snapshot_persistent.py`, `…/codex_notes.md`, `DOC/AF/code_review/x.md`, `CODE_BACKUP/x.md`, `CODE.txt`, `MYCODE/x`, `C:/autre/CODES/x.st`, `.claude/settings.json.bak`, `DOC/x/CODE_BACKUP/a.md`, `DOC/x/CODEBOOK~1/a.md`.
- **Attaques d'alias Windows (doivent être refusées) :** `CODE./x.st`, `CODE /x.st`, `CODE.../x.st`, `CODE~1/x.st`, `CODE_X~1/a.xml`, `PRJ_CO~1/x.py`, `CODE::$DATA/x.st`, `.claude/settings.json::$DATA`, `.claude/settings.json:stream`, `.claude/settings.json.`, `DOC/x/CODE./a.st`, `DOC/x/CODE_XML./a.xml`, `C:/autre/CODE./x.st`.

## 5. Limites et suite
- **Non couverts** (comme avant) : jonctions/liens vers un dossier protégé, noms 8.3 à préfixe court ambigu. Le correctif suit la règle sûre : un alias 8.3 est refusé si son début est un préfixe du motif protégé (un faux refus rare vaut mieux qu'un contournement).
- **Pas appliqué.** Pour l'appliquer : remplacer `_matches_anywhere` dans `task_scope.py` par le code ci-dessus, ajouter `_canon`, créer un test dans `TOOLS/AGENT_WORKFLOW/tests/` avec la matrice du §4, lancer le test et `run_all_gates.py --palier C`, **relire le diff** avant de commiter.
- À traiter par l'exploitant ou dans la sous-tâche transmise à l'orchestrateur (règle `fix:` + `guard:`).
- Relire aussi `hook_shell_scope_guard.py` : il applique probablement la même fonction aux commandes shell (non vérifié ici).
