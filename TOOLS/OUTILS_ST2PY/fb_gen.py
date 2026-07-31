#!/usr/bin/env python3
"""fb_gen.py

Générateur minimal d'un module Python + test pour un POU/FB donné à partir d'un bundle PLCopen XML.
Usage:
  python fb_gen.py --bundle <path> --pou <POU_NAME> --out <outdir> [--force]

Comportement:
  - extrait le POU par nom depuis le bundle (ElementTree, namespace-aware)
  - calcule un hash canonical (SHA256)
  - compare avec .st2py_cache.json et skip si inchangé (sauf --force)
  - génère out/<POU>.py et out/tests/test_<POU>.py et out/<POU>.meta.json
  - met à jour .st2py_cache.json
"""
import argparse
import ast
import hashlib
import json
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from datetime import datetime

NS = {'pc': 'http://www.plcopen.org/xml/tc6_0200'}
CACHE_NAME = '.st2py_cache.json'
CURRENT_BUNDLE_PATH = None

from canonicalize import canonicalize_pou_bytes
from data_contracts import build_contract_from_interface, build_position_decoder_contract, build_translation_contract, FieldSpec


def compute_hash(bytes_blob):
    return hashlib.sha256(bytes_blob).hexdigest()


def load_cache(base_dir):
    path = os.path.join(base_dir, CACHE_NAME)
    if os.path.exists(path):
        try:
            with open(path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            return {}
    return {}


def save_cache(base_dir, cache):
    path = os.path.join(base_dir, CACHE_NAME)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(cache, f, indent=2, ensure_ascii=False)


def git_changed_files(ref):
    cmd = ['git', 'diff', '--name-only', f'{ref}..HEAD']
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        print('git diff failed:', p.stderr)
        sys.exit(2)
    files = [l.strip() for l in p.stdout.splitlines() if l.strip()]
    return files


def extract_pou_from_st(path):
    prog = re.compile(r'^\s*FUNCTION_BLOCK\s+PUBLIC\s+([A-Za-z0-9_]+)', re.IGNORECASE)
    try:
        with open(path, 'r', encoding='utf-8') as f:
            for line in f:
                m = prog.match(line)
                if m:
                    return m.group(1)
    except Exception as e:
        print('Error reading', path, e)
    return None


def list_pous_from_bundle(bundle_path):
    tree = ET.parse(bundle_path)
    root = tree.getroot()
    names = []
    for pou in root.findall('.//pc:pou', NS):
        name = pou.get('name')
        if name:
            names.append(name)
    return names


def _extract_variable_type(variable_elem):
    type_elem = variable_elem.find('pc:type', NS)
    if type_elem is None:
        return 'object'
    if type_elem.find('pc:BOOL', NS) is not None:
        return 'BOOL'
    if type_elem.find('pc:BYTE', NS) is not None:
        return 'BYTE'
    if type_elem.find('pc:WORD', NS) is not None:
        return 'WORD'
    if type_elem.find('pc:INT', NS) is not None:
        return 'INT'
    if type_elem.find('pc:REAL', NS) is not None:
        return 'REAL'
    if type_elem.find('pc:TIME', NS) is not None:
        return 'TIME'
    derived = type_elem.find('pc:derived', NS)
    if derived is not None:
        return derived.get('name', 'object')
    return 'object'


def _python_type_for_plc_type(type_name):
    if type_name in {'BOOL'}:
        return 'bool'
    if type_name in {'BYTE', 'WORD', 'INT', 'UINT', 'USINT', 'SINT', 'DWORD', 'LWORD', 'DINT', 'UDINT', 'LINT', 'ULINT'}:
        return 'int'
    if type_name in {'REAL', 'LREAL'}:
        return 'float'
    if type_name in {'TIME'}:
        return 'float'
    return 'object'


def extract_pou_interface(bundle_path, pou_name):
    tree = ET.parse(bundle_path)
    root = tree.getroot()
    pou_elem = None
    for pou in root.findall('.//pc:pou', NS):
        if pou.get('name') == pou_name:
            pou_elem = pou
            break
    if pou_elem is None:
        raise FileNotFoundError(f'POU {pou_name} not found in bundle')

    interface = pou_elem.find('pc:interface', NS)
    if interface is None:
        return {'inputs': [], 'outputs': []}

    def parse_vars(container_name):
        vars_node = interface.find(container_name, NS)
        variables = []
        if vars_node is None:
            return variables
        for variable_elem in vars_node.findall('pc:variable', NS):
            name = variable_elem.get('name')
            if not name:
                continue
            plc_type = _extract_variable_type(variable_elem)
            variables.append({
                'name': name,
                'type': plc_type,
                'python_type': _python_type_for_plc_type(plc_type),
            })
        return variables

    return {
        'inputs': parse_vars('pc:inputVars'),
        'outputs': parse_vars('pc:outputVars'),
    }


def load_safety_tokens():
    """Charger la liste de tokens safety depuis safety_tokens.json situé au même niveau que ce script.
    Si le fichier est absent ou illisible, retourne la liste par défaut intégrée."""
    default = [
        'EmergencyStop',
        'PowerCutOff',
        'SafeStop',
        'StartStop',
        'CoupeEnable',
        'FB_Watchdog',
    ]
    try:
        here = os.path.dirname(__file__)
        path = os.path.join(here, 'safety_tokens.json')
        if os.path.exists(path):
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            if isinstance(data, list) and all(isinstance(x, str) for x in data):
                return data
            print('safety_tokens.json malformed; using defaults')
            return default
        return default
    except Exception as e:
        print('Cannot load safety_tokens.json:', e)
        return default


SAFETY_TOKENS = load_safety_tokens()


def scan_for_safety_tokens(canonical_bytes):
    found = []
    try:
        text = canonical_bytes.decode('utf-8', errors='ignore')
    except Exception:
        text = str(canonical_bytes)
    tl = text.lower()
    for token in SAFETY_TOKENS:
        if token.lower() in tl:
            found.append(token)
    return found


def write_safety_report(out_dir, pou, found_tokens):
    report = {
        'pou': pou,
        'blocked': True,
        'found_tokens': found_tokens,
        'timestamp': datetime.now().astimezone().isoformat(),
    }
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f'{pou}.safety_report.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    return path


def _default_value_for_type(python_type):
    if python_type == 'bool':
        return 'False'
    if python_type == 'float':
        return '0.0'
    if python_type == 'int':
        return '0'
    return 'None'


def _is_valid_python_identifier(name):
    return bool(re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name))


