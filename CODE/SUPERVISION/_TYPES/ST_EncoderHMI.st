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
    Error            : BOOL;  (* 🔴 Codeur en défaut (liaison EtherCAT ou preset) *)
    ErrorId          : WORD;  (* ❌ Code défaut codeur *)
END_STRUCT
END_TYPE
