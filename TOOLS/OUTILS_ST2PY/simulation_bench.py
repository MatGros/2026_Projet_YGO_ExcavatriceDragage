import argparse
import csv
import importlib.util
import json
import pathlib
import sys

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
OUT_DIR = TOOLS_DIR / 'out' / 'modules'


def load_generated_module(pou_name, module_path=None):
    if module_path is None:
        module_path = OUT_DIR / f'{pou_name}.py'
    module_path = pathlib.Path(module_path)
    if not module_path.exists():
        raise FileNotFoundError(f'Module not found: {module_path}')

    spec = importlib.util.spec_from_file_location(pou_name, module_path)
    if spec is None or spec.loader is None:
        raise ImportError(f'Cannot load module from {module_path}')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _build_safety_translation_fb(module):
    fb = module.FB_Safety_Translation()
    fb.Enable = True
    fb.EmergencyStopOk = True
    fb.BypassGlobal = False
    fb.BypassProcess = False
    fb.BypassOperatorComm = False
    fb.BypassDriveComm = False
    fb.BypassPhaseRotation = False
    fb.BypassSafety = False
    fb.BypassBrakeThermal = False
    fb.BypassMecaB = False
    fb.BypassMecaA = False
    fb.BypassLimitSwitch = False
    fb.BypassSensorIncoherent = False
    fb.JoystickOnline = True
    fb.JoystickOperational = True
    fb.HeartbeatIhmOk = True
    fb.DriveOnline = True
    fb.DriveOperational = True
    fb.PhaseRotationOk = True
    fb.BrakeThermalFeedback = False
    fb.BrakeFeedback = True
    fb.BrakeCmd = False
    fb.Direction = 1
    fb.DriveActualFreqHz = 0.0
    fb.DriveStatusWord = 0
    fb.LimitSwitchFwd = False
    fb.LimitSwitchRev = False
    fb.SensorWordIncoherent = False
    fb.Reset = False
    return fb


def _build_translation_fb(module):
    fb = module.FB_Translation()
    fb.Enable = True
    fb.EmergencyStopOk = True
    fb.StartStop = True
    fb.SafeStop = False
    fb.SpeedRefPct = 80.0
    fb.CaptorDebounce = 5.0
    fb.PositionSensorTarget = False
    fb.Reset = False
    fb.Ready = False
    fb.Busy = False
    fb.Done = False
    fb.Error = False
    fb.ErrorId = 0
    fb.State = 'IDLE'
    return fb


def _snapshot(fb):
    fields = [
        'Enable',
        'EmergencyStopOk',
        'Reset',
        'JoystickOnline',
        'JoystickOperational',
        'HeartbeatIhmOk',
        'DriveOnline',
        'DriveOperational',
        'PhaseRotationOk',
        'BrakeThermalFeedback',
        'BrakeFeedback',
        'BrakeCmd',
        'Direction',
        'DriveActualFreqHz',
        'DriveStatusWord',
        'LimitSwitchFwd',
        'LimitSwitchRev',
        'SensorWordIncoherent',
        'Error',
        'ErrorId',
        'ErrorOperatorComm',
        'ErrorDriveComm',
        'ErrorPhaseRotation',
        'ErrorBrakeThermal',
        'ErrorMecaB',
        'ErrorMecaA',
        'ErrorLimitSwitch',
        'ErrorSensorIncoherent',
        'SafeStop',
        'PowerCutOff',
        'Ready',
        'Busy',
        'Done',
        'State',
        'StateAtError',
    ]
    return {name: getattr(fb, name) for name in fields if hasattr(fb, name)}


def _apply_scenario_phase(fb, phase):
    if phase == 'healthy':
        return
    if phase == 'operator_loss':
        fb.JoystickOnline = False
        fb.JoystickOperational = False
        fb.HeartbeatIhmOk = False
        return
    if phase == 'reset':
        fb.Reset = True
        return
    if phase == 'recover':
        fb.Reset = False
        fb.JoystickOnline = True
        fb.JoystickOperational = True
        fb.HeartbeatIhmOk = True
        fb.DriveOnline = True
        fb.DriveOperational = True
        fb.PhaseRotationOk = True
        fb.BrakeThermalFeedback = False
        fb.BrakeFeedback = True
        fb.DriveActualFreqHz = 0.0
        fb.DriveStatusWord = 0
        return


def run_safety_translation_bench(pou_name='FB_Safety_Translation', module_path=None, time_ms=10.0):
    module = load_generated_module(pou_name, module_path=module_path)
    fb = _build_safety_translation_fb(module)

    timeline = []
    for phase in ['healthy', 'operator_loss', 'reset', 'recover']:
        _apply_scenario_phase(fb, phase)
        fb.step(time_ms)
        timeline.append({'step': phase, 'snapshot': _snapshot(fb)})

    return {'pou': pou_name, 'time_ms': time_ms, 'timeline': timeline}


def run_translation_bench(pou_name='FB_Translation', module_path=None, time_ms=10.0):
    module = load_generated_module(pou_name, module_path=module_path)
    fb = _build_translation_fb(module)

    timeline = []
    phases = [
        ('start', lambda fb: None),
        ('target_reached', lambda fb: setattr(fb, 'PositionSensorTarget', True)),
        ('safe_stop', lambda fb: setattr(fb, 'SafeStop', True)),
        ('reset', lambda fb: setattr(fb, 'SafeStop', False)),
    ]

    for phase, action in phases:
        action(fb)
        fb.step(time_ms)
        timeline.append({'step': phase, 'snapshot': _snapshot(fb)})

    return {'pou': pou_name, 'time_ms': time_ms, 'timeline': timeline}


def export_bench(result, output_path):
    output_path = pathlib.Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.suffix.lower() == '.csv':
        with output_path.open('w', newline='', encoding='utf-8') as handle:
            writer = csv.writer(handle, delimiter=';')
            rows = []
            headers = ['step']
            first_snapshot = result['timeline'][0]['snapshot'] if result['timeline'] else {}
            headers.extend(sorted(first_snapshot.keys()))
            rows.append(headers)
            for item in result['timeline']:
                snapshot = item['snapshot']
                row = [item['step']]
                for key in sorted(snapshot.keys()):
                    row.append(snapshot[key])
                rows.append(row)
            writer.writerows(rows)
        return output_path

    output_path.write_text(json.dumps(result, indent=2), encoding='utf-8')
    return output_path


def main():
    parser = argparse.ArgumentParser(description='Run a simple multi-cycle simulation bench for generated FBs')
    parser.add_argument('--pou', default='FB_Safety_Translation', help='Generated POU name to simulate')
    parser.add_argument('--module', default=None, help='Optional path to the generated Python module')
    parser.add_argument('--time-ms', type=float, default=10.0, help='Time increment passed to step()')
    parser.add_argument('--output', default=None, help='Optional output file (json or csv)')
    args = parser.parse_args()

    if args.pou == 'FB_Translation':
        result = run_translation_bench(pou_name=args.pou, module_path=args.module, time_ms=args.time_ms)
    else:
        result = run_safety_translation_bench(pou_name=args.pou, module_path=args.module, time_ms=args.time_ms)

    if args.output:
        output_path = export_bench(result, args.output)
        print(f'Wrote bench output to {output_path}')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
