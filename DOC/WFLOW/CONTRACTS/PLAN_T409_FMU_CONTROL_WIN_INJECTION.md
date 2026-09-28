# T409 — FMU fonctionnel avec Control Win

## Cible

```text
Control Win / tâche PLC 10 ms
        ↓ commande binaire UDP loopback
OpenModelica FMU (plante M3)
        ↓ image binaire validée
POU passerelle → GVL_Simulation.SimM3OpenModelica
        ↓
FB_SimBench existant → HwSim → logique PLC
```

## Garde-fous

- copie TwinBench Control Win uniquement ; aucun PLC réel ;
- `SimulationModeActive=FALSE` ou `SimM3OpenModelicaActive=FALSE` : aucune écriture utile ;
- trame complète, séquence nouvelle, bornes et âge contrôlés ;
- timeout : image OM invalidée, pas de maintien silencieux ;
- `FB_SimBench`, `HwReal`, `HwSim` et la logique métier ne sont pas modifiés.

## Étapes de recette

1. Compile le POU passerelle dans la copie.
2. Test FMU hors Control Win : trame commande → trame plante.
3. Test Control Win avec les deux verrous faux : aucun effet SimBench.
4. Test avec les deux verrous vrais : capteurs, Hz, frein et statut changent dans `SimM3OpenModelica`.
5. Coupe le gateway : timeout et neutralisation visibles.
6. Remets le gateway : reprise après une image complète valide.

Le passage à une écriture vers un automate réel est hors contrat.
