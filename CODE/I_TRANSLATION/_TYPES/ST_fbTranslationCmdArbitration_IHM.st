(* ═══════════════════════════════════════════════════════════════
   🎛️ ST_fbTranslationCmdArbitration_IHM — Entrées IHM de l'arbitrage M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les commandes IHM consommées par FB_TranslationCommandArbitration
       (boutons, sélecteur positionnement, consigne fréquence).
       Le toggle joystick maître global (Modes.Cmd.TglJoystickMaster) est passé en
       paramètre séparé du FB (I4 — factorisation, source unique GVL_IHM.Modes.Cmd).
   📤 Producteur : PRG_05_Translation (câblage GVL_IHM).
   📄 Doc : DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_fbTranslationCmdArbitration_IHM :
STRUCT
    BtnFwd            : BOOL;  // --> [CMD] Bouton translation avant (TranslationM3.Cmd.BtnFwd)
    BtnRev            : BOOL;  // --> [CMD] Bouton translation arrière (TranslationM3.Cmd.BtnRev)
    SelPositioning    : BOOL;  // --> [CMD] Sélecteur positionnement (TranslationM3.Cmd.SelPositioning)
    SetFreq_Hz        : REAL;  // --> [CMD] Consigne fréquence (TranslationM3.Cmd.SetFreq_Hz)
    BypassGlobal      : BOOL;  // --> [TST] Bypass global translation (TranslationM3.Bypass.Global)
END_STRUCT
END_TYPE
