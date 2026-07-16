// ═══════════════════════════════════════════════════════════════
// 🧪 E_TestStimKind — Profils de stimulus instrumentés
// ═══════════════════════════════════════════════════════════════

TYPE E_TestStimKind :
(
    STIM_PULSE_BOOL    := 0,  // Impulsion calibrée PulsePT puis retour auto
    STIM_RAMP_REAL     := 1,  // Rampe linéaire StartReal->TargetReal en RampPT
    STIM_SEQUENCE_REAL := 2   // Profil de valeurs, chacune tenue SeqDwellPT
);
END_TYPE
