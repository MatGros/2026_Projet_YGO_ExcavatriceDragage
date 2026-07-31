import os, subprocess, sys, pathlib
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

def run(*cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace')
    print('$', ' '.join(cmd[:3]), 'rc=', r.returncode)
    if r.stdout.strip(): print(r.stdout.strip()[-500:])
    if r.stderr.strip(): print('ERR:', r.stderr.strip()[-400:])

scratch = ['_c.txt', '_commit.py', '_f.txt', '_fix.py', '_o.txt', '_s.py', '_r.txt', '_out.txt', '_cleanup.py']
tracked = [f for f in scratch if subprocess.run(['git', 'ls-files', '--error-unmatch', f],
                                                capture_output=True).returncode == 0]
if tracked:
    run('git', 'rm', '--cached', '-q', *tracked)

# guard: empecher toute nouvelle fuite de scratchs d'agent a la racine
gi = pathlib.Path('.gitignore')
t = gi.read_text(encoding='utf-8')
if '_scratch d agent' not in t:
    t += ("\n# Scratchs d'agent a la racine (fichiers de travail temporaires, jamais du livrable).\n"
          "# Ajoute apres deux fuites accidentelles dans des commits (2026-08).\n"
          "/_*.py\n/_*.txt\n/_*.log\n")
    gi.write_text(t, encoding='utf-8')

for f in scratch:
    if os.path.exists(f):
        os.remove(f)

run('git', 'add', '-A')
run('git', 'commit', '-m',
    "chore: ignorer les scratchs d agent a la racine (_*.py/_*.txt)\n\n"
    "Deux commits de suite ont embarque des fichiers de travail temporaires.\n"
    "guard: motif /_*.py /_*.txt /_*.log dans .gitignore, plutot que de compter\n"
    "sur la vigilance a chaque commit.")
run('git', 'push')
run('git', 'status', '--short')
