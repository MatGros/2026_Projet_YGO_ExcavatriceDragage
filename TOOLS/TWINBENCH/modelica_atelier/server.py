"""Local-only atelier. Single native simulation thread, browser sends input intent."""
from __future__ import annotations
from collections import deque
import csv
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import io
import json
import math
from pathlib import Path
import threading
import time
import urllib.parse
import webbrowser
import argparse
from runtime import Engine, DEFAULTS, ROOT, SIGNALS, parameters, variant, installation

MODEL_SCHEMA=2  # M1/M2/M3; client rejects an old process instead of silently losing winch commands.

class Session:
    def __init__(self):
        self.lock=threading.RLock()
        self.engine=None; self.error=''; self.running=False; self.ready=False
        self.config=DEFAULTS.copy(); self.lever=0.; self.m1_command=0.; self.m2_command=0.; self.held=0.; self.last_input=0.
        self.frames=deque(maxlen=15000); self.events=deque(maxlen=150)
        self.scenario='manual'; self.started=0.; self.seq=0; self.epoch=0
        self.lag=0.; self.last={}; self.shutdown=False

    def event(self,text):
        self.events.append(dict(t=round(self.last.get('t',0),2),text=text))

    def loop(self):
        try:
            # The user may still be completing the installer. Do not launch a partial toolchain.
            while not (installation()/'share/omc/runtime/c/fmi/buildproject/CMakeLists.txt.in').exists():
                if self.shutdown: return
                time.sleep(2)
            self.engine=Engine(); self.ready=True
            self.event('FMU chargée · physique Modelica / OMSimulator')
        except Exception as exc:
            self.error=str(exc); return
        due=time.perf_counter()
        while not self.shutdown:
            try:
                with self.lock:
                    if self.running:
                        lever,m1_command,m2_command,held=self.lever,self.m1_command,self.m2_command,self.held
                        if time.monotonic()-self.last_input>.45:
                            lever=m1_command=m2_command=held=0.
                            if self.scenario!='manual' or self.held:
                                self.event('Commande expirée : homme-mort relâché')
                            self.scenario='manual'; self.held=0.
                        if self.scenario!='manual':
                            elapsed=self.engine.t-self.started
                            if self.scenario=='brake': lever,held=(.75,1) if elapsed<4 else (0,0)
                            else: lever,held=(.7,1) if elapsed<3 else ((-.7,1) if elapsed<7 else (0,0))
                            if elapsed>=10:
                                self.scenario='manual'; lever=held=0.; self.event('Scénario terminé · conduite libre')
                        old=self.last
                        begin=time.perf_counter(); frame=self.engine.step(lever,held,m1_command,m2_command)
                        self.lag=(time.perf_counter()-begin)*1000
                        self.seq+=1; frame['seq']=self.seq; self.frames.append(frame); self.last=frame
                        if frame['sensor'] != old.get('sensor',0): self.event('Capteur actif' if frame['sensor'] else 'Capteur libéré')
                        if frame['overtravel'] and not old.get('overtravel',0):
                            self.event('Hors course : rail dépassé, sans écrêtage de position')
                    else: due=time.perf_counter()
            except Exception as exc:
                with self.lock:
                    self.error=str(exc); self.running=False
            due+=.02
            wait=due-time.perf_counter()
            if wait<-.2:
                # Never drop physics steps to catch up. Show real-time ratio in the UI.
                due=time.perf_counter(); wait=0
            time.sleep(max(0,wait))
        self.engine.close()

    def command(self,data):
        if not self.ready or self.error: raise ValueError(self.error or 'Compilation en cours')
        action=data.get('action')
        if action=='input':
            lever=float(data.get('lever',0)); m1_command=float(data.get('m1Command',0)); m2_command=float(data.get('m2Command',0)); held=float(data.get('held',0))
            if not all(math.isfinite(v) and -1<=v<=1 for v in (lever,m1_command,m2_command)) or held not in (0,1): raise ValueError('Commande invalide')
            self.lever=lever; self.m1_command=m1_command; self.m2_command=m2_command; self.held=held; self.last_input=time.monotonic()
        elif action=='play':
            self.running=True; self.lever=self.m1_command=self.m2_command=self.held=0.; self.last_input=time.monotonic(); self.event('Simulation démarrée')
        elif action=='pause':
            self.running=False; self.lever=self.m1_command=self.m2_command=self.held=0.; self.scenario='manual'; self.event('Pause')
        elif action=='manual':
            self.scenario='manual'; self.lever=self.m1_command=self.m2_command=self.held=0.; self.event('Reprise manuelle')
        elif action=='reset':
            self.running=False; self.scenario='manual'; self.lever=self.m1_command=self.m2_command=self.held=0.
            self.engine.reset(self.config); self.frames.clear(); self.events.clear(); self.last={}; self.seq=0; self.epoch+=1
            self.event('État initial restauré · paramètres conservés')
        elif action=='edit':
            patch=parameters(data.get('params',{})); self.config.update(patch); self.engine.set(patch)
            self.event('Édition : '+', '.join(f'{k}={v:g}' for k,v in patch.items()))
        elif action=='scenario':
            name=data.get('name')
            if name not in ('brake','reverse'): raise ValueError('Scénario inconnu')
            self.scenario=name; self.started=self.engine.t; self.running=True; self.last_input=time.monotonic()
            self.event('Scénario : '+('Freinage' if name=='brake' else 'Inversion'))
        else: raise ValueError('Action inconnue')

    def snapshot(self,after):
        return dict(ready=self.ready,error=self.error,running=self.running,config=self.config,
                    frames=[f for f in self.frames if f['seq']>after],last=self.last,events=list(self.events),
                    scenario=self.scenario,epoch=self.epoch,stepMs=self.lag,signals=SIGNALS,modelSchema=MODEL_SCHEMA)

