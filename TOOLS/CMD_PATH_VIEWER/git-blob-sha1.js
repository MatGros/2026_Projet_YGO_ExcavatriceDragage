/* ═══════════════════════════════════════════════════════════════════════════════════════════
   T353 — CMD_PATH_VIEWER · git-blob-sha1.js
   Calcul du blob SHA-1 git, à l'identique de `git hash-object <chemin>` sur CE dépôt.

   Module UNIQUE, partagé par :
     - le navigateur (mode live) : window.GitBlobSha1
     - Node.js (preuve P4)       : require('./git-blob-sha1.js')
   Aucune dépendance, aucun CDN, aucune API WebCrypto (donc fonctionne aussi en file://).

   ⚠️ DEUX PIÈGES MESURÉS SUR CE DÉPÔT (voir PREUVE_T353.md §P4) :

   1. L'en-tête `blob <taille>\0` est OBLIGATOIRE. Un SHA-1 du seul contenu ne donne pas le
      blob git.

   2. `core.autocrlf = true` : `git hash-object <chemin>` convertit CRLF→LF AVANT de calculer
      le blob, et la taille de l'en-tête est celle APRÈS conversion. Sans cette normalisation,
      PRG_04_Treuils_Benne.st rendrait a50024aa… au lieu de 31760d59…, et les ~47 fichiers du
      dépôt seraient affichés PÉRIMÉS à tort.
      ⚠️ Corollaire : `git hash-object --stdin` n'applique PAS ce filtre (git le documente) —
      la comparaison de référence doit toujours se faire sur un CHEMIN DE FICHIER.
   ═══════════════════════════════════════════════════════════════════════════════════════════ */
