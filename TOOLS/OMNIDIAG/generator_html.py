"""
===============================================================================
🌐 OMNIDIAG — Générateur de l'Explorateur Interactif Web (HTML/CSS/JS)
===============================================================================
🎯 Rôle : Produit une application web monopage autonome avec :
   1. Recherche & filtres instantanés
   2. Bouton d'export CSV / Excel direct de la sélection filtrée
   3. Bouton de régénération / re-scan du code ST en un clic
   4. Données ST fiables strictes (zéro invention) et formulaire de saisie/co-construction
   5. Modale synoptique « Face Avant Automate VEICHI » :
      - Slot 1 (CPU) : 2 rangées de LEDs (Gauche = DI, Droite = DQ)
      - Slot 2 (VH_0808ETP) : 2 rangées de LEDs (Gauche = DI, Droite = DQ)
      - Slot 3 (VH_0800END) : 1 rangée de LEDs (8 DI)
      - Slot 4 (VH_0008ER) : 1 rangée de LEDs (8 DO relais)
      - Slot 5 (VH_0008ER_1) : 1 rangée de LEDs (8 DO relais)
   6. Chariot / Curseur de déplacement horizontal du rack + Mode Grille Multiligne
   7. Boutons de repérage direct de LED depuis les fiches d'alarmes (clignotement cible)
===============================================================================
"""

import json
from pathlib import Path
from typing import List, Dict, Any, Optional


