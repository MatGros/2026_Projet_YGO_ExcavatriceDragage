(* ═══════════════════════════════════════════════════════════════
   🎛️ ST_fbWinchCmdArbitration_IHM — Entrées IHM de l'arbitrage treuil
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les commandes IHM consommées par FB_WinchCommandArbitrationM1/M2
       (boutons par treuil, nommage hardware propagé).
       Le toggle joystick maître global (Modes.Cmd.TglJoystickMaster) est passé en
       paramètre séparé des FB (I4 — factorisation, source unique GVL_IHM.Modes.Cmd).
   📤 Producteur : PRG_04_Treuils_Benne (câblage GVL_IHM).
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Nommage : BtnAscentM1/BtnAscentM2 = nommage hardware propagé (convention projet).
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_fbWinchCmdArbitration_IHM :
STRUCT
    BtnAscentM1           : BOOL;  // --> [CMD] Bouton montée treuil M1 (nommage hardware)
    BtnDescentM1         : BOOL;  // --> [CMD] Bouton descente treuil M1
    BtnAscentM2           : BOOL;  // --> [CMD] Bouton montée treuil M2
    BtnDescentM2         : BOOL;  // --> [CMD] Bouton descente treuil M2
    BtnWinchBothAscent    : BOOL;  // --> [CMD] Bouton montée couplée both (Commun)
    BtnWinchBothDescent  : BOOL;  // --> [CMD] Bouton descente couplée both (Commun)
END_STRUCT
END_TYPE
