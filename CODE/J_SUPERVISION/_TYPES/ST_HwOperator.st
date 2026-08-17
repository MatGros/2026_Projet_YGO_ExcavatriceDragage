(* ═══════════════════════════════════════════════════════════════
   🏗️ ST_HwOperator — Image matérielle brute des entrées Opérateur / Joystick
   ───────────────────────────────────────────────────────────────
   📄 Lot L5 (Frontière unique HwIn)
   🎨 Regroupe les signaux physiques d'entrée bruts du joystick CANopen JOY1.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_HwOperator :
STRUCT
    JoyXRaw_ANA1      : INT;          (* Valeur brute analogique axe X (Translation) *)
    JoyYRaw_ANA2      : INT;          (* Valeur brute analogique axe Y (Levage) *)
    JoyBtnRaw         : BOOL;         (* Bouton brut joystick (Homme-Mort) *)
    CanBusState       : INT;          (* État bus CANopen (CANbus.GetBusState) *)
    JOY1_DeviceState  : DEVICE_STATE; (* État device JOY1 (GetDeviceState) *)
END_STRUCT
END_TYPE
