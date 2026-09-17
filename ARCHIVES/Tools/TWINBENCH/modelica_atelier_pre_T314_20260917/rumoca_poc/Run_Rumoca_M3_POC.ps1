param(
  [ValidateSet('M3', 'Grab', 'M3Faults')]
  [string]$Scenario = 'M3',
  [string]$RumocaExe = ''
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$model = Join-Path $here 'RumocaM3Poc.mo'
$modelClass = if ($Scenario -eq 'Grab') { 'RumocaM3Poc.GrabClosureThenHoist' } elseif ($Scenario -eq 'M3Faults') { 'RumocaM3Poc.M3FaultsAndPvZone' } else { 'RumocaM3Poc.ContractCycle' }
$rawResult = Join-Path $here ("RumocaM3Poc_{0}_raw.html" -f $Scenario)
$result = Join-Path $here ("RumocaM3Poc_{0}_dashboard.html" -f $Scenario)
$stopTime = if ($Scenario -eq 'Grab') { 10 } elseif ($Scenario -eq 'M3Faults') { 21 } else { 12 }
$solver = if ($Scenario -eq 'Grab' -or $Scenario -eq 'M3Faults') { 'rk-like' } else { 'auto' }

function Convert-RumocaReportToDashboard([string]$Path) {
  $html = Get-Content -LiteralPath $Path -Raw
  $startMarker = 'globalThis.__rumocaResultsReportMount = function(options) {'
  $endMarker = 'globalThis.__rumocaResultsReportMount({'
  $start = $html.IndexOf($startMarker)
  $end = $html.IndexOf($endMarker, $start + $startMarker.Length)
  if ($start -lt 0 -or $end -lt 0) { throw "Format de rapport Rumoca inattendu : $Path" }
  $renderer = @'
globalThis.__rumocaResultsReportMount = function(options) {
  const { names, allData } = options.payload;
  const time = allData[0];
  const data = Object.fromEntries(names.map((name, i) => [name, allData[i + 1]]));
  const root = options.root || document.body;
  root.innerHTML = `<main><header><p class="eyebrow">TwinBench · Rumoca result</p><h1>${options.model}</h1><p>${time.length} points · ${time.at(-1)} s simulées</p></header><section id="charts"></section></main>`;
  const css = document.createElement('style');
  css.textContent = `body{background:#10151d;color:#e7edf6;font:14px/1.4 system-ui;margin:0}main{max-width:1420px;margin:auto;padding:28px}.eyebrow{color:#70d6a5;text-transform:uppercase;letter-spacing:.12em;font-size:11px}h1{margin:4px 0;font-size:25px}#charts{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:16px;margin-top:24px}.card{background:#18212d;border:1px solid #29394c;border-radius:12px;padding:12px}.card h2{font-size:14px;margin:0 0 9px;color:#c6d7ed}canvas{width:100%;height:220px;display:block;background:#111923;border-radius:8px}`;
  document.head.append(css);
  const preferred = [
    ['Câbles / position', ['m1CableM','m2CableM','positionM']],
    ['Vitesse / fréquence', ['velocityMps','frequencyTargetHz','actualFrequencyHz']],
    ['Fermeture / remontée', ['bucketClosurePct','bucketClosedDI','closureCommand','hoistRequest','hoistActive','hoistBlockedByOpenBucket']],
    ['Capteurs / défauts', ['tremieRawDI','tremieIdealDI','p1RawDI','p1IdealDI','brakeReleaseCmd','brakeFeedbackDI','brakeStuckFaultDI','pvZoneDI','sensorBounceFaultDI']]
  ];
  const charts = document.querySelector('#charts');
  const colors = ['#64b5f6','#ffb74d','#81c784','#ef9a9a','#ce93d8','#4dd0e1','#fff176','#f48fb1'];
  function draw(canvas, selected) {
    const dpr = devicePixelRatio || 1, box = canvas.getBoundingClientRect();
    canvas.width = box.width*dpr; canvas.height = box.height*dpr;
    const c = canvas.getContext('2d'); c.scale(dpr,dpr); const w=box.width,h=box.height, l=42,r=12,t=14,b=28;
    const values = selected.flatMap(n=>data[n]).filter(Number.isFinite); let lo=Math.min(...values), hi=Math.max(...values);
    if (lo===hi) { lo-=1; hi+=1; } const pad=(hi-lo)*.08; lo-=pad; hi+=pad;
    c.strokeStyle='#2b3a4c'; c.lineWidth=1; for(let i=0;i<5;i++){let y=t+i*(h-t-b)/4;c.beginPath();c.moveTo(l,y);c.lineTo(w-r,y);c.stroke();}
    c.fillStyle='#92a6bd'; c.font='11px system-ui'; c.fillText(lo.toFixed(2),2,h-b); c.fillText(hi.toFixed(2),2,t+8); c.fillText('0 s',l,h-7); c.fillText(time.at(-1).toFixed(1)+' s',w-r-35,h-7);
    selected.forEach((name,k)=>{c.strokeStyle=colors[k%colors.length];c.lineWidth=2;c.beginPath();data[name].forEach((v,i)=>{const x=l+(time[i]-time[0])/(time.at(-1)-time[0])*(w-l-r);const y=t+(hi-v)/(hi-lo)*(h-t-b);i?c.lineTo(x,y):c.moveTo(x,y)});c.stroke();c.fillStyle=colors[k%colors.length];c.fillText(name,l+5+k*115,t+12);});
  }
  let made=0; preferred.forEach(([title, list])=>{const selected=list.filter(n=>data[n]);if(!selected.length)return;made++;const card=document.createElement('article');card.className='card';card.innerHTML=`<h2>${title}</h2><canvas></canvas>`;charts.append(card);draw(card.querySelector('canvas'),selected);});
  if(!made){names.filter(n=>!n.startsWith('c[')).slice(0,8).forEach(name=>{const card=document.createElement('article');card.className='card';card.innerHTML=`<h2>${name}</h2><canvas></canvas>`;charts.append(card);draw(card.querySelector('canvas'),[name]);});}
};

'@
  Set-Content -LiteralPath $Path -Value ($html.Substring(0, $start) + $renderer + $html.Substring($end)) -Encoding utf8
}

if ([string]::IsNullOrWhiteSpace($RumocaExe)) {
  $candidates = @(
    (Join-Path $here 'runtime\rumoca.exe'),
    (Join-Path $env:LOCALAPPDATA 'TwinBench\runtime\rumoca\0.9.20\rumoca.exe')
  )
  $RumocaExe = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not (Test-Path -LiteralPath $RumocaExe)) {
  throw "Rumoca CLI introuvable. Placez rumoca.exe dans $here\runtime\rumoca.exe ou relancez avec -RumocaExe <chemin>."
}

Write-Host "[Rumoca POC] Validation de $modelClass ..."
& $RumocaExe compile $model --model $modelClass --inspect structure
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host '[Rumoca POC] Simulation, échantillon 20 ms...'
$measure = Measure-Command {
  & $RumocaExe sim $model --model $modelClass --t-end $stopTime --dt 0.02 --solver $solver --output $rawResult
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
Copy-Item -LiteralPath $rawResult -Destination $result -Force
Convert-RumocaReportToDashboard -Path $result
Write-Host "[Rumoca POC] Tableau de bord Canvas généré."
Write-Host ("[Rumoca POC] Temps mur : {0:N3} s" -f $measure.TotalSeconds)
Write-Host "[Rumoca POC] Rapport : $result"
Start-Process $result
