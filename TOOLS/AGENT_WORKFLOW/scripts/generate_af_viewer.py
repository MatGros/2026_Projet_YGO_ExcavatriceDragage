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

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
    except Exception:  # pragma: no cover
        pass

REPO_ROOT = Path(__file__).resolve().parents[3]
MATRIX_PATH = REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "config" / "af_traceability_matrix.yaml"
SYNC_PATH = REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "config" / "fb_cartouche_sync.json"
OUT_PATH = REPO_ROOT / "DOC" / "WFLOW" / "AF_VIEWER.html"


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
.bar .b-drift{{background:var(--warn)}}
.bar .b-no_fiche{{background:var(--info)}}
.bar .b-no_pointer{{background:var(--none)}}
.legend{{display:flex;gap:14px;flex-wrap:wrap;font-size:11px;color:var(--muted)}}
.legend i{{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:4px;vertical-align:middle}}
.domchips{{display:flex;flex-wrap:wrap;gap:6px;margin-top:8px}}
.chip{{background:var(--row-alt);border:1px solid var(--line);border-radius:12px;padding:2px 9px;font-size:11px;color:var(--muted)}}
.chip.zero{{opacity:.55}}
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
.p-drift{{background:var(--warn-bg);color:var(--warn)}}
.p-no_fiche{{background:var(--info-bg);color:var(--info)}}
.p-no_pointer{{background:var(--none-bg);color:var(--none)}}
.b-yes{{color:var(--ok);font-weight:700}} .b-no{{color:var(--red);font-weight:700}} .b-na{{color:var(--muted)}}
.small{{color:var(--muted);font-size:11px}}
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

<details class="sec"><summary>1 &middot; Fonctions par AF <span class="count" id="c-fn"></span></summary>
<div class="body">
<div class="controls"><input type="text" id="f-fn" placeholder="filtre texte (AF, fonction, FB, criticite\u2026)" autocomplete="off"></div>
<div class="tablewrap"><table id="t-fn"><thead><tr>
<th data-k="af">AF</th><th data-k="id">ID</th><th data-k="fonction">Fonction</th>
<th data-k="realisee_par">Realisee par</th><th data-k="criticite">Crit.</th>
<th data-k="tcs">TC couvrants</th><th data-k="etat">Etat</th>
</tr></thead><tbody></tbody></table></div>
</div></details>

<details class="sec"><summary>2 &middot; TC par AF <span class="count" id="c-tc"></span></summary>
<div class="body">
<div class="controls"><input type="text" id="f-tc" placeholder="filtre texte (AF, ID, intention, type\u2026)" autocomplete="off"></div>
<div class="tablewrap"><table id="t-tc"><thead><tr>
<th data-k="af">AF</th><th data-k="id">ID</th><th data-k="intention">Intention</th>
<th data-k="preuve">Preuve</th><th data-k="type">Type</th><th data-k="ref">Ref</th><th data-k="etat">Etat</th>
</tr></thead><tbody></tbody></table></div>
</div></details>

<details class="sec"><summary>3 &middot; Sync cartouches FB <span class="count" id="c-sy"></span></summary>
<div class="body">
<div class="controls"><input type="text" id="f-sy" placeholder="filtre texte (FB, statut, pointeur\u2026)" autocomplete="off"></div>
<div class="tablewrap"><table id="t-sy"><thead><tr>
<th data-k="pou_name">FB</th><th data-k="statut">Statut</th><th data-k="stref">.st:ligne</th>
<th data-k="role">Role (.st)</th><th data-k="docref">Pointeur doc:ligne</th>
<th data-k="nom_match">nom_match</th><th data-k="role_match">role_match</th>
</tr></thead><tbody></tbody></table></div>
</div></details>

<footer id="foot"></footer>

