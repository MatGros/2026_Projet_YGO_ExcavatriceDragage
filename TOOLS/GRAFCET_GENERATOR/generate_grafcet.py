#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
===============================================================================
🛠️ GRAFCET GENERATOR — Visualiseur & Simulateur Interactif de Séquenceur
===============================================================================
Projet : Excavatrice de Dragage en Carrière Noyée
Rôle   : Générateur HTML autonome pour visualiser et simuler les GRAFCET,
         graphes d'état et séquenceurs métier (Homing machine, Cycle Semi-Auto, etc.)
Usage  : python generate_grafcet.py [--cycle homing] [--output index.html]
===============================================================================
"""

import os
import sys
import json
import argparse

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Cockpit Séquenceur Interactif — {cycle_name}</title>
  <style>
    :root {{
      --bg-dark: #070a13;
      --bg-card: rgba(18, 24, 38, 0.85);
      --bg-card-active: rgba(28, 40, 68, 0.95);
      --border-subtle: rgba(255, 255, 255, 0.08);
      --border-active: #00e5ff;
      --primary: #00e5ff;
      --primary-glow: rgba(0, 229, 255, 0.35);
      --accent: #f59e0b;
      --accent-glow: rgba(245, 158, 11, 0.35);
      --success: #10b981;
      --success-glow: rgba(16, 185, 129, 0.35);
      --danger: #ef4444;
      --danger-glow: rgba(239, 68, 68, 0.35);
      --purple: #a855f7;
      --text-main: #f1f5f9;
      --text-muted: #94a3b8;
      --font-mono: 'Consolas', 'Monaco', 'Courier New', monospace;
      --font-ui: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    }}

    * {{
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }}

    body {{
      background: var(--bg-dark);
      background-image: 
        radial-gradient(circle at 15% 10%, rgba(0, 229, 255, 0.06) 0%, transparent 40%),
        radial-gradient(circle at 85% 85%, rgba(168, 85, 247, 0.06) 0%, transparent 40%),
        linear-gradient(to bottom, #070a13, #0b1120);
      color: var(--text-main);
      font-family: var(--font-ui);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      line-height: 1.5;
    }}

    /* Top Bar */
    header {{
      background: rgba(11, 17, 32, 0.92);
      backdrop-filter: blur(12px);
      border-bottom: 1px solid var(--border-subtle);
      position: sticky;
      top: 0;
      z-index: 100;
      padding: 12px 24px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
    }}

    .brand {{
      display: flex;
      align-items: center;
      gap: 14px;
    }}

    .brand-logo {{
      width: 42px;
      height: 42px;
      background: linear-gradient(135deg, #00e5ff, #3b82f6);
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
      box-shadow: 0 0 15px var(--primary-glow);
    }}

    .brand-text h1 {{
      font-size: 18px;
      font-weight: 700;
      letter-spacing: -0.5px;
      color: #fff;
    }}

    .brand-text p {{
      font-size: 12px;
      color: var(--text-muted);
      font-family: var(--font-mono);
    }}

    /* Cycle Tabs */
    .cycle-tabs {{
      display: flex;
      background: rgba(255, 255, 255, 0.04);
      padding: 4px;
      border-radius: 8px;
      border: 1px solid var(--border-subtle);
      gap: 4px;
    }}

    .cycle-tab {{
      padding: 6px 14px;
      font-size: 13px;
      font-weight: 600;
      border-radius: 6px;
      cursor: pointer;
      color: var(--text-muted);
      border: none;
      background: transparent;
      transition: all 0.2s ease;
    }}

    .cycle-tab.active {{
      background: var(--primary);
      color: #070a13;
      box-shadow: 0 0 12px var(--primary-glow);
    }}

    .cycle-tab.disabled {{
      opacity: 0.5;
      cursor: not-allowed;
    }}

    /* Live Status Cockpit */
    .cockpit-status {{
      display: flex;
      align-items: center;
      gap: 16px;
      background: rgba(0, 0, 0, 0.4);
      padding: 6px 16px;
      border-radius: 30px;
      border: 1px solid var(--border-subtle);
      font-size: 13px;
      font-family: var(--font-mono);
    }}

    .status-pill {{
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }}

    .status-dot {{
      width: 9px;
      height: 9px;
      border-radius: 50%;
      background: var(--success);
      box-shadow: 0 0 8px var(--success);
      animation: pulse 2s infinite;
    }}

    .status-dot.danger {{
      background: var(--danger);
      box-shadow: 0 0 8px var(--danger);
    }}

    @keyframes pulse {{
      0%, 100% {{ opacity: 1; transform: scale(1); }}
      50% {{ opacity: 0.4; transform: scale(0.85); }}
    }}

    /* Main Container */
    main {{
      display: grid;
      grid-template-columns: 340px 1fr;
      flex: 1;
      height: calc(100vh - 67px);
      overflow: hidden;
    }}

    /* Left Sidebar: Controls & Simulator */
    .sidebar {{
      background: rgba(13, 19, 33, 0.95);
      border-right: 1px solid var(--border-subtle);
      display: flex;
      flex-direction: column;
      overflow-y: auto;
    }}

    .panel-box {{
      padding: 16px;
      border-bottom: 1px solid var(--border-subtle);
    }}

    .panel-title {{
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: var(--text-muted);
      font-weight: 700;
      margin-bottom: 12px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }}

    /* Current Step Display */
    .current-step-hero {{
      background: linear-gradient(135deg, rgba(0, 229, 255, 0.12), rgba(59, 130, 246, 0.08));
      border: 1px solid var(--primary);
      border-radius: 12px;
      padding: 14px;
      box-shadow: 0 0 16px rgba(0, 229, 255, 0.15);
      position: relative;
      overflow: hidden;
    }}

    .hero-tag {{
      display: inline-block;
      font-size: 11px;
      font-weight: 700;
      color: var(--primary);
      background: rgba(0, 229, 255, 0.15);
      padding: 2px 8px;
      border-radius: 4px;
      margin-bottom: 6px;
      font-family: var(--font-mono);
    }}

    .hero-title {{
      font-size: 18px;
      font-weight: 800;
      color: #fff;
      display: flex;
      align-items: center;
      gap: 8px;
    }}

    .hero-instruction {{
      margin-top: 8px;
      font-size: 13px;
      color: #fcd34d;
      background: rgba(245, 158, 11, 0.12);
      padding: 8px 10px;
      border-radius: 6px;
      border-left: 3px solid var(--accent);
      font-weight: 500;
    }}

    /* Simulator Input Toggles */
    .sim-controls {{
      display: flex;
      flex-direction: column;
      gap: 10px;
    }}

    .sim-row {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: rgba(255, 255, 255, 0.03);
      padding: 8px 12px;
      border-radius: 8px;
      border: 1px solid var(--border-subtle);
    }}

    .sim-label {{
      font-size: 13px;
      font-weight: 500;
      display: flex;
      align-items: center;
      gap: 6px;
    }}

    .toggle-switch {{
      position: relative;
      width: 44px;
      height: 24px;
    }}

    .toggle-switch input {{
      opacity: 0;
      width: 0;
      height: 0;
    }}

    .slider {{
      position: absolute;
      cursor: pointer;
      top: 0; left: 0; right: 0; bottom: 0;
      background-color: #334155;
      transition: .2s;
      border-radius: 24px;
    }}

    .slider:before {{
      position: absolute;
      content: "";
      height: 18px;
      width: 18px;
      left: 3px;
      bottom: 3px;
      background-color: white;
      transition: .2s;
      border-radius: 50%;
    }}

    input:checked + .slider {{
      background-color: var(--success);
      box-shadow: 0 0 8px var(--success-glow);
    }}

    input:checked + .slider:before {{
      transform: translateX(20px);
    }}

    .btn-action {{
      width: 100%;
      padding: 9px 14px;
      border-radius: 8px;
      border: none;
      font-weight: 600;
      font-size: 13px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      transition: all 0.2s ease;
    }}

    .btn-pulse {{
      background: linear-gradient(135deg, #0284c7, #0369a1);
      color: white;
      box-shadow: 0 2px 8px rgba(2, 132, 199, 0.3);
    }}

    .btn-pulse:hover {{
      background: linear-gradient(135deg, #0ea5e9, #0284c7);
      box-shadow: 0 0 14px rgba(14, 165, 233, 0.5);
    }}

    .btn-danger {{
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid var(--danger);
      color: #fca5a5;
    }}

    .btn-danger:hover {{
      background: var(--danger);
      color: white;
      box-shadow: 0 0 12px var(--danger-glow);
    }}

    /* Quick Jump Dropdown */
    .jump-select {{
      width: 100%;
      background: #1e293b;
      color: white;
      border: 1px solid var(--border-subtle);
      border-radius: 8px;
      padding: 8px 12px;
      font-size: 13px;
      font-family: var(--font-mono);
      cursor: pointer;
    }}

    /* Main View Area */
    .content-area {{
      display: flex;
      flex-direction: column;
      overflow-y: auto;
      background: rgba(10, 15, 29, 0.6);
      padding: 24px;
      gap: 20px;
    }}

    /* Filter & Search Bar */
    .filter-bar {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 16px;
      background: rgba(18, 24, 38, 0.7);
      padding: 10px 16px;
      border-radius: 12px;
      border: 1px solid var(--border-subtle);
    }}

    .search-input {{
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--border-subtle);
      border-radius: 8px;
      padding: 8px 14px;
      font-size: 13px;
      color: white;
      width: 300px;
      font-family: var(--font-ui);
    }}

    .search-input:focus {{
      outline: none;
      border-color: var(--primary);
      box-shadow: 0 0 8px var(--primary-glow);
    }}

    .view-modes {{
      display: flex;
      gap: 8px;
    }}

    .mode-btn {{
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--border-subtle);
      color: var(--text-muted);
      border-radius: 6px;
      padding: 6px 12px;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: all 0.2s;
    }}

    .mode-btn.active {{
      background: rgba(0, 229, 255, 0.15);
      color: var(--primary);
      border-color: var(--primary);
    }}

    /* Pipeline Step Timeline / Cards Grid */
    .steps-pipeline {{
      display: flex;
      flex-direction: column;
      gap: 18px;
      position: relative;
    }}

    /* Modern Step Card */
    .step-card {{
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      border-radius: 14px;
      padding: 20px;
      transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      position: relative;
      backdrop-filter: blur(8px);
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
    }}

    .step-card:hover {{
      border-color: rgba(255, 255, 255, 0.2);
      transform: translateY(-2px);
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.35);
    }}

    .step-card.active-step {{
      background: var(--bg-card-active);
      border-color: var(--primary);
      box-shadow: 0 0 25px rgba(0, 229, 255, 0.25);
    }}

    .step-card.active-step::before {{
      content: "";
      position: absolute;
      top: 0; left: 0; bottom: 0;
      width: 5px;
      background: linear-gradient(to bottom, #00e5ff, #3b82f6);
      border-radius: 14px 0 0 14px;
    }}

    .step-header {{
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 14px;
      padding-bottom: 12px;
      border-bottom: 1px solid var(--border-subtle);
    }}

    .step-meta {{
      display: flex;
      align-items: center;
      gap: 12px;
    }}

    .step-number {{
      width: 38px;
      height: 38px;
      border-radius: 10px;
      background: rgba(255, 255, 255, 0.06);
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 800;
      font-size: 16px;
      font-family: var(--font-mono);
      color: #fff;
    }}

    .step-card.active-step .step-number {{
      background: var(--primary);
      color: #070a13;
      box-shadow: 0 0 12px var(--primary-glow);
    }}

    .step-identity h2 {{
      font-size: 17px;
      font-weight: 700;
      display: flex;
      align-items: center;
      gap: 8px;
    }}

    .step-id-pill {{
      font-size: 11px;
      font-family: var(--font-mono);
      color: var(--text-muted);
      background: rgba(255, 255, 255, 0.05);
      padding: 2px 6px;
      border-radius: 4px;
    }}

    .step-badge {{
      font-size: 11px;
      font-weight: 700;
      padding: 4px 10px;
      border-radius: 20px;
      letter-spacing: 0.5px;
      text-transform: uppercase;
    }}

    .badge-initial {{ background: rgba(59, 130, 246, 0.15); color: #60a5fa; border: 1px solid rgba(59, 130, 246, 0.4); }}
    .badge-mouvement {{ background: rgba(16, 185, 129, 0.15); color: #34d399; border: 1px solid rgba(16, 185, 129, 0.4); }}
    .badge-pause {{ background: rgba(245, 158, 11, 0.15); color: #fbbf24; border: 1px solid rgba(245, 158, 11, 0.4); }}
    .badge-securite {{ background: rgba(239, 68, 68, 0.15); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.4); }}
    .badge-special {{ background: rgba(168, 85, 247, 0.15); color: #c084fc; border: 1px solid rgba(168, 85, 247, 0.4); }}

    /* Card Main Body Grid */
    .step-grid {{
      display: grid;
      grid-template-columns: 1.1fr 1fr;
      gap: 16px;
      margin-bottom: 16px;
    }}

    .step-block {{
      background: rgba(0, 0, 0, 0.25);
      border: 1px solid var(--border-subtle);
      border-radius: 10px;
      padding: 12px 14px;
    }}

    .block-header {{
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: var(--text-muted);
      margin-bottom: 8px;
      display: flex;
      align-items: center;
      gap: 6px;
    }}

    /* Operator Checklist */
    .checklist {{
      list-style: none;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }}

    .checklist li {{
      font-size: 13px;
      display: flex;
      align-items: flex-start;
      gap: 8px;
      color: #e2e8f0;
    }}

    .checklist-bullet {{
      color: var(--accent);
      font-weight: bold;
    }}

    /* PLC Actions Table */
    .plc-table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 12px;
      font-family: var(--font-mono);
    }}

    .plc-table td {{
      padding: 4px 6px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.04);
    }}

    .plc-var {{
      color: #38bdf8;
      font-weight: 600;
    }}

    .plc-val {{
      color: #e2e8f0;
      text-align: right;
    }}

    /* Transitions & Choices Section */
    .transitions-zone {{
      background: rgba(15, 23, 42, 0.4);
      border: 1px solid var(--border-subtle);
      border-radius: 10px;
      padding: 12px 14px;
    }}

    .transition-chips {{
      display: flex;
      flex-direction: column;
      gap: 8px;
      margin-top: 8px;
    }}

    .transition-chip {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid var(--border-subtle);
      padding: 8px 12px;
      border-radius: 8px;
      cursor: pointer;
      transition: all 0.2s;
    }}

    .transition-chip:hover {{
      background: rgba(255, 255, 255, 0.08);
      border-color: var(--primary);
    }}

    .transition-chip.trans-nominal {{
      border-left: 3px solid var(--success);
    }}

    .transition-chip.trans-abort {{
      border-left: 3px solid var(--danger);
    }}

    .transition-chip.trans-special {{
      border-left: 3px solid var(--purple);
    }}

    .trans-info {{
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 13px;
    }}

    .trans-cond {{
      font-family: var(--font-mono);
      font-size: 11px;
      color: var(--text-muted);
      background: rgba(0, 0, 0, 0.3);
      padding: 2px 6px;
      border-radius: 4px;
    }}

    .trans-btn {{
      font-size: 11px;
      font-weight: 700;
      background: rgba(0, 229, 255, 0.15);
      color: var(--primary);
      border: 1px solid var(--primary);
      padding: 4px 8px;
      border-radius: 5px;
      cursor: pointer;
    }}

    /* Code Accordion */
    .code-accordion {{
      margin-top: 10px;
    }}

    .code-toggle {{
      font-size: 11px;
      color: var(--text-muted);
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      user-select: none;
      padding: 4px 0;
    }}

    .code-toggle:hover {{
      color: var(--primary);
    }}

    .code-content {{
      display: none;
      margin-top: 8px;
      background: #050811;
      border: 1px solid var(--border-subtle);
      border-radius: 8px;
      padding: 10px 14px;
      font-family: var(--font-mono);
      font-size: 12px;
      color: #93c5fd;
      overflow-x: auto;
      white-space: pre;
    }}

    /* Cause Alarms Drawer */
    .fault-matrix {{
      background: rgba(239, 68, 68, 0.05);
      border: 1px solid rgba(239, 68, 68, 0.2);
      border-radius: 12px;
      padding: 16px;
      margin-top: 20px;
    }}

    .fault-title {{
      color: #fca5a5;
      font-weight: 700;
      font-size: 14px;
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 12px;
    }}

    .fault-list {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
      gap: 8px;
    }}

    .fault-item {{
      background: rgba(0, 0, 0, 0.3);
      padding: 8px 10px;
      border-radius: 6px;
      font-size: 12px;
      font-family: var(--font-mono);
      display: flex;
      align-items: center;
      gap: 8px;
      color: #e2e8f0;
    }}

    .fault-code {{
      background: rgba(239, 68, 68, 0.2);
      color: #f87171;
      padding: 2px 6px;
      border-radius: 4px;
      font-weight: bold;
    }}

    /* Footer */
    footer {{
      background: rgba(11, 17, 32, 0.95);
      border-top: 1px solid var(--border-subtle);
      padding: 10px 24px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 12px;
      color: var(--text-muted);
    }}

    /* Micro Animations */
    .flash-highlight {{
      animation: flashBorder 1.2s ease-out;
    }}

    @keyframes flashBorder {{
      0% {{ box-shadow: 0 0 35px var(--primary); border-color: var(--primary); }}
      100% {{ box-shadow: none; }}
    }}
  </style>
</head>
<body>

  <!-- Top Header Bar -->
  <header>
    <div class="brand">
      <div class="brand-logo">🧭</div>
      <div class="brand-text">
        <h1>🧭 GRAFCET EXPLORER & COCKPIT</h1>
        <p>CODESYS 3.5 — Excavatrice de Dragage</p>
      </div>
    </div>

    <!-- Cycle Selector Tabs -->
    <div class="cycle-tabs">
      <button class="cycle-tab active" title="Cycle Homing Actif (Console Sombre)">💻 Console Homing (Sombre)</button>
      <a href="cycle_homing_lumineux.html" class="cycle-tab" style="text-decoration: none;" title="Ouvrir la vue lumineuse et animée du Cycle Homing avec Double Vue & Zoom Capteur">🧭 Homing (Double Vue & Zoom)</a>
      <a href="cycle_auto_lumineux.html" class="cycle-tab" style="text-decoration: none;" title="Ouvrir la vue lumineuse et animée du Cycle Automatique">✨ Cycle Auto Dragage (Lumineux)</a>
    </div>

    <!-- Live Status Pill -->
    <div class="cockpit-status">
      <div class="status-pill">
        <span class="status-dot" id="plc-status-dot"></span>
        <span id="plc-mode-label">MODE: MAINT_N2</span>
      </div>
      <div class="status-pill" style="color: var(--primary);">
        <span>ÉTAPE ACTIVE:</span>
        <strong id="plc-step-indicator">HX0_REPOS</strong>
      </div>
    </div>
  </header>

  <!-- Main Container -->
  <main>
    <!-- Left Sidebar: Simulator & Controls -->
    <aside class="sidebar">
      <!-- Active Step Hero Box -->
      <div class="panel-box">
        <div class="panel-title">
          <span>📍 Étape Actuelle</span>
          <span id="hero-num-badge" style="font-family: var(--font-mono); color: var(--primary);">STEP #0</span>
        </div>
        <div class="current-step-hero">
          <span class="hero-tag" id="hero-tag">INITIAL</span>
          <div class="hero-title" id="hero-title">💤 HX0_REPOS</div>
          <div class="hero-instruction" id="hero-instruction">
            👉 Homing disponible : lancer via 3 appuis joystick ou bouton IHM
          </div>
        </div>
      </div>

      <!-- Simulator Inputs Console -->
      <div class="panel-box">
        <div class="panel-title">
          <span>🕹️ Simulateur d'Entrées Console</span>
          <button class="mode-btn" onclick="resetSimInputs()" style="padding: 2px 6px; font-size: 11px;">RÀZ</button>
        </div>
        <div class="sim-controls">
          <div class="sim-row">
            <span class="sim-label">🛡️ Homme-Mort (Deadman)</span>
            <label class="toggle-switch">
              <input type="checkbox" id="sim-deadman" onchange="evalSimulator()">
              <span class="slider"></span>
            </label>
          </div>

          <div class="sim-row">
            <span class="sim-label">⬆️ Joystick Manche Tiré (Pull)</span>
            <label class="toggle-switch">
              <input type="checkbox" id="sim-joy-pull" onchange="onJoyPullChange()">
              <span class="slider"></span>
            </label>
          </div>

          <div class="sim-row">
            <span class="sim-label">⬇️ Joystick Manche Poussé (Push)</span>
            <label class="toggle-switch">
              <input type="checkbox" id="sim-joy-push" onchange="onJoyPushChange()">
              <span class="slider"></span>
            </label>
          </div>

          <div class="sim-row">
            <span class="sim-label">🛑 Capteur Haut Atteint</span>
            <label class="toggle-switch">
              <input type="checkbox" id="sim-top-sensor" onchange="evalSimulator()">
              <span class="slider"></span>
            </label>
          </div>

          <div class="sim-row">
            <span class="sim-label">⚓ Arrêt Mécanique Confirmé</span>
            <label class="toggle-switch">
              <input type="checkbox" id="sim-winches-stopped" checked onchange="evalSimulator()">
              <span class="slider"></span>
            </label>
          </div>

          <div class="sim-row">
            <span class="sim-label">🗜️ Benne Confirmée Fermée</span>
            <label class="toggle-switch">
              <input type="checkbox" id="sim-bucket-closed" onchange="evalSimulator()">
              <span class="slider"></span>
            </label>
          </div>

          <!-- Pulsed Buttons -->
          <button class="btn-action btn-pulse" onclick="pulseValidation()">
            <span>✨ Motif 3 Appuis Joystick (Validation)</span>
          </button>

          <button class="btn-action btn-pulse" onclick="pulseStartRequest()">
            <span>🚀 Commande IHM Lancer Cycle (Start)</span>
          </button>

          <button class="btn-action btn-danger" onclick="pulseReset()">
            <span>🔄 Front RESET (Acquittement / RÀZ)</span>
          </button>
        </div>
      </div>

      <!-- Quick Step Jumper -->
      <div class="panel-box">
        <div class="panel-title">
          <span>⚡ Forçage de Step (Mise en Service)</span>
        </div>
        <select class="jump-select" id="jump-select" onchange="jumpToStep(this.value)">
          <!-- Generated options -->
        </select>
      </div>

      <!-- Document Reference Info -->
      <div class="panel-box" style="margin-top: auto;">
        <div style="font-size: 11px; color: var(--text-muted); display: flex; flex-direction: column; gap: 4px;">
          <span>📄 <strong>Doc Source :</strong> {doc_ref}</span>
          <span>⚙️ <strong>POU Réel :</strong> FB_CycleMachineHoming.st</span>
          <span>🔒 <strong>Mode Requis :</strong> MAINT_N2 Exclusif</span>
        </div>
      </div>
    </aside>

    <!-- Main Content Area: Step Cards Pipeline -->
    <section class="content-area">
      <!-- Search & Filter Controls -->
      <div class="filter-bar">
        <input type="text" class="search-input" id="search-input" placeholder="🔍 Rechercher une étape, consigne, variable..." onkeyup="filterSteps()">
        <div class="view-modes">
          <button class="mode-btn active" id="btn-view-all" onclick="setViewMode('all')">📑 Vue Cartes Déroulantes</button>
          <button class="mode-btn" id="btn-view-focus" onclick="setViewMode('focus')">🎯 Focus Étape Active</button>
        </div>
      </div>

      <!-- Dynamic Step Cards List -->
      <div class="steps-pipeline" id="steps-container">
        <!-- Rendered by JS -->
      </div>

      <!-- Diagnostic Causes Section -->
      <div class="fault-matrix">
        <div class="fault-title">
          <span>🛡️ Surveillance Transverse & Table des Causes de Défaut (instCauses[])</span>
        </div>
        <div class="fault-list" id="fault-list">
          <!-- Rendered by JS -->
        </div>
      </div>
    </section>
  </main>

  <!-- Footer Info -->
  <footer>
    <div>Machine de Dragage — Outil de visualisation de séquenceur autonome | Zéro dépendance internet</div>
    <div style="font-family: var(--font-mono); color: var(--primary);">Antigravity AGY01 • Mars 2026</div>
  </footer>

  <!-- Embedded JSON Data & Interactive Engine -->
  <script>
    const CYCLE_DATA = {json_data_escaped};

    // State of the simulator
    let currentStepId = "HX0_REPOS";
    let viewMode = "all"; // 'all' or 'focus'
    let filterQuery = "";

    // Simulated internal flags
    let simState = {{
      deadman: false,
      joyPull: false,
      joyPush: false,
      topSensor: false,
      winchesStopped: true,
      bucketClosed: false,
      m1Homed: false,
      m2Homed: false,
      commitDone: false,
      seenNeutral: true,
      failed: false
    }};

    // DOM References
    const stepsContainer = document.getElementById("steps-container");
    const jumpSelect = document.getElementById("jump-select");
    const faultList = document.getElementById("fault-list");

    // Init function
    function init() {{
      buildJumpSelect();
      buildFaultList();
      renderSteps();
      updateHero();
    }}

    // Populate Jump Select Dropdown
    function buildJumpSelect() {{
      jumpSelect.innerHTML = "";
      CYCLE_DATA.steps.forEach(step => {{
        const opt = document.createElement("option");
        opt.value = step.id;
        opt.textContent = `${{step.emoji}} ${{step.id}} — ${{step.titre}}`;
        jumpSelect.appendChild(opt);
      }});
    }}

    // Populate Fault Matrix
    function buildFaultList() {{
      faultList.innerHTML = "";
      CYCLE_DATA.causes_defauts.forEach(cause => {{
        const div = document.createElement("div");
        div.className = "fault-item";
        div.innerHTML = `
          <span class="fault-code">CST #${{cause.code}}</span>
          <span>${{cause.texte}}</span>
        `;
        faultList.appendChild(div);
      }});
    }}

    // Render Steps Cards
    function renderSteps() {{
      stepsContainer.innerHTML = "";
      const q = filterQuery.toLowerCase();

      CYCLE_DATA.steps.forEach(step => {{
        // Filter logic
        const matchesFilter = !q || 
          step.id.toLowerCase().includes(q) || 
          step.titre.toLowerCase().includes(q) || 
          step.consigne_ihm.toLowerCase().includes(q) ||
          JSON.stringify(step.actions_automates).toLowerCase().includes(q);

        if (!matchesFilter) return;

        if (viewMode === "focus" && step.id !== currentStepId) return;

        const isCurrent = step.id === currentStepId;

        const card = document.createElement("div");
        card.className = `step-card ${{isCurrent ? 'active-step' : ''}}`;
        card.id = `card-${{step.id}}`;

        // Badge class
        let badgeClass = "badge-initial";
        if (step.badge.includes("MOUVEMENT")) badgeClass = "badge-mouvement";
        else if (step.badge.includes("PAUSE") || step.badge.includes("NEUTRE")) badgeClass = "badge-pause";
        else if (step.badge.includes("SECURITE") || step.badge.includes("REPLI")) badgeClass = "badge-securite";
        else if (step.badge.includes("SPECIAL") || step.badge.includes("VERROU")) badgeClass = "badge-special";

        // Checklist HTML
        const checklistHtml = step.que_faire_operateur.map(item => `
          <li><span class="checklist-bullet">👉</span><span>${{item}}</span></li>
        `).join("");

        // PLC Actions HTML
        const plcHtml = step.actions_automates.map(act => `
          <tr>
            <td class="plc-var">${{act.var}}</td>
            <td class="plc-val">${{act.val}}</td>
          </tr>
        `).join("");

        // Transitions HTML
        const transitionsHtml = step.transitions.map(t => {{
          let tClass = "trans-nominal";
          if (t.type === "abort") tClass = "trans-abort";
          else if (t.type === "special") tClass = "trans-special";

          return `
            <div class="transition-chip ${{tClass}}" onclick="jumpToStep('${{t.cible}}')">
              <div class="trans-info">
                <span>${{t.emoji}}</span>
                <div>
                  <strong>${{t.nom}}</strong>
                  <div style="font-size: 11px; color: var(--text-muted);">${{t.explication}}</div>
                </div>
              </div>
              <div style="text-align: right;">
                <div class="trans-cond">${{t.condition}}</div>
                <button class="trans-btn" onclick="event.stopPropagation(); jumpToStep('${{t.cible}}')">Aller à ${{t.cible}} ➔</button>
              </div>
            </div>
          `;
        }}).join("");

        card.innerHTML = `
          <div class="step-header">
            <div class="step-meta">
              <div class="step-number">${{step.num}}</div>
              <div class="step-identity">
                <h2>${{step.emoji}} ${{step.titre}} <span class="step-id-pill">${{step.id}}</span></h2>
                <div style="font-size: 12px; color: #fcd34d; margin-top: 4px;">
                  💬 <em>"${{step.consigne_ihm}}"</em>
                </div>
              </div>
            </div>
            <span class="step-badge ${{badgeClass}}">${{step.badge}}</span>
          </div>

          <div class="step-grid">
            <!-- Left: Operator Checklist -->
            <div class="step-block">
              <div class="block-header">🕹️ Que doit faire l'opérateur ?</div>
              <ul class="checklist">
                ${{checklistHtml}}
              </ul>
            </div>

            <!-- Right: PLC Actions -->
            <div class="step-block">
              <div class="block-header">⚙️ Actions Automates (Sorties PLC)</div>
              <table class="plc-table">
                <tbody>
                  ${{plcHtml}}
                </tbody>
              </table>
            </div>
          </div>

          <!-- Bottom: Transitions -->
          <div class="transitions-zone">
            <div class="block-header">🔀 Choix & Transitions Possibles (${{step.transitions.length}})</div>
            <div class="transition-chips">
              ${{transitionsHtml}}
            </div>
          </div>

          <!-- Collapsible ST Code Snippet -->
          <div class="code-accordion">
            <div class="code-toggle" onclick="toggleCode('${{step.id}}')">
              <span>▶</span> <span>Voir le code Structured Text (ST) correspondant</span>
            </div>
            <div class="code-content" id="code-${{step.id}}">${{step.st_code_snippet}}</div>
          </div>
        `;

        stepsContainer.appendChild(card);
      }});
    }}

    // Toggle Code Drawer
    function toggleCode(stepId) {{
      const el = document.getElementById(`code-${{stepId}}`);
      if (el) {{
        el.style.display = el.style.display === "block" ? "none" : "block";
      }}
    }}

    // Jump to Step (Interactive Simulation)
    function jumpToStep(targetStepId) {{
      currentStepId = targetStepId;
      jumpSelect.value = targetStepId;
      updateHero();
      renderSteps();

      // Scroll into view
      const targetCard = document.getElementById(`card-${{targetStepId}}`);
      if (targetCard) {{
        targetCard.scrollIntoView({{ behavior: "smooth", block: "center" }});
        targetCard.classList.add("flash-highlight");
        setTimeout(() => targetCard.classList.remove("flash-highlight"), 1200);
      }}
    }}

    // Update Hero Sidebar
    function updateHero() {{
      const step = CYCLE_DATA.steps.find(s => s.id === currentStepId);
      if (!step) return;

      document.getElementById("plc-step-indicator").textContent = step.id;
      document.getElementById("hero-num-badge").textContent = `STEP #${{step.num}}`;
      document.getElementById("hero-tag").textContent = step.badge;
      document.getElementById("hero-title").textContent = `${{step.emoji}} ${{step.id}}`;
      document.getElementById("hero-instruction").textContent = `👉 ${{step.consigne_ihm}}`;

      const dot = document.getElementById("plc-status-dot");
      if (step.id === "HXF_FAILED") {{
        dot.className = "status-dot danger";
      }} else {{
        dot.className = "status-dot";
      }}
    }}

    // Change View Mode
    function setViewMode(mode) {{
      viewMode = mode;
      document.getElementById("btn-view-all").classList.toggle("active", mode === "all");
      document.getElementById("btn-view-focus").classList.toggle("active", mode === "focus");
      renderSteps();
    }}

    // Search filter
    function filterSteps() {{
      filterQuery = document.getElementById("search-input").value;
      renderSteps();
    }}

    // Simulator Joystick logic
    function onJoyPullChange() {{
      const pull = document.getElementById("sim-joy-pull").checked;
      if (pull) document.getElementById("sim-joy-push").checked = false;
      evalSimulator();
    }}

    function onJoyPushChange() {{
      const push = document.getElementById("sim-joy-push").checked;
      if (push) document.getElementById("sim-joy-pull").checked = false;
      evalSimulator();
    }}

    function resetSimInputs() {{
      document.getElementById("sim-deadman").checked = false;
      document.getElementById("sim-joy-pull").checked = false;
      document.getElementById("sim-joy-push").checked = false;
      document.getElementById("sim-top-sensor").checked = false;
      document.getElementById("sim-winches-stopped").checked = true;
      document.getElementById("sim-bucket-closed").checked = false;
      evalSimulator();
    }}

    // Simulator Interactive Evaluation & Auto-Advance
    function evalSimulator() {{
      const deadman = document.getElementById("sim-deadman").checked;
      const joyPull = document.getElementById("sim-joy-pull").checked;
      const joyPush = document.getElementById("sim-joy-push").checked;
      const topSensor = document.getElementById("sim-top-sensor").checked;
      const winchesStopped = document.getElementById("sim-winches-stopped").checked;
      const bucketClosed = document.getElementById("sim-bucket-closed").checked;

      // Logic simulation based on FB_CycleMachineHoming
      if (currentStepId === "HX2_CLIMB" && topSensor) {{
        // Top sensor reached!
        jumpToStep("HX2N_NEUTRAL");
      }} else if (currentStepId === "HX2N_NEUTRAL" && !joyPull && !joyPush && winchesStopped && joyPush && deadman && topSensor) {{
        jumpToStep("HX3_HOME_AXES");
      }} else if (currentStepId === "HX3_HOME_AXES" && !topSensor) {{
        // Dropped below top sensor -> Homing at the fly!
        jumpToStep("HX3N_PAUSE");
      }} else if (currentStepId === "HX3N_PAUSE" && !joyPull && !joyPush && winchesStopped) {{
        jumpToStep("HX4_BUCKET_ADJUST");
      }} else if (currentStepId === "HX7_LOCKED_REFERENCE" && topSensor && winchesStopped && !joyPull && !joyPush) {{
        jumpToStep("HX6_HOMED");
      }}
    }}

    // Button Pulse Actions
    function pulseValidation() {{
      const topSensor = document.getElementById("sim-top-sensor").checked;
      const bucketClosed = document.getElementById("sim-bucket-closed").checked;

      if (currentStepId === "HX0_REPOS") {{
        jumpToStep("HX1_CHOICE");
      }} else if (currentStepId === "HX1_CHOICE") {{
        if (bucketClosed && !topSensor) {{
          jumpToStep("HX7_LOCKED_REFERENCE");
        }} else if (!topSensor) {{
          jumpToStep("HX2_CLIMB");
        }} else {{
          jumpToStep("HX2N_NEUTRAL");
        }}
      }} else if (currentStepId === "HX4_BUCKET_ADJUST") {{
        jumpToStep("HX5_BUCKET_COMMIT");
        setTimeout(() => {{
          jumpToStep("HX6_HOMED");
          setTimeout(() => jumpToStep("HX0_REPOS"), 1500);
        }}, 800);
      }}
    }}

    function pulseStartRequest() {{
      if (currentStepId === "HX0_REPOS") {{
        jumpToStep("HX1_CHOICE");
      }}
    }}

    function pulseReset() {{
      jumpToStep("HX0_REPOS");
      resetSimInputs();
    }}

    // Boot
    window.addEventListener("DOMContentLoaded", init);
  </script>
</body>
</html>
"""


