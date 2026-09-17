"""Native OMSimulator bridge. Physics exists only in Atelier.mo; no Python fallback."""
from __future__ import annotations
import ctypes as C
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent
DEFAULTS = dict(mass=4000., forceLimit=3500., brakeDelay=.25, sensorPosition=21.)
PLANT_DEFAULTS = dict(winchMaxSpeed=.65, translationMinHeight=6., bucketOffsetOpen=0., bucketOffsetClose=15.)
BOUNDS = dict(mass=(500,12000), forceLimit=(500,7000), brakeDelay=(.05,1.5), sensorPosition=(1,29))
SIGNALS = dict(position=('Position M3','m'), velocity=('Vitesse M3','m/s'), acceleration=('Accélération M3','m/s²'), motorForce=('Effort moteur M3','N'), brakeForce=('Effort de frein M3','N'), brake=('Serrage frein M3','0–1'), sensor=('Capteur M3','0/1'), energy=('Énergie cinétique M3','J'), overtravel=('Hors course M3','0/1'), m1Position=('Câble M1 retenue','m'), m1Speed=('Vitesse M1','m/s'), m2Position=('Câble M2 benne','m'), m2Speed=('Vitesse M2','m/s'), bucketDelta=('Delta M2−M1','m'), bucketOpening=('Ouverture benne','%'), bucketOpen=('Benne ouverte','0/1'), bucketClosed=('Benne fermée','0/1'), translationPermit=('Permis translation','0/1'), lever=('Commande M3','−1…1'), m1Command=('Commande M1','−1…1'), m2Command=('Commande M2','−1…1'), held=('Homme-mort','0/1'))

def installation():
    override = os.environ.get('OPENMODELICAHOME')
    candidates = ([Path(override)] if override else []) + sorted(Path('C:/Program Files').glob('OpenModelica*'), reverse=True)
    for candidate in candidates:
        if (candidate/'bin/omc.exe').exists():
            return candidate
    raise RuntimeError('OpenModelica introuvable : définir OPENMODELICAHOME.')

def parameters(raw):
    if not isinstance(raw, dict) or set(raw)-set(BOUNDS):
        raise ValueError('Paramètres inconnus')
    result = {}
    for key, val in raw.items():
        number = float(val)
        low, high = BOUNDS[key]
        if not math.isfinite(number) or not low <= number <= high:
            raise ValueError(f'{key} hors plage [{low}, {high}]')
        result[key] = number
    return result

def variant(config):
    p = DEFAULTS | parameters(config)
    modifiers = ', '.join(f'{key}={value:g}' for key,value in p.items())
    return (ROOT/'Atelier.mo').read_text(encoding='utf-8') + f'\nmodel MaVariante\n  extends Atelier.AxisLab({modifiers});\nend MaVariante;\n'

def compile_fmu():
    om = installation()
    # Compiler products are scratch, kept outside the repository; never auto-deleted.
    digest = hashlib.sha256((ROOT/'Atelier.mo').read_bytes() + str(om).encode()).hexdigest()[:16]
    work = Path(tempfile.gettempdir())/'TwinBenchAtelier'/digest
    work.mkdir(parents=True, exist_ok=True)
    fmu = work/'Atelier_AxisLab.fmu'
    if not fmu.exists():
        script = work/'build.mos'
        script.write_text(f'loadModel(Modelica, {{"4.0.0"}});\nloadFile({json.dumps((ROOT/"Atelier.mo").as_posix())});\ngetErrorString();\nbuildModelFMU(Atelier.AxisLab, version="2.0", fmuType="cs", fileNamePrefix="Atelier_AxisLab");\ngetErrorString();\n', encoding='utf-8')
        result = subprocess.run([str(om/'bin/omc.exe'), str(script)], cwd=work, capture_output=True, text=True, timeout=240)
        (work/'build.log').write_text(result.stdout+result.stderr, encoding='utf-8')
        if result.returncode or not fmu.exists():
            raise RuntimeError(f'Compilation échouée : {work}/build.log\n{result.stdout[-2500:]}')
    return om, fmu, work

class Engine:
    def __init__(self):
        self.om, self.fmu, self.work = compile_fmu()
        self.dll_dirs = [os.add_dll_directory(str(self.om/'bin'))]
        self.lib = C.CDLL(str(self.om/'bin/libOMSimulator.dll'))
        signatures = {
            'newModel':[C.c_char_p], 'addSystem':[C.c_char_p,C.c_int],
            'addSubModel':[C.c_char_p,C.c_char_p], 'setResultFile':[C.c_char_p,C.c_char_p,C.c_int],
            'setTempDirectory':[C.c_char_p], 'setStopTime':[C.c_char_p,C.c_double],
            'setFixedStepSize':[C.c_char_p,C.c_double], 'setReal':[C.c_char_p,C.c_double],
            'getReal':[C.c_char_p,C.POINTER(C.c_double)], 'instantiate':[C.c_char_p],
            'initialize':[C.c_char_p], 'stepUntil':[C.c_char_p,C.c_double],
            'terminate':[C.c_char_p], 'delete':[C.c_char_p],
        }
        for name,args in signatures.items():
            fn=getattr(self.lib,'oms_'+name); fn.argtypes=args; fn.restype=C.c_int
        self.call('setTempDirectory',str(self.work).encode())
        self.active=False
        self.config=DEFAULTS.copy()
        self.reset()

    def call(self,name,*args):
        code=getattr(self.lib,'oms_'+name)(*args)
        if code>1:
            raise RuntimeError(f'OMSimulator {name}: status {code}')

    def reset(self, config=None):
        if self.active:
            self.call('terminate',b'atelier'); self.call('delete',b'atelier')
        self.active=False
        self.config=DEFAULTS | parameters(config or self.config)
        self.call('newModel',b'atelier')
        self.call('addSystem',b'atelier.root',2)  # none=0, tlm=1, wc=2, sc=3 (Types.h)
        self.call('addSubModel',b'atelier.root.axis',str(self.fmu).encode())
        self.call('setResultFile',b'atelier',b'',0)
        self.call('setStopTime',b'atelier',86400.)
        self.call('setFixedStepSize',b'atelier.root',.02)
        self.call('instantiate',b'atelier')
        # FMI co-simulation inputs are set explicitly: do not rely on FMU start values.
        self.set(self.config | PLANT_DEFAULTS | dict(lever=0.,m1Command=0.,m2Command=0.,held=0.))
        self.call('initialize',b'atelier')
        self.t=0.; self.active=True

    def set(self, values):
        for key,val in values.items():
            self.call('setReal',f'atelier.root.axis.{key}'.encode(),float(val))

    def step(self,lever,held,m1_command=0.,m2_command=0.):
        self.set(dict(lever=lever,m1Command=m1_command,m2Command=m2_command,held=held))
        self.t=round(self.t+.02,8)
        self.call('stepUntil',b'atelier',self.t)
        result=dict(t=self.t,lever=float(lever),m1Command=float(m1_command),m2Command=float(m2_command),held=float(held))
        for name in SIGNALS:
            if name in result: continue
            value=C.c_double()
            self.call('getReal',f'atelier.root.axis.{name}'.encode(),C.byref(value))
            if not math.isfinite(value.value): raise RuntimeError('Sortie non finie : '+name)
            result[name]=value.value
        return result

    def close(self):
        if self.active:
            self.call('terminate',b'atelier')
            self.call('delete',b'atelier')
            self.active=False

if __name__=='__main__':
    engine=Engine()
    for _ in range(100): result=engine.step(.6,1)
    print(json.dumps(result,indent=2))
