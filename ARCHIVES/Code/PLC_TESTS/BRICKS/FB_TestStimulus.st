FUNCTION_BLOCK FB_TestStimulus
VAR_INPUT
    Config     : ST_TestStimAnalogConfig;
    Start      : BOOL;
    Abort      : BOOL;
END_VAR
VAR_OUTPUT
    OutBool    : BOOL;
    OutReal    : REAL;
    OutActive  : BOOL;
    Done       : BOOL;
END_VAR
VAR
    StartTrig   : R_TRIG;
    Timer       : TON;
    SeqTimer    : TON;
    Ramp        : RAMP_REAL;
    ActiveIndex : INT;
    Running     : BOOL;
    Rate        : REAL;
END_VAR
// === IMPLEMENTATION ===
StartTrig(CLK := Start);

// Gestion de l'arrêt ou de l'inactivité
IF Abort OR (NOT Running AND NOT StartTrig.Q) THEN
    Running := FALSE;
    OutActive := FALSE;
    OutBool := FALSE;
    OutReal := 0.0;
    Done := FALSE;
    Timer(IN := FALSE);
    SeqTimer(IN := FALSE);
    Ramp(RESET := TRUE, IN := 0.0);
    RETURN;
END_IF;

// Lancement sur front montant de Start
IF StartTrig.Q THEN
    Running := TRUE;
    Done := FALSE;
    OutActive := TRUE;
    ActiveIndex := 1;
    Timer(IN := FALSE);
    SeqTimer(IN := FALSE);
    
    CASE Config.Kind OF
        E_TestStimKind.STIM_PULSE_BOOL:
            OutBool := TRUE;
            Timer(IN := TRUE, PT := Config.PulsePT);
            
        E_TestStimKind.STIM_RAMP_REAL:
            Ramp(RESET := TRUE, IN := Config.StartReal);
            IF Config.RampPT > T#0s THEN
                // Calcul de la vitesse par seconde
                Rate := ABS(Config.TargetReal - Config.StartReal) / (TIME_TO_REAL(Config.RampPT) / 1000.0);
            ELSE
                Rate := ABS(Config.TargetReal - Config.StartReal);
            END_IF;
            Timer(IN := TRUE, PT := Config.RampPT);
            
        E_TestStimKind.STIM_SEQUENCE_REAL:
            IF Config.SeqCount >= 1 THEN
                OutReal := Config.SeqValues[1];
                SeqTimer(IN := TRUE, PT := Config.SeqDwellPT);
            ELSE
                Running := FALSE;
                OutActive := FALSE;
                Done := TRUE;
            END_IF;
    END_CASE;
END_IF;

// Éxecution logique quand le stimulus tourne
IF Running THEN
    CASE Config.Kind OF
        E_TestStimKind.STIM_PULSE_BOOL:
            Timer();
            IF Timer.Q THEN
                OutBool := FALSE;
                Running := FALSE;
                OutActive := FALSE;
                Done := TRUE;
                Timer(IN := FALSE);
            END_IF;
            
        E_TestStimKind.STIM_RAMP_REAL:
            Timer();
            Ramp(RESET := FALSE, IN := Config.TargetReal, ASCEND := Rate, DESCEND := Rate, TIMEBASE := T#1s);
            OutReal := Ramp.OUT;
            IF Timer.Q THEN
                OutReal := Config.TargetReal; // Assure la valeur cible exacte à la fin
                Running := FALSE;
                OutActive := FALSE;
                Done := TRUE;
                Timer(IN := FALSE);
            END_IF;
            
        E_TestStimKind.STIM_SEQUENCE_REAL:
            SeqTimer();
            IF SeqTimer.Q THEN
                SeqTimer(IN := FALSE);
                ActiveIndex := ActiveIndex + 1;
                IF ActiveIndex > Config.SeqCount OR ActiveIndex > GVL_PLC_Tests_Const.MaxSeqValues THEN
                    Running := FALSE;
                    OutActive := FALSE;
                    Done := TRUE;
                ELSE
                    OutReal := Config.SeqValues[ActiveIndex];
                    SeqTimer(IN := TRUE, PT := Config.SeqDwellPT);
                END_IF;
            END_IF;
    END_CASE;
END_IF;
