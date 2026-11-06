// Run from repository root. No live service or real session is contacted.
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';

const files = {
  interface: 'TOOLS/AGENT_SUPERVISOR/ui/index.html',
  original: 'TOOLS/AGENT_SUPERVISOR/tests/test_ui.mjs',
  adapted: 'TOOLS/AGENT_SUPERVISOR/poc/interface/test_ui_adapte.mjs',
};
const hash = path => createHash('sha256').update(fs.readFileSync(path)).digest('hex');
const run = script => {
  const p = spawnSync(process.execPath, [script], {encoding: 'utf8', timeout: 30000});
  return {script, exit: p.status, signal: p.signal, error: p.error?.message ?? null,
          stdout: p.stdout, stderr: p.stderr};
};
const result = {node: process.version, platform: process.platform, timestamp: new Date().toISOString(),
  dependency_hint: process.env.SUPERVISION_DOM_MODULES || `${os.tmpdir()}/supervision-dom-tests/package.json`,
  sha256: Object.fromEntries(Object.entries(files).map(([k,v]) => [k, hash(v)])),
  original: run(files.original), adapted: run(files.adapted)};
const output = JSON.stringify(result, null, 2) + '\n';
if (process.argv.includes('--record')) fs.writeFileSync('TOOLS/AGENT_SUPERVISOR/poc/interface/results.json', output);
process.stdout.write(output);
if (result.adapted.exit !== 0) process.exitCode = 1;
