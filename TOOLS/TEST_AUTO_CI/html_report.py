#!/usr/bin/env python3
"""Generation du rapport HTML autonome pour un run de test TEST_AUTO_CI, a partir du JSON
structure produit par test_runner.exe --json (cf. run_tests.py) et du fichier .st de test
source (pour extraire ce qui est concretement verifie -- les JSON de STruCpp ne donnent que
PASS/FAIL + 1re erreur, jamais la liste des ASSERT_* verifies)."""

import datetime as _dt
import html as _html
import pathlib
import re

TEST_BLOCK_RE = re.compile(r"TEST\s+'([^']*)'(.*?)END_TEST", re.DOTALL)
ASSERT_RE = re.compile(r"ASSERT_\w+\([^;]*?,\s*'([^']*)'\s*\)\s*;")
COMMENT_RE = re.compile(r"\(\*(.*?)\*\)", re.DOTALL)


def parse_test_checks(test_st_path) -> dict:
    """Extrait, par nom de TEST, la liste des messages ASSERT_* (= ce qui est verifie) et
    des commentaires narratifs (* ... *) du corps -- purement informatif, ne rejoue rien."""
    text = test_st_path.read_text(encoding="utf-8")
    out = {}
    for m in TEST_BLOCK_RE.finditer(text):
        name, body = m.group(1), m.group(2)
        checks = ASSERT_RE.findall(body)
        comments = [c.strip() for c in COMMENT_RE.findall(body) if c.strip()]
        out[name] = {"checks": checks, "comments": comments}
    return out


def _badge(passed: bool) -> str:
    cls = "pass" if passed else "fail"
    label = "PASS" if passed else "FAIL"
    return f'<span class="badge badge-{cls}">{label}</span>'


def _failure_block(failure: dict) -> str:
    if not failure:
        return ""
    parts = ["<div class='failure'>"]
    parts.append(f"<div class='failure-head'>{_html.escape(failure.get('assertType', ''))} — "
                 f"{_html.escape(failure.get('detail', ''))}</div>")
    parts.append(f"<div class='failure-loc'>{_html.escape(failure.get('file', ''))}:{failure.get('line', 0)}</div>")
    if failure.get("message"):
        parts.append(f"<div class='failure-msg'>{_html.escape(failure['message'])}</div>")
    if failure.get("expected") or failure.get("actual"):
        parts.append(
            f"<div class='failure-diff'>attendu <code>{_html.escape(failure.get('expected', ''))}</code>"
            f" · obtenu <code>{_html.escape(failure.get('actual', ''))}</code></div>"
        )
    parts.append("</div>")
    return "".join(parts)


def _fmt_val(v: str, is_bool: bool = True) -> str:
    """is_bool = vrai type declare (IEC_BOOL), jamais deduit des valeurs -- un WORD/INT qui
    vaut 0 ou 1 dans un test donne (ex: ErrorId bit0) reste affiche en chiffre, pas TRUE/FALSE."""
    if is_bool and v == "1":
        return '<span class="v-true">TRUE</span>'
    if is_bool and v == "0":
        return '<span class="v-false">FALSE</span>'
    return _html.escape(v)


def _split_static_fields(scans: list, field_names: list) -> tuple:
    """Separe les champs qui changent au moins une fois de ceux qui restent constants sur
    toute la sequence -- ces derniers n'apportent rien a une lecture temporelle."""
    changed, static = [], []
    for f in field_names:
        values = {s["fields"].get(f, "") for s in scans}
        (changed if len(values) > 1 else static).append(f)
    return changed, static


def _render_table(scans: list, field_names: list, field_types: dict, fail_scan_num=None) -> str:
    header = "".join(f"<th>{_html.escape(f)}</th>" for f in field_names)
    rows = []
    prev = None
    for s in scans:
        cells = []
        for f in field_names:
            v = s["fields"].get(f, "")
            changed = prev is not None and prev.get(f) != v
            cls = " class='changed'" if changed else ""
            cells.append(f"<td{cls}>{_fmt_val(v, field_types.get(f, True))}</td>")
        row_cls = " class='row-fail-scan'" if s["scan"] == fail_scan_num else ""
        marker = " ⚠️" if s["scan"] == fail_scan_num else ""
        rows.append(f"<tr{row_cls}><td class='scan-idx'>#{s['scan']}{marker}</td>"
                     f"<td class='scan-t'>{s['t_display_ms']:.0f} ms</td>{''.join(cells)}</tr>")
        prev = s["fields"]
    return f"""<div class="chrono-scroll"><table class="chrono-table">
        <thead><tr><th>Scan</th><th>Temps</th>{header}</tr></thead>
        <tbody>{"".join(rows)}</tbody>
    </table></div>"""


