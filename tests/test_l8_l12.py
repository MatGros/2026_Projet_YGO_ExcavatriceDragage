"""
Tests L8-L12 — Gates linkage avancés
"""

import sys
from pathlib import Path

# Import depuis scripts
sys.path.insert(0, str(Path(__file__).parent.parent / "TOOLS/AGENT_WORKFLOW/scripts"))

from dataclasses import dataclass
from linkage_gates_l8_l12 import (
    L8Checker, L8Finding,
    L9Checker, L9Finding,
    L10Checker, L10Finding,
    L11Checker, L11Finding,
    L12Checker, L12Finding,
)


# ═══════════════════════════════════════════════════════════════════════════
# Fixtures — Mock Pou for testing
# ═══════════════════════════════════════════════════════════════════════════

class MockPath:
    """Mock Path avec read_text patchable."""
    def __init__(self, path_str, raw_text=""):
        self.path_str = path_str
        self._raw_text = raw_text
    
    def read_text(self, encoding="utf-8", errors="replace"):
        return self._raw_text
    
    def __repr__(self):
        return self.path_str


@dataclass
class MockPou:
    """Mock POU pour tests."""
    name: str
    kind: str  # PROGRAM, FUNCTION_BLOCK
    body: str
    declarations: dict  # {name: (type, section, line)}
    path: Path = None
    raw_text: str = ""  # Optionnel pour L11/L12
    
    def __post_init__(self):
        if self.path is None:
            self.path = MockPath(f"/test/{self.name}.st", self.raw_text)


# ═══════════════════════════════════════════════════════════════════════════
# L8 Tests — Output Assignment
# ═══════════════════════════════════════════════════════════════════════════

def test_l8_output_never_assigned():
    """L8 HIGH: VAR_OUTPUT jamais assignée."""
    pou = MockPou(
        name="PRG_OUTPUTS_LD",
        kind="PROGRAM",
        body="""
        instWinch(...);
        M1_Fwd_RQ := instWinch.M1_Fwd;
        (* M1_Rev_RQ jamais assignée *)
        """,
        declarations={
            "M1_Fwd_RQ": ("BOOL", "VAR_OUTPUT", 1),
            "M1_Rev_RQ": ("BOOL", "VAR_OUTPUT", 2),
        }
    )
    
    checker = L8Checker(pou)
    findings = checker.check()
    
    # M1_Rev_RQ doit être HIGH
    high_findings = [f for f in findings if f.level == "HIGH"]
    assert len(high_findings) == 1
    assert high_findings[0].var_name == "M1_Rev_RQ"
    print("[PASS] test_l8_output_never_assigned")


def test_l8_output_assigned_once():
    """L8 OK: VAR_OUTPUT assignée une fois."""
    pou = MockPou(
        name="PRG_OUTPUTS_LD",
        kind="PROGRAM",
        body="""
        instWinch(...);
        M1_Fwd_RQ := instWinch.M1_Fwd;
        M1_Rev_RQ := instWinch.M1_Rev;
        """,
        declarations={
            "M1_Fwd_RQ": ("BOOL", "VAR_OUTPUT", 1),
            "M1_Rev_RQ": ("BOOL", "VAR_OUTPUT", 2),
        }
    )
    
    checker = L8Checker(pou)
    findings = checker.check()
    
    ok_findings = [f for f in findings if f.level == "OK"]
    assert len(ok_findings) == 2
    print("[PASS] test_l8_output_assigned_once")


def test_l8_output_multiple_assignments():
    """L8 MEDIUM: VAR_OUTPUT assignée 2+ fois."""
    pou = MockPou(
        name="PRG_OUTPUTS_LD",
        kind="PROGRAM",
        body="""
        M1_Fwd_RQ := instWinch.M1_Fwd;
        M1_Fwd_RQ := FALSE;  (* Override? *)
        """,
        declarations={
            "M1_Fwd_RQ": ("BOOL", "VAR_OUTPUT", 1),
        }
    )
    
    checker = L8Checker(pou)
    findings = checker.check()
    
    medium_findings = [f for f in findings if f.level == "MEDIUM"]
    assert len(medium_findings) == 1
    print("[PASS] test_l8_output_multiple_assignments")


def test_l8_ignores_diagnostics():
    """L8 IGNORE: sorties diagnostiques."""
    pou = MockPou(
        name="PRG_OUTPUTS_LD",
        kind="PROGRAM",
        body="",
        declarations={
            "DiagMotorTemp": ("REAL", "VAR_OUTPUT", 1),  # Diag* = ignored
            "M1_Status_Txt": ("STRING", "VAR_OUTPUT", 2),  # _Txt = ignored
        }
    )
    
    checker = L8Checker(pou)
    findings = checker.check()
    
    ignored = [f for f in findings if f.level == "IGNORE"]
    assert len(ignored) == 2
    print("[PASS] test_l8_ignores_diagnostics")


