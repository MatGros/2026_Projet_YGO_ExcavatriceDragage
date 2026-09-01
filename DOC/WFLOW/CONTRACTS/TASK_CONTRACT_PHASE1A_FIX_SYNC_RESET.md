# ═══════════════════════════════════════════════════════════════════════════
# CONTRAT DE TACHE — Phase 1.A : Fix défaut synchro non acquittable
# ═══════════════════════════════════════════════════════════════════════════

contract:
  task_id: PHASE1A-FIX-SYNC-RESET
  criticality: C1            # point sécurité : défaut non acquittable
  strategy: patch

  # ── 1. Objectif metier ────────────────────────────────────────────────────
  objective: >
    Permettre l'acquittement du défaut synchro ([SYNC] ErrorID:01) même hors
    mode sync. Actuellement, Enable de FB_WinchSync est câblé sur SyncEnable ;
    sortir du mode sync → Enable=FALSE → le RETURN (FB_WinchSync.st:80-86) coupe
    l'appel de instFault → le Reset n'atteint jamais le latch → défaut non
    acquittable. Violation du contrat FB_FaultCore.st:11 (reset effectif même
    Enable=FALSE).

  # ── 2. Criteres testables ─────────────────────────────────────────────────
  acceptance:
    - id: AC1
      statement: "Le Reset efface le latch synchro même quand Enable=FALSE (hors mode sync)."
      verified_by: "Test CI ad hoc FB_WinchSync (Enable=FALSE + Reset → Fault.Latched=FALSE)"
    - id: AC2
      statement: "FB_WinchSync appelle instFault (avec Reset) avant le RETURN, conformément à FB_FaultCore.st:11."
      verified_by: "Lecture code FB_WinchSync.st"
    - id: AC3
      statement: "Le comportement nominal (Enable=TRUE, mode sync) est inchangé."
      verified_by: "Lecture code + test CI"
    - id: AC4
      statement: "Aucune régression : G200 PASS, bundle frais."
      verified_by: "G200_check_linkage.py + generate_codesys_bundle.py"

  # ── 3. Perimetre ──────────────────────────────────────────────────────────
  scope:
    allowed:
      - CODE/H_TREUILS_BENNE/FB_WinchSync.st
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
      - CODE/H_TREUILS_BENNE/FB_Safety_Winch.st   # logique safety réelle NON touchée

  # ── 4. Contrat de conservation ────────────────────────────────────────────
  conservation:
    must_survive:
      - "La neutralisation du FB hors sync (Enable=FALSE → pas de calcul)"
      - "La logique safety réelle (FB_Safety_Winch) inchangée"
    dropped_on_purpose:
      - "Le court-circuit du Reset par le RETURN (le bug)"

  # ── 5. Preuves attendues ──────────────────────────────────────────────────
  evidence_required:
    - check_linkage
    - run_all_gates
    - bundle
    - test_ci             # test CI ad hoc FB_WinchSync

  # ── 6. Modeles autorises ──────────────────────────────────────────────────
  models_allowed:
    - "omni/cc/claude-sonnet-5"
    - "omni/cx/gpt-5.6-terra"

  # ── 7. Devoir d'alerte ────────────────────────────────────────────────────
  alert_duty: >
    Tout problème trouvé en cours de route remonte IMMÉDIATEMENT à l'orchestrateur.

# 🚦 SUIVI
status: PENDING           # PENDING → GO utilisateur → IN_PROGRESS (implémentation) → COMPLETED

execution:
  executed_by: "..."
  completed_at: "..."
  status: PENDING
  summary: >
    Contrat préparé. En attente GO utilisateur pour implémentation.
  evidence_submitted: []

validation:
  status: PENDING
  validated_by: "..."
  validated_at: "..."
  notes: >
    Prêt pour implémentation (Phase 1.A). Diagnostic synchro validé (agent 247c6653).
