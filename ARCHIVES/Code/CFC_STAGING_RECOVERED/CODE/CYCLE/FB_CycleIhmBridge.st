(* ═══════════════════════════════════════════════════════════════
   🔄 FB_CycleIhmBridge — Frontière IHM du séquenceur Cycle
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.0.md §1/3
   🎯 Rôle : transforme les commandes IHM impulsionnelles et les réglages
      Cycle en entrées explicites du FB_Cycle.
   🛡️ Sécurité : l'homme-mort ne mémorise aucune permission; son relâchement
      force CycleMotionPermit à FALSE. Ce FB ne produit aucune sortie physique.
   🧩 Dépendances : ST_CycleCmd, E_Mode, FB_Cycle.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_CycleIhmBridge
VAR_INPUT
    Mode                : E_Mode; (* Mode déjà arbitré par FB_Modes *)
    DeadmanArmed        : BOOL;   (* TRUE = homme-mort armé *)
    AxisCmdYStartStop   : BOOL;   (* TRUE = intention verticale maintenue *)
    SetDepthM           : REAL;   (* m, consigne IHM de profondeur *)
    SetOffsetM          : REAL;   (* m, consigne IHM fermeture benne *)
    SelectedTargetNum   : INT;    (* 2=P2, 3=P1 *)
END_VAR
VAR_IN_OUT
    CycleCmd            : ST_CycleCmd; (* Commandes IHM consommées sur ce scan *)
END_VAR
VAR_OUTPUT
    CycleEnable                 : BOOL; (* TRUE seulement en SEMI_AUTO *)
    CycleMotionPermit           : BOOL; (* homme-mort + intention verticale présents *)
    StartCycle                  : BOOL; (* impulsion Start consommée *)
    PauseCycle                  : BOOL; (* impulsion Pause consommée *)
    AbortCycle                  : BOOL; (* impulsion Abort consommée *)
    ResetCycle                  : BOOL; (* impulsion Reset Cycle, distincte défaut machine *)
    SetDepthMOut                : REAL; (* m *)
    SetOffsetMOut               : REAL; (* m *)
    SelectedTargetNumOut        : INT;  (* 2=P2, 3=P1 *)
    SpeedMismatchThresholdMps   : REAL; (* m/s; 0 = surveillance non configurée *)
    SpeedMismatchTimeout        : TIME; (* 0 = surveillance non configurée *)
END_VAR
VAR CONSTANT
    CST_SpeedMismatchThresholdMps : REAL := 0.0;  (* T43 provisoirement désactivé *)
    CST_SpeedMismatchTimeout      : TIME := T#0ms; (* T43 provisoirement désactivé *)
END_VAR

// 🎚️ Les Modes autorisent; ce bridge ne porte aucune interdiction métier.
CycleEnable := (Mode = E_Mode.SEMI_AUTO);

// 🕹️ L'homme-mort reste une intention maintenue, jamais une autorisation mémorisée.
CycleMotionPermit := DeadmanArmed AND AxisCmdYStartStop;

// 🔘 Capture avant remise à zéro : GVL_IHM est RETAIN et doit donc rester impulsionnelle.
StartCycle := CycleCmd.BtnStart;
PauseCycle := CycleCmd.BtnPause;
AbortCycle := CycleCmd.BtnAbort;
ResetCycle := CycleCmd.BtnReset;

SetDepthMOut := SetDepthM;
SetOffsetMOut := SetOffsetM;
SelectedTargetNumOut := SelectedTargetNum;
SpeedMismatchThresholdMps := CST_SpeedMismatchThresholdMps;
SpeedMismatchTimeout := CST_SpeedMismatchTimeout;

// 🧹 Une commande IHM est consommée une fois, sans modifier l'état ni l'étape Cycle.
CycleCmd.BtnStart := FALSE;
CycleCmd.BtnPause := FALSE;
CycleCmd.BtnAbort := FALSE;
CycleCmd.BtnReset := FALSE;
