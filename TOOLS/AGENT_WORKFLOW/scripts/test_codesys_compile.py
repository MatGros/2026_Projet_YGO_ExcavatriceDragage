#!/usr/bin/env python3
"""Run CODESYS Headless compilation test on a granular POU / PRG.

This tool:
1. Generates a granular PLCopenXML for the requested object (e.g. PRG_06_Outputs_Provisoire)
   with all its transitive dependencies resolved automatically.
2. Copies a base CODESYS project (.project) to a temporary location to keep hardware/IO context.
3. Invokes CODESYS in Headless mode (--noUI) via an IronPython script.
4. Imports the granular XML into the base project and runs project.check_syntax().
5. Prints the exact compilation findings (C0xxx errors, warnings) in clean human-readable output.

Usage:
    python test_codesys_compile.py [OBJECT_NAME] [--base-project PATH] [--codesys-exe PATH]

Example:
    python test_codesys_compile.py PRG_06_Outputs_Provisoire
"""

from __future__ import annotations

import argparse
from contextlib import nullcontext
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Paths
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parents[2]
CODE_DIR = PROJECT_ROOT / "CODE"
PRJ_CODESYS_DIR = PROJECT_ROOT / "PRJ_CODESYS"
GENERATOR_DIR = PROJECT_ROOT / "TOOLS" / "CONVERTER_ST2XML_PLCopenXML"


def find_codesys_executable() -> Path | None:
    """Find CODESYS.exe in standard Windows installation directories."""
    candidates = [
        r"C:\Program Files\CODESYS 3.5.19.10\CODESYS\Common\CODESYS.exe",
        r"C:\Program Files\CODESYS 3.5\CODESYS\Common\CODESYS.exe",
        r"C:\Program Files (x86)\CODESYS 3.5\CODESYS\Common\CODESYS.exe",
        r"C:\Program Files\CODESYS\CODESYS\Common\CODESYS.exe",
    ]
    for c in candidates:
        p = Path(c)
        if p.is_file():
            return p

    # Fallback: search in Program Files
    pf_dirs = [Path(r"C:\Program Files"), Path(r"C:\Program Files (x86)")]
    for pf in pf_dirs:
        if pf.exists():
            for exe in pf.rglob("CODESYS.exe"):
                if "Common" in exe.parts or "CODESYS" in exe.parts:
                    return exe

    return None


def find_latest_base_project() -> Path | None:
    """Find the latest .project file in PRJ_CODESYS."""
    if not PRJ_CODESYS_DIR.exists():
        return None
    projects = list(PRJ_CODESYS_DIR.glob("*.project"))
    if not projects:
        return None
    # Sort by mtime descending
    projects.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return projects[0]


def generate_xml_for_object(object_name: str, out_dir: Path) -> Path:
    """Invoke st2plcopenxml to generate a granular XML bundle for the object."""
    cmd = [
        sys.executable, "-m", "generator.cli",
        object_name,
        "--code-dir", str(CODE_DIR),
        "--out-dir", str(out_dir),
        "--bundle", object_name,
    ]
    res = subprocess.run(cmd, cwd=GENERATOR_DIR, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"ERROR: XML generation failed for '{object_name}':\n{res.stderr}", file=sys.stderr)
        sys.exit(1)

    xml_file = out_dir / f"{object_name}.xml"
    if not xml_file.is_file():
        print(f"ERROR: Expected XML file not created: {xml_file}", file=sys.stderr)
        sys.exit(1)

    return xml_file


