(* ═══════════════════════════════════════════════════════════════
   💾 GVL_PERSISTENT — Variables persistantes machine (PERSISTENT RETAIN)
   ───────────────────────────────────────────────────────────────
   ⚠️ Ces variables survivent aux : coupures secteur, Reset Warm/Cold,
      ET aux téléchargements de programme (Download). Elles ne sont
      réinitialisées QUE par "Reset Origin" ou modification de structure.
   🔒 Toute valeur ici est un réglage de mise en service ou une calibration
      physique. Sa perte entraînerait un risque de casse matérielle ou
      de danger humain (position erronée, vitesse non régulée, etc.)
   📐 Convention de nommage : PascalCase strict + suffixe d'unité si REAL
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL PERSISTENT RETAIN

    // ═══════════════════════════════════════════════════════════
    // 🧲 CODEURS ABSOLUS — Données de homing (survit au Download)
    // ═══════════════════════════════════════════════════════════
    CalibM1 : ST_EncoderCalib; // 💾 Calibration treuil M1 : Homed, HomingRefRaw, LastKnownRawPos
    CalibM2 : ST_EncoderCalib; // 💾 Calibration treuil M2 : Homed, HomingRefRaw, LastKnownRawPos

    // Position du capteur de fin de course haut (réglée sur site)
    HomingTargetM1_M : REAL := 12.5; // 💾 Hauteur cible homing M1 (mètres) — ⚠️ perte = homing invalide
    HomingTargetM2_M : REAL := 12.5; // 💾 Hauteur cible homing M2 (mètres) — ⚠️ perte = homing invalide

    // 🧪 REX 2026-07-08 : compteur brut du codeur SIMULÉ (FB_Sim_Encoder, banc de test UNIQUEMENT,
    // sans rapport avec une calibration réelle). Doit survivre à un reset FROID comme le ferait un
    // vrai codeur absolu physique (indépendant de l'automate) — regroupé ici avec le reste des
    // PERSISTENT RETAIN plutôt que déclaré localement dans le FB (PERSISTENT n'est valide que sur
    // du VAR_GLOBAL en CODESYS). Sans ça, HomingSuspect (§3.7) se levait à tort après chaque reboot
    // à froid en simulation : CalibMx.LastKnownRawPos (vrai PERSISTENT) survivait, mais ce compteur
    // simulé retombait à sa valeur par défaut, créant un écart artificiel détecté comme incohérent.
    SimEncoderRawPosM1 : UDINT := 1000000; // 🧪 Simulation uniquement — pas une donnée de calibration réelle
    SimEncoderRawPosM2 : UDINT := 1000000; // 🧪 Simulation uniquement — pas une donnée de calibration réelle

    // ═══════════════════════════════════════════════════════════
    // 🕹️ JOYSTICK — Points neutres calibrés
    // ═══════════════════════════════════════════════════════════
    JoystickNeutralX : INT := 5000; // 💾 Point neutre axe X (valeur brute 0..10000)
    JoystickNeutralY : INT := 5000; // 💾 Point neutre axe Y (valeur brute 0..10000)

    // ═══════════════════════════════════════════════════════════
    // 🪜 TREUILS M1/M2 — Table de paliers de vitesse (COMMUNE aux 2 treuils)
    //    Réglée sur site selon le câblage réel des 4 contacteurs
    //    ⚠️ Perte = paliers invalides → surintensité ou vitesse non régulée
    //    🔧 REX 2026-07-08 : fusion WinchM1SpeedStepTable + WinchM2SpeedStepTable
    //       → WinchSpeedStepTable UNIQUE (demande utilisateur : les 2 treuils sont
    //       mécaniquement/électriquement identiques, les 2 tables étaient déjà
    //       strictement identiques en valeurs — plus de duplication à maintenir).
    //       Si un jour M1/M2 divergent réellement (câblage contacteur différent),
    //       réintroduire 2 tables distinctes à ce moment-là.
    // ═══════════════════════════════════════════════════════════
    // 🔧 REX 2026-07-08 (2) : valeurs relevées en ligne (IHM) et reportées ici comme nouveau
    // défaut — palier 1 sans contacteur engagé (roue libre lente), progression 1 contacteur/palier
    WinchSpeedStepTable : ST_SpeedStepTable := (
        P1R1 := FALSE, P1R2 := FALSE, P1R3 := FALSE, P1R4 := FALSE,
        P2R1 := TRUE,  P2R2 := FALSE, P2R3 := FALSE, P2R4 := FALSE,
        P3R1 := TRUE,  P3R2 := TRUE,  P3R3 := FALSE, P3R4 := FALSE,
        P4R1 := TRUE,  P4R2 := TRUE,  P4R3 := TRUE,  P4R4 := FALSE,
        P5R1 := TRUE,  P5R2 := TRUE,  P5R3 := TRUE,  P5R4 := TRUE,
        StepThreshold_Pct := [20.0, 40.0, 60.0, 80.0, 100.0]
    );

    // Limitation du palier en descente (1..5) — ⚠️ perte = descente trop rapide possible
    // 🔧 REX 2026-07-08 (demande utilisateur) : consolidé en UNE seule valeur commune M1/M2 (les
    // 2 treuils doivent avoir le même profil de déplacement) — remplace WinchM1MaxStepDescente/
    // WinchM2MaxStepDescente (2 valeurs indépendantes). Même pattern que CableLimitDescent_M/
    // WinchSlowdownDistance_M/WinchSlowSpeedPct ci-dessous (miroir bidirectionnel PRG_09_Supervision).
    WinchMaxStepDescente : INT := 3; // 💾 Palier max descente, commun M1/M2 — 🔧 REX 2026-07-08 : défaut relevé à 3 (demande utilisateur)

    // Rampes de vitesse treuils — ⚠️ perte = SafeStop non calibré → risque de choc mécanique
    WinchM1RampAccelRate_Pct    : REAL := 50.0;  // 💾 Accélération M1 (%/s)
    WinchM1RampDecelNormal_Pct  : REAL := 150.0; // 💾 Décélération normale M1 (%/s)
    WinchM1RampDecelFast_Pct    : REAL := 400.0; // 💾 Décélération SafeStop M1 (%/s) — CRITIQUE
    WinchM2RampAccelRate_Pct    : REAL := 50.0;  // 💾 Accélération M2 (%/s)
    WinchM2RampDecelNormal_Pct  : REAL := 150.0; // 💾 Décélération normale M2 (%/s)
    WinchM2RampDecelFast_Pct    : REAL := 400.0; // 💾 Décélération SafeStop M2 (%/s) — CRITIQUE

    // 📐 PARAMÈTRES DE LIMITES DE DESCENTE ET DE RALENTISSEMENT SUR BORDURE (Nouveau 2026-07-03)
    CableLimitDescentM1_M       : REAL := -20.0; // 💾 Limite basse physique de descente M1 (m, négatif)
    CableLimitDescentM2_M       : REAL := -20.0; // 💾 Limite basse physique de descente M2 (m, négatif)
    WinchSlowdownDistance_M     : REAL := 1.0;   // 💾 Distance de ralentissement commune (m)
    WinchSlowSpeedPct           : REAL := 15.0;  // 💾 Vitesse lente dans la zone de ralentissement commune (%)
    // 🔧 REX 2026-07-08 : arrêt réel encodeur en fonctionnement NORMAL, distinct du capteur
    // physique fin de course haut (HomingTargetM1/M2_M, 12.5m). EXPRIMÉ EN MARGE (pas en valeur
    // absolue) : arrêt = HomingTargetMx_M - WinchTopStopMarginM, pour rester automatiquement
    // cohérent avec la position haute de référence si celle-ci est recalibrée sur site (au lieu
    // de devoir aussi corriger une 2e valeur absolue à la main). Commun aux 2 treuils (même
    // ensemble mécanique hissé ensemble). Bypass en MAINT_N2 (référencement codeur) pour
    // pouvoir remonter manuellement en petite vitesse au-delà, jusqu'au capteur physique.
    WinchTopStopMarginM        : REAL := 0.5;    // 💾 Marge sous HomingTargetM1/M2_M pour l'arrêt normal (m)

    // 📏 LIMITE LÉGALE DE DRAGAGE (Nouveau 2026-07-03)
    LimitLegalDepthMinAllowed   : REAL := -15.0; // 💾 Cote min de dragage autorisée (m, négatif)
    LimitLegalEnabled           : BOOL := TRUE;  // 💾 Activation de la limite légale

    // ═══════════════════════════════════════════════════════════
    // ⚖️ SYNCHRONISATION — Tolérance d'écart M1/M2
    // ═══════════════════════════════════════════════════════════
    WinchSyncTolerance_M : REAL := 0.10; // 💾 Écart max toléré entre M1/M2 (mètres) — réglé selon jeu mécanique
    WinchCriticalSyncTolerance_M : REAL := 2.0; // 🆕 REX 2026-07-08 (4) : Méca E — écart critique, défense en profondeur (théorique)

    // ═══════════════════════════════════════════════════════════
    // 🪣 GRAPPIN — Offsets de position et état mécanique mémorisé
    //    ⚠️ Perte OffsetCloseM → retour à 0 = grappin ne se ferme plus
    //    ⚠️ REX 2026-07-07 : signe de OffsetCloseM inversé (-1.5 → +10.0) suite au
    //       constat terrain d'inversion du sens moteur M2 (ENROULAGE ferme désormais,
    //       au lieu de DEROULAGE) — voir Partie12 v1.1 §REX. Amplitude corrigée à ~10 m
    //       (valeur terrain, remplace l'ancienne estimation théorique de 1.5 m) — à
    //       affiner au 1er essai réel du grappin.
    //    🔧 REX 2026-07-08 (2) : défaut revenu à 10.0 m (valeur terrain réelle) — le 2.0 m
    //       "confort test banc" se force ponctuellement en vue instance CODESYS si besoin,
    //       pas dans le défaut source (⚠️ PERSISTENT RETAIN : rappel, un changement de défaut
    //       seul ne remplace pas une valeur déjà retenue en mémoire sur un PLC déjà chargé).
    // ═══════════════════════════════════════════════════════════
    GrappinConfig : ST_GrappinConfig := (
        OffsetOpenM      := 0.0,   // 💾 Position d'ouverture relative (m)
        OffsetCloseM     := 10.0,  // 💾 Position de fermeture relative (m) — valeur terrain
        CoherenceLimitM  := 0.05   // 💾 Tolérance cohérence grappin (m)
    );
    GrappinState : ST_GrappinState; // 💾 État mécanique mémorisé du grappin (ouvert/fermé)

    // 🔧 REX 2026-07-08 : bloc "PARAMÈTRES HISTORIQUES (hérités de PV)" supprimé — audit confirmé
    // (CableSafetyLimit_Pts, MotorAccelDuration_Ms, AnalogInMin/Max_Pts, AnalogOutMin/Max_Pts) :
    // 0 référence CODE/, 0 mention DOC/. ⚠️ Suppression = changement de structure GVL_PERSISTENT →
    // reset retain de TOUT le bloc au prochain download (voir bandeau en-tête fichier).
END_VAR
