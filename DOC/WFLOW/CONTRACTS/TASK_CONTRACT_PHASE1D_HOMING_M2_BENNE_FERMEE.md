# ═══════════════════════════════════════════════════════════════════════════
# CONTRAT DE TACHE — Phase 1.D : Homing M2 benne fermée (M2 reste à 8.5m)
# ═══════════════════════════════════════════════════════════════════════════

contract:
  task_id: PHASE1D-HOMING-M2-BENNE-FERMEE
  criticality: C2
  strategy: patch

  # ── 1. Objectif metier ────────────────────────────────────────────────────
  objective: >
    Corriger le bug de homing M2 avec benne FERMÉE : M2 reste à 8,5 m au lieu
    de prendre la cible dynamique (M1 + OffsetCloseM = 25 m). Le test CI a prouvé
    que FB_Encoder_Homing applique correctement la cible dynamique → le bug est
    en AMONT : le caller (PRG_02_Acquisition + FB_MachineHomingCycle) ne fournit
    pas la cible à M2 (UseDynamicTarget / DynamicHomingTargetM non câblés à 25 m).

  # ── 2. Criteres testables ─────────────────────────────────────────────────
  acceptance:
    - id: AC1
      statement: "Lors du homing M2 benne fermée, DynamicHomingTargetM = CfgTopHomingTarget_M + OffsetClose_M (25 m)."
      verified_by: "Test CI + lecture code caller"
    - id: AC2
      statement: "M2 se référence à la cible dynamique (CablePosM = 25 m) après homing benne fermée."
      verified_by: "Test/snapshot"
    - id: AC3
      statement: "Le homing M2 benne OUVERTE reste correct (M2 = M1, offset 0)."
      verified_by: "Test CI"
    - id: AC4
      statement: "Aucune régression : G200 PASS, bundle frais."
      verified_by: "G200_check_linkage.py + generate_codesys_bundle.py"

  # ── 3. Perimetre ──────────────────────────────────────────────────────────
  scope:
    allowed:
      - CODE/M_MAIN/PRG_02_Acquisition.st          # câblage UseDynamicTarget/DynamicHomingTargetM M2
      - CODE/G_CYCLE/FB_MachineHomingCycle.st      # M2Demand.DynamicTarget_M
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export

  # ── 4. Contrat de conservation ────────────────────────────────────────────
  conservation:
    must_survive:
      - "Le homing M1 (référence capteur haut) inchangé"
      - "Le homing M2 benne ouverte inchangé"
      - "La logique FB_Encoder_Homing (déjà correcte) inchangée"
    dropped_on_purpose:
      - "Le câblage fautif du caller (si confirmé)"

  # ── 5. Preuves attendues ──────────────────────────────────────────────────
  evidence_required:
    - check_linkage
    - run_all_gates
    - bundle
    - test_ci

  # ── 6. Modeles autorises ──────────────────────────────────────────────────
  models_allowed:
    - "omni/cc/claude-sonnet-5"
    - "omni/cx/gpt-5.6-terra"

  # ── 7. Devoir d'alerte ────────────────────────────────────────────────────
  alert_duty: >
    Tout problème trouvé en cours de route remonte IMMÉDIATEMENT à l'orchestrateur.

# 🚦 SUIVI — ATTEND INVESTIGATION CÂBLAGE DU CALLER
status: PENDING

execution:
  executed_by: "..."
  completed_at: "..."
  status: PENDING
  summary: >
    Test CI FB_Encoder_Homing PASS (cible dynamique correcte). Bug en amont (caller). Attente investigation câblage.
  evidence_submitted: ["test_ci: FB_Encoder_Homing PASS 3/3"]

validation:
  status: PENDING
  validated_by: "..."
  validated_at: "..."
  notes: >
    Prochaine étape : investiguer le câblage UseDynamicTarget/DynamicHomingTargetM pour M2 dans PRG_02_Acquisition + FB_MachineHomingCycle.
