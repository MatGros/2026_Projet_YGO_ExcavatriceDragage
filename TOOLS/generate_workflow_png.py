#!/usr/bin/env python3
"""Genere les diagrammes workflow PNG sans serveur externe (Pillow pur).
Tous les caracteres sont ASCII pur pour eviter les problemes de police."""

from __future__ import annotations
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W       = 900
PAD     = 40
BOX_W   = 820
LANE_W  = 248
LANE_GAP= 13
BOX_R   = 14
ARROW_W = 2
LINE_H  = 22

COLORS = {
    "entrees":    "#BBDEFB",
    "qualif":     "#FFF9C4",
    "fast":       "#DCEDC8",
    "standard":   "#B3E5FC",
    "safety":     "#FFCCBC",
    "validation": "#F8BBD0",
    "trace":      "#E1BEE7",
    "note":       "#FFFDE7",
    "border":     "#78909C",
    "arrow":      "#37474F",
    "bg":         "#FFFFFF",
    "title":      "#263238",
    "text":       "#212121",
    "ab":         "#FFCDD2",
    "result":     "#EF9A9A",
    "alert":      "#FFAB91",
    "code":       "#FFFDE7",
}

def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def try_font(size, bold=False):
    candidates = [
        "C:/Windows/Fonts/segoeui.ttf"  if not bold else "C:/Windows/Fonts/segoeuib.ttf",
        "C:/Windows/Fonts/arial.ttf"    if not bold else "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/calibri.ttf"  if not bold else "C:/Windows/Fonts/calibrib.ttf",
        "C:/Windows/Fonts/verdana.ttf"  if not bold else "C:/Windows/Fonts/verdanab.ttf",
    ]
    for p in candidates:
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            pass
    return ImageFont.load_default()

def rounded_rect(draw, xy, fill, border="#78909C"):
    draw.rounded_rectangle(xy, radius=BOX_R,
                            fill=hex2rgb(fill),
                            outline=hex2rgb(border), width=2)

