(* ═══════════════════════════════════════════════════════════════
   🎚️ E_Mode — Modes de marche de la machine
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie5_Modes_Maintenance_v1.1.md §1
   🧩 Fondation manquante requise par le contrat FB (Partie3 §1) :
      tout FB métier expose une entrée Mode : E_Mode.
   ═══════════════════════════════════════════════════════════════ *)

TYPE E_Mode :
ENUM
    MANUEL      := 0,   (* Pilotage joystick direct, sécurités actives *)
    MAINT_N1    := 1,   (* Manuel "encadré" : ~cycle avec interdictions, sécurité correcte *)
    MAINT_N2    := 2,   (* Droits étendus, mot de passe, override de sécurités *)
    SEMI_AUTO   := 3    (* Séquenceur FB_Cycle (semi-automatique) *)
END_ENUM
END_TYPE
