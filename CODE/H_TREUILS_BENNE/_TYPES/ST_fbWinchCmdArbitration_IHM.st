(* ═══════════════════════════════════════════════════════════════
   🎛️ ST_fbWinchCmdArbitration_IHM — Entrées IHM de l'arbitrage treuil
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les commandes IHM consommées par FB_WinchCommandArbitrationM1/M2
       (boutons par treuil, nommage hardware propagé, toggle joystick maître).
   📤 Producteur : PRG_04_Treuils_Benne (câblage GVL_IHM).
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Nommage : BtnUpM1/BtnUpM2 = nommage hardware propagé (convention projet).
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_fbWinchCmdArbitration_IHM :
STRUCT
    TglJoystickMaster : BOOL;  // --> [CMD] Toggle joystick maître global (Modes.Cmd)
    BtnUpM1           : BOOL;  // --> [CMD] Bouton montée treuil M1 (nommage hardware)
    BtnDownM1         : BOOL;  // --> [CMD] Bouton descente treuil M1
    BtnUpM2           : BOOL;  // --> [CMD] Bouton montée treuil M2
    BtnDownM2         : BOOL;  // --> [CMD] Bouton descente treuil M2
    BtnWinchBothUp    : BOOL;  // --> [CMD] Bouton montée couplée both (Commun)
    BtnWinchBothDown  : BOOL;  // --> [CMD] Bouton descente couplée both (Commun)
END_STRUCT
END_TYPE
