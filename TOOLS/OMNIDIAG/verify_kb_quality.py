import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

with open('knowledge_base.json', 'r', encoding='utf-8') as f:
    kb = json.load(f)

print(f"Total fiches KB : {len(kb)}")

forbidden_words = ['cabine', 'appeler la maintenance', 'capteur sur mâchoire', 'inductif disque']
errors = []

for k, v in kb.items():
    for field in ['action_conducteur', 'action_maintenance', 'cause_racine', 'points_test']:
        txt = v.get(field, '').lower()
        for fw in forbidden_words:
            if fw in txt:
                errors.append(f"[{k}] Champ {field} contient '{fw}'")

if errors:
    print(f"❌ {len(errors)} anomalies détectées :")
    for e in errors:
        print("  -", e)
else:
    print("✅ VALIDATION PARFAITE : 0 mot interdit ('cabine', 'appeler la maintenance', capteur sur mâchoire).")
