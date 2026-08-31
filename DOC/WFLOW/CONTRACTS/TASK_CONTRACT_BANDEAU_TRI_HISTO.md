# ═══════════════════════════════════════════════════════════════════════════
# CONTRAT DE TACHE — Bandeau IHM : tri carrousel + marqueur [HISTO]
# ═══════════════════════════════════════════════════════════════════════════

contract:
  # ── Identification ────────────────────────────────────────────────────────
  task_id: BANDEAU-TRI-HISTO
  criticality: C2            # touche les DUT safety (M1/M2/M3)
  strategy: patch

  # ── 1. Objectif metier ────────────────────────────────────────────────────
  objective: >
    (1) Trier le carrousel d'alarmes pour ne publier que les défauts actifs
    BLOQUANTS (SafeStop/PowerCutOff/interlock), pas les warnings non bloquants.
    (2) Ajouter le marqueur [HISTO] pour les défauts latched passés (LatchedId
    AND NOT ErrorId), en exposant la vue latched M1/M2/M3 dans les DUT safety.

  # ── 2. Criteres testables ─────────────────────────────────────────────────
  acceptance:
    - id: AC1
      statement: "Le carrousel AlarmBanner ne publie que les défauts actifs bloquants (SafeStop/PowerCutOff/interlock), pas les warnings non bloquants (ex. mou de câble, surchauffe)."
      verified_by: "Lecture code FB_Hmi_BannerFormatter.st §5"
    - id: AC2
      statement: "Les DUT ST_SafetyWinch et ST_SafetyTranslation exposent une vue latched (LatchedId)."
      verified_by: "Lecture ST_SafetyWinch.st / ST_SafetyTranslation.st"
    - id: AC3
      statement: "Le marqueur [HISTO] est affiché pour un défaut latched passé (LatchedId AND NOT ErrorId) sur M1/M2/M3."
      verified_by: "Lecture code FB_Hmi_BannerFormatter.st + FB_WinchStateProjection.st"
    - id: AC4
      statement: "Les messages d'alarme contiennent le code ErrorID (ex. ErrorID:08)."
      verified_by: "Lecture code FB_Hmi_BannerFormatter.st"
    - id: AC5
      statement: "Aucune régression : les défauts critiques restent dans OperatorActionText (champ fixe), G200 PASS, bundle frais."
      verified_by: "G200_check_linkage.py + generate_codesys_bundle.py"
    - id: AC6
      statement: "La documentation AF-07 reflète le tri du carrousel et le marqueur [HISTO]."
      verified_by: "Lecture AF_Partie-07"

  # ── 3. Perimetre ──────────────────────────────────────────────────────────
  scope:
    allowed:
      - CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st
      - CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_SafetyWinch.st
      - CODE/J_SUPERVISION/_TYPES/2_TRANSLATION/ST_SafetyTranslation.st
      - CODE/H_TREUILS_BENNE/FB_WinchStateProjection.st
      - CODE/M_MAIN/PRG_05_Translation.st   # si câblage LatchedId M3
      - CODE/M_MAIN/PRG_07_Supervision.st   # si câblage entrées formateur
      - DOC/AF/AF_Partie-07_Interface_IHM_v2.3.md
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
      - CODE/H_TREUILS_BENNE/FB_Safety_Winch.st   # logique safety réelle NON touchée
      - CODE/I_TRANSLATION/FB_Safety_Translation.st

  # ── 4. Contrat de conservation ────────────────────────────────────────────
  conservation:
    must_survive:
      - "Les défauts critiques restent dans OperatorActionText (champ fixe, ForceInstant)"
      - "La logique safety réelle (FB_Safety_Winch / FB_Safety_Translation) inchangée"
      - "Le carrousel continue d'afficher les défauts bloquants avec préfixe n/N"
    dropped_on_purpose:
      - "Les warnings non bloquants ne sont plus dans le carrousel (tri)"

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
    En attente d'implémentation.
  evidence_submitted: []

validation:
  status: PENDING
  validated_by: "..."
  validated_at: "..."
  notes: >
    GO utilisateur (2026-09-01) : trier le carrousel + implémenter [HISTO] (modifier DUT safety).