def draw_text_block(draw, lines_data, cx, y):
    """lines_data = [(text, font, color_hex), ...]  — centre sur cx"""
    cy = y
    for text, font, color in lines_data:
        bb = draw.textbbox((0, 0), text, font=font)
        tw = bb[2] - bb[0]
        th = bb[3] - bb[1]
        draw.text((cx - tw // 2, cy), text, font=font, fill=hex2rgb(color))
        cy += th + 5
    return cy

def box_h(n_lines):
    return 14 + n_lines * LINE_H

def arrow_down(draw, cx, y0, y1, color="#37474F"):
    c = hex2rgb(color)
    draw.line([(cx, y0), (cx, y1 - 8)], fill=c, width=ARROW_W)
    draw.polygon([(cx-6, y1-8), (cx+6, y1-8), (cx, y1)], fill=c)

def arrow_diag(draw, x0, y0, x1, y1, color="#37474F"):
    c = hex2rgb(color)
    draw.line([(x0, y0), (x1, y1 - 8)], fill=c, width=ARROW_W)
    draw.polygon([(x1-6, y1-8), (x1+6, y1-8), (x1, y1)], fill=c)


# ── VUE 1 : OVERVIEW ─────────────────────────────────────────────────────────
def draw_overview(path: Path):
    fn   = try_font(13)
    fn_b = try_font(14, bold=True)
    fn_s = try_font(12)
    fn_t = try_font(17, bold=True)

    img  = Image.new("RGB", (W, 1100), hex2rgb(COLORS["bg"]))
    draw = ImageDraw.Draw(img)
    cx   = W // 2
    y    = PAD

    # Titre
    title = "Workflow de Developpement - Vue d ensemble"
    bb = draw.textbbox((0,0), title, font=fn_t)
    draw.text((cx - (bb[2]-bb[0])//2, y), title, font=fn_t, fill=hex2rgb(COLORS["title"]))
    y += 42

    def block(lines_data, color, y_cur):
        n = len(lines_data)
        bh = box_h(n)
        rounded_rect(draw, (PAD, y_cur, PAD+BOX_W, y_cur+bh), color)
        draw_text_block(draw, lines_data, cx, y_cur + 8)
        return y_cur + bh

    # ENTREES
    y = block([("ENTREES", fn_b, COLORS["text"]),
               ("CODE_CHANGE  ou  NEW_INFORMATION", fn, COLORS["text"])],
              COLORS["entrees"], y)
    arrow_down(draw, cx, y, y+28); y += 28

    # QUALIFICATION
    y = block([("QUALIFICATION  C0-C4", fn_b, COLORS["text"]),
               ("Pi propose la criticite", fn, COLORS["text"]),
               ("Humain valide en 1 mot", fn, COLORS["text"])],
              COLORS["qualif"], y)
    qual_bot = y
    y += 10

    # Labels voies
    lx = [PAD + LANE_W//2,
          PAD + LANE_W + LANE_GAP + LANE_W//2,
          PAD + 2*(LANE_W+LANE_GAP) + LANE_W//2]
    LANE_Y = qual_bot + 40

    for x_l, lbl in zip(lx, ["C0-C1", "C2-C3", "C4"]):
        arrow_diag(draw, cx, qual_bot, x_l, LANE_Y)
        bb = draw.textbbox((0,0), lbl, font=fn_s)
        mx = (cx + x_l)//2
        my = (qual_bot + LANE_Y)//2 - 14
        draw.text((mx - (bb[2]-bb[0])//2, my), lbl, font=fn_s, fill=hex2rgb(COLORS["arrow"]))

    # 3 LANES
    lane_content = [
        ("FAST LANE  [C0-C1]", COLORS["fast"],
         ["Pre-edit Gate", "Plan + Code  Pi seul", "Gates 1 a 4", "Pas de multi-modele"]),
        ("STANDARD LANE  [C2-C3]", COLORS["standard"],
         ["Registre + Task (proposes)", "Code Pi fort", "Gates 1 a 5", "Revue 1 agent Herdr"]),
        ("SAFETY LANE  [C4]", COLORS["safety"],
         ["Registre+Task+TestDesign", "OBLIGATOIRES", "ALERTE RISQUES explicite",
          "Code ST  High Effort", "Gates 1 a 5", "DOUBLE REVUE  A/B"]),
    ]
    max_bh = max(box_h(len(c)+1) for _,_,c in lane_content)
    lane_bots = []
    for i, (title_l, color_l, lines_l) in enumerate(lane_content):
        x0 = PAD + i*(LANE_W+LANE_GAP)
        x1 = x0 + LANE_W
        rounded_rect(draw, (x0, LANE_Y, x1, LANE_Y+max_bh), color_l)
        lx_i = (x0+x1)//2
        ld = [(title_l, fn_b, COLORS["text"])] + [(l, fn, COLORS["text"]) for l in lines_l]
        draw_text_block(draw, ld, lx_i, LANE_Y+8)
        lane_bots.append(LANE_Y + max_bh)

    bot_lane = max(lane_bots)
    y = bot_lane + 30
    for x_l in lx:
        arrow_diag(draw, x_l, bot_lane, cx, y+8)
    y += 8

    # VALIDATION
    y = block([("VALIDATION HUMAINE", fn_b, COLORS["text"]),
               ("CODESYS Import + Build", fn, COLORS["text"]),
               ("Simulation PLC_TESTS", fn, COLORS["text"]),
               ("Terrain  FAT / SAT", fn, COLORS["text"])],
              COLORS["validation"], y)
    arrow_down(draw, cx, y, y+28); y += 28

    # TRACABILITE
    y = block([("TRACABILITE", fn_b, COLORS["text"]),
               ("fix + guard", fn, COLORS["text"]),
               ("WORKFLOW.md (double boucle)", fn, COLORS["text"]),
               ("VERSION_HISTORY + PLAN_TASK", fn, COLORS["text"])],
              COLORS["trace"], y)
    y += 16

    # Note erreur centree
    nw, nh = 310, 52
    nx = cx - nw//2
    rounded_rect(draw, (nx, y, nx+nw, y+nh), COLORS["note"], "#F9A825")
    draw.text((nx+12, y+8),  "Erreur a toute etape", font=fn_s, fill=hex2rgb(COLORS["text"]))
    draw.text((nx+12, y+27), "-> retour QUALIFICATION", font=fn_s, fill=hex2rgb("#B71C1C"))
    y += nh + 16

    img = img.crop((0, 0, W, y))
    img.save(path, "PNG", dpi=(150, 150))
    print(f"[OK] {path.name}  {img.width}x{img.height}px")


# ── VUE 2 : SAFETY DETAIL ────────────────────────────────────────────────────
def draw_safety_detail(path: Path):
    fn   = try_font(13)
    fn_b = try_font(14, bold=True)
    fn_s = try_font(12)
    fn_t = try_font(17, bold=True)

    W2 = 820
    img  = Image.new("RGB", (W2, 1050), hex2rgb(COLORS["bg"]))
    draw = ImageDraw.Draw(img)
    cx   = W2 // 2
    y    = PAD
    BW   = W2 - 2*PAD

    title = "Safety Lane C4 - Detail"
    bb = draw.textbbox((0,0), title, font=fn_t)
    draw.text((cx - (bb[2]-bb[0])//2, y), title, font=fn_t, fill=hex2rgb(COLORS["title"]))
    y += 42

    def block(lines_data, color, y_cur):
        n = len(lines_data)
        bh = box_h(n)
        rounded_rect(draw, (PAD, y_cur, PAD+BW, y_cur+bh), color)
        draw_text_block(draw, lines_data, cx, y_cur + 8)
        return y_cur + bh

    def ld(title_s, rest, fn_b=fn_b, fn=fn):
        return [(title_s, fn_b, COLORS["text"])] + [(l, fn, COLORS["text"]) for l in rest]

    # ARTEFACTS
    y = block(ld("ARTEFACTS OBLIGATOIRES", [
        "REGISTRE_ACTIONS (sas audit -> PLAN_TASK)",
        "TASK_CONTEXT.yaml (perimetre + criteres + hors-scope)",
        "TEST_DESIGN.md (matrice TC avant tout code)",
    ]), COLORS["safety"], y)
    arrow_down(draw, cx, y, y+26); y += 26

    # ALERTE
    y = block(ld("ALERTE RISQUES", [
        "Pi liste explicitement les risques",
        "Humain valide les 3 artefacts avant de continuer",
    ]), COLORS["alert"], y)
    arrow_down(draw, cx, y, y+26); y += 26

    # CODE ST
    y = block(ld("CODE ST - Pi High Effort", [
        "Guardrails AGENTS.md + NAMING_CONVENTION",
        "PascalCase - Interface FB - Reset sur front obligatoire",
        "Ponytail INTERDIT (sujet safety)",
    ]), COLORS["code"], y)
    arrow_down(draw, cx, y, y+26); y += 26

    # GATES
    y = block(ld("GATES DETERMINISTES  1 -> 5", [
        "Gate 1: Structure   Gate 2: Style   Gate 3: Bundle",
        "Gate 4: PyTest (306 tests)   Gate 5: Compilation CODESYS",
    ]), COLORS["fast"], y)

    # Double revue A/B
    ab_y = y + 30
    abw  = (BW - LANE_GAP) // 2
    lx_ab = [PAD + abw//2, PAD + abw + LANE_GAP + abw//2]
    for x_l in lx_ab:
        arrow_diag(draw, cx, y, x_l, ab_y)
    for i, (agent, note) in enumerate([("AGENT A", "Ne voit pas B"),
                                        ("AGENT B", "Ne voit pas A")]):
        x0 = PAD + i*(abw+LANE_GAP)
        bh = box_h(3)
        rounded_rect(draw, (x0, ab_y, x0+abw, ab_y+bh), COLORS["ab"])
        draw_text_block(draw, [
            (agent, fn_b, COLORS["text"]),
            ("Revue read-only", fn, COLORS["text"]),
            (note, fn_s, "#546E7A"),
        ], x0+abw//2, ab_y+8)

    ab_bot = ab_y + box_h(3)
    y = ab_bot + 30
    for x_l in lx_ab:
        arrow_diag(draw, x_l, ab_bot, cx, y+8)
    y += 8

    # RESULTAT
    y = block(ld("RESULTAT A/B", [
        "Consensus  ->  synthese presentee a l humain",
        "Divergence  ->  ALERTE + positions A vs B cote a cote",
    ]), COLORS["result"], y)
    arrow_down(draw, cx, y, y+26); y += 26

    # VALIDATION
    y = block(ld("VALIDATION HUMAINE", [
        "CODESYS Import + Build",
        "Simulation PLC_TESTS",
        "Terrain  FAT / SAT",
    ]), COLORS["validation"], y)
    y += 20

    img = img.crop((0, 0, W2, y))
    img.save(path, "PNG", dpi=(150, 150))
    print(f"[OK] {path.name}  {img.width}x{img.height}px")


if __name__ == "__main__":
    out = Path("DOC/DIAGRAMS/TOOLS")
    out.mkdir(parents=True, exist_ok=True)
    draw_overview(out / "DIAG_WF_Overview.png")
    draw_safety_detail(out / "DIAG_WF_SafetyDetail.png")
