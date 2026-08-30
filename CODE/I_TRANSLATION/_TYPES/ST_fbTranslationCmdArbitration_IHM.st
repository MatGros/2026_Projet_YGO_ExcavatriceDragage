(* ═══════════════════════════════════════════════════════════════
   🎛️ ST_fbTranslationCmdArbitration_IHM — Entrées IHM de l'arbitrage M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les commandes IHM consommées par FB_TranslationCommandArbitration
       (boutons, sélecteur positionnement, consigne fréquence, toggle joystick maître).
   📤 Producteur : PRG_05_Translation (câblage GVL_IHM).
   📄 Doc : DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_fbTranslationCmdArbitration_IHM :
STRUCT
    TglJoystickMaster : BOOL;  // --> [CMD] Toggle joystick maître global (Modes.Cmd)
    BtnFwd            : BOOL;  // --> [CMD] Bouton translation avant (TranslationM3.Cmd.BtnFwd)
    BtnRev            : BOOL;  // --> [CMD] Bouton translation arrière (TranslationM3.Cmd.BtnRev)
    SelPositioning    : BOOL;  // --> [CMD] Sélecteur positionnement (TranslationM3.Cmd.SelPositioning)
    SetFreq_Hz        : REAL;  // --> [CMD] Consigne fréquence (TranslationM3.Cmd.SetFreq_Hz)
    BypassGlobal      : BOOL;  // --> [TST] Bypass global translation (TranslationM3.Bypass.Global)
END_STRUCT
END_TYPE
