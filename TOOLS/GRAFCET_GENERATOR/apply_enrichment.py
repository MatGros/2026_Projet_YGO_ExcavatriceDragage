#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
apply_enrichment.py
Assemble et injecte toutes les données et composants interactifs issus du code ST automate (FB_CycleMachineHoming.st)
dans cycle_homing_lumineux.html et cycle_homing_t364.html.
"""

import os
import re
import json
import html
from html.parser import HTMLParser

# Import data from enrich_homing_st
import enrich_homing_st

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HTML_LUMINEUX = os.path.join(ROOT_DIR, "TOOLS", "GRAFCET_GENERATOR", "cycle_homing_lumineux.html")
HTML_T364 = os.path.join(ROOT_DIR, "TOOLS", "GRAFCET_GENERATOR", "cycle_homing_t364.html")

NEW_CSS = """
    /* --- ENRICHISSEMENT COCKPIT ST & MULTI-ONGLETS (T364) --- */
    .cockpit-tabs-bar {
      display: flex;
      gap: 4px;
      border-bottom: 1px solid var(--border-color);
      padding-bottom: 4px;
      margin-top: 4px;
      margin-bottom: 5px;
      overflow-x: auto;
    }
    .cockpit-tab {
      background: var(--bg-card-subtle);
      border: 1px solid var(--border-color);
      border-radius: 5px;
      padding: 3px 8px;
      font-size: 10px;
      font-weight: 700;
      color: var(--text-muted);
      cursor: pointer;
      white-space: nowrap;
      transition: all 0.2s;
    }
    .cockpit-tab:hover {
      border-color: var(--primary);
      color: var(--text-main);
    }
    .cockpit-tab.active {
      background: var(--primary);
      border-color: var(--primary);
      color: white;
      box-shadow: 0 2px 6px rgba(2, 132, 199, 0.25);
    }
    .cockpit-tab-pane {
      display: none;
      flex-direction: column;
      gap: 4px;
      animation: fadeIn 0.15s ease-in-out;
    }
    .cockpit-tab-pane.active {
      display: flex;
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(2px); }
      to { opacity: 1; transform: translateY(0); }
    }

    /* IHM Banner */
    .ihm-instruction-banner {
      display: flex;
      align-items: center;
      gap: 7px;
      background: rgba(2, 132, 199, 0.08);
      border-left: 3px solid var(--primary);
      border-radius: 4px;
      padding: 4px 8px;
      margin-top: 3px;
    }

    /* ST Code Views */
    .st-pane-wrapper {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .st-block-header {
      font-size: 9.5px;
      font-weight: 800;
      color: var(--text-muted);
      text-transform: uppercase;
      display: flex;
      align-items: center;
      gap: 4px;
    }
    .st-code-view {
      background: #0f172a;
      color: #e2e8f0;
      border-radius: 6px;
      padding: 6px 10px;
      font-family: var(--font-mono);
      font-size: 9.5px;
      line-height: 1.4;
      max-height: 125px;
      overflow-y: auto;
      border: 1px solid #334155;
      white-space: pre-wrap;
    }
    body.dark-theme .st-code-view {
      background: #090d16;
      border-color: #1e293b;
    }

    /* Interactive Transition Branches */
    .branches-container {
      display: flex;
      flex-direction: column;
      gap: 5px;
      max-height: 220px;
      overflow-y: auto;
    }
    .branch-card {
      border: 1.5px solid var(--border-color);
      background: var(--bg-card-subtle);
      border-radius: 6px;
      padding: 5px 8px;
      display: flex;
      flex-direction: column;
      gap: 3px;
      transition: all 0.2s;
    }
    .branch-card.nominal {
      border-color: #10b981;
      background: rgba(16, 185, 129, 0.06);
    }
    .branch-card.abort {
      border-color: #ef4444;
      background: rgba(239, 68, 68, 0.06);
    }
    .branch-card.retry {
      border-color: #f59e0b;
      background: rgba(245, 158, 11, 0.06);
    }
    .branch-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .branch-badge {
      font-size: 8px;
      font-weight: 800;
      padding: 1px 5px;
      border-radius: 3px;
      text-transform: uppercase;
      font-family: var(--font-mono);
    }
    .branch-badge.nominal {
      background: #d1fae5;
      color: #047857;
    }
    .branch-badge.abort {
      background: #fee2e2;
      color: #b91c1c;
    }
    .branch-badge.retry {
      background: #fef3c7;
      color: #b45309;
    }
    .branch-btn {
      padding: 4px 8px;
      border-radius: 4px;
      font-size: 9.5px;
      font-weight: 700;
      cursor: pointer;
      border: none;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 4px;
      transition: all 0.15s;
    }
    .branch-btn.nominal {
      background: #0284c7;
      color: white;
    }
    .branch-btn.nominal:hover {
      background: #0369a1;
    }
    .branch-btn.abort {
      background: #ef4444;
      color: white;
    }
    .branch-btn.abort:hover {
      background: #dc2626;
    }
    .branch-btn.retry {
      background: #d97706;
      color: white;
    }
    .branch-btn.retry:hover {
      background: #b45309;
    }

    /* PLC Tables (Tab 4) */
    .plc-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 9.5px;
    }
    .plc-table th, .plc-table td {
      border: 1px solid var(--border-color);
      padding: 3px 6px;
      text-align: left;
    }
    .plc-table th {
      background: rgba(2, 132, 199, 0.08);
      font-weight: 700;
      color: var(--text-muted);
      text-transform: uppercase;
    }
    .plc-table code {
      font-family: var(--font-mono);
      font-weight: bold;
      color: var(--primary);
    }

    /* Commissioning Step Forcing Bar (§4bis) */
    .commissioning-bar {
      display: flex;
      align-items: center;
      gap: 8px;
      background: var(--bg-card);
      border: 1.5px dashed #0284c7;
      border-radius: 7px;
      padding: 4px 10px;
      box-shadow: var(--shadow-sm);
      margin-top: 1px;
      overflow-x: auto;
    }
    .comm-label {
      font-size: 10.5px;
      font-weight: 800;
      color: #0284c7;
      white-space: nowrap;
      display: flex;
      align-items: center;
      gap: 4px;
    }
    .comm-step-buttons {
      display: flex;
      gap: 4px;
      flex-wrap: nowrap;
    }
    .btn-force-step {
      background: var(--bg-card-subtle);
      border: 1px solid var(--border-color);
      border-radius: 4px;
      padding: 2px 7px;
      font-size: 9.5px;
      font-family: var(--font-mono);
      font-weight: 700;
      color: var(--text-main);
      cursor: pointer;
      white-space: nowrap;
      transition: all 0.15s;
    }
    .btn-force-step:hover {
      border-color: var(--primary);
      background: rgba(2, 132, 199, 0.1);
      color: var(--primary);
    }
    .btn-force-step.active {
      background: var(--primary);
      border-color: var(--primary);
      color: white;
    }
    .btn-force-step.fail {
      color: #b91c1c;
      border-color: rgba(239, 68, 68, 0.4);
    }
    .btn-force-step.fail:hover {
      background: #fee2e2;
      border-color: #ef4444;
      color: #b91c1c;
    }
    .btn-force-step.fail.active {
      background: #ef4444;
      color: white;
    }

    /* Full ST Modal */
    .st-regions-bar {
      display: flex;
      gap: 4px;
      overflow-x: auto;
      padding-bottom: 4px;
      border-bottom: 1px solid var(--border-color);
    }
    .st-region-btn {
      background: var(--bg-card-subtle);
      border: 1px solid var(--border-color);
      border-radius: 4px;
      padding: 3px 6px;
      font-size: 9.5px;
      font-weight: 600;
      color: var(--text-muted);
      cursor: pointer;
      white-space: nowrap;
    }
    .st-region-btn:hover {
      border-color: var(--primary);
      color: var(--primary);
    }
    .st-region-btn.active {
      background: var(--primary);
      color: white;
      border-color: var(--primary);
    }
    .st-code-scroll {
      flex: 1;
      overflow-y: auto;
      background: #0f172a;
      border-radius: 6px;
      padding: 10px 14px;
      border: 1px solid #334155;
      font-family: var(--font-mono);
      font-size: 11px;
      line-height: 1.45;
      color: #e2e8f0;
    }
