(* ═══════════════════════════════════════════════════════════════
   🏗️ ST_HwTranslation — Image matérielle brute des entrées Translation M3
   ───────────────────────────────────────────────────────────────
   🎨 Regroupe les signaux physiques d'entrée bruts de la translation M3 (AC600).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_HwTranslation :
STRUCT
    M3_PosTremie_DI      : BOOL;         (* Capteur position trémie *)
    M3_PosPV_DI          : BOOL;         (* Capteur position point de vitesse (pré-ralentissement) *)
    M3_PosPVP2_DI        : BOOL;         (* Capteur position P2 / petite vitesse avant P1 *)
    M3_PosP1_DI          : BOOL;         (* Capteur position P1 *)
    M3_PosMaintenance_DI : BOOL;         (* Capteur position maintenance *)
    M3_BrakeIsOpen_DI    : BOOL;         (* Retour frein M3 (1 = ouvert) *)
    M3_ThermalOK_DI      : BOOL;         (* Retour disjoncteur thermique moteur/variateur AC600 (1 = OK) — diagnostic seul, l'AC600 se protège lui-même *)
    M3_StatusWord        : WORD;         (* Status word variateur AC600 *)
    M3_ActualFrequencyHz : UINT;         (* Fréquence réelle variateur AC600 (x100) *)
    AC600_DeviceState    : DEVICE_STATE; (* État device AC600 (GetDeviceState) *)
END_STRUCT
END_TYPE
