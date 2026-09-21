#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=====================================================================
 T372 — Génération d'un template de trace CODESYS (.trace)
---------------------------------------------------------------------
 Transforme un fichier .trace RÉEL (modèle) : il prend la liste de
 variables + un nom d'enregistrement (+ optionnellement un trigger) et
 réécrit la <TraceConfiguration> en conservant TOUT ce qui rend le
 fichier importable (schémas d'axe, GUID d'archivage, section
 Diagrams/ReferencedVarGuid, version), sans rien « réinventer ».

 -> Approche retenue : TEMPLATE TRANSFORMÉ (le plus fiable), PAS un
    générateur XML from-scratch. La base est un fichier .trace réel.
    C'est la réponse au « devoir de challenge » du brief T372.

 Preuve de validité intégrée (--selftest) :
   régénérer la config avec l'EXACTE liste de variables du modèle =>
   la <TraceConfiguration> produite est BYTE-À-BYTE identique au modèle.

 Format fichier cible (prouvé sur 81 fichiers réels du dépôt) :
   UTF-16 LE avec BOM · retours à la ligne CRLF · racine <Trace>.
   <Trace>
     <TraceConfiguration> ... config des variables / trigger / axes ...
     <TraceData Version="1.0.0.0"> ... échantillons enregistrés (optionnel)

 NON PROUVÉ (signalé, pas deviné) :
   - l'encodage d'un TRIGGER ACTIF (variable+condition+mode) : aucun des
     81 .trace du dépôt n'a de trigger configuré (TriggerVariable vide,
     TriggerEdge=None, TriggerFlags=Undefined partout). Un trigger demandé
     est écrit en best-effort avec un avertissement — à valider contre un
     fichier réel avec trigger avant utilisation en production.
   - l'import CODESYS d'un <TraceData> vide : à vérifier humainement dans
     l'IDE (agent sans accès CODESYS). Par défaut on émet un TraceData
     vide ; `--keep-data` réutilise celui du modèle.

 Hors périmètre PLC : ne modifie AUCUN fichier CODE/.
