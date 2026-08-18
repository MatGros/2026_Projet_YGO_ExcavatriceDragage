(* ═══════════════════════════════════════════════════════════════
   💾 GVL_BypassRetain — Variables RETAIN pour les bypass de mise en service
   ───────────────────────────────────────────────────────────────
   🔒 Survit au Warm Restart (CPU Stop/Start) mais PAS au Download.
   🎯 Utilisé uniquement lors de la mise en service / débogage.
   ═══════════════════════════════════════════════════════════════ *)
VAR_GLOBAL RETAIN

    // 🌐 Bypass Global Translation M3 (FB_Safety_Translation + FB_Translation)
    BypassTranslationGlobal     : BOOL := FALSE;
    // 🌐 Bypass Global Treuil M1 (FB_Safety_Winch + FB_Winch)
    BypassWinchM1Global         : BOOL := FALSE;
    // 🌐 Bypass Global Treuil M2 (FB_Safety_Winch + FB_Winch)
    BypassWinchM2Global         : BOOL := FALSE;
    // 🌐 Bypass Global Synchro M1/M2 (FB_WinchSync)
    BypassSyncGlobal            : BOOL := FALSE;
    // 🌐 Bypass Global Réseau CAN/EtherCAT (force Online)
    BypassNetworkGlobal         : BOOL := FALSE;
    // 🌐 Bypass Global Benne (FB_Bucket)
    BypassBucketGlobal          : BOOL := FALSE;
    // 🌐 Bypass Global Commun M1+M2 (GVL_IHM.Commun.Bypass.Global)
    BypassCommunGlobal          : BOOL := FALSE;

    // ⚡ BYPASS RAPIDES UNITAIRES COMMUMS (Levée immédiate des sécurités d'essai)
    BypassLimitLegal            : BOOL := FALSE; // 📐 Bypass Limite Légale de Profondeur
    BypassTopLimitSwitch        : BOOL := FALSE; // 🚧 Bypass Capteur Fin de Course Haut Physique
    BypassTopLimitSoftware      : BOOL := FALSE; // 📐 Bypass Butée Logicielle Haute
    BypassCableLimitSwitch      : BOOL := FALSE; // 📏 Bypass Butée Basse Câble
    BypassSlackCable            : BOOL := FALSE; // ⚠️ Bypass Mou de Câble M1/M2

END_VAR
