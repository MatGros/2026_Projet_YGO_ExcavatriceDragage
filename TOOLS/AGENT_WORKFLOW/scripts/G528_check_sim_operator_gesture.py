"""T418: ownership of raw joystick stimuli and sequenced operator gesture.

Static wiring guard; executable ST integration remains the behavioral proof.
No exports or files are modified by this gate, including its selftest.
"""
from pathlib import Path
import argparse
import re

ROOT = Path(__file__).resolve().parents[3]


def clean(source):
    source = re.sub(r"\(\*.*?\*\)", "", source, flags=re.S)
    return re.sub(r"//[^\n]*", "", source)


def check(bench, joystick):
    bench, joystick = clean(bench), clean(joystick)
    errors = []
    expected = {
        'JoyXRaw_ANA1': ['instSimJoystick.RawX', 'SimJoystickRawX'],
        'JoyYRaw_ANA2': ['instSimJoystick.RawY', 'SimJoystickRawY'],
        'JoyBtnRaw': ['instSimJoystick.RawButton', 'SimJoystickRawButton'],
    }
    for field, values in expected.items():
        actual = re.findall(rf'Operator\.{field}\s*:=\s*(.*?);', bench, re.S | re.I)
        if actual != values:
            errors.append(f'{field}: expected model/manual exclusive producers, got {actual}')
    pattern = (r'IF\s+instSimJoystick\.ModelActive\s+THEN\s+'
               r'Operator\.JoyXRaw_ANA1\s*:=\s*instSimJoystick\.RawX;\s+'
               r'Operator\.JoyYRaw_ANA2\s*:=\s*instSimJoystick\.RawY;\s+'
               r'Operator\.JoyBtnRaw\s*:=\s*instSimJoystick\.RawButton;\s+ELSE')
    if not re.search(pattern, bench, re.I):
        errors.append('model must own all three raw signals in the same branch')
    disabled = re.search(r'IF NOT Enable THEN(.*?)RETURN;', bench, re.S | re.I)
    if not disabled or 'instSimJoystick(Enable := FALSE);' not in disabled[1]:
        errors.append('joystick must reset before disabled bench RETURN')
    for source in (bench, joystick):
        if re.search(r'\bDeadmanArmed\s*:=', source, re.I):
            errors.append('real armed state must not be produced by simulation')
    if re.search(r'RawButton\s*:=.*(?:BtnLeft|BtnRight|BtnFwd|BtnRev)', joystick, re.I):
        errors.append('raw arm button must not be combinatorial with directions')
    if 'RawButton := NOT instButtonReleaseTimer.Q;' not in joystick:
        errors.append('arm button release phase missing')
    if 'IF NOT GesturePermit THEN GestureStep := CST_GESTURE_WAIT_RELEASE;' not in joystick:
        errors.append('manual conflict must cancel gesture')
    if re.search(r'CASE\s+GestureStep\s+OF', joystick, re.I):
        errors.append('named local CASE constants unsupported by current ST CI compiler; use comparisons')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--selftest', action='store_true')
    args = parser.parse_args()
    bench = (ROOT / 'CODE/L_SIMULATION/FB_SimBench.st').read_text(encoding='utf-8-sig')
    joy = (ROOT / 'CODE/L_SIMULATION/FB_Sim_Joystick.st').read_text(encoding='utf-8-sig')
    errors = check(bench, joy)
    acquisition = (ROOT / 'CODE/M_MAIN/PRG_02_Acquisition.st').read_text(encoding='utf-8-sig')
    errors.extend(check_source_selection(bench, acquisition))
    tests = (ROOT / 'TOOLS/TEST_AUTO_CI/RESULTS/L_SIMULATION/tests/test_sim_operator_joystick.st').read_text(encoding='utf-8-sig')
    errors.extend(check_test_initialization(tests))
    manual_tests = (ROOT / 'TOOLS/TEST_AUTO_CI/RESULTS/L_SIMULATION/tests/test_sim_manual_reference.st').read_text(encoding='utf-8-sig')
    errors.extend(check_manual_harness(manual_tests))
    if args.selftest and not errors:
        mutations = [
            (bench.replace('Operator.JoyBtnRaw := instSimJoystick.RawButton;',
                           'Operator.JoyBtnRaw := SimJoystickRight_Fwd_MAINT_Active;'), joy),
            (bench.replace('IF instSimJoystick.ModelActive THEN', 'IF TRUE THEN'), joy),
            (bench.replace('instSimJoystick(Enable := FALSE);', ''), joy),
            (bench.replace('Operator.JoyXRaw_ANA1 := instSimJoystick.RawX;',
                           'Operator.JoyXRaw_ANA1 := SimJoystickRawX;'), joy),
            (bench, joy.replace('RawButton := NOT instButtonReleaseTimer.Q;', 'RawButton := TRUE;')),
            (bench, joy + '\nDeadmanArmed := TRUE;'),
            (bench, joy.replace('IF NOT GesturePermit THEN GestureStep := CST_GESTURE_WAIT_RELEASE;', '')),
            (bench, joy + '\nCASE GestureStep OF CST_GESTURE_ARM: RawButton := TRUE; END_CASE;'),
        ]
        for number, (mut_bench, mut_joy) in enumerate(mutations, 1):
            if not check(mut_bench, mut_joy):
                errors.append(f'selftest mutation {number} survived')
        if not check_test_initialization(tests.replace('nx := 5000;', '', 1)):
            errors.append('selftest uninitialized calibration survived')
        if not check_source_selection(bench, acquisition.replace(
                'OperatorSourceActive     := OperatorInputSourceSimulated,',
                'OperatorSourceActive     := TRUE,')):
            errors.append('selftest source selection disconnection survived')
        if not check_source_selection(bench.replace(
                'Operator := HwReal.Operator;\nELSE',
                'Operator := HwReal.Operator;\n(* no ELSE *)'), acquisition):
            errors.append('selftest manual fallback after real source survived')
        if not check_manual_harness(manual_tests.replace('SETUP\nVAR', 'VAR', 1)):
            errors.append('selftest local test VAR_IN_OUT harness survived')
        if not check_manual_harness(manual_tests.replace('calibM1 := encoderM1.Calib;', '', 1)):
            errors.append('selftest missing multi-FB calibration copy-out survived')
        if not errors:
            print(f'Selftest PASS: {len(mutations) + 5} mutations rejected, source unchanged')
    for error in errors:
        print(f'FAIL: {error}')
    print(f'G528 operator gesture: {"FAIL" if errors else "PASS"}')
    return bool(errors)


