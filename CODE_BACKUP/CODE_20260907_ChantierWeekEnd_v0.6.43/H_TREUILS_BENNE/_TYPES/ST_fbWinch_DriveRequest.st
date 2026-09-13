(* =======================================================================
   🪝 ST_fbWinch_Req — Requête d'axe treuil (producteur PRG_04)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Demande de mouvement, palier et bornes de clamp d'un treuil
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   📤 Producteur : PRG_04_Treuils_Benne (une par treuil M1/M2)
   📥 Consommateur : FB_Winch
   🔒 Structs cibles + champs conservés pour garder le décodage %→palier
      et le clamp DANS FB_Winch (comportement bit-identique).
      SpeedStepReq est consommé par FB_Winch (§5) ; MinStepUp est déclaré
      mais non consommé (usage aval).
   ======================================================================= *)
TYPE ST_fbWinch_Req :
STRUCT
    // === ORDRE DE MOUVEMENT ===
    RunRequest                      : BOOL;   // TRUE = mouvement demandé
    ReqAscent                       : BOOL;   // TRUE = demande montée
    ReqDescend                      : BOOL;   // TRUE = demande descente
    SpeedStepReq                    : INT;    // [cible] Palier demandé (1..5, 0 = arrêt) — consommé par FB_Winch

    // === BORNES DE CLAMP (agrégées PRG_04) ===
    MinStepUp                       : INT;    // [cible] Plancher palier montée (usage aval)
    MaxStepUp                       : INT := 5;    // Plafond palier montée (1..5)
    MinStepDown                     : INT := 0;    // Plancher palier descente (0 = aucun) -- plongee Kobold
    MaxStepDown                     : INT := 3;    // Plafond palier descente (1..5)

    // === LIMITES EFFECTIVES DU CYCLE ===
    TopLimitM                       : REAL := 8.5;   // Position limite haute active (m)
    BottomLimitM                    : REAL := -20.0; // Position limite basse active (m)

    // === DIAGNOSTIC (jamais lu par la logique FB_Winch) ===
    SyncCoupled                     : BOOL;   // [diag] Couplage synchro actif (garde de revue)

    // === CHAMPS CONSERVÉS (clamp interne FB_Winch) ===
    HomingApproachActive            : BOOL;   // [08a] Vitesse limitée au palier 1 (approche homing)
END_STRUCT
END_TYPE