def _render_static_table(scans: list, field_names: list, field_types: dict) -> str:
    if not field_names:
        return ""
    rows = "".join(
        f"<tr><td><code>{_html.escape(f)}</code></td>"
        f"<td>{_fmt_val(scans[0]['fields'].get(f, ''), field_types.get(f, True))}</td></tr>"
        for f in field_names
    )
    return f"""
    <details class="chronogram-static">
        <summary>🔒 Valeurs constantes sur toute la séquence ({len(field_names)})</summary>
        <table class="static-table"><tbody>{rows}</tbody></table>
    </details>"""


def _render_waveform(scans: list, field_names: list, field_types: dict, fail_scan_num=None) -> str:
    """Chronogramme graphique SVG : 1 ligne par variable, temps en abscisse (par index de
    scan -- espacement uniforme pour rester lisible meme quand les t_ns reels sont tres
    inegaux -- le temps simule reel est annote sous chaque colonne). BOOL = creneau
    (analyseur logique) ; numerique = valeur affichee, ligne plate entre transitions.
    is_bool = vrai type IEC_BOOL declare (jamais deduit des valeurs observees)."""
    if not scans or not field_names:
        return ""
    col_w = 56
    left_margin = 200
    top_margin = 62
    lane_h = 40
    n = len(scans)
    width = left_margin + n * col_w + 20
    height = top_margin + len(field_names) * lane_h + 30

    def is_bool(f):
        return field_types.get(f, all(scans[i]["fields"].get(f) in ("0", "1") for i in range(n)))

    OTHER_PALETTE = ["#2563eb", "#059669", "#0891b2", "#65a30d", "#0d9488", "#1d4ed8"]
    RED_PALETTE = ["#dc2626", "#b91c1c", "#f43f5e", "#e11d48"]  # nuances distinctes -- plusieurs
    # signaux "erreur" proches (ERROR, DIAG.ERROR, REDUNDANCYTESTFAILED...) ne doivent PAS
    # partager exactement la meme couleur, sinon impossible de les distinguer piste a piste
    _other_colors: dict = {}
    _red_colors: dict = {}

    def wf_color(f: str) -> str:
        """Couleur semantique par type de signal -- RESET toujours noir, LOCKOUT toujours
        orange (fixes, reconnaissables d'un rapport a l'autre). Tout ce qui touche a un defaut
        (ERROR/FAILED/FAIL) reste dans la famille rouge mais avec une nuance differente par
        signal (sinon 2 pistes "erreur" adjacentes sont indiscernables a l'oeil). Le reste
        tourne dans une palette bleu/vert, assignee dans l'ordre d'apparition et stable pour
        tout le chronogramme (memes couleurs table/waveform)."""
        upper = f.upper()
        if "RESET" in upper:
            return "#111827"
        if "LOCKOUT" in upper:
            return "#ea580c"
        if "ERROR" in upper or "FAILED" in upper or upper.endswith("FAIL"):
            if f not in _red_colors:
                _red_colors[f] = RED_PALETTE[len(_red_colors) % len(RED_PALETTE)]
            return _red_colors[f]
        if f not in _other_colors:
            _other_colors[f] = OTHER_PALETTE[len(_other_colors) % len(OTHER_PALETTE)]
        return _other_colors[f]

    legend = [("#111827", "Reset"), ("#dc2626", "Erreur / défaut"), ("#ea580c", "Lockout"), ("#2563eb", "Autres (palette)")]
    svg_parts = [f'<svg width="{width}" height="{height}" viewBox="0 0 {width} {height}" '
                 f'xmlns="http://www.w3.org/2000/svg" class="waveform">']

    # legende couleurs
    lx = left_margin
    for color, label in legend:
        svg_parts.append(f'<circle cx="{lx}" cy="14" r="4" fill="{color}"/>')
        svg_parts.append(f'<text x="{lx + 8}" y="17" class="wf-legend">{_html.escape(label)}</text>')
        lx += 16 + len(label) * 6

    # grille verticale + labels temps/scan + bande rouge sur le scan ou l'assertion a echoue
    for i, s in enumerate(scans):
        x = left_margin + i * col_w
        if s["scan"] == fail_scan_num:
            svg_parts.append(f'<rect x="{x}" y="{top_margin - 6}" width="{col_w}" height="{height - 12 - top_margin}" class="wf-fail-band"/>')
            svg_parts.append(f'<text x="{x + col_w/2}" y="{top_margin - 28}" class="wf-fail-marker">⚠️ FAIL</text>')
        svg_parts.append(f'<line x1="{x}" y1="{top_margin - 6}" x2="{x}" y2="{height - 18}" class="wf-grid"/>')
        svg_parts.append(f'<text x="{x + col_w/2}" y="{top_margin - 10}" class="wf-time">{s["t_display_ms"]:.0f}ms</text>')
        svg_parts.append(f'<text x="{x + col_w/2}" y="{height - 6}" class="wf-scan">#{s["scan"]}</text>')

    for row, f in enumerate(field_names):
        y_lane = top_margin + row * lane_h
        y_mid = y_lane + lane_h / 2
        color = wf_color(f)
        svg_parts.append(f'<text x="{left_margin - 18}" y="{y_mid + 4}" class="wf-label">{_html.escape(f)}</text>')
        svg_parts.append(f'<circle cx="{left_margin - 8}" cy="{y_mid}" r="4" fill="{color}"/>')

        if is_bool(f):
            y_hi, y_lo = y_lane + 6, y_lane + lane_h - 8
            # echelle 0/1 sur la 1ere ligne uniquement (evite de repeter sur chaque piste)
            if row == 0:
                svg_parts.append(f'<text x="{left_margin - 6}" y="{y_hi + 3}" class="wf-scale">1</text>')
                svg_parts.append(f'<text x="{left_margin - 6}" y="{y_lo + 3}" class="wf-scale">0</text>')
            path = []
            prev_v = None
            for i, s in enumerate(scans):
                v = s["fields"].get(f)
                x0, x1 = left_margin + i * col_w, left_margin + (i + 1) * col_w
                y = y_hi if v == "1" else y_lo
                if prev_v is None:
                    path.append(f"M{x0},{y}")
                elif v != prev_v:
                    path.append(f"L{x0},{y_hi if prev_v == '1' else y_lo}L{x0},{y}")
                path.append(f"L{x1},{y}")
                prev_v = v
            svg_parts.append(f'<path d="{"".join(path)}" class="wf-line" stroke="{color}"/>')
        else:
            prev_v = None
            for i, s in enumerate(scans):
                v = s["fields"].get(f, "")
                x0, x1 = left_margin + i * col_w, left_margin + (i + 1) * col_w
                changed = prev_v is not None and v != prev_v
                svg_parts.append(f'<line x1="{x0}" y1="{y_mid}" x2="{x1}" y2="{y_mid}" class="wf-num-line"/>')
                if changed or prev_v is None:
                    cx, cy = (x0 + x1) / 2, y_mid - 6
                    chip_w = max(18, len(v) * 7)
                    svg_parts.append(
                        f'<rect x="{cx - chip_w/2}" y="{cy - 8}" width="{chip_w}" height="13" rx="3" '
                        f'fill="{color}" class="wf-chip"/>'
                    )
                    svg_parts.append(f'<text x="{cx}" y="{cy + 1}" class="wf-num-changed">{_html.escape(v)}</text>')
                else:
                    svg_parts.append(f'<text x="{(x0+x1)/2}" y="{y_mid - 6}" class="wf-num">{_html.escape(v)}</text>')
                prev_v = v

    svg_parts.append("</svg>")
    return "".join(svg_parts)


