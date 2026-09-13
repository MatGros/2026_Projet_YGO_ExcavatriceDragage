(* =======================================================================
   💾 FB_CfgPersistBridge_fbJoystick_Cfg — Pont persistance pour ST_fbJoystick_Cfg
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Restauration et synchronisation bidirectionnelle IHM / Persist
   💾 Persistance : Transfert GVL_PERSISTENT <-> GVL_IHM sur Initialized
   📄 Doc métier : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md
   ======================================================================= *)
FUNCTION_BLOCK FB_CfgPersistBridge_fbJoystick_Cfg
VAR_OUTPUT
    // === ETATS RESTAURATION ===
    JustRestored            : BOOL;                  // <-- [STAT] Vrai sur le cycle de restauration initiale
END_VAR
VAR_IN_OUT
    // === BUS CONFIGURATION ET PERSISTANCE ===
    Hmi                     : ST_fbJoystick_Cfg;     // <-> [BUS] Structure de configuration IHM
    Persist                 : ST_fbJoystick_Cfg;     // <-> [BUS] Structure de configuration persistante
END_VAR

JustRestored := FALSE;
IF NOT Hmi.Initialized THEN
    Hmi := Persist;
    Hmi.Initialized := TRUE;
    JustRestored := TRUE;
ELSE
    Persist := Hmi;
END_IF;
