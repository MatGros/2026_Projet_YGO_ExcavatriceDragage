(* ═══════════════════════════════════════════════════════════════
   🚦 ST_CycleState — États et diagnostics IHM du cycle semi-automatique
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleState :
STRUCT
    Ready                  : BOOL;        (* 🟢 Séquenceur prêt *)
    Busy                   : BOOL;        (* ⚙️ Cycle en cours *)
    Done                   : BOOL;        (* ✅ Cycle terminé *)
    Error                  : BOOL;        (* Défaut cycle actif ou mémorisé, à acquitter *)
    ErrorId                : WORD;        (* ❌ Code affiché : actif, ou latched après repli AX_STAB *)
    CycleStep              : E_AutoCycleStep; (* 🔄 Étape courante du Grafcet *)
    CycleStateStr          : STRING(80);  (* 📝 Libellé texte de l'étape courante *)
    SelTarget              : INT;         (* 🎯 Miroir lecture seule de GVL_IHM.M3Translation.Cmd.SelTarget *)
    KoboldContactFond      : BOOL;        (* 🔌 Fond confirmé par Kobold uniquement *)
    PositionFondAtteinte    : BOOL;        (* 📐 Fond confirmé par limite de travail/consigne *)
    KoboldContactorCmd     : BOOL;        (* 🔌 Commande contacteur Kobold (calculée par FB_Cycle) *)
    LimitLegalReached      : BOOL;        (* 📐 Miroir de GVL_IHM.Commun.LimitLegalReached *)
    LimitLegalDepth_M      : REAL;        (* 📐 Miroir de GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M *)
    WinchSyncError         : BOOL;        (* ⚖️ Miroir de l'erreur synchro M1/M2 *)
    WinchSyncDelta_M       : REAL;        (* ⚖️ Miroir de l'écart synchro M1/M2 *)
    SpeedMismatch_Mps      : REAL;        (* 🐢 Écart de vitesse mesuré  *)
    SpeedMismatchActive    : BOOL;        (* 🐢 Écart de vitesse détecté *)
    SpeedMismatchConfirmed : BOOL;        (* 🐢 Écart de vitesse confirmé *)
    M1Position_M           : REAL;        (* 📊 Position câble M1 *)
    M2Position_M           : REAL;        (* 📊 Position câble M2 *)
    DeadmanArmed           : BOOL;        (* 🔫 Homme-mort joystick armé *)
    JoystickDeflected      : BOOL;        (* 🕹️ Joystick défléchi (non centré) — même signal que JoystickDeflected (FB_Cycle) ; SANS homme-mort *)
    CycleStepAtError       : E_AutoCycleStep; (* 🧊 Étape spécifique au moment du défaut  *)
    SampleCount            : INT;         (* Compteur de prélèvements (RETAIN, Q3bis) *)
    (* ⚠️ Inséré volontairement À CÔTÉ de SampleCount (regroupement sémantique des deux compteurs).
       ST_CycleState est une structure d'ÉCHANGE IHM volatile : elle n'est ni persistée ni
       mappée par position (aucune occurrence dans GVL_PERSISTENT) — l'ordre des champs y est
       donc libre, contrairement à ST_CycleCfg/ST_CycleCmd dont les ajouts vont en fin. *)
    SampleCountTotal       : UDINT;       (* 🔒 TOTALISATEUR de prélèvements (PERSISTENT) — LECTURE SEULE : jamais remis à zéro, aucune commande d'écriture *)
    (* ⏱️ Durées de cycle exposées IHM en 2 champs entiers (T347) : minutes illimitées + secondes 0..59.
       Le type TIME est abandonné côté IHM (affichage panel peu lisible) ; suffixes d'unité NC-030. *)
    CurrentCycleElapsed_Min : INT;        (* ⏱️ Minutes écoulées du cycle en cours *)
    CurrentCycleElapsed_S   : INT;        (* ⏱️ Secondes écoulées du cycle en cours (0..59) *)
    LastCycleDuration_Min   : INT;        (* ⏱️ Minutes du dernier cycle achevé (figées à X13) *)
    LastCycleDuration_S     : INT;        (* ⏱️ Secondes du dernier cycle achevé (figées à X13, 0..59) *)
    DrainTimeElapsed_S     : INT;         (* Compat IHM : tag historique conserve ; porte le temps restant AX13, secondes entieres ; 0 hors AX13 *)
    CycleChecksInhibited   : BOOL;        (* 🧪 Contrôles procédé cycle inhibés, protections machine actives *)
    IgnoredCycleCheckId    : WORD;        (* 🔎 Contrôles procédé actifs mais ignorés *)
    ForceStepAccepted      : BOOL;        (* ✅ Impulsion : consigne de forçage appliquée (saut d'étape effectif) *)
    ForceStepRejected      : BOOL;        (* ❌ Impulsion : consigne écartée (cible hors plage énum, ou cycle inactif) *)
    ForceStepResult        : STRING(120); (* 📝 Motif de rejet de la dernière consigne (vide après une consigne appliquée) *)
    ResumeAfterFaultAvailable : BOOL;    (* Reprise AX_STAB disponible apres disparition de la cause *)
END_STRUCT
END_TYPE
