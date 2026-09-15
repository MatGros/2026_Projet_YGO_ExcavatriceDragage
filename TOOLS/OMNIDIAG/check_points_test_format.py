import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

with open('knowledge_base.json', 'r', encoding='utf-8') as f:
    kb = json.load(f)

print(f"Vérification des {len(kb)} fiches...")

missing_chevrons = []
for k, v in kb.items():
    pt = v.get('points_test', '')
    count = pt.count('➔')
    # Les fiches avec 2 signaux peuvent avoir plusieurs chevrons ou barre verticale, mais doivent contenir au moins un chevron
    if count < 1:
        missing_chevrons.append((k, pt))

if missing_chevrons:
    print(f"❌ {len(missing_chevrons)} fiches sans chevron ➔ :")
    for k, pt in missing_chevrons:
        print(f"  [{k}] {pt}")
else:
    print("✅ 100% DES 87 FICHES ONT LE FORMAT NORMALISÉ AVEC CHEVRONS ➔ !")
