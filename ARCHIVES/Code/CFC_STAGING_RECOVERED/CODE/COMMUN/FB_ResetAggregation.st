(* ═══════════════════════════════════════════════════════════════
   🔘 FB_ResetAggregation — Producteur unique du niveau Reset IHM
   ───────────────────────────────────────────────────────────────
   📄 Contrat : ST_ResetCommand
   🛡️ Agrège uniquement les quatre boutons existants. Il ne détecte
      pas de front et ne réarme rien : les consommateurs conservent
      leur R_TRIG local, conformément à la règle Reset = front.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_ResetAggregation
VAR_INPUT
    BtnFaultReset : BOOL;
    BtnResetM1 : BOOL;
    BtnResetM2 : BOOL;
    BtnResetBucket : BOOL;
END_VAR
VAR_OUTPUT
    Cmd : ST_ResetCommand;
END_VAR

Cmd.CmdReset := BtnFaultReset OR BtnResetM1 OR BtnResetM2 OR BtnResetBucket;
