(* ═══════════════════════════════════════════════════════════════
   🖥️ ST_HmiBanner — Bandeau d'information et messages opérateur
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-07_Interface_IHM_v2.0.md §4
   🎯 Responsabilité : regroupe les 4 champs de guidage et contexte
      IHM à responsabilités disjointes (Macro, Micro, Dérogations, Action).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_HmiBanner :
STRUCT
    GlobalContextText    : STRING(80);  (* 1. Macro : [RÉEL/SIMU] [MODE] [COUPLAGE] *)
    SequenceProgressText : STRING(120); (* 2. Micro : Cycle Maître > Sous-cycle / Étape active *)
    SpecialConditionText : STRING(120); (* 3. Dérogations : Bypass, bridages, butées inactives *)
    OperatorActionText   : STRING(120); (* 4. Action attendue : [ORGANE] Action physique > Fin *)
END_STRUCT
END_TYPE