<script type="application/json" id="data-fn">{FN}</script>
<script type="application/json" id="data-tc">{TC}</script>
<script type="application/json" id="data-sy">{SY}</script>
<script type="application/json" id="data-dom">{DOM}</script>
<script type="application/json" id="data-meta">{META}</script>
<script>
"use strict";
function grab(id){{return JSON.parse(document.getElementById(id).textContent);}}
var FN=grab("data-fn"), TC=grab("data-tc"), SY=grab("data-sy"), DOM=grab("data-dom"), META=grab("data-meta");
function esc(s){{s=(s==null?"":String(s));return s.replace(/[&<>"]/g,function(c){{return {{"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}}[c];}});}}

/* ---------- bandeau stats ---------- */
(function(){{
  var c=META.sync_counts, tot=META.sync_total;
  var order=["synced","drift","no_fiche","no_pointer"];
  var seg=order.map(function(k){{
    var w=tot?(100*(c[k]||0)/tot):0;
    return '<span class="b-'+k+'" style="width:'+w.toFixed(2)+'%" title="'+k+' : '+(c[k]||0)+'"></span>';
  }}).join("");
  var afWith=DOM.filter(function(d){{return d.has_table_fonctions;}}).length;
  var chips=DOM.map(function(d){{
    var z=(d.n_fonctions===0&&d.n_tc===0)?" zero":"";
    return '<span class="chip'+z+'">'+esc(d.af)+' &middot; '+d.n_fonctions+' fn / '+d.n_tc+' TC</span>';
  }}).join("");
  var partial = afWith<DOM.length
    ? '<span class="warnbadge" title="AF sans section &laquo; Table des fonctions &raquo; : extraction fonctions partielle">extraction partielle : '+afWith+'/'+DOM.length+' AF</span>'
    : '';
  document.getElementById("stats").innerHTML =
    '<div class="statgrid">'
    + '<div class="stat"><div class="n">'+FN.length+'</div><div class="l">fonctions AF</div></div>'
    + '<div class="stat"><div class="n">'+TC.length+'</div><div class="l">TC AF</div></div>'
    + '<div class="stat"><div class="n">'+(c.synced||0)+'</div><div class="l">&#9989; synced</div></div>'
    + '<div class="stat"><div class="n">'+(c.drift||0)+'</div><div class="l">&#9888; drift</div></div>'
    + '<div class="stat"><div class="n">'+(c.no_fiche||0)+'</div><div class="l">&#128309; no_fiche</div></div>'
    + '<div class="stat"><div class="n">'+(c.no_pointer||0)+'</div><div class="l">&#9898; no_pointer</div></div>'
    + '<div class="stat"><div class="n">'+afWith+'/'+DOM.length+'</div><div class="l">AF avec table fn</div></div>'
    + '</div>'
    + '<div class="bar">'+seg+'</div>'
    + '<div class="legend">'
    + '<span><i style="background:var(--ok)"></i>synced</span>'
    + '<span><i style="background:var(--warn)"></i>drift</span>'
    + '<span><i style="background:var(--info)"></i>no_fiche</span>'
    + '<span><i style="background:var(--none)"></i>no_pointer</span>'
    + '&nbsp;&nbsp;'+partial
    + '</div>'
    + '<div class="domchips">'+chips+'</div>';
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
function makeTable(tblId, filtId, cntId, rows, cols, defSort){{
  var tbl=document.getElementById(tblId), tb=tbl.tBodies[0];
  var state={{key:defSort?defSort.key:cols[0].k, dir:defSort?defSort.dir:1}};
  function cellVal(r,k){{
    if(k==="tcs") return (r.tc||[]).join(" ");
    if(k==="stref") return (r.file||r.pou_name||"")+":"+(r.st_line||0)+" "+(r.pou_name||"");
    if(k==="docref") return (r.doc_pointer||"")+":"+(r.doc_line||0);
    return r[k];
  }}
  function render(){{
    var q=document.getElementById(filtId).value.toLowerCase().trim();
    var list=rows.filter(function(r){{
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
  render();
}}

makeTable("t-fn","f-fn","c-fn",FN,[
  {{k:"af",fmt:function(r){{return esc(r.af);}}}},
  {{k:"id",cls:"mono",fmt:function(r){{return esc(r.id);}}}},
  {{k:"fonction",fmt:function(r){{return esc(r.fonction)+(r.description?'<div class="small">'+esc(r.description)+"</div>":"");}}}},
  {{k:"realisee_par",fmt:function(r){{return esc(r.realisee_par);}}}},
  {{k:"criticite",fmt:function(r){{return esc(r.criticite);}}}},
  {{k:"tcs",cls:"mono",fmt:function(r){{return esc((r.tc||[]).join(", "));}}}},
  {{k:"etat",fmt:function(r){{return esc(r.etat);}}}}
]);

makeTable("t-tc","f-tc","c-tc",TC,[
  {{k:"af",fmt:function(r){{return esc(r.af);}}}},
  {{k:"id",cls:"mono",fmt:function(r){{return esc(r.id);}}}},
  {{k:"intention",fmt:function(r){{return esc(r.intention);}}}},
  {{k:"preuve",fmt:function(r){{return esc(r.preuve);}}}},
  {{k:"type",fmt:function(r){{return esc(r.type);}}}},
  {{k:"ref",cls:"mono",fmt:function(r){{return esc(r.ref);}}}},
  {{k:"etat",fmt:function(r){{return esc(r.etat);}}}}
]);

var RANK={{drift:0,no_fiche:1,no_pointer:2,synced:3}};
SY.forEach(function(r){{r._rank=RANK[r.statut]==null?9:RANK[r.statut];}});
makeTable("t-sy","f-sy","c-sy",SY,[
  {{k:"pou_name",cls:"mono",fmt:function(r){{return (r.emoji?esc(r.emoji)+" ":"")+esc(r.pou_name);}}}},
  {{k:"statut",fmt:function(r){{return '<span class="pill p-'+r.statut+'">'+esc(r.statut)+"</span>";}}}},
  {{k:"stref",cls:"mono",fmt:function(r){{return esc(r.file)+":"+(r.st_line||0);}}}},
  {{k:"role",fmt:function(r){{return r.role?esc(r.role):'<span class="small">(pas de ligne Role)</span>';}}}},
  {{k:"docref",cls:"mono",fmt:function(r){{return r.doc_pointer?esc(r.doc_pointer)+":"+(r.doc_line||0):'<span class="small">\u2014</span>';}}}},
  {{k:"nom_match",cls:"",fmt:function(r){{return r.nom_match==null?'<span class="b-na">n/a</span>':(r.nom_match?'<span class="b-yes">oui</span>':'<span class="b-no">non</span>');}}}},
  {{k:"role_match",fmt:function(r){{return r.role_match==null?'<span class="b-na">n/a</span>':(r.role_match?'<span class="b-yes">oui</span>':'<span class="b-no">non</span>');}}}}
],{{key:"_rank",dir:1}});

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
    )

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(page, encoding="utf-8")

    # garde-fou local : aucune primitive reseau / edition dans la page emise
    banned = ["fetch(", "XMLHttpRequest", "<form", "download=", "http://", "https://"]
    hits = [b for b in banned if b in page]
    print(f"AF_VIEWER genere -> {OUT_PATH.relative_to(REPO_ROOT).as_posix()}")
    print(f"  {len(fn_rows)} fonctions, {len(tc_rows)} TC, {len(sync.get('fb', []))} FB")
    print(f"  matrice AF : {meta['matrix_fresh']}  |  sync : {meta['sync_generated_at']}  |  build HEAD {meta['build_head']}")
    if hits:
        print(f"  !! motifs interdits detectes : {hits}", file=sys.stderr)
        return 2
    print("  garde-fou hors-ligne : 0 fetch / XHR / form / download / URL externe")
    return 0


if __name__ == "__main__":
    sys.exit(main())
