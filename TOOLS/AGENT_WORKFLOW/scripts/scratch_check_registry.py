import re

with open('TOOLS/TEST_AUTO_CI/registry.yaml', 'r', encoding='utf-8') as f:
    lines = f.readlines()

problems = []
for i, line in enumerate(lines):
    if 'ST_AcquisitionNetworkDiagnostics.st' in line:
        window = lines[max(0,i-35):i]
        has_ediag = any('E_Diag_State' in l for l in window)
        has_sdiag = any('ST_Diag_Device.st' in l for l in window)
        if not has_ediag or not has_sdiag:
            entry_name = '?'
            for j in range(i-1, max(0,i-80), -1):
                stripped = lines[j].strip()
                if stripped.endswith(':') and not stripped.startswith('-') and stripped != 'sources:':
                    entry_name = stripped.rstrip(':')
                    break
            problems.append({'line': i+1, 'entry': entry_name, 'has_ediag': has_ediag, 'has_sdiag': has_sdiag})

for p in problems:
    print("Ligne %4d | %-35s | E_Diag_State=%s | ST_Diag_Device=%s" % (
        p['line'], p['entry'], p['has_ediag'], p['has_sdiag']))
print("Total problemes: %d" % len(problems))
