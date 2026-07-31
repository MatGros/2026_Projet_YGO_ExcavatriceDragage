import os, subprocess, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
for f in ['_s.py', '_o.txt']:
    if os.path.exists(f):
        os.remove(f)

MSG = """fix(TOOLS): le catalogue M3 devient un vrai test (il ne testait rien)

Bug reel, pas une reorganisation : `functional_tests/run_translation_m3_catalog.py`
executait les 4 scenarios du catalogue puis ecrivait `'status': 'passed'` EN DUR,
sans jamais comparer a la colonne `expected_result`. Un FB_Translation completement
casse aurait affiche 4 lignes vertes. Le script n'etait dans aucun gate, dans aucune
suite pytest, et absent de TEST_REGISTRY.md : rien ne cassait s'il regressait.

fix:   suites/contracts/test_translation_m3_catalog.py -- chaque ligne du CSV devient
       un cas pytest parametre (ids = AF-TR-01..04) et les colonnes expect_* sont
       reellement comparees a l'etat du FB apres scenario. Un scenario inconnu
       leve une erreur au lieu de tomber dans une branche par defaut silencieuse.
guard: les 4 cas sont enregistres dans TEST_REGISTRY.md, donc couverts par
       check_test_registry.py ; ils tournent dans `pytest suites`.

Le CSV (suites/catalogs/) reste la source : une ligne = un cas, ajouter un scenario
fonctionnel ne demande pas de Python. Colonnes `expected_result`/`notes` en prose
remplacees par des colonnes verifiables expect_state/ready/done/error/error_id.

Correction de fond au passage : le scenario reset_recover ne relachait pas SafeStop
avant le Reset. Il testait donc un rearmement sous cause toujours presente, ce que la
regle projet interdit (Reset = front, cause disparue + appui conscient).

`functional_tests/` supprime : son seul contenu utile (le CSV) est migre, son runner
etait le faux test decrit ci-dessus.

Verifications :
- pytest suites -> 23 passed (19 + 4 nouveaux cas catalogue)
- mutation test : en forcant AF-TR-03 a attendre DONE au lieu de FAULT, la suite
  passe bien a `1 failed, 3 passed` avec un message lisible -> le test peut echouer,
  donc il prouve quelque chose (ce que l'ancien runner ne pouvait pas)
- check_test_registry.py --report -> PASS (20 tests traces)
- check_doc_links.py -> PASS
"""

for cmd in (['git', 'add', '-A'], ['git', 'commit', '-m', MSG], ['git', 'push']):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace')
    print('$', ' '.join(cmd[:2]), 'rc=', r.returncode)
    out = (r.stdout or '').strip().splitlines()
    print('\n'.join(out[-6:]))
    if r.stderr.strip():
        print('ERR:', r.stderr.strip().splitlines()[-3:])
