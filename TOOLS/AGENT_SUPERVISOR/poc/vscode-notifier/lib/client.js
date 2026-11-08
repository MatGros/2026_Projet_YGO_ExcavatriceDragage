'use strict';

const http = require('node:http');

function validPort(value) {
  const port = Number(value);
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Port Agent Supervisor invalide.');
  return port;
}

function getSummary(port, timeoutMs = 2500) {
  const servicePort = validPort(port);
  return new Promise((resolve, reject) => {
    const request = http.get({ hostname: '127.0.0.1', port: servicePort, path: '/api/supervision/summary',
      headers: { Accept: 'application/json' } }, (response) => {
      const chunks = [];
      let size = 0;
      if (response.statusCode !== 200) {
        response.resume();
        reject(new Error(`Service Agent Supervisor : HTTP ${response.statusCode || 'inconnu'}.`));
        return;
      }
      response.on('data', (chunk) => {
        size += chunk.length;
        if (size > 1_000_000) request.destroy(new Error('Résumé Agent Supervisor trop volumineux.'));
        else chunks.push(chunk);
      });
      response.on('end', () => {
        try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
        catch (_) { reject(new Error('Réponse JSON invalide d?Agent Supervisor.')); }
      });
    });
    request.setTimeout(timeoutMs, () => request.destroy(new Error('Délai de réponse d?Agent Supervisor dépassé.')));
    request.on('error', (error) => reject(error));
  });
}

module.exports = { getSummary, validPort };
