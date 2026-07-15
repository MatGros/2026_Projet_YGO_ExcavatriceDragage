import os
import re

gvl_path = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\CODE\GVL_PERSISTENT.st"
root_dir = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage"

# Define map from qualified reference to new undecorated reference
rename_map = [
    ("GVL_PERSISTENT.CalibM1", "_CalibM1"),
    ("GVL_PERSISTENT.CalibM2", "_CalibM2"),
    ("GVL_PERSISTENT.HomingTargetM1_M", "_HomingTargetM1_M"),
    ("GVL_PERSISTENT.HomingTargetM2_M", "_HomingTargetM2_M"),
    ("GVL_PERSISTENT.WinchSpeedStepTable", "_WinchSpeedStepTable"),
    ("GVL_PERSISTENT.WinchMaxStepDescente", "_WinchMaxStepDescent"),
    ("GVL_PERSISTENT.WinchMaxStepDescent", "_WinchMaxStepDescent"),
    ("GVL_PERSISTENT.WinchM1RampAccelRate_Pct", "_WinchM1RampAccelRate_Pct"),
    ("GVL_PERSISTENT.WinchM1RampDecelNormal_Pct", "_WinchM1RampDecelNormal_Pct"),
    ("GVL_PERSISTENT.WinchM1RampDecelFast_Pct", "_WinchM1RampDecelFast_Pct"),
    ("GVL_PERSISTENT.WinchM2RampAccelRate_Pct", "_WinchM2RampAccelRate_Pct"),
    ("GVL_PERSISTENT.WinchM2RampDecelNormal_Pct", "_WinchM2RampDecelNormal_Pct"),
    ("GVL_PERSISTENT.WinchM2RampDecelFast_Pct", "_WinchM2RampDecelFast_Pct"),
    ("GVL_PERSISTENT.CableLimitDescentM1_M", "_CableLimitM1Descent_M"),
    ("GVL_PERSISTENT.CableLimitDescentM2_M", "_CableLimitM2Descent_M"),
    ("GVL_PERSISTENT.CableLimitAscentM1_M", "_CableLimitM1Ascent_M"),
    ("GVL_PERSISTENT.CableLimitAscentM2_M", "_CableLimitM2Ascent_M"),
    ("GVL_PERSISTENT.WinchSlowdownDistance_M", "_WinchSlowdownDistance_M"),
    ("GVL_PERSISTENT.WinchSlowSpeedPct", "_WinchSlowSpeed_Pct"),
    ("GVL_PERSISTENT.WinchSlowSpeed_Pct", "_WinchSlowSpeed_Pct"),
    ("GVL_PERSISTENT.WinchSyncTolerance_M", "_WinchSyncTolerance_M"),
    ("GVL_PERSISTENT.WinchCriticalSyncTolerance_M", "_WinchCriticalSyncTolerance_M"),
    ("GVL_PERSISTENT.SyncSoftStopEnable", "_SyncSoftStopEnable"),
    ("GVL_PERSISTENT.BucketConfig", "_BucketConfig"),
    ("GVL_PERSISTENT.BucketState", "_BucketState"),
    ("GVL_PERSISTENT.TranslationMaxFreqHz", "_TranslationMaxFreq_Hz"),
    ("GVL_PERSISTENT.TranslationMaxFreq_Hz", "_TranslationMaxFreq_Hz"),
    ("GVL_PERSISTENT.JoystickNeutralX", "_JoystickNeutralX"),
    ("GVL_PERSISTENT.JoystickNeutralY", "_JoystickNeutralY"),
    ("GVL_PERSISTENT.LimitLegalDepthMinAllowed", "_LimitLegalDepthMinAllowed_M"),
    ("GVL_PERSISTENT.LimitLegalDepthMinAllowed_M", "_LimitLegalDepthMinAllowed_M"),
    ("GVL_PERSISTENT.LimitLegalEnabled", "_LimitLegalEnabled"),
    ("GVL_PERSISTENT.SimEncoderRawPosM1", "_SimEncoderRawPosM1"),
    ("GVL_PERSISTENT.SimEncoderRawPosM2", "_SimEncoderRawPosM2"),
]

