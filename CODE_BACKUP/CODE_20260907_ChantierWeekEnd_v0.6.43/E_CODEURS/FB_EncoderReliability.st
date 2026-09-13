(* =======================================================================
   🛡️ FB_EncoderReliability — Gates de fiabilite de la chaine codeur
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Synthetise les gates de fiabilite d'un treuil a partir des
      faits produits par la chaine codeur (Abs/Homing/Safety), pur calcul
      combinatoire, sans memoire ni machine d'etat.
   🔒 Polarité :
      EncoderFault     = NOT EncoderAvailable OR EncoderIncoherent   (gate GENERAL, SANS Homed)
      HomedAndReliable = EncoderAvailable AND Homed AND NOT EncoderIncoherent (gate STRICT M3)
   🧩 Responsabilite scindee (D-A2bis) : Homing = referencement, Safety = coherence,
      ce FB = « le codeur est fiable ». Aucune recomposition chez les consommateurs.
   📄 Doc : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_EncoderReliability
VAR_INPUT
    // === FAITS DE LA CHAINE CODEUR ===
    EncoderAvailable  : BOOL;        // --> [HW]  Codeur operationnel sur bus (FB_Encoder_Abs)
    Homed             : BOOL;        // --> [STAT] Codeur reference (FB_Encoder_Homing)
    EncoderIncoherent : BOOL;        // --> [SAFE] Incoherence ou hors bornes (FB_Encoder_Safety)
END_VAR
VAR_OUTPUT
    // === GATES DE FIABILITE ===
    EncoderFault      : BOOL;        // <-- [SAFE] Gate general fiabilite (SANS Homed) — vitesse/mouvements
    HomedAndReliable  : BOOL;        // <-- [STAT] Gate strict M3 : disponible ET reference ET pas incoherent
END_VAR

// 🛡️ 1. GATE GENERAL (D-A11, C1) — PAS de Homed : non-reference ≠ incoherent.
//    Ce gate sert a la fiabilite de la mesure (vitesse, mouvements, PositionsValid).
EncoderFault := (NOT EncoderAvailable) OR EncoderIncoherent;

// 🎯 2. GATE STRICT — reserve a l'interlock hauteur M3 (C1) : on ne translate pas
//    si la hauteur est inconnue (jamais home) ou douteuse.
HomedAndReliable := EncoderAvailable AND Homed AND (NOT EncoderIncoherent);
