"""Profil R29 (2026-11-22) : le snapshot complet prend ~7 s (1,2 Mo) -> l'IHM
timeout a 8 s et affiche 'service injoignable'. Identifier les points chauds.
Lecture seule : charge l'etat, aucun ecrit (load_error sinon).
Usage : python TOOLS/AGENT_SUPERVISOR/tests/profile_snapshot.py
"""
import cProfile
import io
import os
import pstats
import sys
import time

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scripts')))
import supervisor_service as m  # noqa: E402

STATE = os.path.join(os.environ['LOCALAPPDATA'], 'ExcavatriceDragage', 'agent-supervision.json')


def main():
    service = m.Supervisor(STATE)
    if service.load_error:
        print('load_error :', service.load_error)
        return 1
    t0 = time.monotonic()
    snapshot = service.snapshot()
    elapsed = time.monotonic() - t0
    print('snapshot direct : %.2f s | %d sessions' % (elapsed, len(snapshot['sessions'])))
    profiler = cProfile.Profile()
    profiler.enable()
    service.snapshot()
    profiler.disable()
    buffer = io.StringIO()
    pstats.Stats(profiler, stream=buffer).sort_stats('cumulative').print_stats(16)
    print('\n'.join(buffer.getvalue().splitlines()[4:28]))
    return 0


if __name__ == '__main__':
    sys.exit(main())