SESSION=Session()

class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def send(self,body,kind='application/json',status=200,filename=None):
        payload=body if isinstance(body,bytes) else body.encode('utf-8')
        self.send_response(status); self.send_header('Content-Type',kind+'; charset=utf-8')
        self.send_header('Content-Length',str(len(payload))); self.send_header('Cache-Control','no-store')
        self.send_header('X-Content-Type-Options','nosniff')
        if filename: self.send_header('Content-Disposition',f'attachment; filename="{filename}"')
        self.end_headers(); self.wfile.write(payload)
    def do_GET(self):
        url=urllib.parse.urlparse(self.path)
        if url.path in ('/','/app.js','/style.css'):
            name={'/':'index.html','/app.js':'app.js','/style.css':'style.css'}[url.path]
            kind={'/':'text/html','/app.js':'text/javascript','/style.css':'text/css'}[url.path]
            return self.send((ROOT/name).read_bytes(),kind)
        with SESSION.lock:
            if url.path=='/state':
                try: after=int(urllib.parse.parse_qs(url.query).get('after',['0'])[0])
                except ValueError: return self.send('{}',status=400)
                return self.send(json.dumps(SESSION.snapshot(after)))
            if url.path=='/model': return self.send(variant(SESSION.config),'text/plain',filename='MaVariante.mo')
            if url.path=='/session':
                return self.send(json.dumps(dict(config=SESSION.config,events=list(SESSION.events),frames=list(SESSION.frames),model='Atelier.AxisLab',note='Acquisition bornée aux 15000 derniers pas; pas de rejeu déterministe implémenté.'),ensure_ascii=False),'application/json',filename='session-atelier.json')
            if url.path=='/csv':
                output=io.StringIO(); writer=csv.DictWriter(output,fieldnames=['t','seq',*SIGNALS]); writer.writeheader(); writer.writerows(SESSION.frames)
                return self.send(output.getvalue(),'text/csv',filename='traces-atelier.csv')
        self.send('{}',status=404)
    def do_POST(self):
        # Loopback only plus origin check: no cross-site control of the local session.
        origin=self.headers.get('Origin')
        if origin and origin!=f'http://{self.headers.get("Host")}': return self.send('{}',status=403)
        if self.path!='/command': return self.send('{}',status=404)
        try:
            size=int(self.headers.get('Content-Length','0'))
            if not 0<size<4096: raise ValueError('Taille de commande invalide')
            data=json.loads(self.rfile.read(size))
            with SESSION.lock: SESSION.command(data)
            self.send('{"ok":true}')
        except (BrokenPipeError, ConnectionAbortedError, ConnectionResetError):
            # A browser reload can abandon its in-flight POST. This is not an FMU failure.
            return
        except (ValueError,TypeError,KeyError) as exc: self.send(json.dumps(dict(error=str(exc))),status=400)
        except Exception as exc:
            SESSION.error=str(exc); SESSION.running=False
            self.send(json.dumps(dict(error=str(exc))),status=500)

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--port',type=int,default=8766); parser.add_argument('--no-browser',action='store_true'); args=parser.parse_args()
    server=ThreadingHTTPServer(('127.0.0.1',args.port),Handler)
    threading.Thread(target=SESSION.loop,daemon=True).start()
    print(f'Atelier : http://127.0.0.1:{args.port} — Ctrl+C pour fermer',flush=True)
    if not args.no_browser: webbrowser.open(f'http://127.0.0.1:{args.port}')
    try: server.serve_forever()
    except KeyboardInterrupt: SESSION.shutdown=True; server.server_close()
