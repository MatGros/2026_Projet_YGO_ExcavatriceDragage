"""Exécution FMU native de la plante M3 hors PLC.

Ce module est le futur point d'entrée de l'adaptateur shadow : il accepte seulement
les sorties finales déjà interverrouillées du PLC et renvoie une image capteurs.
Il ne contient ni autorisation, ni réarmement, ni sortie physique.
"""
from __future__ import annotations

import ctypes as C
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import tempfile

from runtime import installation

ROOT = Path(__file__).resolve().parent
STEP_S = 0.02
INPUTS = ("reqTremie", "reqMaintenance", "speedCmdPct", "brakeReleaseCmd")
OUTPUTS = (
    "positionM", "velocityMps", "actualFrequencyHz", "brakeIsOpenDI",
    "posTremieDI", "posPVDI", "posP2DI", "posP1DI", "posMaintenanceDI",
    "statusWord", "commandConflict", "hardStopTremie", "hardStopMaintenance",
)


def compile_m3_fmu():
    """Construit une FMU CS2 reproductible à partir de la seule source Modelica."""
    om = installation()
    digest = hashlib.sha256((ROOT / "Dredge.mo").read_bytes() + str(om).encode()).hexdigest()[:16]
    work = Path(tempfile.gettempdir()) / "TwinBenchDredge" / digest
    work.mkdir(parents=True, exist_ok=True)
    fmu = work / "Dredge_TranslationM3Plant.fmu"
    if not fmu.exists():
        script = work / "build_m3.mos"
        script.write_text(
            f'loadModel(Modelica, {{"4.0.0"}});\n'
            f'loadFile({json.dumps((ROOT / "Dredge.mo").as_posix())});\n'
            'buildModelFMU(Dredge.TranslationM3Plant, version="2.0", fmuType="cs", '
            'fileNamePrefix="Dredge_TranslationM3Plant");\ngetErrorString();\n',
            encoding="utf-8",
        )
        result = subprocess.run([str(om / "bin" / "omc.exe"), str(script)], cwd=work,
                                capture_output=True, text=True, timeout=240)
        (work / "build_m3.log").write_text(result.stdout + result.stderr, encoding="utf-8")
        if result.returncode or not fmu.exists():
            raise RuntimeError(f"Compilation M3 échouée : {work / 'build_m3.log'}")
    return om, fmu, work


class M3ShadowEngine:
    """FMU OMSimulator. Destiné au shadow/rejeu, jamais au pilotage réel."""
    def __init__(self):
        self.om, self.fmu, self.work = compile_m3_fmu()
        self.dll_dirs = [os.add_dll_directory(str(self.om / "bin"))]
        self.lib = C.CDLL(str(self.om / "bin" / "libOMSimulator.dll"))
        signatures = {
            "newModel": [C.c_char_p], "addSystem": [C.c_char_p, C.c_int],
            "addSubModel": [C.c_char_p, C.c_char_p], "setResultFile": [C.c_char_p, C.c_char_p, C.c_int],
            "setTempDirectory": [C.c_char_p], "setStopTime": [C.c_char_p, C.c_double],
            "setFixedStepSize": [C.c_char_p, C.c_double], "setReal": [C.c_char_p, C.c_double],
            "getReal": [C.c_char_p, C.POINTER(C.c_double)], "instantiate": [C.c_char_p],
            "initialize": [C.c_char_p], "stepUntil": [C.c_char_p, C.c_double],
            "terminate": [C.c_char_p], "delete": [C.c_char_p],
        }
        for name, args in signatures.items():
            fn = getattr(self.lib, "oms_" + name)
            fn.argtypes, fn.restype = args, C.c_int
        self.active = False
        self.call("setTempDirectory", str(self.work).encode())
        self.reset()

    def call(self, name, *args):
        code = getattr(self.lib, "oms_" + name)(*args)
        if code > 1:
            raise RuntimeError(f"OMSimulator {name}: status {code}")

    def reset(self):
        if self.active:
            self.call("terminate", b"dredge")
            self.call("delete", b"dredge")
        self.call("newModel", b"dredge")
        self.call("addSystem", b"dredge.root", 2)
        self.call("addSubModel", b"dredge.root.plant", str(self.fmu).encode())
        self.call("setResultFile", b"dredge", b"", 0)
        self.call("setStopTime", b"dredge", 86400.0)
        self.call("setFixedStepSize", b"dredge.root", STEP_S)
        self.call("instantiate", b"dredge")
        self._set(dict.fromkeys(INPUTS, 0.0))
        self.call("initialize", b"dredge")
        self.t, self.active = 0.0, True

    def _set(self, values):
        for name, value in values.items():
            self.call("setReal", f"dredge.root.plant.{name}".encode(), float(value))

    def step(self, *, req_tremie=0.0, req_maintenance=0.0, speed_cmd_pct=0.0, brake_release_cmd=0.0):
        """Un pas : commandes finales PLC in, faits de plante out."""
        command = dict(reqTremie=req_tremie, reqMaintenance=req_maintenance,
                       speedCmdPct=speed_cmd_pct, brakeReleaseCmd=brake_release_cmd)
        self._set(command)
        self.t = round(self.t + STEP_S, 8)
        self.call("stepUntil", b"dredge", self.t)
        image = {"timestampS": self.t, **command}
        for name in OUTPUTS:
            value = C.c_double()
            self.call("getReal", f"dredge.root.plant.{name}".encode(), C.byref(value))
            if not math.isfinite(value.value):
                raise RuntimeError("Sortie M3 non finie : " + name)
            image[name] = value.value
        return image

    def close(self):
        if self.active:
            self.call("terminate", b"dredge")
            self.call("delete", b"dredge")
            self.active = False

