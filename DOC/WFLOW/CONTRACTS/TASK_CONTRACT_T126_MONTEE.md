# ═══════════════════════════════════════════════════════════════════════════
# CONTRAT DE TACHE — Message « Montée interdite » avec cause (extension T126)
# ═══════════════════════════════════════════════════════════════════════════

contract:
  # ── Identification ────────────────────────────────────────────────────────
  task_id: T126-MONTEE
  criticality: C3            # amélioration IHM, non bloquante sécurité
  strategy: patch

  # ── 1. Objectif metier ────────────────────────────────────────────────────
  objective: >
    Remplacer le message IHM générique « [TREUIL] Montée interdite » par un
    message qui précise la CAUSE du blocage de montée (limite haute / capteur
    haut / treuil M2), en dérivant la cause des sorties déjà exposées par les
    FB safety (producteurs uniques), conformément au design T126.

  # ── 2. Criteres testables ─────────────────────────────────────────────────
  acceptance:
    - id: AC1
      statement: "Quand la montée est bloquée par la butée logicielle haute (TopLimitReached=TRUE), le message affiche la cause « limite haute » au lieu du générique."
      verified_by: "Lecture code FB_Hmi_BannerFormatter.st + test CI ad hoc si possible"
    - id: AC2
      statement: "Quand la montée est bloquée par le capteur haut (fin de course), le message affiche la cause « capteur haut »."
      verified_by: "Lecture code + variable de cause disponible"
    - id: AC3
      statement: "Quand la montée est bloquée par le treuil M2 (M1.AscentPermit=TRUE, M2.AscentPermit=FALSE), le message le précise."
      verified_by: "Lecture code"
    - id: AC4
      statement: "Le message générique « Montée interdite » reste le fallback si aucune cause spécifique n'est identifiée."
      verified_by: "Lecture code"
    - id: AC5
      statement: "Aucune cause n'est recalculée dans le formateur : le formateur affiche uniquement des causes déjà exposées par les FB safety (1 FB = 1 responsabilité)."
      verified_by: "Revue code (R6 cohérence AF)"

  # ── 3. Perimetre ──────────────────────────────────────────────────────────
  scope:
    allowed:
      - CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
      - CODE/H_TREUILS_BENNE/FB_Safety_Winch.st   # ne pas toucher la logique safety
      - CODE/M_MAIN/PRG_07_Supervision.st          # ne pas toucher l'agrégation AscentPermit

  # ── 4. Contrat de conservation ────────────────────────────────────────────
  conservation:
    must_survive:
      - "Priorité des messages (AbortMsg > PowerCutOff > SafeStop > DirectionBlocked) inchangée"
      - "Le message « Descente interdite » (sens négatif) inchangé"
      - "Le fallback générique « Montée interdite » conservé"
    dropped_on_purpose:
      - "Aucun"

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
    Tout problème constaté en cours de route (cause non disponible en entrée du
    formateur, conflit de priorité, risque hors scope) est remonté IMMÉDIATEMENT
    à l'orchestrateur, pas à la fin et jamais silencieusement.

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
    GO utilisateur reçu (2026-08-31) pour implémenter le message détaillé.
