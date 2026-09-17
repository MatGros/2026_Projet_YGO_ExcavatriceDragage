const $ = id => document.getElementById(id);
const SVG_NS = 'http://www.w3.org/2000/svg';
const colors = ['#63d5ac', '#f0ba68', '#61aef2', '#e67f83', '#b893ed', '#51c4d3', '#e59454', '#92c66c'];

const defaultProfile = {
  deviceId: '', axes: {m3: 0, m1: 1, m2: 2}, deadmanButton: 0,
  neutral: {m3: 0, m1: 0, m2: 0}, deadzone: 0.12
};
const state = {
  ready: false, frames: [], seq: 0, epoch: null, zoom: 1, catalog: [],
  chartKeys: JSON.parse(localStorage.getItem('twinbench-traces') || 'null') ||
    ['positionM', 'm1CablePositionM', 'm2CablePositionM', 'bucketOpeningPct'],
  layout: JSON.parse(localStorage.getItem('twinbench-layout') || 'null') ||
    {trolley: [0, 0], winches: [0, 0], bucket: [0, 0]},
  edit: false, pressed: {m3: 0, m1: 0, m2: 0}, keys: new Set(),
  pointerDeadman: false, gamepadIndex: null, gamepadArmed: false,
  gamepadProfile: {...defaultProfile, ...(JSON.parse(localStorage.getItem('twinbench-gamepad') || 'null') || {})},
  learnTarget: null, learnBaseline: [], lastGamepadSend: 0, configLoaded: false
};

