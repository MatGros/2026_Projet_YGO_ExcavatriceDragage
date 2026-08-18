(* ═══════════════════════════════════════════════════════════════
   🧲 ST_EncoderHMI — Données d'échange IHM pour les codeurs absolus
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des informations et diagnostics des codeurs.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_EncoderHMI :
STRUCT
    RawPos           : UDINT; (* 📊 Position brute lue sur le bus *)
    Alarms           : UINT;  (* ⚠️ Code d'alarme brut du codeur *)
    Warnings         : UINT;  (* 🟧 Code d'avertissement brut du codeur *)
    SlaveOperational : BOOL;  (* 📡 Esclave EtherCAT opérationnel *)
    PresetTriggerCmd : WORD;  (* 🎯 Commande de preset active *)
    PresetValueOut   : UDINT; (* 📐 Valeur de preset envoyée au codeur *)
    Error            : BOOL;  (* Codeur en défaut (liaison EtherCAT ou preset) *)
    ErrorId          : WORD;  (* ❌ Code défaut codeur *)

    (* 🎯 Homing — déplacés depuis ST_WinchState racine (2026-08, réorganisation ST_WinchHMI/Homing) *)
    Homed                   : BOOL;             (* 🎯 Prise d'origine (Homing) validée *)
    HomingBusy              : BOOL;             (* ⏳ Référencement en cours *)
    HomingDone              : BOOL;             (* ✅ Pulse de référencement réussi *)
    HomingError             : BOOL;             (* Défaut de référencement *)
    HomingErrorId           : WORD;             (* ❌ Bitfield défaut homing *)
    HomingState             : E_State;          (* 🤖 État FB_Encoder_Homing *)
    HomingStateAtError      : E_State;          (* 🧭 État lors du défaut *)
    HomingSuspect           : BOOL;             (* ⚠️ Référence à confirmer *)
    HomingRefRaw            : UDINT;            (* 📐 Référence brute appliquée *)
END_STRUCT
END_TYPE
