"""Indicateurs de la 2e ligne du statusline : état du workflow projet et repère git.

Séparé de `session_statusline.py` (orchestrateur : identité de session, titre terminal,
badge Superviseur) pour que chaque fichier reste lisible.

Règles :
  * Workflow : l'état DÉCLARÉ (fichier d'état) et l'état CONSTATÉ (transcript) sont
    distingués. Un workflow déclaré mais non appliqué est affiché comme tel — jamais
    certifié "ACTIF" sur la seule foi d'une commande.
  * Couleur : le vert ne s'allume QUE quand le workflow est réellement appliqué.
  * Git : branche (tronquée), worktree, écart avec l'upstream, fichiers modifiés.
  * Aucun plantage : toute erreur d'accès retombe sur un libellé neutre.
"""
import json
import os
import subprocess
import time
from pathlib import Path

LOCAL_APP = Path(os.environ.get("LOCALAPPDATA", r"C:\Users\ZEDVICTUS\AppData\Local"))
WORKFLOW_STATE_DIR = LOCAL_APP / "ExcavatriceDragage" / "workflow"
GIT_CACHE = LOCAL_APP / "Temp" / "session_statusline_git.json"
GIT_CACHE_TTL = 1.5  # secondes : évite 4 appels git à chaque rafraîchissement de prompt

# Décalage à droite de la 2e ligne. Claude Code SUPPRIME les espaces de tête de chaque
# ligne : l'écart est donc porté par un glyphe visible, suivi d'espaces intérieurs
# (conservés) puis la flèche de hiérarchie.
STATUSLINE_INDENT = "│" + " " * 3 + "↳ "



def get_workflow_badge(conv_id):
    """Workflow : variable binaire lue dans le fichier d'état de la session.

    `dans_le_workflow` = 1 (entré par /workflow-project) ou 0 (sorti par la commande off).
    Affichage : ● = 1, ○ = 0. Rien d'autre à décider — l'attestation du hook Stop
    (hook_workflow_attest.py) reste déposée à côté comme constat, elle ne commande rien.
    """
    green = "\033[1;32m"
    pastel_yellow = "\033[38;2;228;208;140m"
    reset = "\033[0m"
    if not conv_id:
        return "· session inconnue"
    path = WORKFLOW_STATE_DIR / f"{conv_id}.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return "· non démarré"
    dans_le_workflow = 1 if str(data.get("etat", "")).upper() == "ACTIF" else 0
    if dans_le_workflow:
        voie = data.get("voie") or "libre"
        etape = data.get("etape")
        detail = " · ".join(part for part in (etape, voie) if part)
        criticality = data.get("criticality") or ""
        if criticality:
            detail = f"{criticality} · {detail}"
        marker = ""
        try:
            attestation = json.loads((WORKFLOW_STATE_DIR / f"{conv_id}.attest.json").read_text(encoding="utf-8"))
            if int(attestation.get("conform_turns", 0)) == 0:
                # T429 M2 : declare actif, mais aucun tour conforme n'a ete atteste.
                marker = f" {pastel_yellow}⚠ non entré{reset}"
        except (OSError, ValueError):
            pass
        return f"{green}🛣️ ●{reset} · {detail}{marker}"
    return "🛣️ ○ · /workflow-project pour reprendre"


