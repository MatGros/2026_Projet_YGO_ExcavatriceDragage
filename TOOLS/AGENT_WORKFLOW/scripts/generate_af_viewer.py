#!/usr/bin/env python3
"""Genere DOC/WFLOW/AF_VIEWER.html : visualiseur AF *read-only*, hors-ligne.

Lit deux sources deja produites :
  - TOOLS/AGENT_WORKFLOW/config/af_traceability_matrix.yaml  (extract_functions_matrix.py)
  - TOOLS/AGENT_WORKFLOW/config/fb_cartouche_sync.json        (check_fb_cartouche_sync.py)

Emet UN SEUL fichier HTML auto-contenu : CSS + JS inline, donnees embarquees en
``<script type="application/json">``. Aucun ``fetch(``, ``XMLHttpRequest``,
``<form``, ``download=``, aucune ressource externe -> s'ouvre au double-clic
(``file://``), zero requete reseau.

Fraicheur (AC7) :
  - fb_cartouche_sync.json porte deja ``generated_at`` + ``source_head``.
  - Pour af_traceability_matrix.yaml (extracteur NON modifie), la fraicheur est
    derivee ici : max(dernier commit ``git log -1 --format=%cI``, mtime disque).
  - build_at = maintenant ; build_head = git rev-parse --short HEAD.
Les badges couleur (vert <=1 j, orange <=7 j, rouge >7 j) sont calcules COTE
CLIENT a l'ouverture (Date.now() - horodatage embarque).
"""

from __future__ import annotations

import html
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:  # pragma: no cover
    print("PyYAML requis", file=sys.stderr)
    sys.exit(1)

sys.path.insert(0, str(Path(__file__).resolve().parent))
# Reutilise l'extracteur de TC des titres TEST (meme dossier scripts/).
from G450_check_af_ci_coverage import expand_tc_ids, ids_from_test_titles  # noqa: E402

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
    except Exception:  # pragma: no cover
        pass

REPO_ROOT = Path(__file__).resolve().parents[3]
MATRIX_PATH = REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "config" / "af_traceability_matrix.yaml"
SYNC_PATH = REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "config" / "fb_cartouche_sync.json"
OUT_PATH = REPO_ROOT / "DOC" / "WFLOW" / "AF_VIEWER.html"

FB_TOKEN_RE = re.compile(r"FB_[A-Za-z0-9_]+")


def _canonical_tc_ids(text: str) -> list[str]:
    """Etend 'TC-P01-004/009', 'TC-P10-001-010'... en identifiants canoniques ordonnes."""
    return sorted(expand_tc_ids(str(text)))


def _vp_lookup(vpoints: dict[str, Any]) -> dict[str, dict[str, str]]:
    """id canonique -> {intention, type} ; gere les cles composees ('TC-a, TC-b')."""
    table: dict[str, dict[str, str]] = {}
    for key, val in (vpoints or {}).items():
        val = val or {}
        entry = {"intention": str(val.get("intention", "")), "type": str(val.get("type", ""))}
        for cid in _canonical_tc_ids(key):
            table.setdefault(cid, entry)
    return table


