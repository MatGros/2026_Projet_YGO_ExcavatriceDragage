import copy
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path

src_path = Path("TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_97_SIMU_M3_Translation_M3_manu_auto_20261116.trace")
out_path = Path("TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Trace_Site_M3_Par_Echelle.trace")

tree = ET.parse(src_path)
root = tree.getroot()

var_list = None
for single in root.iter("Single"):
    if single.attrib.get("Name") == "VariableList":
        var_list = single.find("List")
        break

assert var_list is not None, "VariableList not found"
template_item = copy.deepcopy(var_list[0])
var_list.clear()

for child in list(root):
    if child.tag != "TraceConfiguration":
        root.remove(child)

groups = [
    # Groupe 1 : Booleens (0/1) -> [0.0 .. 1.0] (Min=-0.1, Max=1.2 pour visibilite fronts)
    ("PRG_02_Acquisition.Data.Joystick.DeadmanArmed", -0.1, 1.2, -16744448),
    ("PRG_02_Acquisition.Data.Joystick.AxisX.DirectionPositive", -0.1, 1.2, -16711936),
    ("PRG_02_Acquisition.Data.Joystick.AxisX.DirectionNegative", -0.1, 1.2, -65281),
    ("PRG_02_Acquisition.Data.Joystick.AxisY.AtNeutral", -0.1, 1.2, -8355712),
    ("PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.ReqStart", -0.1, 1.2, -15110196),
    ("PRG_02_Acquisition.HwIn.Translation.M3_PosPV_DI", -0.1, 1.2, -256),
    ("PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI", -0.1, 1.2, -65536),
    ("PRG_02_Acquisition.HwIn.Translation.M3_PosP1_DI", -0.1, 1.2, -16776961),
    ("PRG_05_Translation.Data.TranslationState.AtTremie", -0.1, 1.2, -32768),
    ("PRG_05_Translation.Data.TranslationState.AtP1", -0.1, 1.2, -16744193),
    ("PRG_05_Translation.Data.TranslationState.PositionReached", -0.1, 1.2, -12566464),
    ("PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Tremie", -0.1, 1.2, -16728064),
    ("PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Maintenance", -0.1, 1.2, -16744320),
    ("PRG_05_Translation.Data.TranslationFinalInterlockRequest.ReqTremieSemantic", -0.1, 1.2, -4194304),
    ("PRG_05_Translation.Data.TranslationState.ActiveTremie", -0.1, 1.2, -8388608),
    ("PRG_05_Translation.Data.TranslationState.ActiveMaintenance", -0.1, 1.2, -8388480),
    ("PRG_05_Translation.Data.TranslationState.BrakeCmd", -0.1, 1.2, -16711681),
    ("PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest", -0.1, 1.2, -65408),
    ("PRG_05_Translation.Data.TranslationState.BrakeCommandOpenConfirmed", -0.1, 1.2, -8323328),
    ("PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI", -0.1, 1.2, -16777216),
    ("PRG_05_Translation.Data.TranslationFinalInterlockRequest.SafeStop", -0.1, 1.2, -65536),
    ("PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerCutOff", -0.1, 1.2, -8388608),
    ("PRG_05_Translation.Data.TranslationState.Error", -0.1, 1.2, -65536),
    # Groupe 2 : Positions (m) & Cibles / Mots de commande (0..10) -> [-1.0 .. 11.0]
    ("PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.PositionTgt", -1.0, 11.0, -16744193),
    ("PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord", -1.0, 11.0, -8388480),
    ("PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord", -1.0, 11.0, -16776961),
    ("GVL_IHM.M3Translation.State.EstimatedPosM3_M", -1.0, 11.0, -16744448),
    ("GVL_Simulation.SimM3ObsPositionTrue_M", -1.0, 11.0, -65536),
    # Groupe 3 : Step, ErrorId, Frequences (Hz) & Consignes (%) -> [-5.0 .. 105.0]
    ("PRG_03_Modes_Cycle.Data.SequenceState.Step", -5.0, 105.0, -15132212),
    ("PRG_05_Translation.Data.TranslationState.ErrorId", -5.0, 105.0, -65536),
    ("PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveFreqHz", -5.0, 105.0, -16744193),
    ("PRG_06_Outputs.instTranslationOutputInterlockM3.DriveFreqCmd_Hz", -5.0, 105.0, -16711936),
    ("PRG_05_Translation.Data.TranslationState.SpeedCmd_Pct", -5.0, 105.0, -32768),
    ("GVL_IHM.M2TreuilBenne.Bucket.State.BucketOpening_Pct", -5.0, 105.0, -8388480),
    # Groupe 4 : Frequence variateur brute x100 (0..5000) -> [0.0 .. 5000.0]
    ("PRG_02_Acquisition.Data.M3.ActualFrequencyHz", 0.0, 5000.0, -65536),
]

for name, vmin, vmax, col in groups:
    item = copy.deepcopy(template_item)
    for s in item.findall("Single"):
        sname = s.attrib.get("Name")
        if sname == "VariableName":
            s.text = name
        elif sname == "GraphColor":
            s.text = str(col)
        elif sname == "Visible":
            s.text = "True"
        elif sname == "Enabled":
            s.text = "True"
        elif sname == "guid":
            s.text = str(uuid.uuid4())
        elif sname == "YAxisSettings":
            for ys in s.findall("Single"):
                yname = ys.attrib.get("Name")
                if yname == "Mode":
                    ys.text = "0"
                elif yname == "Min":
                    ys.text = str(vmin)
                elif yname == "Max":
                    ys.text = str(vmax)
                elif yname == "Range":
                    ys.text = str(round(vmax - vmin, 2))
    var_list.append(item)

tree.write(out_path, encoding="utf-8", xml_declaration=False)
print(f"OK: Generated {out_path} with {len(groups)} variables.")
