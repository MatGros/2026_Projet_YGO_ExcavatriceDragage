# ═══════════════════════════════════════════════════════════════════════════
# CONTRAT DE TACHE — Fix latch MecaE ré-armé en boucle (SyncFault piégé)
# ═══════════════════════════════════════════════════════════════════════════

contract:
  # ── Identification ────────────────────────────────────────────────────────
  task_id: FIX-LATCH-MECAE-ENABLE
  criticality: C1            # point de sécurité critique
  strategy: patch

  # ── 1. Objectif metier ────────────────────────────────────────────────────
  objective: >
    Empêcher le latch MecaE (écart synchro) de se ré-armer en boucle quand le
    FB_Safety_Winch est désactivé (Enable=FALSE). Actuellement, SyncEnable est
    forcé à TRUE en mode DISABLE (FB_Modes.st:232) et la cause MecaE est évaluée
    indépendamment de Enable (FB_Safety_Winch.st:197, 318-321) → le latch se
    ré-arme sur le même scan que le reset, piégeant l'opérateur (SyncFault
    persiste, reset inefficace).

  # ── 2. Criteres testables ─────────────────────────────────────────────────
  acceptance:
    - id: AC1
      statement: "Le latch MecaE ne se ré-arme que si Enable=TRUE (FB_Safety_Winch.st:318-321)."
      verified_by: "Lecture code"
    - id: AC2
      statement: "Quand Enable=FALSE, le reset efface le latch MecaE sans ré-armement (l'opérateur sort du piège)."
      verified_by: "Lecture code + test CI ad hoc si possible"
    - id: AC3
      statement: "Le comportement fail-safe est préservé : quand Enable=TRUE et écart>tolérance, le latch se ré-arme toujours."
      verified_by: "Lecture code"
    - id: AC4
      statement: "Aucune régression : G200 PASS, bundle frais, logique safety réelle non dégradée."
      verified_by: "G200_check_linkage.py + generate_codesys_bundle.py"

  # ── 3. Perimetre ──────────────────────────────────────────────────────────
  scope:
    allowed:
      - CODE/H_TREUILS_BENNE/FB_Safety_Winch.st
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
      - CODE/F_MODES/FB_Modes.st   # ne pas toucher la logique de mode (autre décision)

  # ── 4. Contrat de conservation ────────────────────────────────────────────
  conservation:
    must_survive:
      - "Le latch MecaE se ré-arme quand Enable=TRUE et écart>tolérance (sécurité)"
      - "Le reset efface le latch (front ResetEdge)"
      - "Le comportement fail-safe (pas de redémarrage auto après défaut)"
    dropped_on_purpose:
      - "Le ré-armement du latch MecaE quand Enable=FALSE (le bug)"

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
    GO utilisateur (2026-09-01) : implémenter le fix latch MecaE (gater par Enable).
