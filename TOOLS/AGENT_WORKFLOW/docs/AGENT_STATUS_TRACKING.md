# 📡 Suivi d'état des agents (checkpoints partagés)

> Pourquoi : les utilisateurs ont besoin de **voir l'avancement** des sous-agents en
> quasi temps réel, pas seulement leur état final.

## 🚨 Limite de fond — pourquoi pas un heartbeat 5s natif

Un sous-agent LLM **ne bat pas** un heartbeat 5 s : il travaille par **tours**
(« penser → appeler un outil → attendre → penser … »). Chaque tour dure typiquement
**10–60 s+**. Le harness ne notifie l'orchestrateur qu'à la **fin** d'un agent.
Impossible donc de garantir un « toutes les 5 s » strict côté agent.

**La solution :** un **checkpoint explicite** — chaque agent append une ligne d'état
dans un fichier partagé à chaque étape. L'humain / l'orchestrateur suit en direct.

## ⚙️ Script : `agent_heartbeat.py`

Emplacement : `TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py` (stdlib uniquement).

```bash
# 1. Créer le dossier status/ (idempotent)
python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py init

# 2. Agent : journaliser une étape (~10s max sans log, autant que possible)
python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py record <SESSION> <ETAPE> <etat> --agent <nom> --msg "<resume>"
#    <etat> : en_cours | ok | fail | attente_validation | termine

# 3. Humain / orchestrateur : suivi en direct
python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py watch            # toutes sessions
python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py watch <SESSION>  # une session
python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py watch <SESSION> --no-follow  # état courant puis sort
```

## 📁 Emplacement des fichiers

- `TOOLS/AGENT_WORKFLOW/status/<SESSION>.log` — un fichier par session.
- **Git-ignore** (`.gitignore` racine) : jamais commités, régénérables.

## ⏱️ Run des gates : durée remontée en temps réel

`run_all_gates.py` (mode compact, le défaut) affiche désormais le résultat de
**chaque gate dès qu'il se termine**, avec sa durée :

```text
  ✅ PASS G100 — Code style (VAR_OUTPUT, simulation) · 0.31s
  ❌ FAIL G480 — Harnais integration ... · 1.02s
```

Plus besoin d'attendre le résumé final pour connaître l'avancement gate par gate.
C'est indépendant du `watch` d'`agent_heartbeat.py` : c'est la sortie console
directe du runner.

## 📋 Contrat pour les agents délégués

Le préambule `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` (section
**« Checkpoint de progression — obligatoire »**) impose à chaque sous-agent :
- journaliser à chaque étape franchie (début, lecture specs, écriture, gates,
  attente validation, fin) ;
- cible **~10s** sans log, avec dérogation justifiée pour un outil long.

## ❓ FAQ rapide

- **Pourquoi ~10s et pas 5s ?** Un agent LLM bloque parfois sur un appel d'outil
  long (gros gate, génération de bundle) ; 10s est une cible réaliste pour des tours
  de 10–60s. Le 5s strict est structurellement impossible.
- **Qui écrit ?** L'agent lui-même (obligation dans le préambule) et/ou
  l'orchestrateur qui consigne les événements qu'il observe.
- **Et l'orchestrateur ?** Il peut aussi `record` des événements pour regrouper les
  sessions dans un seul flux `watch`.
