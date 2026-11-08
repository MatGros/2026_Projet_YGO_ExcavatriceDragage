"""Opt-in real model A/B. Never attaches to or modifies a CLI conversation."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys
import time
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from TOOLS.AGENT_SUPERVISOR.scripts import supervisor_service as service
from TOOLS.AGENT_SUPERVISOR.tests.campaign_fr import CASES


def run_one(case, variant, system, model):
    started = time.monotonic()
    record = dict(id=case['id'], variant=variant, source=case['source'], split=case['split'], expected=case['expected'])
    payload = dict(model=model, system=system, prompt=json.dumps(case['messages'], ensure_ascii=False),
                   stream=False, think=False, format='json',
                   options=dict(temperature=0, num_ctx=16384, num_predict=1800))
    try:
        request = urllib.request.Request('http://127.0.0.1:11434/api/generate', data=json.dumps(payload).encode(), headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(request, timeout=90) as response:
            envelope = json.load(response)
        result = json.loads(envelope.get('response', ''))
        if not isinstance(result, dict) or not isinstance(result.get('alert'), bool):
            raise ValueError('invalid_verdict')
        quote = result.get('evidence', '')
        exact = not result['alert'] or (isinstance(quote, str) and len(quote.strip()) >= 4 and any(m['role'] == 'assistant' and quote in m['text'] for m in case['messages']))
        grounded = not result['alert'] or (exact and service.alert_basis(result, case['messages']))
        record.update(result=result, exact_quote=exact, grounded=grounded,
                      status='match' if result['alert'] == case['expected'] and exact and grounded else 'mismatch',
                      input_tokens=envelope.get('prompt_eval_count'), output_tokens=envelope.get('eval_count'), done_reason=envelope.get('done_reason'))
    except Exception as exc:
        record.update(status='unavailable', error=type(exc).__name__)
    record['seconds'] = round(time.monotonic()-started, 3)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', required=True)
    parser.add_argument('--allow-cloud', action='store_true', help='Explicit permission to send these short excerpts to the configured cloud model')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--variant', choices=['A', 'B', 'both'], default='both')
    parser.add_argument('--split', choices=['tuning', 'heldout', 'all'], default='all')
    args = parser.parse_args()
    service.check_model_consent(args.model, args.allow_cloud)
    baseline = getattr(service, 'BASELINE_JUDGE_SYSTEM', service.JUDGE_SYSTEM.split(' Pour chaque constat existant fourni,')[0])
    systems = {'A': baseline, 'B': service.JUDGE_SYSTEM}
    variants = list(systems) if args.variant == 'both' else [args.variant]
    cases = [case for case in CASES if args.split == 'all' or case['split'] == args.split]
    jobs = [(case, variant) for case in cases for variant in variants]
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(run_one, case, variant, systems[variant], args.model) for case, variant in jobs]
        results = [future.result() for future in futures]
    report = dict(created_at=datetime.now(timezone.utc).isoformat(), model=args.model, cloud_consent=args.allow_cloud,
                  kind='real_model_offline_corpus_not_live_sessions', cases=results,
                  prompt_hashes={v:hashlib.sha256(systems[v].encode()).hexdigest() for v in variants})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    for variant in variants:
        rows = [r for r in results if r['variant'] == variant]
        print(variant, {s:sum(r['status']==s for r in rows) for s in ['match','mismatch','unavailable']})
    return 0 if all(r['status']=='match' for r in results if r['variant']=='B') else 1


if __name__ == '__main__':
    raise SystemExit(main())
