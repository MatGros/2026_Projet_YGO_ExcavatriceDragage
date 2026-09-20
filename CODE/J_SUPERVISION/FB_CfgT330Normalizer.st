(* ═══════════════════════════════════════════════════════════════
   🔧 FB_CfgT330Normalizer — Normalisation des réglages HAUT (T330)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : ramener DANS SON DOMAINE le couple de réglages de fin de
             course HAUT — FDC logiciel (CfgCableLimitAscent_M) et cote
             TOP homing (CfgTopSensorPos_M) — plus le plancher du
             ralentissement haut (WinchSlowdownDistanceTop_M), puis
             signaler la correction à l'IHM.
   📄 Doc : DOC/WFLOW/AUDITS/DESIGN/PLAN_T330_C3_INVARIANT_HAUT_v1.0.md (plan C3 v1.3, §2/§4)
            DOC/WFLOW/AUDITS/DESIGN/CADRAGE_T330_INVARIANT_HAUT_v1.0.md
   🛡️ Sécurité : une valeur de réglage HORS DOMAINE resterait hors domaine
             indéfiniment sans ce bloc (contre-exemple Q21 bis : FDC=9,50 m +
             TOP=12,00 m, où Δ=2,50 m ≥ 1,00 m n'active AUCUNE règle Δ).
             ⇒ R0 (clamp absolu) est INCONDITIONNELLE et EN AMONT de la règle Δ.
             Ce FB ne commande AUCUN mouvement : il corrige de la configuration.
   🧩 Dépendances : ST_WinchCfg (CfgTopSensorPos_M) · ST_CommunCfg
             (CfgCableLimitAscent_M, WinchSlowdownDistanceTop_M).
   ⚠️ Ordre d'appel : AVANT les ponts de persistance (PRG_07_Supervision §2).
             Le pont écrit la valeur CORRIGÉE dans le MÊME scan (option A / Q23)
             ⇒ aucune fenêtre NVRAM. Les mémoires internes sont amorcées depuis
             ces valeurs RESTAURÉES, jamais depuis les défauts du DUT (piège P2).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK FB_CfgT330Normalizer
VAR_INPUT
    // === CONTRAT STANDARD (Enable) ===
    Enable              : BOOL;  // 🟢 Autorise la normalisation (ponts de config RESTAURÉS)

    // === CONTEXTE MACHINE ===
    InHoming            : BOOL;  // 🎯 Homing en cours : cycle machine COMPLET (HX0..HX6) OU transaction de preset, M1 ou M2
END_VAR

VAR_IN_OUT
    // === RÉGLAGES HAUT À NORMALISER (référence — jamais de copie) ===
    WinchCfgM1          : ST_WinchCfg;   // 🔧 M1 = MAÎTRE du capteur haut : porte CfgTopSensorPos_M
    CommunCfg           : ST_CommunCfg;  // 🔧 Commun M1/M2 : porte CfgCableLimitAscent_M + WinchSlowdownDistanceTop_M
END_VAR

VAR_OUTPUT
    // === CONTRAT STANDARD (Ready) ===
    Ready               : BOOL;  // 🟢 Normalisation armée ce scan (Enable ET mémoires amorcées)

    // === DIAGNOSTIC / IHM ===
    Corrected           : BOOL;  // 🔧 Une correction T330 a eu lieu CE scan (impulsion d'un seul scan)
    CorrectedHeld       : BOOL;  // 🔧 Maintien du message T330 (fenêtre IHM — 1 scan serait invisible)
END_VAR

VAR CONSTANT
    // === T330 (Q1/Q2) — RÈGLES D'INGÉNIERIE, PAS DES COTES MÉTIER ===
    // NON persistantes et NON IHM (AC3) : jamais exposées, jamais RETAIN.
    CST_T330ReserveMinMargin_M : REAL := 1.00;   // Réserve minimale FDC logiciel haut / TOP homing
    CST_T330SlowdownTopMin_M   : REAL := 0.50;   // Plancher du ralentissement haut (Q1)
    CST_T330FdcMin_M           : REAL := 0.00;   // Borne basse FDC (Q21)
    CST_T330FdcMax_M           : REAL := 9.00;   // Borne haute FDC (Q21/C1 : TOP<=10 et Delta>=1 => FDC<=9)
    CST_T330TopMin_M           : REAL := 1.00;   // Borne basse TOP (Q21)
    CST_T330TopMax_M           : REAL := 10.00;  // Borne haute TOP (Q21)
END_VAR

VAR
    // === T330 — MÉMOIRES NON PERSISTANTES (AC3 : ni IHM, ni RETAIN) ===
    T330PrevInit               : BOOL;  // . [LOC] Seed des mémoires effectué depuis les valeurs RESTAURÉES
    T330PrevTopSensorPos_M     : REAL;  // . [LOC] Valeur précédente TOP (détection du champ modifié par l'opérateur)
    T330PrevCableLimitAscent_M : REAL;  // . [LOC] Valeur précédente FDC (détection du champ modifié par l'opérateur)
    T330MsgHold                : TOF;   // . [LOC] Maintien du message T330 (un scan de 10 ms serait invisible à l'IHM)
END_VAR


// ═══════════════════════════════════════════════════════════════════════════════
// 🔧 T330 — COHÉRENCE DES RÉGLAGES HAUT (Q1/Q2) · plan C3 v1.3
// ───────────────────────────────────────────────────────────────────────────────
// ORDRE IMPOSÉ (Q21 bis) :  (1) R0 clamp ABSOLU inconditionnel, FDC et TOP séparément
//                        puis (2) règle Delta >= 1,00 m / slowdown >= 0,50 m.
// OPTION A (Q23) : ce bloc s'exécute AVANT les ponts de persistance, qui écrivent la
//                  valeur CORRIGÉE dans le MÊME scan (aucune fenêtre NVRAM). La
//                  référence est donc lue sur GVL_IHM.Cfg — l'état que les ponts
//                  tiennent à jour, et NON directement la NVRAM.
// AC3 : AUCUNE variable persistante ni IHM nouvelle — constantes CST_* et mémoires
//       locales uniquement. Jamais de champ de fin de course supplémentaire.
// C2/Q22 : R2 (correction du TOP) est INHIBÉE pendant le homing — sur le CYCLE COMPLET
//          (HX0..HX6), pas seulement la transaction de preset (~50 ms). Aucune mémoire
//          d'intention : au retour, si la config est toujours invalide, le REPLI NIVEAU
//          ci-dessous applique Q17 (préserver le TOP, corriger le FDC).
// ═══════════════════════════════════════════════════════════════════════════════
{region "🔧 T330 NORMALISATION"}
Corrected := FALSE;
Ready := FALSE;

// Inhibée tant que les ponts n'ont pas RESTAURÉ (sinon les défauts DUT seraient pris
// pour une saisie opérateur — piège P2 du cadrage).
IF Enable THEN

    // Seed des mémoires depuis les valeurs RESTAURÉES (jamais depuis les défauts DUT).
    IF NOT T330PrevInit THEN
        T330PrevTopSensorPos_M     := WinchCfgM1.CfgTopSensorPos_M;
        T330PrevCableLimitAscent_M := CommunCfg.CfgCableLimitAscent_M;
        T330PrevInit               := TRUE;
    END_IF;

    Ready := TRUE;

    // ─── GEL PENDANT LE HOMING (décision C2 b : « NVRAM gelée — AUCUNE écriture Cfg ») ──
    // Toutes les écritures ci-dessous (R0, R3, R1, R2) sont suspendues pendant le homing.
    // ⚠️ Ce gel couvre R1/R0/R3 AUSSI : une correction pendant un homing déplacerait la CIBLE
    // de homing (R0/R2) ou détruirait le réglage commissionné (R1) et le persisterait.
    // ⇒ À la sortie du homing, les mémoires ont suivi la saisie (bloc ci-dessous, hors gel) :
    //    il n'y a plus de FRONT, donc le REPLI NIVEAU applique R1 = Q17 (préserver le TOP). C'est
    //    exactement la décision 2c : « rien à mémoriser, on retombe dans le cas normal Q2 ».
    IF NOT InHoming THEN

    // ─── (1) R0 — CLAMP ABSOLU (Q21 bis) : non conditionné à une violation de Delta ──────
    // ⚠️ « INCONDITIONNEL » au sens de Q21 bis = non subordonné à la règle Delta. Le gel
    //    homing ci-dessus reste prioritaire (décision C2 b, motivée sécurité).
    IF CommunCfg.CfgCableLimitAscent_M < CST_T330FdcMin_M THEN
        CommunCfg.CfgCableLimitAscent_M := CST_T330FdcMin_M;
        Corrected := TRUE;
    ELSIF CommunCfg.CfgCableLimitAscent_M > CST_T330FdcMax_M THEN
        CommunCfg.CfgCableLimitAscent_M := CST_T330FdcMax_M;
        Corrected := TRUE;
    END_IF;
    IF WinchCfgM1.CfgTopSensorPos_M < CST_T330TopMin_M THEN
        WinchCfgM1.CfgTopSensorPos_M := CST_T330TopMin_M;
        Corrected := TRUE;
    ELSIF WinchCfgM1.CfgTopSensorPos_M > CST_T330TopMax_M THEN
        WinchCfgM1.CfgTopSensorPos_M := CST_T330TopMax_M;
        Corrected := TRUE;
    END_IF;

    // ─── (2) R3 — plancher du ralentissement haut ───────────────────────────────────────
    IF CommunCfg.WinchSlowdownDistanceTop_M < CST_T330SlowdownTopMin_M THEN
        CommunCfg.WinchSlowdownDistanceTop_M := CST_T330SlowdownTopMin_M;
        Corrected := TRUE;
    END_IF;

    // ─── (3) R1 / R2 — règle Delta >= 1,00 m sur les valeurs CLAMPÉES ───────────────────
    // Détection du champ MODIFIÉ : M1 (maître) et FDC commun uniquement.
    // ⛔ JAMAIS le champ M2 : il est RÉÉCRIT chaque scan par le miroir M1 (PRG_07_Supervision).
    IF (WinchCfgM1.CfgTopSensorPos_M
        - CommunCfg.CfgCableLimitAscent_M) < CST_T330ReserveMinMargin_M THEN
        IF (WinchCfgM1.CfgTopSensorPos_M <> T330PrevTopSensorPos_M)
           AND (CommunCfg.CfgCableLimitAscent_M = T330PrevCableLimitAscent_M) THEN
            // R2 — le TOP vient d'être saisi : corriger le TOP, sauf pendant le homing (C2/Q22).
            // ⚠️ Ce test est structurellement TOUJOURS VRAI ici (le gel homing englobe déjà le
            //    bloc) : il est CONSERVÉ comme marqueur nommé de la décision C2/Q22, pour qu'un
            //    déplacement futur du gel ne puisse pas réactiver R2 pendant un homing en silence.
            IF NOT InHoming THEN
                WinchCfgM1.CfgTopSensorPos_M :=
                    CommunCfg.CfgCableLimitAscent_M + CST_T330ReserveMinMargin_M;
                Corrected := TRUE;
            END_IF;
        ELSE
            // R1 (et Q17 : les deux champs ont changé, ou aucun) — PRÉSERVER le TOP,
            // corriger le FDC. C'est aussi le REPLI NIVEAU à la sortie du homing.
            CommunCfg.CfgCableLimitAscent_M :=
                WinchCfgM1.CfgTopSensorPos_M - CST_T330ReserveMinMargin_M;
            Corrected := TRUE;
        END_IF;
    END_IF;   // fin de la règle Delta (R1/R2)
    END_IF;   // ─── fin du GEL HOMING (décision C2 b) : plus aucune écriture Cfg pendant le homing

    // ─── Mémoires de front (HORS gel : suivies MÊME pendant le homing) ──────────────────
    // Indispensable : à la sortie du homing la saisie opérateur n'est plus un FRONT, donc le
    // REPLI NIVEAU ci-dessus applique R1 = Q17 (préserver le TOP, corriger le FDC). C'est la
    // décision 2c : « rien à mémoriser, on retombe dans le cas normal Q2 ».
    T330PrevTopSensorPos_M     := WinchCfgM1.CfgTopSensorPos_M;
    T330PrevCableLimitAscent_M := CommunCfg.CfgCableLimitAscent_M;

ELSE
    // Ponts non restaurés : aucune écriture Cfg, aucune mémoire amorcée.
    Ready := FALSE;
END_IF;

// Maintien IHM : une correction dure UN scan (10 ms) -> sans maintien le message serait
// invisible. TOF = conserve Q VRAI pendant PT après retombée de IN (fenêtre de maintien).
// Appelé à CHAQUE scan, y compris normalisation inhibée (la fenêtre doit pouvoir retomber).
T330MsgHold(IN := Corrected, PT := T#500ms);
CorrectedHeld := T330MsgHold.Q;
{endregion}
END_FUNCTION_BLOCK
