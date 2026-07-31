import os, subprocess, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

def run(*cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace')
    print('$', ' '.join(cmd[:3]), 'rc=', r.returncode)
    if r.stdout.strip():
        print(r.stdout[-800:])
    if r.stderr.strip():
        print('ERR:', r.stderr[-600:])
    return r

run('git', 'rm', '--cached', '-q', '_c.txt', '_commit.py')
for f in ['_c.txt', '_commit.py']:
    if os.path.exists(f):
        os.remove(f)
run('git', 'commit', '-m',
    'chore: retirer les scratchs d agent commites par erreur (_c.txt, _commit.py)')
run('git', 'push')
run('git', 'status', '--short')
