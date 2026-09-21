#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Générateur de la vue Lumineuse & Animée pour le Cycle Automatique de Dragage
"""
import os
import sys
import json

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def build_cycle_auto():
    json_path = os.path.join(SCRIPT_DIR, "data_auto.json")
    html_path = os.path.join(SCRIPT_DIR, "cycle_auto_lumineux.html")

    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    with open(html_path, "r", encoding="utf-8") as f:
        html = f.read()

    # Embed data directly
    json_embedded = "const AUTO_DATA = " + json.dumps(data, ensure_ascii=False) + ";"
    
    # Replace variable declaration and loadData
    if "let AUTO_DATA = null;" in html:
        html = html.replace("let AUTO_DATA = null;", json_embedded)
    
    old_loader = """    // Load Data
    async function loadData() {
      try {
        const res = await fetch("data_auto.json");
        AUTO_DATA = await res.json();
      } catch (e) {
        console.error("Fetch local data_auto.json failed, falling back to embedded data", e);
      }
      initApp();
    }"""

    new_loader = """    // Load Data (Direct Offline Safe)
    function loadData() {
      initApp();
    }"""

    if old_loader in html:
        html = html.replace(old_loader, new_loader)

    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html)

    print("============================================================")
    print("✅ CYCLE AUTO LUMINEUX EMBARQUÉ AVEC SUCCÈS")
    print("============================================================")
    print(f"📄 Fichier généré : {html_path}")
    print(f"📊 Étapes compilées : {len(data.get('steps', []))}")
    print("============================================================")

if __name__ == "__main__":
    build_cycle_auto()
