"""Validate exact synthetic user/assistant items for one explicitly supplied UUID."""
import argparse
import json
from pathlib import Path
import sys
import uuid


def main():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf8')
    parser = argparse.ArgumentParser()
    parser.add_argument('thread_id', type=lambda value: str(uuid.UUID(value)))
    parser.add_argument('marker')
    args = parser.parse_args()
    if not args.marker.startswith('POC_ALERTE_ACTIF_'):
        raise SystemExit('Marqueur synthétique requis')
    files = list((Path.home()/'.codex'/'sessions').rglob('*'+args.thread_id+'.jsonl'))
    if len(files) != 1:
        raise SystemExit(f'Source absente ou ambiguë : {len(files)}')
    events = []
    for line in files[0].read_text(encoding='utf8').splitlines():
        row = json.loads(line)
        if row.get('type') != 'event_msg':
            continue
        p = row.get('payload', {})
        item = p.get('item', {})
        text = ''.join(x.get('text', '') for x in item.get('content', []) if isinstance(x, dict))
        if p.get('type') == 'item_completed' and p.get('thread_id') == args.thread_id and args.marker in text:
            events.append({'timestamp': row.get('timestamp'), 'thread': p['thread_id'],
                           'turn': p.get('turn_id'), 'item_type': item.get('type'), 'text': text})
    users = [e for e in events if e['item_type'] == 'UserMessage']
    assistants = [e for e in events if e['item_type'] == 'AgentMessage' and e['text'].strip() == args.marker]
    matched = any(a['turn'] == u['turn'] and a['timestamp'] >= u['timestamp'] for u in users for a in assistants)
    print(json.dumps({'source': str(files[0]), 'marker':args.marker, 'events':events,
                      'same_thread_turn_and_exact_response':matched}, ensure_ascii=False, indent=2))
    return 0 if matched else 1


if __name__ == '__main__':
    sys.exit(main())