def create_ironpython_script(script_path: Path, project_path: Path, xml_path: Path, log_path: Path, baseline: bool = False, simulation: bool = False) -> None:
    """Create the IronPython script to be executed inside CODESYS."""
    proj_p = str(project_path).replace("\\", "/")
    xml_p = str(xml_path).replace("\\", "/")
    log_p = str(log_path).replace("\\", "/")

    content = f'''# -*- coding: utf-8 -*-
# IronPython script executed INSIDE CODESYS --noUI
import sys

project_file = r"{proj_p}"
xml_file = r"{xml_p}"
log_file = r"{log_p}"
trace_file = log_file + ".trace"

def trace(msg):
    try:
        f = open(trace_file, "a")
        f.write(str(msg) + "\\n")
        f.close()
    except:
        pass

trace("1. Script start")
try:
    trace("2. Using the CODESYS --noUI default prompt policy")
    
    trace("3. Opening project: " + project_file)
    proj = projects.open(project_file, primary=True, update_flags=VersionUpdateFlags.NoUpdates)
    trace("4. Project opened successfully: " + str(proj))

    if {not baseline}:
        trace("5. Importing XML: " + xml_file)
        proj.import_xml(xml_file, False)
        trace("6. XML imported successfully")
    else:
        trace("5. Baseline: no import")

    trace("7. Rebuilding active application...")
    app = proj.active_application
    if app is None:
        raise Exception("No active application in copied project")
    if {simulation}:
        device = app
        while device is not None and not hasattr(device, "set_simulation_mode"):
            device = device.parent
        if device is None:
            raise Exception("Device supporting IDE simulation not found")
        device.set_simulation_mode(True)
        if not device.get_simulation_mode():
            raise Exception("IDE simulation mode not confirmed")
        trace("Simulation IDE confirmed")
    for category in system.get_message_categories(False):
        system.clear_messages(category)
    app.rebuild()
    msgs = []
    for category in system.get_message_categories(True):
        msgs.extend(system.get_message_objects(category))
    trace("8. Rebuild completed. Messages: " + str(len(msgs)))
    for index, message in enumerate(msgs):
        # Preserve CODESYS' native diagnostic fields in the scratch trace; the
        # display text alone can collapse build failures to a generic message.
        for name in dir(message):
            if name.startswith("_"):
                continue
            try:
                value = getattr(message, name)
                if callable(value):
                    continue
                rendered = repr(value)
                if len(rendered) > 300:
                    rendered = rendered[:300] + "..."
                trace("Message[%s].%s=%s" % (index, name, rendered))
            except:
                pass

    error_count = 0
    warning_count = 0

    log_lines = ["=== CODESYS COMPILATION FINDINGS ==="]
    for m in msgs:
        if m.severity == Severity.Error or m.severity == Severity.FatalError:
            error_count += 1
            log_lines.append("  [ERREUR] %s" % m.text)
        elif m.severity == Severity.Warning:
            warning_count += 1
            log_lines.append("  [AVERTISSEMENT] %s" % m.text)

    log_lines.append("Summary: %s error(s), %s warning(s)" % (error_count, warning_count))
    trace("9. Closing project")
    proj.close()
    
    f = open(log_file, "w")
    f.write("\\n".join(log_lines))
    f.close()
    trace("10. All finished OK!")

except Exception as exc:
    trace("CRITICAL ERROR: " + str(exc))
'''
    script_path.write_text(content, encoding="utf-8")


def create_retained_scratch(object_name: str) -> Path:
    """Create the authorized gate scratch and retain it for human inspection."""
    scratch_root = PROJECT_ROOT / "TOOLS" / "AGENT_WORKFLOW" / ".tmp"
    scratch_root.mkdir(parents=True, exist_ok=True)
    safe_name = "".join(char if char.isalnum() or char in "_-" else "_" for char in object_name)
    return Path(tempfile.mkdtemp(prefix=f"codesys_compile_{safe_name}_", dir=scratch_root))


