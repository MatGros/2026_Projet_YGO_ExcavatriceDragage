import os

export_path = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\PRJ_CODESYS\PROJ_Full_ImportExport\Device.export"

with open(export_path, "r", encoding="utf-8") as f:
    content = f.read()

replacements = [
    ("\t_HomingTargetM1_M: REAL := 12.5;", "\t_HomingTargetM1_M: REAL := 8.5;"),
    ("\t_HomingTargetM2_M: REAL := 12.5;", "\t_HomingTargetM2_M: REAL := 8.5;"),
    ("\t_CableLimitM1Ascent_M: REAL := 12.0;", "\t_CableLimitM1Ascent_M: REAL := 8.0;"),
    ("\t_CableLimitM2Ascent_M: REAL := 12.0;", "\t_CableLimitM2Ascent_M: REAL := 8.0;"),
    ("HomingRefRaw := 16726016; // 16777216 - (12.5 * 8192 / 2.0)", "HomingRefRaw := 16742400; // 16777216 - (8.5 * 8192 / 2.0)"),
    ("_CalibM1.HomingRefRaw := 16726016; // 16777216 - (12.5 * 8192 / 2.0)", "_CalibM1.HomingRefRaw := 16742400; // 16777216 - (8.5 * 8192 / 2.0)"),
    ("_CalibM2.HomingRefRaw := 16726016; // 16777216 - (12.5 * 8192 / 2.0)", "_CalibM2.HomingRefRaw := 16742400; // 16777216 - (8.5 * 8192 / 2.0)"),
    ("\tTopSensorPositionM: REAL := 12.5;", "\tTopSensorPositionM: REAL := 8.5;"),
    ("\tTopLimitM: REAL := 12.5;", "\tTopLimitM: REAL := 8.5;"),
    ("\tCableLimitAscentM: REAL := 12.0;", "\tCableLimitAscentM: REAL := 8.0;"),
    ('<Single Name="Value" Type="string">12.5</Single>', '<Single Name="Value" Type="string">8.5</Single>'),
    ('<Single Name="Value" Type="string">12</Single>', '<Single Name="Value" Type="string">8</Single>'),
    ('<Single Name="Value" Type="string">12.0</Single>', '<Single Name="Value" Type="string">8.0</Single>')
]

original_length = len(content)
for old, new in replacements:
    content = content.replace(old, new)

with open(export_path, "w", encoding="utf-8") as f:
    f.write(content)

print(f"Device.export updated. Length: {original_length} -> {len(content)}")