def _apply_realistic_time(scans: list, cycle_time_ms: float) -> list:
    """Le temps simule (__CURRENT_TIME_NS) ne bouge que si le test appelle ADVANCE_TIME
    explicitement -- plusieurs scans consecutifs peuvent donc afficher le meme 't_ns', ce qui
    est physiquement impossible sur l'automate (chaque scan prend au moins cycle_time_ms,
    parametre projet -- voir TEST_AUTO_CI/config.yaml, differe potentiellement d'un projet a
    l'autre). Filet de securite d'affichage : les .st de test devraient deja appeler
    ADVANCE_TIME(cycle_time_ms) entre chaque scan (convention -- voir README), ceci ne fait
    que corriger l'affichage si un test ne la respecte pas, sans jamais modifier le temps reel
    qui sert a evaluer les timers cote C++."""
    out = []
    prev_display = None
    for s in scans:
        real_ms = s["t_ns"] / 1e6
        display_ms = real_ms if prev_display is None else max(prev_display + cycle_time_ms, real_ms)
        out.append({**s, "t_display_ms": display_ms})
        prev_display = display_ms
    return out


def _render_chronogram(test_name: str, entries: list, cycle_time_ms: float, field_types: dict,
                        test_passed: bool = True) -> str:
    scans = [e for e in entries if e.get("test") == test_name]
    if not scans:
        return ""
    scans = _apply_realistic_time(scans, cycle_time_ms)
    all_fields = list(scans[0]["fields"].keys())
    changed_fields, static_fields = _split_static_fields(scans, all_fields)

    # Un ASSERT_* qui echoue interrompt immediatement l'execution du test (return false cote
    # C++) -- la trace s'arrete donc net, et le DERNIER scan capture est precisement celui ou
    # l'assertion a echoue. On le signale explicitement, sinon rien ne le distingue visuellement
    # d'un arret normal de fin de test.
    fail_note = ""
    fail_scan_num = None
    if not test_passed:
        fail_scan_num = scans[-1]["scan"]
        fail_note = (
            f'<div class="chrono-fail-note">⚠️ Trace interrompue au scan #{fail_scan_num} — '
            f"c'est le scan où l'assertion a échoué (le test s'arrête net, les scans suivants "
            f"n'existent pas).</div>"
        )

    return f"""
    <div class="chronogram-group">
        {fail_note}
        <details {"open" if not test_passed else ""}>
            <summary>📊 Chronogramme graphique ({len(scans)} scans, {len(changed_fields)} variables actives)</summary>
            <div class="wf-scroll">{_render_waveform(scans, changed_fields, field_types, fail_scan_num)}</div>
        </details>
        <details {"open" if not test_passed else ""}>
            <summary>📋 Chronogramme tableau ({len(scans)} scans)</summary>
            {_render_table(scans, changed_fields, field_types, fail_scan_num)}
        </details>
        {_render_static_table(scans, static_fields, field_types)}
    </div>"""


