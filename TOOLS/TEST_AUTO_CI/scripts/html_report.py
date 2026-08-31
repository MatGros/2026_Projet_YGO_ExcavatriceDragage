#!/usr/bin/env python3
"""Generation du rapport HTML autonome pour un run de test TEST_AUTO_CI, a partir du JSON
structure produit par test_runner.exe --json (cf. run_tests.py) et du fichier .st de test
source (pour extraire ce qui est concretement verifie -- les JSON de STruCpp ne donnent que
PASS/FAIL + 1re erreur, jamais la liste des ASSERT_* verifies)."""

import datetime as _dt
import html as _html
import json
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
        
        # Extraction contextuelle des notes par scan
        scan_notes = {}
        s_idx = 0
        last_comment = ""
        for line in body.splitlines():
            line_s = line.strip()
            cm = re.search(r"\(\*\s*(.*?)\s*\*\)", line_s)
            if cm:
                c_text = cm.group(1).strip()
                if not c_text.startswith("1.") and not c_text.startswith("2.") and not c_text.startswith("==="):
                    last_comment = c_text

            if re.search(r"\bfb\s*\(", line_s, re.IGNORECASE) or re.search(r"\bharness\s*\(", line_s, re.IGNORECASE):
                inline_cm = re.search(r"\(\*\s*(.*?)\s*\*\)", line_s)
                if inline_cm:
                    scan_notes[s_idx] = inline_cm.group(1).strip()
                elif last_comment:
                    scan_notes[s_idx] = last_comment
                s_idx += 1

        out[name] = {"checks": checks, "comments": comments, "scan_notes": scan_notes}
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
            f"<div class='failure-diff'>attendu <code class='val-expected'>{_html.escape(failure.get('expected', ''))}</code>"
            f" · obtenu <code class='val-actual'>{_html.escape(failure.get('actual', ''))}</code></div>"
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
    try:
        if "." in v or ("e" in v.lower() and not v.startswith("0x")):
            fval = float(v)
            return f"{fval:.3f}"
    except ValueError:
        pass
    return _html.escape(v)


def _sort_fields_for_chronogram(field_names: list) -> list:
    """Trie les colonnes du chronogramme selon l'ergonomie de test industriel :
    1. Résultats de mesures & grandeurs testées (Gauche) : MEASUREMENT, OUT, CMD, READY, BUSY, DONE, SPEED, POSITION, FAULT
    2. Ordres de marche & consignes d'entrées (Centre) : ENABLE, STARTSTOP, SAFESTOP, RESET, TARGET, REQ, SETPOINT
    3. Signaux matériels bruts, config et diag (Droite) : HWIN, HWOUT, CFG, CALIB, RAW, INTERNAL, PARAMS"""
    def _field_priority(name: str) -> tuple:
        u = name.upper()
        # 1. RÉSULTATS DE MESURES & SORTIES PRINCIPALES (Priorité 10..19)
        if "MEASUREMENT.SPEED" in u or "SPEED_MPS" in u or "SIGNEDSPEED" in u:
            return (10, u)
        if "MEASUREMENT.POS" in u or "CABLEPOSM" in u or "POSITIONM" in u or "POS_M" in u:
            return (11, u)
        if "MEASUREMENT.SPEEDVALID" in u or "MEASUREMENT.POSITIONVALID" in u:
            return (12, u)
        if "MEASUREMENT.HOMED" in u or "HOMED" in u:
            return (13, u)
        if u.startswith("MEASUREMENT."):
            return (14, u)
        if u.startswith("OUT.") or u.startswith("CMD."):
            return (15, u)
        if u in ("READY", "BUSY", "DONE", "ACTIVE", "ERROR", "FAULT.ERROR", "FAULT.ERRORID") or u.startswith("FAULT."):
            return (16, u)
        if u.startswith("STATUS.") or u.startswith("LIFECYCLE."):
            return (17, u)

        # 2. ORDRES DE MARCHE & CONSIGNES ENTRÉES (Priorité 20..29)
        if u in ("ENABLE", "STARTSTOP", "SAFESTOP", "RESET"):
            return (20, u)
        if u.startswith("TARGET.") or u.startswith("REQ.") or u.startswith("SET_"):
            return (21, u)
        if "HOMING" in u and not u.startswith("HW"):
            return (22, u)

        # 3. ENTRÉES BRUTES, CONFIGURATION & MATÉRIEL (Priorité 30..39)
        if u.startswith("HWOUT."):
            return (30, u)
        if u.startswith("HWIN.RAW") or "RAWPOS" in u or "RAW" in u:
            return (35, u)
        if u.startswith("HWIN."):
            return (34, u)
        if u.startswith("CFG.") or u.startswith("CALIB.") or "POINTSPERREV" in u or "CABLEM_PERREV" in u:
            return (36, u)
        if u.startswith("INTERNAL.") or u.startswith("DIAG."):
            return (38, u)

        return (25, u)

    return sorted(field_names, key=_field_priority)


def _split_static_fields(scans: list, field_names: list) -> tuple:
    """Separe les champs qui changent au moins une fois de ceux qui restent constants sur
    toute la sequence -- ces derniers n'apportent rien a une lecture temporelle."""
    changed, static = [], []
    for f in field_names:
        values = {s["fields"].get(f, "") for s in scans}
        (changed if len(values) > 1 else static).append(f)
    return _sort_fields_for_chronogram(changed), _sort_fields_for_chronogram(static)


def _render_table(scans: list, field_names: list, field_types: dict, fail_scan_num=None, scan_notes=None) -> str:
    scan_notes = scan_notes or {}
    has_notes = any(bool(scan_notes.get(s["scan"])) for s in scans)

    note_th = "<th class='note-th' style='min-width:180px;' title='Double-cliquez pour replier, glissez le bord pour redimensionner'><span class='th-content'>Étape / Contexte</span><div class='col-resizer'></div></th>" if has_notes else ""
    header = "".join(f"<th class='var-th' title='Double-cliquez pour replier, glissez le bord pour redimensionner'><span class='th-content'>{_html.escape(f)}</span><div class='col-resizer'></div></th>" for f in field_names)
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

        note_td = ""
        if has_notes:
            note = scan_notes.get(s["scan"], "")
            if note:
                note_td = f"<td class='chrono-note-cell' title='{_html.escape(note)}'><span class='chrono-note-chip'>{_html.escape(note)}</span></td>"
            else:
                note_td = "<td class='chrono-note-cell' style='color:var(--muted);'>—</td>"

        rows.append(f"<tr{row_cls}><td class='scan-idx'>#{s['scan']}{marker}</td>"
                     f"<td class='scan-t'>{s['t_display_ms']:.0f} ms</td>"
                     f"{note_td}"
                     f"{''.join(cells)}</tr>")
        prev = s["fields"]
    return f"""<div class="chrono-scroll"><table class="chrono-table">
        <thead><tr><th title="Double-cliquez pour replier, glissez le bord pour redimensionner"><span class="th-content">Scan</span><div class="col-resizer"></div></th><th title="Double-cliquez pour replier, glissez le bord pour redimensionner"><span class="th-content">Temps</span><div class="col-resizer"></div></th>{note_th}{header}</tr></thead>
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


def _fmt_scale(v: float) -> str:
    if abs(v) >= 1000:
        return f"{v:.0f}"
    elif abs(v) >= 10:
        return f"{v:.1f}"
    elif abs(v) == 0.0:
        return "0"
    else:
        return f"{v:.2f}"


def _render_waveform(scans: list, field_names: list, field_types: dict, fail_scan_num=None, scan_notes: dict = None) -> str:
    """Chronogramme graphique SVG : 1 ligne par variable, temps en abscisse (par index de
    scan -- espacement uniforme pour rester lisible meme quand les t_ns reels sont tres
    inegaux -- le temps simule reel est annote sous chaque colonne). BOOL = creneau
    (analyseur logique) ; numerique = courbe analogique auto-scalee avec bascule en puces texte au clic."""
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

    # Palette haute visibilité & contraste élevé (16 teintes distinctes saturées pour les thèmes sombre & clair)
    DISTINCT_PALETTE = [
        "#0284c7",  # 0: Bleu Cyan
        "#16a34a",  # 1: Vert Émeraude
        "#9333ea",  # 2: Violet Intense
        "#ea580c",  # 3: Orange Vif
        "#0d9488",  # 4: Sarcelle / Teal
        "#d97706",  # 5: Ambre / Doré
        "#4f46e5",  # 6: Indigo
        "#059669",  # 7: Vert Menthe
        "#c026d3",  # 8: Magenta / Fuchsia
        "#0891b2",  # 9: Bleu Lagon
        "#65a30d",  # 10: Lime / Vert Pomme
        "#db2777",  # 11: Rose Bonbon
        "#2563eb",  # 12: Bleu Royal
        "#ca8a04",  # 13: Jaune Moutarde
        "#7c3aed",  # 14: Violet Pourpre
        "#0284c7"   # 15: Cyan Vif
    ]
    RED_PALETTE = ["#ef4444", "#dc2626", "#f43f5e", "#e11d48", "#b91c1c"]
    _assigned_colors: dict = {}

    def wf_color(f: str, lane_idx: int = 0) -> str:
        upper = f.upper()
        if "RESET" in upper:
            return "#64748b"  # Gris ardoise neutre pour Reset
        if "ERROR" in upper or "FAILED" in upper or upper.endswith("FAIL"):
            if f not in _assigned_colors:
                _assigned_colors[f] = RED_PALETTE[len(_assigned_colors) % len(RED_PALETTE)]
            return _assigned_colors[f]
        if "LOCKOUT" in upper:
            return "#f97316"  # Orange vif alerte
        
        # Attribution d'une couleur distincte par ligne / variable
        if f not in _assigned_colors:
            _assigned_colors[f] = DISTINCT_PALETTE[lane_idx % len(DISTINCT_PALETTE)]
        return _assigned_colors[f]

    legend = [("#64748b", "Reset"), ("#ef4444", "Erreur / défaut"), ("#f97316", "Lockout"), ("#0284c7", "Voies actives")]
    
    notes_dict = scan_notes or {}
    scans_data = []
    for s in scans:
        scans_data.append({
            "scan": s["scan"],
            "t_ms": round(s["t_display_ms"], 1),
            "fields": s["fields"],
            "note": notes_dict.get(s["scan"], "")
        })
    scans_json = _html.escape(json.dumps(scans_data))
    fields_json = _html.escape(json.dumps(field_names))

    svg_parts = [f'<svg width="{width}" height="{height}" viewBox="0 0 {width} {height}" '
                 f'data-scans="{scans_json}" data-fields="{fields_json}" '
                 f'data-left="{left_margin}" data-top="{top_margin}" '
                 f'data-colw="{col_w}" data-laneh="{lane_h}" '
                 f'xmlns="http://www.w3.org/2000/svg" class="waveform">']

    # Curseur vertical guide
    svg_parts.append(f'<line class="wf-cursor-line" x1="0" y1="{top_margin - 6}" x2="0" y2="{height - 18}" stroke="#38bdf8" stroke-width="1.5" stroke-dasharray="3,3" opacity="0.8" style="display:none; pointer-events:none;"/>')

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
        color = wf_color(f, row)
        svg_parts.append(f'<circle cx="{left_margin - 8}" cy="{y_mid}" r="4" fill="{color}"/>')

        if is_bool(f):
            svg_parts.append(f'<text x="{left_margin - 18}" y="{y_mid + 4}" class="wf-label">{_html.escape(f)}</text>')
            y_hi, y_lo = y_lane + 6, y_lane + lane_h - 8
            # echelle 0/1 sur la 1ere ligne uniquement
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
            svg_parts.append(f'<text x="{left_margin - 18}" y="{y_mid + 4}" class="wf-label wf-clickable active-curve" onclick="toggleWfLane(this, {row})" title="Cliquer pour basculer Courbe / Chiffres">{_html.escape(f)}</text>')

            vals = []
            for s in scans:
                raw_v = s["fields"].get(f, "")
                try:
                    vals.append(float(raw_v))
                except (ValueError, TypeError):
                    vals.append(0.0)

            vmin = min(vals)
            vmax = max(vals)
            vrange = vmax - vmin if vmax > vmin else 1.0

            y_top = y_lane + 6
            y_bot = y_lane + lane_h - 6
            h_avail = lane_h - 12

            def to_y(val):
                if vmax == vmin:
                    return y_mid
                return y_bot - ((val - vmin) / vrange) * h_avail

            # Vue Analogique
            analog_parts = []
            analog_parts.append(f'<text x="{left_margin - 6}" y="{y_top + 4}" class="wf-scale">{_fmt_scale(vmax)}</text>')
            analog_parts.append(f'<text x="{left_margin - 6}" y="{y_bot + 2}" class="wf-scale">{_fmt_scale(vmin)}</text>')
            
            analog_path = []
            for i in range(n):
                x0 = left_margin + i * col_w
                x1 = left_margin + (i + 1) * col_w
                y = to_y(vals[i])
                if i == 0:
                    analog_path.append(f"M{x0},{y:.1f}")
                else:
                    prev_y = to_y(vals[i-1])
                    if abs(y - prev_y) > 0.1:
                        analog_path.append(f"L{x0},{y:.1f}")
                analog_path.append(f"L{x1},{y:.1f}")
            analog_parts.append(f'<path d="{"".join(analog_path)}" class="wf-line" stroke="{color}" stroke-width="2.2"/>')

            for i in range(n):
                if i > 0 and vals[i] != vals[i-1]:
                    cx = left_margin + i * col_w
                    cy = to_y(vals[i])
                    analog_parts.append(f'<circle cx="{cx}" cy="{cy:.1f}" r="2.5" fill="{color}"/>')

            # Vue Digitale (Puces texte)
            digital_parts = []
            prev_v = None
            for i, s in enumerate(scans):
                v = s["fields"].get(f, "")
                x0, x1 = left_margin + i * col_w, left_margin + (i + 1) * col_w
                changed = prev_v is not None and v != prev_v
                digital_parts.append(f'<line x1="{x0}" y1="{y_mid}" x2="{x1}" y2="{y_mid}" class="wf-num-line"/>')
                if changed or prev_v is None:
                    cx, cy = (x0 + x1) / 2, y_mid - 6
                    chip_w = max(18, len(v) * 7)
                    digital_parts.append(
                        f'<rect x="{cx - chip_w/2}" y="{cy - 8}" width="{chip_w}" height="13" rx="3" '
                        f'fill="{color}" class="wf-chip"/>'
                    )
                    digital_parts.append(f'<text x="{cx}" y="{cy + 1}" class="wf-num-changed">{_html.escape(v)}</text>')
                else:
                    digital_parts.append(f'<text x="{(x0+x1)/2}" y="{y_mid - 6}" class="wf-num">{_html.escape(v)}</text>')
                prev_v = v

            svg_parts.append(
                f'<g class="wf-numeric-group" data-row="{row}">'
                f'<g class="wf-analog-view">{"".join(analog_parts)}</g>'
                f'<g class="wf-digital-view" style="display:none;">{"".join(digital_parts)}</g>'
                f'</g>'
            )

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
                        test_passed: bool = True, scan_notes: dict = None) -> str:
    scans = [e for e in entries if e.get("test") == test_name]
    if not scans:
        return ""
    scans = _apply_realistic_time(scans, cycle_time_ms)
    all_fields = list(scans[0]["fields"].keys())
    changed_fields, static_fields = _split_static_fields(scans, all_fields)

    fail_note = ""
    fail_scan_num = None
    if not test_passed:
        fail_scan_num = scans[-1]["scan"]
        fail_note = (
            f'<div class="chrono-fail-note">⚠️ Trace interrompue au scan #{fail_scan_num} — '
            f"c'est le scan où l'assertion a échoué (le test s'arrête net, les scans suivants "
            f"n'existent pas).</div>"
        )

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
        <!-- Décision (2026-08-29) : les 2 chronogrammes (graphique + tableau) sont OUVERTS par
             défaut quand la carte du test est dépliée, quel que soit le PASS/FAIL. Avant, ils
             ne s'ouvraient qu'en cas d'échec. L'échec reste signalé par `fail_note` ci-dessus. -->
        <details open>
            <summary class="chrono-table-summary">
                <div class="chrono-summary-inner">
                    <span>📊 Chronogramme graphique ({len(scans)} scans, {len(changed_fields)} variables actives)</span>
                    <span class="table-export-actions" onclick="event.stopPropagation();">
                        <button type="button" class="btn-export" onclick="toggleAllWaveforms(this)" title="Basculer toutes les pistes numériques entre Courbes et Chiffres">📈 Courbes / 🔢 Chiffres</button>
                    </span>
                </div>
            </summary>
            <div class="wf-scroll">{_render_waveform(scans, changed_fields, field_types, fail_scan_num, scan_notes=scan_notes)}</div>
        </details>
        <details open>
            <summary class="chrono-table-summary">
                <div class="chrono-summary-inner">
                    <span>📋 Chronogramme tableau ({len(scans)} scans)</span>
                    <span class="table-export-actions" onclick="event.stopPropagation();">
                        <button type="button" class="btn-export" onclick="toggleVerticalHeaders(this)" title="Basculer l'orientation des en-têtes (gain de place)">📐 Titres Verticaux</button>
                        <button type="button" class="btn-export" onclick="exportTableCSV(this, '{_html.escape(test_name)}')" title="Télécharger le tableau en CSV">📥 CSV</button>
                        <button type="button" class="btn-export" onclick="copyTableMarkdown(this)" title="Copier le tableau en Markdown">📋 Markdown</button>
                    </span>
                </div>
            </summary>
            {_render_table(scans, changed_fields, field_types, fail_scan_num, scan_notes=scan_notes)}
        </details>
        {_render_static_table(scans, static_fields, field_types)}
    </div>"""


