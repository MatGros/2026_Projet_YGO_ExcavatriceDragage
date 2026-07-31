from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Tuple


@dataclass(frozen=True)
class FieldSpec:
    name: str
    type: str
    meaning: str
    default: Any = None


@dataclass(frozen=True)
class DataContract:
    inputs: Tuple[FieldSpec, ...] = ()
    outputs: Tuple[FieldSpec, ...] = ()
    state: Tuple[FieldSpec, ...] = ()

    def to_dict(self) -> Dict[str, list[dict[str, Any]]]:
        return {
            'inputs': [self._field_to_dict(field) for field in self.inputs],
            'outputs': [self._field_to_dict(field) for field in self.outputs],
            'state': [self._field_to_dict(field) for field in self.state],
        }

    @staticmethod
    def _field_to_dict(field: FieldSpec) -> Dict[str, Any]:
        return {
            'name': field.name,
            'type': field.type,
            'meaning': field.meaning,
            'default': field.default,
        }


def _default_for_python_type(python_type: str) -> Any:
    if python_type == 'bool':
        return False
    if python_type == 'float':
        return 0.0
    if python_type == 'int':
        return 0
    if python_type == 'str':
        return ''
    return None


def build_contract_from_interface(interface: Dict[str, list[dict[str, Any]]], state_fields: Tuple[FieldSpec, ...] = ()) -> DataContract:
    inputs = tuple(
        FieldSpec(
            name=var['name'],
            type=var['python_type'],
            meaning=f"input {var['name']}",
            default=_default_for_python_type(var['python_type']),
        )
        for var in interface.get('inputs', [])
    )
    outputs = tuple(
        FieldSpec(
            name=var['name'],
            type=var['python_type'],
            meaning=f"output {var['name']}",
            default=_default_for_python_type(var['python_type']),
        )
        for var in interface.get('outputs', [])
    )
    return DataContract(inputs=inputs, outputs=outputs, state=state_fields)


def build_position_decoder_contract() -> DataContract:
    return DataContract(
        inputs=(
            FieldSpec('SensorTremie', 'bool', 'capteur tremie / position haute', False),
            FieldSpec('SensorPV', 'bool', 'capteur position PV', False),
            FieldSpec('SensorP2', 'bool', 'capteur position P2', False),
            FieldSpec('SensorP1', 'bool', 'capteur position P1', False),
            FieldSpec('SensorMaintenance', 'bool', 'capteur maintenance', False),
        ),
        outputs=(
            FieldSpec('SensorsWord', 'int', 'mot binaire des capteurs', 0),
            FieldSpec('Incoherent', 'bool', 'décodage incohérent', False),
            FieldSpec('LimitSwitchFwd', 'bool', 'butée avant', False),
            FieldSpec('LimitSwitchRev', 'bool', 'butée arrière', False),
        ),
        state=(),
    )


def build_translation_contract(interface: Dict[str, list[dict[str, Any]]]) -> DataContract:
    base_contract = build_contract_from_interface(interface)
    state_fields = (
        FieldSpec('_state', 'str', 'machine d\'état interne', 'IDLE'),
        FieldSpec('_state_timer_ms', 'float', 'compteur de temporisation interne', 0.0),
        FieldSpec('_prev_reset', 'bool', 'état précédent du reset', False),
        FieldSpec('_prev_enable', 'bool', 'état précédent de l\'enable', False),
        FieldSpec('_prev_safe_stop', 'bool', 'état précédent du safe stop', False),
        FieldSpec('_prev_start_stop', 'bool', 'état précédent du start stop', False),
        FieldSpec('_first_scan_done', 'bool', 'premier scan traité', False),
        FieldSpec('_meca_b_timer_ms', 'float', 'temporisation sécurité Meca B', 0.0),
        FieldSpec('_meca_a_timer_ms', 'float', 'temporisation sécurité Meca A', 0.0),
        FieldSpec('_meca_b_active', 'bool', 'Meca B actif', False),
        FieldSpec('_meca_a_active', 'bool', 'Meca A actif', False),
        FieldSpec('_post_ramp_timeout_ms', 'float', 'timeout après rampe', 3000.0),
        FieldSpec('_meca_a_timeout_ms', 'float', 'timeout Meca A', 1000.0),
    )
    return DataContract(inputs=base_contract.inputs, outputs=base_contract.outputs, state=state_fields)


def validate_contract(contract: DataContract, payloads: Dict[str, Dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    for scope in ('inputs', 'outputs', 'state'):
        fields = getattr(contract, scope)
        payload = payloads.get(scope, {})
        for field in fields:
            if field.name not in payload:
                errors.append(f'missing {scope} field {field.name}')
                continue
            value = payload[field.name]
            if not _matches_type(value, field.type):
                errors.append(f'{scope} field {field.name} should be {field.type}')
    return errors


def _matches_type(value: Any, expected_type: str) -> bool:
    if expected_type in {'bool', 'int', 'float', 'str'}:
        return isinstance(value, {'bool': bool, 'int': int, 'float': float, 'str': str}[expected_type])
    return True
