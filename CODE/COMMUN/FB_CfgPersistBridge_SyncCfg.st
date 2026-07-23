(* ═══════════════════════════════════════════════════════════════
   🌉 FB_CfgPersistBridge_SyncCfg — Pont persistance générique pour ST_SyncCfg
   ───────────────────────────────────────────────────────────────
   🎯 Remplace les blocs manuels restauration/sauvegarde dupliqués à chaque domaine
   (voir DOC/AUDITS/ConfigPersistence/). Une instance = un couple (struct IHM, struct
   GVL_PERSISTENT) du MÊME type. Logique :
   - Hmi.Initialized = FALSE (RETAIN invalidé, ex. changement de layout DUT) → restaure
     Hmi depuis Persist, marque Initialized, pulse JustRestored 1 scan.
   - Hmi.Initialized = TRUE → sauvegarde continue Hmi vers Persist (jamais l'inverse).
   🔒 Défense en profondeur : jamais d'écriture PERSISTENT avant qu'une restauration
   réussie n'ait eu lieu (même principe que tous les blocs Cfg du Lot 2).
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_CfgPersistBridge_SyncCfg
VAR_IN_OUT
    Hmi     : ST_SyncCfg; (* 🖥️ ex. GVL_IHM.M1M2Sync.Cfg — struct exposé à l'IHM *)
    Persist : ST_SyncCfg; (* 💾 ex. GVL_PERSISTENT._SyncCfgPersist — mémoire PERSISTENT *)
END_VAR
VAR_OUTPUT
    JustRestored : BOOL; (* 🔔 TRUE pendant 1 scan le boot où la restauration a eu lieu —
                             l'appelant s'en sert pour piloter GVL_IHM.Commun.ConfigRestoredFromPersistent *)
END_VAR

JustRestored := FALSE;
IF NOT Hmi.Initialized THEN
    Hmi := Persist;
    Hmi.Initialized := TRUE;
    JustRestored := TRUE;
ELSE
    Persist := Hmi;
END_IF;
