(* ═══════════════════════════════════════════════════════════════
   🖥️ ST_HmiBanner — Bandeau d'information et messages opérateur
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-07_Interface_IHM_v2.3.md §4, §4bis
   🎯 Responsabilité : regroupe les 4 champs de guidage et contexte, plus
      un état position M3 dédié, à responsabilités disjointes.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_HmiBanner :
STRUCT
    GlobalContextText    : STRING(80);  (* 1. Macro : [RÉEL/SIMU] [MODE] [COUPLAGE] *)
    SequenceProgressText : STRING(120); (* 2. Micro : Cycle Maître > Sous-cycle / Étape active *)
    SpecialConditionText : STRING(120); (* 3. Dérogations : Bypass, bridages, butées inactives *)
    OperatorActionText   : STRING(120); (* 4. Action attendue : [ORGANE] Action physique > Fin *)
    PositionM3Text       : STRING(120); (* 5. État stable M3 : position utilisateur, hors priorités bandeau *)
    AlarmBanner          : ST_AlarmBanner; (* 🚨 Défauts actifs en carrousel (index n/N) *)
END_STRUCT
END_TYPE
