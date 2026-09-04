(* ═══════════════════════════════════════════════════════════════
   🕹️ ST_AcquisitionJoystickQualified — Données joystick qualifiées
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les commandes d'axes, statut homme-mort et diagnostics
      produits par FB_Joystick dans PRG_02_Acquisition.
   📤 Producteur unique : PRG_02_Acquisition (Data.Joystick).
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_AcquisitionJoystickQualified :
STRUCT
    AxisX               : ST_fbJoystick_AxisCmd; // 📊 Commande et direction qualifiée axe X
    AxisY               : ST_fbJoystick_AxisCmd; // 📊 Commande et direction qualifiée axe Y
    DeadmanArmed        : BOOL;                  // 🔒 Homme-mort armé et valide
    AtNeutralXY         : BOOL;                  // 🟢 Les deux axes X et Y sont au neutre
    ArmingPermitDenied  : BOOL;                  // ⚠️ Tentative d'armement sans permission
    Ready               : BOOL;                  // 🟢 Façade joystick prête et opérationnelle
    Fault               : ST_Fault;              // ❌ Diagnostic défaut joystick
    NeutralXAct         : INT;                   // 📍 Valeur ADC neutre calibré X
    NeutralYAct         : INT;                   // 📍 Valeur ADC neutre calibré Y
END_STRUCT
END_TYPE
