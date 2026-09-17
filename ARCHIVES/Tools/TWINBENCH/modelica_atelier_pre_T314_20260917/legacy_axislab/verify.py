"""Acceptance checks against the actual native FMU, not a duplicate plant model."""
import json
from pathlib import Path
import subprocess
import tempfile
import time
from runtime import Engine, DEFAULTS, parameters, variant

def main():
    engine=Engine()
    checks={}
    def run(n,lever,held,m1_command=0,m2_command=0):
        samples=[]
        for _ in range(n): samples.append(engine.step(lever,held,m1_command,m2_command))
        return samples
    stationary=run(100,1,0)[-1]
    assert abs(stationary['position']-12)<1e-6
    checks['homme_mort_independant']='PASS'
    engine.reset(); forward=run(150,.8,1)[-1]
    assert forward['position']>12.5 and forward['velocity']>0
    stopped=run(150,0,0)[-1]
    assert abs(stopped['velocity'])<.02
    checks['avance_et_freinage']='PASS'
    engine.reset(); reverse=run(150,-.8,1)[-1]
    assert reverse['position']<11.5 and reverse['velocity']<0
    checks['marche_arriere']='PASS'
    engine.reset(DEFAULTS|{'mass':1000}); light=run(50,.8,1)[-1]['velocity']
    engine.reset(DEFAULTS|{'mass':10000}); heavy=run(50,.8,1)[-1]['velocity']
    assert light>heavy*1.5
    checks['inertie_masse']={'light_mps':light,'heavy_mps':heavy}
    engine.reset(); engine.set({'sensorPosition':12}); sensor=run(1,0,0)[-1]
    assert sensor['sensor']==1
    engine.set({'sensorPosition':25}); assert run(1,0,0)[-1]['sensor']==0
    checks['edition_capteur_native']='PASS'
    engine.reset(); begin=time.perf_counter(); outside=run(1200,1,1)[-1]; elapsed=time.perf_counter()-begin
    assert outside['position']>30 and outside['overtravel']==1
    checks['surcourse_non_masquee']='PASS'
    engine.reset(); opened=run(1,0,0)[-1]
    assert opened['bucketOpen']==1 and opened['bucketOpening']>=95 and abs(opened['bucketDelta'])<.01
    closed=run(1250,0,1,0,1)[-1]
    assert closed['m2Position']-closed['m1Position']>15 and closed['bucketClosed']==1 and closed['bucketOpening']<=5
    checks['cinematique_benne_m2_m1']='PASS'
    engine.reset(); lowered=run(220,0,1,-1,-1)[-1]
    assert lowered['translationPermit']==0
    blocked=run(100,.8,1)[-1]
    assert abs(blocked['position']-lowered['position'])<.01 and abs(blocked['motorForce'])<.1
    checks['interlock_translation_hauteur_m1_m2']='PASS'
    checks['performance']={'steps':1200,'wall_seconds':elapsed,'simulation_seconds':24,'mean_ms':elapsed/1200*1000}
    try: parameters({'mass':float('nan')})
    except ValueError: pass
    else: raise AssertionError('NaN accepté')
    try: parameters({'mass':-100})
    except ValueError: pass
    else: raise AssertionError('Masse négative acceptée')
    checks['validation_parametres']='PASS'
    work=Path(tempfile.mkdtemp(prefix='atelier_variant_'))
    model=work/'MaVariante.mo'; model.write_text(variant(DEFAULTS|{'mass':6300}),encoding='utf-8')
    script=work/'check.mos'; script.write_text(f'loadModel(Modelica, {{"4.0.0"}});\nloadFile({json.dumps(model.as_posix())});\ncheckModel(MaVariante);\ngetErrorString();\n',encoding='utf-8')
    result=subprocess.run([str(engine.om/'bin/omc.exe'),str(script)],cwd=work,capture_output=True,text=True,timeout=60)
    assert 'completed successfully' in result.stdout, result.stdout+result.stderr
    checks['export_modelica_recharge']='PASS'
    checks['variant_check']=result.stdout.strip()
    example_script=work/'check_example.mos'
    example_script.write_text(
        f'loadModel(Modelica, {{"4.0.0"}});\nloadFile({json.dumps((Path(__file__).resolve().parent/"Atelier.mo").as_posix())});\n'
        'checkModel(Atelier.Examples.CycleM1M2M3);\n'
        'checkModel(Atelier.Examples.AnimatedCycle);\ngetErrorString();\n',
        encoding='utf-8')
    example_result=subprocess.run(
        [str(engine.om/'bin/omc.exe'),str(example_script)],cwd=work,
        capture_output=True,text=True,timeout=60)
    assert 'completed successfully' in example_result.stdout, example_result.stdout+example_result.stderr
    checks['exemple_omedit_autonome']='PASS'
    assert 'AnimatedCycle' in example_result.stdout, example_result.stdout+example_result.stderr
    animation_work=work/'animation'
    animation_work.mkdir()
    animation_script=animation_work/'simulate_animation.mos'
    animation_script.write_text(
        f'loadModel(Modelica, {{"4.0.0"}});\nloadFile({json.dumps((Path(__file__).resolve().parent/"Atelier.mo").as_posix())});\n'
        'setCommandLineOptions("+d=visxml");\n'
        'simulate(Atelier.Examples.AnimatedCycle, stopTime=2, numberOfIntervals=20);\n'
        'getErrorString();\n', encoding='utf-8')
    animation_result=subprocess.run(
        [str(engine.om/'bin/omc.exe'),str(animation_script)],cwd=animation_work,
        capture_output=True,text=True,timeout=180)
    visual_files=list(animation_work.glob('*_visual.xml'))
    assert animation_result.returncode==0 and visual_files, animation_result.stdout+animation_result.stderr
    checks['animation_omedit_3d']='PASS'
    contract_work=work/'controller_contract'
    contract_work.mkdir()
    contract_script=contract_work/'check_contract.mos'
    contract_script.write_text(
        f'loadModel(Modelica, {{"4.0.0"}});\nloadFile({json.dumps((Path(__file__).resolve().parent/"Dredge.mo").as_posix())});\n'
        'checkModel(Dredge.TranslationM3Plant);\n'
        'simulate(Dredge.Examples.M3ContractCycle, stopTime=12, numberOfIntervals=120);\ngetErrorString();\n', encoding='utf-8')
    contract_result=subprocess.run(
        [str(engine.om/'bin/omc.exe'),str(contract_script)],cwd=contract_work,
        capture_output=True,text=True,timeout=180)
    assert contract_result.returncode==0 and 'completed successfully' in contract_result.stdout, contract_result.stdout+contract_result.stderr
    checks['contrat_m3_commandes_finales']='PASS'
    engine.close()
    print(json.dumps(checks,ensure_ascii=False,indent=2))

if __name__=='__main__': main()
