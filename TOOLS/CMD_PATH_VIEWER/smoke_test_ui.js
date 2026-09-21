#!/usr/bin/env node
/* ═══════════════════════════════════════════════════════════════════════════════════════════
   T353 — CMD_PATH_VIEWER · smoke_test_ui.js
   Test de fumée du front en MODE STATIQUE, sans navigateur.

   Pourquoi ce test : aucune automatisation de navigateur n'est disponible dans ce lot. Ce test
   exécute donc app.js dans un DOM minimal simulé (Node `vm`) et vérifie que le rendu réel des
   maillons, du bandeau de fraîcheur, de la branche non empruntée et de l'auto-test s'effectue
   SANS exception et produit le contenu attendu.

   Limite déclarée : ce test prouve que le code de rendu s'exécute et produit le HTML attendu ;
   il ne remplace pas un contrôle visuel dans un navigateur (mise en page, couleurs).

   Usage : node smoke_test_ui.js     (code de sortie 0 = PASS)
   ═══════════════════════════════════════════════════════════════════════════════════════════ */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const dossier = __dirname;
const elements = {};
function fakeEl(id) {
  if (!elements[id]) {
    elements[id] = { id: id, innerHTML: '', textContent: '', value: '', className: '', style: {},
                     onchange: null, onclick: null, oninput: null };
  }
  return elements[id];
}

const sandbox = {
  console: console,
  document: { getElementById: fakeEl, body: { innerHTML: '' } },
  location: { protocol: 'file:', href: 'file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/TOOLS/CMD_PATH_VIEWER/index.html' },
  URL: URL, Date: Date, setTimeout: setTimeout,
  fetch: undefined
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);

const fichiers = ['git-blob-sha1.js', 'data/graph.js', 'data/freshness.js', 'app.js'];
const resultats = [];
function check(nom, cond, detail) {
  resultats.push({ nom: nom, pass: !!cond, detail: detail === undefined ? '' : String(detail) });
}
function compter(html, motif) { return (html.match(motif) || []).length; }

/* Exécution des scripts du front dans l'ordre exact de index.html */
let exception = null;
try {
  fichiers.forEach(function (f) {
    const code = fs.readFileSync(path.join(dossier, f), 'utf8');
    vm.runInContext(code, sandbox, { filename: f });
  });
} catch (e) {
  exception = e;
}
check('exécution des 4 scripts sans exception', exception === null, exception ? exception.message : '');

const G = sandbox.CMD_PATH_VIEWER_GRAPH;
const F = sandbox.CMD_PATH_VIEWER_FRESHNESS;
check('data/graph.js expose le graphe', !!G, G ? G.maillons.length + ' maillons' : 'absent');
check('data/freshness.js expose le constat figé', !!F, F ? F.totaux.fichiers + ' fichiers' : 'absent');
check('GitBlobSha1 exposé au navigateur (mode statique)', !!sandbox.GitBlobSha1, '');

const bandeau = elements['bandeau-fraicheur'] ? elements['bandeau-fraicheur'].innerHTML : '';
check('bandeau statique : fraîcheur déclarée NON recalculée',
  bandeau.indexOf('NON RECALCULÉE EN DIRECT') >= 0 && bandeau.indexOf('figés') >= 0, '');
check('bandeau statique : horodatage affiché',
  bandeau.indexOf((F && F.meta && F.meta.genere_le) || 'ZZZ') >= 0, (F && F.meta && F.meta.genere_le) || '');
check('badge de mode = STATIQUE', (elements['badge-mode'] || {}).textContent === 'MODE STATIQUE (file://)',
  (elements['badge-mode'] || {}).textContent);