def _render_fb_section(fb_name: str, domain: str, sources: list,
                        json_data: dict, text_report: str = "", test_st_path=None,
                        trace_entries=None, source_paths=None, cycle_time_ms: float = 10,
                        field_types=None, af_warnings=None, extra_test_warnings=None,
                        wirings=None, encapsulation_report=None, source_prg=None) -> dict:
    """Construit le contenu d'un FB (sous-titre + warning AF + cartes de test + details
    sources) SANS l'enveloppe de page complete -- reutilise a l'identique par un rapport
    mono-FB (render_html_report) et un rapport groupe multi-FB (render_group_report).
    wirings : liste de {"label": str|None, "wiring": dict|None} -- un element par instance
    production configuree (registry.yaml prod_instances), ou un seul element label=None pour
    un FB mono-instance / pas encore instancie (retro-compat prod_instance singulier)."""
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
    contract_cards = []
    toc_entries = []
    for i, r in enumerate(results):
        name = r.get("name", "")
        passed_r = r.get("passed", False)
        info = checks_by_test.get(name, {"checks": [], "comments": [], "scan_notes": {}})

        checks_html = "".join(f"<li>{_html.escape(c)}</li>" for c in info["checks"])
        chrono_html = _render_chronogram(name, trace_entries or [], cycle_time_ms, field_types, passed_r, scan_notes=info.get("scan_notes"))

        is_p03_fb = (fb_name == "FB_FbStatus")
        is_contract_test = not is_p03_fb and name.upper().startswith("TC-P03-")
        contract_tag = '<span style="background:#e0e7ff;color:#3730a3;border:1px solid #c7d2fe;padding:1px 6px;border-radius:4px;font-size:10.5px;font-weight:700;margin-left:4px;">🧬 CONTRAT & INTERFACE</span>' if is_contract_test else ''

        anchor = f"test-{fb_slug}-{i}"
        toc_entries.append((anchor, name, passed_r))

        # Par défaut : replié pour les tests PASS afin de gagner de la place, ouvert pour les FAIL
        collapsed_class = " test-card-collapsed" if passed_r else ""
        card_classes = f"test-card test-card-{'pass' if passed_r else 'fail'}{collapsed_class}" + (" test-card-contract" if is_contract_test else "")

        scenario_drawer_html = ""
        if info["comments"]:
            steps_items = "".join(f"<li>{_html.escape(c)}</li>" for c in info["comments"])
            scenario_drawer_html = f"""
            <details class="checks-details">
                <summary class="checks-summary"><span class="checks-label">📝 Scénario & Déroulé ({len(info["comments"])})</span></summary>
                <ul class="scenario-list">{steps_items}</ul>
            </details>"""

        checks_drawer_html = ""
        if info["checks"]:
            checks_drawer_html = f"""
            <details class="checks-details">
                <summary class="checks-summary"><span class="checks-label">🔍 Vérifié ({len(info["checks"])})</span></summary>
                <ul class="checks-list">{checks_html}</ul>
            </details>"""

        rendered_card = f"""
        <article id="{anchor}" class="{card_classes}">
            <header class="test-card-header" style="cursor: pointer; user-select: none;" title="Cliquer pour replier / déplier le test">
                {_badge(passed_r)}
                <h3 style="flex: 1;">{_html.escape(name)} {contract_tag}</h3>
                <span class="test-card-toggle" style="font-size: 13px; color: var(--muted); margin-left: 8px;">▾</span>
            </header>
            <div class="test-card-body">
                {scenario_drawer_html}
                {checks_drawer_html}
                {_failure_block(r.get('failure'))}
                {chrono_html}
            </div>
        </article>"""

        if is_contract_test:
            contract_cards.append(rendered_card)
        else:
            cards.append(rendered_card)

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

    # Tiroir dédié aux tests d'interface et contrat socle (dépliable)
    if contract_cards:
        contract_section_html = f"""
    <details class="encaps-details" style="margin-top: 16px;">
        <summary>🧬 Tests Socle & Contrat d'Interface AF03 <span class="badge badge-pass" style="margin-left:6px;">PASS</span> — {len(contract_cards)} validation(s) (Enable/Reset/Ready/Status & Invariants)</summary>
        <div style="margin-top: 12px;">
            {"".join(contract_cards)}
        </div>
    </details>"""
    else:
        contract_section_html = f"""
    <details class="encaps-details" style="margin-top: 16px; opacity: 0.95;">
        <summary style="color:#94a3b8;font-size:13px;">🧬 Tests Socle & Contrat d'Interface AF03 <span style="color:#94a3b8;font-size:11.5px;font-weight:600;margin-left:6px;">(0 test dédié)</span></summary>
        <div style="padding: 14px; font-size: 13px; color: #cbd5e1; background: var(--card-sub); border-radius: 6px; margin-top: 8px; border: 1px solid var(--border);">
            ℹ️ Aucun test de cycle de vie socle direct déclaré dans cette suite (validé par composition ou profil spécifique).
        </div>
    </details>"""

    # Tiroir dédié aux tests fonctionnels métier & procédé AF / TC (dépliable, ouvert par défaut si non vide)
    if cards:
        domain_section_html = f"""
    <details class="encaps-details" open style="margin-top: 16px;">
        <summary>🎯 Tests Fonctionnels Métier & Procédé AF / TC <span class="badge badge-pass" style="margin-left:6px;">PASS</span> — {len(cards)} scénario(s) métier & sécurité machine</summary>
        <div style="margin-top: 12px;">
            {"".join(cards)}
        </div>
    </details>"""
    else:
        domain_section_html = f"""
    <details class="encaps-details" style="margin-top: 16px; opacity: 0.95;">
        <summary style="color:#94a3b8;font-size:13px;">🎯 Tests Fonctionnels Métier & Procédé AF / TC <span style="color:#94a3b8;font-size:11.5px;font-weight:600;margin-left:6px;">(0 test métier)</span></summary>
        <div style="padding: 14px; font-size: 13px; color: #cbd5e1; background: var(--card-sub); border-radius: 6px; margin-top: 8px; border: 1px solid var(--border);">
            ℹ️ Composant technique / socle transverse : non rattaché à un catalogue de tests métier ou de procédé spécifique.
        </div>
    </details>"""
    encapsulation_html = ""
    if encapsulation_report:
        n_violations = sum(1 for e in encapsulation_report if e["has_violation"])
        rows_html = []
        for e in encapsulation_report:
            ok = not e["has_violation"]
            if ok:
                verified_invariants = [
                    f"<span style='color:#cbd5e1;'><b style='color:#34d399;'>✓</b> Pas d'écriture externe ({e['n_local']} VAR locales protégées)</span>",
                    f"<span style='color:#cbd5e1;'><b style='color:#34d399;'>✓</b> Zéro dépendance GVL masquée (Interface IEC pure)</span>"
                ]
                detail_html = f"<div style='font-size:12px;'>{' · '.join(verified_invariants)}</div>"
            else:
                detail = "".join(
                    f"<li>🚨 <b>Écriture externe clandestine sur VAR locale :</b> <code>{_html.escape(w)}</code></li>"
                    for w in e.get("external_writes", [])
                ) + "".join(
                    f"<li>⚠️ <b>Bypass interface (Dépendance GVL directe) :</b> <code>{_html.escape(g)}</code></li>"
                    for g in e.get("gvl_refs", [])
                )
                detail_html = f"<ul style='margin:0;padding-left:16px;color:#f87171;font-size:12px;font-weight:600;'>{detail}</ul>"

            rows_html.append(f"""
            <tr class="encaps-row-{'pass' if ok else 'fail'}">
                <td>{_badge(ok)}</td>
                <td><code>{_html.escape(e['fb_name'])}</code></td>
                <td>{e['n_input']}</td><td>{e['n_output']}</td>
                <td>{e['n_inout']}</td><td>{e['n_local']}</td>
                <td>{detail_html}</td>
            </tr>""")
        summary_badge = '<span class="badge badge-pass" style="margin-left:6px;">PASS</span>' if n_violations == 0 else '<span class="badge badge-fail" style="margin-left:6px;">FAIL</span>'
        summary_txt = (f"⚠️ {n_violations} violation(s) sur {len(encapsulation_report)} FB de la chaine"
                        if n_violations else
                        f"✅ {len(encapsulation_report)} FB de la chaine, encapsulation propre (0 violation)")
        
        help_invariants_html = """
        <details style="margin: 12px 0 16px 0; background: var(--card-sub); border: 1px solid var(--border); border-radius: 8px; padding: 10px 14px;">
            <summary style="cursor: pointer; color: var(--accent); font-weight: 700; font-size: 13px;">
                ℹ️ Guide d'Audit : Les 7 Invariants & Règles d'Encapsulation Automatisme (Cliquez pour afficher)
            </summary>
            <table style="width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 12px; text-align: left;">
                <thead>
                    <tr style="background: var(--surface); color: var(--text);">
                        <th style="padding: 6px 8px; border-bottom: 1px solid var(--border);">#</th>
                        <th style="padding: 6px 8px; border-bottom: 1px solid var(--border);">Règle / Invariant POO</th>
                        <th style="padding: 6px 8px; border-bottom: 1px solid var(--border);">Risque Machine Réel</th>
                        <th style="padding: 6px 8px; border-bottom: 1px solid var(--border);">Contrôle Automatique</th>
                    </tr>
                </thead>
                <tbody>
                    <tr style="border-bottom: 1px solid var(--border);">
                        <td style="padding: 6px 8px; font-weight: bold; color: var(--accent);">1</td>
                        <td style="padding: 6px 8px; color: var(--text);"><b>Écriture externe clandestine sur VAR locale</b></td>
                        <td style="padding: 6px 8px; color: #f87171;">Écrasement d'un filtre, timer ou état interne par un autre bloc.</td>
                        <td style="padding: 6px 8px; color: #34d399;">🚨 Violation d'encapsulation (External Write)</td>
                    </tr>
                    <tr style="border-bottom: 1px solid var(--border);">
                        <td style="padding: 6px 8px; font-weight: bold; color: var(--accent);">2</td>
                        <td style="padding: 6px 8px; color: var(--text);"><b>Accès GVL direct sans passer par l'interface</b></td>
                        <td style="padding: 6px 8px; color: #f87171;">FB non testable unitairement, couplage fort et masqué.</td>
                        <td style="padding: 6px 8px; color: #34d399;">⚠️ Effet de bord Global (Hidden GVL Dependency)</td>
                    </tr>
                    <tr style="border-bottom: 1px solid var(--border);">
                        <td style="padding: 6px 8px; font-weight: bold; color: var(--accent);">3</td>
                        <td style="padding: 6px 8px; color: var(--text);"><b>Référence VAR_IN_OUT orpheline</b></td>
                        <td style="padding: 6px 8px; color: #f87171;">Pointeur nul / crash automate lors de l'appel.</td>
                        <td style="padding: 6px 8px; color: #34d399;">🚨 Invalidation appel de FB</td>
                    </tr>
                    <tr style="border-bottom: 1px solid var(--border);">
                        <td style="padding: 6px 8px; font-weight: bold; color: var(--accent);">4</td>
                        <td style="padding: 6px 8px; color: var(--text);"><b>Reset sur front montant (R_TRIG)</b></td>
                        <td style="padding: 6px 8px; color: #f87171;">Réarmement intempestif si le bouton reste coincé/actif.</td>
                        <td style="padding: 6px 8px; color: #34d399;">🔒 Règle IEC Reset obligatoire</td>
                    </tr>
                    <tr style="border-bottom: 1px solid var(--border);">
                        <td style="padding: 6px 8px; font-weight: bold; color: var(--accent);">5</td>
                        <td style="padding: 6px 8px; color: var(--text);"><b>Profils standards (Enable / Ready / Status)</b></td>
                        <td style="padding: 6px 8px; color: #f87171;">Composant impossible à chaîner en sécurité AU.</td>
                        <td style="padding: 6px 8px; color: #34d399;">⚠️ Contrat AF03 §1bis</td>
                    </tr>
                    <tr style="border-bottom: 1px solid var(--border);">
                        <td style="padding: 6px 8px; font-weight: bold; color: var(--accent);">6</td>
                        <td style="padding: 6px 8px; color: var(--text);"><b>Sorties VAR_OUTPUT orphelines</b></td>
                        <td style="padding: 6px 8px; color: #f87171;">Information calculée mais oubliée dans le câblage global.</td>
                        <td style="padding: 6px 8px; color: #34d399;">💡 Alerte Pinout non consommé</td>
                    </tr>
                    <tr>
                        <td style="padding: 6px 8px; font-weight: bold; color: var(--accent);">7</td>
                        <td style="padding: 6px 8px; color: var(--text);"><b>Variables locales non initialisées</b></td>
                        <td style="padding: 6px 8px; color: #f87171;">Comportement aléatoire lors d'un redémarrage à chaud.</td>
                        <td style="padding: 6px 8px; color: #34d399;">⚠️ Détection d'état initial indéfini</td>
                    </tr>
                </tbody>
            </table>
        </details>"""

        encapsulation_html = f"""
    <details class="encaps-details" {"open" if n_violations else ""}>
        <summary>🔒 Encapsulation (Interface & POO) {summary_badge} — {summary_txt}</summary>
        {help_invariants_html}
        <table class="encaps-table">
            <thead><tr><th>Statut</th><th>Composant (FB)</th><th>VAR_IN</th><th>VAR_OUT</th><th>IN_OUT</th><th>LOCAL</th><th>Analyse Invariants & Violations</th></tr></thead>
            <tbody>{"".join(rows_html)}</tbody>
        </table>
    </details>"""

    # Bloc de compilation des composants sources
    compilation_rows = []
    compil_errors_total = 0
    if source_paths:
        for p in source_paths:
            p_obj = pathlib.Path(p)
            fname = p_obj.name
            st_type = "DUT"
            try:
                txt = p_obj.read_text(encoding="utf-8", errors="ignore")
                if re.search(r"\bFUNCTION_BLOCK\b", txt):
                    st_type = "FB"
                elif re.search(r"\bTYPE\s+\w+\s*:\s*ENUM\b|\bTYPE\s+\w+\s*:\s*\([^)]+\)\s*;?\s*END_TYPE", txt):
                    st_type = "DUT (Enum)"
                elif re.search(r"\bTYPE\s+\w+\s*:\s*STRUCT\b", txt):
                    st_type = "DUT (Struct)"
                elif re.search(r"\bPROGRAM\b", txt):
                    st_type = "PRG"
            except Exception:
                pass

            # Analyse des erreurs spécifiques à ce fichier dans text_report
            file_errors = []
            if text_report and fname in text_report:
                for line in text_report.splitlines():
                    if fname in line and ("error:" in line.lower() or "erreur" in line.lower()):
                        file_errors.append(line.strip())

            # Verification si c'est un Mock
            is_mock = "MOCKS" in str(p_obj.as_posix())
            mock_badge = '<span style="background:rgba(245,158,11,0.2);color:#fbbf24;border:1px solid #d97706;font-size:10px;padding:1px 6px;border-radius:4px;margin-left:6px;font-weight:600;">MOCK</span>' if is_mock else ''

            is_ok = len(file_errors) == 0
            if not is_ok:
                compil_errors_total += len(file_errors)

            err_detail = f"<ul style='margin:0;padding-left:16px;'>{''.join(f'<li>{_html.escape(e)}</li>' for e in file_errors)}</ul>" if file_errors else ("Simulé pour environnement CI (hors CODESYS)" if is_mock else "Aucune erreur")
            status_badge = _badge(is_ok)
            compilation_rows.append(f"""
            <tr class="compil-row-{'pass' if is_ok else 'fail'}">
                <td><code>{_html.escape(fname)}</code>{mock_badge}</td>
                <td>{_html.escape(st_type)}</td>
                <td><span style="color:var(--green-text);font-weight:600;">OK</span></td>
                <td><span style="color:{'var(--green-text)' if is_ok else 'var(--red-text)'};font-weight:600;">{'OK' if is_ok else 'FAIL'}</span></td>
                <td>{status_badge}</td>
                <td>{err_detail}</td>
            </tr>""")

    compil_summary_txt = f"⚠️ {compil_errors_total} erreur(s) de compilation" if compil_errors_total > 0 else f"✅ {len(source_paths or [])} composant(s) compilé(s) avec succès (0 erreur)"
    compil_badge = '<span class="badge badge-pass" style="margin-left:6px;">PASS</span>' if compil_errors_total == 0 else '<span class="badge badge-fail" style="margin-left:6px;">FAIL</span>'
    compilation_html = f"""
    <details class="encaps-details" {"open" if compil_errors_total > 0 else ""}>
        <summary>⚙️ État de Compilation STruCpp (ST → C++) {compil_badge} — {compil_summary_txt}</summary>
        <table class="encaps-table">
            <thead><tr><th>Fichier / Bloc</th><th>Type</th><th>Conversion ST → C++</th><th>Compilation C++ (STruCpp)</th><th>Statut Global</th><th>Détail / Erreurs</th></tr></thead>
            <tbody>{"".join(compilation_rows)}</tbody>
        </table>
    </details>"""

    # Schéma Bloc & Boîte Noire I/O (Interface + Flux Réels GVL & Inter-PRG)
    io_diagram_html = ""
    target_prg_or_fb = None
    if source_prg:
        p_cand = pathlib.Path(source_prg)
        if not p_cand.is_absolute():
            repo_root = pathlib.Path(__file__).resolve().parents[3]
            p_cand = repo_root / source_prg
        if p_cand.exists():
            target_prg_or_fb = p_cand

    if not target_prg_or_fb and source_paths:
        for sp in source_paths:
            p_obj = pathlib.Path(sp)
            if ("PRG_" in p_obj.name or p_obj.name.startswith("FB_")) and "TestHarness" not in p_obj.name and "MOCKS" not in str(p_obj):
                target_prg_or_fb = p_obj
                if "PRG_" in p_obj.name:
                    break
        if not target_prg_or_fb and source_paths:
            target_prg_or_fb = pathlib.Path(source_paths[-1])

    if target_prg_or_fb and target_prg_or_fb.exists():
        try:
            import parse_st_io
            io_analysis = parse_st_io.analyze_st_file(target_prg_or_fb)
            io_diagram_html = _render_st_io_block_diagram(io_analysis)
        except Exception as exc:
            import traceback
            tb_txt = traceback.format_exc()
            io_diagram_html = f"""
            <details class="pin-diagram-details" open style="border: 2px solid #ef4444; background: #fef2f2;">
                <summary style="color: #991b1b; font-weight: 700;">📦 Représentation Bloc & Boîte Noire I/O <span class="badge badge-fail" style="margin-left:6px;">FAIL</span> — Erreur d'analyse ({_html.escape(target_prg_or_fb.name)})</summary>
                <div style="padding: 12px; font-size: 12px; color: #7f1d1d;">
                    <p><b>Le schéma bloc I/O n'a pas pu être généré :</b> <code>{_html.escape(str(exc))}</code></p>
                    <pre style="background: #ffffff; border: 1px solid #fca5a5; padding: 8px; border-radius: 4px; overflow-x: auto; color: #b91c1c; font-size: 11px;">{_html.escape(tb_txt)}</pre>
                </div>
            </details>"""

    pin_diagram_html = "".join(
        _render_pin_diagram(fb_name, item.get("wiring"), label=item.get("label"))
        for item in (wirings or [])
    )

    is_prg = fb_name.startswith("PRG_")
    comp_type = "Programme POU" if is_prg else "Bloc Fonctionnel (FB)"
    primary_source = pathlib.Path(source_paths[-1]).name if source_paths else f"{fb_name}.st"

    body_html = f"""
    <div class="subtitle" style="display:flex;justify-content:space-between;align-items:center;padding:12px 18px;background:var(--surface);border:1px solid var(--border);border-radius:10px;margin-bottom:18px;">
        <div>
            <span style="font-size:14px;color:var(--text);font-weight:700;">📁 <code style="color:var(--accent);font-size:14px;">CODE/{_html.escape(domain)}/{_html.escape(primary_source)}</code></span>
            <span style="margin-left:10px;font-size:12.5px;color:var(--muted);">({comp_type})</span>
        </div>
        <div style="font-size:13.5px;font-weight:700;color:var(--text);">
            {passed}/{total} vérifications validées
        </div>
    </div>
    {compilation_html}
    {af_warning_html}
    {io_diagram_html}
    {pin_diagram_html}
    {encapsulation_html}
    {contract_section_html}
    {domain_section_html}
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
        --bg: #0b0f19; --bg-grid: rgba(255, 255, 255, 0.035); --surface: #131b2e; --surface-card: #182238; --border: #23304d; --text: #f1f5f9; --muted: #94a3b8;
        --accent: #818cf8; --green-bg: rgba(16, 185, 129, 0.15); --green-text: #34d399; --green-border: #059669;
        --red-bg: rgba(239, 68, 68, 0.15); --red-text: #f87171; --red-border: #dc2626;
        --warn-bg: rgba(245, 158, 11, 0.15); --warn-text: #fbbf24; --warn-border: #d97706;
        --card-sub: #0f172a; --badge-prg-bg: rgba(59, 130, 246, 0.2); --badge-prg-txt: #93c5fd;
        --badge-fb-bg: rgba(148, 163, 184, 0.15); --badge-fb-txt: #cbd5e1; --btn-bg: #1e293b; --btn-border: #334155;
        --code-bg: #070a12; --code-border: #1e293b;
        --neon-green-glow: 0 0 25px rgba(16, 185, 129, 0.65), 0 0 10px rgba(16, 185, 129, 0.4), inset 0 0 12px rgba(16, 185, 129, 0.15);
        --neon-red-glow: 0 0 25px rgba(239, 68, 68, 0.65), 0 0 10px rgba(239, 68, 68, 0.4), inset 0 0 12px rgba(239, 68, 68, 0.15);
        --neon-blue-glow: 0 0 25px rgba(99, 102, 241, 0.6), 0 0 10px rgba(99, 102, 241, 0.35);
    }
    [data-theme="light"] {
        --bg: #f8fafc; --bg-grid: rgba(0, 0, 0, 0.03); --surface: #ffffff; --surface-card: #ffffff; --border: #e2e8f0; --text: #1e293b; --muted: #64748b;
        --accent: #4f46e5; --green-bg: #ecfdf5; --green-text: #059669; --green-border: #a7f3d0;
        --red-bg: #fef2f2; --red-text: #dc2626; --red-border: #fecaca;
        --warn-bg: #fffbeb; --warn-text: #b45309; --warn-border: #fde68a;
        --card-sub: #f8fafc; --badge-prg-bg: #dbeafe; --badge-prg-txt: #1e40af;
        --badge-fb-bg: #f1f5f9; --badge-fb-txt: #475569; --btn-bg: #f8fafc; --btn-border: #cbd5e1;
        --code-bg: #f1f5f9; --code-border: #e2e8f0;
        --neon-green-glow: none; --neon-red-glow: none; --neon-blue-glow: none;
    }
    * { box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; margin: 0;
        background-color: var(--bg);
        background-image: linear-gradient(var(--bg-grid) 1px, transparent 1px), linear-gradient(90deg, var(--bg-grid) 1px, transparent 1px);
        background-size: 28px 28px;
        background-position: -1px -1px;
        color: var(--text); font-size: 15px; line-height: 1.6; transition: background 0.2s, color 0.2s; }
    .page { max-width: 1720px; width: 96%; margin: 0 auto; padding: 28px 16px 60px; }
    .header { display: flex; justify-content: space-between; align-items: center;
        margin-bottom: 8px; gap: 16px; background: var(--surface); border: 1px solid var(--border);
        border-radius: 12px; padding: 20px 26px; box-shadow: 0 4px 20px rgba(0,0,0,0.25); }
    .theme-toggle-btn { background: var(--btn-bg); border: 1px solid var(--btn-border); color: var(--text);
        padding: 8px 16px; border-radius: 8px; font-size: 13.5px; font-weight: 700; cursor: pointer;
        display: flex; align-items: center; gap: 8px; transition: all 0.2s; }
    .theme-toggle-btn:hover { border-color: var(--accent); color: var(--accent); }
    h1 { font-size: 26px; margin: 0; font-weight: 800; letter-spacing: -0.4px; color: #cbd5e1; }
    .header .badge, .fb-section-title .badge { font-size: 16px; padding: 8px 22px; }
    .subtitle { color: var(--muted); font-size: 14px; margin: 4px 0 26px; }
    .subtitle b { color: var(--text); font-weight: 700; }
    .badge { display: inline-block; padding: 6px 16px; border-radius: 8px; font-weight: 800;
        font-size: 13.5px; letter-spacing: 0.8px; font-family: monospace; text-transform: uppercase; }
    .badge-pass, .badge-pass.badge-strong { background: rgba(16, 185, 129, 0.22); color: #ffffff; border: 2px solid #34d399; box-shadow: 0 0 16px rgba(16, 185, 129, 0.45); }
    .badge-fail, .badge-fail.badge-strong { background: rgba(244, 63, 94, 0.22); color: #ffffff; border: 2px solid #fb7185; box-shadow: 0 0 16px rgba(244, 63, 94, 0.45); }
    
    /* Cartes modernes avec effets Neon Glow */
    .card-neon-ok { border: 1px solid var(--green-border) !important; box-shadow: var(--neon-green-glow) !important; }
    .card-neon-fail { border: 1px solid var(--red-border) !important; box-shadow: var(--neon-red-glow) !important; }
    .card-neon-blue { border: 1px solid #4f46e5 !important; box-shadow: var(--neon-blue-glow) !important; }

    details { margin-bottom: 20px; }
    summary { cursor: pointer; color: var(--muted); font-size: 12px; user-select: text; }
    summary:hover { color: var(--text); }
    ul { font-size: 12px; color: var(--muted); margin: 8px 0 0; padding-left: 18px; }
    .test-card { background: var(--surface); border: 1px solid var(--border); border-radius: 10px;
        padding: 16px 18px; margin-bottom: 12px; transition: transform 0.15s ease, box-shadow 0.15s ease, padding 0.2s ease; }
    .test-card:hover { transform: translateY(-1px); }
    .test-card-fail { border-color: var(--red-border); box-shadow: 0 0 10px rgba(239, 68, 68, 0.15); }
    .test-card-collapsed { padding: 10px 18px !important; }
    .test-card-collapsed .test-card-body { display: none !important; }
    .test-card-collapsed .test-card-header { margin-bottom: 0 !important; }
    .test-card-collapsed .test-card-toggle { transform: rotate(-90deg); }
    .test-card-toggle { transition: transform 0.2s ease; display: inline-block; }
    /* Style distinct pour les tests de contrat et d'interface socle */
    .test-card-contract { background: var(--card-sub); border-left: 5px solid #818cf8; border-color: var(--border) var(--border) var(--border) #818cf8; }
    .test-card-contract header h3 { color: #818cf8; }
    .test-card header { display: flex; align-items: center; gap: 10px; margin-bottom: 4px; }
    .test-card header h3 { font-size: 13.5px; margin: 0; font-weight: 700; }
    .comment { font-size: 12px; color: var(--muted); margin: 6px 0; font-style: italic; }
    .checks-details { margin-top: 10px; margin-bottom: 10px; border: 1px solid var(--border); border-radius: 8px; padding: 12px 16px; background: rgba(0, 0, 0, 0.02); }
    .checks-summary { cursor: pointer; font-size: 13.5px; color: var(--text); font-weight: 700; outline: none; user-select: text; }
    .checks-summary:hover { color: var(--accent); }
    .checks-label { font-size: 13.5px; font-weight: 700; }
    .checks-list, .scenario-list { list-style: none; padding-left: 0; margin: 12px 0 6px; }
    .checks-list li { font-size: 13px; color: var(--text); padding: 5px 0 5px 26px; position: relative; line-height: 1.5; }
    .checks-list li::before { content: "✓"; position: absolute; left: 2px; color: var(--green-text); font-weight: bold; font-size: 14px; }
    .scenario-list li { font-size: 14px; color: #f1f5f9; padding: 7px 0 7px 28px; position: relative; line-height: 1.6; border-bottom: 1px solid rgba(255, 255, 255, 0.07); font-weight: 500; }
    .scenario-list li:last-child { border-bottom: none; }
    .scenario-list li::before { content: "🔹"; position: absolute; left: 0; font-size: 12px; opacity: 0.9; top: 8px; }
    .table-export-actions { display: inline-flex; align-items: center; gap: 6px; }
    .btn-export { background: var(--btn-bg); border: 1px solid var(--btn-border); color: var(--text); padding: 2px 8px; border-radius: 5px; font-size: 11px; font-weight: 600; cursor: pointer; transition: all 0.15s ease; user-select: none; }
    .btn-export:hover { border-color: var(--accent); color: var(--accent); background: var(--surface-card); }
    /* Bouton discret "retour à l'index" (les rapports vivent dans RESULTS/<domaine>/reports/) */
    .btn-index { display: inline-flex; align-items: center; gap: 6px; background: transparent; border: 1px solid var(--btn-border); color: var(--muted); padding: 5px 12px; border-radius: 6px; font-size: 12px; font-weight: 600; text-decoration: none; cursor: pointer; transition: all 0.15s ease; user-select: none; white-space: nowrap; }
    .btn-index:hover { border-color: var(--accent); color: var(--accent); background: var(--surface-card); }
    .btn-export.btn-copied { background: var(--green-bg); color: var(--green-text); border-color: var(--green-border); }
    .failure { margin-top: 10px; padding: 12px 16px; background: var(--red-bg);
        border-left: 4px solid var(--red-text); border-radius: 6px; font-size: 13px; }
    .failure-head { color: var(--red-text); font-weight: 700; font-size: 13.5px; }
    .failure-loc { color: var(--muted); margin-top: 3px; font-size: 11.5px; font-family: monospace; }
    .failure-msg { color: var(--text); margin-top: 6px; font-weight: 600; }
    .failure-diff { margin-top: 8px; color: var(--text); font-size: 12.5px; display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
    .failure-diff code { padding: 3px 8px; border-radius: 5px; font-family: monospace; font-size: 12px; font-weight: 700; }
    .failure-diff code.val-expected { background: rgba(16, 185, 129, 0.15); color: #34d399; border: 1px solid rgba(52, 211, 153, 0.3); }
    .failure-diff code.val-actual { background: rgba(239, 68, 68, 0.18); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.35); }
    [data-theme="light"] .failure-diff code.val-expected { background: #ecfdf5; color: #059669; border: 1px solid #a7f3d0; }
    [data-theme="light"] .failure-diff code.val-actual { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }
    pre { background: #0f172a; color: #cbd5e1; padding: 12px; border-radius: 8px; font-size: 11px;
        overflow-x: auto; }
    .chronogram-group { margin-top: 10px; }
    .chronogram-group details { margin-bottom: 8px; border: 1px solid var(--border); border-radius: 8px;
        padding: 8px 12px; }
    .chronogram-group summary { font-size: 12px; font-weight: 600; color: var(--text); user-select: text; }
    .chrono-summary-inner { display: inline-flex; justify-content: space-between; align-items: center; width: calc(100% - 24px); margin-left: 6px; vertical-align: middle; }
    .chrono-scroll { overflow-x: auto; margin-top: 8px; border-radius: 8px; border: 1px solid var(--border);
        scrollbar-width: thin; scrollbar-color: var(--accent) var(--surface-card); }
    .chrono-scroll::-webkit-scrollbar, .wf-scroll::-webkit-scrollbar { display: block !important; height: 8px !important; width: 8px !important; }
    .chrono-scroll::-webkit-scrollbar-track, .wf-scroll::-webkit-scrollbar-track { background: var(--surface-card); border-radius: 4px; }
    .chrono-scroll::-webkit-scrollbar-thumb, .wf-scroll::-webkit-scrollbar-thumb { background: var(--accent); border-radius: 4px; }
    .chrono-scroll::-webkit-scrollbar-thumb:hover, .wf-scroll::-webkit-scrollbar-thumb:hover { background: #a5b4fc; }
    .chrono-table { border-collapse: collapse; font-size: 11.5px; white-space: nowrap; width: 100%; table-layout: auto; }
    .chrono-table th, .chrono-table td { padding: 5px 9px; border: 1px solid var(--border); text-align: center; position: relative; }
    .chrono-table th { background: var(--surface-card); color: var(--muted); font-weight: 700; position: sticky; top: 0; font-family: monospace; font-size: 11px; cursor: pointer; user-select: text; transition: max-width 0.2s, min-width 0.2s, padding 0.2s; }
    .chrono-table th:hover { color: var(--accent); }
    .col-resizer { position: absolute; top: 0; right: 0; width: 5px; cursor: col-resize; user-select: none; height: 100%; z-index: 10; }
    .col-resizer:hover, .col-resizer.resizing { background: var(--accent); }
    .chrono-table th.col-collapsed,
    .chrono-table td.col-collapsed {
        max-width: 24px !important;
        min-width: 24px !important;
        width: 24px !important;
        padding: 4px 1px !important;
        overflow: hidden !important;
        white-space: nowrap !important;
        opacity: 0.35 !important;
        background: rgba(0, 0, 0, 0.25) !important;
        color: transparent !important;
        border-color: rgba(255, 255, 255, 0.05) !important;
        font-size: 0 !important;
        position: relative;
    }
    .chrono-table th.col-collapsed {
        cursor: pointer;
        opacity: 0.75 !important;
        background: rgba(129, 140, 248, 0.18) !important;
    }
    .chrono-table th.col-collapsed:hover {
        opacity: 1 !important;
        background: rgba(129, 140, 248, 0.38) !important;
    }
    .chrono-table th.col-collapsed::after {
        content: "⋮";
        font-size: 12px;
        color: var(--accent);
        display: block;
        text-align: center;
    }
    /* Mode Titres Verticaux (Compact) */
    .chrono-table.headers-vertical {
        width: max-content !important;
    }
    .chrono-table.headers-vertical th.note-th,
    .chrono-table.headers-vertical td.chrono-note-cell {
        max-width: 280px !important;
        width: 280px !important;
    }
    .chrono-table.headers-vertical th.var-th {
        height: 155px;
        vertical-align: bottom;
        padding-bottom: 10px;
        padding-top: 10px;
        max-width: 36px;
        min-width: 30px;
        width: 34px;
    }
    .chrono-table.headers-vertical th.var-th .th-content {
        writing-mode: vertical-rl;
        transform: rotate(180deg);
        display: inline-block;
        white-space: nowrap;
        text-align: left;
        max-height: 135px;
        overflow: hidden;
        text-overflow: ellipsis;
    }
    .chrono-table th .th-content {
        display: inline-block;
        pointer-events: auto;
    }
    .chrono-table .scan-idx { color: var(--accent); font-weight: 700; font-family: monospace; }
    .chrono-table td.changed { background: rgba(56, 189, 248, 0.16); color: #38bdf8; font-weight: 700; border-color: rgba(56, 189, 248, 0.3); }
    [data-theme="light"] .chrono-table th { background: #f1f5f9; color: #475569; }
    [data-theme="light"] .chrono-table td.changed { background: #e0f2fe; color: #0369a1; border-color: #bae6fd; }
    .chrono-note-cell { text-align: left !important; max-width: 320px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 11px; }
    .chrono-note-chip { display: inline-flex; align-items: center; gap: 4px; background: rgba(129, 140, 248, 0.12); color: #a5b4fc; border: 1px solid rgba(129, 140, 248, 0.25); border-radius: 4px; padding: 2px 8px; font-weight: 600; cursor: help; transition: all 0.2s ease; max-width: 310px; overflow: hidden; text-overflow: ellipsis; }
    .chrono-note-chip:hover { background: rgba(129, 140, 248, 0.25); color: #ffffff; border-color: #818cf8; }
    [data-theme="light"] .chrono-note-chip { background: #eef2ff; color: #4338ca; border-color: #c7d2fe; }
    [data-theme="light"] .chrono-note-chip:hover { background: #e0e7ff; color: #312e81; }
    .v-true { color: #34d399; font-weight: 700; }
    .v-false { color: #64748b; }
    .wf-scroll { overflow-x: auto; background: var(--surface); border: 1px solid var(--border);
        border-radius: 8px; margin-top: 8px; padding: 4px 0;
        scrollbar-width: thin; scrollbar-color: var(--accent) var(--surface-card); }
    .waveform { display: block; }
    .wf-grid { stroke: var(--border); stroke-width: 1; opacity: 0.6; }
    .wf-time { font-size: 9px; fill: var(--muted); text-anchor: middle; font-family: monospace; }
    .wf-scan { font-size: 9px; fill: var(--muted); opacity: 0.7; text-anchor: middle; font-family: monospace; }
    .wf-label { font-size: 11px; fill: var(--text); font-family: monospace; text-anchor: end; font-weight: 600; }
    .wf-label.wf-clickable { cursor: pointer; transition: fill 0.15s; }
    .wf-label.wf-clickable:hover { fill: var(--accent); font-weight: 700; text-decoration: underline; }
    .wf-label.active-curve { fill: #38bdf8; font-weight: 700; }
    [data-theme="light"] .wf-label.active-curve { fill: #0284c7; }
    .wf-line { fill: none; stroke-width: 2.2; }
    .wf-num-line { stroke: var(--border); stroke-width: 1; }
    .wf-num { font-size: 10.5px; fill: var(--muted); text-anchor: middle; font-family: monospace; }
    .wf-num-changed { font-size: 10.5px; fill: #ffffff; font-weight: 700; text-anchor: middle; font-family: monospace; }
    .wf-chip { opacity: 0.95; }
    .wf-legend { font-size: 10px; fill: var(--muted); }
    .wf-scale { font-size: 9px; fill: #cbd5e1; text-anchor: end; font-family: monospace; font-weight: 600; }
    [data-theme="light"] .wf-scale { fill: #64748b; }
    .wf-tooltip {
        position: fixed; pointer-events: none; z-index: 9999;
        background: rgba(15, 23, 42, 0.95); backdrop-filter: blur(8px);
        border: 1px solid rgba(56, 189, 248, 0.4); box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
        border-radius: 8px; padding: 8px 12px; font-size: 11.5px; color: #f8fafc;
        display: none; max-width: 320px; line-height: 1.4;
    }
    [data-theme="light"] .wf-tooltip {
        background: rgba(255, 255, 255, 0.97); border-color: #cbd5e1;
        color: #1e293b; box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
    }
    .wf-tt-head { font-weight: 700; color: #38bdf8; font-family: monospace; margin-bottom: 3px; font-size: 11px; }
    [data-theme="light"] .wf-tt-head { color: #0284c7; }
    .wf-tt-var { font-weight: 700; font-family: monospace; font-size: 12px; margin-bottom: 3px; }
    .wf-tt-val { margin-bottom: 3px; font-size: 12px; }
    .wf-tt-val strong { font-family: monospace; color: #34d399; font-size: 12.5px; }
    .wf-tt-note { font-size: 11px; color: var(--muted); border-top: 1px solid rgba(255, 255, 255, 0.12); padding-top: 4px; margin-top: 4px; }
    [data-theme="light"] .wf-tt-note { border-top-color: rgba(0, 0, 0, 0.1); }
    .af-warning-banner { background: var(--warn-bg); color: var(--warn-text); border: 1px solid var(--warn-border);
        border-radius: 10px; padding: 12px 18px; margin: 14px 0; font-size: 13px; }
    .af-warning-banner .af-warning-title { font-weight: 600; margin-bottom: 6px; }
    .af-warning-banner ul { margin: 0; padding-left: 20px; }
    .af-warning-banner li { margin: 3px 0; }
    .encaps-details, .pin-diagram-details { background: var(--surface); border: 1px solid var(--border); border-radius: 10px;
        padding: 12px 18px; margin: 14px 0; box-sizing: border-box; width: 100%; }
    .encaps-details summary, .pin-diagram-details summary { font-weight: 600; color: var(--text); font-size: 13px; cursor: pointer; user-select: text; }
    .encaps-details summary:hover, .pin-diagram-details summary:hover { color: var(--accent); }
    .wiring-pastille { display: inline-block; margin-left: 8px; padding: 1px 9px; border-radius: 999px;
        font-size: 11px; font-weight: 700; letter-spacing: 0.3px; vertical-align: 1px; }
    .wiring-pastille-ok { background: var(--green-bg); color: var(--green-text); border: 1px solid var(--green-border); }
    .wiring-pastille-warn { background: var(--warn-bg); color: var(--warn-text); border: 1px solid var(--warn-border); }
    .encaps-table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 12.5px; }
    .encaps-table th { text-align: left; padding: 6px 10px; color: var(--muted); font-weight: 600; }
    .encaps-table td { padding: 6px 10px; border-top: 1px solid var(--border); }
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
    .pin-diagram { display: flex; align-items: flex-start; gap: 0; margin-top: 12px; font-size: 12px; width: 100%; }
    .pin-col { flex: 1; display: flex; flex-direction: column; gap: 4px; min-width: 0; max-height: 600px; overflow-y: auto; padding: 4px 8px;
        scrollbar-width: none; -ms-overflow-style: none; }
    .pin-col::-webkit-scrollbar { display: none; width: 0; height: 0; }
    .pin-row { display: flex; align-items: center; gap: 8px; padding: 5px 10px; border: 1px solid var(--border); border-radius: 6px;
        background: var(--surface); min-width: 0; }
    /* Entrees : texte colle au bloc -> justifie a droite (flux entrant vers le bloc) */
    .pin-col-in .pin-row { justify-content: space-between; text-align: right; }
    /* Sorties : texte colle au bloc -> justifie a gauche (flux sortant du bloc) */
    .pin-col-out .pin-row { justify-content: space-between; text-align: left; }
    .pin-name { font-family: monospace; font-weight: 700; font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: #f8fafc; }
    .pin-type { color: var(--muted); font-weight: 500; font-size: 11px; margin-left: 4px; }
    .pin-tag { font-size: 10px; border-radius: 4px; padding: 2px 6px; margin-left: 4px; font-weight: 700; white-space: nowrap; }
    .pin-expr { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; min-width: 0; }
    .pin-expr code { background: var(--code-bg); color: #93c5fd; border: 1px solid var(--border); padding: 2px 6px; border-radius: 4px; font-size: 11.5px;
        cursor: pointer; font-family: monospace; }
    .pin-expr code:hover { border-color: var(--accent); color: #ffffff; }
    .pin-expr code.pin-copied { background: var(--green-bg); color: var(--green-text); }
    .pin-missing { color: #fbbf24; font-style: italic; font-size: 12px; }
    .pin-more { color: var(--muted); font-size: 11px; }
    .pin-row-unwired { background: var(--card-sub); }
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

function exportTableCSV(btn, testName) {
    var details = btn.closest('details');
    if (!details) return;
    var table = details.querySelector('.chrono-table');
    if (!table) return;

    var rows = [];
    var ths = Array.from(table.querySelectorAll('thead th'));
    var headers = ths.map(function(th) {
        return '"' + th.textContent.replace(/"/g, '""').trim() + '"';
    });
    rows.push(headers.join(';'));

    table.querySelectorAll('tbody tr').forEach(function(tr) {
        var cells = Array.from(tr.querySelectorAll('td')).map(function(td) {
            return '"' + td.textContent.replace(/"/g, '""').trim() + '"';
        });
        rows.push(cells.join(';'));
    });

    var csvContent = "\\uFEFF" + rows.join('\\r\\n');
    var blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    var safeName = (testName || 'chronogram').replace(/[^a-zA-Z0-9_\\-]+/g, '_').substring(0, 50);
    a.href = url;
    a.download = safeName + '_chronogram.csv';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    var orig = btn.innerHTML;
    btn.innerHTML = "📥 Téléchargé !";
    btn.classList.add('btn-copied');
    setTimeout(function() {
        btn.innerHTML = orig;
        btn.classList.remove('btn-copied');
    }, 1200);
}

function copyTableMarkdown(btn) {
    var details = btn.closest('details');
    if (!details) return;
    var table = details.querySelector('.chrono-table');
    if (!table) return;

    var lines = [];
    var ths = Array.from(table.querySelectorAll('thead th'));
    var headers = ths.map(function(th) {
        return th.textContent.trim();
    });
    lines.push('| ' + headers.join(' | ') + ' |');
    lines.push('| ' + headers.map(function() { return '---'; }).join(' | ') + ' |');

    table.querySelectorAll('tbody tr').forEach(function(tr) {
        var cells = Array.from(tr.querySelectorAll('td')).map(function(td) {
            return td.textContent.trim().replace(/\\|/g, '\\\\|');
        });
        lines.push('| ' + cells.join(' | ') + ' |');
    });

    var md = lines.join('\\n');
    var ta = document.createElement('textarea');
    ta.value = md;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch (e) {}
    document.body.removeChild(ta);

    var orig = btn.innerHTML;
    btn.innerHTML = "📋 Copié !";
    btn.classList.add('btn-copied');
    setTimeout(function() {
        btn.innerHTML = orig;
        btn.classList.remove('btn-copied');
    }, 1200);
}

function toggleVerticalHeaders(btn) {
    var details = btn.closest('details');
    if (!details) return;
    var table = details.querySelector('.chrono-table');
    if (!table) return;

    var isVert = table.classList.toggle('headers-vertical');
    btn.innerHTML = isVert ? "↔️ Titres Horizontaux" : "📐 Titres Verticaux";
    if (isVert) {
        btn.classList.add('btn-copied');
    } else {
        btn.classList.remove('btn-copied');
    }
}

function toggleWfLane(textEl, rowIdx) {
    var svg = textEl.closest('svg');
    if (!svg) return;
    var group = svg.querySelector('.wf-numeric-group[data-row="' + rowIdx + '"]');
    if (!group) return;
    var analog = group.querySelector('.wf-analog-view');
    var digital = group.querySelector('.wf-digital-view');
    if (!analog || !digital) return;

    var isAnalog = analog.style.display !== 'none';
    if (isAnalog) {
        analog.style.display = 'none';
        digital.style.display = '';
        textEl.classList.remove('active-curve');
    } else {
        analog.style.display = '';
        digital.style.display = 'none';
        textEl.classList.add('active-curve');
    }
}

function toggleAllWaveforms(btn) {
    var details = btn.closest('details');
    if (!details) return;
    var svg = details.querySelector('svg.waveform');
    if (!svg) return;

    var groups = svg.querySelectorAll('.wf-numeric-group');
    if (!groups.length) return;

    var firstAnalog = groups[0].querySelector('.wf-analog-view');
    var currentlyAnalog = firstAnalog && firstAnalog.style.display !== 'none';
    var targetAnalog = !currentlyAnalog;

    groups.forEach(function(g) {
        var a = g.querySelector('.wf-analog-view');
        var d = g.querySelector('.wf-digital-view');
        if (a) a.style.display = targetAnalog ? '' : 'none';
        if (d) d.style.display = targetAnalog ? 'none' : '';
    });

    var labels = svg.querySelectorAll('.wf-label.wf-clickable');
    labels.forEach(function(lbl) {
        if (targetAnalog) lbl.classList.add('active-curve');
        else lbl.classList.remove('active-curve');
    });

    btn.innerHTML = targetAnalog ? "🔢 Vue Chiffres" : "📈 Vue Courbes";
}

function toggleTheme() {
    var current = document.documentElement.getAttribute('data-theme') || 'light';
    var next = current === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    try { localStorage.setItem('test_ci_theme', next); } catch (e) {}
    updateThemeBtn(next);
}

function updateThemeBtn(theme) {
    var btns = document.querySelectorAll('.theme-toggle-btn');
    btns.forEach(function(b) {
        b.innerHTML = theme === 'dark' ? '☀️ Mode Clair' : '🌙 Mode Sombre';
    });
}

(function() {
    try {
        var saved = localStorage.getItem('test_ci_theme');
        if (saved) {
            document.documentElement.setAttribute('data-theme', saved);
            document.addEventListener('DOMContentLoaded', function() { updateThemeBtn(saved); });
        }
    } catch (e) {}
})();

document.addEventListener('DOMContentLoaded', function() {
    // Redimensionnement manuel des colonnes a la souris (Drag & Drop border)
    var isResizing = false;
    var currentTh = null;
    var startX = 0;
    var startWidth = 0;

    document.addEventListener('mousedown', function(e) {
        var resizer = e.target.closest('.col-resizer');
        if (!resizer) return;
        isResizing = true;
        currentTh = resizer.closest('th');
        startX = e.pageX;
        startWidth = currentTh.offsetWidth;
        resizer.classList.add('resizing');
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';
        e.preventDefault();
        e.stopPropagation();
    });

    document.addEventListener('mousemove', function(e) {
        if (!isResizing || !currentTh) return;
        var diff = e.pageX - startX;
        var newWidth = Math.max(30, startWidth + diff);
        currentTh.style.width = newWidth + 'px';
        currentTh.style.minWidth = newWidth + 'px';
        currentTh.style.maxWidth = newWidth + 'px';

        if (currentTh.classList.contains('note-th')) {
            var table = currentTh.closest('.chrono-table');
            if (table) {
                table.querySelectorAll('.chrono-note-cell').forEach(function(td) {
                    td.style.maxWidth = newWidth + 'px';
                });
                table.querySelectorAll('.chrono-note-chip').forEach(function(chip) {
                    chip.style.maxWidth = Math.max(20, newWidth - 10) + 'px';
                });
            }
        }
    });

    document.addEventListener('mouseup', function() {
        if (isResizing) {
            isResizing = false;
            document.body.style.cursor = '';
            document.body.style.userSelect = '';
            document.querySelectorAll('.col-resizer.resizing').forEach(function(r) {
                r.classList.remove('resizing');
            });
            currentTh = null;
        }
    });

    // Double-clic sur un en-tete de colonne pour la replier / deplier (hors barre de redimensionnement)
    document.addEventListener('dblclick', function(e) {
        if (e.target.closest('.col-resizer')) return;
        var th = e.target.closest('.chrono-table th');
        if (!th) return;
        var table = th.closest('.chrono-table');
        if (!table) return;
        var colIdx = Array.from(th.parentNode.children).indexOf(th);
        var isCollapsed = th.classList.toggle('col-collapsed');
        table.querySelectorAll('tbody tr').forEach(function(row) {
            var cell = row.children[colIdx];
            if (cell) cell.classList.toggle('col-collapsed', isCollapsed);
        });
    });

    // Clic simple sur colonne repliee pour la reouvrir
    document.addEventListener('click', function(e) {
        var th = e.target.closest('.chrono-table th.col-collapsed');
        if (th) {
            var table = th.closest('.chrono-table');
            if (table) {
                var colIdx = Array.from(th.parentNode.children).indexOf(th);
                th.classList.remove('col-collapsed');
                table.querySelectorAll('tbody tr').forEach(function(row) {
                    var cell = row.children[colIdx];
                    if (cell) cell.classList.remove('col-collapsed');
                });
            }
            return;
        }

        // Clic sur l'en-tête d'une carte de test pour la replier / déplier
        var testHeader = e.target.closest('.test-card-header');
        if (testHeader) {
            var card = testHeader.closest('.test-card');
            if (card) {
                card.classList.toggle('test-card-collapsed');
            }
        }
    });

    // Bulle d'inspection interactive et curseur vertical pour chronogramme graphique
    var tt = document.getElementById('wf-global-tooltip');
    if (!tt) {
        tt = document.createElement('div');
        tt.id = 'wf-global-tooltip';
        tt.className = 'wf-tooltip';
        document.body.appendChild(tt);
    }

    document.addEventListener('mousemove', function(e) {
        var svg = e.target.closest('svg.waveform');
        if (!svg) {
            if (tt) tt.style.display = 'none';
            document.querySelectorAll('.wf-cursor-line').forEach(function(l) { l.style.display = 'none'; });
            return;
        }

        var rect = svg.getBoundingClientRect();
        var scaleX = svg.viewBox.baseVal.width / rect.width;
        var scaleY = svg.viewBox.baseVal.height / rect.height;

        var svgX = (e.clientX - rect.left) * scaleX;
        var svgY = (e.clientY - rect.top) * scaleY;

        var left = parseFloat(svg.getAttribute('data-left') || '200');
        var top = parseFloat(svg.getAttribute('data-top') || '62');
        var colw = parseFloat(svg.getAttribute('data-colw') || '56');
        var laneh = parseFloat(svg.getAttribute('data-laneh') || '40');

        var scansData = JSON.parse(svg.getAttribute('data-scans') || '[]');
        var fieldsData = JSON.parse(svg.getAttribute('data-fields') || '[]');

        var colIdx = Math.floor((svgX - left) / colw);
        var rowIdx = Math.floor((svgY - top) / laneh);

        var cursorLine = svg.querySelector('.wf-cursor-line');

        if (colIdx >= 0 && colIdx < scansData.length && rowIdx >= 0 && rowIdx < fieldsData.length) {
            var s = scansData[colIdx];
            var f = fieldsData[rowIdx];
            var val = s.fields[f];
            if (val === undefined) val = "—";

            var displayVal = val;
            if (val === "1") displayVal = "TRUE";
            else if (val === "0") displayVal = "FALSE";
            else {
                var num = parseFloat(val);
                if (!isNaN(num)) {
                    displayVal = Math.abs(num) >= 100 ? num.toFixed(0) : num.toFixed(3);
                }
            }

            if (cursorLine) {
                var cx = left + (colIdx + 0.5) * colw;
                cursorLine.setAttribute('x1', cx);
                cursorLine.setAttribute('x2', cx);
                cursorLine.style.display = '';
            }

            var noteHtml = s.note ? '<div class="wf-tt-note">' + s.note + '</div>' : '';

            tt.innerHTML = '<div class="wf-tt-head">Scan #' + s.scan + ' (' + s.t_ms + ' ms)</div>' +
                           '<div class="wf-tt-var">' + f + '</div>' +
                           '<div class="wf-tt-val">Valeur : <strong>' + displayVal + '</strong></div>' +
                           noteHtml;

            tt.style.display = 'block';
            var ttX = e.clientX + 16;
            var ttY = e.clientY + 16;
            if (ttX + 280 > window.innerWidth) ttX = e.clientX - 280;
            if (ttY + 120 > window.innerHeight) ttY = e.clientY - 120;
            tt.style.left = ttX + 'px';
            tt.style.top = ttY + 'px';
        } else {
            if (tt) tt.style.display = 'none';
            if (cursorLine) cursorLine.style.display = 'none';
        }
    });

    document.addEventListener('mouseleave', function() {
        if (tt) tt.style.display = 'none';
        document.querySelectorAll('.wf-cursor-line').forEach(function(l) { l.style.display = 'none'; });
    });
});
"""


