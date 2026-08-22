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


def _badge(passed: bool, strong: bool = False) -> str:
    cls = "pass" if passed else "fail"
    label = "PASS" if passed else "FAIL"
    extra = " badge-strong" if strong else ""
    return f'<span class="badge badge-{cls}{extra}">{label}</span>'


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

    # Test a scan unique (souvent un test d'etat fige, pas une sequence temporelle) : la
    # detection de changement compare 2 scans consecutifs, donc TOUJOURS 0 variable "active"
    # ici par construction -- afficher un graphique/tableau vides serait trompeur. On montre
    # directement les valeurs plutot que 2 panneaux vides.
    if len(scans) == 1:
        single_rows = "".join(
            f"<tr><td><code>{_html.escape(f)}</code></td>"
            f"<td>{_fmt_val(scans[0]['fields'].get(f, ''), field_types.get(f, True))}</td></tr>"
            for f in all_fields
        )
        return f"""
    <div class="chronogram-group">
        {fail_note}
        <p class="chrono-single-scan-note">ℹ️ Test à scan unique (état figé) — rien à observer dans le temps.</p>
        <details class="chronogram-static">
            <summary>🔒 Valeurs du scan unique ({len(all_fields)})</summary>
            <table class="static-table"><tbody>{single_rows}</tbody></table>
        </details>
    </div>"""

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


