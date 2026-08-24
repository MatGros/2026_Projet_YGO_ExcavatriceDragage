import importlib.util
import pathlib
import sys
import tempfile

TOOLS_DIR = pathlib.Path(__file__).resolve().parents[3]
if str(TOOLS_DIR / 'core') not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR / 'core'))

from results_layout import results_dir

MODULES_DIR = results_dir('FB_Safety_EmergencyManagement', 'modules')
CHRONICLES_DIR = results_dir('FB_Safety_EmergencyManagement', 'chronicles')

import fb_gen
from test_tracer import ExecutionTracer

REPO_ROOT = pathlib.Path(__file__).resolve().parents[6]
BUNDLE_PATH = REPO_ROOT / 'CODE' / 'CODE_Bundle.xml'


def _load_generated_emergency_module():
    # Dossier temp systeme (jamais dans out/) : out/ reste reserve aux artefacts
    # persistants (modules generes + rapports), pas aux dossiers de scratch des tests.
    tmp_dir = pathlib.Path(tempfile.mkdtemp(prefix='st2py-test-'))
    module_path, _, _ = fb_gen.generate_module_and_test(
        'FB_Safety_EmergencyManagement',  # NOSONAR generation en tmp_dir isole, pas dans out/ (evite pollution)
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
    tracer.export_html_report(CHRONICLES_DIR / "TC-P01-003_Chronicle_Report.html")


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

    tracer.export_html_report(CHRONICLES_DIR / "TC-P01-006_Chronicle_Report.html")


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

    tracer.export_html_report(CHRONICLES_DIR / "TC-P01-007_Chronicle_Report.html")


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

    tracer.export_html_report(CHRONICLES_DIR / "TC-P01-008_Chronicle_Report.html")


def test_tc_p01_004_reset_never_conditioned():
    """TC-P01-004 (REX 2026-08) : Reset TOUJOURS effectif, jamais conditionne par
    PowerContactorEngaged. Reproduit le bug terrain identifie en test CODESYS reel :
    l'ancienne regle 'Reset ET PowerContactorEngaged=TRUE' creait une impasse operateur
    car le contacteur ne peut justement pas s'engager tant que le defaut est actif."""
    module = _load_generated_emergency_module()
    fb = module.FB_Safety_EmergencyManagement()
    tracer = ExecutionTracer("TC-P01-004 Reset jamais conditionne")

    fb.Enable = True
    fb.EmergencyChainClosed = True
    fb.step(10.0)

    # Séquence complète jusqu'au timeout de confirmation (ArmingFailed)
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
    assert fb.ArmingSeqStep == 6

    # Timeout confirmation : PowerContactorEngaged reste FALSE (defaut reel non simule)
    fb.step(2000.0)
    fb.step(10.0)
    tracer.log_step(fb, 2210.0, "Timeout confirmation -> ArmingFailed, contacteur TOUJOURS FALSE")
    assert fb.EmergencyArmingFailed is True
    assert fb.PowerContactorEngaged is False  # le defaut persiste, contacteur non engage

    # Attendre fin du debounce d'affichage + tenter un Reset alors que la cause est
    # ENCORE presente (PowerContactorEngaged toujours FALSE) — reproduction exacte
    # du scenario terrain : l'operateur acquitte sans que le contacteur ait ete simule.
    fb.Reset = True
    fb.step(10.0)
    fb.Reset = False
    fb.step(10.0)
    tracer.log_step(fb, 20.0, "Reset presse SANS PowerContactorEngaged=TRUE -> doit etre effectif")

    # ✅ Le Reset doit acquitter l'affichage MEME si le contacteur n'est jamais engage.
    assert fb.EmergencyArmingFailed is False
    assert fb.Error is False

    # Le lockout 5s (interlock securite distinct, TC-P01-007) reste actif independamment
    # de l'acquittement — c'est attendu : Ack n'ouvre jamais un interlock de securite.
    assert fb.EmergencyArmingLockoutActive is True
    assert fb.State['Armable'] is False

    # Apres expiration du lockout, un nouvel armement redevient possible SANS que
    # l'acquittement en ait ete la condition (c'est ArmRequest qui relance, pas Reset).
    fb.step(5000.0)
    fb.step(10.0)
    tracer.log_step(fb, 5010.0, "Fin lockout 5s -> armement de nouveau possible")
    assert fb.EmergencyArmingLockoutActive is False
    assert fb.State['Armable'] is True

    tracer.export_html_report(CHRONICLES_DIR / "TC-P01-004_Chronicle_Report.html")


def test_tc_p01_009_relatch_after_premature_ack():
    """TC-P01-009 : un acquittement pendant que la cause est encore presente ne doit
    PAS empecher une nouvelle alarme si la cause reapparait lors d'une tentative
    suivante (pattern Cause/Ack — re-acquittement redemande a chaque nouvelle occurrence)."""
    module = _load_generated_emergency_module()
    fb = module.FB_Safety_EmergencyManagement()
    tracer = ExecutionTracer("TC-P01-009 Re-latch apres acquittement premature")

    fb.Enable = True
    fb.EmergencyChainClosed = True
    fb.step(10.0)

    # 1re tentative : échec redondance (canal A reste colle)
    fb.ArmRequest = True
    fb.step(10.0)
    fb.EmergencyChainClosed = True  # canal A ne s'ouvre pas -> redondance echoue
    fb.step(200.0)
    fb.step(10.0)
    tracer.log_step(fb, 210.0, "1re tentative : RedundancyTestFailed (canal colle)")
    assert fb.RedundancyTestFailed is True

    # Acquittement immediat (Reset toujours effectif)
    fb.Reset = True
    fb.step(10.0)
    fb.Reset = False
    fb.step(10.0)
    tracer.log_step(fb, 20.0, "Acquittement -> affichage efface")
    assert fb.RedundancyTestFailed is False

    # 2e tentative : la cause revient (canal encore colle) -> DOIT re-alarmer
    # sans nouvel acquittement, car un nouveau front de Cause remet Ack a FALSE.
    fb.ArmRequest = False
    fb.step(10.0)
    fb.ArmRequest = True
    fb.step(10.0)
    fb.EmergencyChainClosed = True  # toujours colle
    fb.step(200.0)
    fb.step(10.0)
    tracer.log_step(fb, 220.0, "2e tentative : cause revient -> re-alarme automatique")

    assert fb.RedundancyTestFailed is True  # re-latche, PAS besoin d'un nouveau defaut different

    tracer.export_html_report(CHRONICLES_DIR / "TC-P01-009_Chronicle_Report.html")
