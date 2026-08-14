"""Garde-fou : la vue AU doit exposer les faits publics nécessaires au diagnostic."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CHECKLIST = ROOT / "CODE" / "SUPERVISION" / "_TYPES" / "ST_SafetyChecklist.st"
VIEW = ROOT / "CODE" / "DEPANNAGE" / "FB_TroubleshootingView.st"


def test_checklist_has_public_arming_observables() -> None:
    source = CHECKLIST.read_text(encoding="utf-8")
    required = (
        "Step4_ContactorReleased",
        "Step5_ArmingAllowed",
        "ArmingStep",
        "ArmingBusy",
        "LockoutActive",
        "PowerCutOffActive",
        "MaintainAActive",
        "MaintainBActive",
        "ArmingErrorId",
    )
    assert all(name in source for name in required)
    assert "Step4_ContactorRedundancyOk" not in source
    assert "BtnFaultReset" not in source
    assert "BtnEmergencyArming" in source


def test_view_projects_public_state_and_diagnostic_only() -> None:
    source = VIEW.read_text(encoding="utf-8")
    for name in ("EmergencyState", "EmergencyDiag", "PowerCutOffActive", "MaintainAActive", "MaintainBActive"):
        assert name in source
    assert "Step4_ContactorReleased     := NOT HwIn.Machine.PowerContactorEngaged_DI" in source
    assert "EmergencyState.Armable" in source
    assert "EmergencyDiag.LockoutActive" in source
    assert "EmergencyDiag.ErrorId" in source
    assert "Safety.ArmingErrorId" in source
    assert "EmergencyDiag.ArmFailed" in source
    assert "Step4_ContactorRedundancyOk" not in source
