(* =======================================================================
   ST_LocalIHM_StatusBlock — Bloc cyclique d'états IHM locaux
   -----------------------------------------------------------------------
   📄 Frontière : GVL_IHM.LocalIHM.StatusBlock
   🎯 Rôle : réserver 5 WORD et 5 INT PLC→IHM pour l'échange local continu.
   ======================================================================= *)
TYPE ST_LocalIHM_StatusBlock :
STRUCT
    StatusWord01 : WORD; // PLC→IHM : registre WORD local 01
    StatusWord02 : WORD; // PLC→IHM : registre WORD local 02
    StatusWord03 : WORD; // PLC→IHM : registre WORD local 03
    StatusWord04 : WORD; // PLC→IHM : registre WORD local 04
    StatusWord05 : WORD; // PLC→IHM : registre WORD local 05
    StatusInt01  : INT;  // PLC→IHM : registre INT local 01
    StatusInt02  : INT;  // PLC→IHM : registre INT local 02
    StatusInt03  : INT;  // PLC→IHM : registre INT local 03
    StatusInt04  : INT;  // PLC→IHM : registre INT local 04
    StatusInt05  : INT;  // PLC→IHM : registre INT local 05
END_STRUCT
END_TYPE
