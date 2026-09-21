/* ═══════════════════════════════════════════════════════════════════════════════════════════
   T353 — CMD_PATH_VIEWER · app.js
   Front statique, vanilla JS, AUCUNE dépendance, AUCUN CDN.
   Mode STATIQUE (file://) : badges de fraîcheur FIGÉS, horodatés, bandeau explicite.
   Mode LIVE (servi par `python -m http.server`) : chaque blob cité est RECALCULÉ dans le
   navigateur avec git-blob-sha1.js (identique à `git hash-object <chemin>` sur ce dépôt).
   ═══════════════════════════════════════════════════════════════════════════════════════════ */
(function () {
  'use strict';

  var G = window.CMD_PATH_VIEWER_GRAPH;
  var F = window.CMD_PATH_VIEWER_FRESHNESS;
  var H = window.GitBlobSha1;

  if (!G) { document.body.innerHTML = '<p style="padding:20px">data/graph.js absent — lancez <code>python parse_cartographies.py</code>.</p>'; return; }

  var EST_FILE = (location.protocol === 'file:');
  var etat = { chaine: G.chaines[0] ? G.chaines[0].id : null, geste: '', recherche: '', nonResoluesSeules: false };
  var fraicheur = {};        // chemin -> entrée de freshness.json
  var fraicheurLive = {};    // chemin -> résultat recalculé (mode live)
  var gesteCourant = null;

  /* ── utilitaires ───────────────────────────────────────────────────────────────────────── */
  function el(id) { return document.getElementById(id); }
  function esc(s) {
    return String(s === undefined || s === null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }
  function maillonsDe(chaineId) {
    var out = G.maillons.filter(function (m) { return m.chaine_id === chaineId; });
    if (chaineId === 't334/M' && gesteCourant && gesteCourant.complements_annexe) {
      out = out.concat(G.complements.filter(function (c) {
        return c.statut === 'COMPLEMENT_NON_FUSIONNE' && c.chaine === 'M';
      }));
    }
    return out;
  }
  function refsDe(m) { return m.refs || []; }

  function etatRef(r) {
    if (r.categorie === 'CONTESTEE_HORS_BORNES') return 'CONTESTEE_HORS_BORNES';
    if (r.categorie === 'NON_RESOLUE') return 'NON_RESOLUE';
    if (r.categorie === 'AMBIGUE') return 'AMBIGU';
    var f = fraicheur[r.chemin_resolu];
    if (!f) return 'NON_ANCRABLE';
    if (r.chemin_resolu in fraicheurLive) return fraicheurLive[r.chemin_resolu].etat;
    return f.etat;
  }
  function pire(etats) {
    var ordre = { ROUGE: 5, CONTESTEE_HORS_BORNES: 4, NON_RESOLUE: 3, AMBIGU: 3, ABSENT: 3, NON_ANCRABLE: 2, VERT: 1 };
    var p = 0, nom = 'VERT';
    etats.forEach(function (e) { if ((ordre[e] || 0) > p) { p = ordre[e] || 0; nom = e; } });
    return nom;
  }
  function classeMaillon(m) {
    var e = pire(refsDe(m).map(etatRef).concat(['VERT']));
    if (e === 'VERT') return 'ok';
    if (e === 'NON_ANCRABLE') return 'warn';
    return 'ko';
  }
  function texteRef(r) {
    var base = r.chemin_resolu || (r.fichier_token ? r.fichier_token + ' (non résolu)' : r.brut);
    var lignes = r.lignes && r.lignes.length ? ':' + r.plages : '';
    return base + lignes;
  }
  function titreRef(r) {
    var t = [];
    t.push('texte brut : ' + r.brut);
    t.push('forme : ' + r.forme + (r.liste ? ' (liste de lignes)' : ''));
    t.push('champ : ' + r.champ);
    t.push('règle de résolution : ' + r.regle);
    if (r.chemin_resolu) t.push('chemin réel : ' + r.chemin_resolu);
    if (r.categorie === 'CONTESTEE_HORS_BORNES') {
      t.push('⚠ RÉFÉRENCE CONTESTÉE : le couple (fichier, ligne) est IMPOSSIBLE — la fiche cite une');
      t.push('  continuation qui ne correspond à AUCUNE ligne du fichier désigné. Elle n\'est donc');
      t.push('  jamais présentée comme résolue : c\'est une trouvaille de diagnostic (rédaction');
      t.push('  relâchée de la fiche T351), pas un fichier manquant.');
      if (r.antecedent_ecarte) t.push('fichier écarté : ' + r.antecedent_ecarte);
    }
    if (r.regle === 'DESIGNATION_PLURIELLE_AMBIGUE') {
      t.push('AMBIGU — désignation PLURIELLE : la cellule écrit « arbitres » sans identifier lequel.');
      (r.candidats || []).forEach(function (c) { t.push('  candidat ' + c.alias + ' → ' + c.chemin); });
      t.push('  Aucun candidat n\'est choisi silencieusement.');
    }
    if (r.regle === 'E_CONTINUATION_HORS_BORNES_AUTRE_FICHIER_CELLULE') {
      t.push('reroutage VÉRIFIABLE : l\'héritage sortait du fichier, un SEUL autre fichier nommé dans');
      t.push('  la cellule contient la ligne (règle nommée, aucun choix arbitraire)');
      if (r.antecedent_ecarte) t.push('fichier écarté : ' + r.antecedent_ecarte);
    }
    if (r.propagation) t.push('ligne HÉRITÉE du fichier nommé avant dans la même cellule');
    if (r.alias_source) t.push('alias documenté : ' + r.alias_source.alias + ' (source ' + r.alias_source.document + ' ligne ' + r.alias_source.ligne + ')');
    if (r.motif) t.push('motif : ' + r.motif);
    if (r.note) t.push('note : ' + r.note);
    var f = fraicheur[r.chemin_resolu];
    if (f) {
      t.push('blob consigné : ' + (f.blob_consigne || '—'));
      t.push('source de l\'ancrage : ' + (f.sources_ancrage || []).map(function (s) { return s.source + ' [' + s.etiquette + ']'; }).join(' + ') || '—');
      t.push(f.ancrage_derive ? 'ancrage DÉRIVÉ (annexe §1.3) — jamais un ancrage de T334' : 'ancrage propre au document');
      if (f.etat === 'VERT') t.push('blob mesuré (figé le ' + F.meta.genere_le + ') : ' + f.blob_mesure);
      if (f.etat === 'ROUGE') t.push('⚠ blob mesuré ' + f.blob_mesure + ' ≠ consigné ' + f.blob_consigne);
    }
    if (r.chemin_resolu in fraicheurLive) {
      var l = fraicheurLive[r.chemin_resolu];
      t.push('RECALCULÉ EN DIRECT le ' + l.mesure_le + ' : ' + l.blob_mesure + ' (' + l.normalisation + ')');
    }
    return t.join('\n');
  }

  /* ── rendu : sélecteurs ────────────────────────────────────────────────────────────────── */
  function rendreSelecteurs() {
    var sc = el('sel-chaine');
    sc.innerHTML = G.chaines.map(function (c) {
      return '<option value="' + c.id + '">' + esc(c.libelle + ' — ' + c.mode + ' (' + c.nb_maillons + ' maillons)') + '</option>';
    }).join('');
    sc.value = etat.chaine;
    sc.onchange = function () { etat.chaine = sc.value; gesteCourant = null; el('sel-geste').value = ''; rendreTout(); };

    var sg = el('sel-geste');
    sg.innerHTML = '<option value="">— aucun filtre (chaîne brute) —</option>' +
      G.gestes.map(function (g) {
        var marque = g.statut === 'NON_SEPARABLE' ? '⛔ NON SÉPARABLE' : '✅ curé sourcé';
        return '<option value="' + g.id + '">' + esc(marque + ' · ' + g.libelle) + '</option>';
      }).join('');
    sg.onchange = function () {
      gesteCourant = G.gestes.filter(function (g) { return g.id === sg.value; })[0] || null;
      if (gesteCourant && gesteCourant.type === 'CHAINE') etat.chaine = gesteCourant.document + '/' + gesteCourant.chaine;
      el('sel-chaine').value = etat.chaine;
      rendreTout();
    };

    el('recherche').oninput = function (e) { etat.recherche = e.target.value.toLowerCase(); rendreMaillons(); };
    el('chk-non-resolues').onchange = function (e) { etat.nonResoluesSeules = e.target.checked; rendreMaillons(); };
  }

  /* ── rendu : bandeau de fraîcheur ──────────────────────────────────────────────────────── */
  function rendreBandeau() {
    var b = el('bandeau-fraicheur');
    var t = (F && F.totaux) || { fichiers: 0, verts: 0, rouges: 0, absents: 0, non_ancrables: 0, ancrage_derive: 0 };
    el('badge-mode').textContent = EST_FILE ? 'MODE STATIQUE (file://)' : 'MODE LIVE (serveur de fichiers local)';
    el('badge-mode').className = 'badge badge-mode ' + (EST_FILE ? 'statique' : 'live');
    el('badge-head').textContent = 'HEAD ' + String(G.meta.head_mesure).slice(0, 8) + ' · graphe ' + G.meta.genere_le;

    if (EST_FILE) {
      b.className = 'bandeau statique';
      b.innerHTML = '<b>⚠ FRAÎCHEUR NON RECALCULÉE EN DIRECT.</b> Cette page est ouverte en <code>file://</code> : ' +
        'un navigateur n\'y exécute ni <code>git</code> ni la lecture des fichiers du dépôt, donc les badges sont ' +
        '<b>figés</b> — mesurés le <b>' + esc((F && F.meta && F.meta.genere_le) || '—') + '</b> (HEAD ' +
        esc(((F && F.meta && F.meta.head_mesure) || '').slice(0, 8)) + '). ' +
        '<span class="pastille">' + t.verts + ' vert</span><span class="pastille">' + t.rouges + ' rouge</span>' +
        '<span class="pastille">' + t.non_ancrables + ' non ancrable</span>' +
        '<span class="pastille">' + t.ancrage_derive + ' ancrage DÉRIVÉ</span><br>' +
        'Pour un recalcul réel, lancez <code>OPEN_CMD_PATH_VIEWER.bat</code> (serveur de FICHIERS statique, ' +
        'zéro logique métier côté serveur).';
    } else {
      var tot = Object.keys(fraicheurLive).length;
      b.className = 'bandeau ' + (compteLive('ROUGE') ? 'rouge' : 'live');
      b.innerHTML = '<b>FRAÎCHEUR RECALCULÉE EN DIRECT</b> — ' + tot + ' fichier(s) recalculé(s) dans le navigateur. ' +
        '<span class="pastille">' + compteLive('VERT') + ' vert</span>' +
        '<span class="pastille">' + compteLive('ROUGE') + ' rouge</span>' +
        '<span class="pastille">constat figé du ' + esc((F && F.meta && F.meta.genere_le) || '—') + '</span>' +
        (compteLive('ROUGE') ? '<br><b>⚠ Un fichier cité a changé de blob : ses numéros de ligne sont à re-vérifier (re-grep).</b>' : '');
    }
  }
  function compteLive(e) {
    return Object.keys(fraicheurLive).filter(function (k) { return fraicheurLive[k].etat === e; }).length;
  }

  /* ── rendu : maillons ─────────────────────────────────────────────────────────────────── */
  function rendreMaillons() {
    var chaine = G.chaines.filter(function (c) { return c.id === etat.chaine; })[0];
    var maillons = maillonsDe(etat.chaine);
    if (etat.recherche) {
      maillons = maillons.filter(function (m) {
        return (m.code + ' ' + m.variable + ' ' + m.producteur + ' ' + m.consommateur + ' ' + m.role +
          ' ' + refsDe(m).map(function (r) { return r.chemin_resolu || r.brut; }).join(' ')).toLowerCase().indexOf(etat.recherche) >= 0;
      });
    }
    if (etat.nonResoluesSeules) {
      maillons = maillons.filter(function (m) { return refsDe(m).some(function (r) { return r.categorie !== 'RESOLUE'; }); });
    }
    var html = maillons.map(function (m) {
      var refs = refsDe(m).map(function (r) {
        var e = etatRef(r);
        return '<span class="ref ' + e + (r.propagation ? ' propage' : '') + '" title="' + esc(titreRef(r)) + '">' +
          esc(texteRef(r)) + ' · ' + e + '</span>';
      }).join('');
      var manque = (m.refs_manquantes && m.refs_manquantes.length)
        ? '<div class="mini">⚠ référence absente dans le document : <b>' + esc(m.refs_manquantes.join(', ')) + '</b> — affichée telle quelle, jamais complétée.</div>' : '';
      var marq = (m.marqueurs && m.marqueurs.length)
        ? '<div class="mini">marqueurs du document : ' + esc(m.marqueurs.join(' ')) + '</div>' : '';
      var comp = m.statut === 'COMPLEMENT_NON_FUSIONNE'
        ? '<span class="pill warn" title="Complément de l\'annexe §4, non fusionné dans la chaîne de T334">complément annexe — ' + esc(m.nature) + '</span>' : '';
      return '<article class="maillon ' + classeMaillon(m) + '">' +
        '<div class="maillon tete"><span class="code ' + m.chaine + '">' + esc(m.code) + '</span>' +
        '<span class="var">' + esc(m.variable) + '</span>' + comp +
        '<span class="doc">' + esc(m.document) + ' · ligne ' + m.ligne_document + ' · ordre ' + m.ordre + '</span></div>' +
        '<dl class="grille">' +
          '<dt>Producteur</dt><dd>' + esc(m.producteur || '—') + '</dd>' +
          '<dt>Consommateur</dt><dd>' + esc(m.consommateur || '—') + '</dd>' +
        '</dl>' + manque +
        '<div class="role">' + esc(m.role) + '</div>' + marq +
        '<div style="margin-top:8px">' + refs + '</div>' +
      '</article>';
    }).join('');
    el('liste-maillons').innerHTML = html || '<p class="vide">Aucun maillon pour ce filtre.</p>';

    var sansRef = maillons.filter(function (m) { return !refsDe(m).length; }).length;
    var nbNR = maillons.filter(function (m) { return refsDe(m).some(function (r) { return r.categorie !== 'RESOLUE'; }); }).length;
    var deriv = maillons.filter(function (m) { return refsDe(m).some(function (r) { return fraicheur[r.chemin_resolu] && fraicheur[r.chemin_resolu].ancrage_derive; }); }).length;
    el('resume-chaine').innerHTML =
      '<h2>' + esc(chaine ? chaine.libelle : '') + '</h2>' +
      '<div>Mode : <b>' + esc(chaine ? chaine.mode : '') + '</b> · table du document : ligne ' + (chaine ? chaine.table_ligne : '—') +
      ' · section : ' + esc(chaine ? chaine.section : '') + '</div>' +
      '<div>' + maillons.length + ' maillon(s) affiché(s) · ' +
      '<span class="pill ' + (nbNR ? 'warn' : 'ok') + '">' + nbNR + ' avec référence non résolue</span> ' +
      '<span class="pill ' + (sansRef ? 'ko' : 'ok') + '">' + sansRef + ' sans aucune référence</span> ' +
      '<span class="pill info">' + deriv + ' avec ancrage DÉRIVÉ (annexe §1.3)</span></div>' +
      '<div class="mini">Aucun maillon n\'est affiché sans ses références <code>fichier:ligne</code> : ' +
      'lorsque le document ne les porte pas, la mention « référence absente » est affichée explicitement.</div>';
  }

  /* ── rendu : branche non empruntée (AC8) ──────────────────────────────────────────────── */
  function rendreNonEmpruntee() {
    var chaine = G.chaines.filter(function (c) { return c.id === etat.chaine; })[0];
    var z = el('branche-non-empruntee');
    if (!chaine || !chaine.non_empruntee) { z.innerHTML = '<p class="vide">—</p>'; return; }
    var ne = chaine.non_empruntee;
    var seur = G.chaines.filter(function (c) { return c.id === ne.chaine_id; })[0];
    z.innerHTML =
      '<p>' + esc(ne.motif) + '</p>' +
      '<p class="mini">Source : ' + esc(ne.source.document) + ' ligne ' + ne.source.ligne + ' — ' +
      (ne.citation_verifiee ? '<span class="pill ok">citation vérifiée</span>' : '<span class="pill ko">citation NON vérifiée</span>') + '</p>' +
      '<p class="mini"><code>' + esc(ne.extrait) + '</code></p>' +
      (seur ? '<p>Chaîne NON retenue : <b>' + esc(seur.libelle) + '</b> (' + seur.nb_maillons + ' maillons, ' +
        esc(seur.mode) + '). <button id="btn-voir-seur">Voir cette chaîne</button></p>' +
        '<p class="mini">Codes : ' + esc(seur.codes.join(' ')) + '</p>' : '') +
      '<p class="mini">Les branches non empruntées ne sont jamais masquées : elles sont listées ici, avec leur origine ' +
      'documentaire, pour que le diagnostic n\'oublie pas le chemin non pris.</p>';
    var b = el('btn-voir-seur');
    if (b) b.onclick = function () { etat.chaine = ne.chaine_id; el('sel-chaine').value = etat.chaine; rendreTout(); };
  }

  /* ── rendu : marqueurs / dissymétries / divergences (AC8) ─────────────────────────────── */
  function rendreMarqueurs() {
    var docId = etat.chaine.split('/')[0];
    var asy = G.asymetries.filter(function (a) { return a.document === docId; });
    var div = G.divergences.filter(function (d) { return d.document === docId; });
    var marq = G.maillons.filter(function (m) { return m.document === docId && m.marqueurs && m.marqueurs.length; });
    var h = '';
    if (asy.length) {
      h += '<h3 style="font-size:13px;margin:10px 0 4px">Dissymétries relevées par le document (' + asy.length + ')</h3>' +
        '<table class="mini-tab"><tr><th>#</th><th>Asymétrie</th><th>Ligne</th><th>Marqueurs</th></tr>' +
        asy.map(function (a) {
          return '<tr><td>' + esc(a.id) + '</td><td>' + esc(a.titre) + '</td><td>' + a.ligne + '</td><td>' + esc((a.marqueurs || []).join(' ')) + '</td></tr>';
        }).join('') + '</table>';
    }
    if (div.length) {
      h += '<h3 style="font-size:13px;margin:12px 0 4px">Divergences MANU ↔ CYCLE (' + div.length + ')</h3>' +
        '<table class="mini-tab"><tr><th>#</th><th>Divergence</th><th>Ligne</th></tr>' +
        div.map(function (d) {
          return '<tr><td>' + esc(d.id) + '</td><td>' + esc(d.titre) + '</td><td>' + d.ligne + '</td></tr>';
        }).join('') + '</table>';
    }
    h += '<h3 style="font-size:13px;margin:12px 0 4px">Maillons portant un marqueur (' + marq.length + ')</h3>';
    h += marq.length ? '<ul class="liste">' + marq.map(function (m) {
      return '<li><span class="code ' + m.chaine + '">' + esc(m.code) + '</span> ' + esc(m.variable) +
        ' <span class="mini">' + esc(m.marqueurs.join(' ')) + ' (doc ' + esc(m.document) + ' ligne ' + m.ligne_document + ')</span></li>';
    }).join('') + '</ul>' : '<p class="vide">aucun</p>';
    el('marqueurs').innerHTML = h || '<p class="vide">aucun marqueur pour ce document</p>';
  }

  /* ── rendu : ancrage, limites, auto-test ─────────────────────────────────────────────── */
  function rendreAncrage() {
    var h = '<table class="mini-tab"><tr><th>Document</th><th>Ancrage</th><th>HEAD</th><th>Mesure</th><th>Fichiers</th></tr>';
    G.documents.forEach(function (d) {
      h += '<tr><td>' + esc(d.id) + '</td><td>' + (d.ancrage.statut === 'ABSENT'
        ? '<span class="pill ko">ABSENT</span> <span class="mini">' + esc(d.ancrage.libelle) + '</span>'
        : '<span class="pill ok">' + esc(d.ancrage.id) + '</span> <span class="mini">' + esc(d.ancrage.etiquette) + '</span>') +
        '</td><td>' + esc((d.ancrage.head_document || '—').slice(0, 12)) + '</td><td>' + esc(d.ancrage.horodatage_mesure || '—') +
        '</td><td>' + d.ancrage.nb_fichiers_declares + '</td></tr>';
    });
    h += '</table>';
    h += '<p class="mini">Les fichiers cités par <b>T334</b> sont étiquetés <b>ancrage DÉRIVÉ</b> : ils reposent sur la table de blobs du §1.3 de l\'ANNEXE (' +
      esc(G.documents.filter(function (d) { return d.id === 'annexe'; })[0].ancrage.horodatage_mesure || '') +
      '), mesurée après coup. T334 ne porte <b>aucun</b> bloc d\'ancrage — c\'est le trou n°1 relevé par l\'annexe elle-même. ' +
      'Cet ancrage n\'est jamais présenté comme un ancrage de T334.</p>';
    var t = (F && F.totaux) || {};
    h += '<p>Constat figé : <b>' + t.fichiers + '</b> fichiers · <span class="pill ok">' + t.verts + ' vert</span> ' +
      '<span class="pill ' + (t.rouges ? 'ko' : 'info') + '">' + t.rouges + ' rouge</span> ' +
      '<span class="pill info">' + t.non_ancrables + ' non ancrable</span> · horodaté <b>' + esc(F ? F.meta.genere_le : '') + '</b></p>';
    var ko = (F ? F.fichiers : []).filter(function (x) { return x.etat !== 'VERT'; });
    if (ko.length) {
      h += '<table class="mini-tab"><tr><th>Fichier</th><th>État</th><th>Motif</th></tr>' + ko.map(function (x) {
        return '<tr><td class="mono">' + esc(x.chemin) + '</td><td>' + esc(x.etat) + '</td><td class="mini">' + esc(x.motif) + '</td></tr>';
      }).join('') + '</table>';
    }
    h += '<p class="mini"><b>Formule employée</b> : <code>' + esc(G.meta.hash_exact) + '</code> — ' +
      'soit exactement <code>git hash-object &lt;chemin&gt;</code> sur ce dépôt (core.autocrlf=true). ' +
      '<b>Piège mesuré</b> : <code>git hash-object --stdin</code> n\'applique PAS le filtre CRLF — la comparaison ' +
      'doit toujours porter sur un chemin de fichier.</p>';
    if (!EST_FILE) {
      var l = Object.keys(fraicheurLive).map(function (k) { return fraicheurLive[k]; });
      if (l.length) {
        h += '<table class="mini-tab"><tr><th>Fichier</th><th>Recalculé en direct</th><th>État</th></tr>' + l.map(function (x) {
          return '<tr><td class="mono">' + esc(x.chemin) + '</td><td class="mono mini">' + esc(x.blob_mesure || x.erreur) +
            '</td><td>' + esc(x.etat) + '</td></tr>';
        }).join('') + '</table>';
      }
    }
    el('panneau-ancrage').innerHTML = h;
  }

  function rendreAutotest() {
    var t = H ? H.autoTest() : { pass: false, vecteurs: [] };
    var h = '<p>Vecteurs vérifiés contre <code>git hash-object</code> sur cette machine : ' +
      (t.pass ? '<span class="pill ok">PASS</span>' : '<span class="pill ko">FAIL</span>') +
      ' <span class="mini">(ce test s\'exécute dans votre navigateur, à l\'ouverture de la page)</span></p>';
    h += '<table class="mini-tab"><tr><th>Vecteur</th><th>Attendu</th><th>Obtenu</th></tr>' + t.vecteurs.map(function (v) {
      return '<tr><td>' + esc(v.nom) + '</td><td class="mono mini">' + esc(v.attendu) + '</td><td class="mono mini">' +
        esc(v.obtenu) + ' ' + (v.pass ? '✅' : '❌') + '</td></tr>';
    }).join('') + '</table>';
    el('autotest').innerHTML = h;
  }

  /* ── rendu : corrections de références périmées (annexe §4.10, non fusionné) ───────────── */
  function rendreCorrections() {
    var c = G.corrections_references_perimees || [];
    var m = G.corrections_meta || {};
    if (!c.length) { el('corrections-perimees').innerHTML = '<p class="vide">—</p>'; return; }
    var h = '<p class="mini"><b>' + c.length + ' corrections</b> fournies par l\'annexe (§4.10) : ' +
      'pour un code de chaîne, la référence <b>citée par T334</b> et la <b>valeur correcte</b> mesurée par ' +
      'l\'audit. Ce sont des <b>lignes de correction</b>, jamais des maillons : elles ne sont pas fusionnées ' +
      'et n\'entrent pas dans l\'ordre chronologique.</p>';
    h += '<p class="mini">⚠ ' + esc(m.avertissement || '') + '</p>';
    h += '<table class="mini-tab"><tr><th>Code</th><th>Référence citée (périmée)</th><th>Valeur correcte</th>' +
      '<th>Ligne annexe</th></tr>' +
      c.map(function (x) {
        var cor = (x.refs_corrigees || []).map(function (r) { return texteRef(r); }).join(' · ');
        return '<tr><td class="mono">' + esc(x.code) + '</td><td class="mono mini">' +
          esc(x.ancienne_reference) + '</td><td class="mono mini">' + esc(cor) + '</td><td class="mini">' +
          x.ligne + '</td></tr>';
      }).join('') + '</table>';
    el('corrections-perimees').innerHTML = h;
  }

  /* ── rendu : références CONTESTÉES (couple fichier:ligne impossible) ───────────────────── */
  function rendreContestees() {
    var R = G.rapport_resolution;
    var con = R.refs_contestees_detail || [];
    var rer = R.refs_reroutees_detail || [];
    var ci = G.controle_invariants || {};
    var h = '<p class="mini"><b>Auto-contrôle des invariants</b> : <span class="pill ' +
      (ci.verdict === 'PASS' ? 'ok' : 'ko') + '">' + esc(ci.verdict || '?') + '</span> ' +
      ci.refs_controlees + ' références contrôlées · ' + ci.total_violations + ' violation(s) — ' +
      'aucune référence <code>RESOLUE</code> ne peut porter une ligne hors des bornes de son fichier. ' +
      '<span class="mini">' + esc((ci.invariants || [])[0] || '') + '</span></p>';
    h += '<p class="mini">Une <b>référence contestée</b> n\'est pas une référence non résolue : c\'est un ' +
      'couple <code>(fichier, ligne)</code> <b>impossible</b> — la fiche cite une ligne qui ne correspond à ' +
      '<b>aucune</b> ligne du fichier désigné. L\'outil ne l\'affiche jamais comme résolue. ' +
      '<b>C\'est une trouvaille de diagnostic</b> (rédaction relâchée des fiches, en lecture seule ici).</p>';
    h += '<p><span class="pill ' + (con.length ? 'warn' : 'ok') + '">' + con.length +
      ' contestée(s)</span> <span class="pill info">' + rer.length + ' reroutée(s) de façon vérifiable</span></p>';
    if (con.length) {
      h += '<table class="mini-tab"><tr><th>Origine</th><th>Cité</th><th>Fichier écarté</th><th>Raison</th></tr>' +
        con.map(function (e) {
          return '<tr><td class="mono">' + esc(e.maillon) + ' <span class="mini">(' + esc(e.zone || '') + ')</span></td>' +
            '<td class="mono">' + esc(e.brut) + '</td><td class="mono mini">' +
            esc(e.antecedent_ecarte || '') + ' <span class="mini">(' + esc(e.chemin_resolu_ecarte || '') + ')</span></td>' +
            '<td class="mini">' + esc(e.motif || '') + '</td></tr>';
        }).join('') + '</table>';
    }
    if (rer.length) {
      h += '<h3 style="font-size:13px;margin:10px 0 4px">Reroutées par règle nommée ' +
        '<code>E_CONTINUATION_HORS_BORNES_REROUTAGE</code></h3>' +
        '<table class="mini-tab"><tr><th>Maillon</th><th>Cité</th><th>Fichier écarté</th><th>Rerouté vers</th><th>Note</th></tr>' +
        rer.map(function (e) {
          return '<tr><td class="mono">' + esc(e.maillon) + '</td><td class="mono">' + esc(e.brut) +
            '</td><td class="mono mini">' + esc(e.antecedent_ecarte || '') + '</td><td class="mono">' +
            esc(e.chemin_resolu) + '</td><td class="mini">' + esc(e.note || '') + '</td></tr>';
        }).join('') + '</table>' +
        '<p class="mini">Règle volontairement étroite : reroutage accepté seulement s\'il existe ' +
        '<b>exactement un</b> autre fichier cité dans la <b>même cellule</b> ou la <b>même ligne de tableau</b> ' +
        'dont la plage contient la ligne. Sinon la référence reste CONTESTÉE — aucune heuristique d\'inférence.</p>';
    }
    var ca = G.controle_attendus || {};
    if (ca.attendus) {
      h += '<h3 style="font-size:13px;margin:10px 0 4px">Verrou des attendus de résolution ' +
        '<span class="pill ' + (ca.verdict === 'PASS' ? 'ok' : 'ko') + '">' + esc(ca.verdict) + ' ' +
        ca.conformes + '/' + ca.total + '</span></h3>' +
        '<p class="mini">Valeurs fournies par la revue et vérifiées dans les fiches : elles verrouillent ' +
        'l\'héritage des continuations pour <b>toutes</b> les formes d\'antécédent (chemin complet, nom nu, ' +
        '<b>abréviation</b> de préfixe, <b>alias documenté</b>). Toute régression fait échouer le parseur.</p>' +
        '<table class="mini-tab"><tr><th>Maillon</th><th>Cité</th><th>Attendu / obtenu</th><th>Forme d\'antécédent</th></tr>' +
        ca.attendus.map(function (a) {
          return '<tr><td class="mono">' + esc(a.maillon) + '</td><td class="mono">' + esc(a.brut) +
            '</td><td class="mono mini">' + esc(a.obtenu) + ' ' + (a.pass_ ? '✅' : '❌') +
            '</td><td class="mini">' + esc(a.forme_antecedent) + '</td></tr>';
        }).join('') + '</table>';
    }
    el('refs-contestees').innerHTML = h;
  }

  /* ── rendu : audit global des références (4e forme : ABRÉVIATION) ─────────────────────── */
  function rendreAudit() {
    var A = G.audit_references;
    if (!A) { el('audit-references').innerHTML = '<p class="vide">—</p>'; return; }
    var t = A.totaux;
    var h = '<p class="mini">Périmètre : <b>toutes zones</b> des 3 documents (chaînes, tableaux d\'audit, ' +
      'prose, journal) — donc plus large que le graphe, qui ne porte que les tableaux de chaîne. ' +
      'Les <b>4 formes</b> sont traitées séparément : chemin complet, nom de fichier, continuation, ' +
      '<b>abréviation</b> (préfixe d\'un POU : <code>PRG_04</code>, <code>FB_Winch</code>).</p>';
    h += '<table class="mini-tab"><tr><th>Document</th><th>Occurrences</th><th>Préfixe unique</th>' +
      '<th>AMBIGU</th><th>Alias curé</th><th>Troncature</th></tr>' +
      Object.keys(A.par_document).map(function (k) {
        var d = A.par_document[k];
        var pu = (d.prefixe_unique_total !== undefined ? d.prefixe_unique_total : d.prefixe_unique.length);
        var ac = (d.alias_contexte_cure_total !== undefined ? d.alias_contexte_cure_total : d.alias_contexte_cure.length);
        return '<tr><td>' + esc(k) + '</td><td>' + d.occurrences + '</td><td>' + pu +
          '</td><td>' + (d.prefixe_ambigu.length ? '<span class="pill warn">' + d.prefixe_ambigu.length + '</span>' : '0') +
          '</td><td>' + ac + '</td><td>' + d.troncature_ou_nom_introuvable.length + '</td></tr>';
      }).join('') + '</table>';
    h += '<table class="mini-tab"><tr><th>Traitement</th><th>Occurrences</th></tr>' +
      Object.keys(t).filter(function (k) { return typeof t[k] === 'number'; }).map(function (k) {
        return '<tr><td class="mono">' + esc(k) + '</td><td>' + t[k] + '</td></tr>';
      }).join('') + '</table>';
    var amb = [];
    if (A.par_document) Object.keys(A.par_document).forEach(function (k) {
      A.par_document[k].prefixe_ambigu.forEach(function (e) { amb.push([k, e]); });
    });
    if (amb.length) {
      h += '<h3 style="font-size:13px;margin:10px 0 4px">Préfixes AMBIGUS — jamais tranchés silencieusement</h3>' +
        '<table class="mini-tab"><tr><th>Doc · ligne</th><th>Référence</th><th>Candidats</th></tr>' +
        amb.map(function (x) {
          return '<tr><td class="mini">' + esc(x[0]) + ':' + x[1].ligne + '</td><td class="mono">' + esc(x[1].brut) +
            '</td><td class="mini">' + esc(x[1].candidats.map(function (c) { return c.split('/').pop(); }).join(' · ')) + '</td></tr>';
        }).join('') + '</table>';
    }
    var tro = [];
    Object.keys(A.par_document).forEach(function (k) {
      A.par_document[k].troncature_ou_nom_introuvable.forEach(function (e) { tro.push([k, e]); });
    });
    if (tro.length) {
      h += '<h3 style="font-size:13px;margin:10px 0 4px">Troncatures de prose / noms introuvables</h3>' +
        '<table class="mini-tab"><tr><th>Doc · ligne</th><th>Référence</th><th>Motif</th></tr>' +
        tro.map(function (x) {
          return '<tr><td class="mini">' + esc(x[0]) + ':' + x[1].ligne + '</td><td class="mono">' + esc(x[1].brut) +
            '</td><td class="mini">' + esc(x[1].motif || '') + '</td></tr>';
        }).join('') + '</table>';
    }
    var ci = A.controle_anti_invention || { chemins_inventes: '?' };
    h += '<p class="mini">Contrôle anti-invention : <span class="pill ' + (ci.chemins_inventes === 0 ? 'ok' : 'ko') + '">' +
      ci.chemins_inventes + ' chemin inventé</span> — aucun alias n\'est converti en fichier ' +
      '(<code>M1.st</code>, <code>PRG_04.st</code>) : les abréviations se résolvent par préfixe UNIQUE, ' +
      'les alias par une table curée dont la provenance est citée et vérifiée, le reste est AMBIGU ou NON RÉSOLU.</p>';
    el('audit-references').innerHTML = h;
  }

  function rendreLimites() {    el('limites').innerHTML = '<ul class="liste">' + G.limites.map(function (l) {
      return '<li><span class="pill ' + (l.gravite === 'BLOQUANT' ? 'ko' : (l.gravite === 'MAJEUR' ? 'warn' : 'info')) + '">' +
        esc(l.gravite) + '</span> <b>' + esc(l.titre) + '</b><br>' + esc(l.detail) +
        '<br><span class="mini">source : ' + esc(l.source) + '</span></li>';
    }).join('') + '</ul>' +
    '<p class="mini">Résolution des références : <b>' + (G.rapport_resolution.par_categorie.RESOLUE) + '</b> résolues / ' +
    G.rapport_resolution.par_categorie.AMBIGUE + ' ambiguës / ' + G.rapport_resolution.par_categorie.NON_RESOLUE +
    ' non résolues — une référence non résolue est <b>affichée comme telle</b>, jamais remplacée par une supposition.</p>';
  }

  /* ── mode live : recalcul des blobs ──────────────────────────────────────────────────── */
  function recalculer() {
    if (EST_FILE) return;
    var liste = (F && F.fichiers ? F.fichiers : []).map(function (x) { return x.chemin; });
    var i = 0;
    function suivant() {
      if (i >= liste.length) { rendreBandeau(); rendreMaillons(); rendreAncrage(); rendreNonEmpruntee(); rendreMarqueurs(); return; }
      var chemin = liste[i++];
      var url = new URL('../../' + chemin, location.href).href;
      fetch(url).then(function (r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.arrayBuffer();
      }).then(function (buf) {
        var res = H.gitBlobSha1(new Uint8Array(buf));
        var consigne = (fraicheur[chemin] || {}).blob_consigne;
        var e = (consigne === undefined || consigne === null) ? 'NON_ANCRABLE' : (res.sha1_git === consigne ? 'VERT' : 'ROUGE');
        fraicheurLive[chemin] = {
          chemin: chemin, blob_mesure: res.sha1_git, blob_mesure_brut: res.sha1_brut,
          taille_brute: res.taille_brute, taille_normalisee: res.taille_normalisee,
          crlf_converti: res.crlf_converti, normalisation: res.normalisation,
          etat: e, mesure_le: new Date().toISOString(), erreur: null
        };
      }).catch(function (err) {
        fraicheurLive[chemin] = { chemin: chemin, blob_mesure: null, etat: 'ABSENT', erreur: String(err), mesure_le: new Date().toISOString() };
      }).then(suivant);
    }
    suivant();
  }

  /* ── démarrage ───────────────────────────────────────────────────────────────────────── */
  (F && F.fichiers ? F.fichiers : []).forEach(function (x) { fraicheur[x.chemin] = x; });
  rendreSelecteurs();
  rendreBandeau();
  rendreTout();
  rendreAutotest();
  recalculer();

  function rendreTout() {
    rendreMaillons();
    rendreNonEmpruntee();
    rendreMarqueurs();
    rendreAncrage();
    rendreCorrections();
    rendreContestees();
    rendreAudit();
    rendreLimites();
  }
})();