async function post(payload) {
  try {
    const response = await fetch('/command', {
      method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(payload)
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
    return data;
  } catch (error) {
    showError(error.message);
    throw error;
  }
}

function showError(message = '') {
  $('error').hidden = !message;
  $('error').textContent = message;
}

function log(message) {
  const line = document.createElement('div');
  line.textContent = message;
  $('eventLog').prepend(line);
  while ($('eventLog').children.length > 12) $('eventLog').lastChild.remove();
}

function deadmanHeld() {
  const pad = selectedGamepad();
  const gamepadHeld = state.gamepadArmed && !!pad?.buttons?.[state.gamepadProfile.deadmanButton]?.pressed;
  return state.pointerDeadman || state.keys.has('Space') || gamepadHeld;
}

function updateDeadmanUi() {
  const held = deadmanHeld();
  $('deadman').classList.toggle('held', held);
  $('deadmanLamp').classList.toggle('on', held);
  return held;
}

function axisDirection(axis) {
  if (state.gamepadArmed) {
    const pad = selectedGamepad();
    if (!pad) return 0;
    const index = state.gamepadProfile.axes[axis];
    const raw = pad.axes[index] ?? 0;
    const neutral = state.gamepadProfile.neutral[axis] ?? 0;
    const value = Math.max(-1, Math.min(1, raw - neutral));
    return Math.abs(value) < state.gamepadProfile.deadzone ? 0 : Math.sign(value);
  }
  let value = state.pressed[axis] || 0;
  const keyboard = {
    m3: (state.keys.has('ArrowRight') ? 1 : 0) - (state.keys.has('ArrowLeft') ? 1 : 0),
    m1: (state.keys.has('KeyD') ? 1 : 0) - (state.keys.has('KeyA') ? 1 : 0),
    m2: (state.keys.has('ArrowUp') ? 1 : 0) - (state.keys.has('ArrowDown') ? 1 : 0)
  };
  return keyboard[axis] || value;
}

function commandSnapshot() {
  return {
    action: 'input', m3: axisDirection('m3'), m1: axisDirection('m1'), m2: axisDirection('m2'),
    speed: +$('speed').value, held: updateDeadmanUi()
  };
}

function sendControl() {
  if (state.ready) post(commandSnapshot()).catch(() => {});
}

document.querySelectorAll('[data-axis]').forEach(button => {
  const axis = button.dataset.axis;
  const direction = +button.dataset.dir;
  const press = event => {
    event.preventDefault();
    state.pressed[axis] = direction;
    button.classList.add('active');
    sendControl();
  };
  const release = () => {
    if (state.pressed[axis] === direction) state.pressed[axis] = 0;
    button.classList.remove('active');
    sendControl();
  };
  button.addEventListener('pointerdown', press);
  ['pointerup', 'pointercancel', 'pointerleave'].forEach(name => button.addEventListener(name, release));
});

$('deadman').addEventListener('pointerdown', event => { event.preventDefault(); state.pointerDeadman = true; sendControl(); });
['pointerup', 'pointercancel', 'pointerleave'].forEach(name => $('deadman').addEventListener(name, () => {
  state.pointerDeadman = false; sendControl();
}));

const keyCodes = new Set(['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'KeyA', 'KeyD', 'Space']);
window.addEventListener('keydown', event => {
  if (event.target.matches('input, select, button')) return;
  if (keyCodes.has(event.code)) { event.preventDefault(); state.keys.add(event.code); }
});
window.addEventListener('keyup', event => {
  if (keyCodes.has(event.code)) { state.keys.delete(event.code); sendControl(); }
});

function neutralizeLocal(reason) {
  state.pressed = {m3: 0, m1: 0, m2: 0};
  state.keys.clear();
  state.pointerDeadman = false;
  state.gamepadArmed = false;
  updateGamepadStatus();
  updateDeadmanUi();
  if (state.ready) post({action: 'input', m3: 0, m1: 0, m2: 0, speed: +$('speed').value, held: false}).catch(() => {});
  if (reason) log(reason);
}
window.addEventListener('blur', () => neutralizeLocal('Perte de focus · joystick désarmé'));
document.addEventListener('visibilitychange', () => { if (document.hidden) neutralizeLocal('Onglet masqué · commandes neutralisées'); });

$('speed').addEventListener('input', event => $('speedValue').textContent = `${event.target.value} %`);
$('play').onclick = () => post({action: 'play'}).catch(() => {});
$('pause').onclick = () => { neutralizeLocal(); post({action: 'pause'}).catch(() => {}); };
$('reset').onclick = () => post({action: 'reset'}).catch(() => {});
$('grab').onclick = () => post({action: 'scenario', name: 'grab'}).catch(() => {});

function render(frame, snapshot) {
  $('position').textContent = (+frame.positionM || 0).toFixed(2);
  $('cables').textContent = `${(+frame.m1CablePositionM || 0).toFixed(2)} / ${(+frame.m2CablePositionM || 0).toFixed(2)}`;
  $('opening').textContent = (+frame.bucketOpeningPct || 0).toFixed(1);
  $('frequency').textContent = (+frame.actualFrequencyHz || 0).toFixed(1);
  $('brakes').textContent = `${(+frame.m1BrakeIsOpenDI || 0).toFixed(0)} / ${(+frame.m2BrakeIsOpenDI || 0).toFixed(0)}`;
  $('stepMs').textContent = (+snapshot.stepMs || 0).toFixed(2);
  $('phase').textContent = snapshot.scenarioPhase || (snapshot.running ? 'Conduite manuelle' : 'En pause');
  $('mode').textContent = snapshot.scenario === 'grab' ? 'SCÉNARIO' : state.edit ? 'ÉDITION' : 'MANUEL';
  renderScene(frame, snapshot.config);
  fillSignalTable(frame);
}

function renderScene(frame, config) {
  const travel = Math.max(1, +config.travelM || 30);
  const x = 90 + Math.max(0, Math.min(travel, +frame.positionM || 0)) / travel * 720;
  const meanCable = ((+frame.m1CablePositionM || 0) + (+frame.m2CablePositionM || 0)) / 2;
  const bucketY = Math.max(205, Math.min(350, 270 + meanCable * 4));
  const opening = Math.max(0, Math.min(100, +frame.bucketOpeningPct || 0));
  const spread = opening / 100 * 28;
  const [tx, ty] = state.layout.trolley;
  const [wx, wy] = state.layout.winches;
  const [bx, by] = state.layout.bucket;
  $('trolley').setAttribute('transform', `translate(${x + tx} ${ty})`);
  $('winches').setAttribute('transform', `translate(${x + wx} ${wy})`);
  $('bucket').setAttribute('transform', `translate(${x + bx} ${bucketY + by})`);
  $('cableM1').setAttribute('y2', bucketY - wy - 2);
  $('cableM2').setAttribute('y2', bucketY - wy - 2);
  $('leftJaw').setAttribute('transform', `translate(${-spread} 0)`);
  $('leftTeeth').setAttribute('transform', `translate(${-spread} 0)`);
  $('rightJaw').setAttribute('transform', `translate(${spread} 0)`);
  $('rightTeeth').setAttribute('transform', `translate(${spread} 0)`);
  $('positionLabel').setAttribute('x', x);
  $('positionLabel').textContent = `M3 ${(+frame.positionM || 0).toFixed(1)} m`;
}

let drag = null;
$('edit').onclick = () => {
  state.edit = !state.edit;
  $('edit').classList.toggle('active', state.edit);
  $('editHint').setAttribute('visibility', state.edit ? 'visible' : 'hidden');
  document.querySelectorAll('.editable').forEach(element => element.classList.toggle('editing', state.edit));
};
$('save').onclick = () => { localStorage.setItem('twinbench-layout', JSON.stringify(state.layout)); log('Disposition de vue enregistrée'); };
$('resetLayout').onclick = () => { state.layout = {trolley: [0, 0], winches: [0, 0], bucket: [0, 0]}; localStorage.removeItem('twinbench-layout'); };
document.querySelectorAll('.editable').forEach(element => {
  element.addEventListener('pointerdown', event => {
    if (!state.edit) return;
    drag = {id: element.id, x: event.clientX, y: event.clientY, start: [...state.layout[element.id]]};
    element.setPointerCapture(event.pointerId);
  });
  element.addEventListener('pointermove', event => {
    if (!drag || drag.id !== element.id) return;
    const rect = $('scene').getBoundingClientRect();
    state.layout[element.id] = [drag.start[0] + (event.clientX - drag.x) * 900 / rect.width,
      drag.start[1] + (event.clientY - drag.y) * 470 / rect.height];
    if (state.frames.length) renderScene(state.frames.at(-1), currentConfig());
  });
  element.addEventListener('pointerup', () => { drag = null; });
});

function setupCatalog(catalog) {
  state.catalog = catalog;
  const picker = $('tracePicker');
  picker.innerHTML = '';
  catalog.forEach((signal, index) => {
    const label = document.createElement('label');
    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox'; checkbox.value = signal.key; checkbox.checked = state.chartKeys.includes(signal.key);
    checkbox.addEventListener('change', () => {
      state.chartKeys = [...picker.querySelectorAll('input:checked')].map(input => input.value);
      if (!state.chartKeys.length) { checkbox.checked = true; state.chartKeys = [signal.key]; }
      localStorage.setItem('twinbench-traces', JSON.stringify(state.chartKeys)); drawChart();
    });
    const dot = document.createElement('i'); dot.style.background = colors[index % colors.length];
    label.append(checkbox, dot, document.createTextNode(`${signal.label} · ${signal.unit}`));
    picker.append(label);
  });
}

function fillSignalTable(frame) {
  const query = $('signalFilter').value.trim().toLowerCase();
  const role = $('roleFilter').value;
  const table = $('signalTable');
  table.innerHTML = '';
  state.catalog.filter(signal => (!role || signal.role === role) &&
    (!query || `${signal.key} ${signal.label} ${signal.group}`.toLowerCase().includes(query))).forEach(signal => {
      const cell = document.createElement('button');
      cell.className = `signal-cell role-${signal.role}`;
      const value = Number.isFinite(+frame[signal.key]) ? formatValue(+frame[signal.key]) : '—';
      cell.innerHTML = `<span><em>${signal.role.toUpperCase()}</em>${signal.group} · ${signal.label}<small>${signal.key}</small></span><b>${value}<small>${signal.unit}</small></b>`;
      cell.title = 'Cliquer pour ajouter ou retirer du chronogramme';
      cell.onclick = () => toggleTrace(signal.key);
      table.append(cell);
    });
}
function formatValue(value) { return Math.abs(value) >= 100 ? value.toFixed(0) : value.toFixed(3); }
function toggleTrace(key) {
  const checkbox = [...$('tracePicker').querySelectorAll('input')].find(input => input.value === key);
  if (!checkbox) return;
  checkbox.checked = !checkbox.checked; checkbox.dispatchEvent(new Event('change'));
}
$('signalFilter').addEventListener('input', () => fillSignalTable(state.frames.at(-1) || {}));
$('roleFilter').addEventListener('change', () => fillSignalTable(state.frames.at(-1) || {}));

function visibleFrames() {
  const count = Math.max(40, Math.floor(1800 / state.zoom));
  return state.frames.slice(-count);
}
function drawChart() {
  const data = visibleFrames();
  if (data.length < 2) return;
  const width = 1200, height = 340, left = 55, right = 20, top = 20, bottom = 30;
  $('chartGrid').innerHTML = ''; $('chartLines').innerHTML = ''; $('chartLegend').innerHTML = '';
  for (let i = 0; i < 6; i++) {
    const y = top + i * (height - top - bottom) / 5;
    const line = document.createElementNS(SVG_NS, 'line');
    line.setAttribute('x1', left); line.setAttribute('x2', width - right); line.setAttribute('y1', y); line.setAttribute('y2', y); line.classList.add('chart-grid');
    $('chartGrid').append(line);
  }
  const t0 = data[0].t, t1 = data.at(-1).t;
  state.chartKeys.forEach((key, seriesIndex) => {
    const signal = state.catalog.find(item => item.key === key);
    if (!signal) return;
    const values = data.map(frame => +frame[key]).filter(Number.isFinite);
    if (!values.length) return;
    const low = Math.min(...values), high = Math.max(...values), padding = (high - low || 1) * 0.08;
    const path = document.createElementNS(SVG_NS, 'path');
    let definition = '';
    data.forEach((frame, index) => {
      const value = +frame[key]; if (!Number.isFinite(value)) return;
      const x = left + (frame.t - t0) / (t1 - t0 || 1) * (width - left - right);
      const y = top + (high + padding - value) / (high - low + 2 * padding) * (height - top - bottom);
      definition += `${index ? 'L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`;
    });
    path.setAttribute('d', definition); path.style.stroke = colors[seriesIndex % colors.length]; path.classList.add('chart-line');
    $('chartLines').append(path);
    const legend = document.createElement('span');
    legend.innerHTML = `<i style="background:${colors[seriesIndex % colors.length]}"></i>${signal.label} <small>${low.toFixed(2)}…${high.toFixed(2)} ${signal.unit}</small>`;
    $('chartLegend').append(legend);
  });
  const axis = document.createElementNS(SVG_NS, 'text');
  axis.setAttribute('x', left); axis.setAttribute('y', height - 7); axis.classList.add('chart-axis');
  axis.textContent = `${t0.toFixed(2)} s → ${t1.toFixed(2)} s`;
  $('chartGrid').append(axis);
}

function chartPointer(event) {
  const data = visibleFrames(); if (!data.length) return;
  const rect = $('chart').getBoundingClientRect();
  const ratio = Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width));
  const x = ratio * 1200; $('cursor').setAttribute('x1', x); $('cursor').setAttribute('x2', x); $('cursor').setAttribute('visibility', 'visible');
  const target = data[0].t + ratio * (data.at(-1).t - data[0].t);
  const frame = data.reduce((a, b) => Math.abs(b.t - target) < Math.abs(a.t - target) ? b : a);
  const lines = [`t = ${frame.t.toFixed(2)} s`];
  state.chartKeys.forEach(key => { const signal = state.catalog.find(item => item.key === key); if (signal) lines.push(`${signal.label}: ${formatValue(+frame[key] || 0)} ${signal.unit}`); });
  $('chartTooltip').textContent = lines.join('\n'); $('chartTooltip').hidden = false;
}
$('chart').addEventListener('pointermove', chartPointer);
$('chart').addEventListener('pointerleave', () => { $('cursor').setAttribute('visibility', 'hidden'); $('chartTooltip').hidden = true; });
$('zoomIn').onclick = () => { state.zoom = Math.min(12, state.zoom * 1.6); drawChart(); };
$('zoomOut').onclick = () => { state.zoom = Math.max(0.35, state.zoom / 1.6); drawChart(); };
$('zoomReset').onclick = () => { state.zoom = 1; drawChart(); };

function selectedGamepad() {
  if (state.gamepadIndex === null || !navigator.getGamepads) return null;
  return navigator.getGamepads()[state.gamepadIndex] || null;
}
function saveGamepadProfile() { localStorage.setItem('twinbench-gamepad', JSON.stringify(state.gamepadProfile)); }
function fillMapping(select, count, prefix, value) {
  const old = String(value);
  select.innerHTML = '';
  for (let i = 0; i < count; i++) select.add(new Option(`${prefix}${i}`, String(i)));
  select.value = old;
}
function configureMappingUi(pad) {
  fillMapping($('mapM3'), pad?.axes.length || 8, 'A', state.gamepadProfile.axes.m3);
  fillMapping($('mapM1'), pad?.axes.length || 8, 'A', state.gamepadProfile.axes.m1);
  fillMapping($('mapM2'), pad?.axes.length || 8, 'A', state.gamepadProfile.axes.m2);
  fillMapping($('mapDeadman'), pad?.buttons.length || 16, 'B', state.gamepadProfile.deadmanButton);
}
function refreshGamepads() {
  if (!navigator.getGamepads) return;
  const pads = [...navigator.getGamepads()].filter(Boolean);
  const select = $('gamepadSelect');
  const previousIndex = state.gamepadIndex;
  select.innerHTML = '<option value="">Sélectionner un périphérique…</option>';
  pads.forEach(pad => select.add(new Option(`${pad.id} · entrée ${pad.index + 1}`, String(pad.index))));
  let chosen = pads.find(pad => pad.index === previousIndex);
  if (!chosen && state.gamepadProfile.deviceId) chosen = pads.find(pad => pad.id === state.gamepadProfile.deviceId);
  if (!chosen) chosen = pads.find(pad => /045e.*0b22|STANDARD GAMEPAD/i.test(pad.id));
  if (chosen) {
    state.gamepadIndex = chosen.index; select.value = String(chosen.index);
    if (previousIndex !== chosen.index) configureMappingUi(chosen);
  } else {
    if (state.gamepadArmed) neutralizeLocal('Joystick déconnecté · commandes neutralisées');
    state.gamepadIndex = null;
  }
  updateGamepadStatus();
}
function updateGamepadStatus() {
  const pad = selectedGamepad();
  $('gamepadStatus').textContent = !pad ? 'Aucun joystick sélectionné' : state.gamepadArmed ? `ACTIF · ${pad.id}` : `Sélectionné, non armé · ${pad.id}`;
  $('gamepadStatus').classList.toggle('armed', state.gamepadArmed);
  $('armGamepad').textContent = state.gamepadArmed ? 'Désactiver le joystick' : 'Activer le joystick';
}
$('gamepadSelect').addEventListener('change', event => {
  neutralizeLocal(); state.gamepadIndex = event.target.value === '' ? null : +event.target.value;
  const pad = selectedGamepad(); state.gamepadProfile.deviceId = pad?.id || ''; configureMappingUi(pad); saveGamepadProfile(); updateGamepadStatus();
});
['m3', 'm1', 'm2'].forEach(axis => $('map' + axis.toUpperCase()).addEventListener('change', event => {
  state.gamepadProfile.axes[axis] = +event.target.value; state.gamepadArmed = false; saveGamepadProfile(); updateGamepadStatus();
}));
$('mapDeadman').addEventListener('change', event => { state.gamepadProfile.deadmanButton = +event.target.value; state.gamepadArmed = false; saveGamepadProfile(); updateGamepadStatus(); });
document.querySelectorAll('.learn').forEach(button => button.onclick = () => {
  const pad = selectedGamepad(); if (!pad) return log('Sélectionner un joystick avant apprentissage');
  state.learnTarget = button.dataset.learn; state.learnBaseline = [...pad.axes];
  log(`Apprentissage ${state.learnTarget} : actionner franchement la commande`);
});
$('calibrate').onclick = () => {
  const pad = selectedGamepad(); if (!pad) return log('Aucun joystick à calibrer');
  ['m3', 'm1', 'm2'].forEach(axis => state.gamepadProfile.neutral[axis] = pad.axes[state.gamepadProfile.axes[axis]] ?? 0);
  saveGamepadProfile(); log('Neutres joystick enregistrés');
};
$('armGamepad').onclick = () => {
  if (!selectedGamepad()) return log('Sélectionner un joystick');
  state.gamepadArmed = !state.gamepadArmed; updateGamepadStatus();
  log(state.gamepadArmed ? 'Joystick activé volontairement' : 'Joystick désactivé');
};

function gamepadLoop(timestamp) {
  const pad = selectedGamepad();
  if (pad) {
    const axes = pad.axes.map((value, index) => `A${index} ${value.toFixed(2)}`);
    const buttons = pad.buttons.map((button, index) => button.pressed ? `B${index}` : '').filter(Boolean);
    $('rawInputs').textContent = `${axes.join(' · ')}${buttons.length ? ` | actifs : ${buttons.join(', ')}` : ''}`;
    if (state.learnTarget) {
      if (state.learnTarget === 'deadman') {
        const index = pad.buttons.findIndex(button => button.pressed);
        if (index >= 0) { state.gamepadProfile.deadmanButton = index; $('mapDeadman').value = String(index); state.learnTarget = null; log(`Homme-mort appris : B${index}`); saveGamepadProfile(); }
      } else {
        const index = pad.axes.findIndex((value, i) => Math.abs(value - (state.learnBaseline[i] ?? 0)) > 0.55);
        if (index >= 0) { const axis = state.learnTarget; state.gamepadProfile.axes[axis] = index; $('map' + axis.toUpperCase()).value = String(index); state.learnTarget = null; log(`${axis.toUpperCase()} appris : A${index}`); saveGamepadProfile(); }
      }
    }
    updateDeadmanUi();
    if (state.gamepadArmed && timestamp - state.lastGamepadSend > 50) { sendControl(); state.lastGamepadSend = timestamp; }
  }
  requestAnimationFrame(gamepadLoop);
}
if (navigator.getGamepads) {
  window.addEventListener('gamepadconnected', refreshGamepads);
  window.addEventListener('gamepaddisconnected', refreshGamepads);
  setInterval(refreshGamepads, 1000); refreshGamepads(); requestAnimationFrame(gamepadLoop);
}

function currentConfig() {
  return {travelM: +$('cfgTravel').value || 30, fullTravelTimeS: +$('cfgTravelTime').value || 8,
    minSpeedMps: +$('cfgWinchMin').value || 1, maxSpeedMps: +$('cfgWinchMax').value || 2,
    bucketClosedDeltaM: +$('cfgBucket').value || 15};
}
function loadConfig(config) {
  $('cfgTravel').value = config.travelM; $('cfgTravelTime').value = config.fullTravelTimeS;
  $('cfgWinchMin').value = config.minSpeedMps; $('cfgWinchMax').value = config.maxSpeedMps; $('cfgBucket').value = config.bucketClosedDeltaM;
}
$('applyConfig').onclick = () => post({action: 'config', ...currentConfig()}).then(() => log('Paramètres appliqués au modèle')).catch(() => {});
$('openOmEdit').onclick = () => post({action: 'open_omedit'}).then(() => log('Dredge.mo ouvert dans OMEdit')).catch(() => {});
$('reloadModel').onclick = async () => {
  $('reloadModel').disabled = true; $('reloadModel').textContent = 'Compilation…';
  try { await post({action: 'reload_model'}); state.frames = []; state.seq = 0; log('Dredge.mo recompilé et rechargé'); }
  finally { $('reloadModel').disabled = false; $('reloadModel').textContent = 'Recharger le modèle'; }
};

async function poll() {
  try {
    const response = await fetch(`/state?after=${state.seq}`, {cache: 'no-store'});
    const snapshot = await response.json();
    state.ready = !!snapshot.ready;
    $('connection').textContent = snapshot.error ? 'Erreur OpenModelica' : snapshot.ready ? 'OpenModelica READY · 20 ms' : 'Compilation des FMU…';
    $('connection').className = `status ${snapshot.error ? 'bad' : snapshot.ready ? 'ok' : 'pending'}`;
    showError(snapshot.error || '');
    if (state.epoch !== null && snapshot.epoch !== state.epoch) { state.frames = []; state.seq = 0; }
    state.epoch = snapshot.epoch;
    if (!state.catalog.length && snapshot.signalCatalog) setupCatalog(snapshot.signalCatalog);
    if (!state.configLoaded && snapshot.config) { loadConfig(snapshot.config); state.configLoaded = true; }
    if (snapshot.frames?.length) {
      state.frames.push(...snapshot.frames); state.seq = snapshot.frames.at(-1).seq;
      if (state.frames.length > 5000) state.frames.splice(0, state.frames.length - 5000);
    }
    if (snapshot.last && Object.keys(snapshot.last).length) { render(snapshot.last, snapshot); drawChart(); }
    if (snapshot.events) {
      $('eventLog').innerHTML = '';
      snapshot.events.forEach(event => { const line = document.createElement('div'); line.textContent = `${event.t.toFixed(2)} s · ${event.message}`; $('eventLog').append(line); });
    }
  } catch (error) {
    state.ready = false; $('connection').textContent = 'Serveur arrêté'; $('connection').className = 'status bad';
  }
  setTimeout(poll, 100);
}

setInterval(() => { if (!state.gamepadArmed) sendControl(); }, 60);
poll();
