#!/usr/bin/env python3
"""Generate CODE_XML/CODE_Bundle.xml then prove that it is fresh.

Single mandatory delivery command for a CODE/ change. Keeps the project name of
an existing bundle unless --project-name is provided.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def existing_project_name(bundle: Path) -> str | None:
    if not bundle.is_file():
        return None
    try:
        tree = ET.parse(bundle)
        header = next((node for node in tree.iter() if node.tag.endswith("contentHeader")), None)
        if header is None:
            return None
        name = header.attrib.get("name")
        return name.removesuffix(".project") if name else None
    except ET.ParseError:
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".")
    parser.add_argument("--project-name")
    args = parser.parse_args()

    root = Path(args.project_root).resolve()
    code_dir = root / "CODE"
    out_dir = root / "CODE_XML"
    generator_dir = root / "TOOLS" / "ST_PLCOPENXML_GENERATOR"
    freshness = root / "TOOLS" / "AGENT_WORKFLOW" / "scripts" / "G390_check_bundle_freshness.py"
    bundle = out_dir / "CODE_Bundle.xml"
    project_name = args.project_name or existing_project_name(bundle)

    if not project_name:
        print("ERROR: --project-name is required when no valid existing bundle is available.", file=sys.stderr)
        return 2

    # Purge preventive (REX 2026-08-17) : sans elle, un .xml dont le .st source a ete
    # renomme/supprime reste orphelin en silence dans CODE_XML/ (ni generation ni gate
    # ne le detectait -- 4 fichiers morts trouves : FB_DigitalInputFilter, GVL_IHM_AU,
    # ST_Safety_Emergency_HmiCmd/HmiState). CODE_XML/ doit etre un miroir strict de
    # CODE/, jamais un historique. Purge APRES la lecture du nom de projet ci-dessus :
    # existing_project_name() a besoin de l'ancien bundle si --project-name est omis.
    shutil.rmtree(out_dir, ignore_errors=True)
    out_dir.mkdir(parents=True, exist_ok=True)
    command = [
        sys.executable, "-m", "generator.cli",
        "--code-dir", str(code_dir),
        "--out-dir", str(out_dir),
        "--bundle", "CODE_Bundle",
        "--project-name", project_name,
    ]
    result = subprocess.run(command, cwd=generator_dir)
    if result.returncode:
        return result.returncode

    # Miroir un-fichier-par-objet dans CODE_XML/ : `--bundle` et le mode par objet sont
    # exclusifs dans generator/cli.py, donc sans ce second passage les fichiers de
    # CODE_XML/<DOSSIER>/*.xml restent perimes en silence pendant que le bundle, lui,
    # est a jour (REX 2026-08-13 : FB_SimBench.xml datait de la veille apres modif du .st).
    per_object = [
        sys.executable, "-m", "generator.cli",
        "--code-dir", str(code_dir),
        "--out-dir", str(out_dir),
        "--project-name", project_name,
    ]
    result_objects = subprocess.run(per_object, cwd=generator_dir)
    if result_objects.returncode:
        return result_objects.returncode

    return subprocess.run([sys.executable, str(freshness), str(root)]).returncode


if __name__ == "__main__":
    raise SystemExit(main())
