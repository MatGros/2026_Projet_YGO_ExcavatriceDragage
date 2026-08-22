(* ═══════════════════════════════════════════════════════════════
   🛡️ ST_SafetyWinch — Diagnostics de sécurité pour un treuil
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des défauts de sécurité d'un treuil.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SafetyWinch :
STRUCT
    Error             : BOOL;    (* 🛡️ Bloc sécurité (Safety) en défaut *)
    ErrorId           : WORD;    (* ❌ Code bitfield du défaut de sécurité *)
    SafeStop          : BOOL;    (* 🟧 Arrêt rapide activé par la sécurité *)
    ForbidDescent     : BOOL;    (* 🚯 Descente interdite (détecteur mou de câble / limites) *)
    ForbidAscent      : BOOL;    (* 🚯 Montée interdite (fin de course haut) *)
    SlackCable        : BOOL;    (* ⚠️ Mou de câble physiquement détecté *)
    ThermalFault      : BOOL;    (* 🔥 Surchauffe thermique moteur *)
    EncoderFault      : BOOL;    (* 🔌 Perte de liaison ou incohérence codeur *)
    BypassActive      : BOOL;    (* 🔧 Bypass codeur effectivement accepté, uniquement MAINT_N2 *)
    CableLimitDescent : BOOL;    (* ⚠️ Longueur max de câble atteinte (limite basse physique) *)
    CableLimitAscent  : BOOL;    (* ⚠️ Limite haute d'exploitation normale atteinte *)
    MecaADrift_M      : REAL;    (* 📐 Dérive mesurée Méca A (m) *)
    MecaCDrift_M      : REAL;    (* 📐 Dérive mesurée Méca C (m) *)
    MecaBElapsedTime  : TIME;    (* ⏳ Temps écoulé confirmation contacteurs/frein *)
    PowerCutOff       : BOOL;    (* 🧨 Coupure puissance amont activée *)
    BrakeTimeoutFault : BOOL;    (* ⏱️ Défaut watchdog confirmation ouverture/fermeture frein *)
    CableOutOfBoundsFault : BOOL; (* 📐 Dépassement des bornes physiques haute/basse du câble *)
END_STRUCT
END_TYPE
