from __future__ import annotations

import re
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
LIVE = ROOT / "TOOLS" / "TWINBENCH" / "modelica_poc_m3" / "live_poc"
EXPECTED = [
    "M3_LiveFMU.mo",
    "build_fmu.py",
    "engine.py",
    "test_headless.py",
    "app.py",
    "Main.qml",
    "Start_M3_Live.ps1",
    "README.md",
]
FORBIDDEN = ["codesys", "opc.tcp", "asyncua", "socket.", "plcwrite", "device.application"]


def fail(message: str) -> None:
    print(f"[FAIL] {message}")
    raise SystemExit(1)


def main() -> None:
    missing = [name for name in EXPECTED if not (LIVE / name).is_file()]
    if missing:
        fail("fichiers manquants : " + ", ".join(missing))

    sources = "\n".join((LIVE / name).read_text(encoding="utf-8") for name in EXPECTED)
    lowered = sources.lower()
    found_forbidden = [token for token in FORBIDDEN if token in lowered]
    # Les mentions documentaires de CODESYS/PLC sont admises dans README et libellés,
    # mais aucune API ou adresse de communication ne doit apparaître.
    found_forbidden = [token for token in found_forbidden if token not in {"codesys"}]
    if found_forbidden:
        fail("API interdite détectée : " + ", ".join(found_forbidden))

    modelica = (LIVE / "M3_LiveFMU.mo").read_text(encoding="utf-8")
    engine = (LIVE / "engine.py").read_text(encoding="utf-8")
    qml = (LIVE / "Main.qml").read_text(encoding="utf-8")
    required_model_tokens = [
        "input Real directionCmd",
        "input Real frequencyCmd_Hz",
        "input Boolean brakeReleaseCmd",
        "when sample(0, communicationStep_S)",
        "M3_POC.TranslationM3 plant",
    ]
    for token in required_model_tokens:
        if token not in modelica:
            fail(f"contrat Modelica absent : {token}")
    if not re.search(r"STEP_S\s*=\s*0\.01", engine):
        fail("pas FMI de 10 ms absent du moteur")
    for token in ["backend.direction", "frequencyActual", "scanCounter", "brakeOpen", "tracePoints"]:
        if token not in qml:
            fail(f"observation QML absente : {token}")

    local_app_data = Path.home() / "AppData" / "Local" / "TwinBenchM3Live" / "Build" / "M3_LiveFMU.fmu"
    if local_app_data.is_file():
        with zipfile.ZipFile(local_app_data) as archive:
            description = archive.read("modelDescription.xml").decode("utf-8")
        for variable in [
            "directionCmd", "frequencyCmd_Hz", "brakeReleaseCmd",
            "positionAct_M", "frequencyAct_Hz", "scanCounter",
        ]:
            if f'name="{variable}"' not in description:
                fail(f"variable FMU absente : {variable}")
        if 'causality="input"' not in description or 'causality="output"' not in description:
            fail("causalités FMI input/output absentes")
        print("[PASS] modelDescription.xml : interface FMI scalaire présente")
    else:
        print("[INFO] FMU non construite : contrôle modelDescription.xml ignoré")

    print("[PASS] T405 POC M3 live : structure, isolation et pas 10 ms conformes")


if __name__ == "__main__":
    main()