# We also need to map the declaration renames inside GVL_PERSISTENT.st itself
declaration_map = [
    (r"\bCalibM1\b", "_CalibM1"),
    (r"\bCalibM2\b", "_CalibM2"),
    (r"\bHomingTargetM1_M\b", "_HomingTargetM1_M"),
    (r"\bHomingTargetM2_M\b", "_HomingTargetM2_M"),
    (r"\bWinchSpeedStepTable\b", "_WinchSpeedStepTable"),
    (r"\bWinchMaxStepDescente\b", "_WinchMaxStepDescent"),
    (r"\bWinchMaxStepDescent\b", "_WinchMaxStepDescent"),
    (r"\bWinchM1RampAccelRate_Pct\b", "_WinchM1RampAccelRate_Pct"),
    (r"\bWinchM1RampDecelNormal_Pct\b", "_WinchM1RampDecelNormal_Pct"),
    (r"\bWinchM1RampDecelFast_Pct\b", "_WinchM1RampDecelFast_Pct"),
    (r"\bWinchM2RampAccelRate_Pct\b", "_WinchM2RampAccelRate_Pct"),
    (r"\bWinchM2RampDecelNormal_Pct\b", "_WinchM2RampDecelNormal_Pct"),
    (r"\bWinchM2RampDecelFast_Pct\b", "_WinchM2RampDecelFast_Pct"),
    (r"\bCableLimitDescentM1_M\b", "_CableLimitM1Descent_M"),
    (r"\bCableLimitDescentM2_M\b", "_CableLimitM2Descent_M"),
    (r"\bCableLimitAscentM1_M\b", "_CableLimitM1Ascent_M"),
    (r"\bCableLimitAscentM2_M\b", "_CableLimitM2Ascent_M"),
    (r"\bWinchSlowdownDistance_M\b", "_WinchSlowdownDistance_M"),
    (r"\bWinchSlowSpeedPct\b", "_WinchSlowSpeed_Pct"),
    (r"\bWinchSlowSpeed_Pct\b", "_WinchSlowSpeed_Pct"),
    (r"\bWinchSyncTolerance_M\b", "_WinchSyncTolerance_M"),
    (r"\bWinchCriticalSyncTolerance_M\b", "_WinchCriticalSyncTolerance_M"),
    (r"\bSyncSoftStopEnable\b", "_SyncSoftStopEnable"),
    (r"\bBucketConfig\b", "_BucketConfig"),
    (r"\bBucketState\b", "_BucketState"),
    (r"\bTranslationMaxFreqHz\b", "_TranslationMaxFreq_Hz"),
    (r"\bTranslationMaxFreq_Hz\b", "_TranslationMaxFreq_Hz"),
    (r"\bJoystickNeutralX\b", "_JoystickNeutralX"),
    (r"\bJoystickNeutralY\b", "_JoystickNeutralY"),
    (r"\bLimitLegalDepthMinAllowed\b", "_LimitLegalDepthMinAllowed_M"),
    (r"\bLimitLegalDepthMinAllowed_M\b", "_LimitLegalDepthMinAllowed_M"),
    (r"\bLimitLegalEnabled\b", "_LimitLegalEnabled"),
    (r"\bSimEncoderRawPosM1\b", "_SimEncoderRawPosM1"),
    (r"\bSimEncoderRawPosM2\b", "_SimEncoderRawPosM2"),
]

# Update GVL_PERSISTENT.st
print("Updating GVL_PERSISTENT.st...")
with open(gvl_path, "r", encoding="utf-8") as f:
    gvl_content = f.read()

# Remove {attribute 'qualified_only'}
gvl_content = gvl_content.replace("{attribute 'qualified_only'}", "// {attribute 'qualified_only'} (removed to allow direct access via prefix _)")

# Apply declarations rename
for pattern, replacement in declaration_map:
    gvl_content = re.sub(pattern, replacement, gvl_content)

with open(gvl_path, "w", encoding="utf-8") as f:
    f.write(gvl_content)

# Apply GVL qualified reference updates across the whole project
print("Updating GVL references across workspace...")
exclude_dirs = {".git", ".pytest_cache", ".vscode", "ARCHIVES"}

for dirpath, dirnames, filenames in os.walk(root_dir):
    # skip excluded directories
    dirnames[:] = [d for d in dirnames if d not in exclude_dirs]
    for filename in filenames:
        if filename.endswith((".st", ".md", ".xml", ".export")):
            file_path = os.path.join(dirpath, filename)
            # Skip GVL_PERSISTENT.st itself since we already processed it
            if os.path.abspath(file_path) == os.path.abspath(gvl_path):
                continue
            
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                
                original_content = content
                for old_val, new_val in rename_map:
                    content = content.replace(old_val, new_val)
                
                # Special cases where the variable might be used without qualified_only inside the GVL or elsewhere
                # (but since qualified_only was active, all outside references must have been qualified_only)
                
                if content != original_content:
                    with open(file_path, "w", encoding="utf-8") as f:
                        f.write(content)
                    print(f"Updated: {file_path}")
            except Exception as e:
                print(f"Failed to process {file_path}: {e}")

print("Done renaming variables and updating references.")