def render_html_report(fb_name: str, domain: str, test_file: str, sources: list,
                        json_data: dict, text_report: str, test_st_path=None,
                        trace_entries=None, source_paths=None, cycle_time_ms: float = 10,
                        field_types=None) -> str:
    field_types = field_types or {}
    summary = json_data.get("summary", {})
    results = json_data.get("results", [])
    total = summary.get("total", len(results))
    passed = summary.get("passed", sum(1 for r in results if r.get("passed")))
    failed = summary.get("failed", total - passed)
    all_pass = failed == 0
    exec_time = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    checks_by_test = parse_test_checks(test_st_path) if test_st_path else {}

    cards = []
    for r in results:
        name = r.get("name", "")
        passed_r = r.get("passed", False)
        info = checks_by_test.get(name, {"checks": [], "comments": []})

        checks_html = "".join(f"<li>{_html.escape(c)}</li>" for c in info["checks"])
        comments_html = "".join(f"<p class='comment'>{_html.escape(c)}</p>" for c in info["comments"])

        chrono_html = _render_chronogram(name, trace_entries or [], cycle_time_ms, field_types, passed_r)

        cards.append(f"""
        <article class="test-card test-card-{'pass' if passed_r else 'fail'}">
            <header>
                {_badge(passed_r)}
                <h3>{_html.escape(name)}</h3>
            </header>
            {f'<div class="comments">{comments_html}</div>' if comments_html else ''}
            {f'<div class="checks"><span class="checks-label">Vérifié ({len(info["checks"])})</span><ul>{checks_html}</ul></div>' if checks_html else ''}
            {_failure_block(r.get('failure'))}
            {chrono_html}
        </article>""")

    sources_list = "".join(f"<li><code>{_html.escape(s)}</code></li>" for s in sources)

    source_blocks = ""
    if source_paths:
        blocks = []
        for p in source_paths:
            try:
                content = pathlib.Path(p).read_text(encoding="utf-8")
            except OSError:
                continue
            blocks.append(f"""
            <details>
                <summary><code>{_html.escape(str(p))}</code></summary>
                <pre>{_html.escape(content)}</pre>
            </details>""")
        source_blocks = "".join(blocks)

    return f"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Rapport de test — {_html.escape(fb_name)} [{'PASS' if all_pass else 'FAIL'}]</title>
