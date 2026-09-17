"""Contrat exécutable M3 : FMU OpenModelica + OMSimulator, sans PLC connecté."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile
from dredge_runtime import M3ShadowEngine


def samples(engine, count, **command):
    return [engine.step(**command) for _ in range(count)]


def main():
    engine = M3ShadowEngine()
    checks = {}
    try:
        idle = samples(engine, 20)[-1]
        assert idle["brakeIsOpenDI"] == 0 and idle["actualFrequencyHz"] == 0
        checks["idle_is_neutral"] = "PASS"

        moving = samples(engine, 180, req_maintenance=1, speed_cmd_pct=70, brake_release_cmd=1)[-1]
        assert moving["positionM"] > 20.2
        assert moving["velocityMps"] > 0 and moving["actualFrequencyHz"] == 28
        assert moving["brakeIsOpenDI"] == 1 and moving["statusWord"] == 135
        checks["maintenance_final_command_to_sensor_image"] = "PASS"

        braked = samples(engine, 100, req_maintenance=1, speed_cmd_pct=70, brake_release_cmd=0)[-1]
        assert braked["brakeIsOpenDI"] == 0 and abs(braked["velocityMps"]) < .01
        checks["brake_feedback_and_stop"] = "PASS"

        conflict = engine.step(req_tremie=1, req_maintenance=1, speed_cmd_pct=100, brake_release_cmd=1)
        assert conflict["commandConflict"] == 1 and conflict["actualFrequencyHz"] == 0
        checks["opposed_final_commands_reported"] = "PASS"

        engine.reset()
        limit = samples(engine, 700, req_maintenance=1, speed_cmd_pct=100, brake_release_cmd=1)[-1]
        assert limit["positionM"] <= 30.001 and limit["posMaintenanceDI"] == 1
        checks["physical_travel_bound"] = "PASS"
    finally:
        engine.close()
    visual_work = Path(tempfile.mkdtemp(prefix="dredge_m3_visual_"))
    visual_script = visual_work / "animation.mos"
    model = Path(__file__).resolve().parent / "Dredge.mo"
    visual_script.write_text(
        f'loadModel(Modelica, {{"4.0.0"}});\nloadFile("{model.as_posix()}");\n'
        'setCommandLineOptions("+d=visxml");\n'
        'simulate(Dredge.Examples.AnimatedM3ContractCycle, stopTime=2, numberOfIntervals=20);\n'
        'getErrorString();\n', encoding="utf-8")
    rendered = subprocess.run([str(engine.om / "bin" / "omc.exe"), str(visual_script)],
                               cwd=visual_work, capture_output=True, text=True, timeout=180)
    assert rendered.returncode == 0 and list(visual_work.glob("*_visual.xml")), rendered.stdout + rendered.stderr
    checks["m3_animation_reads_plant_position"] = "PASS"
    print(json.dumps(checks, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