==========================================================================
"""
from __future__ import annotations
import argparse, colorsys, os, re, sys, uuid

VAR_SINGLE = '{b6a18d24-a045-4a81-a2ac-7044c6f553c0}'
REF_SINGLE = '{8d42fb88-c20c-44ee-9563-111d64032744}'
VAR_OPENER = '<Single Type="' + VAR_SINGLE + '"'   # ouverture complète du bloc variable
REF_OPENER = '<Single Type="' + REF_SINGLE + '"'    # ouverture complète du bloc ReferencedVarGuid

DEFAULT_TEMPLATE = os.path.join(
    os.path.dirname(__file__), '..', 'RESULTS', 'trace',
    'Suivi_Cycle_M3_20260906_49.trace')


# ------------------------------------------------------- couleurs par thème
# Déterministe : même liste de variables => mêmes couleurs. Une hue distincte
# par "thème" (chemin parent), et des teintes voisines (luminosité variable)
# pour chaque variable D'UN MÊME groupe -> distinguables sans perdre le repère
# visuel de groupe. Encode en ARGB int signé (0xFFRRGGBB), identique au
# GraphColor des fichiers réels (ex. -16776961 = rouge).
_HUE_PALETTE = [0.00, 0.08, 0.16, 0.25, 0.33, 0.42, 0.50, 0.58, 0.66, 0.75, 0.83, 0.92]


def group_key(variable: str) -> str:
    i = variable.rfind('.')
    return variable[:i] if i > 0 else variable


def graphcolor_by_group(group_index: int, index_in_group: int, group_size: int) -> int:
    hue = _HUE_PALETTE[group_index % len(_HUE_PALETTE)]
    light = 0.45 if group_size <= 1 else 0.45 + 0.28 * index_in_group / (group_size - 1)
    r, g, b = colorsys.hls_to_rgb(hue, light, 0.78)
    v = (0xFF000000 | ((round(b * 255) & 0xFF) << 16)
         | ((round(g * 255) & 0xFF) << 8) | (round(r * 255) & 0xFF))
    return v - 0x100000000 if v >= 0x80000000 else v


# ---------------------------------------------------------------- helpers
def read_trace(path: str) -> str:
    """Lit un .trace en UTF-16, sans traduction de fins de ligne (CRLF préservés)."""
    with open(path, encoding='utf-16', newline='') as f:
        return f.read()


def write_trace(path: str, txt: str) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, 'w', encoding='utf-16', newline='') as f:
        f.write(txt)


def balanced_close(txt: str, open_i: int) -> int:
    """Retourne l'index juste APRÈS le tag fermant équilibré du tag ouvert
    à open_i (open_i pointe sur '<')."""
    m = re.match(r'</?\s*([a-zA-Z][a-zA-Z0-9]*)', txt[open_i:])
    if not m:
        raise ValueError(f'pas de tag à l\'index {open_i}')
    tag = m.group(1)
    pat = re.compile(r'</?' + re.escape(tag) + r'(?![a-zA-Z0-9])')
    depth = 0
    for mm in pat.finditer(txt, open_i):
        tok = mm.group(0)
        if tok.startswith('</'):
            depth -= 1
            if depth == 0:
                pos = mm.end()
                if pos < len(txt) and txt[pos] == '>':
                    pos += 1            # après le chevron fermant
                return pos
        else:
            depth += 1
    raise ValueError(f'{tag} non équilibré à partir de {open_i}')


def split_blocks(txt: str, start: int, end: int, opener: str):
    """Découpe [start,end) en items (texte/bloc). Les blocs commencent par `opener`.
    Retourne (items, texts, blocks) où items = liste de ('text',s)/('block',s),
    texts = liste des segments texte, blocks = liste des blocs bruts."""
    items, texts, blocks = [], [], []
    pos = start
    while True:
        i = txt.find(opener, pos)
        if i < 0 or i >= end:
            if pos < end:
                t = txt[pos:end]
                items.append(('text', t)); texts.append(t)
            break
        t = txt[pos:i]
        items.append(('text', t)); texts.append(t)
        c = balanced_close(txt, i)
        b = txt[i:c]
        items.append(('block', b)); blocks.append(b)
        pos = c
    return items, texts, blocks


# ---------------------------------------------------------------- parsing
def parse_variables(cfg: str):
    """Retourne (start_open, content_start, close_index, texts, blocks, names, guids)
    pour la région Interior InnerList."""
    o = cfg.find('<List Name="InnerList"')
    if o < 0:
        raise ValueError('<List Name="InnerList"> introuvable dans la config')
    open_end = cfg.index('>', o) + 1
    close = balanced_close(cfg, o)          # index juste après '</List>'
    items, texts, blocks = split_blocks(cfg, open_end, close - len('</List>'), VAR_OPENER)
    names = []
    guids = []
    for b in blocks:
        nm = re.search(r'<Single Name="VariableName" Type="string">([^<]*)</Single>', b)
        names.append(nm.group(1) if nm else None)
        g = re.search(r'<Single Name="guid" Type="System.Guid">([^<]*)</Single>', b)
        guids.append(g.group(1) if g else None)
    return dict(open_end=open_end, close=close, texts=texts, blocks=blocks,
                names=names, guids=guids)


def parse_refguids(cfg: str):
    """Retourne (open_end, close, texts, blocks, guids) de la région
    <List2 Name="Variables"> (section Diagrams)."""
    o = cfg.find('<List2 Name="Variables">')
    if o < 0:
        return None
    open_end = o + len('<List2 Name="Variables">')
    close = balanced_close(cfg, o)  # après </List2>
    items, texts, blocks = split_blocks(cfg, open_end, close - len('</List2>'), REF_OPENER)
    guids = []
    for b in blocks:
        g = re.search(r'<Single Name="ReferencedVarGuid" Type="System.Guid">([^<]*)</Single>', b)
        guids.append(g.group(1) if g else None)
    return dict(open_end=open_end, close=close, texts=texts, blocks=blocks, guids=guids)


def make_var_block(proto: str, name: str, guid: str, graph_color: int | None = None) -> str:
    b = re.sub(r'(<Single Name="VariableName" Type="string">)[^<]*(</Single>)',
               lambda m: m.group(1) + name + m.group(2), proto, count=1)
    b = re.sub(r'(<Single Name="guid" Type="System.Guid">)[0-9a-f\-]+(</Single>)',
               lambda m: m.group(1) + guid + m.group(2), b, count=1)
    if graph_color is not None:
        b = re.sub(r'(<Single Name="GraphColor" Type="int">)[-0-9]+(</Single>)',
                   lambda m: m.group(1) + str(graph_color) + m.group(2), b, count=1)
    return b


def make_ref_block(proto: str, guid: str) -> str:
    return re.sub(r'(<Single Name="ReferencedVarGuid" Type="System.Guid">)[^<]*(</Single>)',
                  lambda m: m.group(1) + guid + m.group(2), proto, count=1)


def rebuild_region(texts, blocks_out):
    """Réassemble une région découpée : texts[0] puis chaque bloc suivi du
    séparateur texte correspondant (recyclé pour les blocs excédentaires)."""
    seps = texts[1:]
    s = texts[0] if texts else ''
    for i, blk in enumerate(blocks_out):
        s += blk
        if i < len(seps):
            s += seps[i]
        elif seps:
            s += seps[-1]
    return s


# ---------------------------------------------------------------- trigger
def apply_trigger(cfg: str, args) -> str:
    """Remplace les champs de trigger. BEST-EFFORT : l'encodage d'un trigger
    actif n'est PAS prouvé sur les exemples du dépôt (tous vide/None)."""
    changed = False
    if args.trigger_var is not None:
        cfg = re.sub(r'(<Single Name="TriggerVariable" Type="string">)[^<]*(</Single>)',
                     lambda m: m.group(1) + args.trigger_var + m.group(2), cfg, count=1)
        changed = True
    if args.trigger_edge is not None:
        cfg = re.sub(r'(<Single Name="TriggerEdge" Type="\{33a32e6c-d512-4195-9e73-520baca05512\}">)[^<]*(</Single>)',
                     lambda m: m.group(1) + args.trigger_edge + m.group(2), cfg, count=1)
        changed = True
    if args.trigger_level is not None:
        cfg = re.sub(r'(<Single Name="TriggerLevel" Type="string">)[^<]*(</Single>)',
                     lambda m: m.group(1) + args.trigger_level + m.group(2), cfg, count=1)
        changed = True
    if args.trigger_position is not None:
        cfg = re.sub(r'(<Single Name="TriggerPosition" Type="byte">)[^<]*(</Single>)',
                     lambda m: m.group(1) + str(args.trigger_position) + m.group(2), cfg, count=1)
        # PostTriggerSamples suit TriggerPosition (cohérent)
        cfg = re.sub(r'(<Single Name="PostTriggerSamples" Type="uint">)[^<]*(</Single>)',
                     lambda m: m.group(1) + str(args.trigger_position) + m.group(2), cfg, count=1)
        changed = True
    if args.condition is not None:
        cfg = re.sub(r'(<Single Name="Condition" Type="string">)[^<]*(</Single>)',
                     lambda m: m.group(1) + args.condition + m.group(2), cfg, count=1)
        changed = True
    if changed:
        print('[AVERTISSEMENT] Trigger best-effort écrit — encodage NON PROUVÉ '
              'sur les exemples du dépôt (aucun trigger actif présent). '
              'À valider contre un .trace réel avec trigger.', file=sys.stderr)
    return cfg


