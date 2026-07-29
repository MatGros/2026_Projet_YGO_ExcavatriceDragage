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
from data_contracts import build_position_decoder_contract, validate_contract


REPO_ROOT = pathlib.Path(__file__).resolve().parents[4]
BUNDLE_PATH = REPO_ROOT / 'CODE' / 'CODE_Bundle.xml'


def _load_generated_module(pou_name):
    tmp_dir = pathlib.Path(tempfile.mkdtemp(prefix='st2py-test-', dir=str(TOOLS_DIR / 'out')))
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