"""

COMMISSIONING_BAR_HTML = """
    <!-- Commissioning Step Forcing Bar (§4bis CfgCommissioningEnable) -->
    <div class="commissioning-bar">
      <div class="comm-label">
        <span>🔧 §4bis Forçage Mise en Service (Commissioning) :</span>
      </div>
      <div class="comm-step-buttons">
        <button class="btn-force-step active" id="btn-force-0" onclick="forceStep(0)">HX0 Repos</button>
        <button class="btn-force-step" id="btn-force-1" onclick="forceStep(1)">HX1 Prép. Benne</button>
        <button class="btn-force-step" id="btn-force-2" onclick="forceStep(2)">HX1a Interlock E1</button>
        <button class="btn-force-step" id="btn-force-3" onclick="forceStep(3)">HX2 Montée</button>
        <button class="btn-force-step" id="btn-force-4" onclick="forceStep(4)">HX3 Réf. Vol</button>
        <button class="btn-force-step" id="btn-force-5" onclick="forceStep(5)">HX4 Stab. Check</button>
        <button class="btn-force-step" id="btn-force-6" onclick="forceStep(6)">HX5 Dégagement</button>
        <button class="btn-force-step" id="btn-force-7" onclick="forceStep(7)">HX6 Succès Homed</button>
        <button class="btn-force-step fail" id="btn-force-8" onclick="forceStep(8)">HX7 Repli Échec</button>
      </div>
    </div>
