(* =======================================================================
   ST_LocalIHM_CtrlBlock — Bloc cyclique de commandes IHM locales
   -----------------------------------------------------------------------
   📄 Frontière : GVL_IHM.LocalIHM.CtrlBlock
   🎯 Rôle : réserver 5 WORD et 5 INT IHM→PLC pour l'échange local continu.
   ======================================================================= *)
TYPE ST_LocalIHM_CtrlBlock :
STRUCT
    CtrlWord01 : WORD; // IHM→PLC : registre WORD local 01
    CtrlWord02 : WORD; // IHM→PLC : registre WORD local 02
    CtrlWord03 : WORD; // IHM→PLC : registre WORD local 03
    CtrlWord04 : WORD; // IHM→PLC : registre WORD local 04
    CtrlWord05 : WORD; // IHM→PLC : registre WORD local 05
    CtrlInt01  : INT;  // IHM→PLC : registre INT local 01
    CtrlInt02  : INT;  // IHM→PLC : registre INT local 02
    CtrlInt03  : INT;  // IHM→PLC : registre INT local 03
    CtrlInt04  : INT;  // IHM→PLC : registre INT local 04
    CtrlInt05  : INT;  // IHM→PLC : registre INT local 05
END_STRUCT
END_TYPE
