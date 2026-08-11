(* ═══════════════════════════════════════════════════════════════
   📥 FB_DigitalInputFilter — Filtre temporel minimal d'une entrée TOR
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-06_Acquisition_Qualification_IO_v2.1.md
   🎯 Rôle unique : accepter un changement BOOL seulement après FilterTime.
   🛡️ Ce FB ne normalise pas la polarité et ne réalise aucun diagnostic device.
      La polarité est portée par le nom/mapping d'acquisition ; la santé carte
      est publiée séparément par PRG_02_Acquisition.GetDeviceState().
   🔗 Producteur : PRG_02_Acquisition, image HwRealQualified.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_DigitalInputFilter
VAR_INPUT
    InputRaw   : BOOL; (* Valeur brute du canal réel *)
    FilterTime : TIME; (* Durée minimale de stabilité avant validation *)
END_VAR
VAR_OUTPUT
    State : BOOL; (* Valeur filtrée ; première valeur prise immédiatement au démarrage *)
END_VAR
VAR
    FilterTon     : TON;
    FirstScanDone : BOOL;
END_VAR

IF NOT FirstScanDone THEN
    State := InputRaw;
    FirstScanDone := TRUE;
ELSE
    FilterTon(IN := (InputRaw <> State), PT := FilterTime);
    IF FilterTon.Q THEN
        State := InputRaw;
    END_IF;
END_IF;