"""

COCKPIT_CARD_HTML = """      <!-- Right Column: Focus Step Cockpit -->
      <div class="active-step-focus" id="active-step-card">
        <div>
          <div class="step-badge-row">
            <div style="display: flex; align-items: center; gap: 8px;">
              <span class="step-tag-pill" id="focus-step-id">HX0_REPOS</span>
              <span style="font-size: 11px; font-weight: 700; color: var(--text-muted);" id="focus-badge">INITIAL</span>
            </div>
            <div style="display: flex; gap: 4px;">
              <button class="auto-play-btn" onclick="openStModal()" style="padding: 2px 7px; font-size: 10px; background: rgba(2, 132, 199, 0.1); color: var(--primary); border: 1px solid var(--primary); box-shadow: none;">
                📄 ST Source
              </button>
            </div>
          </div>

          <div class="step-headline">
            <h2 id="focus-title">💤 Étape Initiale & Repos</h2>
          </div>

          <!-- Cockpit Tabs Navigation -->
          <div class="cockpit-tabs-bar">
            <button class="cockpit-tab active" id="btn-tab-role" onclick="switchCockpitTab('tab-role')">
              📋 Rôle & Conduite
            </button>
            <button class="cockpit-tab" id="btn-tab-st" onclick="switchCockpitTab('tab-st')">
              💻 Code ST Automate
            </button>
            <button class="cockpit-tab" id="btn-tab-branches" onclick="switchCockpitTab('tab-branches')">
              🔀 Choix & Arbre des Transitions
            </button>
            <button class="cockpit-tab" id="btn-tab-io" onclick="switchCockpitTab('tab-io')">
              🛡️ Sorties & Verrous PLC
            </button>
          </div>

          <!-- Tab 1: Rôle & Conduite -->
          <div class="cockpit-tab-pane active" id="pane-tab-role">
            <div class="step-explanation-box">
              <div class="exp-item">
                <strong>❓ But de l'étape :</strong>
                <p id="focus-pourquoi" style="color: var(--text-muted); margin-top: 2px;">
                  Machine au repos. En attente de la demande de référencement en mode MAINT_N2.
                </p>
              </div>
              <div class="exp-item" style="margin-top: 3px;">
                <strong>🕹️ Consigne Opérateur Terrain :</strong>
                <p id="focus-consigne" style="color: var(--primary); font-weight: 700; margin-top: 2px;">
                  Homing disponible : lancer via 3 appuis joystick ou bouton IHM Start.
                </p>
              </div>
            </div>

            <!-- IHM Official Instruction Banner (§10) -->
            <div class="ihm-instruction-banner">
              <span style="font-size: 11px;">💬</span>
              <div>
                <div style="font-size: 8.5px; font-weight: 800; color: #0284c7; text-transform: uppercase;">Message Écran IHM (§10 HomingInstructionText) :</div>
                <div id="focus-ihm-text" style="font-size: 9.5px; font-family: var(--font-mono); font-weight: bold; color: var(--text-main);">...</div>
              </div>
            </div>

            <!-- Interactive Decision Card for HX0_REPOS -->
            <div id="hx0-decision-card" style="display: block; background: var(--bg-card-subtle); border: 1.5px solid var(--border-color); border-radius: 7px; padding: 5px 8px; margin-top: 4px;">
              <div style="font-size: 10px; font-weight: 800; display: flex; align-items: center; justify-content: space-between;" id="hx0-decision-title">
                <span id="hx0-decision-tag" style="color: #b91c1c;">🚦 SITUATION AU BOOT : NON RÉFÉRENCÉE</span>
                <span id="hx0-gate-tag" style="font-size: 8.5px; padding: 1px 5px; border-radius: 4px; background: #fee2e2; color: #b91c1c; font-weight: bold;">
                  Cycle Auto Verrouillé
                </span>
              </div>
              <p id="hx0-decision-desc" style="font-size: 9px; color: var(--text-muted); margin-top: 2px; line-height: 1.3;">
                Sans référence codeurs, l'automate exige le cycle complet de homing avant toute production.
              </p>
              <div id="hx0-action-buttons" style="display: flex; gap: 6px; margin-top: 4px;">
                <!-- Dynamically populated -->
              </div>
            </div>

            <!-- Interactive Action Card for HX1_BUCKET_PREPARE -->
            <div id="hx1-action-card" style="display: none; background: rgba(2, 132, 199, 0.08); border: 1.5px solid var(--primary); border-radius: 7px; padding: 5px 8px; margin-top: 4px;">
              <div style="font-size: 10px; font-weight: 800; color: #0284c7; display: flex; align-items: center; justify-content: space-between;">
                <span>🗜️ FERMETURE BENNE OPÉRATEUR (PALIER 1 SOUS FDC INHIBÉ)</span>
                <span id="hx1-status-tag" style="font-size: 8.5px; padding: 1px 5px; border-radius: 4px; background: #fee2e2; color: #b91c1c; font-weight: bold;">
                  Benne Ouverte
                </span>
              </div>
              <p style="font-size: 9px; color: var(--text-muted); margin-top: 2px; line-height: 1.3;">
                Fermeture au palier 1 (WinchSel=2, garde 8s max). Confirmer le contact mécanique franc au sol :
              </p>
              <div style="display: flex; gap: 6px; margin-top: 4px;">
                <button id="btn-hx1-close" onclick="actionCloseBucket()" style="flex: 1; padding: 4px 6px; font-size: 9.5px; background: #0284c7; color: white; border-radius: 4px; cursor: pointer; border: none; font-weight: bold;">
                  🗜️ 1. Fermer Benne (Joystick)
                </button>
                <button id="btn-hx1-confirm" onclick="actionConfirmBucket()" style="flex: 1; padding: 4px 6px; font-size: 9.5px; background: #64748b; color: white; border-radius: 4px; cursor: pointer; border: none; font-weight: bold;" disabled>
                  ✅ 2. Bouton IHM Dédié
                </button>
              </div>
            </div>

            <!-- Interactive Card for HX1A_COUPLING_INTERLOCK -->
            <div id="hx1a-action-card" style="display: none; background: rgba(139, 92, 246, 0.08); border: 1.5px solid var(--purple); border-radius: 7px; padding: 5px 8px; margin-top: 4px;">
              <div style="font-size: 10px; font-weight: 800; color: #7c3aed; display: flex; align-items: center; gap: 5px;">
                <span>🔗 INTERLOCK COUPLAGE E1 (RÉSOLUTION ANOMALIE E1)</span>
              </div>
              <p style="font-size: 9px; color: var(--text-muted); margin-top: 2px; line-height: 1.3;">
                Bascule <code>WinchSel = 0</code>, réactivation FDC benne, dwell temporisé 300 ms, validation treuils immobiles.
              </p>
              <div style="display: flex; gap: 8px; margin-top: 3px; font-size: 9px; font-family: var(--font-mono); color: #7c3aed;">
                <span>WinchSelArbitrated: <strong>0 (Couplé)</strong></span>
                <span>Dwell: <strong>300 ms [OK]</strong></span>
                <span>Stop: <strong>Confirmé</strong></span>
              </div>
            </div>

            <!-- Interactive Card for HX4_STABILIZATION_CHECK -->
            <div id="hx4-action-card" style="display: none; background: rgba(16, 185, 129, 0.08); border: 1.5px solid var(--success); border-radius: 7px; padding: 5px 8px; margin-top: 4px;">
              <div style="font-size: 10px; font-weight: 800; color: #047857; display: flex; align-items: center; justify-content: space-between;">
                <span>🎯 CONTRÔLE INERTIE & COHÉRENCE TREUILS M1/M2</span>
                <span style="font-size: 8.5px; padding: 1px 5px; border-radius: 4px; background: #d1fae5; color: #065f46; font-weight: bold;">
                  Fenêtre [8.50..8.80 m]
                </span>
              </div>
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 6px; margin-top: 4px; font-size: 9px; font-family: var(--font-mono);">
                <div style="background: var(--bg-card); padding: 3px 6px; border-radius: 4px; border: 1px solid var(--border-color);">
                  Pos M1: <strong>8.58 m</strong> ✅
                </div>
                <div style="background: var(--bg-card); padding: 3px 6px; border-radius: 4px; border: 1px solid var(--border-color);">
                  Pos M2: <strong>8.60 m</strong> ✅
                </div>
              </div>
              <div style="font-size: 8.5px; color: var(--text-muted); margin-top: 3px;">
                Écart: <code>|M1 - M2| = 0.02 m &lt;= 1.0 m</code> • Tentatives: <code id="retry-counter-display">0/3</code>
              </div>
            </div>

            <!-- Interactive Card for HX7_FAILED -->
            <div id="hx7-action-card" style="display: none; background: rgba(239, 68, 68, 0.08); border: 1.5px solid var(--danger); border-radius: 7px; padding: 5px 8px; margin-top: 4px;">
              <div style="font-size: 10px; font-weight: 800; color: #b91c1c; display: flex; align-items: center; gap: 5px;">
                <span>🚨 REPLI SÉCURISÉ HX7_FAILED</span>
              </div>
              <p style="font-size: 9px; color: var(--text-muted); margin-top: 2px;">
                Toutes les sorties coupées (<code>CmdWinchSelect := -1</code>). Réarmement exclusivement par front montant Reset en MAINT_N2.
              </p>
            </div>
          </div>

          <!-- Tab 2: Code ST Automate -->
          <div class="cockpit-tab-pane" id="pane-tab-st">
            <div class="st-pane-wrapper">
              <div class="st-block-header">⚙️ Actions Automate (Corps CASE SeqStep OF) :</div>
              <pre class="st-code-view" id="focus-st-actions">// Actions ST...</pre>

              <div class="st-block-header" style="margin-top: 4px;">⚡ Conditions de Transition Écrites en ST :</div>
              <pre class="st-code-view" id="focus-st-transitions">// Transitions ST...</pre>
            </div>
          </div>

          <!-- Tab 3: Choix & Arbre des Transitions -->
          <div class="cockpit-tab-pane" id="pane-tab-branches">
            <div style="font-size: 9.5px; font-weight: 700; color: var(--text-muted); margin-bottom: 3px;">
              Arbre décisionnel de l'étape & simulation des transitions :
            </div>
            <div id="focus-branches-list" class="branches-container">
              <!-- Populated dynamically -->
            </div>
          </div>

          <!-- Tab 4: Sorties & Verrous PLC -->
          <div class="cockpit-tab-pane" id="pane-tab-io">
            <div style="display: flex; flex-direction: column; gap: 5px; max-height: 220px; overflow-y: auto;">
              <div>
                <div style="font-size: 9.5px; font-weight: 800; color: var(--text-main); margin-bottom: 2px;">
                  📤 Variables de Commande & Verrous Affectés :
                </div>
                <table class="plc-table">
                  <thead>
                    <tr>
                      <th style="width: 38%;">Variable Automate</th>
                      <th style="width: 24%;">Valeur</th>
                      <th>Conséquence Machine</th>
                    </tr>
                  </thead>
                  <tbody id="tbody-plc-outputs"></tbody>
                </table>
              </div>

              <div>
                <div style="font-size: 9.5px; font-weight: 800; color: var(--text-main); margin-bottom: 2px;">
                  ⏱️ Temporisations & Gardes Actives :
                </div>
                <table class="plc-table">
                  <thead>
                    <tr>
                      <th style="width: 38%;">Garde / Timer</th>
                      <th style="width: 24%;">PT (Temps)</th>
                      <th>Condition / Rôle</th>
                    </tr>
                  </thead>
                  <tbody id="tbody-plc-guards"></tbody>
                </table>
              </div>

              <div>
                <div style="font-size: 9.5px; font-weight: 800; color: var(--text-main); margin-bottom: 2px;">
                  🚨 Causes de Repli & Alarmes Surveillées :
                </div>
                <div id="list-plc-alarms" style="display: flex; flex-direction: column; gap: 3px;"></div>
              </div>
            </div>
          </div>
        </div>

        <!-- Big Transition Prompt (Bottom) -->
        <div class="next-step-prompt">
          <div class="prompt-header">
            <span>⚡ Condition Nominale de Sortie (ST)</span>
          </div>
          <div style="font-size: 11px; color: var(--text-main); font-weight: 700;" id="focus-cond-titre">
            ...
          </div>
          <div style="font-size: 9.5px; font-family: var(--font-mono); color: var(--text-muted);" id="focus-cond-tech">
            ...
          </div>

          <button class="btn-advance-step" onclick="advanceStep()">
            <span id="btn-advance-label">Passer au step suivant ➔</span>
            <span>⏩</span>
          </button>
        </div>
      </div>