# ---------------------------------------------------------------- core
def generate(template_path: str, variables: list[str], record_name: str,
             trigger=None, keep_data: bool = False) -> str:
    txt = read_trace(template_path)
    ci = txt.find('<TraceConfiguration>')
    co = txt.find('</TraceConfiguration>')
    if ci < 0 or co < 0:
        raise ValueError('racines <TraceConfiguration> introuvables')
    prefix = txt[:ci + len('<TraceConfiguration>')]
    suffix = txt[co:]
    cfg = txt[ci + len('<TraceConfiguration>'):co]

    vip = parse_variables(cfg)
    vblocks_out = []
    vguids_out = []
    used = [False] * len(vip['blocks'])
    name_idx = {}
    for i, n in enumerate(vip['names']):
        if n is not None:
            name_idx[n] = name_idx.get(n, []) + [i]

    # groupes (thème = chemin parent) pour l'assignement couleur des Nouvelles
    # variables ; les blocs réutilisés gardent leur couleur d'origine du modèle.
    group_order = []
    group_lists = {}
    for name in variables:
        gk = group_key(name)
        if gk not in group_lists:
            group_lists[gk] = []
            group_order.append(gk)
        group_lists[gk].append(name)

    for name in variables:
        idx_list = name_idx.get(name, [])
        chosen = next((i for i in idx_list if not used[i]), None)
        if chosen is not None:
            used[chosen] = True
            b = vip['blocks'][chosen]
            g = vip['guids'][chosen]
        else:
            gk = group_key(name)
            color = graphcolor_by_group(group_order.index(gk),
                                        group_lists[gk].index(name),
                                        len(group_lists[gk]))
            b = make_var_block(vip['blocks'][0], name, str(uuid.uuid4()), color)
            g = re.search(r'<Single Name="guid" Type="System.Guid">([^<]*)</Single>', b).group(1)
        vblocks_out.append(b)
        vguids_out.append(g)

    new_inner = rebuild_region(vip['texts'], vblocks_out)
    new_cfg = cfg[:vip['open_end']] + new_inner + cfg[vip['close'] - len('</List>'):]

    # Section Diagrams/ReferencedVarGuid.
    # ATTENTION : dans le .trace réel, l'ordre des ReferencedVarGuid n'est PAS
    # aligné sur l'ordre de la VariableList (démontré sur Suivi_Cycle_M3_...).
    #  -> liste identique au modèle : on LAISSE la section telle quelle
    #     (elle référence déjà les bons guids) => identité byte-à-byte.
    #  -> liste différente         : on reconstruit 1 ReferencedVarGuid par
    #     variable cible, dans l'ordre des variables (ordre d'affichage libre).
    same_list = (list(variables) == [n for n in vip['names'] if n is not None])
    if not same_list:
        rp = parse_refguids(new_cfg)
        if rp is not None:
            rblocks_out = []
            for g in vguids_out:
                proto = rp['blocks'][0] if rp['blocks'] else (
                    '<Single Type="%s" Method="IArchivable">\n'
                    '                <Single Name="ReferencedVarGuid" Type="System.Guid">%s</Single>\n'
                    '              </Single>' % (REF_SINGLE, g))
                rblocks_out.append(make_ref_block(proto, g))
            new_rg = rebuild_region(rp['texts'], rblocks_out)
            new_cfg = new_cfg[:rp['open_end']] + new_rg + new_cfg[rp['close'] - len('</List2>'):]

    # RecordName
    new_cfg = re.sub(r'(<Single Name="RecordName" Type="string">)[^<]*(</Single>)',
                     lambda m: m.group(1) + record_name + m.group(2), new_cfg, count=1)

    if trigger:
        new_cfg = apply_trigger(new_cfg, trigger)

    # TraceData : par défaut on émet un TraceData vide ; --keep-data réutilise
    # celui du modèle (config seule => import non vérifié, cf. docstring).
    after = suffix                      # suffix commence à '</TraceConfiguration>'
    if keep_data:
        new_txt = prefix + new_cfg + suffix
    else:
        td = after.find('<TraceData')
        if td < 0:
            # pas de TraceData dans le modèle : on ne force rien
            new_txt = prefix + new_cfg + after
        else:
            head = after[:td]                                    # '</TraceConfiguration>' + blancs
            td_close = balanced_close(after, td)                 # après '</TraceData>' du modèle
            tail = after[td_close:]
            new_txt = (prefix + new_cfg + head
                       + '<TraceData Version="1.0.0.0"></TraceData>' + tail)
    return new_txt