def _page_shell(title: str, inner_html: str, all_pass: bool = True) -> str:
    """Enveloppe de page commune (mono-FB ou groupe) -- CSS partage via _CSS.
    Le fond sombre technique avec grille reste intact et les halos Neon font foi pour l'état."""
    return f"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>{_html.escape(title)}</title>
<style>{_CSS}</style>
</head>
<body>
<div class="page">
{inner_html}
</div>
<script>{_COPY_JS}</script>
</body>
</html>
"""


def _render_st_io_block_diagram(analysis: dict) -> str:
    """Rendu interactif complet de la boîte noire I/O pour un POU (Programme ou Function Block).
    Affiche à gauche les entrées (formelles + GVL/PRG lues), au centre le bloc POU, et à droite les sorties (formelles + GVL écrites)."""
    if not analysis:
        return ""

    file_name = analysis.get("file_name", "POU")
    decls = analysis.get("declarations", {})
    writes = analysis.get("categorized_writes", {})
    reads = analysis.get("categorized_reads", {})
    fb_instances = analysis.get("fb_instances", {})

    var_in = decls.get("VAR_INPUT", {})
    var_out = decls.get("VAR_OUTPUT", {})
    var_inout = decls.get("VAR_IN_OUT", {})

    # Entrées : regroupement clair par type et source
    left_items = []
    for v, t in var_in.items():
        left_items.append(f'<div class="pin-row pin-row-wired" style="background:var(--surface);border:1px solid var(--border);margin:3px 0;"><div class="pin-expr"><span style="color:#38bdf8;font-weight:700;font-size:11px;font-family:monospace;">[VAR_INPUT]</span></div><div class="pin-name">{_html.escape(v)} <span class="pin-type" style="color:var(--muted);">{_html.escape(t)}</span></div></div>')
    for v, t in var_inout.items():
        left_items.append(f'<div class="pin-row pin-row-wired" style="background:var(--surface);border:1px solid var(--border);margin:3px 0;"><div class="pin-expr"><span style="color:#a78bfa;font-weight:700;font-size:11px;font-family:monospace;">[VAR_IN_OUT]</span></div><div class="pin-name">{_html.escape(v)} <span class="pin-type" style="color:var(--muted);">{_html.escape(t)}</span></div></div>')
    
    # 1. Grouper les E/S physiques matérielles (Device_IO)
    hw_reads = reads.get("HW_IO", {})
    if hw_reads:
        sub_rows = []
        for p, info in sorted(hw_reads.items()):
            iec = info.get("iec_addr", "")
            dev = info.get("device", "")
            desc = info.get("desc", "")
            sub_rows.append(f"""
            <div class="pin-row pin-row-wired" style="padding-left:16px;background:var(--card-sub);border-left:3px solid #14b8a6;margin-top:2px;">
                <div class="pin-expr"><code style="color:#2dd4bf;background:rgba(20,184,166,0.15);font-size:11px;">{_html.escape(p)}</code> <span style="font-size:10px;color:var(--muted);">[{_html.escape(iec)} · {_html.escape(dev)}]</span></div>
                <div class="pin-name"><span class="pin-tag" style="background:rgba(20,184,166,0.2);color:#5eead4;font-size:10px;">🔌 E/S Matérielle</span></div>
            </div>""")
        left_items.append(f"""
        <details style="margin:4px 0;">
            <summary style="list-style:none;cursor:pointer;">
                <div class="pin-row pin-row-wired" style="background:rgba(20,184,166,0.15);border:1px solid #14b8a6;cursor:pointer;">
                    <div class="pin-expr"><span style="color:#5eead4;font-weight:700;font-size:12px;">🔌 Entrées Physiques / E/S Mappées</span> <span style="font-size:11px;color:#2dd4bf;">({len(hw_reads)} capteurs/adresses ▾)</span></div>
                    <div class="pin-name"><span class="pin-tag" style="background:rgba(20,184,166,0.25);color:#5eead4;">Device_IO</span></div>
                </div>
            </summary>
            <div style="margin-top:2px;">{"".join(sub_rows)}</div>
        </details>""")

    # 2. Grouper les lectures GVL par variable globale parente (ex: GVL_Simulation, GVL_IHM)
    gvl_reads_by_group = {}
    for g in reads.get("GVL", []):
        parts = g.split(".", 1)
        g_grp = parts[0]
        g_sub = parts[1] if len(parts) > 1 else g
        gvl_reads_by_group.setdefault(g_grp, []).append((g, g_sub))

    for g_grp, items in sorted(gvl_reads_by_group.items()):
        sub_rows = []
        for full_expr, sub_name in sorted(items):
            sub_rows.append(f"""
            <div class="pin-row pin-row-unwired" style="padding-left:16px;background:var(--card-sub);border-left:3px solid #0284c7;margin-top:2px;">
                <div class="pin-expr"><code style="color:#38bdf8;background:rgba(2,132,199,0.15);font-size:11px;">{_html.escape(full_expr)}</code></div>
                <div class="pin-name"><span class="pin-tag" style="background:rgba(2,132,199,0.2);color:#7dd3fc;font-size:10px;">🌐 GVL In</span></div>
            </div>""")
        left_items.append(f"""
        <details style="margin:4px 0;">
            <summary style="list-style:none;cursor:pointer;">
                <div class="pin-row pin-row-unwired" style="background:rgba(2,132,199,0.15);border:1px solid #0284c7;cursor:pointer;">
                    <div class="pin-expr"><span style="color:#7dd3fc;font-weight:700;font-size:12px;">🌐 {_html.escape(g_grp)}</span> <span style="font-size:11px;color:#38bdf8;">({len(items)} signaux ▾)</span></div>
                    <div class="pin-name"><span class="pin-tag" style="background:rgba(2,132,199,0.25);color:#7dd3fc;">Lecture Globale</span></div>
                </div>
            </summary>
            <div style="margin-top:2px;">{"".join(sub_rows)}</div>
        </details>""")

    # 3. Grouper les lectures inter-PRG par programme source (ex: PRG_03, PRG_04, ...)
    prg_reads_by_group = {}
    for p in reads.get("PRG_Inter", []):
        parts = p.split(".", 1)
        p_grp = parts[0]
        p_sub = parts[1] if len(parts) > 1 else p
        prg_reads_by_group.setdefault(p_grp, []).append((p, p_sub))

    for p_grp, items in sorted(prg_reads_by_group.items()):
        sub_rows = []
        for full_expr, sub_name in sorted(items):
            sub_rows.append(f"""
            <div class="pin-row pin-row-unwired" style="padding-left:16px;background:var(--card-sub);border-left:3px solid #6366f1;margin-top:2px;">
                <div class="pin-expr"><code style="color:#818cf8;background:rgba(99,102,241,0.15);font-size:11px;">{_html.escape(full_expr)}</code></div>
                <div class="pin-name"><span class="pin-tag" style="background:rgba(99,102,241,0.2);color:#c7d2fe;font-size:10px;">🔗 PRG In</span></div>
            </div>""")
        left_items.append(f"""
        <details style="margin:4px 0;">
            <summary style="list-style:none;cursor:pointer;">
                <div class="pin-row pin-row-unwired" style="background:rgba(99,102,241,0.15);border:1px solid #6366f1;cursor:pointer;">
                    <div class="pin-expr"><span style="color:#c7d2fe;font-weight:700;font-size:12px;">🔗 {_html.escape(p_grp)}</span> <span style="font-size:11px;color:#818cf8;">({len(items)} retours ▾)</span></div>
                    <div class="pin-name"><span class="pin-tag" style="background:rgba(99,102,241,0.25);color:#c7d2fe;">Inter-PRG</span></div>
                </div>
            </summary>
            <div style="margin-top:2px;">{"".join(sub_rows)}</div>
        </details>""")

    # 4. Nœuds / Équipements CODESYS (ex: CANbus, COD1_CODEUR, AC600_ECAT_Drive)
    dev_reads = reads.get("DEVICES", [])
    if dev_reads:
        sub_rows = []
        for p in dev_reads:
            sub_rows.append(f"""
            <div class="pin-row pin-row-unwired" style="padding-left:16px;background:var(--card-sub);border-left:3px solid #8b5cf6;margin-top:2px;">
                <div class="pin-expr"><code style="color:#a78bfa;background:rgba(139,92,246,0.15);font-size:11px;">{_html.escape(p)}</code></div>
                <div class="pin-name"><span class="pin-tag" style="background:rgba(139,92,246,0.2);color:#ddd6fe;font-size:10px;">📡 Device CODESYS</span></div>
            </div>""")
        left_items.append(f"""
        <details style="margin:4px 0;">
            <summary style="list-style:none;cursor:pointer;">
                <div class="pin-row pin-row-unwired" style="background:rgba(139,92,246,0.15);border:1px solid #8b5cf6;cursor:pointer;">
                    <div class="pin-expr"><span style="color:#ddd6fe;font-weight:700;font-size:12px;">📡 Arbre Matériel / Devices ({len(dev_reads)} équipements ▾)</span></div>
                    <div class="pin-name"><span class="pin-tag" style="background:rgba(139,92,246,0.25);color:#ddd6fe;">Nœud Système</span></div>
                </div>
            </summary>
            <div style="margin-top:2px;">{"".join(sub_rows)}</div>
        </details>""")

    # 5. Énumérations globales / Types Système (ex: DEVICE_STATE, E_Mode)
    enum_reads = reads.get("ENUMS", [])
    if enum_reads:
        sub_rows = []
        for p in enum_reads:
            sub_rows.append(f"""
            <div class="pin-row pin-row-unwired" style="padding-left:16px;background:var(--card-sub);border-left:3px solid #64748b;margin-top:2px;">
                <div class="pin-expr"><code style="color:#cbd5e1;background:rgba(100,116,139,0.2);font-size:11px;">{_html.escape(p)}</code></div>
                <div class="pin-name"><span class="pin-tag" style="background:rgba(100,116,139,0.25);color:#e2e8f0;font-size:10px;">🏷️ Enum / Type</span></div>
            </div>""")
        left_items.append(f"""
        <details style="margin:4px 0;">
            <summary style="list-style:none;cursor:pointer;">
                <div class="pin-row pin-row-unwired" style="background:rgba(100,116,139,0.18);border:1px solid #475569;cursor:pointer;">
                    <div class="pin-expr"><span style="color:#e2e8f0;font-weight:700;font-size:12px;">🏷️ Énumérations Globales</span> <span style="font-size:11px;color:#94a3b8;">({len(enum_reads)} constantes ▾)</span></div>
                    <div class="pin-name"><span class="pin-tag" style="background:rgba(100,116,139,0.3);color:#f1f5f9;">Type Global</span></div>
                </div>
            </summary>
            <div style="margin-top:2px;">{"".join(sub_rows)}</div>
        </details>""")

    constant_reads = reads.get("GLOBAL_CONSTANTS", [])
    if constant_reads:
        sub_rows = "".join(
            f'<span style="display:inline-block;margin:2px 4px 2px 0;padding:3px 6px;border:1px solid #d97706;border-radius:4px;color:#fde68a;font-family:monospace;font-size:11px;">{_html.escape(p)}</span>'
            for p in constant_reads
        )
        left_items.append(f"""
        <details style="margin:4px 0;">
            <summary style="list-style:none;cursor:pointer;">
                <div class="pin-row pin-row-wired" style="background:rgba(245,158,11,0.12);border:1px solid #d97706;cursor:pointer;">
                    <div class="pin-expr"><span style="color:#fde68a;font-weight:700;font-size:12px;">📐 Constantes globales CST_* ({len(constant_reads)} constantes ▾)</span></div>
                    <div class="pin-name"><span class="pin-tag" style="background:rgba(217,119,6,0.25);color:#fde68a;">VAR_GLOBAL CONSTANT</span></div>
                </div>
            </summary>
            <div style="padding:4px 8px;">{sub_rows}</div>
        </details>""")

    # 6. Variables rémanentes / Calibrations persistantes RETAIN (ex: _CalibM1, _WinchM1CfgPersist)
    retain_reads = reads.get("RETAIN_PERSIST", [])
    if retain_reads:
        sub_rows = []
        for p in retain_reads:
            sub_rows.append(f"""
            <div class="pin-row pin-row-unwired" style="padding-left:16px;background:var(--card-sub);border-left:3px solid #d97706;margin-top:2px;">
                <div class="pin-expr"><code style="color:#fcd34d;background:rgba(217,119,6,0.2);font-size:11px;">{_html.escape(p)}</code> <span style="font-size:10px;color:var(--muted);">[VAR_GLOBAL PERSISTENT RETAIN]</span></div>
                <div class="pin-name"><span class="pin-tag" style="background:rgba(217,119,6,0.25);color:#fde68a;font-size:10px;font-weight:700;">💾 RETAIN PERSISTANT</span></div>
            </div>""")
        left_items.append(f"""
        <details style="margin:4px 0;">
            <summary style="list-style:none;cursor:pointer;">
                <div class="pin-row pin-row-unwired" style="background:rgba(217,119,6,0.18);border:1px solid #92400e;cursor:pointer;">
                    <div class="pin-expr"><span style="color:#fde68a;font-weight:700;font-size:12px;">💾 Variables Rémanentes Persistantes / RETAIN</span> <span style="font-size:11px;color:#fcd34d;">({len(retain_reads)} variables ▾)</span></div>
                    <div class="pin-name"><span class="pin-tag" style="background:rgba(217,119,6,0.3);color:#fef3c7;font-weight:700;">VAR PERSISTENT</span></div>
                </div>
            </summary>
            <div style="margin-top:2px;">{"".join(sub_rows)}</div>
        </details>""")

    # 7. Variables externes réellement inconnues / non déclarées
    unres_reads = reads.get("EXTERNAL", [])
    if unres_reads:
        sub_rows = []
        for p in unres_reads:
            sub_rows.append(f"""
            <div class="pin-row pin-row-unwired" style="padding-left:16px;background:var(--card-sub);border-left:3px solid #e11d48;margin-top:2px;">
                <div class="pin-expr"><code style="color:#fda4af;background:rgba(225,29,72,0.2);font-size:11px;">{_html.escape(p)}</code></div>
                <div class="pin-name"><span class="pin-tag" style="background:rgba(225,29,72,0.25);color:#fecdd3;font-size:10px;">❓ Non Déclaré</span></div>
            </div>""")
        left_items.append(f"""
        <details style="margin:4px 0;">
            <summary style="list-style:none;cursor:pointer;">
                <div class="pin-row pin-row-unwired" style="background:rgba(225,29,72,0.18);border:1px solid #9f1239;cursor:pointer;">
                    <div class="pin-expr"><span style="color:#fecdd3;font-weight:700;font-size:12px;">❓ Inconnues / Non Déclarées</span> <span style="font-size:11px;color:#fda4af;">({len(unres_reads)} identifiants ▾)</span></div>
                    <div class="pin-name"><span class="pin-tag" style="background:rgba(225,29,72,0.3);color:#ffe4e6;">Alerte</span></div>
                </div>
            </summary>
            <div style="margin-top:2px;">{"".join(sub_rows)}</div>
        </details>""")

    # Sorties : regroupement clair par structure parente
    right_items = []
    # Indexer les sous-champs écrits par variable parente
    sub_writes_by_parent = {}
    for w in writes.get("VAR_OUTPUT", []):
        if "." in w:
            p_name, child = w.split(".", 1)
            sub_writes_by_parent.setdefault(p_name, []).append(child)

    for v, t in var_out.items():
        children = sub_writes_by_parent.get(v, [])
        if children:
            # En-tête dépliable de la structure (Fermé par défaut)
            children_rows = []
            for ch in sorted(children):
                children_rows.append(f"""
                <div class="pin-row pin-row-wired pin-row-out" style="padding-left:18px;background:var(--card-sub);border-left:3px solid #818cf8;margin-top:2px;">
                    <div class="pin-name" style="font-size:12px;color:#f8fafc;">↳ <b>{_html.escape(v)}</b>.{_html.escape(ch)}</div>
                    <div class="pin-expr"><span style="font-size:10.5px;color:var(--muted);">champ de {_html.escape(t)}</span></div>
                </div>""")
            
            right_items.append(f"""
            <details style="margin:4px 0;">
                <summary style="list-style:none;cursor:pointer;">
                    <div class="pin-row pin-row-wired pin-row-out" style="background:rgba(99,102,241,0.15);border:1px solid #6366f1;cursor:pointer;">
                        <div class="pin-name" style="color:#c7d2fe;font-size:12.5px;">📦 <b>{_html.escape(v)}</b> : <span class="pin-type" style="color:#818cf8;font-weight:700;">{_html.escape(t)}</span> <span style="font-size:11px;color:#a5b4fc;">({len(children)} champs ▾)</span></div>
                        <div class="pin-expr"><span style="color:#34d399;font-weight:700;font-size:10.5px;font-family:monospace;">[VAR_OUTPUT STRUCTURE]</span></div>
                    </div>
                </summary>
                <div style="margin-top:2px;">{"".join(children_rows)}</div>
            </details>""")
        else:
            right_items.append(f"""
            <div class="pin-row pin-row-wired pin-row-out" style="background:var(--surface);border:1px solid var(--border);margin:3px 0;">
                <div class="pin-name"><b>{_html.escape(v)}</b> <span class="pin-type" style="color:var(--accent);font-weight:600;">{_html.escape(t)}</span></div>
                <div class="pin-expr"><span style="color:#34d399;font-weight:700;font-family:monospace;">[VAR_OUTPUT]</span></div>
            </div>""")

    # Écritures transverses vers GVL groupées par GVL cible
    gvl_writes_by_group = {}
    for g in writes.get("GVL", []):
        parts = g.split(".", 1)
        g_grp = parts[0]
        g_sub = parts[1] if len(parts) > 1 else g
        gvl_writes_by_group.setdefault(g_grp, []).append((g, g_sub))

    for g_grp, items in sorted(gvl_writes_by_group.items()):
        sub_rows = []
        for full_expr, sub_name in sorted(items):
            sub_rows.append(f"""
            <div class="pin-row pin-row-unwired pin-row-out" style="padding-left:16px;background:var(--card-sub);border-left:3px solid #0284c7;margin-top:2px;">
                <div class="pin-name"><span class="pin-tag" style="background:rgba(2,132,199,0.2);color:#7dd3fc;font-size:10px;">🌐 GVL Out</span></div>
                <div class="pin-expr"><code style="color:#38bdf8;background:rgba(2,132,199,0.15);font-size:11px;">{_html.escape(full_expr)}</code></div>
            </div>""")
        right_items.append(f"""
        <details style="margin:4px 0;">
            <summary style="list-style:none;cursor:pointer;">
                <div class="pin-row pin-row-unwired pin-row-out" style="background:rgba(2,132,199,0.15);border:1px solid #0284c7;cursor:pointer;">
                    <div class="pin-name"><span style="color:#7dd3fc;font-weight:700;font-size:12px;">🌐 {_html.escape(g_grp)}</span> <span style="font-size:11px;color:#38bdf8;">({len(items)} écritures ▾)</span></div>
                    <div class="pin-expr"><span class="pin-tag" style="background:rgba(2,132,199,0.25);color:#7dd3fc;">Écriture Globale</span></div>
                </div>
            </summary>
            <div style="margin-top:2px;">{"".join(sub_rows)}</div>
        </details>""")

    if not left_items:
        left_items.append('<div class="pin-row"><div class="pin-missing">Aucune entrée directe</div></div>')
    if not right_items:
        right_items.append('<div class="pin-row pin-row-out"><div class="pin-missing">Aucune sortie directe</div></div>')

    sub_inst_badges = "".join(f'<span style="background:var(--card-sub);color:var(--accent);border:1px solid var(--border);font-size:12px;font-weight:700;padding:3px 8px;border-radius:6px;margin:2px;display:inline-block;font-family:monospace;">⚙️ {_html.escape(inst)} <span style="color:var(--muted);font-weight:500;">({_html.escape(t)})</span></span>' for inst, t in fb_instances.items())

    var_const = decls.get("VAR_CONSTANT", {})
    const_badges = "".join(f'<span style="background:var(--card-sub);color:#fbbf24;border:1px solid rgba(245,158,11,0.3);font-size:12px;font-weight:700;padding:3px 8px;border-radius:6px;margin:2px;display:inline-block;font-family:monospace;">📐 <b>{_html.escape(c_name)}</b> : {_html.escape(c_val)}</span>' for c_name, c_val in var_const.items())

    const_section = f"""
        <div style="margin:6px 0;font-size:13px;color:var(--muted);">
            <b>Constantes internes (VAR CONSTANT) :</b><br>
            <div style="margin-top:4px;">{const_badges}</div>
        </div>""" if const_badges else ""

    # Calcul des compteurs précis et du nom du POU
    pou_title = file_name.replace(".st", "")
    total_in_count = len(var_in) + len(var_inout) + len(hw_reads) + len(dev_reads) + len(enum_reads) + len(retain_reads) + sum(len(items) for items in gvl_reads_by_group.values()) + sum(len(items) for items in prg_reads_by_group.values()) + len(unres_reads)
    total_out_count = sum(len(children) for children in sub_writes_by_parent.values()) + sum(1 for v in var_out if v not in sub_writes_by_parent) + sum(len(items) for items in gvl_writes_by_group.values())

    # Détection du profil de contrat AF03 (§1bis) - Uniquement pour les FB
    in_keys = [v.upper() for v in var_in]
    out_keys = [v.upper() for v in var_out]

    has_enable = "ENABLE" in in_keys
    has_ready = "READY" in out_keys
    has_reset = "RESET" in in_keys
    has_status = "STATUS" in out_keys
    
    # Signaux de gestion de défauts / cycle de vie étendus ou tolérance transitoire T137
    has_flat_error = any(k in out_keys for k in ("ERROR", "ERRORID", "STATE", "STATEATEROR", "DONE", "BUSY", "WARNING"))

    is_prg = pou_title.startswith("PRG_")
    contract_info_html = ""
    if not is_prg:
        if has_enable and has_ready and has_reset and has_status:
            contract_badge = '<span style="background:rgba(16,185,129,0.18);color:#34d399;border:1px solid #059669;padding:3px 8px;border-radius:6px;font-size:11px;font-weight:800;letter-spacing:0.5px;">CONTRAT STANDARD AF03</span>'
            contract_desc = "✅ Enable + Reset + Ready + Status (ST_Status complet)"
        elif has_enable and (has_ready or "DONE" in out_keys) and (has_reset or has_flat_error):
            contract_badge = '<span style="background:rgba(245,158,11,0.18);color:#fbbf24;border:1px solid #d97706;padding:3px 8px;border-radius:6px;font-size:11px;font-weight:800;letter-spacing:0.5px;">CONTRAT STANDARD (Tolérance T137 Flat)</span>'
            contract_desc = "⚠️ Signaux à plat (Reset/Error/Busy/Done) sans ST_Status"
        elif has_enable and has_ready:
            contract_badge = '<span style="background:rgba(16,185,129,0.18);color:#34d399;border:1px solid #059669;padding:3px 8px;border-radius:6px;font-size:11px;font-weight:800;letter-spacing:0.5px;">CONTRAT LIGHT AF03</span>'
            contract_desc = "✅ Enable + Ready (Calculateur / Brique sans défaut)"
        else:
            contract_badge = '<span style="background:var(--card-sub);color:var(--text);border:1px solid var(--border);padding:3px 8px;border-radius:6px;font-size:11px;font-weight:800;letter-spacing:0.5px;">PROFIL TECHNIQUE SPÉCIFIQUE</span>'
            contract_desc = "Brique utilitaire / Interface sur-mesure"

        contract_info_html = f"""
        <div style="margin: 8px 0 4px 0;">{contract_badge}</div>
        <div style="font-size: 11px; color: var(--muted); margin-bottom: 8px; font-weight: 500;">{contract_desc}</div>"""

    # Structure & Qualité du code ST (En-tête et bannières requises pour FB et PRG)
    sq = analysis.get("structure_quality", {})
    hdr_ok = sq.get("has_header_comment", True)
    in_b_ok = sq.get("has_var_input_banner", True)
    out_b_ok = sq.get("has_var_output_banner", True)
    loc_b_ok = sq.get("has_var_local_banner", True)
    all_struct_ok = hdr_ok and in_b_ok and out_b_ok and loc_b_ok

    struct_status_html = f"""
    <div style="margin-top:8px;padding:8px 10px;background:var(--card-sub);border:1px solid var(--border);border-radius:6px;font-size:11px;text-align:left;color:#f1f5f9;font-weight:normal;">
        <div style="font-weight:800;color:var(--accent);margin-bottom:4px;border-bottom:1px solid var(--border);padding-bottom:2px;font-size:11.5px;">📋 Structure ST :</div>
        <div>{'✅' if hdr_ok else '❌'} Cartouche En-tête <code>(* === *)</code></div>
        <div>{'✅' if in_b_ok else '❌'} Bannière <code>VAR_INPUT</code></div>
        <div>{'✅' if out_b_ok else '❌'} Bannière <code>VAR_OUTPUT</code></div>
        <div>{'✅' if loc_b_ok else '❌'} Bannière <code>VAR</code> locale</div>
    </div>"""

    pou_badge_type = '<span style="display:inline-block;padding:3px 10px;border-radius:6px;font-size:12px;font-weight:800;letter-spacing:0.6px;background:rgba(99,102,241,0.2);color:#c7d2fe;border:1px solid #818cf8;margin-left:8px;font-family:monospace;">POU PRINCIPAL</span>'
    return f"""
    <details class="pin-diagram-details" open>
        <summary>📦 Représentation Bloc & Boîte Noire I/O — <b>{_html.escape(pou_title)}</b> {pou_badge_type} <span style="font-size:13px;color:var(--muted);font-weight:600;margin-left:8px;">(📊 {total_in_count} flux entrants · {total_out_count} flux sortants)</span></summary>
        <div style="margin:10px 0 6px 0;font-size:13px;color:var(--muted);">
            <b>Sous-instances actives intégrées :</b><br>
            <div style="margin-top:4px;">{sub_inst_badges or '(aucune)'}</div>
        </div>
        {const_section}
        <div class="pin-diagram" style="background: var(--card-sub); border: 1px solid var(--border); border-radius: 8px; padding: 12px;">
            <div class="pin-col pin-col-in">{"".join(left_items)}</div>
            <div class="pin-block" style="min-width: 220px; background: var(--surface-card); border: 2px solid var(--accent); color: var(--text); font-size: 13px; letter-spacing: 0.3px; padding: 14px 10px; border-radius: 10px; box-shadow: 0 4px 20px rgba(0,0,0,0.35);">
                <span style="font-weight:900;font-size:15px;color:#c7d2fe;font-family:monospace;">{_html.escape(pou_title)}</span>
                {contract_info_html}
                
                <div style="margin-top:8px;padding:8px 10px;background:var(--card-sub);border:1px solid var(--border);border-radius:6px;width:100%;font-size:11.5px;text-align:left;color:#e2e8f0;font-weight:normal;">
                    <div style="color:var(--accent);font-weight:800;border-bottom:1px solid var(--border);padding-bottom:3px;margin-bottom:4px;font-size:12px;">📊 Métriques I/O :</div>
                    <div>• Entrées Formelles : <b style="color:#ffffff;">{len(var_in) + len(var_inout)}</b></div>
                    <div>• Entrées Physiques : <b style="color:#ffffff;">{len(hw_reads)}</b></div>
                    <div>• Lectures GVL : <b style="color:#ffffff;">{sum(len(items) for items in gvl_reads_by_group.values())}</b></div>
                    <div>• Retours PRG : <b style="color:#ffffff;">{sum(len(items) for items in prg_reads_by_group.values())}</b></div>
                    <div>• Calibrations RETAIN : <b style="color:#ffffff;">{len(retain_reads)}</b></div>
                    <div style="border-top:1px solid var(--border);margin-top:4px;padding-top:2px;">• Structures Out : <b style="color:#ffffff;">{len(var_out)}</b></div>
                    <div>• Champs Out : <b style="color:#ffffff;">{sum(len(children) for children in sub_writes_by_parent.values())}</b></div>
                    <div>• Écritures GVL : <b style="color:#ffffff;">{sum(len(items) for items in gvl_writes_by_group.values())}</b></div>
                    <div style="border-top:1px solid var(--border);margin-top:6px;padding-top:4px;font-weight:800;color:#38bdf8;font-size:12px;">Total : <b style="color:#ffffff;">{total_in_count} IN</b> / <b style="color:#ffffff;">{total_out_count} OUT</b></div>
                </div>
                {struct_status_html}
            </div>
            <div class="pin-col pin-col-out">{"".join(right_items)}</div>
        </div>
    </details>"""


def _render_pin_diagram(fb_name: str, wiring: dict | None, label: str | None = None) -> str:
    """Bloc pinout FBD-like : pins IN/IN_OUT a gauche, OUT a droite, autour d'un rectangle
    central portant le nom du FB. L'interface (liste/type/ordre des pins) vient exclusivement
    du compilateur (generated.hpp, via prod_wiring.extract_pins) -- jamais du .st. Le cablage
    affiche a cote de chaque pin (expression reelle en production) vient du point
    d'instanciation .st -- seule source qui la connaisse. Non bloquant : degrade en pinout nu
    si aucun cablage de production n'est configure/trouve. `label` distingue plusieurs
    instances production d'un meme FB (ex: instEncoderM1/instEncoderM2) -- un bloc par
    instance, chacun avec son propre cablage reel."""
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
        is_constant = wired and wired.upper() in ("TRUE", "FALSE")
        source_label = "Constante" if is_constant else "Source production"
        expr_html = (f'<span style="color:var(--muted);font-size:10px;margin-right:4px;">{source_label} :</span>'
                     f'<code title="{_html.escape(wired)}" onclick="copyPinExpr(this)">{_html.escape(wired)}</code>'
                     if wired else "<span class='pin-missing'>⚠ non câblé en production</span>")
        tag_html = f"<span class='pin-tag'>{tag}</span>" if tag else ""
        # Nom du pin en dernier -> reste colle au bloc (colonne IN justifiee a droite)
        return f"""<div class="pin-row {cls}">
            <div class="pin-expr">{expr_html} <span style="color:var(--muted);">→</span></div>
            <div class="pin-name">IN {_html.escape(name)}{tag_html} <span class="pin-type">{_html.escape(ftype)}</span></div>
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
            <div class="pin-name">OUT {_html.escape(name)} <span class="pin-type">{_html.escape(ftype)}</span></div>
            <div class="pin-expr"><span style="color:var(--muted);">→ Consommateur :</span> {expr_html}</div>
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

    pastille = (f'<span class="wiring-pastille wiring-pastille-warn" title="Écart(s) interface ↔ câblage '
                f'production — informatif, n\'impacte pas le résultat du rapport">⚠️ {n_warn} écart{"s" if n_warn > 1 else ""}</span>'
                if n_warn else
                '<span class="wiring-pastille wiring-pastille-ok" title="Interface entièrement câblée en production">✓ 0 écart</span>')
    summary_txt = (f"🔌 Interface & câblage production — {_html.escape(label)} {pastille}" if label
                   else f"🔌 Interface & câblage production {pastille}")
    block_label = f"{_html.escape(fb_name)} ({_html.escape(label)})" if label else _html.escape(fb_name)
    return f"""
    <details class="pin-diagram-details">
        <summary>{summary_txt}</summary>
        {warnings_html}
        <div style="display:grid;grid-template-columns:1fr 220px 1fr;gap:0;padding:0 8px 3px;font-size:10px;font-weight:800;color:var(--muted);text-transform:uppercase;letter-spacing:.05em;"><div style="text-align:right;padding-right:10px;">Source production → Entrées FB</div><div style="text-align:center;">Composant</div><div style="padding-left:10px;">Sorties FB → Consommateurs</div></div>
        <div class="pin-diagram">
            <div class="pin-col pin-col-in">{left_html}</div>
            <div class="pin-block">{block_label}</div>
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
            sec_id = f"fb-section-{title.lower()}"
            parts.append(f'<div class="toc-group-title"><a href="#{sec_id}" style="color:var(--accent);text-decoration:none;font-weight:800;font-size:13px;display:flex;align-items:center;gap:6px;">📦 {_html.escape(title)} <span style="font-size:11px;font-weight:normal;color:var(--muted);">➔ sauter au bloc</span></a></div>')
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
                        wirings=None, encapsulation_report=None, source_prg=None) -> str:
    """Rapport HTML autonome pour UN SEUL FB ou UN SEUL PROGRAMME."""
    section = _render_fb_section(fb_name, domain, sources, json_data, text_report, test_st_path,
                                  trace_entries, source_paths, cycle_time_ms, field_types,
                                  af_warnings, extra_test_warnings, wirings, encapsulation_report, source_prg=source_prg)
    exec_time = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    toc_html = _render_toc([(None, section["toc_entries"])])
    inner = f"""
    <div class="header">
        <div>
            <h1>{_html.escape(fb_name)}</h1>
        </div>
        <div style="display:flex;align-items:center;gap:12px;">
            <a class="btn-index" href="../../../index.html" title="Retour à l'index général (tous les tests)">⬅ Index</a>
            <button class="theme-toggle-btn" onclick="toggleTheme()">☀️ Mode Clair</button>
            {_badge(section['all_pass'])}
        </div>
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
    # Tri rigoureusement identique à l'index (ordre alphabétique / hiérarchique uniforme)
    sorted_sections_kw = sorted(fb_sections, key=lambda s: s.get("fb_name", ""))
    sections = [_render_fb_section(**kw) for kw in sorted_sections_kw]
    exec_time = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    all_pass = all(s["all_pass"] for s in sections)
    n_pass = sum(1 for s in sections if s["all_pass"])

    body_parts = []
    for s in sections:
        sec_id = f"fb-section-{s['fb_name'].lower()}"
        body_parts.append(f"""
    <div id="{sec_id}" class="fb-section-title" style="scroll-margin-top:20px;">
        <span style="font-family:monospace;font-size:18px;font-weight:900;color:var(--text);">📦 {_html.escape(s['fb_name'])}</span> {_badge(s['all_pass'])}
    </div>
    {s['body_html']}""")

    toc_html = _render_toc([(s["fb_name"], s["toc_entries"]) for s in sections])

    inner = f"""
    <div class="header">
        <div>
            <h1>{_html.escape(group_name)}</h1>
        </div>
        <div style="display:flex;align-items:center;gap:12px;">
            <a class="btn-index" href="../../../index.html" title="Retour à l'index général (tous les tests)">⬅ Index</a>
            <button class="theme-toggle-btn" onclick="toggleTheme()">☀️ Mode Clair</button>
            {_badge(all_pass)}
        </div>
    </div>
    <div class="exec-time">{n_pass}/{len(sections)} FB OK · {exec_time}</div>
    {toc_html}
    {"".join(body_parts)}"""
    title = f"Rapport de test — {group_name} [{'PASS' if all_pass else 'FAIL'}]"
    return _page_shell(title, inner, all_pass=all_pass)


