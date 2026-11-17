"""Bisect R29 : qui bloque le spawn dans le contexte du service ?
Verrou d'etat + serveur thread + Popen DETACHED, chaque etape trace.
Resultat : %TEMP%/t429_bisect_spawn.out
"""
import time
import threading
import http.server
import os
import sys
import msvcrt

out = open(os.path.join(os.environ['TEMP'], 't429_bisect_spawn.out'), 'w', encoding='utf-8')

def log(message):
    from datetime import datetime
    out.write(f"{datetime.now().isoformat(timespec='seconds')} {message}\n")
    out.flush()

log("debut")
lock = open(os.path.join(os.environ['TEMP'], 't429_bisect.lock'), 'a+b')
msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
log("verrou pris")
server = type('S', (http.server.ThreadingHTTPServer,), {'daemon_threads': True})(('127.0.0.1', 0), http.server.BaseHTTPRequestHandler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
log("serveur thread demarre")
log("Popen DETACHED + DEVNULL en cours")
import subprocess
try:
    child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(3)'],
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, creationflags=0x8 | 0x200)
    log(f"spawn OK pid={child.pid}")
except Exception as exc:
    log(f"spawn ECHEC {type(exc).__name__}: {exc}")
log("fin")
out.close()
os._exit(0)
