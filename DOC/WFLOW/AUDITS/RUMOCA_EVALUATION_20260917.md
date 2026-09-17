# Évaluation Rumoca — 2026-09-17

Statut : **candidat R&D pour édition/visualisation · non qualifié comme référence de physique ni de sécurité**.

## Fait constaté sur le poste

- Extension VS Code installée : `Rumoca Modelica 0.9.20`.
- Binaire embarqué et vérifié : `rumoca-lsp.exe 0.9.20`.
- Ce binaire est un serveur de langage : coloration, diagnostic, navigation, formatage et symboles.
- Il n'est pas, à lui seul, le compilateur/runtime qui exécute une FMU ou une scène 3D.

## Décision

```text
OpenModelica + OMSimulator
  = référence actuelle des équations, FMU et recettes hors ligne

Rumoca + VS Code + viewer Three.js
  = voie R&D pour l'édition moderne et la visualisation 2D/3D
```

Rumoca n'obtient pas le droit de remplacer `FB_SimBench`, le PLC, la sélection `HwReal/HwSim/HwIn`,
l'AU, les interlocks, l'homme-mort, le homing ou les sorties physiques. Le viewer ne lit que les
sorties de plante qualifiées ; il ne décide aucune sécurité.

## POC court proposé

1. Ouvrir `TOOLS/TWINBENCH/modelica_atelier/Dredge.mo` dans VS Code avec l'extension Rumoca :
   contrôler structure, navigation et diagnostics sans modifier le modèle.
2. Installer/identifier le CLI Rumoca officiel dans un environnement isolé, puis compiler un
   sous-modèle M3 minimal, sans bibliothèque métier non supportée.
3. Rejouer le même cycle M3 que `Dredge.Examples.M3ContractCycle`.
4. Comparer les traces `positionM`, `velocityMps`, `actualFrequencyHz`, frein, capteurs et conflit
   à la référence OpenModelica/OMSimulator avec tolérances explicites.
5. Seulement si la parité est établie, brancher un viewer : vue opérationnelle 2D X-Z d'abord,
   puis scène 3D avec profondeur Y, câble/poulies/benne.

## Gates de qualification Rumoca

| ID | Critère vérifiable | Verdict requis |
|---|---|---|
| RUM-01 | Le CLI compile le sous-modèle M3 et produit un résultat rejouable. | PASS |
| RUM-02 | Les traces M3 sont comparables à la référence OpenModelica sur le même scénario. | PASS |
| RUM-03 | Les tags, unités, encodages et provenance du catalogue de signaux sont conservés. | PASS |
| RUM-04 | Le viewer consomme uniquement les sorties `HW`/`DIAG` ; aucune commande ne contourne l'adaptateur PLC → FMU. | PASS |
| RUM-05 | Les caractéristiques Rust/3D non supportées ou divergentes sont listées. | PASS, avec écarts tracés |

Sans RUM-01 à RUM-05, Rumoca reste un excellent éditeur Modelica dans VS Code, pas un moteur
de simulation de référence pour le projet.

## Première exécution POC

Le `2026-09-17`, Rumoca CLI `0.9.20` a compilé et exécuté `RumocaM3Poc.ContractCycle` :
`606` points sur `12 s` avec rapport HTML. Le modèle est volontairement autonome : il ne charge
pas la MSL, car la compilation du `Dredge.mo` actuel bloque encore sur
`Modelica.Mechanics.MultiBody.Visualizers.Advanced.Shape`.

Le scénario `GrabClosureThenHoist` (fermeture image, puis remontée image) compile et s'exécute
avec `rk-like` : `501` points sur `10 s`. Le solveur automatique BDF échoue à `t=0,12 s` sur les
discontinuités de ce POC. Verdict : **RUM-01 partiellement PASS** (noyau autonome), **RUM-02
non commencé**, et compatibilité MSL/animation OMEdit **FAIL à traiter**.

## Configuration VS Code de départ

Dans les réglages du workspace, ajouter le dossier qui contient les packages Modelica lorsque
le CLI Rumoca est installé. Ne pas pointer un chemin au hasard : le chemin du package standard
doit être confirmé par le CLI Rumoca, car son mécanisme de résolution est distinct d'OpenModelica.

```json
{
  "rumoca.sourceRootPaths": [
    "<racine-des-packages-Modelica-qualifiee>"
  ]
}
```
