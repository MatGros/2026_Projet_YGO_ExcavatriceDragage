# ═══════════════════════════════════════════════════════════════════════════
# CONTRAT DE TACHE — Propager les renames GVL_Troubleshooting (préfixe numérique)
# ═══════════════════════════════════════════════════════════════════════════

contract:
  # ── Identification ────────────────────────────────────────────────────────
  task_id: PROPAG-RENAMES-GVL-TROUBLESHOOTING
  criticality: C2
  strategy: patch

  # ── 1. Objectif metier ────────────────────────────────────────────────────
  objective: >
    Propager les renames des variables GVL_Troubleshooting (préfixe numérique
    ajouté par l'utilisateur) dans toutes les références : FB_TroubleshootingView.st,
    troubleshooting_variables.txt, et tout autre CODE/*.st. Renommage pur, aucun
    changement de comportement.

  # ── 2. Criteres testables ─────────────────────────────────────────────────
  acceptance:
    - id: AC1
      statement: "Toutes les références aux anciens noms (ex. GVL_Troubleshooting.ContexteMachineGlobal) sont mises à jour vers les nouveaux (ex. GVL_Troubleshooting.00_ContexteMachineGlobal)."
      verified_by: "grep des anciens noms → 0 occurrence dans CODE/"
    - id: AC2
      statement: "troubleshooting_variables.txt est mis à jour avec les nouveaux noms."
      verified_by: "grep troubleshooting_variables.txt"
    - id: AC3
      statement: "Renommage pur : aucun changement de comportement (G200 PASS, bundle frais)."
      verified_by: "G200_check_linkage.py + generate_codesys_bundle.py"

  # ── 3. Perimetre ──────────────────────────────────────────────────────────
  scope:
    allowed:
      - CODE/J_SUPERVISION/FB_TroubleshootingView.st
      - TOOLS/PLC_CSV_SNAPSHOT/variable_lists/troubleshooting_variables.txt
      - CODE/J_SUPERVISION/GVL_Troubleshooting.st   # si besoin de vérifier
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export

  # ── 4. Contrat de conservation ────────────────────────────────────────────
  conservation:
    must_survive:
      - "Le comportement du troubleshooting (aucun changement de logique)"
      - "La structure des variables (IdxXXX) inchangée"
    dropped_on_purpose:
      - "Aucun"

  # ── 5. Preuves attendues en restitution ─────────────────────────────────
  evidence_required:
    - check_linkage
    - run_all_gates
    - bundle

  # ── 6. Modeles autorises ──────────────────────────────────────────────────
  models_allowed:
    - "omni/cc/claude-sonnet-5"
    - "omni/cx/gpt-5.6-terra"

  # ── 7. Devoir d'alerte ────────────────────────────────────────────────────
  alert_duty: >
    Tout problème constaté en cours de route (incohérence de spec, effet de bord,
    risque hors scope) est remonté IMMÉDIATEMENT à l'orchestrateur.

# ═══════════════════════════════════════════════════════════════════════════
# 🚦 SUIVI DE L'ETAT D'AVANCEMENT
# ═══════════════════════════════════════════════════════════════════════════
status: IN_PROGRESS

execution:
  executed_by: "..."
  completed_at: "..."
  status: PENDING
  summary: >
    En attente d'implémentation.
  evidence_submitted: []

validation:
  status: PENDING
  validated_by: "..."
  validated_at: "..."
  notes: >
    GO utilisateur (2026-09-01) : propager les renames GVL_Troubleshooting (préfixe numérique).
