(* ═══════════════════════════════════════════════════════════════
   🗂️ GVL_OUT — Commandes machines (entrée de FB_OutputsMachine)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie6_IO_Conditioning_v1.2.md §5
   🔴 ÉCRITURE : PRG_MAIN SEULEMENT (après FB_Winch/FB_Chariot)
   ✅ LECTURE  : FB_OutputsMachine SEULEMENT (câblage physique sorties)

   🔌 RÈGLE CÂBLAGE SORTIES (lire avant de modifier) :
   ─────────────────────────────────────────────────────
   Les sorties de commande sont en logique POSITIVE (NO) :
     TRUE  (1) = bobine ALIMENTÉE, contacteur FERMÉ, puissance ON
     FALSE (0) = bobine COUPÉE, contacteur OUVERT, puissance OFF (état repos sûr)
   Le frein est l'exception : TRUE = frein DESSERRÉ (mouvement autorisé)
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_OUT) ===

VAR_GLOBAL

    // ─────────────────────────────────────────────────────────────────────
    // 🪝 TREUIL M1 — Commandes relais et contacteurs
    // ─────────────────────────────────────────────────────────────────────

    M1RelayFwd        : BOOL;
    // ⬆️ Relais sens MONTÉE M1 (NO — repos = FALSE = arrêt)
    //    TRUE  = bobine alimentée → moteur M1 tourne en montée (enroule câble)
    //    FALSE = bobine coupée   → moteur M1 à l'arrêt (état sûr)
    //    ⚠️ M1RelayFwd et M1RelayRev ne doivent JAMAIS être TRUE simultanément !

    M1RelayRev        : BOOL;
    // ⬇️ Relais sens DESCENTE M1 (NO — repos = FALSE = arrêt)
    //    TRUE  = bobine alimentée → moteur M1 tourne en descente (déroule câble)
    //    FALSE = bobine coupée   → moteur M1 à l'arrêt

    M1SpeedContactor1 : BOOL;
    // 🐢 Contacteur vitesse 1 M1 — palier 1 (vitesse lente, résistance max insérée)
    //    TRUE = contacteur fermé → palier de vitesse 1 actif

    M1SpeedContactor2 : BOOL;
    // 🐇 Contacteur vitesse 2 M1 — palier 2
    M1SpeedContactor3 : BOOL;
    // 🐇🐇 Contacteur vitesse 3 M1 — palier 3
    M1SpeedContactor4 : BOOL;
    // 🚀 Contacteur vitesse 4 M1 — palier 4 (vitesse max, pleine puissance)

    M1BrakeCmd        : BOOL;
    // 🔓 Commande frein électromagnétique M1 (logique INVERSE sécurité !)
    //    TRUE  = bobine alimentée → frein DESSERRÉ → mouvement possible
    //    FALSE = bobine coupée   → frein SERRÉ (ressort) → position maintenue (état sûr)
    //    ⚠️ Sur défaut : toujours mettre à FALSE pour freiner par sécurité !


    // ─────────────────────────────────────────────────────────────────────
    // 🪝 TREUIL M2 — Commandes relais et contacteurs (même logique que M1)
    // ─────────────────────────────────────────────────────────────────────

    M2RelayFwd        : BOOL;
    // ⬆️ Relais sens MONTÉE M2 — même logique que M1RelayFwd

    M2RelayRev        : BOOL;
    // ⬇️ Relais sens DESCENTE M2 — même logique que M1RelayRev

    M2SpeedContactor1 : BOOL;
    // 🐢 Contacteur vitesse 1 M2
    M2SpeedContactor2 : BOOL;
    // 🐇 Contacteur vitesse 2 M2
    M2SpeedContactor3 : BOOL;
    // 🐇🐇 Contacteur vitesse 3 M2
    M2SpeedContactor4 : BOOL;
    // 🚀 Contacteur vitesse 4 M2

    M2BrakeCmd        : BOOL;
    // 🔓 Commande frein M2 — même logique que M1BrakeCmd (TRUE = desserré)


    // ─────────────────────────────────────────────────────────────────────
    // ↔️ CHARIOT M3 — Frein uniquement (relais du variateur via bus)
    // ─────────────────────────────────────────────────────────────────────

    ChariotBrakeCmd   : BOOL;
    // 🔓 Commande frein chariot M3 — même logique que M1/M2BrakeCmd
    //    TRUE  = frein DESSERRÉ → chariot peut se déplacer
    //    FALSE = frein SERRÉ    → chariot bloqué en position (état sûr)
    //    📝 Les relais sens/vitesse du chariot sont gérés directement par le variateur AC600
    //       via bus EtherCAT (pas de relais physiques câblés sur les sorties TOR de l'API)

END_VAR