def validate_interface_contract(interface, pou_name):
    errors = []
    inputs = interface.get('inputs', [])
    outputs = interface.get('outputs', [])

    if not pou_name:
        errors.append('POU name is empty')
    elif not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', pou_name):
        errors.append('POU name is not a valid Python class name')

    if not inputs:
        errors.append('The POU has no input variables; generation is blocked')
    if not outputs:
        errors.append('The POU has no output variables; generation is blocked')

    names = []
    for var in inputs + outputs:
        name = var.get('name', '')
        if not name:
            errors.append('A variable has no name')
            continue
        if not _is_valid_python_identifier(name):
            errors.append(f'Variable name {name!r} is not a valid Python identifier')
        if name in names:
            errors.append(f'Variable name {name!r} is duplicated between inputs and outputs')
        names.append(name)

    return {
        'valid': not errors,
        'encapsulated': not errors,
        'io_coherent': not errors,
        'errors': errors,
        'input_count': len(inputs),
        'output_count': len(outputs),
    }


def validate_generated_module(pou_name, interface, module_source):
    interface_validation = validate_interface_contract(interface, pou_name)
    errors = list(interface_validation['errors'])

    try:
        tree = ast.parse(module_source)
    except SyntaxError as exc:
        errors.append(f'Generated module is not valid Python: {exc}')
        return {
            'valid': False,
            'encapsulated': False,
            'io_coherent': False,
            'errors': errors,
            'input_count': interface_validation['input_count'],
            'output_count': interface_validation['output_count'],
        }

    has_contract = False
    has_validator = False
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id == 'CONTRACT':
                    has_contract = True
        if isinstance(node, ast.FunctionDef) and node.name == 'validate_runtime_contract':
            has_validator = True
    if not has_contract:
        errors.append('Generated module does not define a data contract')
    if not has_validator:
        errors.append('Generated module does not define a runtime contract validator')

    class_def = None
    for node in tree.body:
        if isinstance(node, ast.ClassDef) and node.name == pou_name:
            class_def = node
            break

    if class_def is None:
        errors.append('The generated module does not define the expected class')
        return {
            'valid': False,
            'encapsulated': False,
            'io_coherent': False,
            'errors': errors,
            'input_count': interface_validation['input_count'],
            'output_count': interface_validation['output_count'],
        }

    top_level_nodes = []
    for node in tree.body:
        if isinstance(node, ast.Expr) and isinstance(node.value, ast.Constant) and isinstance(node.value.value, str):
            continue
        if isinstance(node, ast.ClassDef) and node.name == pou_name:
            top_level_nodes.append(node)
            continue
        if isinstance(node, ast.FunctionDef) and node.name == 'validate_runtime_contract':
            top_level_nodes.append(node)
            continue
        if isinstance(node, ast.Assign):
            if all(isinstance(target, ast.Name) for target in node.targets):
                top_level_nodes.append(node)
                continue
        if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
            top_level_nodes.append(node)
            continue
        errors.append('The module should only contain a docstring, module constants, and the generated class')
        break

    if not any(isinstance(node, ast.ClassDef) and node.name == pou_name for node in tree.body):
        errors.append('The generated module does not define the expected class')

    required_methods = ['__init__', 'step', 'set_inputs_from_mapping', 'set_outputs_from_mapping', 'to_dict']
    missing_methods = []
    for method_name in required_methods:
        if not any(isinstance(node, ast.FunctionDef) and node.name == method_name for node in class_def.body):
            missing_methods.append(method_name)
    if missing_methods:
        errors.append(f'Missing required methods: {", ".join(missing_methods)}')

    init_method = next((node for node in class_def.body if isinstance(node, ast.FunctionDef) and node.name == '__init__'), None)
    initialized_attributes = set()
    if init_method is not None:
        for node in ast.walk(init_method):
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if isinstance(target, ast.Attribute) and isinstance(target.value, ast.Name) and target.value.id == 'self':
                        initialized_attributes.add(target.attr)
            elif isinstance(node, ast.AnnAssign):
                target = node.target
                if isinstance(target, ast.Attribute) and isinstance(target.value, ast.Name) and target.value.id == 'self':
                    initialized_attributes.add(target.attr)

    expected_attributes = [var['name'] for var in interface.get('inputs', [])] + [var['name'] for var in interface.get('outputs', [])]
    missing_attributes = [name for name in expected_attributes if name not in initialized_attributes]
    if missing_attributes:
        errors.append(f'Init block does not initialize all declared interface members: {", ".join(missing_attributes)}')

    return {
        'valid': not errors,
        'encapsulated': not any(error.startswith('Missing required methods') or error.startswith('The module should only contain') for error in errors),
        'io_coherent': not any(error.startswith('Init block does not initialize') or error.startswith('The POU has no') or error.startswith('Variable name') for error in errors),
        'errors': errors,
        'input_count': interface_validation['input_count'],
        'output_count': interface_validation['output_count'],
    }


def write_validation_report(out_dir, pou_name, validation):
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f'{pou_name}.validation_report.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(validation, f, indent=2, ensure_ascii=False)
    return path


def render_translation_position_decoder_module_code(pou_name):
    contract = build_position_decoder_contract()
    contract_literal = repr(contract.to_dict())
    return f'''# {pou_name}.py
"""
Prototype de module Python pour {pou_name}.
Ce modèle reproduit la logique de décodage combinatoire du FB avec une API step().
"""

VALID_WORDS = {{
    0b11111,
    0b01111,
    0b00111,
    0b00011,
    0b00001,
    0b00000,
}}

CONTRACT = {contract_literal}


def validate_runtime_contract(payload: dict, scope: str = 'inputs') -> list:
    if not isinstance(payload, dict):
        return ['payload must be a mapping']
    fields = CONTRACT.get(scope, [])
    errors = []
    for field in fields:
        name = field['name']
        if name not in payload:
            errors.append(f'missing {{scope}} field {{name}}')
            continue
        value = payload[name]
        expected_type = field['type']
        if expected_type == 'bool' and not isinstance(value, bool):
            errors.append(f'{{scope}} field {{name}} should be bool')
        elif expected_type == 'int' and not isinstance(value, int):
            errors.append(f'{{scope}} field {{name}} should be int')
        elif expected_type == 'float' and not isinstance(value, float):
            errors.append(f'{{scope}} field {{name}} should be float')
        elif expected_type == 'str' and not isinstance(value, str):
            errors.append(f'{{scope}} field {{name}} should be str')
    return errors


class {pou_name}:
    def __init__(self) -> None:
        self.SensorTremie: bool = False
        self.SensorPV: bool = False
        self.SensorP2: bool = False
        self.SensorP1: bool = False
        self.SensorMaintenance: bool = False
        self.LimitSwitchFwd: bool = False
        self.LimitSwitchRev: bool = False
        self.Incoherent: bool = False
        self.SensorsWord: int = 0

    def step(self) -> None:
        word = 0
        if bool(self.SensorTremie):
            word |= 0x10
        if bool(self.SensorPV):
            word |= 0x08
        if bool(self.SensorP2):
            word |= 0x04
        if bool(self.SensorP1):
            word |= 0x02
        if bool(self.SensorMaintenance):
            word |= 0x01

        self.SensorsWord = word
        self.Incoherent = self.SensorsWord not in VALID_WORDS
        self.LimitSwitchFwd = (not self.Incoherent) and (self.SensorsWord == 0b11111)
        self.LimitSwitchRev = (not self.Incoherent) and (self.SensorsWord == 0b00000)

    def set_inputs_from_mask(self, mask: int) -> None:
        self.SensorTremie = bool(mask & 0x10)
        self.SensorPV = bool(mask & 0x08)
        self.SensorP2 = bool(mask & 0x04)
        self.SensorP1 = bool(mask & 0x02)
        self.SensorMaintenance = bool(mask & 0x01)

    def set_inputs_from_mapping(self, values: dict) -> None:
        for name, value in values.items():
            if hasattr(self, name):
                setattr(self, name, value)

    def set_outputs_from_mapping(self, values: dict) -> None:
        for name, value in values.items():
            if hasattr(self, name):
                setattr(self, name, value)

    def to_dict(self):
        return {{
            'SensorsWord': self.SensorsWord,
            'Incoherent': self.Incoherent,
            'LimitSwitchFwd': self.LimitSwitchFwd,
            'LimitSwitchRev': self.LimitSwitchRev,
        }}
'''


