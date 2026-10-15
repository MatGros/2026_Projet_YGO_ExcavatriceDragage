(* =======================================================================
   🧪 Mock FB_Sim_Translation_ExtLink — interface seule, sans socket UDP
   -----------------------------------------------------------------------
   Le FB réel (CODE/L_SIMULATION/FB_Sim_Translation_ExtLink.st) ouvre un socket
   loopback et initialise une structure par littéral : ni l'un ni l'autre ne
   compile sous STruCpp. Les tests FB_SimBench n'activent jamais la source
   externe M3 (SimM3OpenModelicaActive = FALSE) : seule l'interface compte.
   Interface recopiée à l'identique ; Enable=FALSE et TRUE -> lien jamais prêt.
   ======================================================================= *)
FUNCTION_BLOCK FB_Sim_Translation_ExtLink
VAR_INPUT
    Enable                  : BOOL;
    ReqTremie               : BOOL;
    ReqMaintenance          : BOOL;
    SetpointFrequencyHz     : WORD;
    BrakeReleaseCmd         : BOOL;
    PlcEcho                 : ST_fbSim_Translation_ExtLink_Echo;
END_VAR
VAR_OUTPUT
    Ready                   : BOOL;
    Translation             : ST_HwTranslation;
    LinkReady               : BOOL;
    LinkTimeout             : BOOL;
    LinkInvalid             : BOOL;
    LinkAge_Ms              : UDINT;
    TxCount                 : UDINT;
    RxCount                 : UDINT;
    RejectCount             : UDINT;
END_VAR

Ready := FALSE;
LinkReady := FALSE;
LinkTimeout := Enable;
LinkInvalid := Enable;
END_FUNCTION_BLOCK
