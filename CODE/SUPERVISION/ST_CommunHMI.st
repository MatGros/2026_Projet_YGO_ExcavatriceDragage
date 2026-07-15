(* ═══════════════════════════════════════════════════════════════
   🌐 ST_CommunHMI — Données d'échange IHM COMMUNES (pas propres à un axe)
   ───────────────────────────────────────────────────────────────
   🆕 REX 2026-07-08 (demande utilisateur) : regroupe les signaux qui ne concernent
   PAS un axe/mécanisme en particulier (1 seul capteur/signal partagé par toute la
   machine) — évite de les dupliquer ou de les laisser en variables isolées
   directement dans GVL_IHM. Exemple : TopPositionSensorActive (capteur unique,
   commun M1+M2), BrakeThermalFault (retour unique, commun M1+M2+M3).
   ⚠️ Ne pas y mettre HmiInitDone (indicateur interne de séquencement boot, pas une
   information machine destinée à l'opérateur) — reste seul dans GVL_IHM.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CommunHMI :
STRUCT
    TopPositionSensorActive   : BOOL; (* ⚠️ Capteur de position haute commun M1+M2 détecté *)
    BrakeThermalFault         : BOOL; (* 🌡️ Défaut/perte thermique frein — retour unique commun M1/M2/M3, escalade PowerCutOff *)
    PhaseRotationFault        : BOOL; (* 🆕 REX 2026-07-08 : rotation de phase incorrecte — retour unique commun M1/M2/M3
                                          (auparavant invisible IHM, seulement décodable via SafetyErrorId bit4/bit2) *)
    LimitLegalDepthMinAllowed : REAL; (* 📐 Cote min de dragage autorisée (m, négatif) *)
    LimitLegalEnabled         : BOOL; (* 🟢 Activation de la limite légale *)
    LimitLegalReached         : BOOL; (* 📐 Limite légale de profondeur de dragage atteinte (globale) *)
    HomingApproachEnableRequest    : BOOL; (* 🆕 REX 2026-07-08 (2) : case IHM — autorise (si MAINT_N2) à dépasser
                                          l'arrêt normal haut pour approcher le capteur physique (préparation
                                          homing) — voir FB_Modes.HomingApproachEnable, commun M1/M2 *)
END_STRUCT
END_TYPE
