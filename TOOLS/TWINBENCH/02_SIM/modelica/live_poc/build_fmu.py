from __future__ import annotations

import os
import re
import shutil
import subprocess
from pathlib import Path


HERE = Path(__file__).resolve().parent
MODEL_DIR = HERE.parent
STATE_DIR = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local")) / "TwinBenchM3Live"
BUILD_DIR = STATE_DIR.parent / "TBM3Live" / "Build"
FMU_PATH = BUILD_DIR / "M3_LiveFMU.fmu"
OMC_DEFAULT = Path(r"C:\Program Files\OpenModelica1.27.1-64bit\bin\omc.exe")


def find_omc() -> Path:
    configured = os.environ.get("OPENMODELICA_OMC")
    candidates = [Path(configured)] if configured else []
    candidates.extend([OMC_DEFAULT, Path(shutil.which("omc") or "")])
    for candidate in candidates:
        if candidate and candidate.is_file():
            return candidate.resolve()
    raise FileNotFoundError(
        "omc.exe introuvable. Installer OpenModelica 1.27.1 ou définir OPENMODELICA_OMC."
    )


def _mos_path(path: Path) -> str:
    return path.resolve().as_posix().replace('"', '\\"')


def build_fmu(force: bool = False) -> Path:
    source_paths = [MODEL_DIR / "M3_POC.mo", HERE / "M3_LiveFMU.mo"]
    if not force and FMU_PATH.exists():
        newest_source = max(path.stat().st_mtime for path in source_paths)
        if FMU_PATH.stat().st_mtime >= newest_source:
            return FMU_PATH

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    script_path = BUILD_DIR / "build_M3_LiveFMU.mos"
    script_path.write_text(
        "\n".join(
            [
                f'cd("{_mos_path(BUILD_DIR)}");',
                'loadModel(Modelica, {"4.1.0"});',
                f'loadFile("{_mos_path(MODEL_DIR / "M3_POC.mo")}");',
                f'loadFile("{_mos_path(HERE / "M3_LiveFMU.mo")}");',
                "checkModel(M3_LiveFMU);",
                'buildModelFMU(M3_LiveFMU, version="2.0", fmuType="cs", fileNamePrefix="M3_LiveFMU");',
                "getErrorString();",
            ]
        ),
        encoding="utf-8",
    )

    process = subprocess.run(
        [str(find_omc()), str(script_path)],
        cwd=BUILD_DIR,
        text=True,
        capture_output=True,
        timeout=180,
        check=False,
    )
    log_path = BUILD_DIR / "build_M3_LiveFMU.log"
    log_path.write_text(process.stdout + "\n" + process.stderr, encoding="utf-8")
    compiler_errors = re.search(r"(?m)^.*\bError:\s", process.stdout + "\n" + process.stderr)
    if process.returncode != 0 or compiler_errors or not FMU_PATH.exists():
        raise RuntimeError(
            f"Construction FMU échouée (code {process.returncode}). Journal : {log_path}"
        )
    return FMU_PATH


if __name__ == "__main__":
    print(build_fmu(force=True))
