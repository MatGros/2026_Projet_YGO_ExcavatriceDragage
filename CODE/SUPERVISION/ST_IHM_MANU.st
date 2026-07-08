(* ═══════════════════════════════════════════════════════════════
   🌐 ST_IHM_MANU — Table d'échange IHM provisoire pour mise en service
   ───────────────────────────────────────────────────────────────
   ⚙️ Permet le pilotage manuel direct des sorties physiques (contacteurs, 
      relais, freins, mots de commande variateurs) en mode dégradé 
      pour la mise en service des treuils M1/M2 et du chariot M3.
   ⚠️ Avertissement : Ce mode désactive les sécurités normales et les interlocks
      logiciels standards. Les interlocks de sécurité de base (ex: Fwd vs Rev)
      doivent être gérés directement dans le code d'activation de secours.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_IHM_MANU :
STRUCT
    (* 🪝 Treuil M1 — Holding / Retenue *)
    PositionM_M1    : REAL; (* 📊 [m] Position brute du treuil M1 *)
    M1_RelayFwd     : BOOL; (* 🛗 Commande montée M1 (Relais forward + Frein desserré) — ⚠️ Interlock M1_RelayRev requis *)
    M1_RelayRev     : BOOL; (* 🛗 Commande descente M1 (Relais reverse + Frein desserré) — ⚠️ Interlock M1_RelayFwd requis *)

    (* 🪝 Treuil M2 — Closing / Fermeture *)
    PositionM_M2    : REAL; (* 📊 [m] Position brute du treuil M2 *)
    M2_RelayFwd     : BOOL; (* 🛗 Commande montée M2 (Relais forward + Frein desserré) — ⚠️ Interlock M2_RelayRev requis *)
    M2_RelayRev     : BOOL; (* 🛗 Commande descente M2 (Relais reverse + Frein desserré) — ⚠️ Interlock M2_RelayFwd requis *)

    (* 🔗 Commande Couplée M1 + M2 (Mouvement Synchrone) *)
    M1_M2_RelayFwd  : BOOL; (* 🔗 Commande montée simultanée M1+M2 + Desserrage freins — ⚠️ Interlock M1_M2_RelayRev requis *)
    M1_M2_RelayRev  : BOOL; (* 🔗 Commande descente simultanée M1+M2 + Desserrage freins — ⚠️ Interlock M1_M2_RelayFwd requis *)
    M1_M2_Contactor1: BOOL; (* ⚡ Vitesse 1 : Contacteur de vitesse K1 pour M1 et M2 *)
    M1_M2_Contactor2: BOOL; (* ⚡ Vitesse 2 : Contacteur de vitesse K2 pour M1 et M2 *)
    M1_M2_Contactor3: BOOL; (* ⚡ Vitesse 3 : Contacteur de vitesse K3 pour M1 et M2 *)
    M1_M2_Contactor4: BOOL; (* ⚡ Vitesse 4 : Contacteur de vitesse K4 pour M1 et M2 *)

    (* ↔️ Variateur Chariot M3 (AC600) *)
    M3_RelayFwd     : BOOL; (* ↔️ Marche avant M3 (Commande frein + bit control_word = 6 puis démarrage) — ⚠️ Interlock M3_RelayRev requis *)
    M3_RelayRev     : BOOL; (* ↔️ Marche arrière M3 (Commande frein + bit control_word = 6 puis démarrage) — ⚠️ Interlock M3_RelayFwd requis *)
    M3_FreqSetpoint : REAL; (* 🎯 [Hz] Consigne de fréquence (ex: 50.0Hz envoie la valeur 5000 sans mot de commande) *)
    M3_FreqActual   : REAL; (* 📊 [Hz] Fréquence réelle lue (ex: 50.0Hz correspond à la valeur 5000) *)

END_STRUCT
END_TYPE
