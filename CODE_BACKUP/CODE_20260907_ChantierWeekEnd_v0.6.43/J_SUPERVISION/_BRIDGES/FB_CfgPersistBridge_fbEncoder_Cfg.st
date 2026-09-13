(* =======================================================================
   💾 FB_CfgPersistBridge_fbEncoder_Cfg — Pont persistance pour ST_fbEncoder_Cfg
   ───────────────────────────────────────────────────────────────────────
   🎯 Rôle : restauration et synchronisation bidirectionnelle IHM / Persist.
   💾 Persistance : transfert GVL_PERSISTENT <-> GVL_IHM sur Initialized.
   📄 Doc : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md
   ======================================================================= *)
FUNCTION_BLOCK FB_CfgPersistBridge_fbEncoder_Cfg
VAR_OUTPUT
    // === ETATS RESTAURATION ===
    JustRestored : BOOL; // <-- [STAT] Vrai sur le cycle de restauration initiale
END_VAR
VAR_IN_OUT
    // === BUS CONFIGURATION ET PERSISTANCE ===
    Hmi    : ST_fbEncoder_Cfg; // <-> [BUS] Structure de configuration IHM commune
    Persist : ST_fbEncoder_Cfg; // <-> [BUS] Structure de configuration persistante
END_VAR

JustRestored := FALSE;
IF NOT Hmi.Initialized THEN
    Hmi := Persist;
    Hmi.Initialized := TRUE;
    JustRestored := TRUE;
ELSE
    Persist := Hmi;
END_IF;