def _ci_verdict(root: Path, registry: dict, fb_key: str | None) -> dict[str, Any]:
    empty = {"domain": "", "total": 0, "passed": 0, "failed": 0, "verdict": "none", "report_rel": ""}
    if not fb_key:
        return empty
    entry = registry.get(fb_key)
    if not isinstance(entry, dict):
        return empty
    domain = str(entry.get("domain", ""))
    jpath = root / "TOOLS" / "TEST_AUTO_CI" / "RESULTS" / domain / "reports" / f"{fb_key}.json"
    if not jpath.is_file():
        return {**empty, "domain": domain}
    try:
        data = json.loads(jpath.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {**empty, "domain": domain}
    summ = data.get("summary") or {}
    total = int(summ.get("total", 0) or 0)
    passed = int(summ.get("passed", 0) or 0)
    failed = int(summ.get("failed", 0) or 0)
    verdict = "pass" if (total > 0 and failed == 0) else ("fail" if total > 0 else "none")
    return {
        "domain": domain,
        "total": total,
        "passed": passed,
        "failed": failed,
        "verdict": verdict,
        "report_rel": f"../../TOOLS/TEST_AUTO_CI/RESULTS/{domain}/reports/{fb_key}.html",
    }


def _traceability(matrix: dict[str, Any], root: Path) -> dict[str, Any]:
    """Chaine Besoin -> Fonction -> TC certifiant -> preuve CI (PASS/FAIL + rapport)."""
    root = Path(root)
    reg_path = root / "TOOLS" / "TEST_AUTO_CI" / "registry.yaml"
    registry: dict[str, Any] = {}
    if reg_path.is_file():
        registry = yaml.safe_load(reg_path.read_text(encoding="utf-8")) or {}

    fb_titles: dict[str, set[str]] = {}
    all_tested: set[str] = set()
    ignored: set[str] = set()
    for key, entry in registry.items():
        if not isinstance(entry, dict):
            continue
        ignored.update(entry.get("af_ignore", []) or [])
        ids: set[str] = set()
        test = entry.get("test")
        if test:
            tpath = root / test
            if tpath.is_file():
                ids = ids_from_test_titles(tpath.read_text(encoding="utf-8"))
        fb_titles[key] = ids
        all_tested |= ids

    rows: list[dict] = []
    fn_no_tc: list[dict] = []
    tc_orphan: list[dict] = []
    contract_tc: list[dict] = []
    tc_no_ci: list[dict] = []
    n_func = n_pass = n_gap = 0

    for af in sorted(matrix.get("domains", {})):
        dom = matrix["domains"][af] or {}
        functions = dom.get("functions", {}) or {}
        vpoints = dom.get("validation_points", {}) or {}
        vp_table = _vp_lookup(vpoints)
        af_cited: set[str] = set()

        for fid, f in functions.items():
            f = f or {}
            n_func += 1
            tc_ids = _canonical_tc_ids(" ".join(str(t) for t in (f.get("tc_couvrants") or []) if t))
            af_cited.update(tc_ids)
            realisee = str(f.get("realisee_par", "") or "")
            fb_key = next((tok for tok in FB_TOKEN_RE.findall(realisee) if tok in registry), None)
            titles = fb_titles.get(fb_key, set()) if fb_key else set()

            tcs = [
                {
                    "id": cid,
                    "intention": vp_table.get(cid, {}).get("intention", ""),
                    "type": vp_table.get(cid, {}).get("type", ""),
                    "in_ci_title": cid in titles,
                }
                for cid in tc_ids
            ]
            ci = _ci_verdict(root, registry, fb_key)

            if not tc_ids:
                fn_no_tc.append({"af": af, "fid": fid, "fonction": f.get("fonction", "")})
            for t in tcs:
                typ = t["type"]
                if t["id"] in all_tested or t["id"] in ignored:
                    continue
                if "SITE" in typ and "AUTO" not in typ:
                    continue
                if "AUTO" not in typ:
                    continue
                tc_no_ci.append({"af": af, "fid": fid, "tc": t["id"]})

            if ci["verdict"] == "pass":
                n_pass += 1
            if (not tc_ids) or any(not t["in_ci_title"] for t in tcs):
                n_gap += 1

            rows.append({
                "af": af,
                "fid": fid,
                "fonction": f.get("fonction", ""),
                "criticite": f.get("criticite", ""),
                "realisee_par": realisee,
                "tcs": tcs,
                "ci": ci,
            })

        seen: set[str] = set()
        for key, val in vpoints.items():
            val = val or {}
            for cid in _canonical_tc_ids(key):
                if cid in seen:
                    continue
                seen.add(cid)
                if cid not in af_cited:
                    target = contract_tc if af == "AF-03" else tc_orphan
                    target.append({"af": af, "tc": cid, "intention": str(val.get("intention", ""))})

    return {
        "rows": rows,
        "fn_no_tc": fn_no_tc,
        "tc_orphan": tc_orphan,
        "contract_tc": contract_tc,
        "tc_no_ci": tc_no_ci,
        "counts": {
            "functions": n_func,
            "functions_with_ci_pass": n_pass,
            "functions_with_gap": n_gap,
        },
    }


def _git(*args: str) -> str:
    try:
        out = subprocess.run(
            ["git", *args], cwd=REPO_ROOT, capture_output=True, text=True, check=True
        )
        return out.stdout.strip()
    except Exception:
        return ""


def _matrix_freshness(path: Path) -> str:
    """max(dernier commit du fichier, mtime disque) -> ISO 8601."""
    candidates: list[datetime] = []
    commit_iso = _git("log", "-1", "--format=%cI", "--", str(path.relative_to(REPO_ROOT)))
    if commit_iso:
        try:
            candidates.append(datetime.fromisoformat(commit_iso))
        except ValueError:
            pass
    try:
        candidates.append(datetime.fromtimestamp(path.stat().st_mtime).astimezone())
    except OSError:
        pass
    if not candidates:
        return datetime.now().astimezone().isoformat(timespec="seconds")
    return max(candidates).isoformat(timespec="seconds")


def _rows_from_matrix(matrix: dict[str, Any]) -> tuple[list[dict], list[dict], list[dict]]:
    """-> (rows_fonctions, rows_tc, per_domain_stats)."""
    fn_rows: list[dict] = []
    tc_rows: list[dict] = []
    dom_stats: list[dict] = []
    domains = matrix.get("domains", {})
    for dom in sorted(domains):
        data = domains[dom] or {}
        functions = data.get("functions", {}) or {}
        vpoints = data.get("validation_points", {}) or {}
        for fid, f in functions.items():
            f = f or {}
            fn_rows.append({
                "af": dom,
                "id": fid,
                "fonction": f.get("fonction", ""),
                "description": f.get("description", ""),
                "realisee_par": f.get("realisee_par", ""),
                "criticite": f.get("criticite", ""),
                "tc": [t for t in (f.get("tc_couvrants") or []) if t],
                "etat": f.get("statut") or f.get("etat") or "",
            })
        for vid, v in vpoints.items():
            v = v or {}
            tc_rows.append({
                "af": dom,
                "id": vid,
                "intention": v.get("intention", ""),
                "preuve": v.get("preuve", ""),
                "type": v.get("type", ""),
                "ref": v.get("ref", ""),
                "etat": v.get("etat", ""),
            })
        dom_stats.append({
            "af": dom,
            "file": data.get("file", ""),
            "n_fonctions": len(functions),
            "n_tc": len(vpoints),
            "has_table_fonctions": len(functions) > 0,
        })
    return fn_rows, tc_rows, dom_stats


def _json_for_script(obj: Any) -> str:
    """JSON serialise, neutralise pour insertion dans <script type=application/json>."""
    txt = json.dumps(obj, ensure_ascii=False)
    return txt.replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")


HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>\U0001F4D0 AF Viewer \u2014 Fonctions, TC & sync cartouches (read-only)</title>
<style>
*,*::before,*::after{{box-sizing:border-box;margin:0;padding:0}}
:root{{
  color-scheme:dark;
  --bg:#1e1e2e;--panel:#282a36;--ink:#f8f8f2;--muted:#9aa3c4;--line:#44475a;
  --accent:#bd93f9;--row-alt:#21222c;--th-bg:#191a21;--th-hover:#2a2c3a;
  --ok:#50fa7b;--ok-bg:#1c3a26;--warn:#ffb86c;--warn-bg:#3d2e18;
  --info:#8be9fd;--info-bg:#123039;--none:#9aa3c4;--none-bg:#2a2c3a;
  --green:#50fa7b;--orange:#ffb86c;--red:#ff5555;
}}
html,body{{background:var(--bg);color:var(--ink);
  font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
  font-size:13px;line-height:1.45}}
body{{padding:16px;max-width:1500px;margin:0 auto}}
h1{{font-size:18px;color:var(--accent);margin-bottom:2px}}
h2{{font-size:15px;color:var(--ink)}}
details.sec{{margin:18px 0}}
details.sec>summary{{font-size:15px;font-weight:600;color:var(--ink);cursor:pointer;
  list-style:none;display:flex;align-items:center;gap:8px;padding:6px 8px;border-radius:6px;
  background:var(--panel);border:1px solid var(--line);user-select:none}}
details.sec>summary:hover{{background:var(--th-hover)}}
details.sec>summary::-webkit-details-marker{{display:none}}
details.sec>summary::before{{content:"\\25B8";color:var(--accent);font-size:12px;transition:transform .12s}}
details.sec[open]>summary::before{{transform:rotate(90deg)}}
details.sec>.body{{padding-top:8px}}
.sub{{color:var(--muted);font-size:12px;margin-bottom:14px}}
.panel{{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:12px 14px;margin-bottom:14px}}
.statgrid{{display:flex;flex-wrap:wrap;gap:18px;align-items:flex-start}}
.stat{{min-width:90px}}
.stat .n{{font-size:20px;font-weight:700}}
.stat .l{{font-size:11px;color:var(--muted);text-transform:uppercase;letter-spacing:.03em}}
.bar{{display:flex;height:14px;border-radius:4px;overflow:hidden;border:1px solid var(--line);margin:8px 0;min-width:220px}}
.bar>span{{display:block}}
.bar .b-synced{{background:var(--ok)}}
.bar .b-covered{{background:var(--accent)}}
.bar .b-drift{{background:var(--warn)}}
.bar .b-no_fiche{{background:var(--info)}}
.bar .b-no_pointer{{background:var(--none)}}
.legend{{display:flex;gap:14px;flex-wrap:wrap;font-size:11px;color:var(--muted)}}
.legend i{{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:4px;vertical-align:middle}}
.domchips{{display:flex;flex-wrap:wrap;gap:6px;margin-top:8px}}
.chip{{background:var(--row-alt);border:1px solid var(--line);border-radius:12px;padding:2px 9px;font-size:11px;color:var(--muted)}}
.chip.zero{{opacity:.55}}
.chip[data-af]{{cursor:pointer}}
.chip.active{{background:var(--accent);color:#000;border-color:var(--accent)}}
.freshbar{{display:flex;flex-wrap:wrap;gap:10px;align-items:center;font-size:12px}}
.fresh{{display:inline-flex;align-items:center;gap:6px;border:1px solid var(--line);border-radius:6px;padding:3px 8px;cursor:help}}
.dot{{width:9px;height:9px;border-radius:50%;background:var(--none);flex:none}}
.dot.g{{background:var(--green)}} .dot.o{{background:var(--orange)}} .dot.r{{background:var(--red)}}
.warnbadge{{background:var(--warn-bg);color:var(--warn);border:1px solid var(--warn);border-radius:6px;
  padding:2px 8px;font-size:11px;font-weight:600}}
.controls{{margin:6px 0 4px}}
.controls input{{width:280px;max-width:100%;padding:6px 9px;border:1px solid var(--line);border-radius:6px;
  font-size:12px;background:var(--bg);color:var(--ink)}}
.controls input:focus{{outline:none;border-color:var(--accent)}}
.qbtns{{display:flex;flex-wrap:wrap;gap:6px;margin:6px 0 2px}}
.filter-btn{{padding:4px 10px;background:var(--row-alt);border:1px solid var(--line);border-radius:12px;
  color:var(--muted);cursor:pointer;font-size:11px;transition:all .15s;white-space:nowrap}}
.filter-btn.active,.filter-btn:hover{{background:var(--accent);color:#000;font-weight:bold}}
th[data-k="af"]{{min-width:64px}}
td.af{{white-space:nowrap}}
.count{{color:var(--muted);font-size:11px;margin-left:8px}}
.tablewrap{{overflow-x:auto;border:1px solid var(--line);border-radius:8px}}
table{{border-collapse:collapse;width:100%;font-size:12px}}
th,td{{text-align:left;padding:6px 9px;border-bottom:1px solid var(--line);vertical-align:top}}
th{{background:var(--th-bg);position:sticky;top:0;cursor:pointer;white-space:nowrap;font-weight:600;color:var(--ink)}}
th:hover{{background:var(--th-hover)}}
th .ar{{color:var(--accent);font-size:10px}}
tbody tr:nth-child(even){{background:var(--row-alt)}}
td.mono,span.mono{{font-family:"SF Mono",SFMono-Regular,Consolas,"Liberation Mono",Menlo,monospace;font-size:11px}}
.pill{{display:inline-block;padding:1px 7px;border-radius:10px;font-size:11px;font-weight:600;white-space:nowrap}}
.p-synced{{background:var(--ok-bg);color:var(--ok)}}
.p-covered{{background:#2a2440;color:var(--accent)}}
.p-drift{{background:var(--warn-bg);color:var(--warn)}}
.p-no_fiche{{background:var(--info-bg);color:var(--info)}}
.p-no_pointer{{background:var(--none-bg);color:var(--none)}}
.b-yes{{color:var(--ok);font-weight:700}} .b-no{{color:var(--red);font-weight:700}} .b-na{{color:var(--muted)}}
.small{{color:var(--muted);font-size:11px}}
.tcbadge{{display:inline-block;margin:1px 3px 1px 0;padding:1px 6px;border-radius:9px;font-size:10px;
  font-family:"SF Mono",SFMono-Regular,Consolas,"Liberation Mono",Menlo,monospace;
  border:1px solid var(--line);background:var(--row-alt);color:var(--muted)}}
.tcbadge.ok{{color:var(--ok);border-color:var(--ok)}}
.tcbadge.no{{color:var(--red);border-color:var(--red)}}
.verdict{{font-weight:700;white-space:nowrap}}
.verdict.pass{{color:var(--ok)}} .verdict.fail{{color:var(--red)}} .verdict.none{{color:var(--muted)}}
.gapbox{{margin:10px 0}}
.gapbox>summary{{cursor:pointer;font-weight:600;padding:4px 0;color:var(--ink);list-style:none}}
.gapbox>summary::-webkit-details-marker{{display:none}}
.gapbox>summary::before{{content:"\\25B8";color:var(--accent);font-size:11px;margin-right:6px;display:inline-block}}
.gapbox[open]>summary::before{{transform:rotate(90deg)}}
.gapbox ul{{margin:6px 0 8px 20px}}
.gapbox li{{margin:2px 0;font-size:11px}}
.okmsg{{color:var(--ok);font-size:11px;margin:4px 0 8px}}
.refresh code{{display:inline-block;background:var(--bg);border:1px solid var(--line);border-radius:4px;
  padding:2px 7px;font-size:11px;
  font-family:"SF Mono",SFMono-Regular,Consolas,"Liberation Mono",Menlo,monospace;color:var(--ink)}}
.refresh .cmdline{{display:flex;gap:8px;align-items:center;margin:4px 0;flex-wrap:wrap}}
.copybtn{{background:var(--panel);border:1px solid var(--line);color:var(--ink);cursor:pointer;
  border-radius:4px;padding:2px 8px;font-size:11px}}
.copybtn:hover{{background:var(--th-hover)}}
footer{{margin-top:26px;color:var(--muted);font-size:11px;border-top:1px solid var(--line);padding-top:10px}}
</style>
</head>
<body>
<h1>\U0001F4D0 AF Viewer \u2014 lecture seule</h1>
<div class="sub">Fonctions &amp; points de validation extraits des specs AF, et etat de synchronisation
des cartouches d'en-tete <span class="mono">CODE/**/FB_*.st</span> avec leur fiche AF.
Page 100&nbsp;% hors-ligne : aucune requete reseau, aucune ecriture, aucun export.</div>

<div class="panel" id="stats"></div>
<div class="panel freshbar" id="fresh"></div>

<div class="panel refresh">
<strong>\U0001F504 Rafraichir (aucun serveur — colle dans un terminal a la racine du repo)</strong>
<div class="cmdline"><code data-cmd="1">python TOOLS/AGENT_WORKFLOW/scripts/check_fb_cartouche_sync.py</code><button type="button" class="copybtn" data-copy="1">copier</button></div>
<div class="cmdline"><code data-cmd="2">python TOOLS/AGENT_WORKFLOW/scripts/extract_functions_matrix.py</code><button type="button" class="copybtn" data-copy="2">copier</button></div>
<div class="cmdline"><code data-cmd="3">python TOOLS/AGENT_WORKFLOW/scripts/generate_af_viewer.py</code><button type="button" class="copybtn" data-copy="3">copier</button></div>
<div class="cmdline"><button type="button" class="copybtn" id="copy-all">copier tout</button>
<span class="small">ou double-clic sur <code>refresh_af_viewer.bat</code> (meme dossier que cette page)</span></div>
</div>

<details class="sec"><summary>1 &middot; Fonctions par AF <span class="count" id="c-fn"></span></summary>
<div class="body">
<div class="controls"><input type="text" id="f-fn" placeholder="filtre texte (AF, fonction, FB, criticite\u2026)" autocomplete="off"></div>
<div class="qbtns" id="qb-fn"></div>
<div class="tablewrap"><table id="t-fn"><thead><tr>
<th data-k="af">AF</th><th data-k="id">ID</th><th data-k="fonction">Fonction</th>
<th data-k="realisee_par">Realisee par</th><th data-k="criticite">Crit.</th>
<th data-k="tcs">TC couvrants</th><th data-k="etat">Etat</th>
</tr></thead><tbody></tbody></table></div>
</div></details>

<details class="sec"><summary>2 &middot; TC par AF <span class="count" id="c-tc"></span></summary>
<div class="body">
<div class="controls"><input type="text" id="f-tc" placeholder="filtre texte (AF, ID, intention, type\u2026)" autocomplete="off"></div>
<div class="qbtns" id="qb-tc"></div>
<div class="tablewrap"><table id="t-tc"><thead><tr>
<th data-k="af">AF</th><th data-k="id">ID</th><th data-k="intention">Intention</th>
<th data-k="preuve">Preuve</th><th data-k="type">Type</th><th data-k="ref">Ref</th><th data-k="etat">Etat</th>
</tr></thead><tbody></tbody></table></div>
</div></details>

<details class="sec"><summary>3 &middot; Sync cartouches FB <span class="count" id="c-sy"></span></summary>
<div class="body">
<div class="controls"><input type="text" id="f-sy" placeholder="filtre texte (FB, statut, pointeur\u2026)" autocomplete="off"></div>
<div class="qbtns" id="qb-sy"></div>
<div class="tablewrap"><table id="t-sy"><thead><tr>
<th data-k="pou_name">FB</th><th data-k="statut">Statut</th><th data-k="stref">.st:ligne</th>
<th data-k="role">Role (.st)</th><th data-k="docref">Pointeur doc:ligne</th>
<th data-k="nom_match">nom_match</th><th data-k="role_match">role_match</th>
</tr></thead><tbody></tbody></table></div>
</div></details>

<details class="sec"><summary>4 &middot; Tracabilite Fonction → TC → Test CI <span class="count" id="c-tr"></span></summary>
<div class="body">
<div class="sub">Chaine <span class="mono">Besoin → Fonction (F&lt;NN&gt;.&lt;seq&gt;) → TC certifiant → preuve CI</span>.
Jointure matrice AF &times; registre <span class="mono">TEST_AUTO_CI</span> &times; rapports JSON — met en evidence les trous.</div>
<div class="controls"><input type="text" id="f-tr" placeholder="filtre texte (AF, fonction, FB, TC, verdict…)" autocomplete="off"></div>
<div class="qbtns" id="qb-tr"></div>
<div class="tablewrap"><table id="t-tr"><thead><tr>
<th data-k="af">AF</th><th data-k="fonction">Fonction</th><th data-k="criticite">Crit.</th>
<th data-k="realisee_par">Realisee par</th><th data-k="tc_str">TC (✅ titre TEST / ❌ absent)</th>
<th data-k="ci_str">CI</th><th data-k="rpt_str">Rapport</th>
</tr></thead><tbody></tbody></table></div>
<div id="tr-gaps"></div>
</div></details>

<footer id="foot"></footer>

<script type="application/json" id="data-fn">{FN}</script>
<script type="application/json" id="data-tc">{TC}</script>
<script type="application/json" id="data-sy">{SY}</script>
<script type="application/json" id="data-dom">{DOM}</script>
<script type="application/json" id="data-meta">{META}</script>
<script type="application/json" id="data-tr">{TR}</script>
<script>
"use strict";
function grab(id){{return JSON.parse(document.getElementById(id).textContent);}}
var FN=grab("data-fn"), TC=grab("data-tc"), SY=grab("data-sy"), DOM=grab("data-dom"), META=grab("data-meta"), TR=grab("data-tr");
function esc(s){{s=(s==null?"":String(s));return s.replace(/[&<>"]/g,function(c){{return {{"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}}[c];}});}}

/* ---------- bandeau stats ---------- */
(function(){{
  var c=META.sync_counts, tot=META.sync_total;
  var order=["synced","covered","drift","no_fiche","no_pointer"];
  var seg=order.map(function(k){{
    var w=tot?(100*(c[k]||0)/tot):0;
    return '<span class="b-'+k+'" style="width:'+w.toFixed(2)+'%" title="'+k+' : '+(c[k]||0)+'"></span>';
  }}).join("");
  var afWith=DOM.filter(function(d){{return d.has_table_fonctions;}}).length;
  var chips=DOM.map(function(d){{
    var z=(d.n_fonctions===0&&d.n_tc===0)?" zero":"";
    return '<span class="chip'+z+'" data-af="'+esc(d.af)+'" title="Filtrer sections 1, 2 et 4 sur '+esc(d.af)+' (re-clic = tout reafficher)">'
      + esc(d.af)+' &middot; '+d.n_fonctions+' fn / '+d.n_tc+' TC</span>';
  }}).join("");
  var partial = afWith<DOM.length
    ? '<span class="warnbadge" title="AF sans section &laquo; Table des fonctions &raquo; : extraction fonctions partielle">extraction partielle : '+afWith+'/'+DOM.length+' AF</span>'
    : '';
  document.getElementById("stats").innerHTML =
    '<div class="statgrid">'
    + '<div class="stat"><div class="n">'+FN.length+'</div><div class="l">fonctions AF</div></div>'
    + '<div class="stat"><div class="n">'+TC.length+'</div><div class="l">TC AF</div></div>'
    + '<div class="stat"><div class="n">'+(TR.counts.functions-TR.fn_no_tc.length)+'</div><div class="l">fonctions tracees</div></div>'
    + '<div class="stat"><div class="n">'+TR.counts.functions_with_gap+'</div><div class="l">fonctions avec trou</div></div>'
    + '<div class="stat"><div class="n">'+(c.synced||0)+'</div><div class="l">&#9989; synced</div></div>'
    + '<div class="stat"><div class="n">'+(c.covered||0)+'</div><div class="l">&#128260; covered</div></div>'
    + '<div class="stat"><div class="n">'+(c.drift||0)+'</div><div class="l">&#9888; drift</div></div>'
    + '<div class="stat"><div class="n">'+(c.no_fiche||0)+'</div><div class="l">&#128309; no_fiche</div></div>'
    + '<div class="stat"><div class="n">'+(c.no_pointer||0)+'</div><div class="l">&#9898; no_pointer</div></div>'
    + '<div class="stat"><div class="n">'+afWith+'/'+DOM.length+'</div><div class="l">AF avec table fn</div></div>'
    + '</div>'
    + '<div class="bar">'+seg+'</div>'
    + '<div class="legend">'
    + '<span><i style="background:var(--ok)"></i>synced (fiche dediee)</span>'
    + '<span><i style="background:var(--accent)"></i>covered (nomme dans chapo domaine)</span>'
    + '<span><i style="background:var(--warn)"></i>drift (fiche ne nomme pas le FB)</span>'
    + '<span><i style="background:var(--info)"></i>no_fiche</span>'
    + '<span><i style="background:var(--none)"></i>no_pointer</span>'
    + '&nbsp;&nbsp;'+partial
    + '</div>'
    + '<div class="domchips">'+chips+'</div>';
  Array.prototype.forEach.call(document.querySelectorAll(".domchips .chip[data-af]"),function(ch){{
    ch.addEventListener("click",function(){{
      var on=!ch.classList.contains("active");
      Array.prototype.forEach.call(document.querySelectorAll(".domchips .chip[data-af]"),function(x){{x.classList.remove("active");}});
      ["f-fn","f-tc","f-tr"].forEach(function(id){{
        var inp=document.getElementById(id); if(!inp) return;
        inp.value=on?ch.getAttribute("data-af"):"";
        try{{inp.dispatchEvent(new Event("input"));}}catch(err){{}}
      }});
      if(on) ch.classList.add("active");
    }});
  }});
}})();

/* ---------- bandeau fraicheur (badges cote client) ---------- */
(function(){{
  function band(ts){{
    var t=Date.parse(ts); if(isNaN(t)) return "";
    var age=(Date.now()-t)/86400000;
    return age<=1?"g":(age<=7?"o":"r");
  }}
  function human(ts){{var d=new Date(ts);return isNaN(d)?ts:d.toLocaleString();}}
  var items=[
    {{lbl:"matrice AF",ts:META.matrix_fresh,sha:null}},
    {{lbl:"sync cartouches",ts:META.sync_generated_at,sha:META.sync_source_head}},
    {{lbl:"page construite",ts:META.build_at,sha:META.build_head}}
  ];
  var h='<strong>Fraicheur des donnees</strong> &nbsp;';
  h+=items.map(function(it){{
    var b=band(it.ts);
    var tip=human(it.ts)+(it.sha?("  \u00b7 HEAD "+it.sha):"");
    return '<span class="fresh" title="'+esc(tip)+'"><span class="dot '+b+'"></span>'
      + esc(it.lbl)+' : '+esc((it.ts||"?").slice(0,19).replace("T"," "))+'</span>';
  }}).join("");
  h+='<span class="small">&nbsp;vert &le;1&nbsp;j &middot; orange &le;7&nbsp;j &middot; rouge &gt;7&nbsp;j (calcul navigateur a l\\'ouverture)</span>';
  document.getElementById("fresh").innerHTML=h;
}})();

/* ---------- tables triables + filtrables ---------- */
function makeTable(tblId, filtId, cntId, rows, cols, defSort, quicks){{
  var tbl=document.getElementById(tblId), tb=tbl.tBodies[0];
  var state={{key:defSort?defSort.key:cols[0].k, dir:defSort?defSort.dir:1}};
  var qwrap=document.getElementById(filtId.replace("f-","qb-"));
  var qstate=null;
  function cellVal(r,k){{
    if(k==="tcs") return (r.tc||[]).join(" ");
    if(k==="stref") return (r.file||r.pou_name||"")+":"+(r.st_line||0)+" "+(r.pou_name||"");
    if(k==="docref") return (r.doc_pointer||"")+":"+(r.doc_line||0);
    return r[k];
  }}
  function render(){{
    var q=document.getElementById(filtId).value.toLowerCase().trim();
    var list=rows.filter(function(r){{
      if(qstate&&!qstate.f(r)) return false;
      if(!q) return true;
      return cols.some(function(c){{return String(cellVal(r,c.k)==null?"":cellVal(r,c.k)).toLowerCase().indexOf(q)>=0;}})
        || String(r.af||"").toLowerCase().indexOf(q)>=0;
    }});
    list.sort(function(a,b){{
      var va=cellVal(a,state.key), vb=cellVal(b,state.key);
      va=va==null?"":va; vb=vb==null?"":vb;
      var na=parseFloat(va), nb=parseFloat(vb);
      var cmp;
      if(!isNaN(na)&&!isNaN(nb)&&String(va).match(/^-?\\d/)&&String(vb).match(/^-?\\d/)) cmp=na-nb;
      else cmp=String(va).localeCompare(String(vb),"fr");
      return cmp*state.dir;
    }});
    tb.innerHTML=list.map(function(r){{
      return "<tr>"+cols.map(function(c){{return "<td"+(c.cls?' class="'+c.cls+'"':"")+">"+c.fmt(r)+"</td>";}}).join("")+"</tr>";
    }}).join("");
    document.getElementById(cntId).textContent="("+list.length+" / "+rows.length+")";
    Array.prototype.forEach.call(tbl.tHead.rows[0].cells,function(th){{
      var k=th.getAttribute("data-k");
      var base=th.textContent.replace(/[\\u25B2\\u25BC]\\s*$/,"").trim();
      th.innerHTML=esc(base)+(k===state.key?(' <span class="ar">'+(state.dir>0?"\\u25B2":"\\u25BC")+"</span>"):"");
    }});
  }}
  Array.prototype.forEach.call(tbl.tHead.rows[0].cells,function(th){{
    th.addEventListener("click",function(){{
      var k=th.getAttribute("data-k");
      if(state.key===k) state.dir=-state.dir; else {{state.key=k;state.dir=1;}}
      render();
    }});
  }});
  document.getElementById(filtId).addEventListener("input",render);
  if(qwrap&&quicks&&quicks.length){{
    qwrap.innerHTML=quicks.map(function(q,i){{
      var n=q.f?rows.filter(q.f).length:rows.length;
      return '<button type="button" class="filter-btn" data-qi="'+i+'">'+esc(q.label)+" ("+n+")</button>";
    }}).join("");
    qwrap.addEventListener("click",function(e){{
      var b=e.target;
      while(b&&b!==qwrap&&!(b.tagName==="BUTTON"&&b.hasAttribute("data-qi"))) b=b.parentNode;
      if(!b||b===qwrap) return;
      var i=parseInt(b.getAttribute("data-qi"),10);
      qstate=(i===0)?null:quicks[i];
      Array.prototype.forEach.call(qwrap.children,function(x){{x.classList.remove("active");}});
      b.classList.add("active");
      render();
    }});
  }}
  render();
}}

/* ---------- filtres rapides (boutons, meme pattern que TASK_VIEWER) ---------- */
var Q_FN=[
  {{label:"Tous",f:null}},
  {{label:"🔴 C4",f:function(r){{return String(r.criticite||"").indexOf("C4")>=0;}}}},
  {{label:"🟠 C3",f:function(r){{return String(r.criticite||"").indexOf("C3")>=0;}}}},
  {{label:"🟡 C2",f:function(r){{return String(r.criticite||"").indexOf("C2")>=0;}}}},
  {{label:"⚪ C1",f:function(r){{return String(r.criticite||"").indexOf("C1")>=0;}}}},
  {{label:"⛔ sans TC",f:function(r){{return !(r.tc||[]).length;}}}}
];
var Q_TC=[{{label:"Tous",f:null}}];
(function(){{
  var seen={{}};
  TC.forEach(function(r){{
    var t=r.type||"";
    if(seen[t]) return; seen[t]=1;
    Q_TC.push({{label:t||"(sans type)",f:(function(v){{return v?function(r){{return r.type===v;}}:function(r){{return !r.type;}};}})(t)}});
  }});
  Q_TC.push({{label:"⬜ NV",f:function(r){{return String(r.etat||"").indexOf("NV")===0;}}}});
  Q_TC.push({{label:"✅ V",f:function(r){{return String(r.etat||"").indexOf("V")===0;}}}});
}})();
var Q_SY=[
  {{label:"Tous",f:null}},
  {{label:"⚠ drift",f:function(r){{return r.statut==="drift";}}}},
  {{label:"🔄 covered",f:function(r){{return r.statut==="covered";}}}},
  {{label:"✅ synced",f:function(r){{return r.statut==="synced";}}}},
  {{label:"🔹 no_fiche",f:function(r){{return r.statut==="no_fiche";}}}},
  {{label:"○ no_pointer",f:function(r){{return r.statut==="no_pointer";}}}}
];
var Q_TR=[
  {{label:"Tous",f:null}},
  {{label:"🟢 CI pass",f:function(r){{return (r.ci||{{}}).verdict==="pass";}}}},
  {{label:"🔴 CI fail",f:function(r){{return (r.ci||{{}}).verdict==="fail";}}}},
  {{label:"⚪ CI none",f:function(r){{var v=(r.ci||{{}}).verdict;return v!=="pass"&&v!=="fail";}}}},
  {{label:"⛔ sans TC",f:function(r){{return !(r.tcs||[]).length;}}}},
  {{label:"❌ TC hors CI",f:function(r){{return (r.tcs||[]).some(function(t){{return !t.in_ci_title;}});}}}}
];

makeTable("t-fn","f-fn","c-fn",FN,[
  {{k:"af",cls:"af",fmt:function(r){{return esc(r.af);}}}},
  {{k:"id",cls:"mono",fmt:function(r){{return esc(r.id);}}}},
  {{k:"fonction",fmt:function(r){{return esc(r.fonction)+(r.description?'<div class="small">'+esc(r.description)+"</div>":"");}}}},
  {{k:"realisee_par",fmt:function(r){{return esc(r.realisee_par);}}}},
  {{k:"criticite",fmt:function(r){{return esc(r.criticite);}}}},
  {{k:"tcs",cls:"mono",fmt:function(r){{return esc((r.tc||[]).join(", "));}}}},
  {{k:"etat",fmt:function(r){{return esc(r.etat);}}}}
],null,Q_FN);

makeTable("t-tc","f-tc","c-tc",TC,[
  {{k:"af",cls:"af",fmt:function(r){{return esc(r.af);}}}},
  {{k:"id",cls:"mono",fmt:function(r){{return esc(r.id);}}}},
  {{k:"intention",fmt:function(r){{return esc(r.intention);}}}},
  {{k:"preuve",fmt:function(r){{return esc(r.preuve);}}}},
  {{k:"type",fmt:function(r){{return esc(r.type);}}}},
  {{k:"ref",cls:"mono",fmt:function(r){{return esc(r.ref);}}}},
  {{k:"etat",fmt:function(r){{return esc(r.etat);}}}}
],null,Q_TC);

var RANK={{drift:0,no_fiche:1,no_pointer:2,covered:3,synced:4}};
SY.forEach(function(r){{r._rank=RANK[r.statut]==null?9:RANK[r.statut];}});
makeTable("t-sy","f-sy","c-sy",SY,[
  {{k:"pou_name",cls:"mono",fmt:function(r){{return (r.emoji?esc(r.emoji)+" ":"")+esc(r.pou_name);}}}},
  {{k:"statut",fmt:function(r){{return '<span class="pill p-'+r.statut+'">'+esc(r.statut)+"</span>";}}}},
  {{k:"stref",cls:"mono",fmt:function(r){{return esc(r.file)+":"+(r.st_line||0);}}}},
  {{k:"role",fmt:function(r){{return r.role?esc(r.role):'<span class="small">(pas de ligne Role)</span>';}}}},
  {{k:"docref",cls:"mono",fmt:function(r){{return r.doc_pointer?esc(r.doc_pointer)+":"+(r.doc_line||0):'<span class="small">\u2014</span>';}}}},
  {{k:"nom_match",cls:"",fmt:function(r){{return r.nom_match==null?'<span class="b-na">n/a</span>':(r.nom_match?'<span class="b-yes">oui</span>':'<span class="b-no">non</span>');}}}},
  {{k:"role_match",fmt:function(r){{return r.role_match==null?'<span class="b-na">n/a</span>':(r.role_match?'<span class="b-yes">oui</span>':'<span class="b-no">non</span>');}}}}
],{{key:"_rank",dir:1}},Q_SY);

/* ---------- section 4 : tracabilite Fonction -> TC -> Test CI ---------- */
(function(){{
  var rows=TR.rows.map(function(r){{
    var ci=r.ci||{{}};
    r.tc_str=(r.tcs||[]).map(function(t){{return t.id+(t.in_ci_title?" ok":" no");}}).join(" ")||"aucun";
    r.ci_str=(ci.verdict||"none")+" "+(ci.passed||0)+"/"+(ci.total||0);
    r.rpt_str=ci.report_rel?"rapport":"";
    return r;
  }});
  function tcCell(r){{
    if(!r.tcs||!r.tcs.length) return '<span class="tcbadge no">aucun TC</span>';
    return r.tcs.map(function(t){{
      var cls=t.in_ci_title?"ok":"no", mk=t.in_ci_title?"\\u2705":"\\u274c";
      return '<span class="tcbadge '+cls+'" title="'+esc((t.type?t.type+" \\u2014 ":"")+t.intention)+'">'
        + esc(t.id)+' '+mk+'</span>';
    }}).join("");
  }}
  function ciCell(r){{
    var ci=r.ci||{{}}, v=ci.verdict||"none";
    var txt = v==="pass" ? ("\\uD83D\\uDFE2 "+(ci.passed||0)+"/"+(ci.total||0))
            : v==="fail" ? ("\\uD83D\\uDD34 "+(ci.passed||0)+"/"+(ci.total||0))
            : "\\u26AA none";
    return '<span class="verdict '+v+'">'+txt+'</span>';
  }}
  function rptCell(r){{
    var ci=r.ci||{{}};
    return ci.report_rel
      ? '<a href="'+esc(ci.report_rel)+'" target="_blank" rel="noopener">rapport</a>'
      : '<span class="small">\\u2014</span>';
  }}
  makeTable("t-tr","f-tr","c-tr",rows,[
    {{k:"af",cls:"af",fmt:function(r){{return esc(r.af);}}}},
    {{k:"fonction",fmt:function(r){{return '<span class="mono">'+esc(r.fid)+'</span> '+esc(r.fonction);}}}},
    {{k:"criticite",fmt:function(r){{return esc(r.criticite);}}}},
    {{k:"realisee_par",fmt:function(r){{return esc(r.realisee_par);}}}},
    {{k:"tc_str",fmt:tcCell}},
    {{k:"ci_str",fmt:ciCell}},
    {{k:"rpt_str",fmt:rptCell}}
  ],{{key:"af",dir:1}},Q_TR);

  function gapList(title,items,render){{
    var body=items.length?('<ul>'+items.map(render).join("")+'</ul>'):'<div class="okmsg">aucun</div>';
    return '<details class="gapbox"'+(items.length?" open":"")+'><summary>'+esc(title)
      + ' ('+items.length+')</summary>'+body+'</details>';
  }}
  var g="";
  g+=gapList("Fonctions sans TC",TR.fn_no_tc,function(x){{
    return '<li><span class="mono">'+esc(x.af+" "+x.fid)+'</span> \\u2014 '+esc(x.fonction)+'</li>';
  }});
  g+=gapList("TC orphelins \\u2014 aucune fonction ne les revendique",TR.tc_orphan,function(x){{
    return '<li><span class="mono">'+esc(x.af+" "+x.tc)+'</span>'+(x.intention?' \\u2014 '+esc(x.intention):"")+'</li>';
  }});
  g+=gapList("Contrats socle AF-03 \\u2014 hors fonctions métier",TR.contract_tc,function(x){{
    return '<li><span class="mono">'+esc(x.af+" "+x.tc)+'</span>'+(x.intention?' \\u2014 '+esc(x.intention):"")+'</li>';
  }});
  g+=gapList("TC AUTO sans titre TEST",TR.tc_no_ci,function(x){{
    return '<li><span class="mono">'+esc(x.af+" "+x.fid+" \\u2192 "+x.tc)+'</span></li>';
  }});
  document.getElementById("tr-gaps").innerHTML=g;
}})();

/* ---------- boutons COPIER (page file:// = pas de script serveur) ---------- */
(function(){{
  var CMDS={{
    "1":"python TOOLS/AGENT_WORKFLOW/scripts/check_fb_cartouche_sync.py",
    "2":"python TOOLS/AGENT_WORKFLOW/scripts/extract_functions_matrix.py",
    "3":"python TOOLS/AGENT_WORKFLOW/scripts/generate_af_viewer.py"
  }};
  function copyText(txt){{
    try{{
      if(navigator.clipboard&&navigator.clipboard.writeText){{navigator.clipboard.writeText(txt);return;}}
    }}catch(e){{}}
    var ta=document.createElement("textarea");
    ta.value=txt; ta.style.position="fixed"; ta.style.opacity="0";
    document.body.appendChild(ta); ta.select();
    try{{document.execCommand("copy");}}catch(e){{}}
    document.body.removeChild(ta);
  }}
  function flash(btn){{
    var old=btn.textContent; btn.textContent="copie \\u2713";
    setTimeout(function(){{btn.textContent=old;}},1200);
  }}
  Array.prototype.forEach.call(document.querySelectorAll(".copybtn[data-copy]"),function(btn){{
    btn.addEventListener("click",function(){{copyText(CMDS[btn.getAttribute("data-copy")]||"");flash(btn);}});
  }});
  var all=document.getElementById("copy-all");
  if(all) all.addEventListener("click",function(){{
    copyText([CMDS["1"],CMDS["2"],CMDS["3"]].join("\\n"));flash(all);
  }});
}})();

document.getElementById("foot").innerHTML=
  "Sources : <span class=mono>af_traceability_matrix.yaml</span> + <span class=mono>fb_cartouche_sync.json</span>. "
  + "Genere par <span class=mono>generate_af_viewer.py</span> le "+esc(META.build_at)+" (HEAD "+esc(META.build_head)+"). "
  + "Donnees embarquees a la generation \u2014 pour rafraichir, relancer les 3 scripts. Aucune donnee n'est ecrite par cette page.";
</script>
</body>
</html>
"""


def main() -> int:
    if not MATRIX_PATH.is_file():
        print(f"introuvable : {MATRIX_PATH}", file=sys.stderr)
        return 1
    if not SYNC_PATH.is_file():
        print(f"introuvable : {SYNC_PATH} (lancer check_fb_cartouche_sync.py)", file=sys.stderr)
        return 1

    matrix = yaml.safe_load(MATRIX_PATH.read_text(encoding="utf-8")) or {}
    sync = json.loads(SYNC_PATH.read_text(encoding="utf-8"))

    fn_rows, tc_rows, dom_stats = _rows_from_matrix(matrix)
    trace = _traceability(matrix, REPO_ROOT)

    sync_counts = sync.get("counts") or {}
    for k in ("synced", "drift", "no_fiche", "no_pointer"):
        sync_counts.setdefault(k, 0)

    meta = {
        "matrix_fresh": _matrix_freshness(MATRIX_PATH),
        "sync_generated_at": sync.get("generated_at", ""),
        "sync_source_head": sync.get("source_head", ""),
        "sync_counts": sync_counts,
        "sync_total": sync.get("total", len(sync.get("fb", []))),
        "build_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "build_head": _git("rev-parse", "--short", "HEAD") or "unknown",
        "n_fonctions": len(fn_rows),
        "n_tc": len(tc_rows),
    }

    page = HTML_TEMPLATE.format(
        FN=_json_for_script(fn_rows),
        TC=_json_for_script(tc_rows),
        SY=_json_for_script(sync.get("fb", [])),
        DOM=_json_for_script(dom_stats),
        META=_json_for_script(meta),
        TR=_json_for_script(trace),
    )

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(page, encoding="utf-8")

    # garde-fou local : aucune primitive reseau / edition dans la page emise
    banned = ["fetch(", "XMLHttpRequest", "<form", "download=", "http://", "https://"]
    hits = [b for b in banned if b in page]
    print(f"AF_VIEWER genere -> {OUT_PATH.relative_to(REPO_ROOT).as_posix()}")
    print(f"  {len(fn_rows)} fonctions, {len(tc_rows)} TC, {len(sync.get('fb', []))} FB")
    tcn = trace["counts"]
    print(f"  tracabilite : {tcn['functions']} fonctions, {tcn['functions_with_ci_pass']} CI pass, "
          f"{tcn['functions_with_gap']} avec trou | "
          f"{len(trace['fn_no_tc'])} sans TC, {len(trace['tc_orphan'])} TC orphelins, "
          f"{len(trace['tc_no_ci'])} TC AUTO sans titre TEST")
    print(f"  matrice AF : {meta['matrix_fresh']}  |  sync : {meta['sync_generated_at']}  |  build HEAD {meta['build_head']}")
    if hits:
        print(f"  !! motifs interdits detectes : {hits}", file=sys.stderr)
        return 2
    print("  garde-fou hors-ligne : 0 fetch / XHR / form / download / URL externe")
    return 0


if __name__ == "__main__":
    sys.exit(main())
