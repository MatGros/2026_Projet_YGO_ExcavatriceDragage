#!/usr/bin/env python3
"""
changed_gen.py

Détecte les fichiers modifiés depuis une référence git et génère les FB concernés via fb_gen.py.
Usage:
  python changed_gen.py --ref origin/main --out <outdir> [--force]

Comportement:
 - exécute `git diff --name-only <ref>..HEAD`
 - si CODE/CODE_Bundle.xml est modifié => parcourt le bundle et génère tous les POUs
 - sinon, pour chaque fichier .st modifié sous CODE/, extrait le nom du POU et appelle fb_gen
"""
import argparse
import subprocess
import os
import sys
import re
import xml.etree.ElementTree as ET

NS = {'pc': 'http://www.plcopen.org/xml/tc6_0200'}


def git_changed_files(ref):
    cmd = ['git', 'diff', '--name-only', f'{ref}..HEAD']
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        print('git diff failed:', p.stderr)
        sys.exit(2)
    files = [l.strip() for l in p.stdout.splitlines() if l.strip()]
    return files


def extract_pou_from_st(path):
    # naive parse: look for line starting with FUNCTION_BLOCK PUBLIC <name>
    prog = re.compile(r'^\s*FUNCTION_BLOCK\s+PUBLIC\s+([A-Za-z0-9_]+)', re.IGNORECASE)
    try:
        with open(path, 'r', encoding='utf-8') as f:
            for line in f:
                m = prog.match(line)
                if m:
                    return m.group(1)
    except Exception as e:
        print('Error reading', path, e)
    return None


def list_pous_from_bundle(bundle_path):
    tree = ET.parse(bundle_path)
    root = tree.getroot()
    names = []
    for pou in root.findall('.//pc:pou', NS):
        name = pou.get('name')
        if name:
            names.append(name)
    return names


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--ref', default='origin/main')
    p.add_argument('--out', required=True)
    p.add_argument('--bundle', default=os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'CODE', 'CODE_Bundle.xml')))
    p.add_argument('--force', action='store_true')
    args = p.parse_args()

    files = git_changed_files(args.ref)
    print('Changed files since', args.ref, ':', len(files))
    # If bundle changed, generate all POUs
    bundle_rel = os.path.relpath(os.path.abspath(args.bundle)).replace('\\', '/')
    generate_all = False
    if any(f.replace('\\','/') == bundle_rel or os.path.basename(f) == os.path.basename(bundle_rel) for f in files):
        generate_all = True

    to_generate = []
    if generate_all:
        print('Bundle changed: will generate all POUs from bundle')
        pou_names = list_pous_from_bundle(args.bundle)
        to_generate = pou_names
    else:
        for f in files:
            if f.endswith('.st') and f.startswith('CODE'):
                pou = extract_pou_from_st(f)
                if pou:
                    to_generate.append(pou)
                else:
                    print('Warning: could not extract POU name from', f)

    if not to_generate:
        print('No POUs to generate. Exiting.')
        sys.exit(0)

    # call fb_gen for each
    script = os.path.join(os.path.dirname(__file__), 'fb_gen.py')
    for pou in sorted(set(to_generate)):
        cmd = [sys.executable, script, '--bundle', args.bundle, '--pou', pou, '--out', args.out]
        if args.force:
            cmd.append('--force')
        print('Calling:', ' '.join(cmd))
        p = subprocess.run(cmd)
        if p.returncode != 0:
            print('fb_gen failed for', pou, 'exit', p.returncode)

if __name__ == '__main__':
    main()
