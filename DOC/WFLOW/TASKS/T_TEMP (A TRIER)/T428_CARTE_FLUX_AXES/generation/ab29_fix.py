# -*- coding: utf-8 -*-
import json, re
from pathlib import Path

T = Path(r"C:\Users\ZEDVICTUS\.claude\jobs\ebe3ca88\tmp\carte")
for ax in ("M1", "M2"):
    p = T / f"annot_{ax}.json"
    ann = json.load(open(p, encoding="utf-8"))
    n = 0
    for c, a in ann.items():
        m = re.fullmatch(r"PRG_06_Outputs\.(M[12])(RelayFwd|RelayRev|SpeedContactor[1-4])", c)
        if m and "Protector" in a["code"]:
            a["condition"] = "Sortie de la barriere finale, puis ecrasee dans le meme cycle par le protecteur anti-chatter : la derniere affectation fait foi"
            a["si_dernier_vrai"] = "Comparer l'ordre de la barriere et la commande du protecteur, puis la sortie physique"
            n += 1
    json.dump(ann, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(ax, n)
p = T / "annot_AU.json"
ann = json.load(open(p, encoding="utf-8"))
a = ann["PRG_06_Outputs.instSafetyEmergencyManagement.Enable"]
a["code"] = "PRG_06_Outputs.st:486 = Enable := TRUE,"
a["condition"] = "Forcee a TRUE a l'appel du bloc : toujours vraie"
a["si_dernier_vrai"] = "Maillon non discriminant : verifier la sequence d'armement du bloc"
json.dump(ann, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
