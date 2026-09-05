import xml.etree.ElementTree as ET

def dump_points(filepath):
    tree = ET.parse(filepath)
    root = tree.getroot()
    
    var_names = []
    for var in root.iter('Single'):
        if var.attrib.get('Type') == '{b6a18d24-a045-4a81-a2ac-7044c6f553c0}':
            vname = var.find("Single[@Name='VariableName']")
            if vname is not None and vname.text:
                var_names.append(vname.text)
                
    values_nodes = root.findall('.//Values')
    data_by_var = {}
    for idx, node in enumerate(values_nodes):
        name = var_names[idx] if idx < len(var_names) else f"Var_{idx}"
        raw_text = node.text.strip() if node.text else ""
        if raw_text:
            items = [float(x.strip()) for x in raw_text.split(',') if x.strip()]
            data_by_var[name] = items

    posM1 = data_by_var.get('PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM', [])
    posM2 = data_by_var.get('PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM', [])
    joyDef = data_by_var.get('PRG_02_Acquisition.Data.Joystick.AxisY.Deflection', [])
    deadman = data_by_var.get('PRG_02_Acquisition.Data.Joystick.DeadmanArmed', [])
    m2Req = data_by_var.get('PRG_06_Outputs.instWinchOutputInterlockM2.MotorRequest', [])

    print("Points 110 à 140:")
    for i in range(110, min(140, len(posM2))):
        p1 = posM1[i]
        p2 = posM2[i]
        jd = joyDef[i]
        dm = deadman[i]
        mr = m2Req[i]
        print(f"pt {i:3d} | M1: {p1:6.2f}m | M2: {p2:6.2f}m | Delta: {p2-p1:6.2f}m | JoyY: {jd:6.1f}% | DM: {int(dm)} | M2_MotorReq: {int(mr)}")

if __name__ == '__main__':
    dump_points('TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_BugCycle_20260905_33.trace')
