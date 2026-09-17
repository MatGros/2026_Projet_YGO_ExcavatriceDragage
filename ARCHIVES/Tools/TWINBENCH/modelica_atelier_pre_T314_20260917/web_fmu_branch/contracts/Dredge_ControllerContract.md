# Contrat PLC ↔ OpenModelica — fondation L0

Statut : **contrat de migration, aucune liaison PLC active**.

```text
PRG_06 / sorties finales PLC (N-1)
  → adaptateur hors-ligne
  → FMU Dredge.Plant (commande finale + horodatage)
  → capteurs / feedbacks simulés, provenance FMU
  → HwSim
  → aiguillage existant HwReal | HwSim → HwIn dans PRG_02
```

Le PLC reste le propriétaire exclusif des autorisations, interlocks, `PowerCutOff`,
chaîne AU, réarmement, arbitrage des commandes et sélection de source. La FMU ne
reçoit que des commandes finales et ne rend que des **faits capteurs simulés**.

| Domaine | Commande reçue par la plante | Image capteur attendue par PLC | Etat L0 |
|---|---|---|---|
| M3 | Direction finale, vitesse %, commande frein | 5 DI de position, frein ouvert, fréquence, StatusWord, état device | L1 prévu |
| M1/M2 | Relais sens, paliers, contacteurs, frein, preset | codeurs bruts/vitesse, frein, contacteurs, thermique, top, câble tendu | L2 prévu |
| Benne/Kobold | Commande alimentation Kobold et état M1 | DI fond/temporisation; géométrie et charge | L3 différé |
| Chaîne machine | lecture de demandes PLC, jamais commande safety | contacteur, thermiques, phase, AU comme DI simulées | L4 différé |
| Opérateur | scénario ou HID hors PLC | `ST_HwOperator` brut uniquement | L5 différé |

## Cadence et sûreté

- Pas PLC cible : 10 ms. L’adaptateur doit horodater commande et réponse et publier le retard.
- Pas FMU courant : 20 ms. Tant que l’alignement 10 ms n’est pas validé, l’intégration ne peut être qu’en **shadow mode**.
- Le moteur asynchrone détaillé `IM_SlipRing` est réservé à l’étude offline; une FMU 20 ms utilisera un modèle moyen identifié.
- Toute valeur périmée, commande contradictoire ou erreur FMU doit produire une image de défaut/neutre explicitement définie; jamais un état sain implicite.

La couverture des entrées du SimBench historique est contrôlée par :

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/check_simbenc_parity.py
```
