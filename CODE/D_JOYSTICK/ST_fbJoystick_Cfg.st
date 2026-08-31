(* =======================================================================
   ⚙️ ST_fbJoystick_Cfg — Réglages regroupés de FB_Joystick
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : porter en un bloc les 5 paramètres de conditionnement du geste
      (zone morte, temporisations homme-mort, marge défaut capteur).
      Passé à FB_Joystick via l'entrée `Cfg` — échange bloc IHM / persistant.
   🧬 Pattern cfg : aligné sur ST_CycleCfg / ST_WinchCfg (préfixe ST_<Domaine>Cfg,
      instance persistante dans GVL_PERSISTENT, pont FB_CfgPersistBridge_* à venir).
   📄 Doc métier : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md (§5bis)
   ======================================================================= *)

TYPE ST_fbJoystick_Cfg :
STRUCT
    DeadbandRaw          : INT  := 300;      // Zone morte en points ADC bruts (0..10000)
    NeutralHoldTime      : TIME := T#100MS;  // Maintien continu au neutre avant désarmement homme-mort
    DeadmanArmHoldTime   : TIME := T#100MS;  // Appui continu bouton requis pour armer le geste
    DeadmanArmGraceTime  : TIME := T#3S;     // Délai de grâce post-armement avant désarmement neutre
    RawOutOfRangeMargin  : INT  := 500;      // Marge ADC autour des bornes [0..10000] avant défaut capteur (AF08 §5bis)
    SpeedStepTable       : ST_SpeedStepTable := (StepThreshold_Pct := [20.0, 40.0, 60.0, 80.0, 100.0]); // 🪜 Table seuils % -> palier (conversion au joystick, logique FB_Winch §5)
    SpeedStepHystMargin  : REAL := 2.0;      // Marge d'hystérésis palier (%) autour des seuils (anti-oscillation)
    Initialized          : BOOL := FALSE;    // 🚦 Flag restauration boot (interne pont FB_CfgPersistBridge_fbJoystick_Cfg)
END_STRUCT
END_TYPE