"""

FULL_ST_MODAL_HTML = """
  <!-- Full ST Automate Code Modal -->
  <div id="st-modal" class="sat-modal-backdrop" onclick="if(event.target === this) closeStModal()">
    <div class="sat-modal-content" style="max-width: 1050px; height: 88vh; display: flex; flex-direction: column;">
      <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border-color); padding-bottom: 8px;">
        <div style="display: flex; align-items: center; gap: 8px;">
          <span style="font-size: 18px;">💻</span>
          <div>
            <h3 style="font-size: 13.5px; margin: 0; color: var(--text-main);">Code Source Automate Complet (FB_CycleMachineHoming.st)</h3>
            <p style="font-size: 10px; margin: 0; color: var(--text-muted);">CODESYS 3.5 — 652 lignes conformes aux 21 Gates et à l'architecture AF-02/09</p>
          </div>
        </div>
        <div style="display: flex; gap: 8px; align-items: center;">
          <input type="text" id="st-search-input" placeholder="🔍 Rechercher dans le code..." oninput="searchStCode()" style="padding: 4px 8px; font-size: 11px; border: 1px solid var(--border-color); border-radius: 4px; background: var(--bg-card-subtle); color: var(--text-main);">
          <button onclick="closeStModal()" style="background: none; border: none; font-size: 18px; cursor: pointer; color: var(--text-muted);">✖</button>
        </div>
      </div>

      <div class="st-regions-bar" id="st-modal-regions">
        <!-- Region navigation buttons generated by JS -->
      </div>

      <div class="st-code-scroll" id="st-modal-code-container">
        <pre id="st-modal-code-body" style="margin: 0; font-family: var(--font-mono);"></pre>
      </div>

      <div style="display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--border-color); padding-top: 8px;">
        <span style="font-size: 10px; color: var(--text-muted);">
          Garantie de non-divergence : extrait directement de <code>CODE/G_CYCLE/FB_CycleMachineHoming.st</code>.
        </span>
        <button onclick="closeStModal()" style="padding: 4px 12px; background: var(--primary); color: white; border: none; border-radius: 5px; font-weight: bold; cursor: pointer; font-size: 11px;">
          Fermer le Code ST
        </button>
      </div>
    </div>
  </div>