def find_codesys_profile(codesys_exe: Path) -> str | None:
    """Find installed CODESYS profile name from the installation directory."""
    profiles_dir = codesys_exe.parent.parent / "Profiles"
    if profiles_dir.is_dir():
        profiles = list(profiles_dir.glob("*.profile.xml"))
        if profiles:
            return profiles[0].name.removesuffix(".profile.xml")
    return None


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("object_name", nargs="?", default="PRG_06_Outputs_Provisoire", help="Target POU/PRG to test")
    parser.add_argument("--base-project", type=Path, help="Base .project file to load context from")
    parser.add_argument("--codesys-exe", type=Path, help="Path to CODESYS.exe")
    parser.add_argument("--profile", help="CODESYS Profile Name (default: auto-detect)")
    parser.add_argument("--baseline", action="store_true", help="Build the copied project without importing XML")
    parser.add_argument("--simulation", action="store_true", help="Build the copied project in CODESYS IDE simulation mode")
    args = parser.parse_args()

    # 1. Find CODESYS executable
    codesys_exe = args.codesys_exe or find_codesys_executable()
    if not codesys_exe or not codesys_exe.is_file():
        print("ERROR: CODESYS.exe not found on the system. Please specify --codesys-exe", file=sys.stderr)
        return 2
    print(f"[INFO] CODESYS Executable: {codesys_exe}")

    # 2. Find Profile
    profile_name = args.profile or find_codesys_profile(codesys_exe) or "CODESYS V3.5 SP19 Patch 1"
    print(f"[INFO] CODESYS Profile: {profile_name}")

    # 3. Find Base Project
    base_proj = args.base_project or find_latest_base_project()
    if not base_proj or not base_proj.is_file():
        print("ERROR: Base .project file not found in PRJ_CODESYS/. Please specify --base-project", file=sys.stderr)
        return 2
    print(f"[INFO] Base Project: {base_proj.name}")

    # 4. Create temp workspace
    retained_scratch = create_retained_scratch(args.object_name)
    print(f"[INFO] Scratch conservé (nettoyage manuel requis) : {retained_scratch}")
    with nullcontext(str(retained_scratch)) as tmp_dir_str:
        tmp_dir = Path(tmp_dir_str)
        print(f"[INFO] Temp Workspace: {tmp_dir}")

        # Step A: Generate XML
        print(f"[BUILD] Generating granular XML for '{args.object_name}'...")
        xml_path = generate_xml_for_object(args.object_name, tmp_dir)
        print(f"[OK] Granular XML created: {xml_path.name}")

        # Step B: Copy base project
        project_copy = tmp_dir / base_proj.name
        shutil.copy2(base_proj, project_copy)

        # Step C: Prepare IronPython Script
        ironpython_script = tmp_dir / "codesys_compile_runner.py"
        log_file = tmp_dir / "build_result.log"
        create_ironpython_script(ironpython_script, project_copy, xml_path, log_file, baseline=args.baseline, simulation=args.simulation)

        # Step D: Run CODESYS Headless
        print("[RUN] Launching CODESYS in Headless mode (--noUI)...")
        # `--runscript` is the ScriptEngine switch exercised by the isolated
        # TwinBench runner.  Invoke CODESYS directly with discrete arguments:
        # a shell command can both break paths containing spaces and mask a
        # script that was never run.
        # Keep the literal quotes required by CODESYS' command-line parser;
        # this is the same form as TwinBench_ControlWin.ps1.
        cmd_line = (
            f'"{codesys_exe}" '
            f'--profile="{profile_name}" '
            f'--runscript="{ironpython_script}" '
            '--noUI'
        )
        res = subprocess.run(cmd_line, capture_output=True, text=True, shell=False)

        # Step E: Display Output
        if log_file.is_file():
            findings = log_file.read_text(encoding="utf-8")
            print("\n" + findings)
            summary = re.search(r"Summary: (\d+) error\(s\), (\d+) warning\(s\)", findings)
            if summary is None or int(summary.group(1)) != 0:
                return 1
        else:
            # CODESYS peut retourner 0 apres avoir delegue la demande a une instance
            # interactive deja ouverte, sans executer le script IronPython. Sans ce
            # fichier, aucun check_syntax ni resultat de compilation n'est prouve.
            print("ERROR: CODESYS did not produce build_result.log; compilation is unproven.",
                  file=sys.stderr)
            print("\n" + res.stdout)
            if res.stderr:
                print(res.stderr, file=sys.stderr)
            return res.returncode if res.returncode != 0 else 1

        return res.returncode


if __name__ == "__main__":
    raise SystemExit(main())