def render_index_dashboard(results: dict, group_report_paths: dict) -> str:
    """Génère une page d'accueil / dashboard index.html à la racine de TEST_AUTO_CI
    listant tous les domaines, programmes (PRG), briques (FB) et liens d'accès direct."""
    exec_time = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    total_fbs = len(results)
    n_pass = sum(1 for r in results.values() if r.get("ok"))
    n_fail = total_fbs - n_pass
    all_pass = n_fail == 0

    # Découverte dynamique de l'ordre officiel des dossiers réels depuis CODE/
    repo_root = pathlib.Path(__file__).resolve().parents[3]
    code_dir = repo_root / "CODE"
    if code_dir.exists():
        official_code_folders = [p.name for p in sorted(code_dir.iterdir()) if p.is_dir()]
    else:
        official_code_folders = []

    # Regroupement par domaine
    by_domain = {}
    for name, r in sorted(results.items()):
        domain = r.get("section_kwargs", {}).get("domain", "AUTRES")
        by_domain.setdefault(domain, []).append((name, r))

    def _domain_sort_key(d: str):
        if d in official_code_folders:
            return (0, official_code_folders.index(d))
        # Fallback si préfixe partiel ou nom sans lettre
        for idx, f in enumerate(official_code_folders):
            if d.lower() in f.lower() or f.lower() in d.lower():
                return (0, idx)
        return (1, d)

    domain_cards = []
    for domain, items in sorted(by_domain.items(), key=lambda kv: _domain_sort_key(kv[0])):
        dom_pass = sum(1 for _, r in items if r.get("ok"))
        dom_total = len(items)
        dom_ok = dom_pass == dom_total

        rows = []
        for name, r in items:
            ok = r.get("ok", False)
            tests = r.get("tests", [])
            n_t_pass = sum(1 for t in tests if t.get("passed"))
            is_prg = name.startswith("PRG_")

            report_file = r.get("report")
            if report_file:
                p_rep = pathlib.Path(report_file)
                if "RESULTS" in p_rep.parts:
                    idx_res = p_rep.parts.index("RESULTS")
                    rel_link = "/".join(p_rep.parts[idx_res:])
                else:
                    rel_link = f"RESULTS/{domain}/reports/{p_rep.name}"
            else:
                rel_link = f"RESULTS/{domain}/reports/{name}.html"

            type_badge = (
                '<span style="background:rgba(6,182,212,0.35);color:#ffffff;border:1.5px solid #22d3ee;font-size:13.5px;padding:4px 10px;border-radius:6px;font-weight:900;letter-spacing:0.8px;font-family:monospace;box-shadow:0 0 10px rgba(6,182,212,0.4);">⚡ PRG</span>'
                if is_prg else
                '<span style="background:rgba(168,85,247,0.35);color:#ffffff;border:1.5px solid #c084fc;font-size:13.5px;padding:4px 10px;border-radius:6px;font-weight:900;letter-spacing:0.8px;font-family:monospace;box-shadow:0 0 10px rgba(168,85,247,0.4);">⚙️ FB</span>'
            )

            rows.append(f"""
            <tr style="border-bottom: 1px solid var(--border);">
                <td style="padding: 12px 14px; width:90px;">{_badge(ok)}</td>
                <td style="padding: 12px 14px;">
                    <div style="display:flex;align-items:center;gap:12px;flex-wrap:wrap;">
                        {type_badge}
                        <a href="{rel_link}" style="font-family:monospace;font-size:16px;font-weight:800;color:#e2e8f0;text-decoration:none;letter-spacing:0.3px;">{_html.escape(name)}</a>
                        <span style="font-size:13px;font-weight:700;color:var(--muted);background:var(--card-sub);padding:3px 10px;border-radius:6px;border:1px solid var(--border);">{n_t_pass}/{len(tests)} test(s) OK</span>
                    </div>
                </td>
                <td style="padding: 12px 14px;text-align:right;"><a href="{rel_link}" style="display:inline-block;padding:6px 14px;background:var(--btn-bg);border:1px solid var(--btn-border);border-radius:6px;font-size:12.5px;font-weight:700;color:var(--text);text-decoration:none;">Ouvrir Rapport ➔</a></td>
            </tr>""")

        domain_neon_cls = "card-neon-ok" if dom_ok else "card-neon-fail"
        domain_cards.append(f"""
        <div class="{domain_neon_cls}" style="background:var(--surface);border-radius:12px;padding:20px 24px;margin-bottom:22px;transition:all 0.2s ease;">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;border-bottom:1px solid var(--border);padding-bottom:12px;">
                <h2 style="margin:0;font-size:19px;font-weight:800;color:var(--text);display:flex;align-items:center;gap:10px;">📁 <span style="color:var(--accent);font-family:monospace;font-weight:800;">CODE/{_html.escape(domain)}</span></h2>
                <div style="display:flex;align-items:center;gap:10px;">{_badge(dom_ok)} <span style="font-size:14px;color:var(--muted);font-weight:700;">{dom_pass}/{dom_total} composant(s)</span></div>
            </div>
            <table style="width:100%;border-collapse:collapse;font-size:14px;">
                <tbody>{"".join(rows)}</tbody>
            </table>
        </div>""")

    header_neon = "card-neon-ok" if all_pass else "card-neon-fail"
    inner = f"""
    <div class="header {header_neon}" style="justify-content:space-between;">
        <div>
            <h1 style="display:flex;align-items:center;gap:14px;font-size:32px;font-weight:900;letter-spacing:-0.5px;">⚡ DASHBOARD <span style="font-size:20px;color:var(--accent);font-weight:800;font-family:monospace;">TEST_AUTO_CI</span></h1>
            <div style="color:var(--muted);font-size:15px;font-weight:600;margin-top:6px;">Excavatrice de Dragage · Validation Automate CODESYS 3.5 & STruCpp</div>
        </div>
        <div style="display:flex;align-items:center;gap:16px;">
            <button class="theme-toggle-btn" onclick="toggleTheme()" style="font-size:14px;padding:9px 18px;">☀️ Mode Clair</button>
            {_badge(all_pass, strong=True)}
        </div>
    </div>
    <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(220px, 1fr));gap:16px;margin:24px 0;">
        <div class="card-neon-blue" style="background:var(--surface);border-radius:12px;padding:18px;text-align:center;">
            <div style="font-size:30px;font-weight:900;color:var(--accent);font-family:monospace;">{total_fbs}</div>
            <div style="font-size:12px;color:var(--muted);text-transform:uppercase;font-weight:800;letter-spacing:0.6px;margin-top:2px;">POU & Composants</div>
        </div>
        <div class="card-neon-ok" style="background:var(--surface);border-radius:12px;padding:18px;text-align:center;">
            <div style="font-size:30px;font-weight:900;color:var(--green-text);font-family:monospace;">{n_pass}</div>
            <div style="font-size:12px;color:var(--muted);text-transform:uppercase;font-weight:800;letter-spacing:0.6px;margin-top:2px;">Succès (PASS)</div>
        </div>
        <div class="{'card-neon-fail' if n_fail > 0 else ''}" style="background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:18px;text-align:center;">
            <div style="font-size:30px;font-weight:900;color:{'var(--red-text)' if n_fail > 0 else 'var(--muted)'};font-family:monospace;">{n_fail}</div>
            <div style="font-size:12px;color:var(--muted);text-transform:uppercase;font-weight:800;letter-spacing:0.6px;margin-top:2px;">Échecs (FAIL)</div>
        </div>
        <div style="background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:18px;text-align:center;">
            <div style="font-size:16px;font-weight:800;color:var(--text);margin-top:8px;font-family:monospace;">{exec_time}</div>
            <div style="font-size:12px;color:var(--muted);text-transform:uppercase;font-weight:800;letter-spacing:0.6px;margin-top:2px;">Horodatage Exécution</div>
        </div>
    </div>
    {"".join(domain_cards)}
    """
    return _page_shell("TEST_AUTO_CI — Tableau de Bord Global", inner, all_pass=all_pass)
