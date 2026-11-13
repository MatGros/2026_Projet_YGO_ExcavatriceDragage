# T000 — Orchestration Générale Multi-Tâches & Pilotage des Sessions

> **Document de travail unique** pour le suivi, les arbitrages, l'avancement des sous-agents et la synchronisation avec le Superviseur.

| | |
|---|---|
| **ID / criticité** | `T000` · C1 (Pilotage & Outillage) |
| **Type** | exécution · étude |
| **Responsable** | `CC01` / `AGY01` (Orchestrateur) |
| **Statut** | ⏳ en cours |
| **Dernière mise à jour** | 2026-11-13 |

---

## 1. But
Centraliser le pilotage des chantiers en cours, cadrer les sous-agents sans dispersion, éviter les freezes d'IDE, et maintenir l'alignement strict entre la machine réelle, CODESYS, le Superviseur local et les terminaux.

---

## 2. Périmètre
- ✅ **Autorisé** :
  - Orchestration générale du catalogue `TASKS.yaml`.
  - Cadrage des prompts chirurgicaux pour sous-agents légers (DeepSeek / GLM Flash).
  - Outillage de supervision, logs d'audit et scripts de statut (`TOOLS/AGENT_WORKFLOW/scripts/`).
  - Validation déterministe (`run_all_gates.py`, `G200_check_linkage.py`, pytest).
- ⛔ **Interdit** :
  - Modification non concertée de `CODE/*.st`.
  - Commits ou pushs sans accord explicite de l'exploitant.
  - Spams d'appels ou boucles d'outils non bornées en background.

---

## 3. Critères d'Acceptation (AC)
- **AC1** : Commande `/rename-session` 100% opérationnelle et synchronisée (Superviseur port 8082, onglet terminal `${sequenceTitle}`, transcript Claude Code).
- **AC2** : Statusline lisible et sobre, intégrant les couleurs normées par famille d'acteur (`CC` rouge, `AGY` bleu, `CDX` vert, `DSH` cyan, `GLM` magenta, `MMX` jaune) et un badge Superviseur non agressif (`Linked (Active)` vert sobre, `0 alerte` gris neutre).
- **AC3** : Découpage chirurgical des délégations sous-agents : application de la règle des 2 écarts et du sas Anti-Garbage-In avant relance.
- **AC4** : Maintien de la performance machine (absence de freeze VS Code, limitation des processus zombies).

---

## 4. Étapes & Jalons
| # | Étape | Fait quand… | État |
|---|---|---|---|
| 1 | Fiabilisation `/rename-session` | Auto-attachement Superviseur + WAL validés | ✅ fait |
| 2 | Harmonisation Couleurs Statusline | Couleurs par modèle et sobriété alertes validées | ✅ fait |
| 3 | Intégration Skill Codex `$rename-session` | Déployé dans `~/.codex/skills/rename-session/` | ✅ fait |
| 4 | Diagnostic & Monitoring anti-freeze | Causes identifiées et process purgés | ⏳ en cours |
| 5 | Lancement première tâche catalogue | Cadrage prompt et lot prioritaire validé | ⬜ à faire |

---

## 5. Décisions d'Architecture
| ID | Question | Décision | Qui, quand |
|---|---|---|---|
| D1 | Séparateur pour les alias machine vs dossiers | Tirets `-` obligatoires pour les alias machine (`TXXX-AGENT`) pour conformité API/URL/regex ; Underscores `_` obligatoires pour les dossiers/fichiers sur disque (norme T279). | Arbitré CC01 / HUM, 2026-11-13 |
| D2 | Identification session Claude Code sous modèle AGY | Identifiant machine rattaché au CLI exécutant (`CC01`), avec affichage contextuel du modèle dans Terminal Keeper. | Arbitré CC01 / HUM, 2026-11-13 |
| D3 | Écrasement intempestif titre terminal | Suppression du fallback forcé dans `session_statusline.py` pour préserver le titre explicite fixé par `/rename-session`. | Résolu CC01, 2026-11-13 |

---

## 6. Fichiers du dossier
| Fichier / dossier | Rôle | Validé par / le |
|---|---|---|
| `T000_PLAN_ORCHESTRATION_MULTI_TACHES_20261113_v1.0.md` | Ce document unique de travail | CC01, 2026-11-13 |
| `DOC/WFLOW/SESSION_RENAME_AUDIT.log` | Journal WAL des renommages de session | CC01, 2026-11-13 |

---

## 7. Vérifié / Non vérifié
- ✅ `test_rename_session.py` : 9/9 PASS (nominal, WAL, accents, offline, auto-add).
- ✅ Notification Superviseur en direct sur port 8082 : validée (status 200, sans mode dirty).
- ✅ Statusline testée : couleurs contrastées conformes aux terminaux.
- ⏳ Identification de la charge d'arrière-plan résiduelle provoquant des freezes VS Code.

---

## 8. Journal de Bord
- 2026-11-13 · Initialisation du plan d'orchestration `T000`, correction de l'écrasement de titre dans `session_statusline.py`, harmonisation des couleurs d'acteurs et support du format `ai-title` dans les transcripts Claude Code.