def render_translation_module_code(pou_name, interface):
    inputs = interface.get('inputs', [])
    outputs = interface.get('outputs', [])
    contract = build_translation_contract(interface)
    contract_literal = repr(contract.to_dict())

    def render_init_block():
        lines = []
        for var in inputs:
            lines.append(f'        self.{var["name"]}: {var["python_type"]} = {_default_value_for_type(var["python_type"])}')
        for var in outputs:
            lines.append(f'        self.{var["name"]}: {var["python_type"]} = {_default_value_for_type(var["python_type"])}')
        for field in contract.state:
            annotation = {'bool': 'bool', 'int': 'int', 'float': 'float', 'str': 'str'}.get(field.type, 'object')
            default = repr(field.default) if field.default is not None else 'None'
            lines.append(f'        self.{field.name}: {annotation} = {default}')
        return '\n'.join(lines)

    input_names = [var['name'] for var in inputs]
    output_names = [var['name'] for var in outputs]

    output_dict_body = []
    for name in output_names:
        output_dict_body.append(f"            '{name}': self.{name},")
    output_dict_body = '\n'.join(output_dict_body) if output_dict_body else "            'status': 'prototype'"

    return f'''# {pou_name}.py
"""
Prototype de module Python pour {pou_name}.
Ce modèle reproduit un comportement de FB de translation proche du cycle PLC avec une machine d'état simple
et une temporisation minimale pour la simulation hors-PLC.
"""

CONTRACT = {contract_literal}


def validate_runtime_contract(payload: dict, scope: str = 'inputs') -> list:
    if not isinstance(payload, dict):
        return ['payload must be a mapping']
    fields = CONTRACT.get(scope, [])
    errors = []
    for field in fields:
        name = field['name']
        if name not in payload:
            errors.append(f'missing {{scope}} field {{name}}')
            continue
        value = payload[name]
        expected_type = field['type']
        if expected_type == 'bool' and not isinstance(value, bool):
            errors.append(f'{{scope}} field {{name}} should be bool')
        elif expected_type == 'int' and not isinstance(value, int):
            errors.append(f'{{scope}} field {{name}} should be int')
        elif expected_type == 'float' and not isinstance(value, float):
            errors.append(f'{{scope}} field {{name}} should be float')
        elif expected_type == 'str' and not isinstance(value, str):
            errors.append(f'{{scope}} field {{name}} should be str')
    return errors


class {pou_name}:
    def __init__(self) -> None:
{render_init_block()}

    def _set_idle(self) -> None:
        self.Ready = True
        self.Busy = False
        self.Done = False
        self.Error = False
        self.ErrorId = 0
        self.TargetReached = False
        self.DriveControlWord = 0
        self.DriveFreqRefHz = 0.0
        self.BrakeCmd = False
        self.State = "IDLE"

    def _set_fault(self, error_id: int, state_name: str = "FAULT") -> None:
        self.Error = True
        self.ErrorId = error_id
        self.StateAtError = self.State if self.State not in {{None, ''}} else state_name
        self.State = state_name
        self.Busy = False
        self.Done = False
        self.Ready = False
        self.TargetReached = False
        self.DriveControlWord = 0
        self.DriveFreqRefHz = 0.0
        self.BrakeCmd = True

    def step(self, time_ms: float = 10.0) -> None:
        time_ms = max(float(time_ms), 0.0)
        reset_edge = bool(self.Reset) and not self._prev_reset
        enable_edge = bool(self.Enable) and not self._prev_enable
        safe_stop_edge = bool(self.SafeStop) and not self._prev_safe_stop
        start_edge = bool(self.StartStop) and not self._prev_start_stop

        self._prev_reset = bool(self.Reset)
        self._prev_enable = bool(self.Enable)
        self._prev_safe_stop = bool(self.SafeStop)
        self._prev_start_stop = bool(self.StartStop)

        if reset_edge and self.Error:
            self._state = "IDLE"
            self._state_timer_ms = 0.0
            self._set_idle()
            return

        if not self.EmergencyStopOk or not self.Enable:
            self._state = "IDLE"
            self._state_timer_ms = 0.0
            self._set_idle()
            return

        if self.SafeStop or safe_stop_edge:
            self._set_fault(1, "FAULT")
            return

        if self._state == "IDLE":
            if start_edge or self.StartStop:
                self._state = "MOVING"
                self._state_timer_ms = 0.0
                self.Ready = False
                self.Busy = True
                self.Done = False
                self.Error = False
                self.ErrorId = 0
                self.TargetReached = False
                self.DriveControlWord = 0x03
                self.DriveFreqRefHz = max(abs(float(self.SpeedRefPct)), 0.0)
                self.BrakeCmd = False
                self.State = self._state
                return
            self._set_idle()
            return

        if self._state == "MOVING":
            self._state_timer_ms += time_ms
            self.DriveControlWord = 0x03
            self.DriveFreqRefHz = max(abs(float(self.SpeedRefPct)), 0.0)
            if self.PositionSensorTarget:
                self._state = "DONE"
                self.Busy = False
                self.Done = True
                self.Ready = True
                self.TargetReached = True
                self.State = self._state
                return
            if self.SlowdownSensor:
                self._state = "SLOWDOWN"
                self._state_timer_ms = 0.0
                self.DriveFreqRefHz = max(abs(float(self.SpeedRefPct)) * 0.5, 0.0)
                self.State = self._state
                return
            self.State = self._state
            return

        if self._state == "SLOWDOWN":
            self._state_timer_ms += time_ms
            self.DriveControlWord = 0x01
            self.DriveFreqRefHz = max(abs(float(self.SpeedRefPct)) * 0.5, 0.0)
            if self.PositionSensorTarget or self._state_timer_ms >= max(float(self.CaptorDebounce), 0.0):
                self._state = "DONE"
                self.Busy = False
                self.Done = True
                self.Ready = True
                self.TargetReached = True
                self.State = self._state
                return
            self.State = self._state
            return

        if self._state == "DONE":
            self.Busy = False
            self.Done = True
            self.Ready = True
            self.TargetReached = True
            self.DriveControlWord = 0x00
            self.DriveFreqRefHz = 0.0
            self.BrakeCmd = True
            self.State = self._state
            return

        self._set_idle()

    def set_inputs_from_mapping(self, values: dict) -> None:
        for name, value in values.items():
            if hasattr(self, name):
                setattr(self, name, value)

    def set_outputs_from_mapping(self, values: dict) -> None:
        for name, value in values.items():
            if hasattr(self, name):
                setattr(self, name, value)

    def to_dict(self):
        return {{
{output_dict_body}
        }}
'''


