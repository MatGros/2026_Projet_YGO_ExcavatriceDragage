from pathlib import Path
import subprocess
import sys


SCRIPTS = Path(__file__).parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from run_all_gates import failure_tail, gate_family, grouped_plan


ROOT = Path(__file__).parents[3]
RUNNER = ROOT / "TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py"


def run_palier_a(*args: str) -> str:
    result = subprocess.run(
        [sys.executable, str(RUNNER), "--palier", "A", *args],
        cwd=ROOT,
        text=True,
        encoding="utf-8",
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout


def test_failure_tail_limits_output_to_last_lines():
    output = "\n".join(f"line-{index}" for index in range(10))
    assert failure_tail(output, limit=3) == "line-7\nline-8\nline-9"


def test_failure_tail_keeps_short_output():
    assert failure_tail("one\ntwo\n", limit=30) == "one\ntwo"


def test_default_mode_is_compact():
    output = run_palier_a()
    assert "🧪 GATES PROJET / MODE COMPACT ACTIF" in output
    assert "Cible : PALIER A · 4 gate(s) prévues" in output
    assert "▶ [01] G100 — Qualité du bloc — G100, G110, G120, G127" in output
    assert "✅ PASS" in output
    assert "Code style check: PASS" not in output


def test_verbose_mode_keeps_gate_detail():
    output = run_palier_a("--verbose")
    assert "Code style check: PASS" in output


def test_families_are_explicit_and_contiguous():
    plan = [("C", "300", "a", []), ("C", "310", "b", []), ("C", "450", "c", [])]
    assert gate_family("300") == "G300 — Structure, documentation & sécurité"
    assert [(family, [item[1] for item in items]) for family, items in grouped_plan(plan)] == [
        ("G300 — Structure, documentation & sécurité", ["300", "310"]),
        ("G400 — Bundle, qualité source & CI", ["450"]),
    ]
