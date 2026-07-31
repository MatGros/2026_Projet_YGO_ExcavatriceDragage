import importlib.util
import pathlib
import sys
import tempfile

TOOLS_DIR = pathlib.Path(__file__).resolve().parents[2]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

OUT_DIR = TOOLS_DIR / 'out'
OUT_DIR.mkdir(parents=True, exist_ok=True)

import fb_gen
from test_tracer import ExecutionTracer

REPO_ROOT = pathlib.Path(__file__).resolve().parents[4]
BUNDLE_PATH = REPO_ROOT / 'CODE' / 'CODE_AU_Bundle.xml'


def _load_generated_emergency_module():
    tmp_dir = pathlib.Path(tempfile.mkdtemp(prefix='st2py-test-', dir=str(TOOLS_DIR / 'out')))
    module_path, _, _ = fb_gen.generate_module_and_test(
        'FB_Safety_EmergencyManagement',
        str(tmp_dir),
        bundle_path=str(BUNDLE_PATH)
    )
    spec = importlib.util.spec_from_file_location('FB_Safety_EmergencyManagement', module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_tc_p01_003_arming_sequence_nominal():
    """TC-P01-003: Front ArmRequest + chain OK -> Auto-test A/B -> Pulse 1s -> Confirm -> Done"""
    module = _load_generated_emergency_module()
    fb = module.FB_Safety_EmergencyManagement()
    tracer = ExecutionTracer("TC-P01-003 Réarmement Nominal")

    # Step 0: Boot - Enable + EmergencyChainClosed
    fb.Enable = True
    fb.EmergencyChainClosed = True
    fb.PowerContactorEngaged = False
    fb.step(10.0)
    tracer.log_step(fb, 10.0, "Boot Enable=TRUE")

    assert fb.Ready is True
    assert fb.ArmingSeqStep == 0
    assert fb.State['Armable'] is True

    # Step 1: ArmRequest rising edge -> enters TestA (step 1)
    fb.ArmRequest = True
    fb.step(10.0)
    tracer.log_step(fb, 10.0, "Front ArmRequest=TRUE")
    assert fb.ArmingSeqStep == 1  # TestA

    # TestA: 200ms duration. Chain opens during test.
    fb.EmergencyChainClosed = False
    fb.step(200.0)
    fb.step(10.0)
    tracer.log_step(fb, 210.0, "Fin TestA -> Transition Step 2")
    assert fb.ArmingSeqStep == 2  # RestoreA

    # RestoreA: 200ms duration. Chain closes.
    fb.EmergencyChainClosed = True
    fb.step(200.0)
    fb.step(10.0)
    tracer.log_step(fb, 210.0, "Fin RestoreA -> Transition Step 3")
    assert fb.ArmingSeqStep == 3  # TestB

    # TestB: 200ms duration. Chain opens.
    fb.EmergencyChainClosed = False
    fb.step(200.0)
    fb.step(10.0)
    tracer.log_step(fb, 210.0, "Fin TestB -> Transition Step 4")
    assert fb.ArmingSeqStep == 4  # RestoreB

    # RestoreB: 200ms duration. Chain closes.
    fb.EmergencyChainClosed = True
    fb.step(200.0)
    fb.step(10.0)
    tracer.log_step(fb, 210.0, "Fin RestoreB -> Transition Step 5 (Pulse)")
    assert fb.ArmingSeqStep == 5  # Pulse
    assert fb.ArmPulse_RQ is True

    # Pulse: 1000ms duration.
    fb.step(1000.0)
    fb.step(10.0)
    tracer.log_step(fb, 1010.0, "Fin Pulse 1s -> Transition Step 6 (Confirm)")
    assert fb.ArmingSeqStep == 6  # Confirm

    # Simulate contactor confirmation
    fb.PowerContactorEngaged = True
    fb.step(10.0)
    tracer.log_step(fb, 10.0, "PowerContactorEngaged=TRUE -> Done")
    assert fb.ArmingSeqStep == 0
    assert fb.Done is True
    assert fb.Error is False

    # Export HTML report
    tracer.export_html_report(OUT_DIR / "TC-P01-003_Chronicle_Report.html")


def test_tc_p01_006_redundancy_test_failure():
    """TC-P01-006: Auto-test A/B - canal A collé (EmergencyChainClosed reste True pendant TestA) -> RedundancyTestFailed"""
    module = _load_generated_emergency_module()
    fb = module.FB_Safety_EmergencyManagement()
    tracer = ExecutionTracer("TC-P01-006 Échec Redondance Canal A Collé")

    fb.Enable = True
    fb.EmergencyChainClosed = True
    fb.step(10.0)
    tracer.log_step(fb, 10.0, "Boot Enable=TRUE")

    fb.ArmRequest = True
    fb.step(10.0)
    tracer.log_step(fb, 10.0, "Front ArmRequest=TRUE")
    assert fb.ArmingSeqStep == 1  # TestA

    # Chain remains closed (simulate welded/bridged contactor)
    fb.EmergencyChainClosed = True
    fb.step(200.0)
    fb.step(10.0)
    tracer.log_step(fb, 210.0, "Fin TestA -> Détection Canal Collé")

    assert fb.RedundancyTestFailed is True
    assert fb.Error is True
    assert (fb.ErrorId & 0x0001) != 0
    assert fb.ArmingSeqStep == 0

    tracer.export_html_report(OUT_DIR / "TC-P01-006_Chronicle_Report.html")


def test_tc_p01_007_lockout_after_confirmation_timeout():
    """TC-P01-007: Confirmation contacteur timeout (2s) -> ArmingFailed + Lockout 5s"""
    module = _load_generated_emergency_module()
    fb = module.FB_Safety_EmergencyManagement()
    tracer = ExecutionTracer("TC-P01-007 Timeout Confirmation + Lockout 5s")

    fb.Enable = True
    fb.EmergencyChainClosed = True
    fb.step(10.0)

    fb.ArmRequest = True
    fb.step(10.0)
    fb.EmergencyChainClosed = False
    fb.step(200.0)
    fb.step(10.0)
    fb.EmergencyChainClosed = True
    fb.step(200.0)
    fb.step(10.0)
    fb.EmergencyChainClosed = False
    fb.step(200.0)
    fb.step(10.0)
    fb.EmergencyChainClosed = True
    fb.step(200.0)
    fb.step(10.0)
    fb.step(1000.0)
    fb.step(10.0)
    tracer.log_step(fb, 1850.0, "Début Étape 6 (Confirm)")

    assert fb.ArmingSeqStep == 6

    # Do not set PowerContactorEngaged, wait 2000ms
    fb.step(2000.0)
    fb.step(10.0)
    tracer.log_step(fb, 2010.0, "Timeout 2s -> ArmingFailed + Lockout 5s")
    assert fb.EmergencyArmingFailed is True
    assert fb.EmergencyArmingLockoutActive is True
    assert fb.ArmingSeqStep == 0

    # Wait 5000ms lockout
    fb.step(5000.0)
    fb.step(10.0)
    tracer.log_step(fb, 5010.0, "Fin Lockout 5s")
    assert fb.EmergencyArmingLockoutActive is False

    tracer.export_html_report(OUT_DIR / "TC-P01-007_Chronicle_Report.html")


def test_tc_p01_008_safety_power_cutoff_request():
    """TC-P01-008: PowerCutOffRequest = True forces MaintainA_RQ et MaintainB_RQ à False"""
    module = _load_generated_emergency_module()
    fb = module.FB_Safety_EmergencyManagement()
    tracer = ExecutionTracer("TC-P01-008 Coupure Sécurité Métier")

    fb.Enable = True
    fb.EmergencyChainClosed = True
    fb.step(10.0)
    tracer.log_step(fb, 10.0, "Boot - Maintien A/B actif")

    assert fb.MaintainA_RQ is True
    assert fb.MaintainB_RQ is True

    # Request safety cutoff
    fb.PowerCutOffRequest = True
    fb.step(10.0)
    tracer.log_step(fb, 10.0, "PowerCutOffRequest=TRUE -> Maintien A/B coupé")

    assert fb.MaintainA_RQ is False
    assert fb.MaintainB_RQ is False

    tracer.export_html_report(OUT_DIR / "TC-P01-008_Chronicle_Report.html")