def render_safety_translation_module_code(pou_name, interface):
    inputs = interface.get('inputs', [])
    outputs = interface.get('outputs', [])
    contract = build_translation_contract(interface)
    contract_literal = repr(contract.to_dict())

    def render_init_block():
        lines = []
        for var in inputs:
            lines.append(f'        self.{var["name"]}: {var["python_type"]} = {_default_value_for_type(var["python_type"])}')
        for var in outputs:
            lines.append(f'        self.{var["name"]}: {var["python_type"]} = {_default_value_for_type(var["python_type"])}')
        for field in contract.state:
            annotation = {'bool': 'bool', 'int': 'int', 'float': 'float', 'str': 'str'}.get(field.type, 'object')
            default = repr(field.default) if field.default is not None else 'None'
            lines.append(f'        self.{field.name}: {annotation} = {default}')
        return '\n'.join(lines)

    output_dict_body = []
    for name in [var['name'] for var in outputs]:
        output_dict_body.append(f"            '{name}': self.{name},")
    output_dict_body = '\n'.join(output_dict_body) if output_dict_body else "            'status': 'prototype'"

    return f'''# {pou_name}.py
"""
Prototype de module Python pour {pou_name}.
Ce modèle reproduit un comportement simplifié du bloc safety de translation pour la simulation hors-PLC.
"""

CONTRACT = {contract_literal}


def validate_runtime_contract(payload: dict, scope: str = 'inputs') -> list:
    if not isinstance(payload, dict):
        return ['payload must be a mapping']
    fields = CONTRACT.get(scope, [])
    errors = []
    for field in fields:
        name = field['name']
        if name not in payload:
            errors.append(f'missing {{scope}} field {{name}}')
            continue
        value = payload[name]
        expected_type = field['type']
        if expected_type == 'bool' and not isinstance(value, bool):
            errors.append(f'{{scope}} field {{name}} should be bool')
        elif expected_type == 'int' and not isinstance(value, int):
            errors.append(f'{{scope}} field {{name}} should be int')
        elif expected_type == 'float' and not isinstance(value, float):
            errors.append(f'{{scope}} field {{name}} should be float')
        elif expected_type == 'str' and not isinstance(value, str):
            errors.append(f'{{scope}} field {{name}} should be str')
    return errors


class {pou_name}:
    def __init__(self) -> None:
{render_init_block()}

    def _clear_outputs(self) -> None:
        self.Ready = False
        self.Busy = False
        self.Done = False
        self.Error = False
        self.ErrorId = 0
        self.State = "DISABLED"
        self.StateAtError = None
        self.SafeStop = False
        self.PowerCutOff = False
        self.ErrorOperatorComm = False
        self.ErrorDriveComm = False
        self.ErrorPhaseRotation = False
        self.ErrorBrakeThermal = False
        self.ErrorMecaB = False
        self.ErrorMecaA = False
        self.ErrorLimitSwitch = False
        self.ErrorSensorIncoherent = False

    def step(self, time_ms: float = 10.0) -> None:
        time_ms = max(float(time_ms), 0.0)
        reset_edge = bool(self.Reset) and not self._prev_reset
        self._prev_reset = bool(self.Reset)

        if not self.Enable:
            self._clear_outputs()
            return

        if not self._first_scan_done:
            self._first_scan_done = True

        error_id = 0
        if not self.BypassGlobal:
            if not (self.BypassProcess or self.BypassOperatorComm) and not (self.JoystickOnline and self.JoystickOperational and self.HeartbeatIhmOk):
                error_id |= 0x0001
            if not (self.BypassProcess or self.BypassDriveComm) and not (self.DriveOnline and self.DriveOperational):
                error_id |= 0x0002
            if not (self.BypassProcess or self.BypassPhaseRotation) and not self.PhaseRotationOk:
                error_id |= 0x0004
            if not (self.BypassSafety or self.BypassBrakeThermal) and self.BrakeThermalFeedback:
                error_id |= 0x0008

            if not (self.BypassSafety or self.BypassMecaB):
                if not self.HeartbeatIhmOk:
                    self._meca_b_active = (abs(float(self.DriveActualFreqHz)) > 0.5) or bool(self.DriveStatusWord & 0x0001) or not self.BrakeFeedback
                elif self.Direction == 0 and not self.BrakeCmd:
                    self._meca_b_active = bool(self.DriveStatusWord & 0x0001) or not self.BrakeFeedback
                else:
                    self._meca_b_active = False

                if self._meca_b_active:
                    self._meca_b_timer_ms += time_ms
                    if self._meca_b_timer_ms >= self._post_ramp_timeout_ms:
                        error_id |= 0x0010
                else:
                    self._meca_b_timer_ms = 0.0
            else:
                self._meca_b_active = False
                self._meca_b_timer_ms = 0.0

            if not (self.BypassSafety or self.BypassMecaA):
                if self.Direction == 0 and not self.BrakeCmd:
                    self._meca_a_active = abs(float(self.DriveActualFreqHz)) > 0.5
                else:
                    self._meca_a_active = False

                if self._meca_a_active:
                    self._meca_a_timer_ms += time_ms
                    if self._meca_a_timer_ms >= self._meca_a_timeout_ms:
                        error_id |= 0x0020
                else:
                    self._meca_a_timer_ms = 0.0
            else:
                self._meca_a_active = False
                self._meca_a_timer_ms = 0.0

            if self.BypassSafety or self.BypassLimitSwitch:
                error_id &= ~0x0040
            elif self.LimitSwitchFwd or self.LimitSwitchRev:
                error_id |= 0x0040

            if self.BypassSafety or self.BypassSensorIncoherent:
                error_id &= ~0x0080
            elif self.SensorWordIncoherent:
                error_id |= 0x0080

        if reset_edge:
            error_id = 0

        self.ErrorId = error_id
        self.Error = error_id != 0
        self.SafeStop = self.Error or not self.EmergencyStopOk
        self.PowerCutOff = (self.ErrorId & 0x00F8) != 0
        self.ErrorOperatorComm = bool(self.ErrorId & 0x0001)
        self.ErrorDriveComm = bool(self.ErrorId & 0x0002)
        self.ErrorPhaseRotation = bool(self.ErrorId & 0x0004)
        self.ErrorBrakeThermal = bool(self.ErrorId & 0x0008)
        self.ErrorMecaB = bool(self.ErrorId & 0x0010)
        self.ErrorMecaA = bool(self.ErrorId & 0x0020)
        self.ErrorLimitSwitch = bool(self.ErrorId & 0x0040)
        self.ErrorSensorIncoherent = bool(self.ErrorId & 0x0080)
        self.Ready = True
        self.Busy = False
        self.Done = False
        self.State = "READY"
        if self.Error:
            self.StateAtError = self.State

    def set_inputs_from_mapping(self, values: dict) -> None:
        for name, value in values.items():
            if hasattr(self, name):
                setattr(self, name, value)

    def set_outputs_from_mapping(self, values: dict) -> None:
        for name, value in values.items():
            if hasattr(self, name):
                setattr(self, name, value)

    def to_dict(self):
        return {{
{output_dict_body}
        }}
'''


