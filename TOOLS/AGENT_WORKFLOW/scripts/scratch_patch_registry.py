"""
Patch registry.yaml : ajoute les dépendances manquantes de ST_AcquisitionNetworkDiagnostics.
Insère avant chaque occurrence de ST_AcquisitionNetworkDiagnostics.st les 2 lignes manquantes si absentes
dans la fenetre de 40 lignes precedentes.
"""
import re

with open('TOOLS/TEST_AUTO_CI/registry.yaml', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
i = 0
insertions = 0
while i < len(lines):
    line = lines[i]
    if 'ST_AcquisitionNetworkDiagnostics.st' in line:
        # Verifier fenetre de 40 lignes precedentes dans new_lines
        window = new_lines[-40:] if len(new_lines) >= 40 else new_lines
        has_ediag = any('E_Diag_State' in l for l in window)
        has_sdiag = any('ST_Diag_Device.st' in l for l in window)
        indent = '    '  # 4 espaces comme le reste du fichier
        if not has_ediag:
            new_lines.append(indent + '- CODE/C_DIAG_RESEAUX/E_Diag_State.st\r\n')
            insertions += 1
        if not has_sdiag:
            new_lines.append(indent + '- CODE/C_DIAG_RESEAUX/ST_Diag_Device.st\r\n')
            insertions += 1
    new_lines.append(line)
    i += 1

with open('TOOLS/TEST_AUTO_CI/registry.yaml', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Insertions effectuees: %d" % insertions)
print("E_Diag_State occurrences: %d" % sum(1 for l in new_lines if 'E_Diag_State' in l))
print("ST_Diag_Device occurrences: %d" % sum(1 for l in new_lines if 'ST_Diag_Device.st' in l))
