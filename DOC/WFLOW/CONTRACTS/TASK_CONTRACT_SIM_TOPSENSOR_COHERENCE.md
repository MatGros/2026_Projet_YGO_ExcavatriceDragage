# ═══════════════════════════════════════════════════════════════════════════
# CONTRAT DE TACHE — Capteur TOP en simulation : cohérence avec mou de câble
# ═══════════════════════════════════════════════════════════════════════════

contract:
  # ── Identification ────────────────────────────────────────────────────────
  task_id: SIM-TOPSENSOR-COHERENCE
  criticality: C3
  strategy: patch

  # ── 1. Objectif metier ────────────────────────────────────────────────────
  objective: >
    Rendre le capteur TOP simulé cohérent avec le capteur mou de câble simulé :
    sain (libre) par défaut en simulation, sauf stimulus manuel. Corriger la
    régression introduite par le commit fc8115d9 qui a rendu le capteur TOP
    piloté par la position M1 (bloquant la montée en simu quand le treuil est en haut).

  # ── 2. Criteres testables ─────────────────────────────────────────────────
  acceptance:
    - id: AC1
      statement: "En simulation, le capteur TOP (M1M2_TopPositionFree_DI) est libre (TRUE) par défaut, sans stimulus manuel."
      verified_by: "Lecture code FB_SimBench.st"
    - id: AC2
      statement: "Le capteur TOP simulé ne dépend plus de la position M1 (RawPosM1) — cohérent avec le mou de câble (M2_TensionedCable_DI := TRUE)."
      verified_by: "Lecture code FB_SimBench.st"
    - id: AC3
      statement: "Le stimulus manuel SimTopPositionActive reste disponible pour injecter un fait capteur au banc."
      verified_by: "Lecture code FB_SimBench.st"
    - id: AC4
      statement: "Aucun code mort laissé (TopPositionModelActive / CfgTopSensorRawPos supprimés ou justifiés)."
      verified_by: "Revue code"
    - id: AC5
      statement: "La documentation AF (AF-13 Simulation) reflète le comportement corrigé du capteur TOP simulé."
      verified_by: "Lecture AF-13"
    - id: AC6
      statement: "Aucune dégradation ni effet de bord : bundle + G200 liaison PASS, logique safety réelle (FB_Safety_Winch) non touchée."
      verified_by: "G200_check_linkage.py + run_all_gates.py"

  # ── 3. Perimetre ──────────────────────────────────────────────────────────
  scope:
    allowed:
      - CODE/L_SIMULATION/FB_SimBench.st
      - CODE/M_MAIN/PRG_02_Acquisition.st   # si retrait de CfgTopSensorRawPos
      - DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
      - DOC/AF/AF_Partie-13_Fonction_Simulation/*.md   # sous-fiches si existantes
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
      - CODE/H_TREUILS_BENNE/FB_Safety_Winch.st   # logique safety réelle NON touchée
      - CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st

  # ── 4. Contrat de conservation ────────────────────────────────────────────
  conservation:
    must_survive:
      - "Le stimulus manuel SimTopPositionActive (injection de fait capteur au banc)"
      - "La logique safety réelle (FB_Safety_Winch) inchangée"
      - "Le comportement du mou de câble simulé (M2_TensionedCable_DI := TRUE)"
    dropped_on_purpose:
      - "Le modèle capteur TOP piloté par la position M1 (régression fc8115d9)"

  # ── 5. Preuves attendues en restitution ───────────────────────────────────
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
    En attente d'implémentation (code + doc) et de revue.
  evidence_submitted: []

validation:
  status: PENDING
  validated_by: "..."
  validated_at: "..."
  notes: >
    GO utilisateur reçu (2026-08-31) : 3 agents (code, doc, revue).
