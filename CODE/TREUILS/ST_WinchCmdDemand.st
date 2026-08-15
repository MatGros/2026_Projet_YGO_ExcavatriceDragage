(* ═══════════════════════════════════════════════════════════════
   🎮 ST_WinchCmdDemand — Demande de commande treuil (depuis cycle/sequenceur)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.1.md
            DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md
   🎯 Demande de mouvement pour treuil M1 ou M2 (depuis FB_Cycle).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_WinchCmdDemand :
STRUCT
    StartStop   : BOOL;    (* TRUE = rampe accélération, FALSE = rampe décélération *)
    Direction   : INT;     (* -1 = Descente, 0 = Arrêt, +1 = Montée *)
    SpeedPct    : REAL;    // Consigne vitesse % (0.0 .. 100.0)
END_STRUCT
END_TYPE