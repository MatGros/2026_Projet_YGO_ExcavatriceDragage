"""Guard: every current FB_SimBench input must be classified in the FMU migration contract."""
from __future__ import annotations
import re
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("PyYAML requis pour check_simbenc_parity.py") from exc

ROOT = Path(__file__).resolve().parents[3]
MANIFEST = ROOT / "DOC/WFLOW/CONTRACTS/T314_SIMBENCH_PARITY.yaml"

def names_in_var_input(source: str) -> list[str]:
    section = re.search(r"VAR_INPUT(.*?)END_VAR", source, re.S)
    if section is None:
        raise ValueError("VAR_INPUT introuvable dans FB_SimBench")
    return re.findall(r"^\s*([A-Za-z][A-Za-z0-9_]*)\s*:\s*[A-Za-z_]", section.group(1), re.M)

def main() -> None:
    manifest = yaml.safe_load(MANIFEST.read_text(encoding="utf-8"))
    source_path = ROOT / manifest["source"]["file"]
    inputs = names_in_var_input(source_path.read_text(encoding="utf-8"))
    groups = manifest["groups"]
    unclassified: list[str] = []
    duplicate: dict[str, list[str]] = {}
    for name in inputs:
        matches = [group["id"] for group in groups if any(re.fullmatch(pattern, name) for pattern in group["match"])]
        if not matches:
            unclassified.append(name)
        elif len(matches) > 1:
            duplicate[name] = matches
    assert not unclassified, "Entrées SimBench non classifiées: " + ", ".join(unclassified)
    assert not duplicate, "Entrées SimBench classifiées plusieurs fois: " + repr(duplicate)
    assert manifest.get("outputs"), "Sorties SimBench absentes du contrat"
    print(f"PASS: {len(inputs)} entrées FB_SimBench classifiées une fois; {len(manifest['outputs'])} sorties contractuelles.")

if __name__ == "__main__":
    main()
