'use strict';
const $=id=>document.getElementById(id);
const REQUIRED_MODEL_SCHEMA=2;
if(document.head){const operatorStyle=document.createElement('style');operatorStyle.textContent=`:root{--ink:#e8f1ec;--muted:#9aada2;--line:#34463e;--green:#44bb88;--paper:#101814;--white:#17231d;--orange:#f0a65c}body{background:var(--paper);color:var(--ink)}header{background:#0c120f;border-color:var(--line)}.brand,.text-link,a{color:var(--ink)}.project,.engine{color:var(--muted)}main{max-width:1640px}.intro{margin-bottom:16px}.intro h1{font-family:system-ui,sans-serif;font-weight:650;font-size:32px}.controls,.scene-panel,.observe{background:var(--white);border-color:var(--line)}.workspace{grid-template-columns:310px minmax(0,1fr)}button,.button,select{background:#213129;color:var(--ink);border-color:#43584c}.segmented{background:#0d1511}.segmented .active{background:#2d493b}.primary{background:#238a62;border-color:#238a62}.mechanism{background:#17231d!important;border-color:#3d584a!important;box-shadow:0 12px 28px #0004}.readouts>div,.readouts button{border-color:var(--line)}.scene-footer{background:#111c16;border-color:var(--line)}.observe{padding-top:17px}.journal,footer{border-color:var(--line)}#stick{height:94px}.axis-line{top:47px}.minus,.plus{top:9px}#knob{top:23px}.stick-caption{margin-top:-10px;margin-bottom:10px}.scenario{margin-top:15px;padding-top:13px}.usb-learning{border-color:var(--line)!important}.trace-row{border-color:var(--line)}@media(max-width:650px){.workspace{grid-template-columns:1fr}.intro h1{font-size:26px}.controls{padding:15px}.mechanism{margin:0 0 14px!important;border-radius:10px!important}.mechanism svg{height:185px!important}.readouts{grid-template-columns:repeat(2,1fr)}.scene-label{display:none}}`;document.head.append(operatorStyle);}
let state={}, frames=[], after=0, epoch=-1, source='virtual', lever=0, m1Command=0, m2Command=0, held=0, usbArmed=false, center=0, m1Center=0, m2Center=0, frozen=false, hover=null, pending=false, editing=false, history=[];
let chosen=['position','velocity'], colors=['#2c7861','#b9874b','#7586aa','#8b7099'];
const names={position:['Position M3','m'],velocity:['Vitesse M3','m/s'],acceleration:['Accélération M3','m/s²'],motorForce:['Effort moteur M3','N'],brakeForce:['Effort de frein M3','N'],brake:['Serrage frein M3','0–1'],sensor:['Capteur M3','0/1'],energy:['Énergie cinétique M3','J'],overtravel:['Hors course M3','0/1'],m1Position:['Câble M1 retenue','m'],m1Speed:['Vitesse M1','m/s'],m2Position:['Câble M2 benne','m'],m2Speed:['Vitesse M2','m/s'],bucketDelta:['Delta M2−M1','m'],bucketOpening:['Ouverture benne','%'],bucketOpen:['Benne ouverte','0/1'],bucketClosed:['Benne fermée','0/1'],translationPermit:['Permis M3','0/1'],lever:['Commande M3','−1…1'],m1Command:['Commande M1','−1…1'],m2Command:['Commande M2','−1…1'],held:['Homme-mort','0/1']};
async function command(action,more={}){const r=await fetch('/command',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action,...more})});const d=await r.json();if(!r.ok)throw Error(d.error||'Commande refusée');return d;}
function report(e){$('error').hidden=false;$('error').textContent=e.message||String(e);}
function act(action,more={}){return command(action,more).catch(report);}
function release(){keys.clear();pointerHeld=false;dragging=false;lever=m1Command=m2Command=held=0;usbArmed=false;$('armUsb').textContent='Activer le joystick';updateStick();updateWinchControls();if(state.ready)act('input',{lever:0,m1Command:0,m2Command:0,held:0});}
function updateStick(){$('knob').style.left=`${50+lever*36}%`;$('lever').textContent=Math.round(lever*100)+' %';$('stick').setAttribute('aria-valuenow',Math.round(lever*100));$('deadman').classList.toggle('held',!!held);}
function selectSource(s){release();source=s;act('manual');$('virtual').classList.toggle('active',s==='virtual');$('usb').classList.toggle('active',s==='usb');$('virtualPanel').hidden=s!=='virtual';$('usbPanel').hidden=s!=='usb';}
$('virtual').onclick=()=>selectSource('virtual');$('usb').onclick=()=>selectSource('usb');
const winchPanel=document.createElement('section');
winchPanel.style.cssText='border-top:1px solid #dce3dc;margin-top:18px;padding-top:14px;';
const winchTitle=document.createElement('span');winchTitle.className='eyebrow';winchTitle.textContent='M1 / M2 — COMMANDE MANUELLE';winchPanel.append(winchTitle);
function makeWinchControl(id,label,setter){const row=document.createElement('label'),out=document.createElement('output'),input=document.createElement('input');row.style.cssText='display:block;margin-top:10px;font-size:12px;';row.textContent=label+' ';out.style.cssText='float:right;color:#245f4b;';input.type='range';input.min='-1';input.max='1';input.step='.01';input.value='0';input.style.cssText='display:block;width:100%;margin-top:7px;accent-color:#245f4b;';input.oninput=()=>{setter(Number(input.value));updateWinchControls();};row.append(out,input);winchPanel.append(row);return {input,out};}
const m1Control=makeWinchControl('m1','M1 retenue  ↓ dérouler / monter ↑',v=>m1Command=v);
const m2Control=makeWinchControl('m2','M2 benne  ↓ ouvrir / monter ↑ fermer',v=>m2Command=v);
const winchHint=document.createElement('p');winchHint.className='hint';winchHint.textContent='Même homme-mort que M3. M3 est interdit sous 6 m sur M1 ou M2.';winchPanel.append(winchHint);$('virtualPanel').append(winchPanel);
function updateWinchControls(){for(const [control,value] of [[m1Control,m1Command],[m2Control,m2Command]]){control.input.value=value;control.out.textContent=(value>0?'+':'')+Math.round(value*100)+' %';}}
updateWinchControls();
const mechanism=document.createElement('section');
mechanism.className='mechanism';mechanism.style.cssText='margin:4px 24px 20px;padding:14px 16px;border:1px solid #dce3dc;border-radius:10px;background:#f8faf5;';
mechanism.innerHTML=`<div style="display:flex;justify-content:space-between;gap:12px;align-items:baseline"><span class="eyebrow">MÉCANISME VIVANT · M1 / M2</span><strong id="bucketStateLive" style="font-size:12px">BENNE OUVERTE</strong></div><svg viewBox="0 0 800 250" role="img" aria-label="Schéma cinématique de la benne preneuse, ses câbles M1 et M2" style="width:100%;height:220px;display:block"><path d="M90 24H710" stroke="#557166" stroke-width="18"/><text x="110" y="18" font-size="10" fill="#697b70">PONT ROULANT / M3</text><path id="m1Ropes" stroke="#825e3c" stroke-width="5" fill="none"/><path id="m2Ropes" stroke="#245f4b" stroke-width="4" fill="none" stroke-dasharray="6 3"/><g id="grabHead"><rect x="-58" y="-12" width="116" height="24" rx="5" fill="#687c70"/><text x="0" y="5" text-anchor="middle" font-size="10" fill="white">TÊTE M1</text></g><g id="movingBlock"><rect x="-45" y="-10" width="90" height="20" rx="5" fill="#b87a43"/><text x="0" y="4" text-anchor="middle" font-size="9" fill="white">TRAVERSE M2</text></g><path id="jawLeft" fill="#bd8655" stroke="#704c2f" stroke-width="4"/><path id="jawRight" fill="#bd8655" stroke="#704c2f" stroke-width="4"/><path id="linkLeft" stroke="#687c70" stroke-width="8" fill="none"/><path id="linkRight" stroke="#687c70" stroke-width="8" fill="none"/><text id="m1Live" x="100" y="230" font-size="11" fill="#825e3c"></text><text id="m2Live" x="330" y="230" font-size="11" fill="#245f4b"></text><text id="deltaLive" x="555" y="230" font-size="11" fill="#4f6257"></text></svg><p style="margin:0;font-size:10px">Schéma cinématique d'étude : les dimensions visibles ne constituent pas un relevé de mouflage.</p>`;
document.querySelector('.intro').after(mechanism);
const mech=selector=>mechanism.querySelector(selector);
function renderMechanism(f){const m1=f.m1Position??8.5,m2=f.m2Position??8.5,delta=f.bucketDelta??0,opening=f.bucketOpening??100;const headY=Math.max(52,Math.min(142,58+(8.5-m1)*12));const blockY=Math.max(headY+22,Math.min(188,headY+30+Math.max(0,delta)*5));const half=24+opening*1.05;mech('#m1Ropes').setAttribute('d',`M270 32V${headY} M530 32V${headY}`);mech('#m2Ropes').setAttribute('d',`M360 32V${blockY} M440 32V${blockY}`);mech('#grabHead').setAttribute('transform',`translate(400 ${headY})`);mech('#movingBlock').setAttribute('transform',`translate(400 ${blockY})`);mech('#linkLeft').setAttribute('d',`M370 ${blockY+9} L${400-half} ${blockY+68}`);mech('#linkRight').setAttribute('d',`M430 ${blockY+9} L${400+half} ${blockY+68}`);mech('#jawLeft').setAttribute('d',`M${400-half} ${blockY+68} L${400-half-45} ${blockY+118} L400 ${blockY+140} L400 ${blockY+94} Z`);mech('#jawRight').setAttribute('d',`M${400+half} ${blockY+68} L${400+half+45} ${blockY+118} L400 ${blockY+140} L400 ${blockY+94} Z`);mech('#m1Live').textContent=`M1 retenue : ${m1.toFixed(2)} m`;mech('#m2Live').textContent=`M2 benne : ${m2.toFixed(2)} m`;mech('#deltaLive').textContent=`Δ M2−M1 : ${delta.toFixed(2)} m · ${opening.toFixed(0)} %`;mech('#bucketStateLive').textContent=f.bucketClosed?'BENNE FERMÉE':f.bucketOpen?'BENNE OUVERTE':'BENNE INTERMÉDIAIRE';}
renderMechanism({});
const renderBase=render;
render=()=>{if(state.ready&&state.modelSchema!==REQUIRED_MODEL_SCHEMA){releaseLocal();report('Serveur Atelier ancien : fermez-le (Ctrl+C), relancez Lancer_Atelier.bat, puis rechargez cette page.');}renderMechanism(state.last||{});return renderBase();};
let dragging=false, pointerHeld=false;
function moveStick(e){const r=$('stick').getBoundingClientRect();lever=Math.max(-1,Math.min(1,(e.clientX-r.left-r.width/2)/(r.width*.36)));updateStick();}
$('stick').onpointerdown=e=>{if(source!=='virtual'||state.scenario!=='manual')return;$('stick').focus();dragging=true;$('stick').setPointerCapture(e.pointerId);moveStick(e);};
$('stick').onpointermove=e=>{if(dragging)moveStick(e);};
function stopStick(){dragging=false;lever=(keys.has('ArrowRight')?1:0)-(keys.has('ArrowLeft')?1:0);updateStick();}
$('stick').onpointerup=stopStick;$('stick').onpointercancel=stopStick;$('stick').onlostpointercapture=stopStick;
$('deadman').onpointerdown=e=>{if(source!=='virtual'||state.scenario!=='manual')return;pointerHeld=true;held=1;$('deadman').setPointerCapture(e.pointerId);updateStick();};
for(const ev of ['pointerup','pointercancel','lostpointercapture'])$('deadman').addEventListener(ev,()=>{pointerHeld=false;held=keys.has('Space')?1:0;updateStick();});
const keys=new Set();
function keyCommand(e,down){
  if(!['ArrowLeft','ArrowRight','Space'].includes(e.code))return;
  if(down){
    if(source!=='virtual'||state.scenario!=='manual'||e.target.isContentEditable)return;
    const tag=e.target.tagName;
    if(['INPUT','SELECT','TEXTAREA'].includes(tag))return;
    if(tag==='BUTTON'&&e.target!==$('deadman'))return;
    keys.add(e.code);
  }else{if(!keys.has(e.code))return;keys.delete(e.code);}
  e.preventDefault();
  if(e.code!=='Space'&&!dragging)lever=(keys.has('ArrowRight')?1:0)-(keys.has('ArrowLeft')?1:0);
  held=(pointerHeld||keys.has('Space'))?1:0;
  updateStick();
}
window.addEventListener('keydown',e=>keyCommand(e,true));
window.addEventListener('keyup',e=>keyCommand(e,false));
window.addEventListener('blur',()=>{keys.clear();release();if(state.running)act('manual');});
document.addEventListener('visibilitychange',()=>{if(document.hidden){release();act('manual');}});
const DEFAULT_GAMEPAD_ID='standard gamepad vendor: 045e product: 0b22';
let selectedPad=null, deviceListSignature='', learning=null, deviceSelectionMode='automatic';
const deviceLabel=document.createElement('label'),deviceSelect=document.createElement('select');
deviceLabel.textContent='Périphérique ';deviceSelect.id='deviceSelect';deviceSelect.setAttribute('aria-label','Joystick à piloter');deviceLabel.append(deviceSelect);$('usbPanel').prepend(deviceLabel);
function makeUsbAxis(label){const row=document.createElement('label'),input=document.createElement('input');row.textContent=label;input.type='number';input.min='-1';input.max='15';input.value='-1';input.style.cssText='width:55px;float:right;';row.append(input);$('usbPanel').prepend(row);return input;}
const m1AxisInput=makeUsbAxis('Axe M1 retenue (−1 = neutre) '),m2AxisInput=makeUsbAxis('Axe M2 benne (−1 = neutre) ');
for(const input of [m1AxisInput,m2AxisInput])input.onchange=()=>{release();saveProfile();};
const usbLearning=document.createElement('section');
usbLearning.className='usb-learning';usbLearning.style.cssText='border-top:1px solid #dce3dc;margin-top:16px;padding-top:14px;';usbLearning.setAttribute('aria-label','Apprentissage du joystick');
const usbLearningTitle=document.createElement('strong'),usbLearningText=document.createElement('p'),axisTarget=document.createElement('select'),learnAxis=document.createElement('button'),learnDeadman=document.createElement('button'),usbLive=document.createElement('div');
usbLearningTitle.textContent='Apprentissage';usbLearningText.className='hint';usbLearningText.textContent='Sélectionnez un périphérique pour visualiser ses entrées.';
axisTarget.innerHTML='<option value="m3">Axe à apprendre : M3</option><option value="m1">Axe à apprendre : M1</option><option value="m2">Axe à apprendre : M2</option>';axisTarget.style.cssText='display:block;width:100%;margin-top:9px;';learnAxis.type=learnDeadman.type='button';learnAxis.textContent='Apprendre l’axe';learnDeadman.textContent='Apprendre l’homme-mort';usbLive.className='usb-live';usbLive.style.cssText='display:grid;gap:4px;margin-top:12px;font:10px ui-monospace,Consolas,monospace;color:#52655a;';
usbLearning.append(usbLearningTitle,usbLearningText,axisTarget,learnAxis,learnDeadman,usbLive);$('usbPanel').append(usbLearning);
function devices(){return Array.from(navigator.getGamepads?.()||[]).filter(p=>p&&p.connected!==false);}
function pad(){return selectedPad?devices().find(p=>p.index===selectedPad.index&&p.id===selectedPad.id):undefined;}
function preferredPad(list){return list.find(p=>p.id.toLowerCase().includes(DEFAULT_GAMEPAD_ID));}
function showUsbInputs(p){
  usbLive.replaceChildren();
  if(!p)return;
  for(let i=0;i<p.axes.length;i++){const item=document.createElement('div'),bar=document.createElement('i');item.className='usb-axis';bar.style.cssText=`display:inline-block;height:4px;margin-left:8px;background:#245f4b;width:${Math.abs(p.axes[i])*100}%;`;item.append(document.createTextNode(`A${i}  ${p.axes[i].toFixed(2)}`),bar);usbLive.append(item);}
  const buttons=document.createElement('div');buttons.className='usb-buttons';for(let i=0;i<p.buttons.length;i++){const b=document.createElement('span');b.className=p.buttons[i].pressed?'down':'';b.textContent=`B${i}`;buttons.append(b);}usbLive.append(buttons);
}
function stopLearning(message){learning=null;usbLearningText.textContent=message;}
learnAxis.onclick=()=>{const p=pad();if(!p)return;learning={kind:'axis',target:axisTarget.value,baseline:p.axes.slice()};usbLearningText.textContent='Bougez nettement l’axe à commander. La première variation significative sera retenue.';};
learnDeadman.onclick=()=>{const p=pad();if(!p)return;learning={kind:'button',baseline:p.buttons.map(b=>!!b.pressed)};usbLearningText.textContent='Appuyez une fois sur le bouton homme-mort à retenir.';};
function learnFrom(p){
  if(!learning)return;
  if(learning.kind==='axis'){const i=p.axes.findIndex((v,n)=>Math.abs(v-learning.baseline[n])>.35);if(i>=0){const target=learning.target;const input=target==='m3'?$('axisIndex'):target==='m1'?m1AxisInput:m2AxisInput;input.value=i;if(target==='m3')center=0;else if(target==='m1')m1Center=0;else m2Center=0;release();saveProfile();stopLearning(`Axe A${i} retenu pour ${target.toUpperCase()}. Relâchez-le puis cliquez « Calibrer le neutre ».`);}}
  else {const i=p.buttons.findIndex((b,n)=>b.pressed&&!learning.baseline[n]);if(i>=0){$('buttonIndex').value=i;release();stopLearning(`Bouton B${i} retenu pour l’homme-mort.`);}}
}
function refreshDevices(){
  const list=devices();
  if(selectedPad&&!pad()){release();selectedPad=null;}
  if(!selectedPad&&deviceSelectionMode==='automatic'){const preferred=preferredPad(list);if(preferred)selectedPad={index:preferred.index,id:preferred.id};}
  const signature=JSON.stringify(list.map(p=>[p.index,p.id]));
  if(signature!==deviceListSignature){
    deviceListSignature=signature;deviceSelect.replaceChildren();
    const prompt=document.createElement('option');prompt.value='';prompt.textContent='Choisir un joystick…';deviceSelect.append(prompt);
    for(const p of list){const o=document.createElement('option');o.value=String(p.index);o.textContent=`${p.id} · entrée ${p.index}`;deviceSelect.append(o);}
  }
  deviceSelect.value=selectedPad?String(selectedPad.index):'';
  $('armUsb').disabled=!pad();$('calibrate').disabled=!pad();
  if(pad()&&deviceSelectionMode==='automatic')usbLearningText.textContent='Contrôleur HID préféré sélectionné. Vérifiez les entrées, puis activez volontairement le joystick.';
}
deviceSelect.onchange=()=>{release();learning=null;deviceSelectionMode='manual';const p=devices().find(p=>String(p.index)===deviceSelect.value);selectedPad=p?{index:p.index,id:p.id}:null;center=0;usbLearningText.textContent=p?'Entrées visibles en direct. Utilisez les boutons d’apprentissage, ou renseignez les numéros à la main.':'Sélectionnez un périphérique pour visualiser ses entrées.';refreshDevices();};
window.addEventListener('gamepadconnected',refreshDevices);
window.addEventListener('gamepaddisconnected',e=>{if(selectedPad?.index===e.gamepad.index){release();selectedPad=null;}refreshDevices();});
function axisValue(p,index,axisCenter,invert=false){const i=Number(index);if(i<0)return 0;const a=p.axes[i]??0,dz=Number($('deadzone').value);let n=(a-axisCenter)/Math.max(.05,a>=axisCenter?1-axisCenter:1+axisCenter);n=Math.abs(n)<dz?0:Math.sign(n)*(Math.abs(n)-dz)/(1-dz);return Math.max(-1,Math.min(1,n))*(invert?-1:1);}
function usbInput(){refreshDevices();const p=pad();$('usbStatus').textContent=p?`${p.id} · ${p.axes.length} axes · ${p.buttons.length} boutons`:'Choisissez votre joystick · appuyez sur un bouton physique pour le détecter';showUsbInputs(p);learnFrom(p);if(!p||!usbArmed){lever=m1Command=m2Command=held=0;return;}lever=axisValue(p,$('axisIndex').value,center,$('invert').checked);m1Command=axisValue(p,m1AxisInput.value,m1Center);m2Command=axisValue(p,m2AxisInput.value,m2Center);held=p.buttons[Number($('buttonIndex').value)]?.pressed?1:0;}
$('calibrate').onclick=()=>{const p=pad();if(!p)return;center=p.axes[Number($('axisIndex').value)]??0;m1Center=p.axes[Number(m1AxisInput.value)]??0;m2Center=p.axes[Number(m2AxisInput.value)]??0;release();saveProfile();};
$('armUsb').onclick=()=>{if(!pad()){release();return;}usbArmed=!usbArmed;$('armUsb').textContent=usbArmed?'Désactiver le joystick':'Activer le joystick';if(!usbArmed)release();};
function saveProfile(){try{localStorage.setItem('atelier-usb',JSON.stringify({center,m1Center,m2Center,axis:$('axisIndex').value,m1Axis:m1AxisInput.value,m2Axis:m2AxisInput.value,button:$('buttonIndex').value,dz:$('deadzone').value,invert:$('invert').checked}));}catch{}}
for(const id of ['axisIndex','buttonIndex','deadzone','invert'])$(id).onchange=()=>{release();saveProfile();};
try{const p=JSON.parse(localStorage.getItem('atelier-usb')||'null');if(p){center=p.center||0;m1Center=p.m1Center||0;m2Center=p.m2Center||0;$('axisIndex').value=p.axis;m1AxisInput.value=p.m1Axis??-1;m2AxisInput.value=p.m2Axis??-1;$('buttonIndex').value=p.button;$('deadzone').value=p.dz;$('invert').checked=p.invert;}}catch{}
$('play').onclick=()=>{release();act(state.running?'pause':'play');};
$('reset').onclick=()=>{release();act('reset');};
document.querySelectorAll('[data-scenario]').forEach(b=>b.onclick=()=>{release();act('scenario',{name:b.dataset.scenario});});
$('manual').onclick=()=>{release();act('manual');};
$('editToggle').onclick=()=>{editing=!editing;$('editor').hidden=!editing;$('editToggle').textContent=editing?'✓ Fermer les réglages':'✎ Modifier la machine';};
const units={mass:'kg',forceLimit:'N',brakeDelay:'s',sensorPosition:'m'};
function syncParams(){for(const k in units){if(document.activeElement!==$(k))$(k).value=state.config?.[k]??$(k).value;$(k+'Out').textContent=Number($(k).value).toLocaleString('fr-FR')+' '+units[k];}}
for(const k in units){$(k).oninput=()=>{$(k+'Out').textContent=Number($(k).value).toLocaleString('fr-FR')+' '+units[k];if(k==='sensorPosition')paintSensor(Number($(k).value));};$(k).onchange=()=>{history.push({...state.config});act('edit',{params:{[k]:Number($(k).value)}});};}
$('undo').onclick=()=>{const prev=history.pop();if(prev)act('edit',{params:prev});};
const NS='http://www.w3.org/2000/svg';
for(let m=0;m<=30;m+=5){const x=70+m/30*760;const t=document.createElementNS(NS,'text');t.setAttribute('x',x);t.setAttribute('y',264);t.setAttribute('text-anchor','middle');t.setAttribute('fill','#8b998b');t.setAttribute('font-size','10');t.textContent=m+' m';$('ticks').append(t);}
function paintSensor(p){$('sensorMarker').setAttribute('transform',`translate(${70+p/30*760},0)`);$('sensorLabel').textContent='CAPTEUR · '+p.toFixed(1)+' m';}
let sensorDrag=false,sensorPreview=21;
function sensorMove(e){const pt=$('scene').createSVGPoint();pt.x=e.clientX;pt.y=e.clientY;const p=pt.matrixTransform($('scene').getScreenCTM().inverse());sensorPreview=Math.round(Math.max(1,Math.min(29,(p.x-70)/760*30))*10)/10;paintSensor(sensorPreview);$('sensorPosition').value=sensorPreview;$('sensorPositionOut').textContent=sensorPreview+' m';}
$('sensorMarker').onpointerdown=e=>{if(!editing){$('editToggle').click();return;}sensorDrag=true;$('sensorMarker').setPointerCapture(e.pointerId);sensorMove(e);};
$('sensorMarker').onpointermove=e=>{if(sensorDrag)sensorMove(e);};
$('sensorMarker').onpointerup=()=>{if(sensorDrag){sensorDrag=false;history.push({...state.config});act('edit',{params:{sensorPosition:sensorPreview}});}};
$('sensorMarker').onpointercancel=()=>{sensorDrag=false;};
$('sensorMarker').onkeydown=e=>{if(e.key==='Enter')$('editToggle').click();};
function render(){const f=state.last||{};$('play').disabled=!state.ready||!!state.error;$('play').textContent=state.running?'Ⅱ Pause':'▶ Démarrer';$('led').classList.toggle('ready',state.ready&&!state.error);$('engine').textContent=state.error?'Moteur indisponible':state.ready?'Modelica · moteur natif':'Compilation du modèle…';if(state.error)report(state.error);$('sourceBadge').textContent=state.scenario!=='manual'?'SCÉNARIO':source==='usb'?'USB':'MANUEL';$('manual').hidden=state.scenario==='manual';$('clock').innerHTML=(f.t||0).toFixed(2)+' <em>s</em>';$('pos').innerHTML=(f.position??12).toFixed(2)+' <em>m</em>';$('vel').innerHTML=(f.velocity||0).toFixed(2)+' <em>m/s</em>';$('brakeState').textContent=(f.brake??1)>.95?'Serré':f.brake<.05?'Libéré':'Transition';$('carriage').setAttribute('transform',`translate(${70+(f.position??12)/30*760},207)`);$('sensorLight').setAttribute('fill',f.sensor?'#42a578':'#bfa88e');if(!sensorDrag)paintSensor(state.config?.sensorPosition??21);$('sceneStatus').textContent=f.overtravel?'⚠ Hors course — aucune butée physique modélisée':state.running?'Expérience en cours · '+(f.held?'homme-mort actif':'commande relâchée'): 'En pause · vous pouvez préparer votre expérience';$('perf').textContent='Calcul : '+(state.stepMs||0).toFixed(1)+' ms / pas de 20 ms';syncParams();$('events').replaceChildren();for(const e of (state.events||[]).slice(-7).reverse()){const line=document.createElement('div'),t=document.createElement('time');t.textContent=e.t.toFixed(2)+' s';line.append(t,document.createTextNode(e.text));$('events').append(line);}if(!frozen)drawTraces();}
for(const [k,[name,u]]of Object.entries(names)){const o=document.createElement('option');o.value=k;o.textContent=`${name} · ${u}`;$('signal').append(o);}
function buildTraces(){$('traces').replaceChildren();chosen.forEach((key,i)=>{const row=document.createElement('div');row.className='trace-row';row.innerHTML=`<div class="trace-info"><button aria-label="Retirer ${names[key][0]}">×</button><strong>${names[key][0]}</strong><span class="value" style="color:${colors[i%colors.length]}">—</span><span class="unit">${names[key][1]}</span></div><canvas aria-label="Courbe ${names[key][0]}"></canvas>`;row.querySelector('button').onclick=()=>{chosen=chosen.filter(x=>x!==key);buildTraces();};const c=row.querySelector('canvas');c.onpointermove=e=>{const r=c.getBoundingClientRect();hover=(e.clientX-r.left)/r.width;drawTraces();};c.onpointerleave=()=>{hover=null;drawTraces();};$('traces').append(row);});drawTraces();}
let frozenFrames=[];
function drawTraces(){const all=frozen?frozenFrames:frames;const end=all.at(-1)?.t||20,start=Math.max(0,end-20),data=all.filter(f=>f.t>=start);document.querySelectorAll('.trace-row').forEach((row,i)=>{const key=chosen[i],c=row.querySelector('canvas'),r=c.getBoundingClientRect(),dpr=devicePixelRatio||1;c.width=Math.max(1,r.width*dpr);c.height=78*dpr;const ctx=c.getContext('2d');ctx.scale(dpr,dpr);const w=r.width,h=78;let vals=data.map(f=>f[key]),lo=Math.min(0,...vals),hi=Math.max(1,...vals);const binary=['sensor','held','overtravel'].includes(key);const pad=(hi-lo)*.15;lo-=pad;hi+=pad;const x=t=>(t-start)/Math.max(20,end-start)*w,y=v=>h-9-(v-lo)/(hi-lo)*(h-18);ctx.strokeStyle='#e6eae3';ctx.lineWidth=1;for(let n=0;n<=4;n++){ctx.beginPath();ctx.moveTo(n*w/4,0);ctx.lineTo(n*w/4,h);ctx.stroke();}ctx.fillStyle='#96a093';ctx.font='9px Segoe UI';ctx.fillText(hi.toFixed(1),3,10);ctx.fillText(start.toFixed(0)+' s',3,h-1);ctx.fillText(end.toFixed(0)+' s',w-30,h-1);ctx.strokeStyle=colors[i%colors.length];ctx.lineWidth=1.6;ctx.beginPath();data.forEach((f,j)=>{if(j===0)ctx.moveTo(x(f.t),y(f[key]));else{if(binary)ctx.lineTo(x(f.t),y(data[j-1][key]));ctx.lineTo(x(f.t),y(f[key]));}});ctx.stroke();let sample=data.at(-1);if(hover!==null&&data.length){const t=start+hover*20;sample=data.reduce((a,b)=>Math.abs(b.t-t)<Math.abs(a.t-t)?b:a);ctx.strokeStyle='#60756655';ctx.beginPath();ctx.moveTo(x(sample.t),0);ctx.lineTo(x(sample.t),h);ctx.stroke();}row.querySelector('.value').textContent=sample?sample[key].toFixed(binary?0:2):'—';});}
$('addTrace').onclick=()=>{const k=$('signal').value;if(!chosen.includes(k)){chosen.push(k);buildTraces();}};
document.querySelectorAll('[data-trace]').forEach(b=>b.onclick=()=>{const k=b.dataset.trace;if(!chosen.includes(k)){chosen.push(k);buildTraces();}document.querySelector('.observe').scrollIntoView({behavior:'smooth',block:'nearest'});});
$('preset').onchange=()=>{chosen={motion:['position','velocity'],braking:['velocity','brake','held'],forces:['motorForce','brakeForce','energy']}[$('preset').value];buildTraces();};
$('freeze').onclick=()=>{frozen=!frozen;frozenFrames=frames.slice();$('freeze').textContent=frozen?'Revenir au direct':'Figer les courbes';drawTraces();};
window.addEventListener('resize',drawTraces);buildTraces();paintSensor(21);render();
async function poll(){if(pending)return;pending=true;try{if(source==='usb')usbInput();if(state.ready&&!state.error&&!document.hidden)await command('input',{lever,m1Command,m2Command,held});const r=await fetch('/state?after='+after);if(!r.ok)throw Error('Connexion au serveur perdue');const next=await r.json();if(next.epoch!==epoch){frames=[];after=0;epoch=next.epoch;}state=next;for(const f of next.frames){if(f.seq>after){frames.push(f);after=f.seq;}}if(frames.length>15000)frames=frames.slice(-15000);render();}catch(e){releaseLocal();report(e);}finally{pending=false;setTimeout(poll,100);}}
function releaseLocal(){keys.clear();pointerHeld=false;dragging=false;lever=m1Command=m2Command=held=0;usbArmed=false;updateStick();updateWinchControls();}
poll();