def _render_fb_section(fb_name: str, domain: str, sources: list,
                        json_data: dict, text_report: str = "", test_st_path=None,
                        trace_entries=None, source_paths=None, cycle_time_ms: float = 10,
                        field_types=None, af_warnings=None, extra_test_warnings=None,
                        wiring=None, encapsulation_report=None) -> dict:
    """Construit le contenu d'un FB (sous-titre + warning AF + cartes de test + details
    sources) SANS l'enveloppe de page complete -- reutilise a l'identique par un rapport
    mono-FB (render_html_report) et un rapport groupe multi-FB (render_group_report)."""
    field_types = field_types or {}
    af_warnings = af_warnings or []
    extra_test_warnings = extra_test_warnings or []
    encapsulation_report = encapsulation_report or []
    summary = json_data.get("summary", {})
    results = json_data.get("results", [])
    total = summary.get("total", len(results))
    passed = summary.get("passed", sum(1 for r in results if r.get("passed")))
    failed = summary.get("failed", total - passed)
    all_pass = failed == 0

    checks_by_test = parse_test_checks(test_st_path) if test_st_path else {}

    fb_slug = re.sub(r"[^a-zA-Z0-9]+", "-", fb_name).strip("-").lower()
    cards = []
    toc_entries = []
    for i, r in enumerate(results):
        name = r.get("name", "")
        passed_r = r.get("passed", False)
        info = checks_by_test.get(name, {"checks": [], "comments": []})

        checks_html = "".join(f"<li>{_html.escape(c)}</li>" for c in info["checks"])
        comments_html = "".join(f"<p class='comment'>{_html.escape(c)}</p>" for c in info["comments"])

        chrono_html = _render_chronogram(name, trace_entries or [], cycle_time_ms, field_types, passed_r)

        anchor = f"test-{fb_slug}-{i}"
        toc_entries.append((anchor, name, passed_r))

        cards.append(f"""
        <article id="{anchor}" class="test-card test-card-{'pass' if passed_r else 'fail'}">
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

    af_warning_html = ""
    if af_warnings:
        items = "".join(
            f"<li><code>{_html.escape(tc_id)}</code> — {_html.escape(intention)}</li>"
            for tc_id, intention in af_warnings
        )
        af_warning_html += f"""
    <div class="af-warning-banner">
        <div class="af-warning-title">⚠️ {len(af_warnings)} test(s) attendu(s) par l'AF (type AUTO) mais absent(s) de ce fichier de test</div>
        <ul>{items}</ul>
    </div>"""
    if extra_test_warnings:
        items2 = "".join(f"<li><code>{_html.escape(tc_id)}</code></li>" for tc_id in extra_test_warnings)
        af_warning_html += f"""
    <div class="af-warning-banner">
        <div class="af-warning-title">⚠️ {len(extra_test_warnings)} test(s) present(s) dans ce fichier mais absent(s) du catalogue AF (ID inconnu ou retire)</div>
        <ul>{items2}</ul>
    </div>"""
    encapsulation_html = ""
    if encapsulation_report:
        n_violations = sum(1 for e in encapsulation_report if e["has_violation"])
        rows_html = []
        for e in encapsulation_report:
            ok = not e["has_violation"]
            detail = "".join(
                f"<li>ecriture externe non declaree : <code>{_html.escape(w)}</code></li>"
                for w in e.get("external_writes", [])
            ) + "".join(
                f"<li>acces GVL direct (bypass interface) : <code>{_html.escape(g)}</code></li>"
                for g in e.get("gvl_refs", [])
            )
            rows_html.append(f"""
            <tr class="encaps-row-{'pass' if ok else 'fail'}">
                <td>{_badge(ok)}</td>
                <td><code>{_html.escape(e['fb_name'])}</code></td>
                <td>{e['n_input']}</td><td>{e['n_output']}</td>
                <td>{e['n_inout']}</td><td>{e['n_local']}</td>
                <td>{f"<ul>{detail}</ul>" if detail else "—"}</td>
            </tr>""")
        summary_txt = (f"⚠️ {n_violations} violation(s) sur {len(encapsulation_report)} FB de la chaine"
                        if n_violations else
                        f"✅ {len(encapsulation_report)} FB de la chaine, encapsulation propre (0 violation)")
        encapsulation_html = f"""
    <details class="encaps-details" {"open" if n_violations else ""}>
        <summary>🔒 Encapsulation (interface FB) — {summary_txt}</summary>
        <table class="encaps-table">
            <thead><tr><th></th><th>FB</th><th>IN</th><th>OUT</th><th>IN_OUT</th><th>LOCAL</th><th>Detail</th></tr></thead>
            <tbody>{"".join(rows_html)}</tbody>
        </table>
    </details>"""

    pin_diagram_html = _render_pin_diagram(fb_name, wiring)

    body_html = f"""
    <div class="subtitle">
        Domaine <b>{_html.escape(domain)}</b> · {passed}/{total} vérifications OK
    </div>
    {af_warning_html}
    {pin_diagram_html}
    {encapsulation_html}
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
    </details>"""

    return {
        "fb_name": fb_name, "domain": domain, "all_pass": all_pass,
        "passed": passed, "total": total, "body_html": body_html,
        "toc_entries": toc_entries,
    }


_CSS = """
    :root {
        --bg: #f8fafc; --surface: #ffffff; --border: #e2e8f0; --text: #1e293b; --muted: #64748b;
        --accent: #4f46e5; --green-bg: #ecfdf5; --green-text: #059669; --green-border: #a7f3d0;
        --red-bg: #fef2f2; --red-text: #dc2626; --red-border: #fecaca;
        --warn-bg: #fffbeb; --warn-text: #b45309; --warn-border: #fde68a;
    }
    * { box-sizing: border-box; }
    body { font-family: -apple-system, "Segoe UI", Roboto, Arial, sans-serif; margin: 0;
        background: var(--bg); color: var(--text); line-height: 1.5; }
    .page { max-width: 1400px; margin: 0 auto; padding: 32px 24px 64px; }
    .header { display: flex; justify-content: flex-start; align-items: center;
        margin-bottom: 6px; gap: 14px; background: var(--surface); border: 1px solid var(--border);
        border-radius: 10px; padding: 16px 18px; }
    h1 { font-size: 22px; margin: 0; font-weight: 600; }
    .header .badge, .fb-section-title .badge { font-size: 14px; padding: 5px 14px; }
    .subtitle { color: var(--muted); font-size: 13px; margin: 4px 0 24px; }
    .subtitle b { color: var(--text); font-weight: 600; }
    .badge { display: inline-block; padding: 3px 10px; border-radius: 999px; font-weight: 600;
        font-size: 11px; letter-spacing: 0.3px; }
    .badge-pass { background: var(--green-bg); color: var(--green-text); border: 1px solid var(--green-border); }
    .badge-fail { background: var(--red-bg); color: var(--red-text); border: 1px solid var(--red-border); }
    /* Sur fond de page pastel (meme teinte que badge-pass/fail), le badge se fondrait --
       variante foncee/opaque pour les badges de titre (header, sommaire FB) qui ressortent. */
    .badge-pass.badge-strong { background: var(--green-text); color: #ffffff; border-color: var(--green-text); }
    .badge-fail.badge-strong { background: var(--red-text); color: #ffffff; border-color: var(--red-text); }
    details { margin-bottom: 20px; }
    summary { cursor: pointer; color: var(--muted); font-size: 12px; user-select: none; }
    summary:hover { color: var(--text); }
    ul { font-size: 12px; color: var(--muted); margin: 8px 0 0; padding-left: 18px; }
    .test-card { background: var(--surface); border: 1px solid var(--border); border-radius: 10px;
        padding: 16px 18px; margin-bottom: 12px; }
    .test-card-fail { border-color: var(--red-border); }
    .test-card header { display: flex; align-items: center; gap: 10px; margin-bottom: 4px; }
    .test-card h3 { font-size: 14px; margin: 0; font-weight: 600; }
    .comment { font-size: 12.5px; color: var(--muted); margin: 6px 0; font-style: italic; }
    .checks { margin-top: 8px; }
    .checks-label { font-size: 10px; text-transform: uppercase; letter-spacing: 0.5px;
        color: var(--muted); font-weight: 600; }
    .checks ul { list-style: none; padding-left: 0; margin-top: 6px; }
    .checks li { font-size: 13px; color: var(--text); padding: 3px 0 3px 20px; position: relative; }
    .checks li::before { content: "✓"; position: absolute; left: 0; color: var(--green-text); font-weight: bold; }
    .failure { margin-top: 10px; padding: 10px 12px; background: var(--red-bg);
        border-left: 3px solid var(--red-text); border-radius: 4px; font-size: 12.5px; }
    .failure-head { color: var(--red-text); font-weight: 600; }
    .failure-loc { color: var(--muted); margin-top: 2px; font-size: 11px; }
    .failure-msg { color: #92400e; margin-top: 4px; }
    .failure-diff { margin-top: 4px; }
    .failure-diff code { background: #ffffff; padding: 1px 5px; border-radius: 3px; border: 1px solid var(--border); }
    pre { background: #0f172a; color: #cbd5e1; padding: 12px; border-radius: 8px; font-size: 11px;
        overflow-x: auto; }
    .chronogram-group { margin-top: 12px; }
    .chronogram-group details { margin-bottom: 8px; border: 1px solid var(--border); border-radius: 8px;
        padding: 8px 12px; }
    .chronogram-group summary { font-size: 12px; font-weight: 600; color: var(--text); }
    .chrono-scroll { overflow-x: auto; margin-top: 8px; }
    .chrono-table { border-collapse: collapse; font-size: 11px; white-space: nowrap; }
    .chrono-table th, .chrono-table td { padding: 4px 8px; border: 1px solid var(--border); text-align: center; }
    .chrono-table th { background: #f1f5f9; color: var(--muted); font-weight: 600; position: sticky; top: 0; }
    .chrono-table .scan-idx { color: var(--muted); font-weight: 600; }
    .chrono-table .scan-t { color: var(--muted); }
    .chrono-table td.changed { background: #fef9c3; }
    .v-true { color: var(--green-text); font-weight: 600; }
    .v-false { color: #cbd5e1; }
    .wf-scroll { overflow-x: auto; background: var(--surface); border: 1px solid var(--border);
        border-radius: 8px; margin-top: 8px; padding: 4px 0; }
    .waveform { display: block; }
    .wf-grid { stroke: #f1f5f9; stroke-width: 1; }
    .wf-time { font-size: 9px; fill: var(--muted); text-anchor: middle; }
    .wf-scan { font-size: 9px; fill: #cbd5e1; text-anchor: middle; }
    .wf-label { font-size: 11px; fill: var(--text); font-family: monospace; text-anchor: end; }
    .wf-line { fill: none; stroke-width: 2; }
    .wf-num-line { stroke: #e2e8f0; stroke-width: 1; }
    .wf-num { font-size: 10px; fill: var(--muted); text-anchor: middle; }
    .wf-num-changed { font-size: 10px; fill: #ffffff; font-weight: 700; text-anchor: middle; }
    .wf-chip { opacity: 0.95; }
    .wf-legend { font-size: 10px; fill: var(--muted); }
    .wf-scale { font-size: 9px; fill: #cbd5e1; text-anchor: end; }
    .af-warning-banner { background: var(--warn-bg); color: var(--warn-text); border: 1px solid var(--warn-border);
        border-radius: 8px; padding: 12px 16px; margin: 14px 0; font-size: 13px; }
    .af-warning-banner .af-warning-title { font-weight: 600; margin-bottom: 6px; }
    .af-warning-banner ul { margin: 0; padding-left: 20px; }
    .af-warning-banner li { margin: 3px 0; }
    .encaps-details { background: var(--surface); border: 1px solid var(--border); border-radius: 10px;
        padding: 10px 16px; margin: 14px 0; }
    .encaps-details summary { font-weight: 600; color: var(--text); font-size: 13px; cursor: pointer; }
    .encaps-table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 12.5px; }
    .encaps-table th { text-align: left; padding: 4px 8px; color: var(--muted); font-weight: 600; }
    .encaps-table td { padding: 4px 8px; border-top: 1px solid var(--border); }
    .encaps-table tr.encaps-row-fail { background: var(--red-bg); }
    .encaps-table ul { margin: 0; padding-left: 16px; }
    .chrono-fail-note { background: var(--red-bg); color: var(--red-text); border: 1px solid var(--red-border);
        border-radius: 6px; padding: 8px 12px; font-size: 12.5px; font-weight: 600; margin-bottom: 8px; }
    .wf-fail-band { fill: #fecaca; opacity: 0.45; }
    .wf-fail-marker { font-size: 11px; fill: #dc2626; font-weight: 700; text-anchor: middle; }
    tr.row-fail-scan { background: var(--red-bg); outline: 2px solid var(--red-text); outline-offset: -2px; }
    .chronogram-static { margin-top: 10px; }
    .chronogram-static summary { font-size: 11px; }
    .chrono-single-scan-note { font-size: 12px; color: var(--muted); font-style: italic; margin: 8px 0 4px; }
    .static-table { font-size: 12px; margin-top: 6px; border-collapse: collapse; }
    .static-table td { padding: 3px 10px; border-bottom: 1px solid var(--border); }
    .exec-time { color: var(--muted); font-size: 12px; margin: 0 0 20px; }
    .pin-diagram-details { background: var(--surface); border: 1px solid var(--border); border-radius: 10px;
        padding: 12px 16px; margin-bottom: 16px; }
    .pin-diagram-details summary { font-weight: 600; color: var(--text); font-size: 13px; }
    .pin-diagram { display: flex; align-items: stretch; gap: 0; margin-top: 12px; font-size: 12px; }
    .pin-col { flex: 1; display: flex; flex-direction: column; justify-content: center; gap: 1px; min-width: 0; }
    .pin-block { flex: 0 0 140px; background: #eef2ff; border: 2px solid var(--accent); border-radius: 6px;
        display: flex; align-items: center; justify-content: center; text-align: center; font-weight: 700;
        font-size: 12px; margin: 0 10px; padding: 8px; align-self: stretch; color: var(--accent); }
    .pin-row { display: flex; align-items: baseline; gap: 8px; padding: 4px 0; border-bottom: 2px dashed #94a3b8;
        min-width: 0; }
    /* Entrees : texte colle au bloc -> justifie a droite (flux entrant vers le bloc) */
    .pin-col-in .pin-row { justify-content: flex-end; text-align: right; }
    /* Sorties : texte colle au bloc -> justifie a gauche (flux sortant du bloc) */
    .pin-col-out .pin-row { justify-content: flex-start; text-align: left; }
    .pin-name { font-family: monospace; font-weight: 600; white-space: nowrap; color: var(--text); }
    .pin-type { color: var(--muted); font-weight: 400; font-size: 10px; }
    .pin-tag { font-size: 9px; background: #ddd6fe; color: #5b21b6; border-radius: 4px; padding: 1px 4px; margin-left: 4px; }
    .pin-expr { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; min-width: 0; }
    .pin-expr code { background: #f1f5f9; padding: 1px 5px; border-radius: 3px; font-size: 11px;
        cursor: pointer; }
    .pin-expr code:hover { background: #e2e8f0; }
    .pin-expr code.pin-copied { background: var(--green-bg); color: var(--green-text); }
    .pin-missing { color: #b45309; font-style: italic; font-size: 11px; }
    .pin-more { color: var(--muted); font-size: 10px; }
    .pin-row-unwired { background: #fffbeb; }
    .fb-section-title { display: flex; align-items: center; gap: 10px; font-size: 17px;
        font-weight: 600; margin: 30px 0 10px; padding: 12px 18px; background: var(--surface);
        border: 1px solid var(--border); border-radius: 10px; }
    .fb-section-title:first-of-type { margin-top: 6px; }
    .toc-details { background: var(--surface); border: 1px solid var(--border); border-radius: 10px;
        padding: 12px 18px; margin-bottom: 16px; }
    .toc-details summary { font-weight: 600; color: var(--text); font-size: 13px; }
    .toc-group-title { font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px;
        color: var(--muted); font-weight: 600; margin: 12px 0 4px; }
    .toc-group-title:first-of-type { margin-top: 10px; }
    .toc-list { list-style: none; margin: 0; padding: 0; columns: 2; column-gap: 24px; }
    .toc-item { font-size: 12.5px; padding: 2px 0; break-inside: avoid; }
    .toc-item a { text-decoration: none; color: var(--text); }
    .toc-item a:hover { text-decoration: underline; }
    .toc-item::before { content: "●"; font-size: 8px; margin-right: 6px; }
    .toc-pass::before { color: var(--green-text); }
    .toc-fail::before { color: var(--red-text); }
    .toc-fail a { color: var(--red-text); font-weight: 600; }
"""


_COPY_JS = """
function copyPinExpr(el) {
    var text = el.getAttribute('title') || el.textContent;
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch (e) {}
    document.body.removeChild(ta);
    el.classList.add('pin-copied');
    setTimeout(function () { el.classList.remove('pin-copied'); }, 500);
}
"""


def _page_shell(title: str, inner_html: str, all_pass: bool = True) -> str:
    """Enveloppe de page commune (mono-FB ou groupe) -- CSS partage via _CSS. Fond de page
    pastel (vert/rouge tres attenue) selon le verdict global -- repere visuel immediat sans
    avoir a lire le badge, sans etre agressif (mêmes tons --green-bg/--red-bg que les badges)."""
    bg = "#ecfdf5" if all_pass else "#fef2f2"
    return f"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>{_html.escape(title)}</title>
<style>{_CSS}
    body {{ background: {bg}; }}
</style>
</head>
<body>
<div class="page">
{inner_html}
</div>
<script>{_COPY_JS}</script>
</body>
</html>
"""


def _render_pin_diagram(fb_name: str, wiring: dict | None) -> str:
    """Bloc pinout FBD-like : pins IN/IN_OUT a gauche, OUT a droite, autour d'un rectangle
    central portant le nom du FB. L'interface (liste/type/ordre des pins) vient exclusivement
    du compilateur (generated.hpp, via prod_wiring.extract_pins) -- jamais du .st. Le cablage
    affiche a cote de chaque pin (expression reelle en production) vient du point
    d'instanciation .st -- seule source qui la connaisse. Non bloquant : degrade en pinout nu
    si aucun cablage de production n'est configure/trouve."""
    if not wiring or not any(wiring.get("pins", {}).values()):
        return ""

    pins = wiring["pins"]
    call_args = wiring.get("call_args", {})
    output_usages = wiring.get("output_usages", {})
    unwired_inputs = set(wiring.get("unwired_inputs", []))
    unwired_outputs = set(wiring.get("unwired_outputs", []))
    orphan_args = wiring.get("orphan_args", [])

    def _in_row(name: str, ftype: str, tag: str = "") -> str:
        key = name.upper()
        wired = call_args.get(key)
        cls = "pin-row-unwired" if key in unwired_inputs else "pin-row-wired"
        expr_html = (f'<code title="{_html.escape(wired)}" onclick="copyPinExpr(this)">{_html.escape(wired)}</code>'
                     if wired else "<span class='pin-missing'>⚠ non câblé en production</span>")
        tag_html = f"<span class='pin-tag'>{tag}</span>" if tag else ""
        # Nom du pin en dernier -> reste colle au bloc (colonne IN justifiee a droite)
        return f"""<div class="pin-row {cls}">
            <div class="pin-expr">{expr_html}</div>
            <div class="pin-name">{_html.escape(name)}{tag_html} <span class="pin-type">{_html.escape(ftype)}</span></div>
        </div>"""

    def _out_row(name: str, ftype: str) -> str:
        key = name.upper()
        usages = output_usages.get(key)
        cls = "pin-row-unwired" if key in unwired_outputs else "pin-row-wired"
        if usages:
            file_label, ctx = usages[0]
            first = _html.escape(f"{file_label}: {ctx}" if file_label else ctx)
            more = f" <span class='pin-more'>(+{len(usages) - 1})</span>" if len(usages) > 1 else ""
            expr_html = f'<code title="{first}" onclick="copyPinExpr(this)">{first}</code>{more}'
        else:
            expr_html = "<span class='pin-missing'>⚠ jamais lu en production</span>"
        # Nom du pin en premier -> reste colle au bloc (colonne OUT justifiee a gauche)
        return f"""<div class="pin-row {cls} pin-row-out">
            <div class="pin-name">{_html.escape(name)} <span class="pin-type">{_html.escape(ftype)}</span></div>
            <div class="pin-expr">{expr_html}</div>
        </div>"""

    left_html = "".join(_in_row(n, t) for n, t in pins["inputs"])
    left_html += "".join(_in_row(n, t, tag="IN_OUT") for n, t in pins["in_out"])
    right_html = "".join(_out_row(n, t) for n, t in pins["outputs"])

    warnings_html = ""
    n_warn = len(unwired_inputs) + len(unwired_outputs) + len(orphan_args)
    if n_warn:
        items = "".join(f"<li>Pin <code>{_html.escape(p)}</code> jamais câblé en production</li>" for p in sorted(unwired_inputs | unwired_outputs))
        items += "".join(f"<li>Argument <code>{_html.escape(p)}</code> câblé en production mais absent de l'interface (interface modifiée ?)</li>" for p in orphan_args)
        warnings_html = f"""<div class="af-warning-banner">
            <div class="af-warning-title">⚠️ {n_warn} écart(s) interface ↔ câblage production</div>
            <ul>{items}</ul>
        </div>"""

    return f"""
    <details class="pin-diagram-details">
        <summary>🔌 Interface & câblage production</summary>
        {warnings_html}
        <div class="pin-diagram">
            <div class="pin-col pin-col-in">{left_html}</div>
            <div class="pin-block">{_html.escape(fb_name)}</div>
            <div class="pin-col pin-col-out">{right_html}</div>
        </div>
    </details>"""


def _render_toc(groups: list) -> str:
    """Sommaire cliquable en haut de page -- groups : [(titre_ou_None, [(anchor,name,passed),...]), ...].
    titre_ou_None : None pour un rapport mono-FB (pas de sous-titre repete), sinon le nom du FB
    (rapport groupe, un sous-titre par FB)."""
    total = sum(len(entries) for _title, entries in groups)
    if total == 0:
        return ""
    parts = []
    for title, entries in groups:
        if title:
            parts.append(f'<div class="toc-group-title">{_html.escape(title)}</div>')
        items = "".join(
            f'<li class="toc-item toc-{"pass" if passed else "fail"}">'
            f'<a href="#{anchor}">{_html.escape(name)}</a></li>'
            for anchor, name, passed in entries
        )
        parts.append(f"<ul class='toc-list'>{items}</ul>")
    return f"""
    <details class="toc-details" open>
        <summary>📋 Sommaire ({total} test{'s' if total > 1 else ''})</summary>
        {"".join(parts)}
    </details>"""


def render_html_report(fb_name: str, domain: str, test_file: str, sources: list,
                        json_data: dict, text_report: str, test_st_path=None,
                        trace_entries=None, source_paths=None, cycle_time_ms: float = 10,
                        field_types=None, af_warnings=None, extra_test_warnings=None,
                        wiring=None, encapsulation_report=None) -> str:
    """Rapport HTML autonome pour UN SEUL FB."""
    section = _render_fb_section(fb_name, domain, sources, json_data, text_report, test_st_path,
                                  trace_entries, source_paths, cycle_time_ms, field_types,
                                  af_warnings, extra_test_warnings, wiring, encapsulation_report)
    exec_time = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    toc_html = _render_toc([(None, section["toc_entries"])])
    inner = f"""
    <div class="header">
        <h1>{_html.escape(fb_name)}</h1>
        {_badge(section['all_pass'])}
    </div>
    <div class="exec-time">{exec_time}</div>
    {toc_html}
    {section['body_html']}"""
    title = f"Rapport de test — {fb_name} [{'PASS' if section['all_pass'] else 'FAIL'}]"
    return _page_shell(title, inner, all_pass=section["all_pass"])


def render_group_report(group_name: str, fb_sections: list) -> str:
    """Rapport HTML unique regroupant PLUSIEURS FB independants (meme fiche de rapport) --
    chaque FB garde ses propres tests/compilation/chronogramme, seule la page est commune.
    fb_sections : liste de dict, chacun avec les memes cles que les arguments de
    _render_fb_section (fb_name, domain, sources, json_data, text_report, test_st_path,
    trace_entries, source_paths, cycle_time_ms, field_types, af_warnings, extra_test_warnings)."""
    sections = [_render_fb_section(**kw) for kw in fb_sections]
    exec_time = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    all_pass = all(s["all_pass"] for s in sections)
    n_pass = sum(1 for s in sections if s["all_pass"])

    body_parts = []
    for s in sections:
        body_parts.append(f"""
    <div class="fb-section-title">{_html.escape(s['fb_name'])} {_badge(s['all_pass'])}</div>
    {s['body_html']}""")

    toc_html = _render_toc([(s["fb_name"], s["toc_entries"]) for s in sections])

    inner = f"""
    <div class="header">
        <h1>{_html.escape(group_name)}</h1>
        {_badge(all_pass)}
    </div>
    <div class="exec-time">{n_pass}/{len(sections)} FB OK · {exec_time}</div>
    {toc_html}
    {"".join(body_parts)}"""
    title = f"Rapport de test — {group_name} [{'PASS' if all_pass else 'FAIL'}]"
    return _page_shell(title, inner, all_pass=all_pass)
