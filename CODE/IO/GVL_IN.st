(* ═══════════════════════════════════════════════════════════════
   🗂️ GVL_IN — Entrées machine CONDITIONNÉES (sortie de FB_InputsMachine)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie6_IO_Conditioning_v1.2.md §5
   🔴 ÉCRITURE : FB_InputsMachine SEULEMENT — ne jamais écrire ailleurs !
   ✅ LECTURE : tous les autres POUs (Safety, Winch, Chariot, Homing…)

   🔌 RÈGLE CÂBLAGE SÉCURITÉ (lire avant de modifier) :
   ─────────────────────────────────────────────────────
   Tous les capteurs de sécurité sont câblés en NORMALEMENT FERMÉ (NC) :
     ✅ REPOS / SAIN = TRUE (1) → circuit fermé, courant qui passe → tout va bien
     🔴 DÉFAUT / FIN DE COURSE = FALSE (0) → circuit ouvert (sécurité OU fil coupé)
   Avantage : une coupure de fil = une détection de défaut automatique !
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_IN) ===

VAR_GLOBAL

    // ─────────────────────────────────────────────────────────────────────
    // 🛑 SÉCURITÉS COMMUNES (NC — repos = TRUE, défaut/actionné = FALSE)
    // ─────────────────────────────────────────────────────────────────────

    EmergencyStopOk      : BOOL;
    // 🚨 Chaîne arrêt d'urgence (AU bouton champignon + filets de sécurité)
    //    TRUE  = chaîne AU FERMÉE → machine autorisée à bouger
    //    FALSE = chaîne AU COUPÉE (bouton appuyé OU câble coupé) → STOP immédiat

    TopPositionSensor    : BOOL;
    // 🔝 Capteur fin de course HAUT (NC monté en sécurité positive)
    //    TRUE  = capteur LIBRE → câble pas en butée haute, mouvement OK
    //    FALSE = capteur ACTIONNÉ (butée atteinte) → remontée interdite, homing déclenché

    SlackCableSwitch     : BOOL;
    // 🔗 Détecteur mou de câble (NC — repos = câble tendu)
    //    TRUE  = câble TENDU → OK pour descendre
    //    FALSE = câble MOU détecté → descente interdite, remontée autorisée uniquement
    //    ⚠️ Logique de commande : ForbidDescent := NOT SlackCableSwitch (voir FB_Safety_Winch)

    PhaseRotationOk      : BOOL;
    // ⚡ Relais contrôle rotation de phases électriques (NC)
    //    TRUE  = phases CORRECTES → moteurs autorisés à démarrer
    //    FALSE = phases inversées/absentes → SafeStop immédiat (moteurs tourneraient à l'envers !)


    // ─────────────────────────────────────────────────────────────────────
    // 🪝 TREUIL M1 — Retours contacteurs & sécurités (logique mixte NC/NO)
    // ─────────────────────────────────────────────────────────────────────

    M1ContactorFeedbackFwd : BOOL;
    // 📡 Retour contacteur MONTÉE M1 (NO miroir de la bobine)
    //    TRUE  = contacteur montée FERMÉ (bobine alimentée, courant de puissance qui passe)
    //    FALSE = contacteur ouvert (commande coupée ou contacteur collé si commande=TRUE)

    M1ContactorFeedbackRev : BOOL;
    // 📡 Retour contacteur DESCENTE M1 (NO miroir de la bobine)
    //    TRUE  = contacteur descente FERMÉ
    //    FALSE = contacteur ouvert

    M1ThermalFeedback      : BOOL;
    // 🌡️ Sonde thermique moteur M1 (NC — protection moteur contre surchauffe)
    //    TRUE  = température NORMALE → moteur autorisé
    //    FALSE = SURCHAUFFE ou fil coupé → SafeStop M1 immédiat

    M1BrakeFeedback        : BOOL;
    // 🔒 Retour contacteur frein électromagnétique M1 (NC — frein serré = sûr)
    //    TRUE  = frein SERRÉ (bobine coupée, ressort actif) → position sécurisée
    //    FALSE = frein DESSERRÉ (bobine alimentée, frein relâché pour mouvement)


    // ─────────────────────────────────────────────────────────────────────
    // 🪝 TREUIL M2 — Retours contacteurs & sécurités (même logique que M1)
    // ─────────────────────────────────────────────────────────────────────

    M2ContactorFeedbackFwd : BOOL;
    // 📡 Retour contacteur MONTÉE M2 — même logique que M1ContactorFeedbackFwd

    M2ContactorFeedbackRev : BOOL;
    // 📡 Retour contacteur DESCENTE M2 — même logique que M1ContactorFeedbackRev

    M2ThermalFeedback      : BOOL;
    // 🌡️ Sonde thermique moteur M2 — même logique que M1ThermalFeedback

    M2BrakeFeedback        : BOOL;
    // 🔒 Retour contacteur frein M2 — même logique que M1BrakeFeedback


    // ─────────────────────────────────────────────────────────────────────
    // ↔️ CHARIOT M3 — Capteurs de position (NO — actionné = position atteinte = TRUE)
    // ─────────────────────────────────────────────────────────────────────

    ChariotPosFosse1      : BOOL;
    // 📍 Capteur position FOSSE 1 (NO — position atteinte = TRUE)
    //    TRUE  = chariot EN POSITION fosse 1 (fin de course actionné physiquement)
    //    FALSE = chariot hors de la fosse 1

    ChariotPosFosse2      : BOOL;
    // 📍 Capteur position FOSSE 2 — même logique que ChariotPosFosse1

    ChariotPosMaintenance : BOOL;
    // 🔧 Capteur position MAINTENANCE — chariot en position de service
    //    TRUE  = position maintenance atteinte (pour interventions mécaniques)

    ChariotPosTremie      : BOOL;
    // 🗑️ Capteur position TRÉMIE (déversement) — chariot en position vidange
    //    TRUE  = position trémie atteinte → autorisation ouverture grappin

    M3BrakeFeedback       : BOOL;
    // 🔒 Retour contacteur frein chariot M3 — même logique que M1BrakeFeedback

END_VAR
