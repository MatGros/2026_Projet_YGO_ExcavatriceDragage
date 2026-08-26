(* =======================================================================
   💾 FB_CfgPersistBridge_DredgingAssistCfg — Pont persistance prélèvement
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Restauration et synchronisation bidirectionnelle IHM / Persist
   💾 Persistance : Transfert GVL_PERSISTENT <-> GVL_IHM sur Initialized
   📄 Doc métier : DOC/AF/AF_Partie-03_Contrats_Composants_v2.3.md §3
   ======================================================================= *)
FUNCTION_BLOCK FB_CfgPersistBridge_DredgingAssistCfg
VAR_OUTPUT
    // === ETATS RESTAURATION ===
    JustRestored            : BOOL;               // <-- [STAT] Vrai sur le cycle de restauration initiale
END_VAR
VAR_IN_OUT
    // === BUS CONFIGURATION ET PERSISTANCE ===
    Hmi                     : ST_DredgingAssistCfg; // <-> [BUS] Structure de configuration IHM
    Persist                 : ST_DredgingAssistCfg; // <-> [BUS] Structure de configuration persistante
END_VAR

JustRestored := FALSE;
IF NOT Hmi.Initialized THEN
    Hmi := Persist;
    Hmi.Initialized := TRUE;
    JustRestored := TRUE;
ELSE
    Persist := Hmi;
END_IF;
