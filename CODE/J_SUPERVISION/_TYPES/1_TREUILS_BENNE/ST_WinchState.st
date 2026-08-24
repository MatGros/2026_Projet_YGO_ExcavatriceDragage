(* ═══════════════════════════════════════════════════════════════
   🚦 ST_WinchState — États, mesures et diagnostics HMI pour un Treuil M1/M2
   ───────────────────────────────────────────────────────────────
   🎨 Destiné aux retours d'informations et bargraphes HMI.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_WinchState :
STRUCT
    (* 🚦 États & Mesures (Lecture seule) *)
    Position_M              : REAL;             (* 📊 Position actuelle du câble (mètres) *)
    MeasuredSpeed_Mps       : REAL;             (* 📏 Vitesse linéaire mesurée du câble (m/s), valeur absolue *)
    SpeedDelta_Mps          : REAL;             (* 🔍 Variation de vitesse entre deux scans (m/s) *)
    SpeedVariationDetected  : BOOL;             (* 🔍 Seuil de variation dépassé sur le scan courant *)
    SpeedVariationConfirmed : BOOL;             (* 🛡️ Variation confirmée pendant la durée paramétrée *)
    SpeedStable             : BOOL;             (* 🟢 Vitesse stable pendant la durée paramétrée *)
    SpeedMonitorError       : BOOL;             (* Défaut mémorisé du moniteur vitesse *)
    SpeedMonitorErrorId     : WORD;             (* ❌ Bitfield du moniteur vitesse *)
    EstimatedLoadPct        : REAL;             (* 📊 Estimation empirique, non certifiée *)
    LoadEstimateConfigured  : BOOL;             (* 🟢 Table charge validée pour lecture *)
    SpeedGuardLimited       : BOOL;             (* 🛡️ Palier limité par vitesse réelle *)
    SpeedRef_Pct            : REAL;             (* 📈 Consigne de vitesse finale après rampe (%) *)
    StepNumber              : INT;              (* 🔢 Palier de vitesse actif (0..5) *)
    FBState                 : E_State;          (* 🤖 État de l'automate interne (FB_Winch) *)
    Ready                   : BOOL;             (* 🟢 Treuil prêt à fonctionner *)
    Busy                    : BOOL;             (* ⚙️ Mouvement en cours *)
    Done                    : BOOL;             (* ✅ Action terminée *)
    Error                   : BOOL;             (* Treuil en défaut *)
    ErrorId                 : WORD;             (* ❌ Code bitfield du défaut treuil *)

    (* 🔌 Sorties Physiques / Indicateurs LEDs *)
    RelayFwd                : BOOL;             (* 🛗 Relais Montée activé *)
    RelayRev                : BOOL;             (* 🛗 Relais Descente activé *)
    Contactor1              : BOOL;             (* 🔌 Contacteur vitesse palier 1 *)
    Contactor2              : BOOL;             (* 🔌 Contacteur vitesse palier 2 *)
    Contactor3              : BOOL;             (* 🔌 Contacteur vitesse palier 3 *)
    Contactor4              : BOOL;             (* 🔌 Contacteur vitesse palier 4 *)
    BrakeCmd                : BOOL;             (* 🔓 Commande frein (TRUE = desserré / libre) *)
    FinalInterlockState     : E_WinchFinalInterlockState; (* 🛡️ État final lecture seule *)
    FinalInterlockReason    : E_WinchFinalInterlockReason; (* 🛡️ Cause finale mémorisée *)
    FinalInterlockError     : BOOL;             (* 🛡️ Défaut final mémorisé *)
    FinalInterlockErrorId   : WORD;             (* 🛡️ Bitfield final *)
    FinalRestartInhibit     : BOOL;             (* 🔒 Reset + neutre + nouvelle demande obligatoires *)
    BrakeCommandOpenConfirmed : BOOL;           (* 🔌 Contacteur/bobine desserrage confirmé, pas frein mécanique *)
    FinalAuthorizedStep     : INT;              (* 🪜 Palier réellement autorisé *)
    FinalBrakeTimeoutElapsed : TIME;            (* ⏱️ Écoulé watchdog 500ms *)
    FinalRestartDelayElapsed : TIME;            (* ⏱️ Écoulé verrou redémarrage 900ms *)
    FinalStepDelayElapsed    : TIME;            (* ⏱️ Écoulé entre paliers 1s250 *)

    (* 🛡️ Sécurités & Diagnostics *)
    Encoder                 : ST_EncoderHMI;    (* 🧲 Données d'échange et diagnostic du codeur — porte aussi les 9 champs Homing* (voir ST_EncoderHMI) *)

    (* 🔍 Diagnostics de cohérence contacteurs réutilisés *)
    ContactorsCheck         : ST_ContactorCheck; (* 🔌 Coherence contacteurs sens+vitesse *)
    BrakeContactorCheck     : ST_ContactorCheck; (* 🔌 Coherence retour frein *)
    InhibitActive           : BOOL;             (* miroir lecture seule — inhibition arbitrée *)

    (* 🐢 : ralentissement sur bordure — diagnostic zone/limite active *)
    BottomLimitActiveM      : REAL;             (* 📏 Limite basse active (m) — câble physique OU légale, la plus restrictive *)
    InTopSlowdownZone       : BOOL;             (* 🐢 Palier plafonné à 1 : approche limite haute *)
    InBottomSlowdownZone    : BOOL;             (* 🐢 Palier plafonné à 1 : approche limite basse (câble ou légale) *)

    (* 🩺 Diagnostic délai ressenti à la remontée *)
    CommandedDirection        : INT;            (* 🩺 Sens interne mémorisé FB_Winch (-1/0/+1) *)
    DirectionChangeDelayElapsed : TIME;         (* 🩺 Écoulé de l'interlock changement/reprise de sens *)
    DirectionChangePending      : BOOL;         (* 🩺 TRUE tant que CommandedDirection n'a pas rejoint Direction *)
END_STRUCT
END_TYPE
