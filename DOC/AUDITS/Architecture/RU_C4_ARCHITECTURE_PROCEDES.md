# RU C4 — Architecture par procédés mécaniques (décision actée)

> **Statut : ACTÉE.** Remplace le découpage transverse historique (safety globale séparée des mouvements).
> Source de la décision : arbitrage utilisateur, session d'architecture avant migration CFC natif.
> Cette décision est reportée dans `DOC/AF_Partie-02_Architecture_Programme_v3.1.md` §2 et §4.

---

## 1. Constat qui a motivé la décision

Le découpage transverse (`PRG_SAFETY_CFC` regroupant M1+M2+M3, séparé des pages mouvement)
produisait des cycles inter-programmes prouvés :

| Cycle | Nature |
|---|---|
| Safety ↔ Treuils | Safety lit direction/commande/benne ; Treuils lit `SafeStop` et interdictions. |
| Safety ↔ Translation | Safety lit direction M3 et frein final ; Translation lit `SafeStop`. |
| Acquisition ↔ Diagnostics | Instances `instJoystick` dupliquées. |
| Acquisition ↔ Encoders | Instances codeurs M1/M2 dupliquées (`instEncoderAbs*`, `instEncoderScale*`, `instHoming*`). |

Ces cycles ne sont pas un défaut de câblage : ils sont la **conséquence directe** d'un découpage
qui sépare une surveillance de l'objet qu'elle surveille.

De plus, `PRG_AUXILIARY_CFC` ne contenait qu'une seule ligne utile
(`HydraulicFaultOk := PRG_ACQUISITION_CFC.HwIn.Machine.HydraulicThermalOk_DI;`) : un programme entier
pour recopier une entrée TOR.

---

## 2. Principe de découpage acté

**Découpage par ensemble mécanique, pas par couche transverse.**

Chaque procédé physique porte sa safety dans sa propre page CFC. Un technicien qui ouvre la page
du procédé voit sur le même schéma : consigne → surveillance safety → commande.

| Rang | POU cible | Contenu |
|---|---|---|
| 01 | `PRG_02_Acquisition` | Acquisition unique `HwReal`/`HwRealQualified`/`HwSim`/`HwIn`, chaîne codeurs complète M1/M2/M3, joystick, diagnostics devices/bus, retours auxiliaires, **état AU qualifié**. |
| — | `PRG_01_Inputs_LD` | Couche historique retirée après remappage ; aucune nouvelle liaison. |
| 03 | `PRG_03_Modes_Cycle` | Modes, droits, autorisations, séquenceur `FB_Cycle`. |
| 04 | `PRG_04_Treuils_Benne` | M1 + M2 + synchro + benne + assistants, **safety M1/M2 intégrée**. |
| 05 | `PRG_05_Translation` | M3 + positionnement, **safety M3 intégrée**. |
| 06 | `PRG_06_Outputs_LD` | Barrières finales, sorties physiques, **agrégation `PowerCutOff`**, réarmement. |
| 07 | `PRG_07_Supervision` | IHM, troubleshooting, bypass. Lecture seule stricte. |

### Pourquoi M1 et M2 ne sont pas dissociables

La benne est suspendue entre le treuil de retenue (M1) et le treuil de benne (M2). L'ouverture,
la fermeture, la synchronisation et la détection de câble mou dépendent de la **combinaison** des
deux treuils. Les séparer en deux pages était une erreur de modélisation mécanique.

### Pourquoi l'acquisition absorbe codeurs, diagnostics et auxiliaires

Acquérir une mesure physique, la mettre à l'échelle, en déduire une vitesse et juger sa validité
est **une seule responsabilité** : l'acquisition. Séparer « lire le fil » et « calculer la vitesse
du même capteur » dans deux POU créait la duplication d'instances constatée.

---

## 3. Décisions transverses actées

### 3.1 — `PowerCutOff` : agrégation par la barrière finale

**Décision : option A (logique POO).**

Chaque procédé publie **sa demande** de coupure. `PRG_06_Outputs_LD`, seul au plus près des
sorties, réalise l'agrégation finale et coupe.

- Aucun POU « safety machine globale » n'est créé.
- Le producteur de la coupure physique reste unique : la barrière finale.
- La chaîne AU matérielle reste indépendante et prioritaire (Partie 01).

### 3.2 — Sécurités croisées : portées par le domaine qui subit

**Décision : option A.**

Une interdiction est portée par le procédé qui la **subit**, pas par les Modes.

> Exemple : interdire la translation lorsque la benne est en position basse est une règle de
> `PRG_05_Translation`, car c'est M3 qui est interdit.

Rôle des Modes clarifié : `PRG_03_Modes_Cycle` **distribue des autorisations**. Il ne porte
pas la responsabilité des interdictions métier. Les commandes métier reçoivent l'autorisation
ou non, et décident localement.

### 3.3 — Chaîne AU : acquise en entrée, agissant en sortie

**Décision : option A.**

L'état AU est un **fait d'entrée qualifié**, acquis dans `PRG_02_Acquisition` avec les autres
entrées. Motif : visibilité immédiate pour la maintenance.

⚠️ Cela ne change rien à son action : le FB de gestion AU agit sur les sorties via la barrière
finale `PRG_06_Outputs_LD`. Acquisition de l'état ≠ lieu d'action.

La chaîne matérielle AU, sa polarité fail-safe, son auto-test et son réarmement restent
propriétaires de la Partie 01. Le PLC ne remplace jamais cette chaîne.

---

## 4. Invariants conservés

Ces règles ne sont pas modifiées par la présente décision :

- `PRG_06_Outputs_LD` est l'**unique producteur** de chaque commande physique.
- Aucun redémarrage automatique après défaut.
- `Reset` sur front : cause disparue **et** appui conscient.
- Aucun retard d'un scan admis pour `Reset`, `SafeStop`, `PowerCutOff`, une commande ou une sortie.
- Une page CFC ne contient ni `IF`, ni calcul inline, ni fusion de commandes.
- Le troubleshooting n'écrit jamais une commande, une configuration ou un interlock.

---

## 5. Condition d'exécution

Aucun renommage, fusion ou conversion CFC natif ne démarre sans lot dédié. Chaque étape exige :

1. Remappage complet des consommateurs **avant** suppression de l'ancien producteur.
2. Jamais deux producteurs actifs en parallèle pour la même donnée.
3. Preuve de liaison (`check_linkage.py --report`) et bundle régénéré.
4. Application manuelle dans CODESYS 3.5 par l'utilisateur, page par page.
