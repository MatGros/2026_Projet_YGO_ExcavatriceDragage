(* =======================================================================
   📊 ST_Diag_Device — Structure diagnostic d'un esclave ou bus
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de donnees d'état, diagnostic et alarme d'un equipement réseau
   📄 Doc métier : DOC/AF/AF_Partie-12_Fonction_Diagnostic_v1.1.md
   ======================================================================= *)
TYPE ST_Diag_Device :
STRUCT
    Online         : BOOL;        (* Esclave visible sur le bus *)
    Operational    : BOOL;        (* Esclave en mode OP (opérationnel) *)
    Error          : BOOL;        (* Signal de défaut actif pour cet esclave *)
    ErrorId        : WORD;        (* Code défaut détaillé *)
    State          : E_Diag_State; (* Phase courante du cycle de diagnostic *)
    StateAtError   : E_Diag_State; (* Instantané de la phase lors de l'anomalie *)
END_STRUCT
END_TYPE
