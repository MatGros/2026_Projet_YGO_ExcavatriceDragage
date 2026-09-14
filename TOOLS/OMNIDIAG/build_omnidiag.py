"""
===============================================================================
🚀 OMNIDIAG — Orchestrateur Principal d'Extraction & Génération
===============================================================================
🎯 Rôle : Point d'entrée CLI autonome pour :
   1. Parser l'ensemble du code source CODESYS (.st)
   2. Enrichir les données avec le moteur d'expertise diagnostic
   3. Exporter en Excel multi-onglets (.xlsx)
   4. Exporter en CSV universel (.csv)
   5. Générer l'application web interactive hors-ligne (.html)
===============================================================================
"""

import os
import sys
import argparse
from pathlib import Path

# Résolution des imports locaux
CURRENT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CURRENT_DIR))

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

import parser
import enricher
import generator_excel
import generator_html
import io_mapper


def main():
    parser_cli = argparse.ArgumentParser(
        description="OMNIDIAG — Outil d'extraction et de visualisation interactive des diagnostics CODESYS"
    )
    parser_cli.add_argument(
        "--root",
        type=Path,
        default=CURRENT_DIR.parent.parent,
        help="Racine du dépôt git du projet (défaut : racine parente)"
    )
    parser_cli.add_argument(
        "--outdir",
        type=Path,
        default=CURRENT_DIR / "EXPORTS",
        help="Dossier de destination des exports (défaut : TOOLS/OMNIDIAG/EXPORTS)"
    )
    args = parser_cli.parse_args()

    repo_root = args.root.resolve()
    outdir = args.outdir.resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    print("=" * 65)
    print("🧭 OMNIDIAG — EXTRACTION & VISUALISATION DES DIAGNOSTICS")
    print("=" * 65)
    print(f"📁 Racine du projet : {repo_root}")
    print(f"📦 Dossier d'export : {outdir}\n")

    # 1. Extraction ST
    print("⏳ [1/4] Parsing des fichiers sources ST (FB_Hmi_BannerFormatter, etc.)...")
    raw_items = parser.run_full_extraction(repo_root)
    print(f"   ✅ {len(raw_items)} éléments bruts extraits du code source.\n")

    # 2. Enrichissement expert
    print("⏳ [2/4] Enrichissement avec les règles expertes & base de connaissances...")
    kb_path = CURRENT_DIR / "knowledge_base.json"
    enriched_items = enricher.enrich_all(raw_items, kb_path)
    print(f"   ✅ {len(enriched_items)} éléments enrichis (causes, actions, maintenance).\n")

    # 3. Export Excel & CSV
    excel_path = outdir / "omnidiag_alarms_and_messages.xlsx"
    csv_path = outdir / "omnidiag_alarms_and_messages.csv"
    print(f"⏳ [3/4] Génération des exports tabulaires...")
    generator_excel.export_to_excel(enriched_items, excel_path)
    print(f"   📊 Excel généré : {excel_path}")
    generator_excel.export_to_csv(enriched_items, csv_path)
    print(f"   📄 CSV généré   : {csv_path}\n")

    # 4. Génération Application Web HTML
    html_path = outdir / "omnidiag_viewer.html"
    print("⏳ [4/4] Compilation de l'application web monopage interactive...")
    rack_data = io_mapper.parse_rack_io(repo_root)
    generator_html.generate_html_viewer(enriched_items, html_path, rack_data)
    print(f"   🌐 Application HTML interactive : {html_path}\n")

    print("=" * 65)
    print("✅ OPÉRATION TERMINÉE AVEC SUCCÈS")
    print(f"👉 Ouvrez dans votre navigateur : file:///{html_path.as_posix()}")
    print("=" * 65)


if __name__ == "__main__":
    main()