# ═══════════════════════════════════════════════════════════════════════════
# L9 Tests — I/O Mapping
# ═══════════════════════════════════════════════════════════════════════════

def test_l9_output_found_in_mapping():
    """L9 OK: VAR_OUTPUT trouvée dans io_map."""
    pou = MockPou(
        name="PRG_OUTPUTS_LD",
        kind="PROGRAM",
        body="",
        declarations={
            "M1_Fwd_RQ": ("BOOL", "VAR_OUTPUT", 1),
        }
    )
    
    io_map = {
        "PRG_OUTPUTS_LD.M1_Fwd_RQ": {
            "address": "%QX0.1",
            "type": "BOOL",
            "domain": "Winch_M1",
        }
    }
    
    checker = L9Checker(pou, io_map)
    findings = checker.check()
    
    ok_findings = [f for f in findings if f.level == "OK"]
    assert len(ok_findings) == 1
    assert ok_findings[0].address == "%QX0.1"
    print("[PASS] test_l9_output_found_in_mapping")


def test_l9_output_missing_from_mapping():
    """L9 HIGH: VAR_OUTPUT absent du io_map."""
    pou = MockPou(
        name="PRG_OUTPUTS_LD",
        kind="PROGRAM",
        body="",
        declarations={
            "M2_Fwd_RQ": ("BOOL", "VAR_OUTPUT", 1),
        }
    )
    
    io_map = {}  # Vide
    
    checker = L9Checker(pou, io_map)
    findings = checker.check()
    
    high_findings = [f for f in findings if f.level == "HIGH"]
    assert len(high_findings) == 1
    print("[PASS] test_l9_output_missing_from_mapping")


# ═══════════════════════════════════════════════════════════════════════════
# L10 Tests — Single Producer
# ═══════════════════════════════════════════════════════════════════════════

def test_l10_single_writer():
    """L10 OK: variable écrite par une seule source."""
    pou1 = MockPou(
        name="PRG_OUTPUTS_LD",
        kind="PROGRAM",
        body="M1_Fwd_RQ := instWinch.M1_Fwd;",
        declarations={}
    )
    
    pou2 = MockPou(
        name="PRG_INPUTS_LD",
        kind="PROGRAM",
        body="PowerOn := HwIn.PowerOK;",
        declarations={}
    )
    
    pous = {"PRG_OUTPUTS_LD": pou1, "PRG_INPUTS_LD": pou2}
    
    checker = L10Checker(pous)
    findings = checker.check()
    
    # Pas de multiwriter
    assert len([f for f in findings if f.level == "MEDIUM"]) == 0
    print("[PASS] test_l10_single_writer")


def test_l10_multiwriter_detected():
    """L10 MEDIUM: variable écrite par 2 fois dans même POU."""
    pou = MockPou(
        name="PRG_OUTPUTS_LD",
        kind="PROGRAM",
        body="""
        M1_Fwd_RQ := instWinch.M1_Fwd;
        M1_Fwd_RQ := SafetyLogic.M1_Fwd;  (* Multiwriter dans même POU *)
        """,
        declarations={}
    )
    
    pous = {"PRG_OUTPUTS_LD": pou}
    
    checker = L10Checker(pous)
    findings = checker.check()
    
    # L10 détecte: PRG_OUTPUTS_LD.M1_Fwd_RQ assignée 2x par même POU
    medium_findings = [f for f in findings if f.level == "MEDIUM"]
    assert len(medium_findings) == 1
    assert "M1_Fwd_RQ" in medium_findings[0].var_name
    print("[PASS] test_l10_multiwriter_detected")


# ═══════════════════════════════════════════════════════════════════════════
# L11 Tests — Polarity Documentation
# ═══════════════════════════════════════════════════════════════════════════

def test_l11_polarity_documented():
    """L11 OK: polarity keywords trouvés."""
    pou = MockPou(
        name="PRG_OUTPUTS_LD",
        kind="PROGRAM",
        body="",
        declarations={
            "M1_Fwd_RQ": ("BOOL", "VAR_OUTPUT", 1),
        }
    )
    
    raw_text = """
    VAR_OUTPUT
        M1_Fwd_RQ : BOOL;  (* TRUE = avant, FALSE = arrière *)
    END_VAR
    """
    
    checker = L11Checker(pou, raw_text)
    findings = checker.check()
    
    ok_findings = [f for f in findings if f.level == "OK"]
    assert len(ok_findings) == 1
    assert "avant" in ok_findings[0].keywords or "avant" in str(ok_findings[0].keywords).lower()
    print("[PASS] test_l11_polarity_documented")


