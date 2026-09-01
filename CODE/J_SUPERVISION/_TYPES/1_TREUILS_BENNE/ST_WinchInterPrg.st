(* ═══════════════════════════════════════════════════════════════
   🪝 ST_WinchInterPrg — Bus d'échange inter-PRG produit par PRG_04_Treuils_Benne
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Encapsuler les demandes finales M1/M2, les états publics
      WinchM1/M2State, les sécurités WinchM1/M2Safety, l'état synchro et
      l'état benne publiés par PRG_04_Treuils_Benne vers les consommateurs
      (PRG_02/03/06/07).
   📤 Producteur unique : PRG_04_Treuils_Benne (VAR_OUTPUT Data : ST_WinchInterPrg).
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Architecture : Bus de données typé — encapsulation des échanges inter-PRG.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_WinchInterPrg :
STRUCT
    // === ⚡ Demandes finales M1/M2 (interlocks & consigne vitesse arbitrée) ===
    WinchM1FinalInterlockRequest : ST_WinchFinalInterlockRequest; // 🪝 Demande finale et interlocks treuil M1
    WinchM2FinalInterlockRequest : ST_WinchFinalInterlockRequest; // 🪝 Demande finale et interlocks treuil M2
    M1LogicRequestSpeedCmd_Pct   : REAL; // 📈 Consigne vitesse M1 arbitree (%) — consommee par FB_SimBench (PRG_02)
    M2LogicRequestSpeedCmd_Pct   : REAL; // 📈 Consigne vitesse M2 arbitree (%) — consommee par FB_SimBench (PRG_02)
    KoboldContactorCmdArbitrated : BOOL; // 🪝 Ordre contacteur capteur fond Kobold (consommé PRG_06)

    // === 📊 États publics des treuils ===
    WinchM1State                 : ST_WinchState; // 🚦 Etat public treuil Retenue M1
    WinchM2State                 : ST_WinchState; // 🚦 Etat public treuil Benne M2

    // === 🛡️ Sécurités des treuils ===
    WinchM1Safety                : ST_SafetyWinch; // 🛡️ Diagnostic et securites treuil M1
    WinchM2Safety                : ST_SafetyWinch; // 🛡️ Diagnostic et securites treuil M2

    // === 🔄 État synchronisation ===
    SyncState                    : ST_SyncState; // 🔄 Etat synchronisation treuils M1/M2
    WinchSyncError               : BOOL;         // 🚨 Defaut de desynchronisme treuils M1/M2
    WinchSyncSignedDeltaPosM     : REAL;         // 📏 Ecart signe M2 - M1 (m)

    // === 🏗️ État benne ===
    BucketState                  : ST_BucketHMIState; // 🏗️ Etat de fonctionnement benne
    Benne_IsRoughlyClosed        : BOOL;               // 🏗️ Benne consideree fermee (tolerance matiere)
    BucketBusy                   : BOOL;               // ⚙️ Mouvement d'ouverture/fermeture benne en cours
    BucketDone                   : BOOL;               // ✅ Mouvement benne termine avec succes
    BucketError                  : BOOL;               // ❌ Defaut sur sous-systeme benne

    // === 🛡️ Permission d'armement homme-mort (Option B — combiné interlock benne) ===
    ArmingPermit                 : BOOL;               // 🛡️ Permission d'armement homme-mort (consommée PRG_02 → FB_Joystick). TRUE = armement autorisé (NC-100)

    // === Usage effectif d'un override/bypass de POSITION (consommé PRG_03 → FB_Modes) ===
    // Producteur unique : PRG_04_Treuils_Benne §5. Lecteur : PRG_03_Modes_Cycle (lag 1 scan assumé,
    // même doctrine que les autres échanges PRG_03/PRG_04 de ce bus).
    // TRUE = la limite de position de cet axe est actuellement levée au-delà du nominal :
    // override FDC logiciel N1 maintenu OU bypass N2 effectif de la famille position
    // (TopLimitSwitch / TopLimitSoftware / CableLimitSwitch / LimitLegal / MecaD).
    // Sert à armer le re-homing obligatoire (AF-05 §4bis) — n'est PAS un permis de mouvement.
    PositionLimitOverriddenM1    : BOOL;               // 🧭 Treuil M1 — limite de position levée
    PositionLimitOverriddenM2    : BOOL;               // 🧭 Treuil M2 — limite de position levée

    // === 🕵️ Trace de blocage terrain (consommée FB_TroubleshootingView) ===
    TraceM1                      : ST_TraceWinch;      // 🕵️ Trace blocage treuil M1 (cause priorisée + horodatage)
    TraceM2                      : ST_TraceWinch;      // 🕵️ Trace blocage treuil M2 (cause priorisée + horodatage)

    // === 🔗 ATOMICITÉ BOTH : diagnostic IHM lecture seule ===
    // Permis agrégés consommés par la commande both + cause priorisée du blocage.
    // Aucune action de conduite n'en dépend (l'arrêt est porté par §5/§6 de PRG_04).
    BothActive                   : BOOL;               // 🔗 Intention both active (M1+M2 ensemble)
    BothAscentPermit             : BOOL;               // 🔗 Permit montée Both (EffectivePermitM1_Ascent AND EffectivePermitM2_Ascent)
    BothDescendPermit            : BOOL;               // 🔗 Permit descente Both (EffectivePermitM1_Descend AND EffectivePermitM2_Descend)
    BothBlocked                  : BOOL;               // 🔗 Commande Both bloquée par le permis agrégé (diagnostic uniquement)
    BothBlockReason              : E_WinchTraceBlockReason; // 🔗 Cause priorisée du blocage Both
END_STRUCT
END_TYPE
