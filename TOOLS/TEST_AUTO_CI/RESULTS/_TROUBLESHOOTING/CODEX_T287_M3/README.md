# CODEX_T287_M3 — scénarios exploratoires

Ces scénarios servent à rechercher et mesurer le comportement des butées M3 pendant T287.
Ils ne sont **pas** des tests CI de non-régression et ne sont pas enregistrés dans le registre
principal tant que le comportement cible n'est pas validé humainement.

Structure obligatoire :

```text
CODEX_T287_M3/
├── README.md
├── tests/       # scénarios modifiables par l'agent
└── reports/     # sorties locales, régénérables
```

Les tests CI officiels restent dans `RESULTS/I_TRANSLATION/tests/` et la baseline frein dans
`RESULTS/A_COMMUN/tests/test_fb_brake.st`.

## Lancement

Depuis ce dossier :

```text
tests\run.bat
python tests\run.py
python tests\run.py --debug
```

Le lanceur utilise le runner canonique avec un registre temporaire hors dépôt. Le rapport est
écrit dans `reports/`; un échec de compilation ou d'assertion est conservé pour diagnostic.