(function (global) {
  'use strict';

  /* ── SHA-1 pur JS (RFC 3174) sur Uint8Array ─────────────────────────────────────────────── */
  function sha1Bytes(bytes) {
    var ml = bytes.length;
    var avecUn = ml + 1;
    var total = ((avecUn + 8 + 63) >> 6) << 6;
    var buf = new Uint8Array(total);
    buf.set(bytes);
    buf[ml] = 0x80;
    var dv = new DataView(buf.buffer);
    var hi = Math.floor(ml / 536870912);      // ml*8 / 2^32
    var lo = (ml * 8) >>> 0;
    dv.setUint32(total - 8, hi);
    dv.setUint32(total - 4, lo);

    var h0 = 0x67452301, h1 = 0xEFCDAB89, h2 = 0x98BADCFE, h3 = 0x10325476, h4 = 0xC3D2E1F0;
    var w = new Uint32Array(80);
    for (var i = 0; i < total; i += 64) {
      var j;
      for (j = 0; j < 16; j++) w[j] = dv.getUint32(i + j * 4);
      for (j = 16; j < 80; j++) {
        var v = w[j - 3] ^ w[j - 8] ^ w[j - 14] ^ w[j - 16];
        w[j] = ((v << 1) | (v >>> 31)) >>> 0;
      }
      var a = h0, b = h1, c = h2, d = h3, e = h4;
      for (j = 0; j < 80; j++) {
        var f, k;
        if (j < 20) { f = (b & c) | ((~b) & d); k = 0x5A827999; }
        else if (j < 40) { f = b ^ c ^ d; k = 0x6ED9EBA1; }
        else if (j < 60) { f = (b & c) | (b & d) | (c & d); k = 0x8F1BBCDC; }
        else { f = b ^ c ^ d; k = 0xCA62C1D6; }
        var t = ((((a << 5) | (a >>> 27)) >>> 0) + (f >>> 0) + e + k + w[j]) >>> 0;
        e = d; d = c; c = ((b << 30) | (b >>> 2)) >>> 0; b = a; a = t;
      }
      h0 = (h0 + a) >>> 0; h1 = (h1 + b) >>> 0; h2 = (h2 + c) >>> 0;
      h3 = (h3 + d) >>> 0; h4 = (h4 + e) >>> 0;
    }
    return hex32(h0) + hex32(h1) + hex32(h2) + hex32(h3) + hex32(h4);
  }

  function hex32(n) {
    var s = (n >>> 0).toString(16);
    while (s.length < 8) s = '0' + s;
    return s;
  }

  /* ── Filtre « clean » du dépôt : CRLF → LF ──────────────────────────────────────────────── */
  function normaliserCRLF(bytes) {
    var n = 0, i;
    for (i = 0; i < bytes.length; i++) if (bytes[i] === 0x0D && bytes[i + 1] === 0x0A) { n++; i++; }
    if (n === 0) return { octets: bytes, conversions: 0, modifie: false };
    var out = new Uint8Array(bytes.length - n);
    var j = 0;
    for (i = 0; i < bytes.length; i++) {
      if (bytes[i] === 0x0D && bytes[i + 1] === 0x0A) { out[j++] = 0x0A; i++; }
      else out[j++] = bytes[i];
    }
    return { octets: out, conversions: n, modifie: true };
  }

  function enTete(taille) {
    var s = 'blob ' + taille + '\u0000';
    var b = new Uint8Array(s.length);
    for (var i = 0; i < s.length; i++) b[i] = s.charCodeAt(i) & 0xFF;
    return b;
  }

  function concat(a, b) {
    var out = new Uint8Array(a.length + b.length);
    out.set(a, 0);
    out.set(b, a.length);
    return out;
  }

  /**
   * Hash comparable à `git hash-object <chemin>` (filtre CRLF du dépôt appliqué).
   * @param {Uint8Array} octets contenu BRUT lu sur le disque
   * @returns {{sha1_git:string, sha1_brut:string, taille_brute:number, taille_normalisee:number,
   *            crlf_converti:number, normalisation:string}}
   */
  function gitBlobSha1(octets) {
    var norm = normaliserCRLF(octets);
    return {
      sha1_git: sha1Bytes(concat(enTete(norm.octets.length), norm.octets)),
      sha1_brut: sha1Bytes(concat(enTete(octets.length), octets)),
      taille_brute: octets.length,
      taille_normalisee: norm.octets.length,
      crlf_converti: norm.conversions,
      normalisation: norm.modifie ? 'CRLF→LF (filtre git du dépôt, core.autocrlf=true)' : 'aucune (contenu déjà en LF)',
      formule: 'SHA1("blob " + ' + norm.octets.length + ' + "\\0" + contenu)'
    };
  }

  /* ── Auto-test : vecteurs vérifiés contre `git hash-object` sur cette machine ───────────── */
  var VECTEURS = [
    { nom: 'vide', octets: [], attendu: 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391', ref: 'git hash-object' },
    { nom: 'hello\\n', octets: [104, 101, 108, 108, 111, 10], attendu: 'ce013625030ba8dba906f756967f9e9ca394464a', ref: 'git hash-object' },
    { nom: 'what is up, doc?\\n', octets: [119, 104, 97, 116, 32, 105, 115, 32, 117, 112, 44, 32, 100, 111, 99, 63, 10], attendu: '7108f7ecb345ee9d0084193f147cdad4d2998293', ref: 'git hash-object' },
    { nom: 'a\\r\\nb\\r\\n  (piège CRLF : la valeur attendue est celle de `git hash-object <fichier>`, filtre CRLF appliqué — `--stdin` ne l\'applique pas)',
      octets: [97, 13, 10, 98, 13, 10], attendu: '422c2b7ab3b3c668038da977e4e93a5fc623169c', ref: 'git hash-object <chemin> (filtre CRLF)' }
  ];

  function autoTest() {
    var res = [], ok = true;
    for (var i = 0; i < VECTEURS.length; i++) {
      var v = VECTEURS[i];
      var r = gitBlobSha1(new Uint8Array(v.octets));
      var bon = r.sha1_git === v.attendu;
      ok = ok && bon;
      res.push({ nom: v.nom, attendu: v.attendu, obtenu: r.sha1_git, ref: v.ref, pass: bon });
    }
    return { pass: ok, vecteurs: res };
  }

  var api = {
    sha1Bytes: sha1Bytes,
    normaliserCRLF: normaliserCRLF,
    gitBlobSha1: gitBlobSha1,
    autoTest: autoTest,
    VECTEURS: VECTEURS
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (global) global.GitBlobSha1 = api;
})(typeof globalThis !== 'undefined' ? globalThis : (typeof window !== 'undefined' ? window : this));
