# ═══════════════════════════════════════════════════════════════════════════
# CONTRAT DE TACHE — Phase 1.C : Défaut Meca au-dessus de la butée logicielle
# ═══════════════════════════════════════════════════════════════════════════

contract:
  task_id: PHASE1C-DEFAUT-MECA-BUTEE
  criticality: C1
  strategy: patch

  # ── 1. Objectif metier ────────────────────────────────────────────────────
  objective: >
    Corriger l'incohérence : la référence de homing (8,5 m, capteur physique)
    est au-dessus de la butée logicielle d'exploitation (7,5 m). Après homing,
    CablePosM >= TopLimitM → machine « en défaut » même sans mouvement (test
    purement positionnel, FB_Safety_Winch:473). À trancher : aligner la limite
    ou gater le déclenchement par le mouvement.

  # ── 2. DECISION A TRANCHER (humain) ───────────────────────────────────────
  decision_required:
    - Option 1 : Relever CfgCableLimitAscent_M à 8,5 m (aligner sur homing) — ⚠️ supprime la marge de 1 m sous le capteur
    - Option 2 : Gater MecaD (et idéalement la butée) par le mouvement (MeasuredSpeedMps > seuil OU MovementCommanded)
    - Option 3 : Workflow post-homing (guider l'opérateur à redescendre sous 7,5 m)
    - Option 4 : Combinaison des options

  # ── 3. Criteres testables (une fois la décision prise) ────────────────────
  acceptance:
    - id: AC1
      statement: "Au-dessus de la butée, sans mouvement, la machine n'est PAS perçue « en défaut »."
      verified_by: "Lecture code + test CI"
    - id: AC2
      statement: "Le déclenchement MecaD exige un mouvement (si Option 2 retenue)."
      verified_by: "Lecture code FB_Safety_Winch.st"
    - id: AC3
      statement: "Aucune régression : G200 PASS, bundle frais."
      verified_by: "G200_check_linkage.py + generate_codesys_bundle.py"

  # ── 4. Perimetre ──────────────────────────────────────────────────────────
  scope:
    allowed:
      - CODE/H_TREUILS_BENNE/FB_Safety_Winch.st   # si gater MecaD par mouvement
      - CODE/GVL_PERSISTENT.st                     # si relever la limite
      - CODE/M_MAIN/PRG_04_Treuils_Benne.st       # TopLimitM1_M/M2_M
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export

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

# 🚦 SUIVI — BLOQUÉ SUR DÉCISION HUMAINE (choix d'option)
status: BLOQUE_DECISION

execution:
  executed_by: "..."
  completed_at: "..."
  status: PENDING
  summary: >
    Diagnostic fait (agent 4284d143). Attente décision utilisateur sur l'option de correction.
  evidence_submitted: []

validation:
  status: PENDING
  validated_by: "..."
  validated_at: "..."
  notes: >
    BLOCKÉE sur la décision : aligner la limite à 8,5 m / gater MecaD par le mouvement / workflow post-homing.
