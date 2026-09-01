# ═══════════════════════════════════════════════════════════════════════════
# CONTRAT DE TACHE — Corriger préfixe GVL_Troubleshooting (chiffre → lettre E)
# ═══════════════════════════════════════════════════════════════════════════

contract:
  # ── Identification ────────────────────────────────────────────────────────
  task_id: FIX-PREFIXE-GVL-TROUBLESHOOTING
  criticality: C1            # erreur de compilation (identifiants invalides IEC 61131-3)
  strategy: patch

  # ── 1. Objectif metier ────────────────────────────────────────────────────
  objective: >
    Corriger les identifiants GVL_Troubleshooting qui commencent par un chiffre
    (00_ContexteMachineGlobal, etc.) — invalides en CEI 61131-3 (un nom de
    variable ne peut pas commencer par un chiffre). Préfixer par une lettre
    (E00_ContexteMachineGlobal, etc.) et propager dans toutes les références.

  # ── 2. Criteres testables ─────────────────────────────────────────────────
  acceptance:
    - id: AC1
      statement: "Les identifiants GVL_Troubleshooting commencent par une lettre (E00_..E18_), pas par un chiffre."
      verified_by: "Lecture GVL_Troubleshooting.st"
    - id: AC2
      statement: "Toutes les références (FB_TroubleshootingView.st, troubleshooting_variables.txt) sont mises à jour."
      verified_by: "grep des anciens noms (00_..18_) → 0 occurrence"
    - id: AC3
      statement: "Renommage pur : G200 PASS, bundle frais, aucun changement de comportement."
      verified_by: "G200_check_linkage.py + generate_codesys_bundle.py"

  # ── 3. Perimetre ──────────────────────────────────────────────────────────
  scope:
    allowed:
      - CODE/J_SUPERVISION/GVL_Troubleshooting.st
      - CODE/J_SUPERVISION/FB_TroubleshootingView.st
      - TOOLS/PLC_CSV_SNAPSHOT/variable_lists/troubleshooting_variables.txt
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export

  # ── 4. Contrat de conservation ────────────────────────────────────────────
  conservation:
    must_survive:
      - "Le comportement du troubleshooting (aucun changement de logique)"
      - "La structure des variables (IdxXXX) inchangée"
    dropped_on_purpose:
      - "Le préfixe numérique invalide (00_..18_)"

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
    GO utilisateur (2026-09-01) : corriger le préfixe numérique invalide (chiffre → lettre E).
