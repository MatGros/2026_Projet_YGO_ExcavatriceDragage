(* ═══════════════════════════════════════════════════════════════
   📡 ST_DeviceDiag — Structure diagnostic d'un esclave ou bus
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_DeviceDiag :
STRUCT
    Online         : BOOL;        (* Esclave visible sur le bus *)
    Operational    : BOOL;        (* Esclave en mode OP (opérationnel) *)
    Error          : BOOL;        (* Signal de défaut actif pour cet esclave *)
    ErrorId        : WORD;        (* Code défaut détaillé *)
    State          : E_DiagState; (* Phase courante du cycle de diagnostic *)
    StateAtError   : E_DiagState; (* Instantané de la phase lors de l'anomalie *)
END_STRUCT
END_TYPE
