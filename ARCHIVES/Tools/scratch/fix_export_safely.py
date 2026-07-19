import re

def fix_code_files():
    # 1. Modify the ST files for code compile fixes
    inputs_path = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\CODE\MAIN\PRG_00_Inputs.st"
    with open(inputs_path, "r", encoding="utf-8") as f:
        content = f.read()
    content = content.replace("PosFosse1_DI", "TranslationPosFosse1_DI")
    content = content.replace("PosFosse2_DI", "TranslationPosFosse2_DI")
    content = content.replace("PosMaintenance_DI", "TranslationPosMaintenance_DI")
    content = content.replace("PosTremie_DI", "TranslationPosTremie_DI")
    with open(inputs_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Updated PRG_00_Inputs.st")

    outputs_path = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\CODE\MAIN\PRG_10_Outputs.st"
    with open(outputs_path, "r", encoding="utf-8") as f:
        content = f.read()
    content = content.replace("GridUp_RQ", "GrilleUp_RQ")
    content = content.replace("GridDown_RQ", "GrilleDown_RQ")
    content = content.replace("HelmetOpen_RQ", "CasqueOpen_RQ")
    content = content.replace("HelmetClose_RQ", "CasqueClose_RQ")
    with open(outputs_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Updated PRG_10_Outputs.st")

def fix_device_export():
    export_path = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\PRJ_CODESYS\PROJ_Full_ImportExport\Device.export"
    with open(export_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    # Pattern to match visualization value strings: <Single Name="Value" Type="string">VALUE</Single>
    value_pattern = re.compile(r'(<Single Name="Value" Type="string">)(.*?)(</Single>)')

    updated_lines = []
    replaced_count = 0

    for line in lines:
        # Check if line contains a visualization value
        match = value_pattern.search(line)
        if match:
            prefix, val, suffix = match.groups()
            new_val = val
            
            # WinchM1 replacements
            if val.startswith("WinchM1."):
                new_val = val.replace("WinchM1.", "M1TreuilRetenue.", 1)
            elif val == "WinchM1":
                new_val = "M1TreuilRetenue"
            
            # WinchM2 replacements
            elif val.startswith("WinchM2."):
                new_val = val.replace("WinchM2.", "M2TreuilBucket.", 1)
            elif val == "WinchM2":
                new_val = "M2TreuilBucket"
                
            # Grappin / GrappinM2 replacements
            elif val.startswith("Grappin."):
                new_val = val.replace("Grappin.", "Bucket.", 1)
            elif val.startswith("GrappinM2."):
                new_val = val.replace("GrappinM2.", "Bucket.", 1)
            elif val in ("Grappin", "GrappinM2"):
                new_val = "Bucket"
                
            # Common replacements
            elif val.startswith("Common."):
                new_val = val.replace("Common.", "Commun.", 1)
            elif val == "Common":
                new_val = "Commun"
                
            # Chariot / ChariotM3 replacements
            elif val.startswith("Chariot."):
                new_val = val.replace("Chariot.", "TranslationM3.", 1)
            elif val.startswith("ChariotM3."):
                new_val = val.replace("ChariotM3.", "TranslationM3.", 1)
            elif val in ("Chariot", "ChariotM3"):
                new_val = "TranslationM3"
                
            # Joystick replacements
            elif val == "Joystick.Error":
                new_val = "JoystickJOY1.Error"
            elif val == "Joystick":
                new_val = "JoystickJOY1"
                
            # IHM_MANU replacements
            elif val.startswith("IHM_MANU.FdcGrappin"):
                new_val = val.replace("IHM_MANU.FdcGrappin", "IHM_MANU.FdcBucket")
            elif val == "IHM_MANU.GrappinDelta":
                new_val = "IHM_MANU.BenneDelta"
            elif val == "IHM_MANU.M3_RelayFwd":
                new_val = "GVL_IHM.TranslationM3.ReqFwd"
            elif val == "IHM_MANU.M3_RelayRev":
                new_val = "GVL_IHM.TranslationM3.ReqRev"

            # Raw I/O mappings if they appear as values in simulation / stub screens
            elif val == "PosFosse1_DI":
                new_val = "TranslationPosFosse1_DI"
            elif val == "PosFosse2_DI":
                new_val = "TranslationPosFosse2_DI"
            elif val == "PosMaintenance_DI":
                new_val = "TranslationPosMaintenance_DI"
            elif val == "PosTremie_DI":
                new_val = "TranslationPosTremie_DI"
            elif val == "GridUp_RQ":
                new_val = "GrilleUp_RQ"
            elif val == "GridDown_RQ":
                new_val = "GrilleDown_RQ"
            elif val == "HelmetOpen_RQ":
                new_val = "CasqueOpen_RQ"
            elif val == "HelmetClose_RQ":
                new_val = "CasqueClose_RQ"

            if new_val != val:
                line = prefix + new_val + suffix
                replaced_count += 1
        
        # Replace task configuration name specifically
        elif '<Single Name="Name" Type="string">PRG_07_ChariotControl</Single>' in line:
            line = line.replace("PRG_07_ChariotControl", "PRG_07_TranslationControl")
            replaced_count += 1

        updated_lines.append(line)

    with open(export_path, "w", encoding="utf-8") as f:
        f.writelines(updated_lines)
    
    print(f"Updated Device.export: applied {replaced_count} safe replacements inside visualization XML nodes.")

if __name__ == "__main__":
    fix_code_files()
    fix_device_export()
