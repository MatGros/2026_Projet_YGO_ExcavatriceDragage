import importlib.util
import pathlib
import sys
import tempfile

TOOLS_DIR = pathlib.Path(__file__).resolve().parents[3]
if str(TOOLS_DIR / 'core') not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR / 'core'))

from results_layout import results_dir

MODULES_DIR = results_dir('FB_Translation', 'modules')

import fb_gen
from data_contracts import build_position_decoder_contract, validate_contract


REPO_ROOT = pathlib.Path(__file__).resolve().parents[6]
BUNDLE_PATH = REPO_ROOT / 'CODE' / 'CODE_Bundle.xml'


def _load_generated_module(pou_name):
    # Dossier temp systeme (jamais dans out/) : out/ reste reserve aux artefacts
    # persistants (modules generes + rapports), pas aux dossiers de scratch des tests.
    tmp_dir = pathlib.Path(tempfile.mkdtemp(prefix='st2py-test-'))
    module_path, _, _ = fb_gen.generate_module_and_test(pou_name, str(tmp_dir), bundle_path=str(BUNDLE_PATH))
    spec = importlib.util.spec_from_file_location(pou_name, module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_translation_moves_to_done_when_target_is_reached():
    module = _load_generated_module('FB_Translation')
    fb = module.FB_Translation()
    fb.Enable = True
    fb.EmergencyStopOk = True
    fb.StartStop = True
    fb.SpeedRefPct = 80.0
    fb.CaptorDebounce = 5.0

    fb.step(10.0)
    assert fb.State == 'MOVING'

    fb.PositionSensorTarget = True
    fb.step(10.0)
    assert fb.State == 'DONE'
    assert fb.Done is True
    assert fb.Busy is False


def test_translation_safe_stop_sets_fault():
    module = _load_generated_module('FB_Translation')
    fb = module.FB_Translation()
    fb.Enable = True
    fb.EmergencyStopOk = True
    fb.SafeStop = True

    fb.step(10.0)
    assert fb.Error is True
    assert fb.ErrorId == 1
    assert fb.State == 'FAULT'


def test_translation_passes_through_slowdown_before_target():
    """AF-TR-02 : la branche de reduction de vitesse est traversee avant la cible.

    Arriver a DONE ne prouve pas que le ralentissement a eu lieu : l'etat SLOWDOWN
    est donc verifie explicitement AVANT l'atteinte de cible.
    """
    module = _load_generated_module('FB_Translation')
    fb = module.FB_Translation()
    fb.Enable = True
    fb.EmergencyStopOk = True
    fb.StartStop = True
    fb.SpeedRefPct = 80.0
    fb.CaptorDebounce = 5.0

    fb.step(10.0)
    assert fb.State == 'MOVING'

    fb.SlowdownSensor = True
    fb.step(10.0)
    assert fb.State == 'SLOWDOWN'

    fb.PositionSensorTarget = True
    fb.step(10.0)
    assert fb.State == 'DONE'
    assert fb.Done is True
    assert fb.Error is False


def test_translation_reset_requires_cause_to_disappear_first():
    """AF-TR-04 : Reset n'acquitte que si la cause a disparu (regle projet).

    Deux phases distinctes, sinon le test ne prouve rien : un Reset appuye alors que
    SafeStop est toujours actif NE DOIT PAS reamorcer (jamais de redemarrage sous
    cause presente) ; une fois la cause levee, un nouvel appui ramene en IDLE.
    """
    module = _load_generated_module('FB_Translation')
    fb = module.FB_Translation()
    fb.Enable = True
    fb.EmergencyStopOk = True
    fb.StartStop = True
    fb.SafeStop = True

    fb.step(10.0)
    assert fb.State == 'FAULT'

    # Phase 1 : Reset alors que la cause est TOUJOURS presente -> reste en defaut.
    fb.Reset = True
    fb.step(10.0)
    assert fb.State == 'FAULT', "Reset ne doit pas acquitter tant que SafeStop est actif"

    # Phase 2 : la cause disparait, mais l'ordre de marche est TOUJOURS enclenche.
    # Le FB doit rester en defaut : disparition de la cause != acquittement.
    fb.Reset = False
    fb.SafeStop = False
    fb.step(10.0)
    assert fb.State == 'FAULT', "la disparition de la cause ne doit pas acquitter seule"

    # Phase 3 : ordre de marche relache (l'operateur reprend la main), puis appui
    # conscient sur Reset -> retour en IDLE, sans repartir tout seul.
    fb.StartStop = False
    fb.Reset = True
    fb.step(10.0)
    assert fb.State == 'IDLE'
    assert fb.Error is False
    assert fb.Ready is True

    # Et surtout : pas de redemarrage automatique au cycle suivant.
    fb.Reset = False
    fb.step(10.0)
    assert fb.State == 'IDLE', "aucun redemarrage automatique apres acquittement"


def test_validation_accepts_generated_translation_module():
    module = _load_generated_module('FB_Translation')
    module_source = pathlib.Path(module.__file__).read_text(encoding='utf-8')
    interface = fb_gen.extract_pou_interface(str(BUNDLE_PATH), 'FB_Translation')
    validation = fb_gen.validate_generated_module('FB_Translation', interface, module_source)
    assert validation['valid'] is True
    assert validation['encapsulated'] is True
    assert validation['io_coherent'] is True


def test_position_decoder_contract_validates_coherent_payloads():
    contract = build_position_decoder_contract()
    payloads = {
        'inputs': {
            'SensorTremie': True,
            'SensorPV': True,
            'SensorP2': False,
            'SensorP1': False,
            'SensorMaintenance': False,
        },
        'outputs': {
            'SensorsWord': 0x18,
            'Incoherent': False,
            'LimitSwitchFwd': False,
            'LimitSwitchRev': False,
        },
        'state': {},
    }
    assert validate_contract(contract, payloads) == []


def test_generated_translation_module_exposes_contract_and_validator():
    module = _load_generated_module('FB_Translation')
    assert hasattr(module, 'CONTRACT')
    assert 'inputs' in module.CONTRACT
    assert 'outputs' in module.CONTRACT
    inputs_payload = {}
    for field in module.CONTRACT['inputs']:
        inputs_payload[field['name']] = field['default']
    assert module.validate_runtime_contract(inputs_payload, 'inputs') == []


def test_validation_rejects_non_encapsulated_module():
    bad_source = '''# bad module\nvalue = 1\n\ndef step():\n    return None\n'''
    interface = {
        'inputs': [{'name': 'Enable', 'type': 'BOOL', 'python_type': 'bool'}],
        'outputs': [{'name': 'Ready', 'type': 'BOOL', 'python_type': 'bool'}],
    }
    validation = fb_gen.validate_generated_module('FB_Bad', interface, bad_source)
    assert validation['valid'] is False
    assert validation['encapsulated'] is False
    assert any(
        'Missing required methods' in error or 'does not define the expected class' in error
        for error in validation['errors']
    )