def test_l11_polarity_missing():
    """L11 MEDIUM: pas de keywords polarité."""
    pou = MockPou(
        name="PRG_OUTPUTS_LD",
        kind="PROGRAM",
        body="",
        declarations={
            "M1_Fwd_RQ": ("BOOL", "VAR_OUTPUT", 1),
        }
    )
    
    raw_text = """
    VAR_OUTPUT
        M1_Fwd_RQ : BOOL;  (* TODO: document polarity *)
    END_VAR
    """
    
    checker = L11Checker(pou, raw_text)
    findings = checker.check()
    
    medium_findings = [f for f in findings if f.level == "MEDIUM"]
    assert len(medium_findings) == 1
    print("[PASS] test_l11_polarity_missing")


# ═══════════════════════════════════════════════════════════════════════════
# L12 Tests — Timing
# ═══════════════════════════════════════════════════════════════════════════

def test_l12_pulse_timing_valid():
    """L12 OK: pulse avec timing valide (≥100ms)."""
    raw_text = """
    VAR_OUTPUT
        EmergencyArming_RQ : BOOL;  (* Pulse duration: T#1s *)
    END_VAR
    """
    
    pou = MockPou(
        name="PRG_OUTPUTS_LD",
        kind="PROGRAM",
        body="",
        declarations={
            "EmergencyArming_RQ": ("BOOL", "VAR_OUTPUT", 1),
        },
        raw_text=raw_text
    )
    
    pou.path = MockPath("/test/test.st", raw_text)
    
    checker = L12Checker(pou)
    findings = checker.check()
    
    ok_findings = [f for f in findings if f.level == "OK"]
    assert len(ok_findings) == 1
    assert ok_findings[0].duration_ms == 1000
    print("[PASS] test_l12_pulse_timing_valid")


def test_l12_pulse_timing_missing():
    """L12 MEDIUM: pulse sans durée documentée."""
    raw_text = """
    VAR_OUTPUT
        TestPulse_RQ : BOOL;  (* No duration info *)
    END_VAR
    """
    
    pou = MockPou(
        name="PRG_OUTPUTS_LD",
        kind="PROGRAM",
        body="",
        declarations={
            "TestPulse_RQ": ("BOOL", "VAR_OUTPUT", 1),
        },
        raw_text=raw_text
    )
    
    pou.path = MockPath("/test/test.st", raw_text)
    
    checker = L12Checker(pou)
    findings = checker.check()
    
    medium_findings = [f for f in findings if f.level == "MEDIUM"]
    assert len(medium_findings) == 1
    print("[PASS] test_l12_pulse_timing_missing")


def test_l12_pulse_too_short():
    """L12 HIGH: pulse <100ms."""
    raw_text = """
    VAR_OUTPUT
        ResetPulse_RQ : BOOL;  (* Duration: 10ms *)
    END_VAR
    """
    
    pou = MockPou(
        name="PRG_OUTPUTS_LD",
        kind="PROGRAM",
        body="",
        declarations={
            "ResetPulse_RQ": ("BOOL", "VAR_OUTPUT", 1),
        },
        raw_text=raw_text
    )
    
    pou.path = MockPath("/test/test.st", raw_text)
    
    checker = L12Checker(pou)
    findings = checker.check()
    
    high_findings = [f for f in findings if f.level == "HIGH"]
    assert len(high_findings) == 1
    print("[PASS] test_l12_pulse_too_short")


# ═══════════════════════════════════════════════════════════════════════════
# Main test runner
# ═══════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    print("\n" + "="*60)
    print("Testing L8-L12 Gates")
    print("="*60 + "\n")
    
    # L8 tests
    test_l8_output_never_assigned()
    test_l8_output_assigned_once()
    test_l8_output_multiple_assignments()
    test_l8_ignores_diagnostics()
    
    # L9 tests
    test_l9_output_found_in_mapping()
    test_l9_output_missing_from_mapping()
    
    # L10 tests
    test_l10_single_writer()
    test_l10_multiwriter_detected()
    
    # L11 tests
    test_l11_polarity_documented()
    test_l11_polarity_missing()
    
    # L12 tests
    test_l12_pulse_timing_valid()
    test_l12_pulse_timing_missing()
    test_l12_pulse_too_short()
    
    print("\n" + "="*60)
    print("[OK] ALL TESTS PASSED (13/13)")
    print("="*60 + "\n")
