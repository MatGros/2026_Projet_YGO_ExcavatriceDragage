(* ═══════════════════════════════════════════════════════════════
   🧲 GVL_Encoder_Stub — Variables IHM/paramètres codeurs COD1 (M1) + COD2 (M2)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie10_Fonction_Encoder_Homing_v1.6.md §5/§7bis
   🎯 Regroupe TOUT ce qui doit être mappé IHM ou réglé pour le pipeline
      codeur/homing (un seul endroit à consulter en mise en service) :
      - Boutons IHM (front) : Reset (acquittement), ConfirmCoherence,
        Home (partagé M1+M2 — référencement simultané, Partie10 §1).
      - Paramètre RETAIN : TopSensorPositionM (cible homing nominal, m).
   ⚠️ `M1_Reset_IHM`/`M2_Reset_IHM` acquittent LES DEUX FB de ce codeur
      (`instEncoderAbsMx` + `instHomingMx`) — même principe que le
      "bouton général" décrit en Partie3 §5, mais scindé par codeur
      pour ce lot (plus simple à tester en mise en service). À
      généraliser en bouton machine unique quand `FB_Modes`/IHM existera.
   🔴 TOUJOURS STUB (pas de vrai bouton IHM câblé) : basculer TRUE puis
      FALSE dans la vue instance CODESYS pour simuler un appui (front).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_Encoder_Stub) ===

VAR_GLOBAL
    // 🔑 Reset — acquittement défauts instEncoderAbsMx + instHomingMx (front)
    M1_Reset_IHM             : BOOL;   // 🖥️ À mapper bouton IHM — acquitte COD1 (Abs + Homing)
    M2_Reset_IHM             : BOOL;   // 🖥️ À mapper bouton IHM — acquitte COD2 (Abs + Homing)

    // 🔓 ConfirmCoherence — lève le doute redémarrage (Partie10 §3.7, front)
    M1_ConfirmCoherence_IHM  : BOOL;   // 🖥️ À mapper bouton IHM dédié COD1
    M2_ConfirmCoherence_IHM  : BOOL;   // 🖥️ À mapper bouton IHM dédié COD2

    // 🎯 Mode homing — 2026-07-03 : sélecteur pour exploitation vs maintenance
    HomingMode_IHM           : INT := 3;   // 🖥️ 1=M1seul, 2=M2seul, 3=Both(normal exploitation)

    // 🎯 Home — bouton UNIQUE (action selon HomingMode_IHM)
    StubHomeButton_IHM       : BOOL;   // 🖥️ À mapper bouton IHM — commande Home M1/M2/Both selon mode
END_VAR

VAR_GLOBAL RETAIN
    // 🎯 Cible de homing nominal — paramétrable PAR TREUIL (Partie10 §7bis).
    // 🖥️ IHM : valeur en MÈTRES au-dessus du niveau d'eau, ajustée via la procédure
    // de calibration (Partie10 §7bis) — c'est LE paramètre qui rend le homing utilisable.
    M1_TopSensorPositionM    : REAL := 12.5;
    M2_TopSensorPositionM    : REAL := 12.5;
END_VAR
