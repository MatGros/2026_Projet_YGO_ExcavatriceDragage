(* ═══════════════════════════════════════════════════════════════
   📡 ST_NetworkDiagHMI — Données d'échange IHM pour les diagnostics réseau
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des diagnostics CANopen et EtherCAT.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_NetworkDiagHMI :
STRUCT
    BusCanOpen          : ST_DeviceDiag;  (* 📡 Diagnostics bus CANopen *)
    Joystick            : ST_DeviceDiag;  (* 🕹️ Diagnostics esclave Joystick *)
    CanError            : BOOL;           (* ⚠️ Anomalie CANopen *)
    CanErrorId          : WORD;           (* ❌ Code anomalie CANopen *)
    
    BusEthercat         : ST_DeviceDiag;  (* 📡 Diagnostics bus EtherCAT *)
    EncoderM1           : ST_DeviceDiag;  (* 🧲 Diagnostics esclave COD1 *)
    EncoderM2           : ST_DeviceDiag;  (* 🧲 Diagnostics esclave COD2 *)
    VariateurM3         : ST_DeviceDiag;  (* ↔️ Diagnostics esclave AC600 *)
    EcatError           : BOOL;           (* ⚠️ Anomalie EtherCAT *)
    EcatErrorId         : WORD;           (* ❌ Code anomalie EtherCAT *)
END_STRUCT
END_TYPE