def check_test_initialization(source):
    """STruCpp SETUP primitive declaration initializers are not emitted in C++."""
    errors = []
    for number, body in enumerate(re.findall(r"\bTEST\s+'[^']+'(.*?)END_TEST", source, re.S), 1):
        for required in ('nx := 5000;', 'ny := 5000;', 'raw1 := 0;', 'raw2 := 0;',
                         'previousButton := FALSE;', 'buttonEdges := 0;'):
            if required not in body:
                errors.append(f'integration test {number}: explicit initialization missing: {required}')
    return errors


def check_source_selection(bench, acquisition):
    errors = []
    if not re.search(r'OperatorSourceActive\s*:=\s*OperatorInputSourceSimulated\s*,', clean(acquisition)):
        errors.append('effective operator source must drive SimBench')
    pattern = (r'IF NOT OperatorSourceActive THEN\s+'
               r'instSimJoystick\(Enable := FALSE\);\s+'
               r'Operator := HwReal.Operator;\s+ELSE')
    if not re.search(pattern, clean(bench)):
        errors.append('real operator source requires reset and direct real image, exclusive from manual stimuli')
    return errors


def check_manual_harness(source):
    """Multi-FB registry entry has no homonymous FB: explicit copy-out is required."""
    source = clean(source)
    if not re.search(r'\bSETUP\s+VAR\b.*?\bEND_SETUP\b', source, re.S):
        return ['manual reference integration requires SETUP for VAR_IN_OUT copy-out']
    if re.search(r"\bTEST\s+'[^']+'\s+VAR\b", source):
        return ['manual reference integration must not use local TEST VAR_IN_OUT variables']
    for instance, copyout in (
            ('encoderM1', 'calibM1 := encoderM1.Calib;'),
            ('encoderM2', 'calibM2 := encoderM2.Calib;'),
            ('bucket', 'bucketState := bucket.BucketState;'),
            ('bench', 'raw1 := bench.RawPosM1; raw2 := bench.RawPosM2;')):
        calls = len(re.findall(rf'\b{instance}\s*\(', source))
        if not calls or source.count(copyout) != calls:
            return [f'manual reference integration: every {instance} call requires explicit VAR_IN_OUT copy-out']
    return []


if __name__ == '__main__':
    raise SystemExit(main())
