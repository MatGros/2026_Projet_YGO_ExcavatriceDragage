'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { getSummary, validPort } = require('../lib/client');

test('client lit uniquement le résumé local et ne transmet ni token ni méthode en écriture', async (t) => {
  let seen;
  const server = http.createServer((req, res) => {
    seen = { method: req.method, url: req.url, headers: req.headers };
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ schema_version: 1, running: true, sessions: [] }));
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());
  const value = await getSummary(server.address().port);
  assert.equal(value.schema_version, 1);
  assert.equal(seen.method, 'GET');
  assert.equal(seen.url, '/api/supervision/summary');
  assert.equal(seen.headers['x-supervision-token'], undefined);
  assert.equal(seen.headers.authorization, undefined);
});

test('refuse les ports hors plage et les HTTP non-200', async (t) => {
  for (const port of [0, -1, 65536, 'abc']) assert.throws(() => validPort(port));
  const server = http.createServer((_req, res) => { res.writeHead(302, { Location: 'http://example.com' }); res.end(); });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());
  await assert.rejects(getSummary(server.address().port), /HTTP 302/);
});
