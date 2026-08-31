# ═══════════════════════════════════════════════════════════════════════════
# CONTRAT DE TACHE — C1 : AnyFaultActive exhaustif (défauts bloquants machine)
# ═══════════════════════════════════════════════════════════════════════════

contract:
  # ── Identification ────────────────────────────────────────────────────────
  task_id: C1-ANYFAULTACTIVE-EXHAUSTIF
  criticality: C1            # obligation sécurité (indicateur de défaut global)
  strategy: patch

  # ── 1. Objectif metier ────────────────────────────────────────────────────
  objective: >
    Rendre GVL_IHM.Modes.State.AnyFaultActive exhaustif : il doit valoir 1 si
    un défaut bloquant est actif sur la machine (y compris les défauts de
    sécurité treuil : SafeStop, MecaE, etc.). Actuellement, AnyFaultActive
    (PRG_07:424-427) est un agrégat étroit qui ne compte pas les défauts treuil,
    d'où le paradoxe « message Acquitter SafeStop » mais AnyFaultActive=0.

  # ── 2. Criteres testables ─────────────────────────────────────────────────
  acceptance:
    - id: AC1
      statement: "AnyFaultActive = 1 si un défaut bloquant est actif sur la machine (y compris SafeStop/MecaE treuil)."
      verified_by: "Lecture code PRG_07_Supervision.st"
    - id: AC2
      statement: "AnyFaultActive inclut les défauts de sécurité treuil M1/M2 (FB_Safety_Winch.Fault.Error/Latched), synchro, benne, translation M3."
      verified_by: "Lecture code"
    - id: AC3
      statement: "Le périmètre d'AnyFaultActive est aligné sur l'intention documentée (ST_ModesState:7-10 : OR de tous les .Error du domaine, même périmètre que BtnFaultReset)."
      verified_by: "Lecture code + ST_ModesState"
    - id: AC4
      statement: "Aucune régression : G200 PASS, bundle frais."
      verified_by: "G200_check_linkage.py + generate_codesys_bundle.py"

  # ── 3. Perimetre ──────────────────────────────────────────────────────────
  scope:
    allowed:
      - CODE/M_MAIN/PRG_07_Supervision.st
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
      - CODE/H_TREUILS_BENNE/FB_Safety_Winch.st   # logique safety réelle NON touchée

  # ── 4. Contrat de conservation ────────────────────────────────────────────
  conservation:
    must_survive:
      - "Les sources existantes d'AnyFaultActive (AU, modules E/S, arbitrage de mode)"
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
    GO utilisateur (2026-09-01) : AnyFaultActive doit être = 1 si un défaut bloquant est actif (obligation).
