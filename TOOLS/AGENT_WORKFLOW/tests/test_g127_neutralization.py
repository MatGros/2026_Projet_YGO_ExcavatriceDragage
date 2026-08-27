"""Regression G127 — le parseur LHS doit voir TOUTES les affectations d'une ligne.

REX T164-1 (2026-08-27) : `ASSIGN_LHS_RE` ancre `^\\s*(...):=` ratait la 2e affectation
d'une ligne `A := 0.0; B := FALSE;` -> 5 FB classes a tort incomplets (FB_SyncDeviation,
FB_WinchSync, FB_DiveSearch, FB_ExtractionSequence, FB_Safety_Translation).
"""
import importlib.util
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "G127_check_neutralization_completeness.py"
_spec = importlib.util.spec_from_file_location("g127", _SCRIPT)
g127 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(g127)


def _lhs(src: str) -> set[str]:
    return {m.split(".")[0] for m in g127.ASSIGN_LHS_RE.findall(src)}


def test_multiple_assignments_same_line():
    assert _lhs("    A := 0.0; B := FALSE; C := 16#0000;") == {"A", "B", "C"}


def test_struct_field_and_line_start():
    assert _lhs("HwOut.PresetTriggerCmd := 0; Homed := Calib.Homed;") == {"HwOut", "Homed"}


def test_named_arg_in_fb_call_is_not_lhs():
    # `In :=` precede de `(` ou `,` = argument nomme d'appel, jamais un LHS de neutralisation
    assert "In" not in _lhs("inst(In := x, PT := t);")


def test_five_false_positive_fbs_now_clean(tmp_path, capsys):
    """Les 5 FB du REX ne doivent plus figurer dans la sortie de G127 sur le repo reel."""
    repo = _SCRIPT.resolve().parents[3]
    if not (repo / "CODE").is_dir():
        return  # hors repo complet : le test unitaire ci-dessus suffit
    rc = g127.main.__wrapped__ if hasattr(g127.main, "__wrapped__") else g127.main
    import sys
    old = sys.argv
    sys.argv = ["g127", str(repo)]
    try:
        g127.main()
    finally:
        sys.argv = old
    out = capsys.readouterr().out
    for fb in ("FB_SyncDeviation", "FB_WinchSync", "FB_DiveSearch",
               "FB_ExtractionSequence", "FB_Safety_Translation"):
        assert fb not in out, f"{fb} re-signale incomplet (regression parseur ;-split)"