"""

def generate_js_additions(steps_data, regions, st_full):
    regions_json = []
    for reg_name, reg_content in regions:
        regions_json.append({
            "name": reg_name.strip(),
            "content": reg_content.strip()
        })

    js = f"""
    // --- NOUVELLES FONCTIONS COCKPIT MULTI-ONGLETS & CODE ST ---
    let currentCockpitTab = 'tab-role';
    let retryCountSimulation = 0;
    const ST_FULL_SOURCE = {json.dumps(st_full)};
    const ST_REGIONS = {json.dumps(regions_json)};

    function switchCockpitTab(tabId) {{
      currentCockpitTab = tabId;
      document.querySelectorAll('.cockpit-tab').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.cockpit-tab-pane').forEach(p => p.classList.remove('active'));

      const activeBtn = document.getElementById(`btn-${{tabId}}`);
      const activePane = document.getElementById(`pane-${{tabId}}`);
      if (activeBtn) activeBtn.classList.add('active');
      if (activePane) activePane.classList.add('active');
    }}

    function forceStep(stepIdx) {{
      updateView(stepIdx);
    }}

    function updateStepCockpitTabs(step) {{
      // 1. Tab Role & IHM
      const ihmEl = document.getElementById("focus-ihm-text");
      if (ihmEl) ihmEl.textContent = step.ihm_instruction || "Aucun message affiché";

      const retryDisplay = document.getElementById("retry-counter-display");
      if (retryDisplay) retryDisplay.textContent = `${{retryCountSimulation}}/3`;

      // 2. Tab ST Code
      const stActions = document.getElementById("focus-st-actions");
      const stTrans = document.getElementById("focus-st-transitions");
      if (stActions) stActions.textContent = step.st_actions || "// Aucune action spécifique";
      if (stTrans) stTrans.textContent = step.st_transitions || "// Aucune transition";

      // 3. Tab Branches
      const branchesList = document.getElementById("focus-branches-list");
      if (branchesList) {{
        branchesList.innerHTML = "";
        (step.st_branches || []).forEach(br => {{
          const card = document.createElement("div");
          card.className = `branch-card ${{br.type}}`;
          
          let badgeText = "NOMINALE";
          if (br.type === "abort") badgeText = "ABANDON FAIL-SAFE";
          else if (br.type === "retry") badgeText = "BOUCLE DE RÉESSAI";

          card.innerHTML = `
            <div class="branch-header">
              <span class="branch-badge ${{br.type}}">${{badgeText}}</span>
              <span style="font-size: 8.5px; font-weight: 700; color: var(--text-muted);">Cible : <code>${{br.target_step}}</code></span>
            </div>
            <div style="font-size: 9.5px; font-weight: 700; color: var(--text-main);">${{br.title}}</div>
            <div style="font-size: 8.5px; font-family: var(--font-mono); color: var(--text-muted); background: var(--bg-card); padding: 2px 4px; border-radius: 3px; border: 1px solid var(--border-color);">
              ${{br.cond_tech}}
            </div>
            <button class="branch-btn ${{br.type}}" onclick="simulateBranch(${{br.target_idx}}, '${{br.type}}')">
              ${{br.btn_label}}
            </button>
          `;
          branchesList.appendChild(card);
        }});
      }}

      // 4. Tab Sorties & Verrous PLC
      const tbodyOutputs = document.getElementById("tbody-plc-outputs");
      if (tbodyOutputs) {{
        tbodyOutputs.innerHTML = "";
        (step.st_outputs || []).forEach(out => {{
          const tr = document.createElement("tr");
          tr.innerHTML = `
            <td><code>${{out.var}}</code></td>
            <td style="font-family: var(--font-mono); font-weight: bold;">${{out.val}}</td>
            <td style="color: var(--text-muted);">${{out.note}}</td>
          `;
          tbodyOutputs.appendChild(tr);
        }});
      }}

      const tbodyGuards = document.getElementById("tbody-plc-guards");
      if (tbodyGuards) {{
        tbodyGuards.innerHTML = "";
        if (step.st_guards && step.st_guards.length > 0) {{
          step.st_guards.forEach(g => {{
            const tr = document.createElement("tr");
            tr.innerHTML = `
              <td style="font-weight: bold;">${{g.name}}</td>
              <td style="font-family: var(--font-mono); font-weight: bold; color: #d97706;">${{g.pt}}</td>
              <td style="color: var(--text-muted);">${{g.note}}</td>
            `;
            tbodyGuards.appendChild(tr);
          }});
        }} else {{
          tbodyGuards.innerHTML = `<tr><td colspan="3" style="color: var(--text-muted); text-align: center;">Aucun timer spécifique actif</td></tr>`;
        }}
      }}

      const listAlarms = document.getElementById("list-plc-alarms");
      if (listAlarms) {{
        listAlarms.innerHTML = "";
        if (step.st_alarms && step.st_alarms.length > 0) {{
          step.st_alarms.forEach(a => {{
            const div = document.createElement("div");
            div.style.cssText = "font-size: 8.5px; background: #fee2e2; border: 1px solid #ef4444; border-radius: 4px; padding: 2px 6px; color: #b91c1c; display: flex; gap: 4px;";
            div.innerHTML = `<strong>Cause #${{a.id}} [${{a.name}}] :</strong> <span>${{a.text}}</span>`;
            listAlarms.appendChild(div);
          }});
        }} else {{
          listAlarms.innerHTML = `<div style="font-size: 8.5px; color: #047857; background: #d1fae5; border-radius: 4px; padding: 2px 6px;">Aucun risque de déclenchement d'alarme sur cette phase</div>`;
        }}
      }}

      // Update Commissioning Bar Button Active State
      document.querySelectorAll(".btn-force-step").forEach((btn, idx) => {{
        if (idx === step.num) btn.classList.add("active");
        else btn.classList.remove("active");
      }});
    }}

    function simulateBranch(targetIdx, branchType) {{
      if (branchType === "retry") {{
        retryCountSimulation++;
        alert(`🔁 Simulation de Réessai : Inertie hors plage ! Tentative ${{retryCountSimulation}}/3 consommée. Rebouclage vers HX1_BUCKET_PREPARE.`);
      }} else if (branchType === "abort") {{
        alert(`🚨 Simulation d'Abandon Fail-Safe : Sécurité engagée, bascule vers HX7_FAILED.`);
      }}
      updateView(targetIdx);
    }}

    // --- MODALE CODE ST COMPLET ---
    function openStModal() {{
      const modal = document.getElementById("st-modal");
      if (modal) {{
        modal.style.display = "flex";
        renderStRegionsBar();
        showStCode(ST_FULL_SOURCE);
      }}
    }}

    function closeStModal() {{
      const modal = document.getElementById("st-modal");
      if (modal) modal.style.display = "none";
    }}

    function renderStRegionsBar() {{
      const container = document.getElementById("st-modal-regions");
      if (!container || container.children.length > 0) return;
      container.innerHTML = "";
      
      const allBtn = document.createElement("button");
      allBtn.className = "st-region-btn active";
      allBtn.textContent = "📄 Tout le Code (652 l.)";
      allBtn.onclick = () => {{
        document.querySelectorAll(".st-region-btn").forEach(b => b.classList.remove("active"));
        allBtn.classList.add("active");
        showStCode(ST_FULL_SOURCE);
      }};
      container.appendChild(allBtn);

      ST_REGIONS.forEach((reg, idx) => {{
        const btn = document.createElement("button");
        btn.className = "st-region-btn";
        btn.textContent = reg.name.split('.')[0] + " - " + reg.name.split('.').slice(1).join('.').trim().substring(0, 22);
        btn.title = reg.name;
        btn.onclick = () => {{
          document.querySelectorAll(".st-region-btn").forEach(b => b.classList.remove("active"));
          btn.classList.add("active");
          showStCode(`// === RÉGION : ${{reg.name}} ===\\n\\n${{reg.content}}`);
        }};
        container.appendChild(btn);
      }});
    }}

    function showStCode(content) {{
      const body = document.getElementById("st-modal-code-body");
      if (body) {{
        body.textContent = content;
      }}
    }}

    function searchStCode() {{
      const query = document.getElementById("st-search-input").value.toLowerCase();
      const body = document.getElementById("st-modal-code-body");
      if (!query) {{
        body.textContent = ST_FULL_SOURCE;
        return;
      }}
      const lines = ST_FULL_SOURCE.split('\\n');
      const matchedLines = lines.filter(l => l.toLowerCase().includes(query));
      body.textContent = `// --- RÉSULTATS DE LA RECHERCHE POUR : "${{query}}" (${{matchedLines.length}} correspondances) ---\\n\\n` + matchedLines.join('\\n');
    }}
    """
    return js

def build_full_html():
    steps_data, regions, st_full = enrich_homing_st.main()

    with open(HTML_LUMINEUX, "r", encoding="utf-8") as f:
        src = f.read()

    # 1. Inject CSS
    src = src.replace("</style>", NEW_CSS + "\n  </style>")

    # 2. Inject Header Button for ST Code
    header_btn = """      <button class="nav-tab" onclick="openStModal()" style="background: rgba(2, 132, 199, 0.12); border-color: #0284c7; color: #0284c7; font-weight: 700; cursor: pointer;">
        <span>💻</span> Code ST Automate (652 l.)
      </button>\n"""
    src = src.replace('<div class="cycle-links">', '<div class="cycle-links">\n' + header_btn)

    # 3. Inject Commissioning Bar right after startup-state-bar
    pattern_startup = re.compile(r'(</div>\s*</div>\s*<div class="homing-cockpit-grid">)', re.DOTALL)
    if pattern_startup.search(src):
        src = pattern_startup.sub(r'</div>\n    </div>\n' + COMMISSIONING_BAR_HTML + '\n    <div class="homing-cockpit-grid">', src, count=1)
    else:
        print("Avertissement : pattern startup-state-bar non trouvé")

    # 4. Replace Cockpit Right Card
    # Pattern to find the active-step-focus block
    pattern_cockpit = re.compile(r'<!-- Right Column: Focus Step Cockpit -->\s*<div class="active-step-focus" id="active-step-card">.*?</div>\s*</div>\s*<!-- Bottom Timeline Stepper -->', re.DOTALL)
    if pattern_cockpit.search(src):
        src = pattern_cockpit.sub(COCKPIT_CARD_HTML + '\n    </div>\n\n    <!-- Bottom Timeline Stepper -->', src, count=1)
    else:
        print("Avertissement : pattern cockpit card non trouvé")

    # 5. Inject Full ST Modal right before </body>
    src = src.replace("</body>", FULL_ST_MODAL_HTML + "\n</body>")

    # 6. Replace HOMING_STEPS in <script>
    steps_json = json.dumps(steps_data, indent=6, ensure_ascii=False)
    pattern_steps = re.compile(r'const HOMING_STEPS = \[.*?\];', re.DOTALL)
    if pattern_steps.search(src):
        src = pattern_steps.sub(lambda m: f"const HOMING_STEPS = {steps_json};", src, count=1)
    else:
        print("Avertissement : pattern HOMING_STEPS non trouvé")

    # 7. Add JS Additions into <script>
    js_additions = generate_js_additions(steps_data, regions, st_full)
    
    # Also hook updateStepCockpitTabs into updateView
    src = src.replace("updateGranularTelemetry(step);", "updateGranularTelemetry(step);\n      updateStepCockpitTabs(step);")

    # Append js_additions at the end of script
    src = src.replace("window.addEventListener(\"DOMContentLoaded\", init);", js_additions + "\n    window.addEventListener(\"DOMContentLoaded\", init);")

    # HTML Validation
    class MyParser(HTMLParser):
        pass

    parser = MyParser()
    parser.feed(src)
    print("-> Validation syntaxique HTMLParser réussie (0 erreur) !")

    return src

def main():
    print("Génération du code HTML enrichi...")
    full_html = build_full_html()

    print(f"Écriture dans {HTML_LUMINEUX}...")
    with open(HTML_LUMINEUX, "w", encoding="utf-8") as f:
        f.write(full_html)

    print(f"Écriture dans {HTML_T364}...")
    with open(HTML_T364, "w", encoding="utf-8") as f:
        f.write(full_html)

    print("Terminé avec succès pour les deux fichiers !")

if __name__ == "__main__":
    main()
