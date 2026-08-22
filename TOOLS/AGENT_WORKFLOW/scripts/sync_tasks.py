"""
sync_tasks.py — Synchronisation & Gestionnaire du Catalogue TASKS.yaml

Rôles :
1. Centralise et normalise toutes les tâches dans DOC/WFLOW/TASKS.yaml (compatible Data Preview).
2. Fournit une vue tableur instantanée, filtrable, triable et modifiable.
3. Lie automatiquement les contrats unitaires dans DOC/WFLOW/CONTRACTS/*.yaml.
"""

import os
import re
import sys
import yaml
from pathlib import Path

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

BASE_DIR = Path(__file__).resolve().parent.parent.parent.parent
WFLOW_DIR = BASE_DIR / "DOC" / "WFLOW"
CONTRACTS_DIR = WFLOW_DIR / "CONTRACTS"
TASKS_YAML = WFLOW_DIR / "TASKS.yaml"



def load_tasks_yaml(yaml_path: Path):
    """Charge les tâches depuis TASKS.yaml (source de vérité unique)."""
    if not yaml_path.exists():
        return []
    with open(yaml_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if isinstance(data, dict) and "tasks" in data:
        return data["tasks"]
    elif isinstance(data, list):
        return data
    return []


def save_tasks_yaml(tasks, output_path: Path):
    """Sauvegarde le catalogue normalisé en YAML."""
    header = (
        "# ==============================================================================\n"
        "# 🗂️ TASK VIEWER — CATALOGUE DES TÂCHES\n"
        "# ==============================================================================\n"
        "# Source officielle de données. Pour visualiser : ouvrir DOC/WFLOW/TASK_VIEWER.html\n\n"
    )
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(header)
        yaml.dump(tasks, f, allow_unicode=True, sort_keys=False, default_flow_style=False)


def save_tasks_html(tasks, output_path: Path):
    """Génère un tableau interactif ultra-compact : vue grille par défaut, dépliable au clic pour voir le détail."""
    import json
    tasks_json = json.dumps(tasks, ensure_ascii=False)
    
    html = f"""<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>📋 Task Viewer — Catalogue des Tâches</title>
    <style>
        :root {{
            --bg: #1e1e2e;
            --card-bg: #282a36;
            --row-alt: #21222c;
            --text: #f8f8f2;
            --subtext: #a6adc8;
            --border: #44475a;
            --accent: #bd93f9;
            --green: #50fa7b;
            --orange: #ffb86c;
            --cyan: #8be9fd;
            --red: #ff5555;
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--bg);
            color: var(--text);
            margin: 0;
            padding: 20px;
        }}
        .header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 2px solid var(--border);
            padding-bottom: 12px;
            margin-bottom: 16px;
        }}
        .title {{ font-size: 20px; font-weight: bold; color: var(--accent); }}
        .badge {{ padding: 3px 8px; border-radius: 6px; font-weight: bold; }}
        .badge-done {{ background: rgba(80, 250, 123, 0.2); color: var(--green); }}
        .badge-lock {{ background: rgba(255, 184, 108, 0.2); color: var(--orange); }}
        .badge-wait {{ background: rgba(139, 233, 253, 0.2); color: var(--cyan); }}
        .badge-todo {{ background: rgba(166, 173, 200, 0.2); color: var(--subtext); }}

        @keyframes pulse {{
            0% {{ opacity: 1; transform: scale(1); }}
            50% {{ opacity: 0.4; transform: scale(1.2); }}
            100% {{ opacity: 1; transform: scale(1); }}
        }}
        .badge-open {{ background: rgba(139, 233, 253, 0.2); color: var(--cyan); }}
        
        .controls {{
            display: flex;
            gap: 10px;
            margin-bottom: 16px;
            flex-wrap: wrap;
            align-items: center;
        }}
        .search-box {{
            flex: 1;
            min-width: 250px;
            padding: 8px 12px;
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 6px;
            color: #fff;
            font-size: 14px;
            outline: none;
        }}
        .search-box:focus {{ border-color: var(--accent); }}
        .sort-box {{
            padding: 8px 12px;
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 6px;
            color: #fff;
            font-size: 13px;
            outline: none;
            cursor: pointer;
        }}
        .filter-btn {{
            padding: 6px 12px;
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 6px;
            color: var(--subtext);
            cursor: pointer;
            font-size: 12px;
            transition: all 0.15s;
        }}
        .filter-btn.active, .filter-btn:hover {{
            background: var(--accent);
            color: #000;
            font-weight: bold;
        }}
        
        .table-container {{
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3);
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
            text-align: left;
        }}
        thead {{
            background: #191a21;
            border-bottom: 2px solid var(--border);
        }}
        th {{
            padding: 6px 8px;
            font-weight: bold;
            color: var(--accent);
            white-space: nowrap;
            user-select: none;
            cursor: pointer;
            transition: color 0.15s;
        }}
        th:hover {{
            color: var(--cyan);
            background: rgba(255,255,255,0.03);
        }}
        th.sort-active {{
            color: var(--green);
        }}


        tbody tr.task-row {{
            border-bottom: 1px solid rgba(255,255,255,0.05);
            cursor: pointer;
            transition: background 0.1s ease;
        }}
        tbody tr.task-row.expanded {{
            background: rgba(189, 147, 249, 0.2);
        }}
        td {{
            padding: 5px 8px;
            vertical-align: middle;
        }}


        /* Couleurs de criticité - Texte direct sans fond */
        .col-crit {{
            text-align: center;
            font-size: 12px;
            font-weight: bold;
            font-family: monospace;
        }}
        .crit-C4 {{ color: #ff5555; font-weight: 900; }}
        .crit-C3 {{ color: #ffb86c; font-weight: 900; }}
        .crit-C2 {{ color: #8be9fd; font-weight: 900; }}
        .crit-C1 {{ color: #a6adc8; }}



        /* Modal & Formulaire d'édition */
        .modal-overlay {{
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0, 0, 0, 0.75);
            display: none;
            justify-content: center;
            align-items: center;
            z-index: 1000;
            backdrop-filter: blur(4px);
        }}
        .modal-box {{
            background: #282a36;
            border: 2px solid var(--accent);
            border-radius: 12px;
            width: 700px;
            max-width: 95%;
            max-height: 90vh;
            overflow-y: auto;
            padding: 24px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.6);
            display: flex;
            flex-direction: column;
            gap: 14px;
        }}
        .modal-title {{
            font-size: 18px;
            font-weight: bold;
            color: var(--accent);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}
        .form-grid {{
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
        }}
        .form-group {{
            display: flex;
            flex-direction: column;
            gap: 4px;
        }}
        .form-group.full {{
            grid-column: span 2;
        }}
        .form-group label {{
            font-size: 12px;
            font-weight: bold;
            color: var(--subtext);
        }}
        .form-control {{
            background: #1e1e2e;
            border: 1px solid var(--border);
            color: #fff;
            padding: 8px 10px;
            border-radius: 6px;
            font-size: 13px;
            outline: none;
        }}
        .form-control:focus {{
            border-color: var(--cyan);
        }}
        textarea.form-control {{
            min-height: 60px;
            resize: vertical;
            line-height: 1.4;
        }}
        .modal-actions {{
            display: flex;
            justify-content: flex-end;
            gap: 10px;
            margin-top: 10px;
        }}
        .btn-action {{
            padding: 8px 16px;
            border-radius: 6px;
            font-weight: bold;
            font-size: 13px;
            cursor: pointer;
            border: none;
            transition: all 0.15s;
        }}
        .btn-save {{ background: var(--green); color: #000; }}
        .btn-save:hover {{ filter: brightness(1.1); transform: scale(1.02); }}
        .btn-cancel {{ background: #44475a; color: #fff; }}
        .btn-primary {{ background: var(--accent); color: #000; font-weight: bold; }}

        /* Couleurs d'alerte vieillissement date */
        .date-fresh {{ color: #50fa7b; font-family: monospace; font-size: 12px; }}
        .date-warning {{ color: #ffb86c; font-weight: bold; font-family: monospace; font-size: 12px; }} /* > 7 jours */
        .date-danger {{ color: #ff5555; font-weight: bold; font-family: monospace; font-size: 12px; }}  /* > 14 jours */
        .parent-tag {{
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: bold;
        }}
        
        /* Volet de détail dépliable */
        .detail-row {{
            background: #21222c;
            border-bottom: 2px solid var(--border);
            display: none;
        }}
        .detail-row.show {{
            display: table-row;
        }}
        .detail-box {{
            padding: 14px 18px;
            display: flex;
            flex-direction: column;
            gap: 8px;
        }}
        .detail-title {{ font-size: 12px; font-weight: bold; color: var(--accent); text-transform: uppercase; }}
        .detail-desc {{
            font-size: 13px;
            line-height: 1.6;
            color: var(--text);
            background: rgba(0,0,0,0.3);
            padding: 10px 14px;
            border-radius: 6px;
            white-space: pre-line;
            border-left: 3px solid var(--cyan);
        }}
        .detail-meta {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 12px;
            color: var(--subtext);
        }}
    </style>
</head>
<body>
    <div class="header">
        <div class="title">🗂️ TASK VIEWER — CATALOGUE DES TÂCHES</div>
        <div class="stats" id="stats"></div>
    </div>
    
    <div class="controls">
        <input type="text" id="search" class="search-box" placeholder="🔍 Rechercher (ID, Kobold, M3, Homed, Frein, AGY...)" oninput="filterTasks()">
        <select id="sort-select" class="sort-box" onchange="setSort(this.value)">
            <option value="date-desc">🕒 Date (Récentes en premier)</option>
            <option value="date-asc">🕒 Date (Anciennes en premier)</option>
            <option value="id-desc">🏷️ ID (Décroissant)</option>
            <option value="id-asc">🏷️ ID (Croissant)</option>
            <option value="crit-desc">🚨 Criticité (C4 → C1)</option>
        </select>
        <button class="filter-btn active" onclick="setFilter('ALL', this)">Tous</button>
        <button class="filter-btn" onclick="setFilter('🔒', this)">🔒 En cours</button>
        <button class="filter-btn" onclick="setFilter('⬜', this)">⬜ À faire</button>
        <button class="filter-btn" onclick="setFilter('⏳', this)">⏳ En attente</button>
        <button class="filter-btn" onclick="setFilter('✅', this)">✅ Validés</button>
        <button class="filter-btn" onclick="setDomain('SÉCURITÉ', this)">🛡️ Sécurité</button>
        <button class="filter-btn" onclick="setDomain('CODEURS', this)">📏 Codeurs</button>
        <button class="filter-btn" onclick="setDomain('TREUILS', this)">🏗️ Treuils</button>
        <button class="filter-btn" onclick="setDomain('TRANSLATION', this)">🚋 Translation</button>
        <button class="filter-btn" onclick="setDomain('CYCLE', this)">⚙️ Cycle</button>
        
        <button class="btn-action btn-save" onclick="openNewTaskModal()">➕ Nouvelle Tâche</button>
        
        <div id="sync-warning-badge" style="display:none; align-items:center; gap:8px; background: rgba(255, 85, 85, 0.15); border: 1px solid #ff5555; padding: 4px 10px; border-radius: 6px; font-size: 12px; color: #ff5555; font-weight: bold;">
            <span style="width:10px; height:10px; background:#ff5555; border-radius:50%; box-shadow:0 0 10px #ff5555; animation: pulse 1.2s infinite; display:inline-block;"></span>
            <span>Modifications non exportées</span>
        </div>

        <button class="btn-action btn-primary" onclick="exportJsonYaml()" id="btn-export">
            <span>💾 Exporter TASKS.yaml</span>
        </button>
    </div>


    
    <div class="table-container">
        <table>
            <thead>
                <tr>
                    <th style="width: 40px; text-align: center;" onclick="sortBy('statut')" id="th-statut">État ↕</th>
                    <th style="width: 75px;" onclick="sortBy('id')" id="th-id">ID ↕</th>
                    <th style="width: 55px;" onclick="sortBy('parent_id')" id="th-parent_id">Parent ↕</th>
                    <th style="width: 60px;" onclick="sortBy('agent')" id="th-agent">Agent ↕</th>
                    <th style="width: 95px;" onclick="sortBy('date')" id="th-date">Date ↕</th>
                    <th style="width: 30px; text-align: center;" onclick="sortBy('criticite')" id="th-criticite">Crit. ↕</th>
                    <th style="width: 85px;" onclick="sortBy('domaine')" id="th-domaine">Domaine ↕</th>
                    <th onclick="sortBy('titre')" id="th-titre">Titre (Cliquer pour trier ou déplier la ligne) ↕</th>

                </tr>
            </thead>
            <tbody id="table-body"></tbody>
        </table>
    </div>

    <!-- Modal d'Édition / Création de Tâche -->
    <div class="modal-overlay" id="task-modal">
        <div class="modal-box">
            <div class="modal-title">
                <span id="modal-heading">📝 Édition de Tâche</span>
                <button onclick="closeModal()" style="background:none; border:none; color:#fff; font-size:20px; cursor:pointer;">✖</button>
            </div>
            <div class="form-grid">
                <div class="form-group">
                    <label>Identifiant (ID) :</label>
                    <input type="text" id="edit-id" class="form-control" placeholder="ex: T147">
                </div>
                <div class="form-group">
                    <label>Tâche Parente (parent_id) :</label>
                    <input type="text" id="edit-parent" class="form-control" placeholder="ex: T146 (optionnel)">
                </div>
                <div class="form-group">
                    <label>État / Statut :</label>
                    <select id="edit-statut" class="form-control">
                        <option value="🔒">🔒 En cours de dev</option>
                        <option value="⬜">⬜ Libre / À faire</option>
                        <option value="🔍">🔍 Étude / Analyse</option>
                        <option value="⏳">⏳ En attente tests / MES</option>
                        <option value="⏸️">⏸️ Bloqué / Différé</option>
                        <option value="✅">✅ Clôturé & Validé</option>
                    </select>
                </div>
                <div class="form-group">
                    <label>Criticité :</label>
                    <select id="edit-crit" class="form-control">
                        <option value="C4">C4 — Sécurité Critique</option>
                        <option value="C3">C3 — Majeur</option>
                        <option value="C2">C2 — Nominal / Métier</option>
                        <option value="C1">C1 — Standards / Doc</option>
                    </select>
                </div>
                <div class="form-group">
                    <label>Domaine :</label>
                    <select id="edit-domaine" class="form-control">
                        <option value="SÉCURITÉ">🛡️ SÉCURITÉ</option>
                        <option value="CODEURS">📏 CODEURS</option>
                        <option value="TREUILS">🏗️ TREUILS</option>
                        <option value="TRANSLATION">🚋 TRANSLATION</option>
                        <option value="CYCLE">⚙️ CYCLE</option>
                        <option value="JOYSTICK">🕹️ JOYSTICK</option>
                        <option value="IHM">🖥️ IHM</option>
                        <option value="STANDARDS">📐 STANDARDS</option>
                        <option value="OUTILLAGE">🛠️ OUTILLAGE</option>
                        <option value="TERRAIN">🚜 TERRAIN</option>
                        <option value="GÉNÉRAL">📦 GÉNÉRAL</option>
                    </select>
                </div>
                <div class="form-group">
                    <label>Agent assigné :</label>
                    <input type="text" id="edit-agent" class="form-control" placeholder="ex: AGY-01, DSH-02, HUM, —">
                </div>
                <div class="form-group full">
                    <label>Titre concis :</label>
                    <input type="text" id="edit-titre" class="form-control" placeholder="Titre court et explicite">
                </div>
                <div class="form-group full">
                    <label>1. Contexte & Origine :</label>
                    <textarea id="edit-contexte" class="form-control" placeholder="Origine, incident, session REX..."></textarea>
                </div>
                <div class="form-group full">
                    <label>2. Description Fonctionnelle :</label>
                    <textarea id="edit-desc" class="form-control" style="min-height:80px;" placeholder="Explication en français du besoin métier..."></textarea>
                </div>
                <div class="form-group full">
                    <label>3. Objectifs (1 objectif par ligne) :</label>
                    <textarea id="edit-obj" class="form-control" placeholder="① Variable FB...&#10;② Condition fail-safe..."></textarea>
                </div>
                <div class="form-group full">
                    <label>Lien Contrat YAML :</label>
                    <input type="text" id="edit-contrat" class="form-control" placeholder="DOC/WFLOW/CONTRACTS/TASK_CONTRACT_...yaml">
                </div>
            </div>
            <div class="modal-actions" style="justify-content: space-between;">
                <div>
                    <button class="btn-action" id="btn-modal-delete" style="background:#ff5555; color:#fff; display:none;" onclick="deleteFromModal()">🗑️ Supprimer</button>
                </div>
                <div style="display: flex; gap: 10px;">
                    <button class="btn-action btn-cancel" onclick="closeModal()">Annuler</button>
                    <button class="btn-action btn-save" onclick="saveTaskModal()">💾 Enregistrer la Tâche</button>
                </div>
            </div>
        </div>
    </div>


    <!-- Modal d'Exportation des Données -->

    <div class="modal-overlay" id="export-modal">
        <div class="modal-box" style="width: 600px;">
            <div class="modal-title">
                <span>💾 Exporter / Sauvegarder les Tâches</span>
                <button onclick="document.getElementById('export-modal').style.display='none'" style="background:none; border:none; color:#fff; font-size:20px; cursor:pointer;">✖</button>
            </div>
            <div style="font-size: 13px; color: var(--subtext);">
                Copiez le texte ci-dessous ou cliquez sur le bouton pour enregistrer directement le fichier :
            </div>
            <textarea id="export-text" class="form-control" style="height: 250px; font-family: monospace; font-size: 11px;" readonly></textarea>
            <div class="modal-actions">
                <button class="btn-action btn-cancel" onclick="document.getElementById('export-modal').style.display='none'">Fermer</button>
                <button class="btn-action btn-save" onclick="copyExportText()">📋 Copier le YAML</button>
                <button class="btn-action btn-primary" onclick="downloadExportFile()">💾 Enregistrer directement dans TASKS.yaml</button>
            </div>

        </div>
    </div>



    <script>

        // Chargement direct et dynamique depuis TASKS.yaml
        const defaultTasks = {tasks_json};
        let tasks = [...defaultTasks];
        let hasUnsavedChanges = false;

        // Fonction de chargement dynamique depuis TASKS.yaml
        async function loadFromYamlFile() {{
            try {{
                const res = await fetch('TASKS.yaml?' + new Date().getTime());
                if (res.ok) {{
                    const text = await res.text();
                    const parsed = parseYamlTasks(text);
                    if (parsed && parsed.length > 0) {{
                        tasks = parsed;
                        hasUnsavedChanges = false;
                        updateSyncIndicator();
                        render();
                        return;
                    }}
                }}
            }} catch(e) {{
                console.warn('Chargement dynamique non disponible (mode local direct file://) :', e);
            }}
            // Fallback base injectée
            tasks = [...defaultTasks];
            hasUnsavedChanges = false;
            updateSyncIndicator();
            render();
        }}

        function parseYamlTasks(yamlText) {{
            const lines = yamlText.split('\\n');
            const result = [];
            let current = null;
            let currentField = null;

            for (let rawLine of lines) {{
                const line = rawLine.replace(/\\r$/, '');
                if (/^\\s*-\\s+id:\\s*"([^"]+)"/.test(line)) {{
                    if (current) result.push(current);
                    current = {{
                        id: line.match(/^\\s*-\\s+id:\\s*"([^"]+)"/)[1],
                        parent_id: '',
                        statut: '⬜',
                        criticite: 'C2',
                        domaine: 'GÉNÉRAL',
                        agent: '—',
                        date: '2026-08-22T00:00:00',
                        titre: '',
                        contexte: '',
                        description: '',
                        contrat: '',
                        objectifs: [],
                        bloque_par: []
                    }};
                    currentField = null;
                    continue;
                }}
                if (!current) continue;

                const kv = line.match(/^\\s+([a-zA-Z0-9_]+):\\s*(.*)$/);
                if (kv) {{
                    const key = kv[1];
                    let val = kv[2].trim();
                    currentField = key;
                    if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {{
                        val = val.substring(1, val.length - 1).replace(/\\\\"/g, '"');
                    }}
                    if (key === 'objectifs' || key === 'bloque_par') {{
                        if (val === '[]') current[key] = [];
                    }} else {{
                        current[key] = val;
                    }}
                    continue;
                }}

                const itemMatch = line.match(/^\\s+-\\s+"(.*)"$/);
                if (itemMatch && currentField && Array.isArray(current[currentField])) {{
                    current[currentField].push(itemMatch[1].replace(/\\\\"/g, '"'));
                }}
            }}
            if (current) result.push(current);
            return result;
        }}




        function updateSyncIndicator() {{
            const badge = document.getElementById('sync-warning-badge');
            const btn = document.getElementById('btn-export');
            if (!badge || !btn) return;

            if (hasUnsavedChanges) {{
                badge.style.display = 'inline-flex';
                btn.style.background = '#bd93f9';
                btn.style.color = '#000';
            }} else {{
                badge.style.display = 'none';
                btn.style.background = 'var(--primary)';
                btn.style.color = '#fff';
            }}
        }}

        function persistTasks() {{
            hasUnsavedChanges = true;
            updateSyncIndicator();
            try {{
                localStorage.setItem('TASK_VIEWER_DATA', JSON.stringify(tasks));
                localStorage.setItem('TASK_VIEWER_UNSAVED', 'true');
            }} catch(e) {{}}
        }}

        function resetToOfficial() {{
            if (confirm('Voulez-vous réinitialiser le catalogue avec les données officielles du fichier ?')) {{
                localStorage.removeItem('TASK_VIEWER_DATA');
                localStorage.removeItem('TASK_VIEWER_UNSAVED');
                tasks = [...defaultTasks];
                hasUnsavedChanges = false;
                updateSyncIndicator();
                render();
            }}
        }}




        let currentStatus = 'ALL';
        let currentDomain = 'ALL';
        let sortKey = 'date';
        let sortAsc = false;
        let expandedId = null;


        function render() {{
            const tbody = document.getElementById('table-body');
            const search = document.getElementById('search').value.toLowerCase();
            tbody.innerHTML = '';
            
            // Mise à jour des flèches d'en-têtes
            document.querySelectorAll('th').forEach(th => {{
                th.classList.remove('sort-active');
                th.innerText = th.innerText.replace(/[▲▼↕]/g, '').trim() + ' ↕';
            }});
            const activeTh = document.getElementById('th-' + sortKey);
            if (activeTh) {{
                activeTh.classList.add('sort-active');
                activeTh.innerText = activeTh.innerText.replace('↕', sortAsc ? '▲' : '▼');
            }}

            let countDone = 0, countLock = 0, countOpen = 0;
            tasks.forEach(t => {{
                if (t.statut === '✅') countDone++;
                else if (t.statut === '🔒' || t.statut === '🔍') countLock++;
                else countOpen++;
            }});
            
            document.getElementById('stats').innerHTML = `
                <span class="badge badge-done">✅ ${{countDone}} Validées</span>
                <span class="badge badge-lock">🔒 ${{countLock}} En cours</span>
                <span class="badge badge-open">⬜ ${{countOpen}} À traiter</span>
                <span class="badge" style="background:#44475a; color:#fff;">Total : ${{tasks.length}}</span>
            `;

            let filtered = tasks.filter(t => {{
                const matchStatus = currentStatus === 'ALL' || t.statut === currentStatus || (currentStatus === '🔒' && t.statut === '🔍');
                const matchDomain = currentDomain === 'ALL' || t.domaine === currentDomain;
                const matchText = (t.id + ' ' + (t.parent_id || '') + ' ' + t.titre + ' ' + t.description + ' ' + t.domaine + ' ' + (t.agent || '')).toLowerCase().includes(search);
                return matchStatus && matchDomain && matchText;
            }});

            filtered.sort((a, b) => {{
                let valA = a[sortKey] || '';
                let valB = b[sortKey] || '';

                if (sortKey === 'id' || sortKey === 'parent_id') {{
                    valA = parseInt(valA.replace(/\\D/g, '')) || 0;
                    valB = parseInt(valB.replace(/\\D/g, '')) || 0;
                }}

                let res = 0;
                if (typeof valA === 'number') {{
                    res = valA - valB;
                }} else {{
                    res = valA.toString().localeCompare(valB.toString());
                }}
                return sortAsc ? res : -res;
            }});

            // Palette de 12 couleurs néon/pastel bien distinctes
            const familyPalette = [
                '#8be9fd', '#50fa7b', '#ffb86c', '#ff79c6', '#bd93f9', 
                '#f1fa8c', '#00f2fe', '#4facfe', '#43e97b', '#fa709a', 
                '#fee140', '#30cfd0'
            ];

            function getFamilyColor(task) {{
                const fam = task.parent_id || task.id.split('-')[0] || task.id;
                let hash = 0;
                for (let i = 0; i < fam.length; i++) {{
                    hash = fam.charCodeAt(i) + ((hash << 5) - hash);
                }}
                const idx = Math.abs(hash) % familyPalette.length;
                return familyPalette[idx];
            }}

            // Calcul de l'âge de la tâche par rapport à aujourd'hui (2026-08-22)
            function getDateClass(dateStr) {{
                const now = new Date('2026-08-22T22:35:00');
                const taskDate = new Date(dateStr);
                const diffDays = Math.floor((now - taskDate) / (1000 * 60 * 60 * 24));
                if (diffDays <= 4) return 'date-fresh';      // Récente (<= 4 jours) : Vert (#50fa7b)
                if (diffDays <= 10) return 'date-warning';   // 5 à 10 jours : Jaune/Orange (#ffb86c)
                return 'date-danger';                        // > 10 jours : Rouge (#ff5555)
            }}

            function formatDate2Lines(dateStr) {{
                if (!dateStr) return '—';
                const parts = dateStr.split('T');
                const d = parts[0] || '';
                const h = (parts[1] || '').substring(0, 5);
                return `<div style="line-height: 1.2;"><div>${{d}}</div><div style="font-size: 11px; opacity: 0.75;">${{h}}</div></div>`;
            }}

            filtered.forEach(t => {{
                const isExp = expandedId === t.id;
                const famColor = getFamilyColor(t);
                const dateCls = getDateClass(t.date);
                const dateHtml = formatDate2Lines(t.date);
                
                const tr = document.createElement('tr');
                tr.className = 'task-row' + (isExp ? ' expanded' : '');
                tr.id = 'row-' + t.id;
                tr.onclick = () => toggleDetail(t.id);

                
                tr.innerHTML = `
                    <td class="col-status">${{t.statut}}</td>
                    <td><span style="background: rgba(255,255,255,0.06); color: ${{famColor}}; border: 1px solid ${{famColor}}55; padding: 2px 8px; border-radius: 4px; font-weight: bold; font-family: monospace;">${{t.id}}</span></td>
                    <td>${{t.parent_id ? '<span class="parent-tag" style="background: rgba(255,255,255,0.06); color: ' + famColor + '; border: 1px dashed ' + famColor + '77;">↳ ' + t.parent_id + '</span>' : '<span style="color:#6272a4;">—</span>'}}</td>
                    <td class="col-agent">${{t.agent && t.agent !== '—' ? t.agent : '—'}}</td>
                    <td class="${{dateCls}}">${{dateHtml}}</td>
                    <td class="col-crit crit-${{t.criticite}}">${{t.criticite}}</td>
                    <td><span class="col-domain">${{t.domaine}}</span></td>
                    <td class="col-title">${{t.titre}}</td>
                `;
                tbody.appendChild(tr);



                // Ligne de détail dépliable avec 3 volets toujours présents et couleurs dédiées
                const trDetail = document.createElement('tr');
                trDetail.className = 'detail-row' + (isExp ? ' show' : '');
                trDetail.id = 'detail-' + t.id;
                
                let objectifsBody = '<div style="font-size: 13px; color: var(--subtext); font-style: italic; margin-top: 2px;">Aucun objectif spécifique renseigné.</div>';
                if (t.objectifs && t.objectifs.length > 0) {{
                    const objList = t.objectifs.map(o => '<li>' + o + '</li>').join('');
                    objectifsBody = '<ul style="margin: 4px 0 0 16px; padding: 0; color: var(--text); font-size: 13px; line-height: 1.5;">' + objList + '</ul>';
                }}

                const contexteBody = t.contexte ? 
                    '<div style="font-size: 13px; color: var(--text); background: rgba(0,0,0,0.2); padding: 6px 10px; border-radius: 4px; margin-top: 2px; border-left: 2px solid var(--orange);">' + t.contexte + '</div>' :
                    '<div style="font-size: 13px; color: var(--subtext); font-style: italic; margin-top: 2px;">Aucun contexte d&apos;origine particulier.</div>';

                const descBody = t.description ?
                    '<div class="detail-desc">' + t.description + '</div>' :
                    '<div style="font-size: 13px; color: var(--subtext); font-style: italic; margin-top: 2px;">Aucune description detaillee.</div>';


                trDetail.innerHTML = `
                    <td colspan="8">
                        <div class="detail-box">
                            <div>
                                <div class="detail-title" style="color: var(--orange);">🗓️ 1. Contexte & Origine :</div>
                                ${{contexteBody}}
                            </div>
                            <div>
                                <div class="detail-title" style="color: var(--cyan);">📖 2. Description Fonctionnelle :</div>
                                ${{descBody}}
                            </div>
                            <div>
                                <div class="detail-title" style="color: var(--green);">🎯 3. Objectifs Mesurables & Attendus :</div>
                                ${{objectifsBody}}
                            </div>
                            <div class="detail-meta" style="margin-top: 10px; border-top: 1px solid rgba(255,255,255,0.08); padding-top: 8px;">
                                <div>
                                    <span>📄 Contrat : <strong>${{t.contrat || 'Aucun contrat dédié'}}</strong></span> &nbsp;|&nbsp; 
                                    <span>🏷️ Statut : <strong>${{t.statut}}</strong></span> &nbsp;|&nbsp; 
                                    <span>🔒 Agent : <strong>${{t.agent || 'Non assigné'}}</strong></span>
                                </div>
                                <div style="display:flex; gap:8px;">
                                    <button class="btn-action" style="background:#ffb86c; color:#000; padding:4px 10px; font-size:12px;" onclick="openEditModal('${{t.id}}', event)">✏️ Modifier</button>
                                    <button class="btn-action" style="background:#bd93f9; color:#000; padding:4px 10px; font-size:12px;" onclick="duplicateTask('${{t.id}}', event)">📋 Dupliquer</button>
                                </div>
                            </div>
                        </div>
                    </td>
                `;
                tbody.appendChild(trDetail);
            }});
        }}

        function deleteTask(taskId, event) {{
            if (event) event.stopPropagation();
            tasks = tasks.filter(t => t.id !== taskId);
            persistTasks();
            render();
        }}

        // --- Fonctions d'Édition / Création / Duplication ---
        let editingIndex = -1;

        function openNewTaskModal() {{
            editingIndex = -1;
            document.getElementById('modal-heading').innerText = '➕ Création d\\'une Nouvelle Tâche';
            document.getElementById('btn-modal-delete').style.display = 'none';
            
            let maxNum = 0;
            tasks.forEach(t => {{
                const n = parseInt(t.id.replace(/\\D/g, '')) || 0;
                if (n > maxNum) maxNum = n;
            }});
            const nextId = 'T' + (maxNum + 1);

            document.getElementById('edit-id').value = nextId;
            document.getElementById('edit-parent').value = '';
            document.getElementById('edit-statut').value = '⬜';
            document.getElementById('edit-crit').value = 'C2';
            document.getElementById('edit-domaine').value = 'SÉCURITÉ';
            document.getElementById('edit-agent').value = '—';
            document.getElementById('edit-titre').value = '';
            document.getElementById('edit-contexte').value = '';
            document.getElementById('edit-desc').value = '';
            document.getElementById('edit-obj').value = '';
            document.getElementById('edit-contrat').value = '';

            document.getElementById('task-modal').style.display = 'flex';
        }}

        function openEditModal(taskId, event) {{
            if (event) event.stopPropagation();
            const idx = tasks.findIndex(t => t.id === taskId);
            if (idx === -1) return;
            
            editingIndex = idx;
            const t = tasks[idx];
            document.getElementById('modal-heading').innerText = '✏️ Modification de la Tâche ' + t.id;
            document.getElementById('btn-modal-delete').style.display = 'inline-block';

            document.getElementById('edit-id').value = t.id;
            document.getElementById('edit-parent').value = t.parent_id || '';
            document.getElementById('edit-statut').value = t.statut;
            document.getElementById('edit-crit').value = t.criticite;
            document.getElementById('edit-domaine').value = t.domaine;
            document.getElementById('edit-agent').value = t.agent || '—';
            document.getElementById('edit-titre').value = t.titre;
            document.getElementById('edit-contexte').value = t.contexte || '';
            document.getElementById('edit-desc').value = t.description || '';
            document.getElementById('edit-obj').value = (t.objectifs || []).join('\\n');
            document.getElementById('edit-contrat').value = t.contrat || '';

            document.getElementById('task-modal').style.display = 'flex';
        }}

        function deleteFromModal() {{
            if (editingIndex >= 0 && editingIndex < tasks.length) {{
                const targetId = tasks[editingIndex].id;
                deleteTask(targetId);
                closeModal();
            }}
        }}



        function duplicateTask(taskId, event) {{
            if (event) event.stopPropagation();
            const t = tasks.find(item => item.id === taskId);
            if (!t) return;

            editingIndex = -1;
            document.getElementById('modal-heading').innerText = '📋 Duplication de ' + t.id;

            // Suggérer sous-tâche ou nouvel ID
            const newId = t.id.includes('-') ? t.id + '-copy' : t.id + '-A';
            document.getElementById('edit-id').value = newId;
            document.getElementById('edit-parent').value = t.parent_id || t.id;
            document.getElementById('edit-statut').value = '⬜';
            document.getElementById('edit-crit').value = t.criticite;
            document.getElementById('edit-domaine').value = t.domaine;
            document.getElementById('edit-agent').value = '—';
            document.getElementById('edit-titre').value = t.titre + ' (Copie)';
            document.getElementById('edit-contexte').value = t.contexte || '';
            document.getElementById('edit-desc').value = t.description || '';
            document.getElementById('edit-obj').value = (t.objectifs || []).join('\\n');
            document.getElementById('edit-contrat').value = '';

            document.getElementById('task-modal').style.display = 'flex';
        }}

        function closeModal() {{
            document.getElementById('task-modal').style.display = 'none';
        }}

        function saveTaskModal() {{
            const idVal = document.getElementById('edit-id').value.trim();
            if (!idVal) {{
                alert('Veuillez renseigner un identifiant (ID) !');
                return;
            }}

            const rawObj = document.getElementById('edit-obj').value.trim();
            const objList = rawObj ? rawObj.split('\\n').map(s => s.trim()).filter(s => s.length > 0) : [];
            
            const nowIso = new Date().toISOString().substring(0, 19);

            const taskData = {{
                id: idVal,
                parent_id: document.getElementById('edit-parent').value.trim(),
                statut: document.getElementById('edit-statut').value,
                criticite: document.getElementById('edit-crit').value,
                domaine: document.getElementById('edit-domaine').value,
                agent: document.getElementById('edit-agent').value.trim() || '—',
                titre: document.getElementById('edit-titre').value.trim(),
                contexte: document.getElementById('edit-contexte').value.trim(),
                description: document.getElementById('edit-desc').value.trim(),
                objectifs: objList,
                contrat: document.getElementById('edit-contrat').value.trim(),
                date: nowIso,
                bloque_par: []
            }};

            if (editingIndex >= 0) {{
                tasks[editingIndex] = taskData;
            }} else {{
                // Nouvelle tâche en tête de liste
                tasks.unshift(taskData);
            }}

            persistTasks();
            closeModal();
            render();
            alert('✅ Tâche ' + idVal + ' enregistrée avec succès dans le visualiseur !\\n\\nCliquez sur "💾 Copier / Exporter" pour récupérer le YAML mis à jour.');

        }}

        function generateYamlText() {{
            let yaml = '# ============================================================\\n';
            yaml += '# CATALOGUE OFFICIEL DES TÂCHES — EXCAVATRICE DE DRAGAGE\\n';
            yaml += '# ============================================================\\n';
            yaml += '# 💡 Modifiable dans TASK_VIEWER.html ou directement ici.\\n';
            yaml += '# 🔄 Synchronisé automatiquement.\\n\\n';
            yaml += 'tasks:\\n';

            tasks.forEach(t => {{
                yaml += '  - id: "' + t.id + '"\\n';
                yaml += '    parent_id: "' + (t.parent_id || '') + '"\\n';
                yaml += '    statut: "' + t.statut + '"\\n';
                yaml += '    criticite: "' + t.criticite + '"\\n';
                yaml += '    domaine: "' + t.domaine + '"\\n';
                yaml += '    agent: "' + (t.agent || '—') + '"\\n';
                yaml += '    date: "' + (t.date || '') + '"\\n';
                yaml += '    titre: ' + JSON.stringify(t.titre) + '\\n';
                yaml += '    contexte: ' + JSON.stringify(t.contexte || '') + '\\n';
                yaml += '    description: ' + JSON.stringify(t.description || '') + '\\n';
                yaml += '    contrat: "' + (t.contrat || '') + '"\\n';
                if (t.objectifs && t.objectifs.length > 0) {{
                    yaml += '    objectifs:\\n';
                    t.objectifs.forEach(o => {{
                        yaml += '      - ' + JSON.stringify(o) + '\\n';
                    }});
                }} else {{
                    yaml += '    objectifs: []\\n';
                }}
                yaml += '    bloque_par: []\\n\\n';
            }});

            return yaml;
        }}

        function exportJsonYaml() {{
            const yamlText = generateYamlText();
            document.getElementById('export-text').value = yamlText;
            document.getElementById('export-modal').style.display = 'flex';
        }}

        function copyExportText() {{
            const textarea = document.getElementById('export-text');
            textarea.select();
            document.execCommand('copy');
            alert('📋 Contenu TASKS.yaml copié dans le presse-papier !');
        }}

        let savedFileHandle = null;

        async function downloadExportFile() {{
            const yamlText = generateYamlText();

            // 1. Si on a déjà un handle ouvert, on écrit directement dedans sans ouvrir de fenêtre !
            if (savedFileHandle) {{
                try {{
                    const writable = await savedFileHandle.createWritable();
                    await writable.write(yamlText);
                    await writable.close();
                    localStorage.removeItem('TASK_VIEWER_UNSAVED');
                    localStorage.setItem('TASK_VIEWER_DATA', JSON.stringify(tasks));
                    hasUnsavedChanges = false;
                    updateSyncIndicator();
                    document.getElementById('export-modal').style.display = 'none';
                    return;
                }} catch (e) {{
                    savedFileHandle = null;
                }}
            }}

            // 2. Si File System Access API est supportée
            if ('showSaveFilePicker' in window) {{
                try {{
                    const handle = await window.showSaveFilePicker({{
                        suggestedName: 'TASKS.yaml',
                        types: [{{
                            description: 'Fichier YAML des Tâches',
                            accept: {{ 'text/yaml': ['.yaml', '.yml'] }}
                        }}]
                    }});
                    const writable = await handle.createWritable();
                    await writable.write(yamlText);
                    await writable.close();
                    savedFileHandle = handle;
                    localStorage.removeItem('TASK_VIEWER_UNSAVED');
                    localStorage.setItem('TASK_VIEWER_DATA', JSON.stringify(tasks));
                    hasUnsavedChanges = false;
                    updateSyncIndicator();
                    document.getElementById('export-modal').style.display = 'none';
                    return;
                }} catch (err) {{
                    if (err.name === 'AbortError') {{
                        return;
                    }}
                    console.warn('Fallback téléchargement :', err);
                }}
            }}

            // 3. Fallback téléchargement direct classique
            const blob = new Blob([yamlText], {{ type: 'text/yaml;charset=utf-8' }});
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'TASKS.yaml';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            localStorage.removeItem('TASK_VIEWER_UNSAVED');
            localStorage.setItem('TASK_VIEWER_DATA', JSON.stringify(tasks));
            hasUnsavedChanges = false;
            updateSyncIndicator();
            document.getElementById('export-modal').style.display = 'none';
        }}











        function sortBy(key) {{
            if (sortKey === key) {{
                sortAsc = !sortAsc;
            }} else {{
                sortKey = key;
                sortAsc = (key === 'id' || key === 'titre' || key === 'domaine');
            }}
            render();
        }}

        function toggleDetail(id) {{
            const detailEl = document.getElementById('detail-' + id);
            const rowEl = document.getElementById('row-' + id);
            if (!detailEl || !rowEl) return;

            const isShown = detailEl.classList.contains('show');
            
            document.querySelectorAll('.detail-row').forEach(el => el.classList.remove('show'));
            document.querySelectorAll('.task-row').forEach(el => el.classList.remove('expanded'));

            if (!isShown) {{
                detailEl.classList.add('show');
                rowEl.classList.add('expanded');
            }}
        }}


        function filterTasks() {{ render(); }}
        function setSort(sortVal) {{
            if (sortVal === 'date-desc') {{ sortKey = 'date'; sortAsc = false; }}
            else if (sortVal === 'date-asc') {{ sortKey = 'date'; sortAsc = true; }}
            else if (sortVal === 'id-desc') {{ sortKey = 'id'; sortAsc = false; }}
            else if (sortVal === 'id-asc') {{ sortKey = 'id'; sortAsc = true; }}
            else if (sortVal === 'crit-desc') {{ sortKey = 'criticite'; sortAsc = false; }}
            render();
        }}
        function setFilter(status, btn) {{
            currentStatus = status;
            currentDomain = 'ALL';
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            render();
        }}
        function setDomain(dom, btn) {{
            currentDomain = dom;
            currentStatus = 'ALL';
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            render();
        }}

        loadFromYamlFile();
    </script>
</body>
</html>

"""

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html)


def load_tasks_yaml(yaml_path: Path):


    """Charge les tâches depuis TASKS.yaml."""
    if not yaml_path.exists():
        return []
    with open(yaml_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if isinstance(data, dict) and "tasks" in data:
        return data["tasks"]
    elif isinstance(data, list):
        return data
    return []


def main():
    print("=" * 60)
    print("🔄 GÉNÉRATION DU CATALOGUE OFFICIEL (TASKS.yaml & TASKS.html)")
    print("=" * 60)

    # TASKS.yaml est l'unique source de vérité officielle !
    tasks = load_tasks_yaml(TASKS_YAML)
    
    html_path = WFLOW_DIR / "TASK_VIEWER.html"
    save_tasks_html(tasks, html_path)
    
    print(f"✅ {len(tasks)} tâches structurées exportées avec succès dans :")
    print(f"   YAML : {TASKS_YAML}")
    print(f"   HTML : {html_path}")

    print("\n💡 Visualisez en 1 clic : Ouvrez TASK_VIEWER.html dans votre navigateur ou VS Code Simple Browser !")


if __name__ == "__main__":
    main()