def render_safety_emergency_management_module_code(pou_name, interface):
    inputs = interface.get('inputs', [])
    outputs = interface.get('outputs', [])
    contract = build_contract_from_interface(
        interface,
        state_fields=(
            FieldSpec('_step', 'int', "Étape machine d'état 0..6", 0),
            FieldSpec('_step_timer_ms', 'float', 'Chronomètre étape', 0.0),
            FieldSpec('_lockout_active', 'bool', 'Verrouillage 5s actif', False),
            FieldSpec('_lockout_timer_ms', 'float', 'Chronomètre lockout', 0.0),
            FieldSpec('_redundancy_failed', 'bool', 'Échec auto-test redondance', False),
            FieldSpec('_arming_failed', 'bool', 'Échec confirmation réarmement', False),
            FieldSpec('_startup_fail', 'bool', 'Échec autotest démarrage', False),
            FieldSpec('_prev_reset', 'bool', 'Front Reset', False),
            FieldSpec('_prev_arm_req', 'bool', 'Front ArmRequest', False),
            FieldSpec('_prev_enable', 'bool', 'Front Enable', False),
            FieldSpec('_first_scan_done', 'bool', 'Premier scan exécuté', False),
        ),
    )
    contract_literal = repr(contract.to_dict())

    output_names = [var['name'] for var in outputs]
    output_dict_body = []
    for name in output_names:
        output_dict_body.append(f"            '{name}': self.{name},")
    output_dict_body = '\n'.join(output_dict_body) if output_dict_body else "            'status': 'prototype'"

    return f'''# {pou_name}.py
"""
Modèle de simulation Python pour {pou_name}.
Ce modèle reproduit la machine d'état (steps 0..6, autotest boot, redondance A/B,
timers 200ms/1s/2s/5s) et les bus d'échange State/Diag du POU.
"""

CONTRACT = {contract_literal}


def validate_runtime_contract(payload: dict, scope: str = 'inputs') -> list:
    if not isinstance(payload, dict):
        return ['payload must be a mapping']
    fields = CONTRACT.get(scope, [])
    errors = []
    for field in fields:
        name = field['name']
        if name not in payload:
            errors.append(f'missing {{scope}} field {{name}}')
            continue
        value = payload[name]
        expected_type = field['type']
        if expected_type == 'bool' and not isinstance(value, bool):
            errors.append(f'{{scope}} field {{name}} should be bool')
        elif expected_type == 'int' and not isinstance(value, int):
            errors.append(f'{{scope}} field {{name}} should be int')
        elif expected_type == 'float' and not isinstance(value, float):
            errors.append(f'{{scope}} field {{name}} should be float')
        elif expected_type == 'str' and not isinstance(value, str):
            errors.append(f'{{scope}} field {{name}} should be str')
    return errors


class {pou_name}:
    def __init__(self) -> None:
        # Inputs
        self.Enable: bool = False
        self.Reset: bool = False
        self.ArmRequest: bool = False
        self.EmergencyChainClosed: bool = False
        self.PowerContactorEngaged: bool = False
        self.PowerCutOffRequest: bool = False
        self.BtnEmergencyCutOff: bool = False

        # Outputs
        self.Ready: bool = False
        self.Busy: bool = False
        self.Done: bool = False
        self.Error: bool = False
        self.ErrorId: int = 0
        self.MaintainA_RQ: bool = False
        self.MaintainB_RQ: bool = False
        self.ArmPulse_RQ: bool = False
        self.State: object = None
        self.Diag: object = None
        self.ArmingSeqStep: int = 0
        self.RedundancyTestFailed: bool = False
        self.EmergencyArmingFailed: bool = False
        self.EmergencyArmingLockoutActive: bool = False

        # Internal FSM state
        self._step: int = 0
        self._step_timer_ms: float = 0.0
        self._lockout_active: bool = False
        self._lockout_timer_ms: float = 0.0
        self._redundancy_failed: bool = False
        self._arming_failed: bool = False
        self._startup_fail: bool = False
        self._force_test_a: bool = False
        self._force_test_b: bool = False
        self._prev_reset: bool = False
        self._prev_arm_req: bool = False
        self._prev_enable: bool = False
        self._first_scan_done: bool = False

        self._update_structs()

    def _clear_outputs(self) -> None:
        self.Ready = False
        self.Busy = False
        self.Done = False
        self.Error = False
        self.ErrorId = 0
        self.MaintainA_RQ = False
        self.MaintainB_RQ = False
        self.ArmPulse_RQ = False
        self._step = 0
        self._force_test_a = False
        self._force_test_b = False
        self._redundancy_failed = False
        self._arming_failed = False
        self._lockout_active = False
        self._startup_fail = False
        self._first_scan_done = False
        self._update_structs()

    def _update_structs(self) -> None:
        armable = (self.Enable and self.EmergencyChainClosed and
                   self._step == 0 and not self._lockout_active and
                   not self._redundancy_failed and not self.PowerContactorEngaged and
                   not self._startup_fail)
        busy = (self._step != 0) or self._lockout_active

        self.State = {{
            'ChainOk': bool(self.EmergencyChainClosed),
            'ContactorOk': bool(self.PowerContactorEngaged),
            'Step': int(self._step),
            'Armable': bool(armable),
            'ArmingBusy': bool(busy),
        }}
        self.Diag = {{
            'Error': bool(self.Error),
            'ErrorId': int(self.ErrorId),
            'RedundancyTestFailed': bool(self._redundancy_failed),
            'ArmFailed': bool(self._arming_failed),
            'LockoutActive': bool(self._lockout_active),
        }}

    def step(self, time_ms: float = 10.0) -> None:
        time_ms = max(float(time_ms), 0.0)

        reset_edge = bool(self.Reset) and not self._prev_reset
        self._prev_reset = bool(self.Reset)

        arm_edge = bool(self.ArmRequest) and not self._prev_arm_req
        self._prev_arm_req = bool(self.ArmRequest)

        enable_edge = bool(self.Enable) and not self._prev_enable
        self._prev_enable = bool(self.Enable)

        if not self.Enable:
            self._clear_outputs()
            return

        if enable_edge:
            self._first_scan_done = False

        if not self._first_scan_done:
            self._first_scan_done = True
            startup_ok = self.EmergencyChainClosed and (not self.PowerContactorEngaged) and (self._step == 0)
            if not startup_ok:
                self._startup_fail = True
                self.ErrorId = 0x0008
                self.Error = True
                self.Ready = False
                self._update_structs()
                return

        if reset_edge:
            self._redundancy_failed = False
            self._startup_fail = False
            if self.PowerContactorEngaged:
                self._arming_failed = False
            self.ErrorId &= ~0x0008

        if self._lockout_active:
            self._lockout_timer_ms += time_ms
            if self._lockout_timer_ms >= 5000.0:
                self._lockout_active = False
                self._lockout_timer_ms = 0.0

        armable = (self.EmergencyChainClosed and
                   self._step == 0 and
                   not self._lockout_active and
                   not self._redundancy_failed and
                   not self.PowerContactorEngaged and
                   not self._startup_fail)

        if arm_edge and armable:
            self._step = 1
            self._step_timer_ms = 0.0

        self._force_test_a = (self._step == 1)
        self._force_test_b = (self._step == 3)
        self.ArmPulse_RQ = (self._step == 5)

        if self._step == 1:
            if self._step_timer_ms >= 200.0:
                self._force_test_a = False
                if self.EmergencyChainClosed:
                    self._redundancy_failed = True
                    self._step = 0
                else:
                    self._step = 2
                    self._step_timer_ms = 0.0
            else:
                self._step_timer_ms += time_ms

        elif self._step == 2:
            if self._step_timer_ms >= 200.0:
                if self.EmergencyChainClosed:
                    self._step = 3
                    self._step_timer_ms = 0.0
                else:
                    self._step = 0
            else:
                self._step_timer_ms += time_ms

        elif self._step == 3:
            if self._step_timer_ms >= 200.0:
                self._force_test_b = False
                if self.EmergencyChainClosed:
                    self._redundancy_failed = True
                    self._step = 0
                else:
                    self._step = 4
                    self._step_timer_ms = 0.0
            else:
                self._step_timer_ms += time_ms

        elif self._step == 4:
            if self._step_timer_ms >= 200.0:
                if self.EmergencyChainClosed:
                    self._step = 5
                    self._step_timer_ms = 0.0
                else:
                    self._step = 0
            else:
                self._step_timer_ms += time_ms

        elif self._step == 5:
            if self._step_timer_ms >= 1000.0:
                self._step = 6
                self._step_timer_ms = 0.0
            else:
                self._step_timer_ms += time_ms

        elif self._step == 6:
            if self.PowerContactorEngaged:
                self._step = 0
                self._lockout_active = False
            elif self._step_timer_ms >= 2000.0:
                self._arming_failed = True
                self._step = 0
                self._lockout_active = True
                self._lockout_timer_ms = 0.0
            else:
                self._step_timer_ms += time_ms

        maintain_a = (not self.PowerCutOffRequest and
                      not self._force_test_a and
                      not self.BtnEmergencyCutOff and
                      not self._redundancy_failed)
        maintain_b = (not self.PowerCutOffRequest and
                      not self._force_test_b and
                      not self.BtnEmergencyCutOff and
                      not self._redundancy_failed)

        self.MaintainA_RQ = maintain_a
        self.MaintainB_RQ = maintain_b
        self.ArmPulse_RQ = (self._step == 5)

        error_id = 0
        if self._redundancy_failed:
            error_id |= 0x0001
        if self._arming_failed:
            error_id |= 0x0002
        if self._startup_fail:
            error_id |= 0x0008

        self.ErrorId = error_id
        self.Error = (error_id != 0)

        self.ArmingSeqStep = self._step
        self.RedundancyTestFailed = self._redundancy_failed
        self.EmergencyArmingFailed = self._arming_failed
        self.EmergencyArmingLockoutActive = self._lockout_active

        self.Ready = self.Enable and not self._startup_fail
        self.Busy = (self._step != 0) or self._lockout_active
        self.Done = self.PowerContactorEngaged

        self._update_structs()

    def set_inputs_from_mapping(self, values: dict) -> None:
        for name, value in values.items():
            if hasattr(self, name):
                setattr(self, name, value)

    def set_outputs_from_mapping(self, values: dict) -> None:
        for name, value in values.items():
            if hasattr(self, name):
                setattr(self, name, value)

    def to_dict(self):
        return {{
{output_dict_body}
        }}
'''


