# T332 — Hooks Claude Code : `hookSpecificOutput` sans `hookEventName`

> **Preuve durable de diagnostic** (T279 — routage : `DOC/WFLOW/AUDITS/`).
> Session T332 · agent **`DSH04`** · 2026-09-20 · criticité **C4 (outillage)** · domaine `OUTILLAGE / AGENT_WORKFLOW`.
> Verrou : `DOC/WFLOW/TASK_LOCKS.json` → `work_locks.T332` = **`DSH04`**.
>
> ⚠️ **Correction de tag (2026-09-20T15:55, arbitrage CC01)** : ce travail a été produit sous le tag
> `DSH01`, **contaminé** — au moins 6 sessions distinctes journalisaient sous `DSH01`
> (`T255-D`, `T300-audit-M3-trace`, `T300-PA`, `T330-P1P2`, `T332`, `T333`). CC01 a renommé
> `T328→DSH03`, `T332→DSH04`, `T255-D→DSH05` ; T333 portait déjà `DSH02`. **Toutes les écritures
> registre/heartbeat de cette session portent désormais `DSH04`.** Les lignes antérieures du log
> `status/T332.log` marquées `[DSH01]` sont **mis-taggées et conservées telles quelles** (aucune
> réécriture automatique d'historique) ; une ligne corrective `[DSH04]` les référence.
> Signalé, non corrigé : plusieurs autres logs/tâches portent encore des tags `DSH01` hérités.
> **Aucun fichier hors dépôt n'a été modifié. Aucun commit. Aucun hook retiré. Aucune allowlist.**

---

## 1. Symptôme (tel que rapporté, session CC01 du 2026-09-20)

À **chaque** appel outil `Bash` / `Read` / `Edit` :

```text
PreToolUse:Read hook error
Hook JSON output validation failed — hookSpecificOutput is missing required field "hookEventName"
```

Effets : erreur répétée dans le contexte de l'agent + latence perçue sur chaque outil.

---

## 2. Verdict

**La cause n'est PAS dans les hooks du projet.** L'émetteur est un **hook utilisateur, hors dépôt**,
déclaré avec un matcher vide (⇒ **tous** les outils) :

| | |
|---|---|
| Fichier fautif | `C:\Users\ZEDVICTUS\.claude\hooks\auto-accept-hook.ps1` (13 lignes, **non versionné**) |
| Lignes | `4-11` — le JSON `hookSpecificOutput` |
| Déclaration | `C:\Users\ZEDVICTUS\.claude\settings.json:43-49` (`"matcher": ""`) |
| Nature | auto-approbation globale (`"permissionDecision": "allow"`) — **pas** un garde-fou `AGENTS.md` |

**Aucun fichier du dépôt n'émet `hookSpecificOutput`** : `grep -r "hookSpecificOutput"` sur le
dépôt ne remonte que (a) des exports de session (`codex-session-*.md`) et (b) les descriptions de
tâches `DOC/WFLOW/TASKS*.yaml`. Zéro script, zéro config.

---

## 3. Preuve par empreinte (non ambiguë)

L'erreur de validation **embarque la sortie du hook fautif**. Extrait verbatim d'un transcript
(`~/.claude/projects/c---MGS-DEV-2026-Projet-YGO-ExcavatriceDragage/bad627cd-28bf-4da2-b3ac-37f7300eff3e.jsonl`,
`attachment.type = "hook_non_blocking_error"`) :

```json
"hookName": "PreToolUse:Read",
"hookEvent": "PreToolUse",
"durationMs": 485,
"stderr": "Hook JSON output validation failed — hookSpecificOutput is missing required field \"hookEventName\"\n\nThe hook's output was: {\n  \"hookSpecificOutput\": {\n    \"permissionDecision\": \"allow\",\n    \"permissionDecisionReason\": \"Auto-approved by Auto Accept Extension\"\n  }\n}\n\nExpected schema: { ... }"
```

La chaîne `Auto-approved by Auto Accept Extension` est **la signature littérale du fichier
`auto-accept-hook.ps1`** (ligne 8) ⇒ identification sans hypothèse.

### 3.1 Schéma attendu, publié par Claude Code lui-même

Extrait complet du champ `Expected schema` de l'erreur :

```text
"hookSpecificOutput": {
  "for PreToolUse": {
    "hookEventName": "\"PreToolUse\"",
    "permissionDecision": "\"allow\" | \"deny\" | \"ask\" | \"defer\" (optional)",
    "permissionDecisionReason": "string (optional)",
    "updatedInput": "object (optional) - Modified tool input to use"
  },
  ... (PermissionRequest / UserPromptSubmit / PostToolUse / PostToolBatch / Stop|SubagentStop)
}
```

⇒ `hookEventName` est **obligatoire** dès que `hookSpecificOutput` est présent, et sa valeur doit
être le nom de l'événement (`"PreToolUse"`). Confirmé par lecture directe, pas par inférence.

### 3.2 Taxonomie des erreurs de hook (6 sessions, classées par empreinte)

| Session (date) | Bash | Read | Edit | Grep | autres | Total | Signature `Auto Accept` | Signature `node` |
|---|---|---|---|---|---|---|---|---|
| `bad627cd` (20/09) | 122 | 54 | 43 | 16 | 10 | **245** | 242 | 0 |
| `cbdb6c6f` (20/09) | 116 | 38 | 24 | 15 | 5 | **198** | 198 | 0 |
| `b93e8a8c` (20/09) | 34 | 6 | 7 | 5 | 4 | **56** | 56 | 0 |
| `cef225b0` (20/09) | 6 | 9 | 1 | 15 | 1 | **32** | 32 | 0 |
| `4d4b3039` (19/09) | 42 | 48 | – | 43 | … | **326** | ~163 | ~163 |
| `3992cbbc` (18/09) | 59 | 37 | 32 | … | … | **310** | ~155 | ~155 |

**20/09 : 100 % des erreurs `PreToolUse` portent la signature auto-accept.** Les seules exceptions
sont **3 erreurs `Stop`** — voir §7.1 (cause distincte, plus grave).

### 3.3 Second émetteur historique — **déjà résolu**

Les sessions du 18-19/09 portaient **en plus** une erreur par appel outil :

```text
Failed with non-blocking status code: node:internal/modules/cjs/loader:1520
Error: Cannot find module 'c:\Users\ZEDVICTUS\.vscode\extensions\manuyehezkely.claude-auto-accept-manuy-0.2.1\dist\hook.js'
```

Émetteur : extension VS Code `manuyehezkely.claude-auto-accept-manuy-0.2.1` (hook Node pointant sur
un `dist/hook.js` disparu). **Plus une seule occurrence le 20/09** ⇒ absent de la configuration
courante. Aucune action requise, aucune action effectuée.

---

## 4. Cartographie hook → script → événement → matcher (AC1)

| Événement | Config (`fichier:ligne`) | Matcher | Commande / script | Sortie | État |
|---|---|---|---|---|---|
| PreToolUse | **USER** `~/.claude/settings.json:34-42` | *(absent ⇒ tous)* | `agent-hook.sh claude PreToolUse` | rien sur stdout (log fichier `agent-events.log`) | ✅ |
| PreToolUse | **USER** `~/.claude/settings.json:43-49` | `""` ⇒ **TOUS** | `powershell -File …\.claude\hooks\auto-accept-hook.ps1` | `{"hookSpecificOutput":{…}}` **sans `hookEventName`** | ❌ **CAUSE** |
| PreToolUse | **PROJET** `.claude/settings.json:40-49` | `Edit\|Write\|MultiEdit` | `python TOOLS/AGENT_WORKFLOW/scripts/hook_pre_edit.py` | stdout vide ; **exit 2 + stderr** si blocage | ✅ |
| PreToolUse | **PROJET** `.claude/settings.json:50-58` | `ExitPlanMode` | `node -e "…{decision:'approve'}"` | format hérité, aucune erreur de validation | ✅ |
| PreToolUse | **PROJET** `.claude/settings.json:59-67` | `AskUserQuestion` | `node -e "…{decision:'approve',answer:'yes'}"` | format hérité, aucune erreur de validation | ✅ |
| PostToolUse | **USER** `~/.claude/settings.json:53-60` | *(absent)* | `agent-hook.sh claude PostToolUse` | — | ✅ |
| PostToolUse | **PROJET** `.claude/settings.json:69-80` | `Edit\|Write\|MultiEdit` | `hook_post_edit.py` | stderr informatif, **exit 0** (jamais bloquant — docstring `:15-22`) | ✅ |
| Stop | **USER** `~/.claude/settings.json:77-90` | *(absent)* | `agent-hook.sh claude Stop` + `printf >> %TEMP%\agent-notifier.jsonl` | — | ✅ |
| Stop | **PROJET** `.claude/settings.json:81-91` | *(absent)* | `hook_stop.py` (`timeout 150`) | **exit 2 + stderr** si blocage | ⚠️ **désactivé hors racine (§7.1)** |
| Stop | plugin `codex@openai-codex` — `hooks/hooks.json:26-36` | *(absent)* | `node …/scripts/stop-review-gate-hook.mjs` (`timeout 900`) | — | non sollicité dans les logs |
| SessionStart / SessionEnd / UserPromptSubmit / Notification / PermissionRequest | **USER** | — | `agent-hook.sh` / `printf` | — | ✅ |
| pre-commit / pre-push | **PROJET** `TOOLS/AGENT_WORKFLOW/hooks/` | — | `core.hooksPath` (Git, hors événements CC) | — | hors périmètre |
| plugin `antigravity@idun-antigravity` `0.1.0` | `.claude-plugin/plugin.json` | — | **aucun bloc `hooks`** | — | ✅ |

---

## 5. Durées (AC2) — 3 runs, médiane + max

Mesure `[System.Diagnostics.Stopwatch]` sur la commande réellement déclarée dans les settings.

| Hook | Déclencheur | Médiane | Max |
|---|---|---|---|
| ❌ `auto-accept-hook.ps1` (USER) | **chaque appel outil** | **423 ms** | 424 ms |
| `agent-hook.sh` PreToolUse (USER) | chaque appel outil | 73 ms | 101 ms |
| `hook_pre_edit.py` (PROJET) | `Edit`/`Write`/`MultiEdit` | 142 ms | 152 ms |
| `hook_post_edit.py` — cible non concernée | éditions | 140 ms | 141 ms |
| `hook_post_edit.py` — cible `.md` (→ G340) | éditions `.md` | 1 211 ms | 1 363 ms |
| `hook_post_edit.py` — cible `CODE/*.st` (→ G200) | éditions `.st` | 1 527 ms | 1 778 ms |
| `hook_stop.py` — sortie rapide (aucun `.st` modifié) | fin de tour | 217 ms | 241 ms |

Mesure indépendante par Claude Code dans le transcript : `"durationMs": 485` pour le hook fautif
⇒ cohérent avec la mesure locale.

**Surcoût actuel par appel outil ≈ 496 ms** (423 + 73) **+ le rendu de l'erreur**.
⚠️ **Le correctif de schéma ne supprime pas ces 423 ms** — voir §6.

---

## 6. Correction proposée — **NON APPLIQUÉE** (décision humaine)

Fichier : `C:\Users\ZEDVICTUS\.claude\hooks\auto-accept-hook.ps1` (**hors dépôt, non versionné**).

```diff
   "hookSpecificOutput": {
+    "hookEventName": "PreToolUse",
     "permissionDecision": "allow",
     "permissionDecisionReason": "Auto-approved by Auto Accept Extension"
   }
```

- **Option 1 (immédiate, sans code)** : appliquer le diff ci-dessus à la main (1 ligne).
- **Option 2 (définitive)** : ce hook est **redondant** avec `defaultMode: "bypassPermissions"` +
  `Bash(*)` du **même** fichier utilisateur ; et c'est un **auto-approve global de tous les outils**,
  donc l'inverse d'un garde-fou. Le retirer supprime l'erreur **et** les 423 ms. Contrepartie :
  suppression d'un mécanisme d'auto-approbation hors dépôt.
- **Validation humaine requise avant toute écriture hors dépôt.**

**Arbitrage rendu par l'humain le 2026-09-20** :
> « NON — rester au diagnostic, ne rien écrire hors dépôt. »

⇒ **Ce document est le livrable de T332.** Le dépôt reste inchangé ; aucune écriture hors dépôt.

### 6.1 Vérification prévue après application (à jouer par l'orchestrateur)

1. `AC3` : ouvrir une session Claude Code **fraîche** dans le dépôt, déclencher 1 `Bash`, 1 `Read`,
   1 `Edit`, puis scanner le nouveau transcript :
   `hook_non_blocking_error` de signature `Auto Accept Extension` = **0**.
2. `AC4` : rejouer le test de garde-fou synthétique (§7.4) ⇒ **exit 2 attendu, inchangé**.
3. `AC6` : `git status --short` ⇒ aucun fichier hors périmètre.

---

## 7. Constats hors scope (devoir d'alerte — signalés, **non corrigés**)

### 7.1 🔴 Garde-fou `Stop` silencieusement inactif hors racine du dépôt

Les hooks **projet** sont déclarés avec un **chemin relatif** :
`"command": "python TOOLS/AGENT_WORKFLOW/scripts/hook_stop.py"` (`.claude/settings.json:86`).

Quand la session Claude Code démarre dans un **sous-dossier**, la commande est résolue depuis ce
sous-dossier et le script devient introuvable. **3 enregistrements réels** dans
`bad627cd-28bf-4da2-b3ac-37f7300eff3e.jsonl` :

```text
"hookName":"Stop","hookEvent":"Stop","durationMs":194,
"stderr":"Hook script appears to be missing — \"python TOOLS/AGENT_WORKFLOW/scripts/hook_stop.py\"
 exited 2 with: C:\\Python314\\python.exe: can't open file
 'C:\\\\_MGS\\\\DEV\\\\2026_Projet_YGO_ExcavatriceDragage\\\\TOOLS\\\\PLC_CSV_SNAPSHOT\\\\TOOLS\\\\AGENT_WORKFLOW\\\\scripts\\\\hook_stop.py':
 [Errno 2] No such file or directory. Treating as non-blocking."
```

⇒ Contexte de session : `TOOLS/PLC_CSV_SNAPSHOT`. **Le garde-fou anti « lot annoncé terminé sur
bundle périmé / liaison rouge » ne tourne simplement pas dans ces sessions** — sans aucun signal
visible pour l'agent. Même fragilité dans les settings des worktrees :
`.claude/worktrees/WT3_TEST_AUTO_CI/.claude/settings.json:18,30,41` et
`.claude/worktrees/WT5_SIMBENCH/.claude/settings.json:18,30,41`.

**Correctif candidat** (non appliqué) : `${CLAUDE_PROJECT_DIR}/TOOLS/AGENT_WORKFLOW/scripts/hook_*.py`
ou chemin absolu, sur **les 3 fichiers de settings** + test de non-régression depuis un sous-dossier.
*Arbitrage humain 2026-09-20 : preuve écrite seule, la suite de pilotage appartient à l'orchestrateur
(candidat : tâche dédiée).*

### 7.2 🟠 `hook_pre_edit.py` — fail-open sur transcript avec BOM

Démontré expérimentalement (transcripts synthétiques identiques, payload identique) :

| Transcript | Résultat |
|---|---|
| ligne JSON **sans** BOM | `EXIT=2` — écriture **refusée**, 4 docs exigés |
| même ligne **avec** BOM UTF-8 (`EF BB BF`) | `EXIT=0` — écriture **autorisée** |

Chemin : `hook_pre_edit.py:89` (`except json.JSONDecodeError: continue`) ⇒ `files_actually_read()`
retourne un ensemble vide ⇒ `:137-138` « transcript illisible : idem, on ne bloque pas ».
Risque pratique faible (les transcripts Claude Code n'ont pas de BOM) mais **c'est un chemin de
contournement réel** du garde-fou « ne pas écrire dans `CODE/` sans avoir lu les règles ».
Correctif candidat : `encoding="utf-8-sig"` (1 mot). **Non appliqué** (hors « correctif minimal »).

### 7.3 🟡 Incohérence catalogue

`DOC/WFLOW/TASKS.yaml:41` porte `statut: ⏳` et `agent: '—'` pour T332, alors que le brief annonce la
tâche « repassée ⬜ / en_attente ». `TASKS.yaml` est **explicitement interdit** par ce brief ⇒ signalé,
non modifié.

### 7.4 🟡 `hook_post_edit.py` sur `CODE/*.st` = 1,5-1,8 s (> 1 s)

Optimisation séparée possible (appel `G200_check_linkage.py --files` au lieu de l'analyse globale).
**Proposée, non implémentée** (le brief impose « ajout du champ, rien d'autre »).

---

## 8. Critères d'acceptation (AC1 → AC6)

| AC | Verdict | Preuve |
|---|---|---|
| **AC1** Cartographie complète | ✅ | §4 — 13 lignes `fichier:ligne`, événement, matcher, commande, état |
| **AC2** Durées médiane + max (3 runs) | ✅ | §5 — 7 hooks mesurés + `durationMs:485` du transcript |
| **AC3** Zéro erreur de validation après correctif | ⏸️ **non atteignable ce jour** | Le correctif est **hors dépôt** et refusé par l'humain le 2026-09-20 ⇒ aucune modification ⇒ erreur toujours présente. Protocole de vérification écrit en §6.1 |
| **AC4** Garde-fou `PreToolUse` toujours bloquant | ✅ (avant) | §7.2 ligne « sans BOM » : payload `Edit CODE/M_MAIN/PRG_04_Treuils_Benne.st` + transcript sans les règles ⇒ **`EXIT=2`**, liste des docs exigés (`CODE_QUALITY_STANDARDS`, `NAMING_CONVENTION`, `AF_Partie-02`, `AF-Partie-06`). Le correctif ne touche pas ce script |
| **AC5** Garde-fou `Stop` toujours bloquant | ⚠️ **partiel + trou prouvé** | Branche bloquante `hook_stop.py:135-143` (`exit 2`) sur `G200 --report` (S1) + `G390_check_bundle_freshness.py` (S2), conditionnée par `st_files_touched()` `:92-97`. **Non exerçable ici** : `git status --porcelain -- CODE` est vide et simuler exigerait d'écrire dans `CODE/` (interdit par ce brief) ; `G390` crée un scratch et relance une génération (écarté pour ne pas concurrencer T300/T333). **Trou réel prouvé en §7.1** : hors racine du dépôt, ce garde-fou ne s'exécute pas du tout |
| **AC6** Diff limité aux scripts/config hooks ; aucun hook retiré, aucune allowlist | ✅ | **Diff dépôt : aucun fichier `CODE/`, `CODE_XML/`, `DOC/AF`, `TASKS.yaml` touché.** Seuls ajouts : `DOC/WFLOW/TASK_LOCKS.json` (verrou T332, **gitignoré** — `.gitignore:102`) et ce document. Aucun hook supprimé/commenté, aucune entrée d'allowlist ajoutée, aucun contournement par « exit 0 sans sortie » |

---

## 9. Journal de session

| Heure | Étape | État |
|---|---|---|
| 13:48 | Brief reçu, préambule relu depuis le dépôt (bloc `[COLLER ICI]` non remplacé) | `ok` |
| 13:48 | Localisation : 0 `hookSpecificOutput` dans le dépôt | `ok` |
| 13:48 | Diagnostic + preuve par empreinte, durées mesurées | `ok` |
| 13:48 | Test garde-fou `PreToolUse` (exit 2) | `ok` |
| 13:49 | Verrou `T332` posé (`TASK_LOCKS.json`, acteur `DSH01` — **tag contaminé**, renommé `DSH04` à 15:55) | `ok` |
| 13:49 | ⛔ **ARRÊT phase 2** — restitution cartographie + durées + correctif | `attente_validation` |
| — | Arbitrage humain : *ne rien écrire hors dépôt* ; preuve écrite durable | `ok` |
| — | Rédaction de cette preuve | `ok` |
| 15:55 | Assainissement nomenclature (CC01) : `T332` → `DSH04`, **adopté** pour toute écriture registre/heartbeat | `ok` |

Checkpoints machine : `TOOLS/AGENT_WORKFLOW/status/T332.log` (`agent_heartbeat.py`).
Les lignes du log antérieures à 15:55 portent `--agent DSH01` (**mis-taggées, conservées telles quelles**) ;
à partir de 15:55, `--agent DSH04`.

---

## 10. Fichiers touchés

| Fichier | Nature |
|---|---|
| `DOC/WFLOW/TASK_LOCKS.json` | verrou `T332` = **`DSH04`** (fichier **gitignoré**, `.gitignore:102`) |
| `DOC/WFLOW/AUDITS/T332_HOOKS_CLAUDE_CODE_20260920.md` | **ce document** (preuve durable) |
| `TOOLS/AGENT_WORKFLOW/status/T332.log` | checkpoints heartbeat (zone locale dédiée) |

**Zéro modification hors dépôt. Zéro modification de code `CODE/`. Zéro commit.**
