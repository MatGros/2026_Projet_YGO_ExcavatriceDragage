(* ═══════════════════════════════════════════════════════════════
   🏗️ ST_HardwareImage — Structure globale d'image matérielle (Frontière HwIn)
   ───────────────────────────────────────────────────────────────
   📄 Lot L5 (Frontière unique HwIn)
   🎨 Agrège les 4 sous-domaines matériels : Winch, Translation, Operator, Machine.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_HardwareImage :
STRUCT
    Winch       : ST_HwWinch;       (* Entrées brutes domaine Treuils M1/M2 + codeurs *)
    Translation : ST_HwTranslation; (* Entrées brutes domaine Translation M3 + variateur *)
    Operator    : ST_HwOperator;    (* Entrées brutes domaine Opérateur / Joystick / bus CAN *)
    Machine     : ST_HwMachine;     (* Entrées brutes domaine Sécurités/Communs Machine *)
END_STRUCT
END_TYPE
