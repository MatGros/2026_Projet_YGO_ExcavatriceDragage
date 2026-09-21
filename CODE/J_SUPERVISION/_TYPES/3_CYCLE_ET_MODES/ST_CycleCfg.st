(* ═══════════════════════════════════════════════════════════════
   ST_CycleCfg — Configuration du cycle semi-automatique
   SetDepth_M et DepthStopMode protégés par persistance GVL_PERSISTENT
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleCfg :
STRUCT
    SetDepth_M         : REAL := -29.0; (* 📐 Profondeur de dragage cible (m, négative) *)
    DepthStopMode      : E_CycleDepthStopMode := E_CycleDepthStopMode.KOBOLD_OR_SETPOINT; (* 🧭 Source arrêt AX7 *)
    DrainTime_S        : INT := 5;      (* ⏱️ Durée d'égouttage du godet en AX13 (configurable IHM, secondes entières [1..3600]) *)
    RaiseOffBottom_M   : REAL := 0.0;   (* 📐 0 = passage direct AX10 ; >0 = distance de décollement AX9 *)
    CtrlAscentMaxStep  : INT  := 2;     (* 🚀 Palier max montée contrôle AX11, borné [1..2] côté FB (GEL Q16) *)
    ExtractionStartOpening_Pct : INT := 0; (* 📐 Ouverture benne restante déclarant la fermeture atteinte [0..20 %] ; 0 = critère d'arrivée seul (branche seuil inactive) *)
    ForceStepTarget    : INT  := 0;     (* 🔧 RESERVE / INERTE depuis T358 — PLUS AUCUN LECTEUR : la cible de forcage est portee par ST_CycleCmd.SetForceStepTgt (zone non persistee). Champ conserve A SA PLACE pour ne pas decaler le mapping RETAIN positionnel des champs suivants (regle : jamais d'insertion ni de retrait au milieu) ; sa suppression releve d'un lot de migration de persistance dedie. L'IHM ne doit PLUS exposer de champ de saisie sur ce tag. *)
    DiveStartMin_M     : REAL := 4.0;   (* 📐 Altimétrie lancement Kobold (AT4, PRG_03) *)
    ImmersionUpper_M   : REAL := 0.5;   (* 📐 Altimétrie Kobold haute confirmation immersion (AT4, PRG_04) *)
    ImmersionLower_M   : REAL := -0.5;  (* 📐 Altimétrie Kobold basse confirmation immersion (AT4, PRG_04) *)
    ExtractionControlDistance_M : REAL := 1.0; (* 📐 Distance de contrôle AX11 après fermeture benne (m) — T298, reglage fin sur site a prevoir *)
    Initialized        : BOOL := FALSE; (* 🚦 flag restauration boot *)
    // ⚠️ AJOUT EN FIN DE STRUCT — mapping RETAIN positionnel : jamais d'insertion au milieu.
    SampleCountResetMode : E_CycleSampleCountResetMode := E_CycleSampleCountResetMode.NEVER; (* 🔢 RAZ auto du compteur JOURNALIER : NEVER par defaut = aucune RAZ auto *)
END_STRUCT
END_TYPE
