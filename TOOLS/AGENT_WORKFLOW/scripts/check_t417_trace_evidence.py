"""T417: extract measured event brackets; never infer distance, mode or PV setting.

Uses the project's CODESYS reader. Fails on missing/asynchronous/duplicate samples
instead of silently pairing different instants. Evidence is append-only under DOC/WFLOW.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import statistics
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'TOOLS/PLC_CSV_SNAPSHOT/external_python'))
from trace_to_csv import read_trace

SIGNALS = {
    'step': 'PRG_03_Modes_Cycle.Data.SequenceState.Step',
    'req': 'PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.ReqStart',
    'target': 'PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.PositionTgt',
    'tremie': 'PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI',
    'p1': 'PRG_02_Acquisition.HwIn.Translation.M3_PosP1_DI',
    'contact': 'PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI',
    'frequency_raw': 'PRG_02_Acquisition.Data.M3.ActualFrequencyHz',
    'error': 'PRG_05_Translation.Data.TranslationState.Error',
    'brake_internal': 'PRG_05_Translation.Data.TranslationState.BrakeCmd',
    'brake_request': 'PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest',
    'word': 'PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord',
    'frequency_command': 'PRG_06_Outputs.instTranslationOutputInterlockM3.DriveFreqCmd_Hz',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bracket(times, index):
    return [times[index - 1], times[index]] if index else None


def duration_bounds(start, end):
    # Events occur in (previous_sample, current_sample], not exactly at the sample.
    return [end[0] - start[1], end[1] - start[0]]


def analyze(path):
    variables, metadata = read_trace(path)
    by_name = {v.name: v for v in variables}
    if len(by_name) != len(variables):
        raise ValueError('Duplicate channel name')
    times = [int(x) for x in variables[0].timestamps_ms]
    if len(times) < 2 or any(b <= a for a, b in zip(times, times[1:])):
        raise ValueError('Timestamps must be strictly increasing')
    if any([int(x) for x in v.timestamps_ms] != times for v in variables):
        raise ValueError('Asynchronous channels: no implicit interpolation allowed')
    data = {k: [float(x) for x in by_name[name].values] for k, name in SIGNALS.items()}
    gaps = [b - a for a, b in zip(times, times[1:])]
    events = []
    for key, values in data.items():
        if key in ('frequency_raw', 'frequency_command'):
            continue
        for i in range(1, len(times)):
            if values[i] != values[i - 1]:
                events.append({'signal': key, 'interval_ms': bracket(times, i),
                               'from': values[i - 1], 'to': values[i]})
    stops = []
    for i in range(1, len(times)):
        if data['word'][i - 1] == 0 or data['word'][i] != 0:
            continue
        # Never associate a later movement's contact/frequency with this stop.
        end = next((j for j in range(i + 1, len(times)) if data['word'][j] != 0), len(times))
        stop = {'command_zero_ms': times[i], 'command_interval_ms': bracket(times, i),
                'step': data['step'][i], 'last_direction_word': data['word'][i - 1],
                'frequency_before_Hz': data['frequency_raw'][i - 1] / 100,
                'frequency_at_Hz': data['frequency_raw'][i] / 100,
                'error_seen': any(data['error'][j] != 0 for j in range(i, end)),
                'distance_M': None, 'mode': 'not recorded', 'PV_setting_Hz': None}
        for label, key in [('frequency_zero', 'frequency_raw'), ('contact_closed', 'contact'),
                           ('brake_request_off', 'brake_request'), ('brake_internal_off', 'brake_internal')]:
            j = next((j for j in range(i, end) if data[key][j] == 0), None)
            # Value already zero before withdrawal: event cannot be dated here.
            if j is not None and data[key][j - 1] != 0:
                interval = bracket(times, j)
                stop[label] = {'sample_ms': times[j], 'interval_ms': interval,
                               'delay_sample_ms': times[j] - times[i],
                               'delay_bounds_ms': duration_bounds(bracket(times, i), interval)}
            else:
                stop[label] = {'state': 'already zero' if j == i else 'not observed before restart/end'}
        stops.append(stop)
    return {'source': path.relative_to(ROOT).as_posix(), 'sha256': digest(path),
            'channels': metadata['variables'], 'samples': len(times),
            'start_ms': times[0], 'end_ms': times[-1],
            'sampling_ms': {'min': min(gaps), 'median': statistics.median(gaps), 'max': max(gaps)},
            'frequency_scale': 'raw / 100 Hz (PRG_05_Translation; FB_SimBench)',
            'steps_seen': sorted(set(data['step'])), 'error_values': sorted(set(data['error'])),
            'events': sorted(events, key=lambda e: (e['interval_ms'][1], e['signal'])), 'stops': stops,
            'limits': ['No mode or PV configuration channel', 'No measured mechanical position/distance',
                       'Brake request is upstream of final interlock; final brake command absent',
                       'No loaded source/version identity; source analysis is a separate evidence']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to((ROOT / 'DOC/WFLOW').resolve()) or not output.parent.is_dir():
        parser.error('Existing evidence directory under DOC/WFLOW required')
    if output.exists():
        parser.error('Evidence already exists; choose a new name')
    sources = ['TOOLS/PLC_CSV_SNAPSHOT/external_python/trace_to_csv.py',
               'TOOLS/AGENT_WORKFLOW/scripts/check_t417_trace_evidence.py',
               'CODE/M_MAIN/PRG_05_Translation.st', 'CODE/L_SIMULATION/FB_SimBench.st',
               'CODE/G_CYCLE/_TYPES/E_AutoCycleStep.st']
    traces = [analyze(ROOT / 'TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace' / name) for name in
              ['Suivi_94_SIMU_M3_manu_auto_20261029.trace', 'Suivi_95_SIMU_M3_manu_auto_10hz_20261029.trace']]
    result = {'sources_sha256': {p: digest(ROOT / p) for p in sources}, 'traces': traces}
    with output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    for trace in traces:
        print(trace['source'], trace['sampling_ms'], 'steps=', trace['steps_seen'])
        for stop in trace['stops']:
            print(json.dumps(stop, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
