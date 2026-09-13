# Workspace de troubleshooting CI

Cet espace sert aux investigations secondaires menees par les agents :
compilation exploratoire, reproduction minimale d'un defaut et essai de
scenario avant de proposer une modification du projet principal.

## Structure obligatoire

```text
_TROUBLESHOOTING/
  <AGENT_ID>/
    README.md
    tests/
    reports/
```

- `<AGENT_ID>` est l'identifiant explicite de l'agent auteur, par exemple
  `AGY-01`, `Codex_T280` ou `HUM_<sujet>`.
- `README.md` declare l'objectif, les sources lues, la commande executee et le
  verdict. Une conclusion durable va dans `DOC/WFLOW/TROUBLESHOOTING/`.
- `tests/` contient les scenarii ST, les fixtures et les petits lanceurs qui
  doivent survivre a l'investigation.
- `reports/` contient les sorties regenerables : logs, HTML, JSON, binaires et
  copies de compilation. Les nouveaux rapports sont locaux et ignores par Git.
- Les scratchs de compilation jetables vont exclusivement sous
  `TOOLS/TEST_AUTO_CI/.tmp_<agent>_<run>/`, jamais ici ni a la racine du depot.

`HUM_LEGACY/` rassemble le contenu historique dont seul l'auteur Git humain est
connu. Il respecte la meme separation `tests/` / `reports/` sans attribuer a
posteriori ces fichiers a un agent inexistant.