def render_module_code(pou_name, interface):
    if pou_name == 'FB_Translation_PositionDecoder':
        return render_translation_position_decoder_module_code(pou_name)
    if pou_name == 'FB_Translation':
        return render_translation_module_code(pou_name, interface)
    if pou_name == 'FB_Safety_Translation':
        return render_safety_translation_module_code(pou_name, interface)
    if pou_name == 'FB_Safety_EmergencyManagement':
        return render_safety_emergency_management_module_code(pou_name, interface)

    inputs = interface.get('inputs', [])
    outputs = interface.get('outputs', [])
    contract = build_translation_contract(interface)
    contract_literal = repr(contract.to_dict())
    input_lines = []
    for var in inputs:
        input_lines.append(f'        self.{var["name"]}: {var["python_type"]} = {_default_value_for_type(var["python_type"])}')
    output_lines = []
    for var in outputs:
        output_lines.append(f'        self.{var["name"]}: {var["python_type"]} = {_default_value_for_type(var["python_type"])}')

    init_block = '\n'.join(input_lines + output_lines) if (input_lines or output_lines) else '        pass'

    input_names = [var['name'] for var in inputs]
    output_names = [var['name'] for var in outputs]

    output_dict_body = []
    for name in output_names:
        output_dict_body.append(f"            '{name}': self.{name},")
    output_dict_body = '\n'.join(output_dict_body) if output_dict_body else "            'status': 'prototype'"

    return f'''# {pou_name}.py
"""
Prototype de module Python généré à partir de l'interface du POU {pou_name}.
Ce module n'est pas une traduction ST complète ; il expose un squelette exécutable
avec les entrées/sorties extraites du bundle PLCopen.
"""

CONTRACT = {contract_literal}


def validate_runtime_contract(payload: dict, scope: str = 'inputs') -> list:
    if not isinstance(payload, dict):
        return ['payload must be a mapping']
    fields = CONTRACT.get(scope, [])
    errors = []
    for field in fields:
        name = field['name']
        if name not in payload:
            errors.append(f'missing {{scope}} field {{name}}')
            continue
        value = payload[name]
        expected_type = field['type']
        if expected_type == 'bool' and not isinstance(value, bool):
            errors.append(f'{{scope}} field {{name}} should be bool')
        elif expected_type == 'int' and not isinstance(value, int):
            errors.append(f'{{scope}} field {{name}} should be int')
        elif expected_type == 'float' and not isinstance(value, float):
            errors.append(f'{{scope}} field {{name}} should be float')
        elif expected_type == 'str' and not isinstance(value, str):
            errors.append(f'{{scope}} field {{name}} should be str')
    return errors


class {pou_name}:
    def __init__(self) -> None:
        # Inputs
{init_block}

        # Output defaults
        self._input_names = {input_names!r}
        self._output_names = {output_names!r}

    def step(self) -> None:
        """Placeholder de step() basé sur l'interface extraites du POU."""
        for name in self._output_names:
            value = getattr(self, name, None)
            if value is None:
                setattr(self, name, 0)

    def set_inputs_from_mapping(self, values: dict) -> None:
        for name, value in values.items():
            if hasattr(self, name):
                setattr(self, name, value)

    def set_outputs_from_mapping(self, values: dict) -> None:
        for name, value in values.items():
            if hasattr(self, name):
                setattr(self, name, value)

    def to_dict(self):
        return {{
{output_dict_body}
        }}
'''


