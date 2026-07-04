(* ═══════════════════════════════════════════════════════════════
   🗂️ GVL_OUT — Commandes machines (entrée de FB_OutputsMachine)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie6_IO_Conditioning_v1.2.md §5
   🔴 ÉCRITURE : PRG_MAIN SEULEMENT | LECTURE : FB_OutputsMachine SEULEMENT
   🔌 RÈGLE NO (commandes) : REPOS=FALSE=arrêt ✅ | TRUE=bobine alimentée/contacteur fermé
   ⚠️ EXCEPTION frein     : TRUE=desserré (mouvement) | FALSE=SERRÉ=position sécurisée ✅
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_OUT) ===

VAR_GLOBAL

    // ── 🪝 TREUIL M1 ─────────────────────────────────────────────────────────────────────
    M1RelayFwd        : BOOL;  // ⬆️ Relais MONTÉE M1 (NO) : TRUE=bobine ON, moteur monte | FALSE=arrêt ✅
    M1RelayRev        : BOOL;  // ⬇️ Relais DESCENTE M1 (NO) : TRUE=bobine ON, moteur descend | FALSE=arrêt ✅
    M1SpeedContactor1 : BOOL;  // 🐢 Contacteur vitesse 1 M1 — palier 1 lent (résistance max)
    M1SpeedContactor2 : BOOL;  // 🐇 Contacteur vitesse 2 M1 — palier 2
    M1SpeedContactor3 : BOOL;  // 🐇🐇 Contacteur vitesse 3 M1 — palier 3
    M1SpeedContactor4 : BOOL;  // 🚀 Contacteur vitesse 4 M1 — palier 4 pleine puissance
    M1BrakeCmd        : BOOL;  // 🔓 Frein M1 ⚠️INVERSÉ : TRUE=desserré/mouvement | FALSE=SERRÉ sécurité ✅

    // ── 🪝 TREUIL M2 (même logique que M1) ──────────────────────────────────────────────
    M2RelayFwd        : BOOL;  // ⬆️ Relais MONTÉE M2 (NO) : TRUE=bobine ON, moteur monte | FALSE=arrêt ✅
    M2RelayRev        : BOOL;  // ⬇️ Relais DESCENTE M2 (NO) : TRUE=bobine ON, moteur descend | FALSE=arrêt ✅
    M2SpeedContactor1 : BOOL;  // 🐢 Contacteur vitesse 1 M2 — palier 1 lent
    M2SpeedContactor2 : BOOL;  // 🐇 Contacteur vitesse 2 M2 — palier 2
    M2SpeedContactor3 : BOOL;  // 🐇🐇 Contacteur vitesse 3 M2 — palier 3
    M2SpeedContactor4 : BOOL;  // 🚀 Contacteur vitesse 4 M2 — palier 4 pleine puissance
    M2BrakeCmd        : BOOL;  // 🔓 Frein M2 ⚠️INVERSÉ : TRUE=desserré/mouvement | FALSE=SERRÉ sécurité ✅

    // ── ↔️ CHARIOT M3 (sens/vitesse via variateur EtherCAT, TOR=frein uniquement) ────────
    ChariotBrakeCmd   : BOOL;  // 🔓 Frein M3 ⚠️INVERSÉ : TRUE=desserré/mouvement | FALSE=SERRÉ sécurité ✅

    // ── 🧨 COUPURE PUISSANCE AMONT — Redondance 2 relais en série ────────────────────────
    // Les 2 relais sont commandés SIMULTANÉMENT par le même signal logique (PowerCutOff_RQ).
    // Leurs contacts sont câblés EN SÉRIE : si l'un colle (soudure), l'autre coupe quand même.
    // Placés sur 2 cartes I/O DIFFÉRENTES pour diversité matérielle (panne carte n'empêche pas la coupure).
    // ⚠️ Logique NC côté puissance : TRUE=relais excité/contact ouvert=CIRCUIT COUPÉ 🔴
    //                                FALSE=relais retombé/contact fermé=puissance OK ✅
    PowerCutOff_A_RQ  : BOOL;  // 🧨 Relais coupure puissance CANAL A (carte 1) : TRUE=coupure active | FALSE=puissance OK ✅
    PowerCutOff_B_RQ  : BOOL;  // 🧨 Relais coupure puissance CANAL B (carte 2) : TRUE=coupure active | FALSE=puissance OK ✅

END_VAR
