"""R29 (demande exploitant 2026-11-22) : etat memoire par session, en %.
Lecture seule : lit le snapshot sauvegarde (pas le service vivant).
Usage : python TOOLS/AGENT_SUPERVISOR/tests/memory_state_report.py <snapshot.json>
"""
import json
import os
import sys


def main(path):
    data = json.load(open(path, encoding='utf-8'))
    settings = data.get('judge_settings') or {}
    ctx_max = int(settings.get('context_messages') or 12)
    ctx_chars_max = int(settings.get('context_chars') or 12000)
    mem_max = int(settings.get('memory_max_items') or 20)
    print('fenetre = %d msg / %d car | longue = %d max | modele = %s tokens (par appel juge)' % (
        ctx_max, ctx_chars_max, mem_max, settings.get('model_context_tokens')))
    print('%-12s %7s %14s %16s %14s %18s' % ('session', 'vus', 'fenetre msg', 'fenetre car', 'longue', 'longue car'))
    for session in data.get('sessions') or []:
        ctx = session.get('context') or []
        mem = session.get('memory') or []
        ctx_chars = sum(len(str(item.get('text') or '')) for item in ctx)
        mem_chars = sum(len(str(item.get('text') or '')) for item in mem)
        print('%-12s %7d   %2d/%2d %3d%%   %5d/%5d %3d%%   %3d/%3d %3d%%   %6d' % (
            session.get('alias') or '?', session.get('messages_observed') or 0,
            len(ctx), ctx_max, round(100 * len(ctx) / max(1, ctx_max)),
            ctx_chars, ctx_chars_max, round(100 * ctx_chars / max(1, ctx_chars_max)),
            len(mem), mem_max, round(100 * len(mem) / max(1, mem_max)), mem_chars))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ['TEMP'], 's1.json')))