# ---------------------------------------------------------------- CLI
def load_variables(arg_list, var_file):
    vars_ = []
    if var_file:
        with open(var_file, encoding='utf-8-sig') as f:
            for ln in f:
                ln = ln.split('#')[0].strip()
                if ln:
                    vars_.append(ln)
    if arg_list:
        for part in arg_list:
            for v in [x for x in part.split(',') if x.strip()]:
                if v not in vars_:
                    vars_.append(v)
    return vars_


def main():
    p = argparse.ArgumentParser(
        description='Génère un template .trace CODESYS à partir d\'un .trace modèle '
                    '+ liste de variables (+ trigger best-effort).')
    p.add_argument('--template', default=DEFAULT_TEMPLATE,
                   help='.trace réel servant de modèle (défaut: un échantillon du dépôt)')
    p.add_argument('--variables', nargs='*', default=[],
                   help='chemins complets de variables (ou liste séparée par virgules)')
    p.add_argument('--var-file', '-f', default=None,
                   help='fichier de variables (une par ligne, # = commentaire)')
    p.add_argument('--record-name', '-n', default='Trace',
                   help='nom de l\'enregistrement (RecordName)')
    p.add_argument('--output', '-o', default=None, help='fichier .trace de sortie')
    p.add_argument('--keep-data', action='store_true',
                   help='réutilise les échantillons (TraceData) du modèle (défaut: vide)')
    p.add_argument('--selftest', action='store_true',
                   help='régénère le modèle avec sa propre liste et vérifie '
                        'l\'identité byte-à-byte de la <TraceConfiguration>')
    # trigger best-effort
    g = p.add_argument_group('trigger (NON PROUVÉ — best-effort)')
    g.add_argument('--trigger-var', default=None)
    g.add_argument('--trigger-edge', default=None,
                   help='ex: Rising/Falling/OnLevel (valeur d\'enum à valider)')
    g.add_argument('--trigger-level', default=None)
    g.add_argument('--trigger-position', type=int, default=None)
    g.add_argument('--condition', default=None)
    args = p.parse_args()

    if args.selftest:
        tmpl = read_trace(args.template)
        ci = tmpl.find('<TraceConfiguration>'); co = tmpl.find('</TraceConfiguration>')
        cfg_src = tmpl[ci + len('<TraceConfiguration>'):co]
        vip = parse_variables(cfg_src)
        names = [n for n in vip['names'] if n is not None]
        gen = generate(args.template, names,
                       record_name=re.search(r'<Single Name="RecordName" Type="string">([^<]*)</Single>',
                                              cfg_src).group(1))
        gci = gen.find('<TraceConfiguration>'); gco = gen.find('</TraceConfiguration>')
        cfg_gen = gen[gci + len('<TraceConfiguration>'):gco]
        rn_src = re.search(r'<Single Name="RecordName" Type="string">([^<]*)</Single>', gen).group(1)
        rn_cfg = re.search(r'<Single Name="RecordName" Type="string">([^<]*)</Single>', cfg_src).group(1)
        if cfg_gen == cfg_src:
            print(f'SELFTEST OK  — {len(names)} var(s) : '
                  f'<TraceConfiguration> byte-à-byte identique au modèle ({args.template})')
            print(f'              RecordName produit : "{rn_src}" (modèle "{rn_cfg}")')
            return 0
        else:
            # localiser la 1re divergence
            for i, (a, b) in enumerate(zip(cfg_gen, cfg_src)):
                if a != b:
                    print(f'SELFTEST FAIL — divergence à l\'octet {i} : '
                          f'gen={cfg_gen[i:i+60]!r} src={cfg_src[i:i+60]!r}', file=sys.stderr)
                    break
            else:
                print(f'SELFTEST FAIL — longueurs différentes '
                      f'({len(cfg_gen)} vs {len(cfg_src)})', file=sys.stderr)
            return 1

    variables = load_variables(args.variables, args.var_file)
    if not variables:
        p.error('au moins une variable (--variables ou --var-file) ou --selftest requis')
    if len(set(variables)) != len(variables):
        p.error('variables en doublon — dédoublonne la liste d\'entrée')

    trigger = None
    if (args.trigger_var or args.trigger_edge or args.trigger_level
            or args.trigger_position is not None or args.condition):
        trigger = args

    out = generate(args.template, variables, args.record_name,
                   trigger=trigger, keep_data=args.keep_data)

    if args.output:
        write_trace(args.output, out)
        print(f'OK  — {len(variables)} variable(s) -> {os.path.abspath(args.output)}')
        print(f'     modèle           : {os.path.abspath(args.template)}')
        print(f'     RecordName       : "{args.record_name}"')
        print(f'     TraceData        : {"réutilisé (modèle)" if args.keep_data else "vide"}')
    else:
        sys.stdout.write(out)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
