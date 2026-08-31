# ═══════════════════════════════════════════════════════════════════════════
# CONTRAT DE TACHE — C2 : ré-enforcer SafeStop à la barrière finale
# ═══════════════════════════════════════════════════════════════════════════

contract:
  # ── Identification ────────────────────────────────────────────────────────
  task_id: C2-SAFESTOP-BARRIERE-FINALE
  criticality: C1            # défense en profondeur (sécurité)
  strategy: patch

  # ── 1. Objectif metier ────────────────────────────────────────────────────
  objective: >
    Ré-enforcer le SafeStop à la barrière finale FB_WinchOutputInterlock.
    Actuellement, l'entrée SafeStop (déclarée l.16) n'est jamais utilisée dans
    la logique : le blocage repose UNIQUEMENT sur FB_Winch (EffectiveSafeStop).
    Si FB_Winch était contourné ou buggé, la barrière finale ne rattraperait pas
    le SafeStop → défense en profondeur manquante.

  # ── 2. Criteres testables ─────────────────────────────────────────────────
  acceptance:
    - id: AC1
      statement: "Quand SafeStop=TRUE, FB_WinchOutputInterlock coupe RelayFwd/RelayRev/contacteurs/frein (barrière finale)."
      verified_by: "Lecture code FB_WinchOutputInterlock.st"
    - id: AC2
      statement: "Le SafeStop est ré-enforcé indépendamment de FB_Winch (défense en profondeur)."
      verified_by: "Lecture code"
    - id: AC3
      statement: "Le comportement nominal (SafeStop=FALSE) est inchangé."
      verified_by: "Lecture code"
    - id: AC4
      statement: "Aucune régression : G200 PASS, bundle frais."
      verified_by: "G200_check_linkage.py + generate_codesys_bundle.py"

  # ── 3. Perimetre ──────────────────────────────────────────────────────────
  scope:
    allowed:
      - CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st
      - CODE/M_MAIN/PRG_06_Outputs.st   # si câblage SafeStop vers l'interlock
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
      - CODE/H_TREUILS_BENNE/FB_Safety_Winch.st   # logique safety réelle NON touchée

  # ── 4. Contrat de conservation ────────────────────────────────────────────
  conservation:
    must_survive:
      - "Le comportement nominal de la barrière finale (SafeStop=FALSE)"
      - "Le watchdog frein, l'anti-redémarrage, le gate mot/fréquence"
      - "La logique safety réelle (FB_Safety_Winch) inchangée"
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
    GO utilisateur (2026-09-01) : résoudre C2 (défense en profondeur SafeStop).
