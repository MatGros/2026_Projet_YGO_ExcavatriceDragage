import os, subprocess, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
for f in ['_cleanup.py', '_r.txt', '_scan.py']:
    if os.path.exists(f):
        os.remove(f)

MSG = """refactor(TOOLS): convention de nommage ST2PY core/scripts/suites/RESULTS

Probleme (signale a l'usage) : la racine de OUTILS_ST2PY melangeait bibliotheque
importable, scripts CLI et suite pytest, avec un dossier `tests/` ambigu (tests DE
l'outil) face a `out/` (ce que l'outil PRODUIT), le tout a plat sans lien visible
avec les fonctions machine reelles.

Trois roles, trois noms :
- core/     bibliotheque importable (fb_gen, canonicalize, changed_gen,
            data_contracts, simulation_bench, test_tracer) + results_layout.py
- scripts/  outils CLI autonomes (check_test_registry, visualize_py_module,
            st_to_py, tools_compute_hash, position_decoder_demo)
- suites/   suite pytest de l'outil (ex-`tests/`, nom ambigu), inchangee dans
            son decoupage contracts/generation/simulation

Artefacts ranges par domaine machine (miroir de CODE/ et de l'analyse
fonctionnelle), a la place de `out/` a plat :
  RESULTS/{AU,TRANSLATION,COMMUN,_ARCHIVE}/{modules,reports,chronicles}/
Les diagrammes UML/FSM rejoignent chronicles/ du meme domaine : un rapport de
test et son diagramme se lisent ensemble, plus dans DOC/DIAGRAMS/TESTS/ isole.
Le mapping POU -> domaine est centralise dans core/results_layout.py, seul
endroit a mettre a jour quand une fonction machine apparait.

Nettoyage :
- TOOLS/ST2PONE/ supprime : doublon abandonne, non reference, version moins a
  jour que la copie deja archivee.
- TOOLS/OUTILS_ST2PY/legacy/ -> ARCHIVES/Tools/OUTILS_ST2PY_legacy/ (prototype
  hors service, conserve pour historique, README marque ARCHIVE).
- .gitignore suit RESULTS/ ; tests_dir_marker (artefact vide) retire.

Verifications :
- pytest suites -> 19 passed
- check_test_registry.py --report -> PASS (19 tests traces)
- check_doc_links.py -> PASS (a detecte les 4 chemins periemes du README,
  corriges dans ce commit)
- check_cfc_wiring.py -> PASS (3 warnings preexistants sur PRG_GLOBAL_CFC.xml)
- check_linkage.py -> PASS (99 instances)
- scripts deplaces reexecutes : position_decoder_demo, run_translation_m3_catalog,
  visualize_py_module (7 UML + 1 FSM regeneres au bon endroit)
"""

for cmd in (['git', 'add', '-A'], ['git', 'commit', '-m', MSG], ['git', 'push']):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace')
    print('$', ' '.join(cmd[:2]), '-> rc=', r.returncode)
    print((r.stdout or '')[-1500:])
    if r.stderr.strip():
        print('ERR:', r.stderr[-1200:])
