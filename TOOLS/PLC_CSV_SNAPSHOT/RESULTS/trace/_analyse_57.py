import csv, sys

f = r"TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_57_SIMU_DefMecaB_20260919_wide.csv"
with open(f, encoding="utf-8-sig") as fh:
    rdr = list(csv.DictReader(fh, delimiter=";"))

def col(d, name):
    return d.get(name, "")

def step_transitions():
    prev = None
    print("=== trans. CycleStep ===")
    for r in rdr:
        s = col(r, "PRG_03_Modes_Cycle.instCycleSemiAuto.CycleStep")
        if s != prev:
            t = col(r, "Timestamp_ms")
            print(f"t={t} Step={s} S1={col(r,'M1TreuilRetenue.State.StepNumber')} S2={col(r,'M2TreuilBenne.State.StepNumber')} "
                  f"JoyY={col(r,'IoHw.In.Hardware.Operator.JoyYRaw_ANA2')} CR1={col(r,'IoHw.In.Hardware.Winch.M1_ContactorsReleased_DI')} "
                  f"CR2={col(r,'IoHw.In.Hardware.Winch.M2_ContactorsReleased_DI')} TensionM2={col(r,'IoHw.In.Hardware.Winch.M2_TensionedCable_DI')} "
                  f"BrkM1={col(r,'GVL_Troubleshooting.I_LevageUnitaireM1.Inputs_100.Idx104_BrakeApplied')} "
                  f"E1={col(r,'M1TreuilRetenue.Safety.ErrorId')} E2={col(r,'PRG_07_Supervision.instTroubleshootingView.WinchM2.Safety.ErrorId')} "
                  f"Kob={col(r,'M1_M2_KoboldMeasureEnable_RQ')} KobTouch={col(r,'M1_M2_KoboldBottomTouch_DI')}")
            prev = s

def window_around_slack():
    # find rows where TensionM2 changes or where S1 drops from >0 to 0
    prevS = "?"
    print("\n=== fenetre chute + tension ===")
    for r in rdr:
        t = col(r, "Timestamp_ms")
        s1 = col(r, "M1TreuilRetenue.State.StepNumber")
        ten = col(r, "IoHw.In.Hardware.Winch.M2_TensionedCable_DI")
        e2 = col(r, "PRG_07_Supervision.instTroubleshootingView.WinchM2.Safety.ErrorId")
        e1 = col(r, "M1TreuilRetenue.Safety.ErrorId")
        # print around when step drops or error changes or tension changes
        if prevS != "?" and ((s1 != prevS and s1 == "0") or ten != prevT or e1 != prevE1 or e2 != prevE2):
            print(f"t={t} Step={col(r,'PRG_03_Modes_Cycle.instCycleSemiAuto.CycleStep')} S1={s1} S2={col(r,'M2TreuilBenne.State.StepNumber')} "
                  f"TensionM2={ten} E1={e1} E2={e2} JoyY={col(r,'IoHw.In.Hardware.Operator.JoyYRaw_ANA2')} "
                  f"CR1={col(r,'IoHw.In.Hardware.Winch.M1_ContactorsReleased_DI')} CR2={col(r,'IoHw.In.Hardware.Winch.M2_ContactorsReleased_DI')} "
                  f"BrkM1={col(r,'GVL_Troubleshooting.I_LevageUnitaireM1.Inputs_100.Idx104_BrakeApplied')} KobTouch={col(r,'M1_M2_KoboldBottomTouch_DI')} Kob={col(r,'M1_M2_KoboldMeasureEnable_RQ')}")
        prevS = s1
        prevT = ten
        prevE1 = e1
        prevE2 = e2

step_transitions()
window_around_slack()

# summary stats
print("\n=== distinct E1 / E2 / Tension / KobTouch ===")
for name in ["M1TreuilRetenue.Safety.ErrorId", "PRG_07_Supervision.instTroubleshootingView.WinchM2.Safety.ErrorId",
             "IoHw.In.Hardware.Winch.M2_TensionedCable_DI", "M1_M2_KoboldBottomTouch_DI"]:
    vals = sorted(set(col(r, name) for r in rdr))
    print(name, "->", vals)
