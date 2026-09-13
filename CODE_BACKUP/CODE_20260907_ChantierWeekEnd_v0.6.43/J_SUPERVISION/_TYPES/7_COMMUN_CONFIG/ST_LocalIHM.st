(* =======================================================================
   ST_LocalIHM — Échange cyclique IHM local
   -----------------------------------------------------------------------
   📄 Frontière : GVL_IHM.LocalIHM
   🎯 Rôle : regrouper les blocs de commandes et d'états de l'IHM locale.
   ======================================================================= *)
TYPE ST_LocalIHM :
STRUCT
    CtrlBlock   : ST_LocalIHM_CtrlBlock;   // IHM→PLC : commandes cycliques locales
    StatusBlock : ST_LocalIHM_StatusBlock; // PLC→IHM : états cycliques locaux
END_STRUCT
END_TYPE