<style>
    :root {{
        --bg: #f8fafc; --surface: #ffffff; --border: #e2e8f0; --text: #1e293b; --muted: #64748b;
        --accent: #4f46e5; --green-bg: #ecfdf5; --green-text: #059669; --green-border: #a7f3d0;
        --red-bg: #fef2f2; --red-text: #dc2626; --red-border: #fecaca;
    }}
    * {{ box-sizing: border-box; }}
    body {{ font-family: -apple-system, "Segoe UI", Roboto, Arial, sans-serif; margin: 0;
        background: var(--bg); color: var(--text); line-height: 1.5; }}
    .page {{ max-width: 900px; margin: 0 auto; padding: 32px 24px 64px; }}
    .header {{ display: flex; justify-content: space-between; align-items: flex-start;
        margin-bottom: 6px; gap: 16px; }}
    h1 {{ font-size: 22px; margin: 0; font-weight: 600; }}
    .subtitle {{ color: var(--muted); font-size: 13px; margin: 4px 0 24px; }}
    .subtitle b {{ color: var(--text); font-weight: 600; }}
    .badge {{ display: inline-block; padding: 3px 10px; border-radius: 999px; font-weight: 600;
        font-size: 11px; letter-spacing: 0.3px; }}
    .badge-pass {{ background: var(--green-bg); color: var(--green-text); border: 1px solid var(--green-border); }}
    .badge-fail {{ background: var(--red-bg); color: var(--red-text); border: 1px solid var(--red-border); }}
    details {{ margin-bottom: 20px; }}
    summary {{ cursor: pointer; color: var(--muted); font-size: 12px; user-select: none; }}
    summary:hover {{ color: var(--text); }}
    ul {{ font-size: 12px; color: var(--muted); margin: 8px 0 0; padding-left: 18px; }}
    .test-card {{ background: var(--surface); border: 1px solid var(--border); border-radius: 10px;
        padding: 16px 18px; margin-bottom: 12px; }}
    .test-card-fail {{ border-color: var(--red-border); }}
    .test-card header {{ display: flex; align-items: center; gap: 10px; margin-bottom: 4px; }}
    .test-card h3 {{ font-size: 14px; margin: 0; font-weight: 600; }}
    .comment {{ font-size: 12.5px; color: var(--muted); margin: 6px 0; font-style: italic; }}
    .checks {{ margin-top: 8px; }}
    .checks-label {{ font-size: 10px; text-transform: uppercase; letter-spacing: 0.5px;
        color: var(--muted); font-weight: 600; }}
    .checks ul {{ list-style: none; padding-left: 0; margin-top: 6px; }}
    .checks li {{ font-size: 13px; color: var(--text); padding: 3px 0 3px 20px; position: relative; }}
    .checks li::before {{ content: "✓"; position: absolute; left: 0; color: var(--green-text); font-weight: bold; }}
    .failure {{ margin-top: 10px; padding: 10px 12px; background: var(--red-bg);
        border-left: 3px solid var(--red-text); border-radius: 4px; font-size: 12.5px; }}
    .failure-head {{ color: var(--red-text); font-weight: 600; }}
    .failure-loc {{ color: var(--muted); margin-top: 2px; font-size: 11px; }}
    .failure-msg {{ color: #92400e; margin-top: 4px; }}
    .failure-diff {{ margin-top: 4px; }}
    .failure-diff code {{ background: #ffffff; padding: 1px 5px; border-radius: 3px; border: 1px solid var(--border); }}
    pre {{ background: #0f172a; color: #cbd5e1; padding: 12px; border-radius: 8px; font-size: 11px;
        overflow-x: auto; }}
    .chronogram-group {{ margin-top: 12px; }}
    .chronogram-group details {{ margin-bottom: 8px; border: 1px solid var(--border); border-radius: 8px;
        padding: 8px 12px; }}
    .chronogram-group summary {{ font-size: 12px; font-weight: 600; color: var(--text); }}
    .chrono-scroll {{ overflow-x: auto; margin-top: 8px; }}
    .chrono-table {{ border-collapse: collapse; font-size: 11px; white-space: nowrap; }}
    .chrono-table th, .chrono-table td {{ padding: 4px 8px; border: 1px solid var(--border); text-align: center; }}
    .chrono-table th {{ background: #f1f5f9; color: var(--muted); font-weight: 600; position: sticky; top: 0; }}
    .chrono-table .scan-idx {{ color: var(--muted); font-weight: 600; }}
    .chrono-table .scan-t {{ color: var(--muted); }}
    .chrono-table td.changed {{ background: #fef9c3; }}
    .v-true {{ color: var(--green-text); font-weight: 600; }}
    .v-false {{ color: #cbd5e1; }}
    .wf-scroll {{ overflow-x: auto; background: var(--surface); border: 1px solid var(--border);
        border-radius: 8px; margin-top: 8px; padding: 4px 0; }}
    .waveform {{ display: block; }}
    .wf-grid {{ stroke: #f1f5f9; stroke-width: 1; }}
    .wf-time {{ font-size: 9px; fill: var(--muted); text-anchor: middle; }}
    .wf-scan {{ font-size: 9px; fill: #cbd5e1; text-anchor: middle; }}
    .wf-label {{ font-size: 11px; fill: var(--text); font-family: monospace; text-anchor: end; }}
    .wf-line {{ fill: none; stroke-width: 2; }}
    .wf-num-line {{ stroke: #e2e8f0; stroke-width: 1; }}
    .wf-num {{ font-size: 10px; fill: var(--muted); text-anchor: middle; }}
    .wf-num-changed {{ font-size: 10px; fill: #ffffff; font-weight: 700; text-anchor: middle; }}
    .wf-chip {{ opacity: 0.95; }}
    .wf-legend {{ font-size: 10px; fill: var(--muted); }}
    .wf-scale {{ font-size: 9px; fill: #cbd5e1; text-anchor: end; }}
    .chrono-fail-note {{ background: var(--red-bg); color: var(--red-text); border: 1px solid var(--red-border);
        border-radius: 6px; padding: 8px 12px; font-size: 12.5px; font-weight: 600; margin-bottom: 8px; }}
    .wf-fail-band {{ fill: #fecaca; opacity: 0.45; }}
    .wf-fail-marker {{ font-size: 11px; fill: #dc2626; font-weight: 700; text-anchor: middle; }}
    tr.row-fail-scan {{ background: var(--red-bg); outline: 2px solid var(--red-text); outline-offset: -2px; }}
    .chronogram-static {{ margin-top: 10px; }}
    .chronogram-static summary {{ font-size: 11px; }}
    .static-table {{ font-size: 12px; margin-top: 6px; border-collapse: collapse; }}
    .static-table td {{ padding: 3px 10px; border-bottom: 1px solid var(--border); }}
</style>
</head>
<body>
<div class="page">
    <div class="header">
        <h1>{_html.escape(fb_name)}</h1>
        {_badge(all_pass)}
    </div>
    <div class="subtitle">
        Domaine <b>{_html.escape(domain)}</b> · {passed}/{total} vérifications OK
        · <b>{exec_time}</b>
    </div>
    {"".join(cards)}
    <details>
        <summary>Fichiers source compilés ({len(sources)})</summary>
        <ul>{sources_list}</ul>
    </details>
    <details>
        <summary>Code source ST original ({len(source_paths or [])})</summary>
        {source_blocks}
    </details>
    <details>
        <summary>Sortie brute strucpp</summary>
        <pre>{_html.escape(text_report)}</pre>
    </details>
</div>
</body>
</html>
"""
