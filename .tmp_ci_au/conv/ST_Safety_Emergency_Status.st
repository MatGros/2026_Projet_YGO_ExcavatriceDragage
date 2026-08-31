(* =======================================================================
   📊 ST_Safety_Emergency_Status — État & diagnostic de la chaîne AU
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : DUT d'état/diagnostic du FB_Safety_EmergencyManagement fusionné.
      Regroupe les états publics IEC (Ready/Busy/Done), le bus d'état (State),
      le bus de diagnostic (Diag), le défaut laté (Fault : ST_Fault, socle
      FB_FaultCore) et le message opérateur par état / par problème.
   🔒 Sécurité : interlock TOUJOURS sur la cause brute (State/Diag), jamais sur le latch.
      Fail-safe : Enable=FALSE → Ready/Busy à FALSE.
   🔌 Interface : Produit par FB_Safety_EmergencyManagement.Status, consommé par
      PRG_07_Supervision / IHM / Troubleshooting.
   📄 Doc métier : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md
   ======================================================================= *)

TYPE ST_Safety_Emergency_Status :
STRUCT
    // === ETATS PUBLICS IEC ===
    Ready           : BOOL; // <-- [STAT] FB pret a fonctionner (Enable + pas de StartupFail)
    Busy            : BOOL; // <-- [STAT] Sequence ou lockout en cours
    Done            : BOOL; // <-- [STAT] Contacteur puissance confirme engage

    // === BUS D'ETAT & DIAGNOSTIC ===
    State           : ST_Safety_Emergency_State; // <-- [STAT] Bus d'etat public
    Diag            : ST_Safety_Emergency_Diag;  // <-- [DIAG] Bus de diagnostic public

    // === DEFAUT LATCHE (socle FB_FaultCore) ===
    Fault           : ST_Fault; // <-- [DIAG] Brique defaut (vue live + latchee), corrige le bug bit3 StartupFail

    // === MESSAGE OPERATEUR PAR ETAT / PAR PROBLEME ===
    OperatorMessage : STRING(120); // <-- [DIAG] Message explicite par etat / par probleme de la chaine AU
END_STRUCT
END_TYPE
