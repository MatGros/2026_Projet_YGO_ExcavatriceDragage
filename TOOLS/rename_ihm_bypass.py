#!/usr/bin/env python3
"""Renommage global convention IHM (Btn/Sel/Set/Tgl/Cfg) + simulation (Sensor/Bus/Sim/Tst/Link)
+ extraction des bypass vers structs dediees. Applique le mapping TASK_CONTEXT_IHM-NAMING-01.

Usage: python TOOLS/rename_ihm_bypass.py [--dry-run]
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# ── Mapping simple find/replace (whole-word, ordre = du plus long au plus court
#    pour eviter qu'un remplacement partiel casse un nom plus long) ──────────
RENAMES: dict[str, str] = {
    # --- ST_WinchHMI ---
    "TopSensorPositionM": "CfgTopSensorPosM",
    "HomingTargetM": "CfgHomingTargetM",
    "MaxStepDescente": "CfgMaxStepDescente",
    "RampAccelRate": "CfgRampAccelRate",
    "RampDecelNormalRate": "CfgRampDecelNormalRate",
    "RampDecelFastRate": "CfgRampDecelFastRate",
    "CableLimitDescentM": "CfgCableLimitDescentM",
    "CableLimitAscentM": "CfgCableLimitAscentM",
    "SlowdownDistanceM": "CfgSlowdownDistanceM",
    "SlowSpeedPct": "CfgSlowSpeedPct",
    "ConfirmCoherence": "BtnConfirmCoherence",
    "CmdInhibit": "BtnInhibit",
    "EncoderFaultBypassActive": "SensorEncoderFaultBypassActive",
    "CmdHome": "BtnHome",  # sans ambiguite (Winch uniquement)

    # --- ST_BucketHMI ---
    "CmdOpen": "BtnOpen",
    "CmdClose": "BtnClose",
    "CmdConfirmOpenPosition": "BtnConfirmOpenPos",
    "CmdConfirmClosePosition": "BtnConfirmClosePos",
    "TimeoutDuration": "CfgTimeoutDuration",
    # CmdReset : ambigu (Winch+Bucket -> BtnReset, mais Cycle reste CmdReset, commande sequenceur)
    # traite via cible_specific_renames() plus bas, PAS ici (pas de find/replace global sur ce mot)

    # --- ST_TranslationHMI ---
    "PositioningSelect": "SelPositioning",
    "SelectedTargetNum": "SelTarget",
    "ReqFwd": "BtnFwd",
    "ReqRev": "BtnRev",
    "FreqSetpointHz": "SetFreqHz",
    "JoystickSelect": "TglJoystickMaster",
    "TestSensorsWordActive": "TstSensorsWordActive",
    "TestSensorsWord": "TstSensorsWord",
    "TestAtTremie": "TstAtTremie",
    "TestBrakeStuckOpen": "TstBrakeStuckOpen",
    "TestPhantomFreq": "TstPhantomFreq",

    # --- ST_ModesHMI ---
    "ModeRequest": "SelMode",
    "FaultMachineReset": "BtnFaultReset",
    "ModeReset": "BtnModeReset",
    "CmdEmergencyArming": "BtnEmergencyArming",
    "CmdEmergencyCutOff": "BtnEmergencyCutOff",
    "JoystickWinchSelect": "SelJoystickWinch",

    # --- ST_JoystickHMI ---
    "Calibrate": "BtnCalibrate",

    # --- ST_SyncHMI ---
    "SyncToleranceM": "CfgSyncToleranceM",
    "SyncEnableRequest": "SelSyncEnable",

    # --- ST_CycleHMI ---
    "TargetDepthM": "SetDepthM",
    "TargetOffsetM": "SetOffsetM",
    "SimKoboldContactFond": "TstKoboldContactFond",

    # --- ST_CommunHMI ---
    "HomingApproachEnableRequest": "SelHomingApproachEnable",
    "HeartbeatIhmToggle": "TglHeartbeatIhm",
    "HeartbeatPlcToggle": "TglHeartbeatPlc",

    # --- GVL_Simulation ---
    "VariateurM3_IsReal": "BusVariateurM3IsReal",
    "EncoderM1_IsReal": "BusEncoderM1IsReal",
    "EncoderM2_IsReal": "BusEncoderM2IsReal",
    "JoystickSignal_IsReal": "BusJoystickSignalIsReal",
    "Joystick_IsReal": "BusJoystickIsReal",
    "IhmHeartbeat_IsReal": "BusIhmHeartbeatIsReal",
    "EmergencyStopChain_IsReal": "SensorEmergencyStopChainIsReal",
    "TopPositionSensor_IsReal": "SensorTopPositionIsReal",
    "SlackCableSwitch_IsReal": "SensorSlackCableIsReal",
    "PhaseRotationOk_IsReal": "SensorPhaseRotationIsReal",
    "ThermalM1_IsReal": "SensorM1ThermalIsReal",
    "ThermalM2_IsReal": "SensorM2ThermalIsReal",
    "BrakeThermal_IsReal": "SensorBrakeThermalIsReal",
    "ContactorFeedbackM1_IsReal": "SensorM1ContactorFeedbackIsReal",
    "ContactorFeedbackM2_IsReal": "SensorM2ContactorFeedbackIsReal",
    "ContactorFeedbackM3_IsReal": "SensorM3ContactorFeedbackIsReal",
    "TranslationPosition_IsReal": "SensorTranslationPositionIsReal",
    "KoboldContactFond_IsReal": "SensorKoboldContactFondIsReal",
    "HydraulicThermal_IsReal": "SensorHydraulicThermalIsReal",
    "JoystickForceNeutralRaw": "TstJoystickForceNeutralRaw",
    "JoystickForceMaxRaw": "TstJoystickForceMaxRaw",
    "KoboldContactFond_Simulated": "SimKoboldContactFondValue",
    "EncoderSimSpeedFactor": "TstEncoderSpeedFactor",
    "InjectSyncDeviationM1": "TstInjectSyncDeviationM1",
    "InjectSyncDeviationM2": "TstInjectSyncDeviationM2",
    "SyncDeviationOffsetM": "TstSyncDeviationOffsetM",
    "refBucket": "LinkBucket",
    "refWinchM2": "LinkWinchM2",
}

# Champs BypassXxx à plat -> retires des structs et remplaces par consommation Bypass.Xxx
# (traites specifiquement par patch, pas par simple renommage texte)

def apply_word_renames(text: str, mapping: dict[str, str]) -> str:
    # Trie par longueur decroissante pour eviter les collisions partielles
    for old in sorted(mapping.keys(), key=len, reverse=True):
        new = mapping[old]
        text = re.sub(rf"\b{re.escape(old)}\b", new, text)
    return text


# ── CmdReset : ambigu selon le proprietaire (Winch/Bucket -> BtnReset, Cycle -> INCHANGE) ──
# Cible via le chemin d'acces (M1TreuilRetenue./M2TreuilBucket./Bucket. -> BtnReset),
# jamais Cycle.CmdReset (reste identique, commande sequenceur interne).
CMD_RESET_OWNER_PATTERNS = [
    r"(GVL_IHM\.M1TreuilRetenue\.)CmdReset\b",
    r"(GVL_IHM\.M2TreuilBucket\.)CmdReset\b",
    r"(GVL_IHM\.Bucket\.)CmdReset\b",
]


def apply_cmdreset_owner_renames(text: str) -> str:
    for pattern in CMD_RESET_OWNER_PATTERNS:
        text = re.sub(pattern, r"\1BtnReset", text)
    return text


def apply_struct_field_declaration_renames(text: str, filename: str) -> str:
    """Renomme la declaration 'CmdReset : BOOL;' dans ST_WinchHMI.st / ST_BucketHMI.st
    uniquement (PAS ST_CycleHMI.st, qui garde CmdReset tel quel)."""
    if filename in ("ST_WinchHMI.st", "ST_BucketHMI.st"):
        text = re.sub(r"\bCmdReset\b", "BtnReset", text)
    return text


def main() -> int:
    dry = "--dry-run" in sys.argv
    files = list((ROOT / "CODE").rglob("*.st"))
    changed = 0
    for f in files:
        original = f.read_text(encoding="utf-8")
        updated = apply_word_renames(original, RENAMES)
        updated = apply_cmdreset_owner_renames(updated)
        updated = apply_struct_field_declaration_renames(updated, f.name)
        if updated != original:
            changed += 1
            if dry:
                print(f"[DRY] {f.relative_to(ROOT)}")
            else:
                f.write_text(updated, encoding="utf-8")
                print(f"[OK] {f.relative_to(ROOT)}")
    print(f"\n{changed} fichier(s) modifie(s) sur {len(files)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