def render_test_code(pou_name, interface):
    if pou_name == 'FB_Translation_PositionDecoder':
        return '''import sys
from pathlib import Path
import pytest

GENERATED_DIR = Path(__file__).resolve().parents[1]
if str(GENERATED_DIR) not in sys.path:
    sys.path.insert(0, str(GENERATED_DIR))

from FB_Translation_PositionDecoder import FB_Translation_PositionDecoder as FBClass

VALID_CASES = [
    (0b11111, False, True, False),
    (0b01111, False, False, False),
    (0b00111, False, False, False),
    (0b00011, False, False, False),
    (0b00001, False, False, False),
    (0b00000, False, False, True),
]

INVALID_CASES = [
    0b10101,
    0b11010,
    0b01010,
    0b10000,
    0b00010,
]

@pytest.mark.parametrize("mask,exp_incoh,exp_fwd,exp_rev", VALID_CASES)
def test_valid_patterns(mask, exp_incoh, exp_fwd, exp_rev):
    fb = FBClass()
    fb.set_inputs_from_mask(mask)
    fb.step()
    assert fb.Incoherent == exp_incoh
    assert fb.LimitSwitchFwd == exp_fwd
    assert fb.LimitSwitchRev == exp_rev
    assert fb.SensorsWord == mask

@pytest.mark.parametrize("mask", INVALID_CASES)
def test_invalid_patterns(mask):
    fb = FBClass()
    fb.set_inputs_from_mask(mask)
    fb.step()
    assert fb.Incoherent is True
    assert not fb.LimitSwitchFwd
    assert not fb.LimitSwitchRev
'''

    if pou_name == 'FB_Translation':
        return '''import sys
from pathlib import Path
import pytest

GENERATED_DIR = Path(__file__).resolve().parents[1]
if str(GENERATED_DIR) not in sys.path:
    sys.path.insert(0, str(GENERATED_DIR))

from FB_Translation import FB_Translation as FBClass


def test_translation_moves_to_done_when_target_is_reached():
    fb = FBClass()
    fb.Enable = True
    fb.EmergencyStopOk = True
    fb.StartStop = True
    fb.SpeedRefPct = 80.0
    fb.CaptorDebounce = 5.0
    fb.step(10.0)
    assert fb.State == "MOVING"
    fb.PositionSensorTarget = True
    fb.step(10.0)
    assert fb.State == "DONE"
    assert fb.Done is True
    assert fb.Busy is False


def test_translation_safe_stop_sets_fault():
    fb = FBClass()
    fb.Enable = True
    fb.EmergencyStopOk = True
    fb.SafeStop = True
    fb.step(10.0)
    assert fb.Error is True
    assert fb.ErrorId == 1
    assert fb.State == "FAULT"
'''

    if pou_name == 'FB_Safety_Translation':
        return '''import sys
from pathlib import Path
import pytest

GENERATED_DIR = Path(__file__).resolve().parents[1]
if str(GENERATED_DIR) not in sys.path:
    sys.path.insert(0, str(GENERATED_DIR))

from FB_Safety_Translation import FB_Safety_Translation as FBClass


def test_safety_translation_reports_operator_comm_loss():
    fb = FBClass()
    fb.Enable = True
    fb.EmergencyStopOk = True
    fb.JoystickOnline = False
    fb.JoystickOperational = False
    fb.HeartbeatIhmOk = False
    fb.step(10.0)
    assert fb.Error is True
    assert fb.ErrorOperatorComm is True
    assert fb.ErrorId & 0x0001 == 0x0001


def test_safety_translation_can_be_reset():
    fb = FBClass()
    fb.Enable = True
    fb.EmergencyStopOk = True
    fb.JoystickOnline = False
    fb.JoystickOperational = False
    fb.HeartbeatIhmOk = False
    fb.step(10.0)
    fb.Reset = True
    fb.step(10.0)
    assert fb.ErrorId == 0
    assert fb.Error is False
'''

    inputs = interface.get('inputs', [])
    outputs = interface.get('outputs', [])
    import_lines = [
        'import sys',
        'from pathlib import Path',
        'import pytest',
        '',
        'GENERATED_DIR = Path(__file__).resolve().parents[1]',
        'if str(GENERATED_DIR) not in sys.path:',
        '    sys.path.insert(0, str(GENERATED_DIR))',
        '',
        f'from {pou_name} import {pou_name} as FBClass',
        '',
    ]
    test_body = []
    if inputs:
        sample_inputs = []
        for var in inputs:
            sample_inputs.append(f'    "{var["name"]}": {_default_value_for_type(var["python_type"])}')
        sample_inputs_str = '{\n' + ',\n'.join(sample_inputs) + '\n}'
        test_body.append(f'def test_set_inputs_from_mapping_updates_inputs():\n    fb = FBClass()\n    values = {sample_inputs_str}\n    fb.set_inputs_from_mapping(values)\n    for name, expected in values.items():\n        assert getattr(fb, name) == expected\n')
    if outputs:
        test_body.append('def test_outputs_default_to_safe_values():\n    fb = FBClass()\n')
        for var in outputs:
            default = _default_value_for_type(var['python_type'])
            test_body.append(f'    assert getattr(fb, "{var["name"]}") == {default}\n')
    if not test_body:
        test_body.append('def test_placeholder():\n    assert True\n')

    return '\n'.join(import_lines + test_body) + '\n'