def generate_html_viewer(items: List[Dict[str, Any]], output_path: Path, rack_data: Optional[Dict[str, Any]] = None):
    """Génère l'application HTML autonome interactive."""
    if rack_data is None:
        try:
            import io_mapper
            rack_data = io_mapper.parse_rack_io(output_path.parents[2])
        except Exception:
            rack_data = {"modules": [], "source_file": "N/A", "by_var": {}, "by_addr": {}}

    items_json = json.dumps(items, ensure_ascii=False)
    rack_json = json.dumps(rack_data, ensure_ascii=False)

    html_content = f"""<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>OMNIDIAG — Diagnostics & Alarmes CODESYS</title>
  <style>
    :root {{
      --bg-main: #0f172a;
      --bg-card: #1e293b;
      --bg-card-alt: #334155;
      --border-color: #475569;
      --text-main: #f8fafc;
      --text-muted: #94a3b8;
      --accent-blue: #38bdf8;
      --accent-rose: #f43f5e;
      --accent-amber: #fbbf24;
      --accent-emerald: #10b981;
      --accent-indigo: #818cf8;
      --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: var(--bg-main);
      color: var(--text-main);
      line-height: 1.5;
      padding-bottom: 5rem;
    }}
    header {{
      background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
      border-bottom: 1px solid var(--border-color);
      padding: 1.25rem 2rem;
      position: sticky;
      top: 0;
      z-index: 100;
      box-shadow: 0 4px 20px rgba(0,0,0,0.4);
    }}
    .header-content {{
      max-width: 1400px;
      margin: 0 auto;
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: center;
      gap: 1rem;
    }}
    .title-area h1 {{
      font-size: 1.5rem;
      font-weight: 800;
      letter-spacing: -0.5px;
      display: flex;
      align-items: center;
      gap: 0.5rem;
      flex-wrap: wrap;
    }}
    .title-area h1 span.badge {{
      background: var(--accent-indigo);
      color: #fff;
      font-size: 0.75rem;
      padding: 0.2rem 0.6rem;
      border-radius: 9999px;
      font-weight: 600;
    }}
    .title-area p {{
      color: var(--text-muted);
      font-size: 0.85rem;
      margin-top: 0.2rem;
    }}
    .header-actions {{
      display: flex;
      align-items: center;
      gap: 0.6rem;
      flex-wrap: wrap;
    }}
    .btn-top {{
      background: rgba(255,255,255,0.08);
      border: 1px solid var(--border-color);
      color: var(--text-main);
      font-size: 0.8rem;
      font-weight: 600;
      padding: 0.45rem 0.85rem;
      border-radius: 6px;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      transition: all 0.2s;
      text-decoration: none;
    }}
    .btn-top:hover {{
      background: var(--border-color);
      border-color: var(--accent-blue);
    }}
    .btn-rack-top {{
      background: rgba(129, 140, 248, 0.15);
      border-color: var(--accent-indigo);
      color: var(--accent-indigo);
    }}
    .btn-rack-top:hover {{
      background: var(--accent-indigo);
      color: #0f172a;
    }}
    .btn-rebuild {{
      background: rgba(56, 189, 248, 0.15);
      border-color: var(--accent-blue);
      color: var(--accent-blue);
    }}
    .btn-rebuild:hover {{
      background: var(--accent-blue);
      color: #0f172a;
    }}
    .stats-bar {{
      display: flex;
      gap: 0.5rem;
      flex-wrap: wrap;
      margin-top: 0.5rem;
    }}
    .stat-pill {{
      background: rgba(255,255,255,0.06);
      border: 1px solid rgba(255,255,255,0.1);
      padding: 0.25rem 0.65rem;
      border-radius: 6px;
      font-size: 0.75rem;
      display: flex;
      align-items: center;
      gap: 0.35rem;
    }}
    .stat-pill b {{ color: var(--accent-blue); }}

    .container {{
      max-width: 1400px;
      margin: 1.5rem auto;
      padding: 0 1.5rem;
    }}

    /* Barre de recherche et contrôles */
    .controls {{
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 1.25rem;
      margin-bottom: 1.5rem;
      box-shadow: 0 4px 15px rgba(0,0,0,0.2);
    }}
    .search-box {{
      margin-bottom: 1rem;
    }}
    .search-box input {{
      width: 100%;
      padding: 0.85rem 1.2rem;
      font-size: 1.05rem;
      border-radius: 8px;
      border: 1px solid var(--border-color);
      background: rgba(15, 23, 42, 0.8);
      color: var(--text-main);
      outline: none;
      transition: border-color 0.2s;
    }}
    .search-box input:focus {{
      border-color: var(--accent-blue);
      box-shadow: 0 0 0 3px rgba(56, 189, 248, 0.2);
    }}
    .filters-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 0.75rem;
      align-items: center;
    }}
    .filter-group label {{
      display: block;
      font-size: 0.7rem;
      text-transform: uppercase;
      font-weight: 700;
      letter-spacing: 0.5px;
      color: var(--text-muted);
      margin-bottom: 0.25rem;
    }}
    .filter-group select {{
      width: 100%;
      padding: 0.55rem 0.75rem;
      border-radius: 6px;
      border: 1px solid var(--border-color);
      background: #0f172a;
      color: var(--text-main);
      font-size: 0.85rem;
      outline: none;
    }}

    /* Barre d'action sur la sélection filtrée */
    .export-bar {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 1rem;
      flex-wrap: wrap;
      gap: 0.75rem;
    }}
    .results-count {{
      font-size: 0.9rem;
      color: var(--text-muted);
      font-weight: 500;
    }}
    .export-buttons {{
      display: flex;
      gap: 0.5rem;
      align-items: center;
    }}
    .btn-export {{
      background: rgba(16, 185, 129, 0.15);
      border: 1px solid var(--accent-emerald);
      color: var(--accent-emerald);
      padding: 0.4rem 0.75rem;
      font-size: 0.8rem;
      font-weight: 600;
      border-radius: 6px;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 5px;
      transition: all 0.15s;
    }}
    .btn-export:hover {{
      background: var(--accent-emerald);
      color: #0f172a;
    }}
    .btn-view {{
      background: #0f172a;
      border: 1px solid var(--border-color);
      color: var(--text-muted);
      padding: 0.4rem 0.7rem;
      font-size: 0.8rem;
      font-weight: 600;
      border-radius: 6px;
      cursor: pointer;
    }}
    .btn-view.active {{
      background: var(--accent-blue);
      color: #0f172a;
      border-color: var(--accent-blue);
    }}

    /* Cartes */
    .grid-cards {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(420px, 1fr));
      gap: 1.25rem;
    }}
    .card {{
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 10px;
      padding: 1.25rem;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      display: flex;
      flex-direction: column;
      gap: 0.75rem;
      position: relative;
    }}
    .card.blocking {{ border-left: 4px solid var(--accent-rose); }}
    .card.action {{ border-left: 4px solid var(--accent-emerald); }}
    .card.histo {{ border-left: 4px solid var(--accent-indigo); }}

    .card-header {{
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 0.5rem;
    }}
    .badges {{
      display: flex;
      gap: 0.35rem;
      flex-wrap: wrap;
    }}
    .badge {{
      font-size: 0.7rem;
      font-weight: 700;
      padding: 0.15rem 0.45rem;
      border-radius: 4px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }}
    .badge-organ {{ background: rgba(56, 189, 248, 0.15); color: var(--accent-blue); border: 1px solid rgba(56, 189, 248, 0.3); }}
    .badge-code {{ background: rgba(251, 191, 36, 0.15); color: var(--accent-amber); border: 1px solid rgba(251, 191, 36, 0.3); font-family: var(--font-mono); }}
    .badge-blocking {{ background: rgba(244, 63, 94, 0.2); color: var(--accent-rose); }}
    .badge-histo {{ background: rgba(129, 140, 248, 0.2); color: var(--accent-indigo); }}
    .badge-val-ok {{ background: rgba(16, 185, 129, 0.2); color: var(--accent-emerald); border: 1px solid rgba(16, 185, 129, 0.4); }}
    .badge-val-todo {{ background: rgba(148, 163, 184, 0.15); color: var(--text-muted); border: 1px dashed var(--border-color); }}

    .card-text {{
      background: rgba(15, 23, 42, 0.75);
      padding: 0.65rem 0.8rem;
      border-radius: 6px;
      font-family: var(--font-mono);
      font-size: 0.95rem;
      font-weight: bold;
      color: #fff;
      word-break: break-word;
      border: 1px solid rgba(255,255,255,0.06);
    }}

    .st-condition {{
      font-size: 0.75rem;
      font-family: var(--font-mono);
      background: rgba(0,0,0,0.3);
      padding: 0.4rem 0.6rem;
      border-radius: 4px;
      color: #cbd5e1;
      border-left: 2px solid var(--accent-indigo);
      overflow-x: auto;
    }}
    .st-condition span {{
      color: var(--accent-indigo);
      font-weight: bold;
      margin-right: 0.3rem;
    }}

    .section-block {{
      font-size: 0.85rem;
      line-height: 1.4;
      background: rgba(255,255,255,0.02);
      border: 1px solid rgba(255,255,255,0.04);
      padding: 0.6rem;
      border-radius: 6px;
    }}
    .section-block b {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      color: var(--text-muted);
      font-size: 0.7rem;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 0.25rem;
    }}
    .val-missing {{
      font-style: italic;
      color: #64748b;
      font-size: 0.8rem;
    }}
    .val-set {{
      color: #e2e8f0;
    }}

    .card-footer {{
      margin-top: auto;
      padding-top: 0.6rem;
      border-top: 1px solid rgba(255,255,255,0.08);
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 0.75rem;
      color: var(--text-muted);
      font-family: var(--font-mono);
    }}
    .card-actions {{
      display: flex;
      gap: 0.4rem;
    }}
    .btn-edit {{
      background: transparent;
      border: 1px solid var(--border-color);
      color: var(--text-muted);
      padding: 0.2rem 0.5rem;
      border-radius: 4px;
      cursor: pointer;
      font-size: 0.7rem;
    }}
    .btn-edit:hover {{
      background: var(--accent-blue);
      color: #0f172a;
    }}

    /* Boutons de repérage LED E/S */
    .btn-locate-led {{
      background: rgba(56, 189, 248, 0.15);
      border: 1px solid rgba(56, 189, 248, 0.4);
      color: var(--accent-blue);
      font-size: 0.72rem;
      font-weight: 600;
      padding: 0.2rem 0.55rem;
      border-radius: 4px;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      transition: all 0.15s;
    }}
    .btn-locate-led:hover {{
      background: var(--accent-blue);
      color: #0f172a;
    }}
    .io-buttons-group {{
      margin-top: 0.45rem;
      display: flex;
      flex-wrap: wrap;
      gap: 0.35rem;
    }}

    /* Vue Tableau */
    .table-view {{
      display: none;
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      overflow-x: auto;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 0.85rem;
      text-align: left;
    }}
    th {{
      background: #0f172a;
      padding: 0.75rem;
      font-size: 0.75rem;
      text-transform: uppercase;
      color: var(--text-muted);
      border-bottom: 1px solid var(--border-color);
      white-space: nowrap;
    }}
    td {{
      padding: 0.75rem;
      border-bottom: 1px solid rgba(255,255,255,0.06);
      vertical-align: top;
    }}
    tr:hover td {{
      background: rgba(255,255,255,0.02);
    }}

    /* ========================================================================== */
    /* 🖲️ STYLES FACE AVANT AUTOMATE VEICHI & CARTOGRAPHIE RACK E/S             */
    /* ========================================================================== */
    .modal-rack-overlay {{
      display: none;
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(2, 6, 23, 0.88);
      backdrop-filter: blur(4px);
      z-index: 1500;
      align-items: center;
      justify-content: center;
      padding: 1rem;
    }}
    .modal-rack {{
      background: #0f172a;
      border: 1px solid #334155;
      border-radius: 12px;
      max-width: 1760px;
      width: 98vw;
      max-height: 94vh;
      display: flex;
      flex-direction: column;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.75);
      overflow: hidden;
    }}
    .rack-modal-header {{
      background: #1e293b;
      border-bottom: 1px solid #334155;
      padding: 1rem 1.5rem;
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: center;
      gap: 1rem;
    }}
    .rack-title-box h2 {{
      font-size: 1.25rem;
      font-weight: 800;
      color: #f8fafc;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }}
    .rack-title-box p {{
      font-size: 0.8rem;
      color: #94a3b8;
      margin-top: 0.2rem;
    }}
    .rack-controls-bar {{
      display: flex;
      align-items: center;
      gap: 0.75rem;
      flex-wrap: wrap;
    }}
    .plc-status-pill {{
      display: inline-flex;
      align-items: center;
      gap: 0.4rem;
      background: #0f172a;
      border: 1px solid #334155;
      padding: 0.35rem 0.75rem;
      border-radius: 9999px;
      font-size: 0.75rem;
      font-family: var(--font-mono);
      font-weight: 700;
    }}
    .plc-led {{
      width: 10px;
      height: 10px;
      border-radius: 50%;
      display: inline-block;
    }}
    .plc-led-run {{
      background: #22c55e;
      box-shadow: 0 0 8px rgba(34, 197, 94, 0.9);
    }}
    .plc-led-alm {{
      background: #334155;
      border: 1px solid #64748b;
    }}
    .plc-led-err {{
      background: #334155;
      border: 1px solid #64748b;
    }}
    .btn-rack-action {{
      background: #1e293b;
      border: 1px solid #475569;
      color: #e2e8f0;
      font-size: 0.8rem;
      font-weight: 600;
      padding: 0.45rem 0.85rem;
      border-radius: 6px;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      transition: all 0.15s;
    }}
    .btn-rack-action:hover {{
      background: #334155;
      border-color: var(--accent-blue);
    }}
    .btn-test-mode.active {{
      background: rgba(245, 158, 11, 0.2);
      border-color: #f59e0b;
      color: #fbbf24;
    }}

    /* Barre de navigation & Chariot de défilement horizontal */
    .rack-nav-bar {{
      padding: 0.55rem 1.5rem;
      background: #131d33;
      border-bottom: 1px solid #334155;
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      justify-content: space-between;
      gap: 0.75rem;
    }}
    .rack-jump-group {{
      display: flex;
      align-items: center;
      gap: 0.4rem;
      flex-wrap: wrap;
    }}
    .slot-jump-btn {{
      background: #1e293b;
      border: 1px solid #475569;
      color: #94a3b8;
      padding: 0.25rem 0.6rem;
      border-radius: 6px;
      font-size: 0.75rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.15s;
    }}
    .slot-jump-btn:hover {{
      background: var(--accent-indigo);
      color: #0f172a;
      border-color: var(--accent-indigo);
    }}
    .rack-slider-container {{
      display: flex;
      align-items: center;
      gap: 0.5rem;
      color: #94a3b8;
      font-size: 0.75rem;
    }}
    .btn-chariot-step {{
      background: #1e293b;
      border: 1px solid #475569;
      color: #e2e8f0;
      padding: 0.25rem 0.55rem;
      border-radius: 4px;
      font-size: 0.8rem;
      cursor: pointer;
    }}
    .btn-chariot-step:hover {{
      background: var(--accent-blue);
      color: #0f172a;
    }}
    .rack-slider {{
      width: 170px;
      height: 6px;
      border-radius: 3px;
      background: #334155;
      outline: none;
      cursor: pointer;
      accent-color: var(--accent-blue);
    }}

    /* Barre de recherche sur façade */
    .rack-search-bar {{
      padding: 0.65rem 1.5rem;
      background: #0f172a;
      border-bottom: 1px solid #334155;
      display: flex;
      align-items: center;
      gap: 1rem;
    }}
    .rack-search-bar input {{
      flex: 1;
      padding: 0.5rem 0.9rem;
      border-radius: 6px;
      border: 1px solid #475569;
      background: #172033;
      color: #f8fafc;
      font-size: 0.88rem;
      outline: none;
    }}
    .rack-search-bar input:focus {{
      border-color: var(--accent-blue);
      box-shadow: 0 0 0 2px rgba(56, 189, 248, 0.2);
    }}

    /* Conteneur des cartes : mode Accordéon Compact (par défaut) ou Tout Déployé (Large) */
    .rack-cards-scroll {{
      flex: 1;
      overflow-x: auto;
      overflow-y: auto;
      padding: 1.25rem;
      display: flex;
      gap: 0.85rem;
      background: #0b1120;
      align-items: flex-start;
      scroll-behavior: smooth;
    }}
    .rack-cards-scroll.accordion-mode {{
      justify-content: center;
    }}

    /* Cartes selon 2 colonnes (Dual) ou 1 colonne (Single) */
    .rack-card {{
      background: #1e293b;
      border: 1px solid #334155;
      border-radius: 8px;
      display: flex;
      flex-direction: column;
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.3);
      transition: width 0.35s cubic-bezier(0.4, 0, 0.2, 1), 
                  flex-basis 0.35s cubic-bezier(0.4, 0, 0.2, 1),
                  box-shadow 0.25s,
                  border-color 0.25s;
      flex-shrink: 0;
      overflow: hidden;
      position: relative;
    }}
    .rack-card.dual-card {{
      width: 580px;
    }}
    .rack-card.single-card {{
      width: 310px;
    }}
    .rack-card.rack-card-targeted {{
      border-color: var(--accent-blue) !important;
      box-shadow: 0 0 24px rgba(56, 189, 248, 0.45) !important;
    }}

    /* COMPORTEMENT ACCORDÉON (Compact par défaut pour tenir sur 1 seul écran) */
    .rack-cards-scroll.accordion-mode .rack-card.dual-card:not(.active-slot):not(:hover) {{
      width: 155px;
      flex: 0 0 155px;
      cursor: pointer;
    }}
    .rack-cards-scroll.accordion-mode .rack-card.single-card:not(.active-slot):not(:hover) {{
      width: 105px;
      flex: 0 0 105px;
      cursor: pointer;
    }}
    .rack-cards-scroll.accordion-mode .rack-card:not(.active-slot):not(:hover) .rack-card-sub,
    .rack-cards-scroll.accordion-mode .rack-card:not(.active-slot):not(:hover) .rack-card-range,
    .rack-cards-scroll.accordion-mode .rack-card:not(.active-slot):not(:hover) .ch-desc,
    .rack-cards-scroll.accordion-mode .rack-card:not(.active-slot):not(:hover) .ch-addr,
    .rack-cards-scroll.accordion-mode .rack-card:not(.active-slot):not(:hover) .ch-var,
    .rack-cards-scroll.accordion-mode .rack-card:not(.active-slot):not(:hover) .col-badge {{
      display: none !important;
    }}
    .rack-cards-scroll.accordion-mode .rack-card:not(.active-slot):not(:hover) .rack-channel-row {{
      grid-template-columns: 14px 18px !important;
      justify-content: center;
      padding: 3px 2px !important;
      gap: 3px !important;
    }}
    .rack-cards-scroll.accordion-mode .rack-card:not(.active-slot):not(:hover) .rack-col {{
      padding: 0.35rem 0.2rem !important;
    }}
    .rack-cards-scroll.accordion-mode .rack-card:not(.active-slot):not(:hover) .col-title {{
      font-size: 0.58rem !important;
      text-align: center;
      width: 100%;
    }}
    .rack-cards-scroll.accordion-mode .rack-card:not(.active-slot):not(:hover) .rack-card-head {{
      padding: 0.5rem 0.4rem !important;
      text-align: center;
    }}
    .rack-cards-scroll.accordion-mode .rack-card:not(.active-slot):not(:hover) .rack-card-name {{
      font-size: 0.72rem !important;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }}

    /* EXPANSION AU SURVOL OU AU CLIC (.active-slot) */
    .rack-cards-scroll.accordion-mode .rack-card.dual-card:hover,
    .rack-cards-scroll.accordion-mode .rack-card.dual-card.active-slot {{
      width: 580px !important;
      flex: 0 0 580px !important;
      box-shadow: 0 12px 35px rgba(0, 0, 0, 0.7), 0 0 20px rgba(56, 189, 248, 0.3);
      border-color: var(--accent-blue);
      z-index: 20;
    }}
    .rack-cards-scroll.accordion-mode .rack-card.single-card:hover,
    .rack-cards-scroll.accordion-mode .rack-card.single-card.active-slot {{
      width: 310px !important;
      flex: 0 0 310px !important;
      box-shadow: 0 12px 35px rgba(0, 0, 0, 0.7), 0 0 20px rgba(56, 189, 248, 0.3);
      border-color: var(--accent-blue);
      z-index: 20;
    }}

    /* MODE TOUT DÉPLOYÉ (Capture d'écran / Balade Large) */
    .rack-cards-scroll.all-expanded {{
      justify-content: flex-start;
      overflow-x: auto !important;
    }}
    .rack-cards-scroll.all-expanded .rack-card.dual-card {{
      width: 580px !important;
      flex: 0 0 580px !important;
    }}
    .rack-cards-scroll.all-expanded .rack-card.single-card {{
      width: 310px !important;
      flex: 0 0 310px !important;
    }}

    .rack-card-head {{
      background: #172033;
      padding: 0.85rem 1rem;
      border-bottom: 1px solid #334155;
      border-top-left-radius: 8px;
      border-top-right-radius: 8px;
    }}
    .rack-card-badge {{
      display: inline-block;
      font-size: 0.7rem;
      font-weight: 700;
      padding: 0.15rem 0.5rem;
      border-radius: 4px;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      margin-bottom: 0.35rem;
      border: 1px solid rgba(255, 255, 255, 0.15);
    }}
    .badge-slot1 {{ background: rgba(6, 182, 212, 0.15); color: #22d3ee; border-color: rgba(6, 182, 212, 0.3); }}
    .badge-slot2 {{ background: rgba(99, 102, 241, 0.15); color: #818cf8; border-color: rgba(99, 102, 241, 0.3); }}
    .badge-slot3 {{ background: rgba(168, 85, 247, 0.15); color: #c084fc; border-color: rgba(168, 85, 247, 0.3); }}
    .badge-slot4 {{ background: rgba(244, 63, 94, 0.15); color: #fb7185; border-color: rgba(244, 63, 94, 0.3); }}
    .badge-slot5 {{ background: rgba(245, 158, 11, 0.15); color: #fbbf24; border-color: rgba(245, 158, 11, 0.3); }}

    .rack-card-name {{
      font-size: 0.92rem;
      font-weight: 700;
      color: #f8fafc;
    }}
    .rack-card-sub {{
      font-size: 0.75rem;
      color: #94a3b8;
      margin-top: 0.15rem;
    }}
    .rack-card-range {{
      font-family: var(--font-mono);
      font-size: 0.7rem;
      color: #38bdf8;
      margin-top: 0.25rem;
    }}

    /* Corps de carte physique : 2 colonnes ou 1 colonne */
    .rack-card-body {{
      padding: 0.65rem;
      display: flex;
      gap: 0.65rem;
      background: #131d33;
      border-bottom-left-radius: 8px;
      border-bottom-right-radius: 8px;
    }}
    .rack-card-body.rack-card-dual {{
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 0.65rem;
    }}
    .rack-card-body.rack-card-single {{
      display: block;
    }}

    .rack-col {{
      background: rgba(15, 23, 42, 0.75);
      border: 1px solid rgba(255, 255, 255, 0.06);
      border-radius: 6px;
      padding: 0.5rem;
      display: flex;
      flex-direction: column;
      gap: 2px;
    }}
    .rack-col.col-in {{
      border-top: 3px solid #22c55e;
    }}
    .rack-col.col-out {{
      border-top: 3px solid #f43f5e;
    }}
    .rack-col.col-relay {{
      border-top: 3px solid #f59e0b;
    }}

    .rack-col-header {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 0.45rem;
      padding-bottom: 0.3rem;
      border-bottom: 1px solid rgba(255, 255, 255, 0.06);
    }}
    .col-title {{
      font-size: 0.68rem;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: #94a3b8;
    }}
    .col-badge {{
      font-size: 0.65rem;
      font-family: var(--font-mono);
      font-weight: 700;
      padding: 0.1rem 0.4rem;
      border-radius: 4px;
    }}
    .col-badge.badge-in {{
      background: rgba(34, 197, 94, 0.15);
      color: #4ade80;
    }}
    .col-badge.badge-out {{
      background: rgba(244, 63, 94, 0.15);
      color: #fb7185;
    }}
    .col-badge.badge-relay {{
      background: rgba(245, 158, 11, 0.15);
      color: #fbbf24;
    }}

    .rack-channel-row {{
      display: grid;
      grid-template-columns: 16px 24px 58px 1fr;
      align-items: center;
      gap: 5px;
      padding: 4px 6px;
      border-radius: 4px;
      margin-bottom: 2px;
      font-size: 0.72rem;
      cursor: pointer;
      transition: background 0.15s;
    }}
    .rack-channel-row:hover {{
      background: rgba(255, 255, 255, 0.06);
    }}
    .rack-channel-row.channel-targeted {{
      background: rgba(56, 189, 248, 0.25) !important;
      outline: 1px solid #38bdf8;
    }}
    .rack-channel-row.dimmed {{
      opacity: 0.18;
    }}
    .led-dot {{
      width: 11px;
      height: 11px;
      border-radius: 50%;
      background: #334155;
      border: 1px solid #64748b;
      transition: all 0.2s;
    }}
    .led-dot.led-on {{
      background: #22c55e;
      border-color: #86efac;
      box-shadow: 0 0 8px rgba(34, 197, 94, 0.9);
    }}
    .led-dot.led-target {{
      animation: pulse-target 0.8s infinite alternate !important;
    }}
    @keyframes pulse-target {{
      0% {{
        transform: scale(1);
        background: #38bdf8;
        box-shadow: 0 0 4px #38bdf8;
      }}
      100% {{
        transform: scale(1.45);
        background: #bae6fd;
        box-shadow: 0 0 14px #38bdf8, 0 0 22px #0284c7;
      }}
    }}
    .ch-bit {{
      font-family: var(--font-mono);
      font-size: 0.68rem;
      color: #94a3b8;
      font-weight: 600;
    }}
    .ch-addr {{
      font-family: var(--font-mono);
      font-size: 0.7rem;
      color: #38bdf8;
      font-weight: 700;
    }}
    .ch-addr.out {{
      color: #f43f5e;
    }}
    .ch-details {{
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }}
    .ch-var {{
      font-weight: 700;
      color: #f1f5f9;
      font-size: 0.72rem;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }}
    .ch-desc {{
      font-size: 0.65rem;
      color: #64748b;
      display: block;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }}

    /* Modal d'édition conjointe */
    .modal-overlay {{
      display: none;
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.75);
      z-index: 1000;
      align-items: center;
      justify-content: center;
      padding: 1rem;
    }}
    .modal {{
      background: var(--bg-card);
      border: 1px solid var(--accent-blue);
      border-radius: 12px;
      max-width: 650px;
      width: 100%;
      padding: 1.5rem;
      box-shadow: 0 10px 40px rgba(0,0,0,0.6);
      display: flex;
      flex-direction: column;
      gap: 1rem;
    }}
    .modal h2 {{
      font-size: 1.2rem;
      color: var(--accent-blue);
    }}
    .form-group label {{
      display: block;
      font-size: 0.75rem;
      text-transform: uppercase;
      color: var(--text-muted);
      margin-bottom: 0.3rem;
      font-weight: bold;
    }}
    .form-group textarea, .form-group input {{
      width: 100%;
      padding: 0.6rem;
      border-radius: 6px;
      border: 1px solid var(--border-color);
      background: #0f172a;
      color: #fff;
      font-size: 0.9rem;
      font-family: inherit;
      outline: none;
    }}
    .form-group textarea:focus, .form-group input:focus {{
      border-color: var(--accent-blue);
    }}
    .modal-actions {{
      display: flex;
      justify-content: flex-end;
      gap: 0.6rem;
      margin-top: 0.5rem;
    }}
    .btn-save {{
      background: var(--accent-emerald);
      color: #0f172a;
      font-weight: bold;
      padding: 0.5rem 1rem;
      border-radius: 6px;
      border: none;
      cursor: pointer;
    }}
    .btn-close {{
      background: transparent;
      border: 1px solid var(--border-color);
      color: var(--text-muted);
      padding: 0.5rem 1rem;
      border-radius: 6px;
      cursor: pointer;
    }}

    /* Toast notification */
    .toast {{
      position: fixed;
      bottom: 2rem;
      right: 2rem;
      background: var(--accent-emerald);
      color: #0f172a;
      padding: 0.75rem 1.25rem;
      border-radius: 8px;
      font-weight: bold;
      font-size: 0.9rem;
      box-shadow: 0 4px 15px rgba(0,0,0,0.4);
      display: none;
      z-index: 2000;
    }}
  </style>
</head>
<body>

  <header>
    <div class="header-content">
      <div class="title-area">
        <h1>🧭 OMNIDIAG <span>v1.0</span> <span class="badge">CODESYS 3.5</span></h1>
        <p>Extraction Déterministe du Code ST — Diagnostic, LEDs & Manuel Opérateur</p>
      </div>
      <div class="header-actions">
        <button class="btn-top btn-rack-top" id="btnOpenRack" onclick="openRackModal()">
          🖲️ Face Avant Automate & LEDs E/S
        </button>
        <button class="btn-top btn-rebuild" id="btnRebuild" onclick="triggerRebuild()">
          🔄 Re-scanner le code ST
        </button>
        <a href="/TASK_VIEWER.html" class="btn-top">
          🗂️ Task Manager
        </a>
      </div>
    </div>
    <div class="header-content" style="margin-top: 0.5rem;">
      <div class="stats-bar" id="statsBar"></div>
    </div>
  </header>

  <div class="container">

    <!-- Contrôles et Filtres -->
    <div class="controls">
      <div class="search-box">
        <input type="text" id="searchInput" placeholder="🔎 Filtrer par mot-clé, code (ex: ErrorID:08), organe (ex: M1, M3, AU), condition ST, fichier...">
      </div>
      <div class="filters-grid">
        <div class="filter-group">
          <label for="categoryFilter">Catégorie</label>
          <select id="categoryFilter">
            <option value="ALL">Toutes les catégories</option>
            <option value="ACTIVE_ALARM">Alarmes Bloquantes (Carrousel)</option>
            <option value="HISTO_ALARM">Alarmes Historisées [HISTO]</option>
            <option value="OPERATOR_ACTION">Actions Opérateur & Interlocks</option>
            <option value="ABORT_REARMEMENT_AU">Échecs Réarmement AU</option>
            <option value="GUIDAGE_HOMING">Guidage Homing Machine</option>
            <option value="CHECKLIST_PREFLIGHT">Checklist Preflight Arrêtée</option>
            <option value="TRACE_BLOCAGE_TERRAIN">Causes de Blocage Terrain (Trace)</option>
            <option value="SOCLE_DEFAUTS_FB">Socles Défauts FB Métier</option>
            <option value="SPECIAL_CONDITION">Conditions Spéciales / Dérogations</option>
          </select>
        </div>
        <div class="filter-group">
          <label for="organFilter">Organe</label>
          <select id="organFilter">
            <option value="ALL">Tous les organes</option>
            <option value="M1">Treuil M1 (Retenue)</option>
            <option value="M2">Treuil M2 (Benne)</option>
            <option value="M3">Translation M3 (Pont)</option>
            <option value="BENNE">Mécanisme Benne</option>
            <option value="AU">Arrêt d'Urgence / Puissance</option>
            <option value="CAN">Bus CAN / Joystick</option>
            <option value="ECAT">Bus EtherCAT / Codeurs</option>
            <option value="IO">Modules E/S</option>
            <option value="SYNC">Synchronisme M1/M2</option>
            <option value="CYCLE">Cycle Semi-Automatique</option>
            <option value="HOMING">Homing Machine</option>
          </select>
        </div>
        <div class="filter-group">
          <label for="validationFilter">Statut Fiche</label>
          <select id="validationFilter">
            <option value="ALL">Tous les statuts</option>
            <option value="VALIDÉ">Fiches Renseignées & Validées</option>
            <option value="À DÉFINIR">Fiches À Définir Ensemble</option>
          </select>
        </div>
        <div class="filter-group">
          <label for="blockingFilter">Type de Blocage</label>
          <select id="blockingFilter">
            <option value="ALL">Tous les états</option>
            <option value="BLOCKING">Bloquant uniquement</option>
            <option value="NON_BLOCKING">Informatif / Guidage</option>
          </select>
        </div>
      </div>
    </div>

    <!-- Barre d'Exportation de la Sélection -->
    <div class="export-bar">
      <div class="results-count" id="resultsCount">Chargement...</div>
      <div class="export-buttons">
        <button class="btn-export" onclick="exportFilteredCSV()">📥 Exporter la sélection (CSV)</button>
        <button class="btn-export" onclick="exportFilteredExcelHTML()" style="border-color:var(--accent-blue);color:var(--accent-blue);background:rgba(56,189,248,0.15)">📊 Exporter la sélection (Excel)</button>
        <div style="display:inline-flex;margin-left:0.5rem;">
          <button class="btn-view active" id="btnCardView" onclick="setViewMode('card')">Fiches</button>
          <button class="btn-view" id="btnTableView" onclick="setViewMode('table')">Tableau</button>
        </div>
      </div>
    </div>

    <!-- Conteneur Fiches -->
    <div class="grid-cards" id="cardsContainer"></div>

    <!-- Conteneur Tableau -->
    <div class="table-view" id="tableContainer">
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Organe</th>
            <th>Code</th>
            <th>Message Exact Extrait du Code ST</th>
            <th>Condition Déclenchement ST</th>
            <th>Cause (Validée)</th>
            <th>Action Utilisateur (Validée)</th>
            <th>Points de Test & LEDs</th>
            <th>Statut</th>
            <th>Source</th>
          </tr>
        </thead>
        <tbody id="tableBody"></tbody>
      </table>
    </div>

  </div>

  <!-- Modale Synoptique Face Avant Automate VEICHI -->
  <div class="modal-rack-overlay" id="rackModal" onclick="if(event.target===this) closeRackModal()">
    <div class="modal-rack">
      <div class="rack-modal-header">
        <div class="rack-title-box">
          <h2>🖲️ Cartographie Matérielle & Face Avant Automate VEICHI</h2>
          <p>Rack PLC Réel · Slot 1 & 2 : Double Rangée (Gauche = IN / Droite = OUT) · Slot 3 à 5 : Simple Rangée</p>
        </div>
        <div class="rack-controls-bar">
          <div class="plc-status-pill" title="Automate en marche">
            <span class="plc-led plc-led-run"></span> RUN
          </div>
          <div class="plc-status-pill" title="Pas d'alarme active">
            <span class="plc-led plc-led-alm"></span> ALM
          </div>
          <div class="plc-status-pill" title="Pas d'erreur automate">
            <span class="plc-led plc-led-err"></span> ERR
          </div>
          <button class="btn-rack-action" onclick="clearAllLeds()" title="Éteindre toutes les LEDs allumées">
            💡 Tout Éteindre
          </button>
          <button class="btn-rack-action" id="btnToggleExpandAll" onclick="toggleExpandAll()" title="Déployer toutes les cartes simultanément pour capture d'écran">
            ↔️ Tout Déployer (Capture)
          </button>
          <button class="btn-rack-action" onclick="clearRackTarget()">
            🧹 Effacer Repère
          </button>
          <button class="btn-rack-action" onclick="closeRackModal()" style="font-weight:bold;">
            ✕ Fermer
          </button>
        </div>
      </div>

      <!-- Chariot / Curseur de déplacement horizontal & Accès direct aux cartes -->
      <div class="rack-nav-bar">
        <div class="rack-jump-group">
          <span style="font-size:0.75rem;color:#94a3b8;font-weight:bold;text-transform:uppercase;">Accès Carte :</span>
          <button class="slot-jump-btn" onclick="jumpToSlot('Local_Digital_IO')">Slot 1 CPU (IN/OUT)</button>
          <button class="slot-jump-btn" onclick="jumpToSlot('VH_0808ETP')">Slot 2 ETP (IN/OUT)</button>
          <button class="slot-jump-btn" onclick="jumpToSlot('VH_0800END')">Slot 3 END (8 DI)</button>
          <button class="slot-jump-btn" onclick="jumpToSlot('VH_0008ER')">Slot 4 ER (8 Relais)</button>
          <button class="slot-jump-btn" onclick="jumpToSlot('VH_0008ER_1')">Slot 5 ER_1 (8 Relais)</button>
        </div>

        <div class="rack-slider-container">
          <button class="btn-chariot-step" onclick="scrollRack(-1)" title="Faire défiler à gauche">◀</button>
          <span>Chariot :</span>
          <input type="range" id="rackScrollSlider" min="0" max="100" value="0" oninput="handleRackSlider(this.value)" class="rack-slider" title="Faire glisser pour déplacer le rack">
          <button class="btn-chariot-step" onclick="scrollRack(1)" title="Faire défiler à droite">▶</button>
        </div>
      </div>

      <div class="rack-search-bar">
        <input type="text" id="rackSearchInput" placeholder="🔎 Filtrer une voie sur la façade (%IX0.0, %QX27, frein, M1, thermique, contacteur, came...)" oninput="filterRackChannels()">
        <span id="rackMatchCount" style="font-size:0.8rem;color:#94a3b8;white-space:nowrap;"></span>
      </div>

      <div class="rack-cards-scroll accordion-mode" id="rackCardsContainer" onscroll="syncRackSlider()">
        <!-- Généré dynamiquement par renderRack() -->
      </div>
    </div>
  </div>

  <!-- Modale d'édition et proposition de fiche -->
  <div class="modal-overlay" id="editModal">
    <div class="modal">
      <h2 id="modalTitle">✏️ Proposition Fiche Diagnostic</h2>
      <div id="modalItemInfo" style="font-size:0.85rem;color:var(--text-muted);font-family:var(--font-mono);"></div>
      
      <div class="form-group">
        <label>Message ST Extrait</label>
        <input type="text" id="modalRawText" readonly style="color:#94a3b8;background:#1e293b;">
      </div>

      <div class="form-group">
        <label>Cause (Proposition)</label>
        <textarea id="modalCause" rows="2" placeholder="Ex: Garniture frein usée, disjoncteur thermique Q2 déclenché..."></textarea>
      </div>

      <div class="form-group">
        <label>Action Utilisateur</label>
        <textarea id="modalActionOp" rows="2" placeholder="Ex: Maintenir manipulateur au repos, ramener la charge au sol..."></textarea>
      </div>

      <div class="form-group">
        <label>Action Maintenance</label>
        <textarea id="modalActionMaint" rows="2" placeholder="Ex: Mesurer la tension bobine frein, inspecter fusible F4..."></textarea>
      </div>

      <div class="form-group">
        <label>Points de Test & Repères Matériels</label>
        <input type="text" id="modalPointsTest" placeholder="Ex: Bornier X1:12, module VH0800END, disjoncteur Q3"></textarea>
      </div>

      <div class="modal-actions">
        <button class="btn-close" onclick="closeModal()">Annuler</button>
        <button class="btn-save" onclick="saveModalData()">💾 Enregistrer la Fiche</button>
      </div>
    </div>
  </div>

  <div class="toast" id="toastMsg">Action enregistrée !</div>

  <script>
    let rawItems = {items_json};
    let rackData = {rack_json};
    let currentView = 'card';
    let currentEditItem = null;
    let isTestModeActive = false;
    let isGridMode = false;
    let currentTargetedChannel = null;

    function initStats() {{
      const total = rawItems.length;
      const activeAlarms = rawItems.filter(i => i.category === 'ACTIVE_ALARM').length;
      const histoAlarms = rawItems.filter(i => i.category === 'HISTO_ALARM').length;
      const actions = rawItems.filter(i => i.category === 'OPERATOR_ACTION' || i.category === 'ABORT_REARMEMENT_AU').length;
      const validated = rawItems.filter(i => i.statut_validation === 'VALIDÉ').length;
      const toDefine = total - validated;

      document.getElementById('statsBar').innerHTML = `
        <div class="stat-pill">Total extrait: <b>${{total}}</b></div>
        <div class="stat-pill">🚨 Bloquantes: <b style="color:var(--accent-rose);">${{activeAlarms}}</b></div>
        <div class="stat-pill">🕘 Histo: <b style="color:var(--accent-indigo);">${{histoAlarms}}</b></div>
        <div class="stat-pill">🕹️ Actions: <b style="color:var(--accent-emerald);">${{actions}}</b></div>
        <div class="stat-pill">✅ Fiches Validées: <b style="color:var(--accent-emerald);">${{validated}}</b></div>
        <div class="stat-pill">📝 À Définir: <b style="color:var(--accent-amber);">${{toDefine}}</b></div>
      `;
    }}

    function filterItems() {{
      const q = document.getElementById('searchInput').value.toLowerCase();
      const cat = document.getElementById('categoryFilter').value;
      const org = document.getElementById('organFilter').value;
      const val = document.getElementById('validationFilter').value;
      const blk = document.getElementById('blockingFilter').value;

      return rawItems.filter(item => {{
        if (cat !== 'ALL' && item.category !== cat) return false;
        if (org !== 'ALL') {{
          const organNorm = (item.organ || '').toUpperCase();
          if (!organNorm.includes(org)) return false;
        }}
        if (val !== 'ALL' && item.statut_validation !== val) return false;
        if (blk === 'BLOCKING' && !item.blocking) return false;
        if (blk === 'NON_BLOCKING' && item.blocking) return false;

        if (q) {{
          const corpus = [
            item.id,
            item.text,
            item.organ,
            item.code,
            item.condition,
            item.cause_racine,
            item.action_conducteur,
            item.action_maintenance,
            item.points_test,
            item.source_file,
            ...(item.keywords || [])
          ].join(' ').toLowerCase();

          return corpus.includes(q);
        }}

        return true;
      }});
    }}

    function render() {{
      const filtered = filterItems();
      document.getElementById('resultsCount').innerText = `Affichage de ${{filtered.length}} élément(s) sur ${{rawItems.length}}`;

      if (currentView === 'card') {{
        renderCards(filtered);
      }} else {{
        renderTable(filtered);
      }}
    }}

    function renderCards(items) {{
      const container = document.getElementById('cardsContainer');
      container.innerHTML = '';

      items.forEach(item => {{
        const card = document.createElement('div');
        const isBlocking = item.blocking;
        const isAction = item.category === 'OPERATOR_ACTION';
        const isHisto = item.category === 'HISTO_ALARM';
        const isValidated = (item.statut_validation === 'VALIDÉ');
        
        card.className = `card ${{isBlocking ? 'blocking' : ''}} ${{isAction ? 'action' : ''}} ${{isHisto ? 'histo' : ''}}`;
        
        // Extraction des boutons de repérage LED E/S
        const ioRefs = extractIoRefs(item.points_test, item.condition);
        const ioButtonsHtml = ioRefs.length > 0 ? `
          <div class="io-buttons-group">
            ${{ioRefs.map(r => `<button class="btn-locate-led" onclick="locateRackChannel('${{r.query}}', '${{escapeHtml(r.label)}}')" title="Situer sur la face avant automate">🖲️ Situer LED ${{escapeHtml(r.label)}}</button>`).join('')}}
          </div>
        ` : '';

        card.innerHTML = `
          <div class="card-header">
            <div class="badges">
              <span class="badge badge-organ">${{item.organ || 'GÉNÉRAL'}}</span>
              ${{item.code && item.code !== '-' ? `<span class="badge badge-code">${{item.code}}</span>` : ''}}
              <span class="badge ${{isBlocking ? 'badge-blocking' : (isHisto ? 'badge-histo' : '')}}">
                ${{item.level || item.category}}
              </span>
              <span class="badge ${{isValidated ? 'badge-val-ok' : 'badge-val-todo'}}">
                ${{item.statut_validation}}
              </span>
            </div>
            <div class="card-actions">
              <button class="btn-edit" onclick="openEditModal('${{item.id}}')">✏️ Proposer</button>
            </div>
          </div>

          <div class="card-text">${{escapeHtml(item.text)}}</div>

          <div class="st-condition">
            <span>ST TRIGGER :</span>${{escapeHtml(item.condition || '-')}}
          </div>

          <div class="section-block">
            <b>🔍 Cause</b>
            <div class="${{item.cause_racine && item.cause_racine !== item.condition ? 'val-set' : 'val-missing'}}">
              ${{escapeHtml(item.cause_racine && item.cause_racine !== item.condition ? item.cause_racine : '[À définir ensemble]')}}
            </div>
          </div>

          <div class="section-block">
            <b>🕹️ Action Utilisateur</b>
            <div class="${{item.action_conducteur ? 'val-set' : 'val-missing'}}">
              ${{escapeHtml(item.action_conducteur || '[À définir ensemble]')}}
            </div>
          </div>

          <div class="section-block">
            <b>🔧 Action Maintenance</b>
            <div class="${{item.action_maintenance ? 'val-set' : 'val-missing'}}">
              ${{escapeHtml(item.action_maintenance || '[À définir ensemble]')}}
            </div>
          </div>

          ${{item.points_test ? `
            <div class="section-block">
              <b>⚡ Points de Test & Câblage Matériel</b>
              <div class="val-set">${{escapeHtml(item.points_test)}}</div>
              ${{ioButtonsHtml}}
            </div>
          ` : (ioButtonsHtml ? `
            <div class="section-block">
              <b>⚡ Raccordement E/S Automate Détecté</b>
              ${{ioButtonsHtml}}
            </div>
          ` : '')}}

          <div class="card-footer">
            <span>📄 ${{item.source_file}} : L${{item.line}}</span>
            <span>${{item.id}}</span>
          </div>
        `;

        container.appendChild(card);
      }});
    }}

    function renderTable(items) {{
      const tbody = document.getElementById('tableBody');
      tbody.innerHTML = '';

      items.forEach(item => {{
        const ioRefs = extractIoRefs(item.points_test, item.condition);
        const ioBtns = ioRefs.length > 0 ? `
          <div style="margin-top:4px;display:flex;flex-wrap:wrap;gap:2px;">
            ${{ioRefs.map(r => `<button class="btn-locate-led" style="font-size:0.65rem;padding:1px 5px;" onclick="locateRackChannel('${{r.query}}', '${{escapeHtml(r.label)}}')" title="Situer sur la face avant">🖲️ ${{escapeHtml(r.query)}}</button>`).join('')}}
          </div>
        ` : '';

        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td style="font-family:var(--font-mono);font-weight:bold;color:var(--accent-blue);">${{item.id}}</td>
          <td><span class="badge badge-organ">${{item.organ}}</span></td>
          <td style="font-family:var(--font-mono);color:var(--accent-amber);">${{item.code}}</td>
          <td style="font-weight:bold;color:#fff;">${{escapeHtml(item.text)}}</td>
          <td style="font-family:var(--font-mono);font-size:0.75rem;color:#94a3b8;">${{escapeHtml(item.condition)}}</td>
          <td>${{escapeHtml(item.cause_racine !== item.condition ? item.cause_racine : '-')}}</td>
          <td style="color:#6ee7b7;">${{escapeHtml(item.action_conducteur || '-')}}</td>
          <td style="font-size:0.75rem;">
            ${{escapeHtml(item.points_test || '-')}}
            ${{ioBtns}}
          </td>
          <td><span class="badge ${{item.statut_validation === 'VALIDÉ' ? 'badge-val-ok' : 'badge-val-todo'}}">${{item.statut_validation}}</span></td>
          <td style="font-family:var(--font-mono);font-size:0.75rem;color:var(--text-muted);">${{item.source_file}}:L${{item.line}}</td>
        `;
        tbody.appendChild(tr);
      }});
    }}

    function setViewMode(mode) {{
      currentView = mode;
      if (mode === 'card') {{
        document.getElementById('cardsContainer').style.display = 'grid';
        document.getElementById('tableContainer').style.display = 'none';
        document.getElementById('btnCardView').classList.add('active');
        document.getElementById('btnTableView').classList.remove('active');
      }} else {{
        document.getElementById('cardsContainer').style.display = 'none';
        document.getElementById('tableContainer').style.display = 'block';
        document.getElementById('btnCardView').classList.remove('active');
        document.getElementById('btnTableView').classList.add('active');
      }}
      render();
    }}

    /* ========================================================================== */
    /* 🖲️ GESTIONNAIRE DE LA FACE AVANT AUTOMATE & RACK E/S                      */
    /* ========================================================================== */
    function renderRack() {{
      const container = document.getElementById('rackCardsContainer');
      if (!container || !rackData || !rackData.modules) return;
      container.innerHTML = '';

      const slotBadges = {{
        "Local_Digital_IO": "badge-slot1",
        "VH_0808ETP": "badge-slot2",
        "VH_0800END": "badge-slot3",
        "VH_0008ER": "badge-slot4",
        "VH_0008ER_1": "badge-slot5"
      }};

      rackData.modules.forEach(mod => {{
        const hasIn = (mod.inputs && mod.inputs.length > 0);
        const hasOut = (mod.outputs && mod.outputs.length > 0);
        const isDual = (hasIn && hasOut);
        const isRelay = mod.dev_id.includes('ER');

        const card = document.createElement('div');
        card.className = `rack-card ${{isDual ? 'dual-card' : 'single-card'}}`;
        card.id = `rack-mod-${{mod.dev_id}}`;
        card.onclick = (e) => toggleCardActive(mod.dev_id, e);

        let bodyHtml = '';

        if (isDual) {{
          // Carte à double rangée physique (Gauche = IN / Droite = OUT)
          bodyHtml = `
            <div class="rack-card-body rack-card-dual">
              <div class="rack-col col-in">
                <div class="rack-col-header">
                  <span class="col-title">ENTRÉES (DI)</span>
                  <span class="col-badge badge-in">${{mod.inputs.length}} DI</span>
                </div>
                <div>
                  ${{mod.inputs.map(ch => renderChannelRow(ch, mod, 'DI')).join('')}}
                </div>
              </div>
              <div class="rack-col col-out">
                <div class="rack-col-header">
                  <span class="col-title">SORTIES (DQ)</span>
                  <span class="col-badge badge-out">${{mod.outputs.length}} DQ</span>
                </div>
                <div>
                  ${{mod.outputs.map(ch => renderChannelRow(ch, mod, 'DQ')).join('')}}
                </div>
              </div>
            </div>
          `;
        }} else if (hasIn) {{
          // Carte à simple rangée physique : ENTRÉES UNIQUEMENT (ex: VH_0800END)
          bodyHtml = `
            <div class="rack-card-body rack-card-single">
              <div class="rack-col col-in">
                <div class="rack-col-header">
                  <span class="col-title">ENTRÉES NUMÉRIQUES (DI)</span>
                  <span class="col-badge badge-in">${{mod.inputs.length}} DI</span>
                </div>
                <div>
                  ${{mod.inputs.map(ch => renderChannelRow(ch, mod, 'DI')).join('')}}
                </div>
              </div>
            </div>
          `;
        }} else if (hasOut) {{
          // Carte à simple rangée physique : SORTIES UNIQUEMENT (ex: VH_0008ER / VH_0008ER_1)
          bodyHtml = `
            <div class="rack-card-body rack-card-single">
              <div class="rack-col ${{isRelay ? 'col-relay' : 'col-out'}}">
                <div class="rack-col-header">
                  <span class="col-title">SORTIES RELAIS (${{isRelay ? 'RQ' : 'DQ'}})</span>
                  <span class="col-badge ${{isRelay ? 'badge-relay' : 'badge-out'}}">${{mod.outputs.length}} DO</span>
                </div>
                <div>
                  ${{mod.outputs.map(ch => renderChannelRow(ch, mod, isRelay ? 'RQ' : 'DQ')).join('')}}
                </div>
              </div>
            </div>
          `;
        }}

        const badgeClass = slotBadges[mod.dev_id] || 'badge-slot1';

        card.innerHTML = `
          <div class="rack-card-head">
            <span class="rack-card-badge ${{badgeClass}}">${{mod.slot}}</span>
            <div class="rack-card-name">${{escapeHtml(mod.name)}}</div>
            <div class="rack-card-sub">${{escapeHtml(mod.desc)}}</div>
            <div class="rack-card-range">${{escapeHtml(mod.range_summary || '')}}</div>
          </div>
          ${{bodyHtml}}
        `;

        container.appendChild(card);
      }});
    }}

    function renderChannelRow(ch, mod, kind) {{
      const isOut = (kind === 'DQ' || kind === 'RQ');
      const safeVar = escapeHtml(ch.var || '');
      const safeDesc = escapeHtml(ch.desc || (ch.var ? '' : 'Voie de réserve'));
      const safeAddr = ch.addr || '-';
      const cleanId = (ch.addr || `${{mod.dev_id}}_B${{ch.bit}}`).replace(/[%.-]/g, '_');
      const varDisplay = ch.var ? safeVar : '<span style="color:#64748b;font-style:italic;">[Réserve]</span>';

      return `
        <div class="rack-channel-row" 
             id="ch-${{cleanId}}"
             data-addr="${{safeAddr}}"
             data-var="${{safeVar}}"
             data-var-lower="${{safeVar.toLowerCase()}}"
             data-desc="${{safeDesc.toLowerCase()}}"
             data-module="${{mod.slot}} (${{mod.dev_id}})"
             onclick="handleChannelClick('${{safeAddr}}')"
             title="Cliquer pour allumer/éteindre et copier les infos : ${{safeAddr}} · ${{ch.var || 'Réservé'}} · ${{ch.desc || ''}}">
          <span class="led-dot" id="led-${{cleanId}}"></span>
          <span class="ch-bit">B${{ch.bit}}</span>
          <span class="ch-addr ${{isOut ? 'out' : ''}}">${{safeAddr}}</span>
          <div class="ch-details">
            <div class="ch-var">${{varDisplay}}</div>
            <span class="ch-desc">${{safeDesc}}</span>
          </div>
        </div>
      `;
    }}

    function openRackModal() {{
      document.getElementById('rackModal').style.display = 'flex';
      const container = document.getElementById('rackCardsContainer');
      if (!container.children.length) {{
        renderRack();
      }}
      syncRackSlider();
    }}

    function closeRackModal() {{
      document.getElementById('rackModal').style.display = 'none';
    }}

    function copyToClipboard(text) {{
      if (navigator.clipboard && window.isSecureContext) {{
        navigator.clipboard.writeText(text).catch(() => fallbackCopy(text));
      }} else {{
        fallbackCopy(text);
      }}
    }}

    function fallbackCopy(text) {{
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      try {{ document.execCommand('copy'); }} catch (e) {{}}
      document.body.removeChild(ta);
    }}

    function clearAllLeds() {{
      document.querySelectorAll('.led-dot.led-on').forEach(l => l.classList.remove('led-on'));
      document.querySelectorAll('.led-dot.led-target').forEach(l => l.classList.remove('led-target'));
      clearRackTarget();
      showToast('💡 Toutes les LEDs sont éteintes.');
    }}

    let isAllExpanded = false;

    function toggleExpandAll() {{
      isAllExpanded = !isAllExpanded;
      const container = document.getElementById('rackCardsContainer');
      const btn = document.getElementById('btnToggleExpandAll');
      if (isAllExpanded) {{
        container.classList.remove('accordion-mode');
        container.classList.add('all-expanded');
        btn.innerHTML = '🗜️ Vue Compacte (1 Écran)';
        btn.style.borderColor = 'var(--accent-blue)';
        btn.style.color = 'var(--accent-blue)';
        showToast('🖼️ Mode Tout Déployé (Vue Large / Capture)');
      }} else {{
        container.classList.remove('all-expanded');
        container.classList.add('accordion-mode');
        btn.innerHTML = '↔️ Tout Déployer (Capture)';
        btn.style.borderColor = '';
        btn.style.color = '';
        showToast('🗜️ Mode Accordéon Compact (1 Écran)');
      }}
      syncRackSlider();
    }}

    function toggleCardActive(devId, event) {{
      if (event && event.target.closest('.rack-channel-row')) return;
      const card = document.getElementById('rack-mod-' + devId);
      if (!card) return;
      const wasActive = card.classList.contains('active-slot');
      document.querySelectorAll('.rack-card.active-slot').forEach(c => c.classList.remove('active-slot'));
      if (!wasActive) {{
        card.classList.add('active-slot');
      }}
    }}

    function scrollRack(direction) {{
      const scrollEl = document.getElementById('rackCardsContainer');
      if (!scrollEl) return;
      const step = 420;
      scrollEl.scrollBy({{ left: direction * step, behavior: 'smooth' }});
    }}

    function handleRackSlider(val) {{
      const scrollEl = document.getElementById('rackCardsContainer');
      if (!scrollEl) return;
      const maxScroll = scrollEl.scrollWidth - scrollEl.clientWidth;
      scrollEl.scrollLeft = (val / 100) * maxScroll;
    }}

    function syncRackSlider() {{
      const scrollEl = document.getElementById('rackCardsContainer');
      const slider = document.getElementById('rackScrollSlider');
      if (!scrollEl || !slider) return;
      const maxScroll = scrollEl.scrollWidth - scrollEl.clientWidth;
      if (maxScroll <= 0) {{
        slider.value = 0;
        return;
      }}
      slider.value = Math.round((scrollEl.scrollLeft / maxScroll) * 100);
    }}

    function jumpToSlot(devId) {{
      const card = document.getElementById('rack-mod-' + devId);
      if (card) {{
        document.querySelectorAll('.rack-card.active-slot').forEach(c => c.classList.remove('active-slot'));
        card.classList.add('active-slot');
        card.scrollIntoView({{ behavior: 'smooth', block: 'nearest', inline: 'center' }});
        card.classList.add('rack-card-targeted');
        setTimeout(() => {{ card.classList.remove('rack-card-targeted'); }}, 1800);
      }}
    }}

    function handleChannelClick(addr) {{
      const cleanId = addr.replace(/[%.-]/g, '_');
      const row = document.getElementById('ch-' + cleanId);
      const led = document.getElementById('led-' + cleanId);
      
      // 1. Basculer l'état de la LED au clic
      if (led) {{
        led.classList.toggle('led-on');
      }}

      // 2. Mettre en valeur la voie et maintenir le slot ouvert
      clearRackTarget();
      if (row) {{
        row.classList.add('channel-targeted');
        const card = row.closest('.rack-card');
        if (card) {{
          document.querySelectorAll('.rack-card.active-slot').forEach(c => c.classList.remove('active-slot'));
          card.classList.add('active-slot');
          card.classList.add('rack-card-targeted');
        }}

        // 3. Copier dans le presse-papier les données de diagnostic
        const varName = row.dataset.var || '[Réserve]';
        const modName = row.dataset.module || '';
        const desc = row.dataset.desc || '';
        const clipText = `${{addr}} · ${{varName}} · ${{modName}} · ${{desc}}`;

        copyToClipboard(clipText);
        showToast(`📋 Copié : ${{addr}} (${{varName}})`);
      }}
    }}

    function clearRackTarget() {{
      document.querySelectorAll('.rack-card.rack-card-targeted').forEach(c => c.classList.remove('rack-card-targeted'));
      document.querySelectorAll('.rack-channel-row.channel-targeted').forEach(r => r.classList.remove('channel-targeted'));
      document.querySelectorAll('.led-dot.led-target').forEach(l => l.classList.remove('led-target'));
      currentTargetedChannel = null;
    }}

    function highlightRackChannel(query) {{
      clearRackTarget();
      if (!query) return;

      const norm = query.trim().toUpperCase();
      const normLower = query.trim().toLowerCase();

      let targetRow = document.querySelector(`.rack-channel-row[data-addr="${{norm}}"]`);
      if (!targetRow) {{
        targetRow = document.querySelector(`.rack-channel-row[data-var-lower="${{normLower}}"]`);
      }}
      if (!targetRow) {{
        targetRow = document.querySelector(`.rack-channel-row[data-addr*="${{norm}}"]`);
      }}

      if (targetRow) {{
        currentTargetedChannel = targetRow;
        targetRow.classList.add('channel-targeted');
        const led = targetRow.querySelector('.led-dot');
        if (led) {{
          led.classList.add('led-on');
          led.classList.add('led-target');
        }}

        const card = targetRow.closest('.rack-card');
        if (card) {{
          document.querySelectorAll('.rack-card.active-slot').forEach(c => c.classList.remove('active-slot'));
          card.classList.add('active-slot');
          card.classList.add('rack-card-targeted');
          card.scrollIntoView({{ behavior: 'smooth', block: 'nearest', inline: 'center' }});
        }}
        targetRow.scrollIntoView({{ behavior: 'smooth', block: 'center', inline: 'nearest' }});

        // Copie automatique lors du ciblage
        const varName = targetRow.dataset.var || '[Réserve]';
        const modName = targetRow.dataset.module || '';
        const desc = targetRow.dataset.desc || '';
        const clipText = `${{targetRow.dataset.addr}} · ${{varName}} · ${{modName}} · ${{desc}}`;
        copyToClipboard(clipText);

        showToast(`📍 LED localisée & copiée : ${{targetRow.dataset.addr}} (${{varName}})`);
      }} else {{
        showToast(`⚠️ Voie introuvable sur le rack : ${{query}}`);
      }}
    }}

    function locateRackChannel(query, label) {{
      openRackModal();
      setTimeout(() => {{
        highlightRackChannel(query);
      }}, 150);
    }}

    function filterRackChannels() {{
      const q = document.getElementById('rackSearchInput').value.trim().toLowerCase();
      const rows = document.querySelectorAll('.rack-channel-row');
      let matchCount = 0;

      rows.forEach(row => {{
        if (!q) {{
          row.classList.remove('dimmed');
          matchCount++;
          return;
        }}
        const text = [
          row.dataset.addr || '',
          row.dataset.var || '',
          row.dataset.desc || '',
          row.dataset.module || ''
        ].join(' ').toLowerCase();

        if (text.includes(q)) {{
          row.classList.remove('dimmed');
          matchCount++;
        }} else {{
          row.classList.add('dimmed');
        }}
      }});

      document.getElementById('rackMatchCount').innerText = q ? `${{matchCount}} voie(s) trouvée(s)` : '';
    }}

    function extractIoRefs(pointsTest, condition) {{
      const text = (pointsTest || '') + ' ' + (condition || '');
      const refs = [];
      const seen = new Set();

      // 1. Détection des adresses absolues %IX... et %QX...
      const addrRegex = /%(?:IX|QX)\\\\d+\\\\.\\\\d+/gi;
      let m;
      while ((m = addrRegex.exec(text)) !== null) {{
        const addr = m[0].toUpperCase();
        if (!seen.has(addr)) {{
          seen.add(addr);
          let label = addr;
          if (rackData && rackData.by_addr && rackData.by_addr[addr.toLowerCase()]) {{
            const ch = rackData.by_addr[addr.toLowerCase()];
            if (ch.var) label = `${{addr}} (${{ch.var}})`;
          }}
          refs.push({{ query: addr, label: label }});
        }}
      }}

      // 2. Détection par nom de variable E/S connue
      if (rackData && rackData.by_var) {{
        for (const [varLower, info] of Object.entries(rackData.by_var)) {{
          if (info.var && !seen.has(info.addr)) {{
            const re = new RegExp('\\\\b' + info.var + '\\\\b', 'i');
            if (re.test(text)) {{
              seen.add(info.addr);
              refs.push({{ query: info.addr, label: `${{info.addr}} (${{info.var}})` }});
            }}
          }}
        }}
      }}

      return refs;
    }}

    /* Export CSV de la sélection filtrée */
    function exportFilteredCSV() {{
      const filtered = filterItems();
      const headers = ["ID", "Organe", "Code", "Message ST", "Condition ST", "Cause", "Action Utilisateur", "Action Maintenance", "Points Test", "Source", "Ligne"];
      
      const rows = filtered.map(i => [
        `"${{(i.id || '').replace(/"/g, '""')}}"`,
        `"${{(i.organ || '').replace(/"/g, '""')}}"`,
        `"${{(i.code || '').replace(/"/g, '""')}}"`,
        `"${{(i.text || '').replace(/"/g, '""')}}"`,
        `"${{(i.condition || '').replace(/"/g, '""')}}"`,
        `"${{(i.cause_racine !== i.condition ? i.cause_racine : '').replace(/"/g, '""')}}"`,
        `"${{(i.action_conducteur || '').replace(/"/g, '""')}}"`,
        `"${{(i.action_maintenance || '').replace(/"/g, '""')}}"`,
        `"${{(i.points_test || '').replace(/"/g, '""')}}"`,
        `"${{(i.source_file || '').replace(/"/g, '""')}}"`,
        `"${{i.line || ''}}"`
      ]);

      const csvContent = "\\ufeff" + headers.join(";") + "\\n" + rows.map(r => r.join(";")).join("\\n");
      downloadBlob(csvContent, "omnidiag_selection.csv", "text/csv;charset=utf-8;");
    }}

    /* Export Excel HTML compatible de la sélection */
    function exportFilteredExcelHTML() {{
      const filtered = filterItems();
      let tableHtml = '<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40">';
      tableHtml += '<head><meta charset="utf-8"><!--[if gte mso 9]><xml><x:ExcelWorkbook><x:ExcelWorksheets><x:ExcelWorksheet><x:Name>OMNIDIAG</x:Name><x:WorksheetOptions><x:DisplayGridlines/></x:WorksheetOptions></x:ExcelWorksheet></x:ExcelWorksheets></x:ExcelWorkbook></xml><![endif]--></head><body>';
      tableHtml += '<table border="1"><tr><th>ID</th><th>Organe</th><th>Code</th><th>Message ST</th><th>Condition ST</th><th>Cause</th><th>Action Utilisateur</th><th>Action Maintenance</th><th>Points Test</th><th>Fichier</th><th>Ligne</th></tr>';
      
      filtered.forEach(i => {{
        tableHtml += `<tr>
          <td>${{escapeHtml(i.id)}}</td>
          <td>${{escapeHtml(i.organ)}}</td>
          <td>${{escapeHtml(i.code)}}</td>
          <td><b>${{escapeHtml(i.text)}}</b></td>
          <td>${{escapeHtml(i.condition)}}</td>
          <td>${{escapeHtml(i.cause_racine !== i.condition ? i.cause_racine : '')}}</td>
          <td>${{escapeHtml(i.action_conducteur)}}</td>
          <td>${{escapeHtml(i.action_maintenance)}}</td>
          <td>${{escapeHtml(i.points_test)}}</td>
          <td>${{escapeHtml(i.source_file)}}</td>
          <td>${{i.line}}</td>
        </tr>`;
      }});
      tableHtml += '</table></body></html>';

      downloadBlob(tableHtml, "omnidiag_selection.xls", "application/vnd.ms-excel");
    }}

    function downloadBlob(content, filename, contentType) {{
      const blob = new Blob([content], {{ type: contentType }});
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      showToast(`Fichier ${{filename}} téléchargé !`);
    }}

    /* Modale d'édition */
    function openEditModal(id) {{
      const item = rawItems.find(i => i.id === id);
      if (!item) return;
      currentEditItem = item;

      document.getElementById('modalTitle').innerText = `✏️ Fiche [${{item.id}}] — ${{item.organ}}`;
      document.getElementById('modalItemInfo').innerText = `${{item.source_file}} : Ligne ${{item.line}} | Code: ${{item.code}}`;
      document.getElementById('modalRawText').value = item.text;
      document.getElementById('modalCause').value = item.cause_racine !== item.condition ? item.cause_racine : '';
      document.getElementById('modalActionOp').value = item.action_conducteur || '';
      document.getElementById('modalActionMaint').value = item.action_maintenance || '';
      document.getElementById('modalPointsTest').value = item.points_test || '';

      document.getElementById('editModal').style.display = 'flex';
    }}

    function closeModal() {{
      document.getElementById('editModal').style.display = 'none';
      currentEditItem = null;
    }}

    function saveModalData() {{
      if (!currentEditItem) return;
      const id = currentEditItem.id;
      const cause = document.getElementById('modalCause').value.trim();
      const actOp = document.getElementById('modalActionOp').value.trim();
      const actMaint = document.getElementById('modalActionMaint').value.trim();
      const pts = document.getElementById('modalPointsTest').value.trim();

      // Mise à jour locale
      currentEditItem.cause_racine = cause || currentEditItem.condition;
      currentEditItem.action_conducteur = actOp;
      currentEditItem.action_maintenance = actMaint;
      currentEditItem.points_test = pts;
      currentEditItem.statut_validation = (cause || actOp || actMaint) ? 'VALIDÉ' : 'À DÉFINIR';

      closeModal();
      initStats();
      render();

      // Envoi au serveur (supporte http:// et file:/// via port 8081)
      const apiBase = window.location.protocol.startsWith('http') ? '' : 'http://127.0.0.1:8081';
      fetch(apiBase + '/api/omnidiag/save-kb', {{
        method: 'POST',
        headers: {{ 'Content-Type': 'application/json' }},
        body: JSON.stringify({{
          id: id,
          cause_racine: cause,
          action_conducteur: actOp,
          action_maintenance: actMaint,
          points_test: pts
        }})
      }}).then(res => res.json()).then(data => {{
        showToast(`Fiche ${{id}} enregistrée dans la base technique !`);
      }}).catch(() => {{
        showToast(`Fiche ${{id}} modifiée localement.`);
      }});
    }}

    /* Re-scan du code ST */
    function triggerRebuild() {{
      const btn = document.getElementById('btnRebuild');
      btn.innerText = '⏳ Scan en cours...';

      const apiBase = window.location.protocol.startsWith('http') ? '' : 'http://127.0.0.1:8081';
      fetch(apiBase + '/api/omnidiag/rebuild', {{ method: 'POST', headers: {{ 'Content-Type': 'application/json' }}, body: JSON.stringify({{}}) }})
        .then(res => res.json())
        .then(data => {{
          if (data.success) {{
            fetch(apiBase + '/api/omnidiag/data')
              .then(r => r.json())
              .then(d => {{
                rawItems = d.items;
                if (d.rack_data) {{
                  rackData = d.rack_data;
                  renderRack();
                }}
                initStats();
                render();
                btn.innerText = '🔄 Re-scanner le code ST';
                showToast('✅ Code ST re-scanné et données synchronisées !');
              }})
              .catch(() => {{
                btn.innerText = '🔄 Re-scanner le code ST';
                window.location.reload();
              }});
          }} else {{
            btn.innerText = '🔄 Re-scanner le code ST';
            alert('Erreur lors du scan : ' + (data.output || data.error || 'Erreur inconnue'));
          }}
        }})
        .catch(err => {{
          btn.innerText = '🔄 Re-scanner le code ST';
          alert("Serveur OMNIDIAG / Task Manager non joignable sur http://127.0.0.1:8081.\\n\\nAssurez-vous que le serveur est lancé, ou lancez :\\nTOOLS\\\\OMNIDIAG\\\\OMNIDIAG_START.bat -r");
        }});
    }}

    function showToast(msg) {{
      const t = document.getElementById('toastMsg');
      t.innerText = msg;
      t.style.display = 'block';
      setTimeout(() => {{ t.style.display = 'none'; }}, 3000);
    }}

    function escapeHtml(str) {{
      if (!str) return '';
      return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
    }}

    window.addEventListener('keydown', (e) => {{
      if (e.key === 'Escape') {{
        closeRackModal();
        closeModal();
      }}
    }});

    document.getElementById('searchInput').addEventListener('input', render);
    document.getElementById('categoryFilter').addEventListener('change', render);
    document.getElementById('organFilter').addEventListener('change', render);
    document.getElementById('validationFilter').addEventListener('change', render);
    document.getElementById('blockingFilter').addEventListener('change', render);

    initStats();
    render();
    renderRack();
  </script>
</body>
</html>
"""

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html_content)