/* Rendu de la première chaîne (treuils/MANUELLE) */
const html0 = elements['liste-maillons'] ? elements['liste-maillons'].innerHTML : '';
const nbCartes0 = compter(html0, /<article class="maillon /g);
check('chaîne par défaut rendue (66 maillons treuils/M)', nbCartes0 === 66, nbCartes0 + ' cartes');
check('le premier maillon affiché est M01', html0.indexOf('>M01<') >= 0, '');
check('le dernier maillon affiché est M66', html0.indexOf('>M66<') >= 0, '');
check('chaque carte porte producteur ET consommateur',
  html0.indexOf('Producteur') >= 0 && html0.indexOf('Consommateur') >= 0, '');
check('les 5 champs exigés par AC7 sont présents (code, variable, producteur, consommateur, rôle)',
  html0.indexOf('class="code ') >= 0 && html0.indexOf('class="var"') >= 0 &&
  html0.indexOf('class="role"') >= 0, '');
check('des références fichier:ligne sont affichées', compter(html0, /class="ref /g) > 100,
  compter(html0, /class="ref /g) + ' pastilles');

/* Auto-test du hash : exécuté dans le bac à sable, comme dans le navigateur */
const at = elements['autotest'] ? elements['autotest'].innerHTML : '';
check('auto-test du hash affiché PASS', at.indexOf('PASS') >= 0, '');

/* Branche non empruntée (AC8) */
const ne = elements['branche-non-empruntee'] ? elements['branche-non-empruntee'].innerHTML : '';
check('branche NON empruntée affichée pour treuils/M',
  ne.indexOf('treuils/C') >= 0 || ne.indexOf('Chaîne AUTO') >= 0, '');
check('branche non empruntée : citation vérifiée', ne.indexOf('citation vérifiée') >= 0, '');

/* Changement de chaîne : translation M3 cycle (T334) puis gestes */
function selectionnerChaine(id) {
  elements['sel-chaine'].value = id;
  elements['sel-chaine'].onchange();
  return elements['liste-maillons'].innerHTML;
}
const htmlM3C = selectionnerChaine('t334/C');
check('chaîne t334/C rendue (35 maillons)', compter(htmlM3C, /<article class="maillon /g) === 35,
  compter(htmlM3C, /<article class="maillon /g) + ' cartes');
check('t334/C : panneau marqueurs/dissymétries alimenté',
  (elements['marqueurs'].innerHTML || '').length > 50, '');

elements['sel-geste'].value = 'NS01_SENS_GESTE_TREUILS';
elements['sel-geste'].onchange();
check('entrée de geste NON SÉPARABLE sélectionnable sans exception', true, '');
check('geste NON SÉPARABLE : motif affiché dans le sélecteur',
  (elements['sel-geste'].innerHTML || '').indexOf('NON SÉPARABLE') >= 0, '');

elements['sel-geste'].value = 'G03_MANU_M3';
elements['sel-geste'].onchange();
const htmlG03 = elements['liste-maillons'].innerHTML;
check('geste curé G03 (M3 manuel) sélectionne la bonne chaîne', elements['sel-chaine'].value === 't334/M',
  elements['sel-chaine'].value);
check('compléments de l\'annexe affichés comme NON FUSIONNÉS dans la chaîne M3',
  htmlG03.indexOf('complément annexe') >= 0 && compter(htmlG03, /<article class="maillon /g) === 74,
  compter(htmlG03, /<article class="maillon /g) + ' cartes (66 + 8 compléments)');

/* Panneaux transverses */
check('limites déclarées rendues', compter(elements['limites'].innerHTML, /<li>/g) >= 7,
  compter(elements['limites'].innerHTML, /<li>/g) + ' entrées');
check('panneau d\'ancrage : mention de l\'ancrage DÉRIVÉ de T334',
  (elements['panneau-ancrage'].innerHTML || '').indexOf('ancrage DÉRIVÉ') >= 0, '');
check('panneau d\'ancrage : piège `--stdin` documenté',
  (elements['panneau-ancrage'].innerHTML || '').indexOf('--stdin') >= 0, '');
check('résumé de chaîne : aucun maillon sans référence (0)',
  (elements['resume-chaine'].innerHTML || '').indexOf('0 sans aucune référence') >= 0, '');
check('panneau d\'audit global rendu (4 formes, préfixes ambigus)',
  (elements['audit-references'].innerHTML || '').indexOf('AMBIGU') >= 0 &&
  (elements['audit-references'].innerHTML || '').indexOf('anti-invention') >= 0, '');
check('audit global : compteurs EXACTS malgré les listes bornées (202 / 39 / 93 préfixes uniques)',
  (elements['audit-references'].innerHTML || '').indexOf('>202<') >= 0 &&
  (elements['audit-references'].innerHTML || '').indexOf('>39<') >= 0 &&
  (elements['audit-references'].innerHTML || '').indexOf('>93<') >= 0, '');
check('audit global : 0 chemin inventé (M1.st / PRG_04.st)',
  (elements['audit-references'].innerHTML || '').indexOf('0 chemin inventé') >= 0, '');
const rc = elements['refs-contestees'] ? elements['refs-contestees'].innerHTML : '';
check('panneau « références contestées » rendu (couple fichier:ligne impossible)',
  rc.indexOf('contestée') >= 0, '');
check('auto-contrôle des invariants affiché PASS', rc.indexOf('PASS') >= 0, '');
check('cas D07 contesté affiché (650 hors des 549 lignes de PRG_06_Outputs.st)',
  rc.indexOf('650') >= 0 && rc.indexOf('PRG_06_Outputs.st') >= 0, '');
check('3 reroutages affichés vers PRG_04_Treuils_Benne.st (M63, C32 ×2)',
  rc.indexOf('E_CONTINUATION_HORS_BORNES_REROUTAGE') >= 0 &&
  (rc.match(/PRG_04_Treuils_Benne\.st/g) || []).length >= 3, '');
check('verrou des attendus affiché 7/7 PASS (anti-régression de l\'héritage)',
  rc.indexOf('Verrou des attendus') >= 0 && rc.indexOf('PASS 7/7') >= 0, '');
check('attendus : M20 alias M1/M2 et M21/M34 abréviation PRG_04 tous ✅',
  (rc.match(/✅/g) || []).length >= 7, (rc.match(/✅/g) || []).length + ' ✅');
const cp = elements['corrections-perimees'] ? elements['corrections-perimees'].innerHTML : '';
check('panneau « corrections de références périmées » rendu (annexe §4.10)',
  cp.indexOf('26 corrections') >= 0 && cp.indexOf('PRG_02_Acquisition.st') >= 0, '');
check('corrections : avertissement d\'ancrage périmé (d6e54377 vs HEAD) affiché',
  cp.indexOf('d6e54377') >= 0 || cp.indexOf('HEAD ANTÉRIEUR') >= 0, '');

/* ── rapport ────────────────────────────────────────────────────────────────────────────── */
let ko = 0;
console.log('='.repeat(96));
console.log('SMOKE TEST UI (mode statique, DOM simulé) — T353 CMD_PATH_VIEWER');
console.log('='.repeat(96));
resultats.forEach(function (r) {
  if (!r.pass) ko++;
  console.log((r.pass ? '  OK   ' : '  FAIL ') + r.nom + (r.detail ? '  [' + r.detail + ']' : ''));
});
console.log('-'.repeat(96));
console.log('  ' + (resultats.length - ko) + '/' + resultats.length + ' vérifications PASS');
process.exit(ko === 0 ? 0 : 1);