def get_cadrage_badge(conv_id):
    """Cadrage de la session : attributs de mission renseignes / attendus.

    Ex. « 0/12 » = aucun attribut de cadrage renseigne : la session n est pas cadree.
    """
    if not conv_id:
        return ""
    try:
        payload = json.loads((WORKFLOW_STATE_DIR / f"{conv_id}.attest.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return ""
    cadrage = payload.get("cadrage") or {}
    total = int(cadrage.get("total") or 0)
    if not total:
        return ""
    renseignes = int(cadrage.get("renseignes") or 0)
    green = "\033[1;32m"
    yellow = "\033[38;2;228;208;140m"
    soft_red = "\033[38;2;235;130;130m"
    reset = "\033[0m"
    color = green if renseignes >= total else (yellow if renseignes else soft_red)
    return f"{color}📋 {renseignes}/{total}{reset}"


def get_scope_badge(conv_id, transcript_path=None, window=10):
    """Part du travail réellement dans le périmètre de la tâche (R10).

    Compté depuis la trace des appels d'outils : c'est un décompte, pas un avis.
    Vert tant que la dérive reste faible, ambre au-delà de 10 %, rouge au-delà de 30 %.
    """
    green = "\033[1;32m"
    pastel_yellow = "\033[38;2;228;208;140m"
    soft_red = "\033[38;2;235;130;130m"
    reset = "\033[0m"
    if not conv_id:
        return ""
    try:
        import task_scope
    except ImportError:
        return ""
    try:
        result = task_scope.metric_logged(conv_id, window)
        if not result.get("total") and transcript_path:
            # Journal vide (hook installe recemment) : on replique sur le transcript.
            result = task_scope.metric(conv_id, transcript_path, window)
    except Exception:
        return ""
    total = int(result.get("total", 0))
    if not total or not result.get("scope_known"):
        return ""
    counts = result.get("counts", {})
    ratio = float(result.get("ratio_hors", 0.0))
    color = green if ratio <= 0.1 else pastel_yellow if ratio <= 0.3 else soft_red
    dedans = int(counts.get("produit", 0)) + int(counts.get("derogation", 0))
    return f"{color}🎯 {dedans}/{total} dans le périmètre{reset}"


def get_progress_badge(alias):
    """Position reelle de la tache : criteres valides / total, lus dans le contrat.

    Reponse a "ou on en est" : le titre de la tache dit le PROBLEME, pas l'etat.
    """
    if not alias:
        return ""
    try:
        import task_progress
    except ImportError:
        return ""
    try:
        data = task_progress.progress_for_alias(alias)
    except Exception:
        return ""
    total = int(data.get("total") or 0)
    if not total:
        return ""
    valides = int(data.get("valides") or 0)
    green = "\033[1;32m"
    yellow = "\033[38;2;228;208;140m"
    reset = "\033[0m"
    color = green if valides == total else yellow
    return f"{color}📐 {valides}/{total} AC{reset}"


def get_socle_badge(conv_id):
    """Socle lu / attendu, d'apres l attestation (constat par relecture du transcript).

    Voyant d'alarme quand le socle n'est pas complet : c'est la preuve que l'agent
    n'a pas lu les documents exiges a l'attachement.
    """
    if not conv_id:
        return ""
    try:
        payload = json.loads((WORKFLOW_STATE_DIR / f"{conv_id}.attest.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return ""
    socle = payload.get("socle") or {}
    total = int(socle.get("total") or 0)
    if not total:
        return ""
    lu = len(socle.get("lu") or [])
    green = "\033[1;32m"
    soft_red = "\033[38;2;235;130;130m"
    reset = "\033[0m"
    color = green if lu >= total else soft_red
    return f"{color}📚 {lu}/{total} lus{reset}"


def _git(args, cwd):
    try:
        done = subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True,
                              timeout=1.2, encoding="utf-8", errors="replace")
    except (OSError, subprocess.SubprocessError):
        return ""
    return done.stdout.strip() if done.returncode == 0 else ""


def _git_facts():
    """Faits git bruts (mis en cache 1,5 s pour ne pas ralentir chaque rafraîchissement)."""
    try:
        if GIT_CACHE.is_file() and (time.time() - GIT_CACHE.stat().st_mtime) < GIT_CACHE_TTL:
            cached = json.loads(GIT_CACHE.read_text(encoding="utf-8"))
            if cached.get("root"):
                return cached
    except (OSError, ValueError):
        pass
    cwd = os.getcwd()
    root = _git(["rev-parse", "--show-toplevel"], cwd)
    if not root:
        return {"root": ""}
    facts = {"root": root}
    facts["branch"] = _git(["rev-parse", "--abbrev-ref", "HEAD"], cwd) or "?"
    upstream = _git(["rev-parse", "--abbrev-ref", "@{u}"], cwd)
    facts["upstream"] = upstream
    counts = _git(["rev-list", "--left-right", "--count", f"{upstream}...HEAD"], cwd) if upstream else ""
    if counts:
        parts = counts.split()
        if len(parts) == 2:
            facts["behind"], facts["ahead"] = parts[0], parts[1]
    git_dir = _git(["rev-parse", "--absolute-git-dir"], cwd)
    facts["worktree"] = ""
    if git_dir and "worktrees" in git_dir.replace("\\", "/"):
        facts["worktree"] = Path(git_dir).name
    status = _git(["status", "--porcelain"], cwd)
    facts["dirty"] = len([line for line in status.splitlines() if line.strip()]) if status else 0
    try:
        GIT_CACHE.parent.mkdir(parents=True, exist_ok=True)
        GIT_CACHE.write_text(json.dumps(facts), encoding="utf-8")
    except OSError:
        pass
    return facts


def get_git_badge():
    """Repère git compact — branche, worktree, écart avec l'upstream, fichiers modifiés.

    Palette : branche principale (ou origin) en vert, autre branche en orange pastel,
    fichiers modifiés en jaune pastel clair (peu vif). Rien de long.
    """
    green = "\033[1;32m"
    pastel_orange = "\033[38;2;255;176;124m"
    pastel_yellow = "\033[38;2;228;208;140m"
    soft_red = "\033[38;2;235;130;130m"
    reset = "\033[0m"
    facts = _git_facts()
    if not facts.get("root"):
        return "🌿 hors dépôt"
    raw_branch = facts.get("branch", "?")
    branch = raw_branch if len(raw_branch) <= 24 else raw_branch[:23] + "…"
    is_main = raw_branch in ("main", "master") or raw_branch.startswith("origin/")
    color = green if is_main else pastel_orange
    parts = [f"{color}🌿 {branch}{reset}"]
    ahead, behind = facts.get("ahead"), facts.get("behind")
    if ahead is not None and behind is not None:
        if ahead != "0":
            parts.append(f"{green}↑{ahead}{reset}")
        if behind != "0":
            parts.append(f"{soft_red}↓{behind}{reset}")
    elif not facts.get("upstream"):
        parts.append(f"{pastel_yellow}↑?{reset}")
    dirty = facts.get("dirty", 0)
    if dirty:
        parts.append(f"{pastel_yellow}●{dirty} modifiés{reset}")
    worktree = facts.get("worktree")
    if worktree:
        parts.append(f"{pastel_yellow}WT:{worktree}{reset}")
    return " ".join(parts)
