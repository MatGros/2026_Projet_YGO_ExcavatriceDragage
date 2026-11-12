import json, os, sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(__file__))
from rules import evaluate

def main():
    data = json.load(open(os.path.join(os.path.dirname(__file__), "cas.json"), encoding="utf-8"))
    r = evaluate(data["cas"], data["catalogue"])
    print(f"cas synthétiques : {len(data['cas'])} | TP={r['tp']} FP={r['fp']} FN={r['fn']} TN={r['tn']}")
    for kind, cid in r["erreurs"]:
        print(f"  {kind} : {cid}")
    return 0 if not r["erreurs"] else 1

if __name__ == "__main__":
    sys.exit(main())
