# ═══════════════════════════════════════════════════════════════════════════
# CONTRAT DE TACHE — Ordre de relâchement contacteurs (vitesse avant direction)
# ═══════════════════════════════════════════════════════════════════════════

contract:
  # ── Identification ────────────────────────────────────────────────────────
  task_id: C2-ORDRE-RELACHEMENT
  criticality: C1            # sécurité moteur (ordre de relâchement contacteurs)
  strategy: patch

  # ── 1. Objectif metier ────────────────────────────────────────────────────
  objective: >
    Ajouter l'ordre de relâchement des contacteurs dans FB_WinchOutputInterlock :
    quand le mouvement s'arrête (SafeStop ou relâchement joystick), relâcher les
    contacteurs de VITESSE (Contactor1-4) AVANT le contacteur de DIRECTION
    (RelayFwd/Rev), avec un décalage minimum de 100ms. Protège le moteur.

  # ── 2. Criteres testables ─────────────────────────────────────────────────
  acceptance:
    - id: AC1
      statement: "Quand le mouvement s'arrête, les contacteurs de vitesse (Contactor1-4) sont relâchés avant le contacteur de direction (RelayFwd/Rev)."
      verified_by: "Lecture code FB_WinchOutputInterlock.st"
    - id: AC2
      statement: "Le décalage entre le relâchement vitesse et direction est >= 100ms."
      verified_by: "Lecture code"
    - id: AC3
      statement: "Le comportement nominal (mouvement en cours) est inchangé."
      verified_by: "Lecture code"
    - id: AC4
      statement: "Aucune régression : G200 PASS, bundle frais."
      verified_by: "G200_check_linkage.py + generate_codesys_bundle.py"

  # ── 3. Perimetre ──────────────────────────────────────────────────────────
  scope:
    allowed:
      - CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
      - CODE/H_TREUILS_BENNE/FB_Safety_Winch.st   # logique safety réelle NON touchée

  # ── 4. Contrat de conservation ────────────────────────────────────────────
  conservation:
    must_survive:
      - "Le comportement nominal (mouvement en cours, contacteurs engagés)"
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
    GO utilisateur (2026-09-01) : ajouter l'ordre de relâchement (vitesse avant direction, 100ms).
