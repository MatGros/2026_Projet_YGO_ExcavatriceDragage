(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_WinchHMI — Données d'échange IHM pour un treuil (M1: moteur de retenue / M2: moteur Benne)
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des bargraphes, LEDs, mesures et réglages.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_WinchHMI :
STRUCT
    (* ⚙️ Paramètres / Calibration (Lecture/Écriture) *)
    TopSensorPositionM      : REAL := 12.5;     (* 📐 Position cible du capteur haut (m) *)
    MaxStepDescente         : INT := 3;         (* 🛑 Limitation palier vitesse en descente (1..5) — 🔧 REX 2026-07-08 :
                                                    commun M1/M2 (même profil de déplacement), miroir bidirectionnel
                                                    GVL_PERSISTENT.WinchMaxStepDescente (voir PRG_09_Supervision),
                                                    même principe que CableLimitDescentM/SlowdownDistanceM/SlowSpeedPct *)
    RampAccelRate           : REAL := 50.0;     (* 📈 Rampe d'accélération (%/s) *)
    RampDecelNormalRate     : REAL := 150.0;    (* 📉 Rampe de décélération normale (%/s) *)
    RampDecelFastRate       : REAL := 400.0;    (* ⚡ Rampe de décélération rapide / SafeStop (%/s) *)
    CableLimitDescentM      : REAL := -20.0;    (* 📐 Limite basse physique de descente (m, négatif) *)
    CableLimitAscentM       : REAL := 12.0;     (* 📐 REX 2026-07-15 (6) : limite haute d'exploitation NORMALE (m) —
                                                    distincte de TopSensorPositionM (12.5m, réservé au Homing) *)
    SlowdownDistanceM       : REAL := 1.0;      (* 📏 Distance avant limite pour enclencher le ralentissement (m) *)
    SlowSpeedPct            : REAL := 15.0;     (* 📉 Vitesse de consigne lente dans la zone de ralentissement (%) *)

    (* 🚦 États & Mesures (Lecture seule) *)
    PositionM               : REAL;             (* 📊 Position actuelle du câble (mètres) *)
    SpeedRefPct             : REAL;             (* 📈 Consigne de vitesse finale après rampe (%) *)
    StepNumber              : INT;              (* 🔢 Palier de vitesse actif (0..5) *)
    FBState                 : E_State;          (* 🤖 État de l'automate interne (FB_Winch) *)
    Ready                   : BOOL;             (* 🟢 Treuil prêt à fonctionner *)
    Busy                    : BOOL;             (* ⚙️ Mouvement en cours *)
    Done                    : BOOL;             (* ✅ Action terminée *)
    Error                   : BOOL;             (* 🔴 Treuil en défaut *)
    ErrorId                 : WORD;             (* ❌ Code bitfield du défaut treuil *)
    
    (* 🔌 Sorties Physiques / Indicateurs LEDs *)
    RelayFwd                : BOOL;             (* 🛗 Relais Montée activé *)
    RelayRev                : BOOL;             (* 🛗 Relais Descente activé *)
    Contactor1              : BOOL;             (* 🔌 Contacteur vitesse palier 1 *)
    Contactor2              : BOOL;             (* 🔌 Contacteur vitesse palier 2 *)
    Contactor3              : BOOL;             (* 🔌 Contacteur vitesse palier 3 *)
    Contactor4              : BOOL;             (* 🔌 Contacteur vitesse palier 4 *)
    BrakeCmd                : BOOL;             (* 🔓 Commande frein (TRUE = desserré / libre) *)
    
    (* 🛡️ Sécurités & Diagnostics *)
    Homed                   : BOOL;             (* 🎯 Prise d'origine (Homing) validée *)
    SafeStopActive          : BOOL;             (* 🟧 Arrêt rapide activé par la sécurité *)
    ForbidDescentActive     : BOOL;             (* 🚯 Descente interdite (détecteur mou de câble / limites) *)
    ForbidAscentActive      : BOOL;             (* 🚯 Montée interdite (fin de course haut) *)
    SlackCableDetected      : BOOL;             (* ⚠️ Mou de câble physiquement détecté *)
    ThermalFault            : BOOL;             (* 🔥 Défaut surchauffe thermique moteur *)
    EncoderFault            : BOOL;             (* 🔌 Perte de liaison ou incohérence codeur *)
    CableLimitDescentReached: BOOL;             (* ⚠️ Longueur max de câble atteinte (limite basse physique) *)
    CableLimitAscentReached : BOOL;             (* ⚠️ REX 2026-07-15 (8) : limite haute d'exploitation normale atteinte (CableLimitAscentM) *)
    Encoder                 : ST_EncoderHMI;    (* 🧲 Données d'échange et diagnostic du codeur *)
    
    (* 🔍 Diagnostics de cohérence contacteurs réutilisés *)
    ContactorsCheck         : ST_ContactorCheck; (* 🔌 REX 2026-07-07 : coherence contacteurs sens+vitesse
                                                     fusionnée (retour unique matériel) — StuckOpen inutilisé,
                                                     remplace FwdContactorCheck/RevContactorCheck *)
    BrakeContactorCheck     : ST_ContactorCheck; (* 🔌 Coherence retour frein *)

    (* 🎮 Commandes Opérateur (Boutons tactiles) *)
    CmdReset                : BOOL;             (* 🔑 Acquittement défauts spécifique treuil *)
    CmdHome                 : BOOL;             (* 🎯 Lancement de la prise d'origine *)
    ConfirmCoherence        : BOOL;             (* 🔓 Confirmation de cohérence au démarrage *)
    CmdInhibit              : BOOL;             (* 🆕 REX 2026-07-08 : bouton IHM inhibition treuil — mise en service,
                                                    UNIQUEMENT actif si MAINT_N2 (voir FB_Modes.InhibitM1/M2) *)

    (* 🐞 Bypasses de Test (Visualisation / Forçage) *)
    BypassContactorFeedback : BOOL;             (* 🔌 Bypass retours contacteurs (banc de test) *)
    BypassSlackCable        : BOOL;             (* ⚠️ Bypass capteur mou de câble (banc de test) *)
    BypassTopPositionSensor : BOOL;             (* 📐 Bypass capteur position haute (banc de test) *)
    SafetyError             : BOOL;             (* 🛡️ Bloc sécurité (Safety) en défaut *)
    SafetyErrorId           : WORD;             (* ❌ Code bitfield du défaut de sécurité *)
    InhibitActive           : BOOL;             (* 🆕 REX 2026-07-08 : miroir lecture seule — confirme que
                                                    l'inhibition a bien été arbitrée (actif seulement si MAINT_N2) *)
    MecaADriftM             : REAL;             (* 🆕 REX 2026-07-08 : dérive mesurée Méca A (m) — réglage UncommandedDriftToleranceM *)
    MecaCDriftM             : REAL;             (* 🆕 REX 2026-07-08 : dérive mesurée Méca C (m, benne M1) — réglage BenneSlipToleranceM *)
    MecaBElapsedTime        : TIME;             (* 🆕 REX 2026-07-08 : temps écoulé confirmation contacteurs/frein — réglage PostRampTimeout *)
END_STRUCT
END_TYPE