def generate_graphset(cycle_file="data_homing.json", output_file="index.html"):
    file_path = os.path.join(SCRIPT_DIR, cycle_file)
    if not os.path.exists(file_path):
        print(f"❌ Erreur : Fichier source introuvable : {file_path}")
        return False

    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    json_str = json.dumps(data, ensure_ascii=False)

    html_content = HTML_TEMPLATE.format(
        cycle_name=data.get("name", "Cycle Machine"),
        doc_ref=data.get("doc_ref", "DOC/AF/"),
        json_data_escaped=json_str
    )

    out_path = os.path.join(SCRIPT_DIR, output_file)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html_content)

    print(f"============================================================")
    print(f"✅ GRAFCET INTERACTIF GÉNÉRÉ AVEC SUCCÈS")
    print(f"============================================================")
    print(f"📄 Fichier HTML produit : {out_path}")
    print(f"📊 Nombre d'étapes : {len(data.get('steps', []))}")
    print(f"🎯 Cycle : {data.get('name')}")
    print(f"============================================================")
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Générateur de Graphset / Séquenceur interactif")
    parser.add_argument("--cycle", default="data_homing.json", help="Fichier JSON du cycle à compiler")
    parser.add_argument("--output", default="index.html", help="Nom du fichier HTML généré")
    args = parser.parse_args()

    success = generate_graphset(args.cycle, args.output)
    sys.exit(0 if success else 1)
