(* =======================================================================
   🧭 ST_MachineHoming — Etat publie du homing conjoint machine (M1/M2/benne)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupe les 8 sorties homing a plat de PRG_02_Acquisition en
             un bus struct unique, publie sur le bus inter-PRG.
   🔒 Sécurité : Homed = qualification conjointe reference machine (gate SEMI_AUTO).
                 HomingLoss = perte reference en mouvement : arret controle SafeStop.
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
   ======================================================================= *)
TYPE ST_MachineHoming :
STRUCT
    Homed            : BOOL;          (* Qualification conjointe reference machine *)
    SetPosBucketOpen : BOOL;          (* Valider position actuelle = reference benne ouverte *)
    SetPosBucketClose: BOOL;          (* Valider position actuelle = reference benne fermee *)
    Active           : BOOL;          (* Homing conjoint en cours *)
    HomingLoss       : BOOL;          (* Perte reference en mouvement : arret controle SafeStop *)
    Step             : INT;           (* Etape guidee reference *)
    Instruction      : STRING(120);   (* Consigne IHM reference *)
    Failed           : BOOL;          (* Transaction reference abandonnee *)
END_STRUCT
END_TYPE
