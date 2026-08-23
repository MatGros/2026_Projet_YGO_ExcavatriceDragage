(* =======================================================================
   📊 HYSTERESIS — Bibliothèque standard Util CODESYS (IN, HIGH, LOW -> OUT)
   ======================================================================= *)
FUNCTION_BLOCK FB_Hysteresis_Util
VAR_INPUT
    IN   : INT;
    HIGH : INT;
    LOW  : INT;
END_VAR
VAR_OUTPUT
    OUT  : BOOL := TRUE;
END_VAR

IF OUT THEN
    IF IN >= HIGH THEN
        OUT := FALSE;
    END_IF;
ELSE
    IF IN <= LOW THEN
        OUT := TRUE;
    END_IF;
END_IF;
END_FUNCTION_BLOCK
