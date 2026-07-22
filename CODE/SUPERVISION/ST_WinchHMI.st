(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_WinchHMI — Données d'échange IHM pour un treuil (M1: moteur de retenue / M2: moteur Benne)
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des bargraphes, LEDs, mesures et réglages.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_WinchHMI :
STRUCT
    (* ⚙️ Paramètres / Calibration (Lecture/Écriture) *)
    CfgTopSensorPosM       : REAL := 8.5;      (* 📐 Position cible du capteur haut (m) *)
    CfgHomingTargetM            : REAL := 0.0;      (* 🔧 Cible libre Homing unitaire MAINT_N2 [-99..+99 m] *)
    CfgMaxStepDescente         : INT := 3;         (* 🛑 Limitation palier vitesse en descente (1..5) — 🔧 REX 2026-07-08 :
                                                    commun M1/M2 (même profil de déplacement), miroir bidirectionnel
                                                    _WinchMaxStepDescent (voir PRG_09_Supervision),
                                                    même principe que CableLimitDescent_M/SlowdownDistance_M/SlowSpeed_Pct *)
    CfgRampAccelRate           : REAL := 50.0;     (* 📈 Rampe d'accélération (%/s) *)
    CfgRampDecelNormalRate     : REAL := 150.0;    (* 📉 Rampe de décélération normale (%/s) *)
    CfgRampDecelFastRate       : REAL := 400.0;    (* ⚡ Rampe de décélération rapide / SafeStop (%/s) *)
    CfgCableLimitDescentM       : REAL := -20.0;    (* 📐 Limite basse physique de descente (m, négatif) *)
    CfgCableLimitAscentM        : REAL := 8.0;      (* 📐 REX 2026-07-15 (6) : limite haute d'exploitation NORMALE (m) *)
    CfgSlowdownDistanceM        : REAL := 1.0;      (* 📏 Distance avant limite pour enclencher le ralentissement (m) *)
    CfgSlowSpeedPct             : REAL := 15.0;     (* 📉 Vitesse de consigne lente dans la zone de ralentissement (%) *)

    (* 🚦 États & Mesures (Lecture seule) *)
    PositionM                : REAL;             (* 📊 Position actuelle du câble (mètres) *)
    MeasuredSpeedMps         : REAL;             (* 📏 Vitesse linéaire mesurée du câble (m/s), valeur absolue *)
    SpeedDeltaMps            : REAL;             (* 🔍 Variation de vitesse entre deux scans (m/s) *)
    SpeedVariationDetected   : BOOL;            (* 🔍 Seuil de variation dépassé sur le scan courant *)
    SpeedVariationConfirmed  : BOOL;            (* 🛡️ Variation confirmée pendant la durée paramétrée *)
    SpeedStable               : BOOL;            (* 🟢 Vitesse stable pendant la durée paramétrée *)
    SpeedMonitorError        : BOOL;             (* 🔴 Défaut mémorisé du moniteur vitesse *)
    SpeedMonitorErrorId      : WORD;             (* ❌ Bitfield du moniteur vitesse *)
    EstimatedLoadPct          : REAL;             (* 📊 Estimation empirique, non certifiée *)
    LoadEstimateConfigured    : BOOL;             (* 🟢 Table charge validée pour lecture *)
    SpeedGuardLimited         : BOOL;             (* 🛡️ Palier limité par vitesse réelle *)
    SpeedRefPct              : REAL;             (* 📈 Consigne de vitesse finale après rampe (%) *)
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
    HomingBusy              : BOOL;             (* ⏳ Référencement en cours *)
    HomingDone              : BOOL;             (* ✅ Pulse de référencement réussi *)
    HomingError             : BOOL;             (* 🔴 Défaut de référencement *)
    HomingErrorId           : WORD;             (* ❌ Bitfield défaut homing *)
    HomingState             : E_State;          (* 🤖 État FB_Encoder_Homing *)
    HomingStateAtError      : E_State;          (* 🧭 État lors du défaut *)
    HomingSuspect            : BOOL;             (* ⚠️ Référence à confirmer *)
    HomingRefRaw             : UDINT;            (* 📐 Référence brute appliquée *)
    SafeStopActive          : BOOL;             (* 🟧 Arrêt rapide activé par la sécurité *)
    ForbidDescentActive     : BOOL;             (* 🚯 Descente interdite (détecteur mou de câble / limites) *)
    ForbidAscentActive      : BOOL;             (* 🚯 Montée interdite (fin de course haut) *)
    SlackCableDetected      : BOOL;             (* ⚠️ Mou de câble physiquement détecté *)
    ThermalFault            : BOOL;             (* 🔥 Défaut surchauffe thermique moteur *)
    EncoderFault            : BOOL;             (* 🔌 Perte de liaison ou incohérence codeur *)
    SensorEncoderFaultBypassActive: BOOL;             (* 🔧 Bypass codeur effectivement accepté, uniquement MAINT_N2 *)
    CableLimitDescentReached: BOOL;             (* ⚠️ Longueur max de câble atteinte (limite basse physique) *)
    CableLimitAscentReached : BOOL;             (* ⚠️ REX 2026-07-15 (8) : limite haute d'exploitation normale atteinte (CableLimitAscent_M) *)
    Encoder                 : ST_EncoderHMI;    (* 🧲 Données d'échange et diagnostic du codeur *)
    
    (* 🔍 Diagnostics de cohérence contacteurs réutilisés *)
    ContactorsCheck         : ST_ContactorCheck; (* 🔌 REX 2026-07-07 : coherence contacteurs sens+vitesse
                                                     fusionnée (retour unique matériel) — StuckOpen inutilisé,
                                                     remplace FwdContactorCheck/RevContactorCheck *)
    BrakeContactorCheck     : ST_ContactorCheck; (* 🔌 Coherence retour frein *)

    (* 🎮 Commandes Opérateur (Boutons tactiles) *)
    // 🆕 REX (session WINCH-BTN-01) — mouvement direct MAINTENU (tant qu'appuye, relachement =
    // arret rampe normale), JAMAIS impulsionnel. Actif seulement si GVL_IHM.Modes.TglJoystickMaster
    // =FALSE (source boutons) ET ce treuil selectionne par SelJoystickWinch (M1/M2/Couple, deja
    // arbitre par FB_Modes) ET homme-mort joystick reel arme (DeadmanArmed, comme le joystick).
    // Voir DOC/AUDITS/WinchIhmButtons/REGISTRE_ACTIONS_WinchIhmButtons_v1.0.md.
    BtnUp                   : BOOL;             (* ⬆️ Mouvement montee maintenu (mode boutons IHM, MAINT_N1 accessible) *)
    BtnDown                 : BOOL;             (* ⬇️ Mouvement descente maintenu (mode boutons IHM, MAINT_N1 accessible) *)
    BtnReset                : BOOL;             (* 🔑 Demande reset exposée par treuil ; agrégée dans le reset domaine partagé *)
    BtnHome                 : BOOL;             (* 🎯 Homing nominal si Couplé, unitaire si M1/M2 sélectionné en MAINT_N2 *)
    BtnConfirmCoherence     : BOOL;             (* 🔓 Confirmation de cohérence au démarrage *)
    BtnInhibit              : BOOL;             (* 🆕 REX 2026-07-08 : bouton IHM inhibition treuil — mise en service,
                                                    UNIQUEMENT actif si MAINT_N2 (voir FB_Modes.InhibitM1/M2) *)

    (* 🔧 Bypass maintenance (dedie a CE treuil — voir DOC/AUDITS/Bypass/REGISTRE_ACTIONS_Bypass_v1.0.md) *)
    Bypass : ST_BypassWinch;             (* EncoderFault, ContactorFeedback — propre a M1 ou M2 *)

    (* 🐞 Diagnostics *)
    SafetyError             : BOOL;             (* 🛡️ Bloc sécurité (Safety) en défaut *)
    SafetyErrorId           : WORD;             (* ❌ Code bitfield du défaut de sécurité *)
    InhibitActive           : BOOL;             (* 🆕 REX 2026-07-08 : miroir lecture seule — confirme que
                                                    l'inhibition a bien été arbitrée (actif seulement si MAINT_N2) *)
    MecaADriftM              : REAL;             (* 🆕 REX 2026-07-08 : dérive mesurée Méca A (m) — réglage UncommandedDriftToleranceM *)
    MecaCDriftM              : REAL;             (* 🆕 REX 2026-07-08 : dérive mesurée Méca C (m, benne M1) — réglage BenneSlipToleranceM *)
    MecaBElapsedTime        : TIME;             (* 🆕 REX 2026-07-08 : temps écoulé confirmation contacteurs/frein — réglage PostRampTimeout *)
END_STRUCT
END_TYPE