def generate_module_and_test(pou_name, out_dir, bundle_path=None):
    global CURRENT_BUNDLE_PATH
    if bundle_path is None:
        bundle_path = CURRENT_BUNDLE_PATH
    os.makedirs(out_dir, exist_ok=True)
    module_path = os.path.join(out_dir, f'{pou_name}.py')
    tests_dir = os.path.join(out_dir, 'tests')
    os.makedirs(tests_dir, exist_ok=True)
    test_path = os.path.join(tests_dir, f'test_{pou_name}.py')

    interface = {'inputs': [], 'outputs': []}
    if bundle_path:
        try:
            interface = extract_pou_interface(bundle_path, pou_name)
        except Exception as e:
            print('WARNING: could not parse interface from bundle:', e)

    module_source = render_module_code(pou_name, interface)
    validation = validate_generated_module(pou_name, interface, module_source)
    if not validation['valid']:
        report_path = write_validation_report(out_dir, pou_name, validation)
        raise RuntimeError(f'Validation failed for {pou_name}: {validation["errors"]}. Report: {report_path}')

    with open(module_path, 'w', encoding='utf-8') as f:
        f.write(module_source)
    with open(test_path, 'w', encoding='utf-8') as f:
        f.write(render_test_code(pou_name, interface))

    meta = {
        'pou': pou_name,
        'generated_at': datetime.now().astimezone().isoformat(),
        'inputs': [var['name'] for var in interface.get('inputs', [])],
        'outputs': [var['name'] for var in interface.get('outputs', [])],
    }
    meta_path = os.path.join(out_dir, f'{pou_name}.meta.json')
    with open(meta_path, 'w', encoding='utf-8') as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
    return module_path, test_path, meta_path


def process_single_pou(pou, bundle, out, force, cache, base_dir, allow_safety=False):
    global CURRENT_BUNDLE_PATH
    CURRENT_BUNDLE_PATH = bundle
    try:
        canonical = canonicalize_pou_bytes(bundle, pou)
    except Exception as e:
        print('ERROR: cannot extract POU:', pou, e)
        return False

    found = scan_for_safety_tokens(canonical)
    if found and not allow_safety:
        print(f'POU {pou} contains safety tokens {found}; blocking generation')
        report_path = write_safety_report(out, pou, found)
        print('Wrote safety report:', report_path)
        return False

    sha = compute_hash(canonical)
    prev = cache.get(pou, {}).get('hash')
    if prev == sha and not force:
        print(f'POU {pou} unchanged (hash {sha}); skipping generation')
        return False
    try:
        module_path, test_path, meta_path = generate_module_and_test(pou, out)
    except Exception as exc:
        print('Validation failed for', pou, ':', exc)
        return False

    cache[pou] = {
        'hash': sha,
        'generated_at': datetime.now().astimezone().isoformat(),
        'callers': cache.get(pou, {}).get('callers', []),
    }
    save_cache(base_dir, cache)
    print('Generated:', module_path, test_path)
    print('Cache updated with hash', sha)
    return True


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--bundle', required=True, help='Path to CODE_Bundle.xml')
    p.add_argument('--pou', required=False, help='POU/FB name (omit with --changed)')
    p.add_argument('--out', required=True, help='Output folder for generated modules')
    p.add_argument('--force', action='store_true', help='Force regeneration even if hash unchanged')
    p.add_argument('--changed', action='store_true', help='Generate only for POUs changed since --ref')
    p.add_argument('--ref', default='origin/main', help='Git reference used for --changed (default: origin/main)')
    p.add_argument('--allow-safety', action='store_true', help='Allow generation even if safety tokens are present (writes report)')
    args = p.parse_args()

    bundle = args.bundle
    out = args.out
    base_dir = os.path.dirname(__file__)
    cache = load_cache(base_dir)

    if args.changed:
        files = git_changed_files(args.ref)
        print('Changed files since', args.ref, ':', len(files))
        bundle_rel = os.path.relpath(os.path.abspath(bundle)).replace('\\', '/')
        generate_all = False
        if any(f.replace('\\', '/') == bundle_rel or os.path.basename(f) == os.path.basename(bundle_rel) for f in files):
            generate_all = True
        pou_list = []
        if generate_all:
            print('Bundle changed: will generate all POUs from bundle')
            pou_list = list_pous_from_bundle(bundle)
        else:
            for f in files:
                if f.endswith('.st') and f.startswith('CODE'):
                    pou = extract_pou_from_st(f)
                    if pou:
                        pou_list.append(pou)
                    else:
                        print('Warning: could not extract POU name from', f)
        if not pou_list:
            print('No POUs to generate. Exiting.')
            sys.exit(0)
        changed_any = False
        for pou in sorted(set(pou_list)):
            ok = process_single_pou(pou, bundle, out, args.force, cache, base_dir, allow_safety=args.allow_safety)
            changed_any = changed_any or ok
        if not changed_any:
            print('No new generation done.')
        sys.exit(0)

    if not args.pou:
        print('Error: --pou required unless --changed is used')
        sys.exit(2)
    process_single_pou(args.pou, bundle, out, args.force, cache, base_dir, allow_safety=args.allow_safety)


if __name__ == '__main__':
    main()
