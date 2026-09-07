(* =======================================================================
   ST_IoHw — Image I/O hardware lecture seule publiée pour l'IHM
   -----------------------------------------------------------------------
   IOHW demandé par l'IHM, identifiants ST conformes PascalCase : IoHw.
   In et Out sont deux images PLC→IHM. Aucun accès IHM n'est utilisé comme
   écriture vers une E/S physique.
   ======================================================================= *)
TYPE ST_IoHw :
STRUCT
    In  : ST_IoHw_In;  // Entrées, états bus et diagnostics hardware
    Out : ST_IoHw_Out; // Sorties produites observées, pas un port de commande
END_STRUCT
END_TYPE
