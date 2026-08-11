# Analyse Fonctionnelle - Partie 2 : Architecture Programme (v3.1)

> Role : architecture cible de l'automate. Elle definit les pages CFC, la sortie Ladder, le programme Cycle ST
> et les frontieres IHM/troubleshooting a finaliser,
> les frontieres de flux et les regles de lisibilite maintenance.
> L'architecture ST historique est archivee. Le code actuel reste une base de migration, pas le
> modele cible.

## 🧭 Sommaire rapide

1. Principes d'architecture
2. Pages CFC, sortie Ladder et programme Cycle
3. Contrats de flux
4. Ordre d'execution
5. Regles de maintenance et de migration

## 🧪 Points de validation

| ID | Intention | Preuve | Type | Réf |
|---|---|---|---|---|
| TC-P02-001 | Un seul producteur par donnée | Aucun écouteur/écrivain multiple sur un contrat | `💻 AUTO` | §1 |
| TC-P02-002 | Page CFC sans logique métier | Zéro `IF`/calcul inline dans le CFC | `💻 AUTO` | §1 |
| TC-P02-003 | Sorties physiques via `PRG_OUTPUTS_LD` | Aucun autre POU n'écrit les Q/PDO finaux | `💻 AUTO` | §2 |
| TC-P02-004 | Ordre d'exécution MainTask conforme | Tâche CODESYS + `check_linkage.py` PASS | `💻 AUTO` | §4 |
| TC-P02-005 | Troubleshooting lecture seule | Aucune écriture commande/config/interlock | `💻 AUTO` | §2 |

---

## 🧱 1. Principes d'architecture

| Principe | Exigence |
|---|---|
| 📑 ST lisible & structuré | Les programmes d'orchestration sont rédigés en **Structured Text (ST)**. Ils sont découpés en sections claires commentées avec des emojis (ex: `// === 📥 §1 ACQUISITION ===`), sans logique métier inline. |
| 🧩 POO | Les FB encapsulent calculs, machines d'état et briques techniques par composition. |
| ✍️ Producteur unique | Toute donnée, commande ou sortie physique a un seul écrivain identifié. |
| 🔗 Contrat par bus DUT | Tout flux inter-domaine passe par une structure DUT publique (`ST_*`), documentée et orientée rôle (`Auth`, `Qualified`, `Measurements`). |
| 🛡️ Safety visible | Les sorties safety et leurs consommateurs sont nommés et explicites ; aucun arbitrage safety anonyme n'est admis. |
| ⚡ Sortie finale | Une barrière finale (`PRG_06_Outputs_LD`) est l'unique productrice de chaque commande physique. |
| 🧪 Simulation | Le choix réel/simulé est réalisé une fois à la frontière acquisition, par domaine. |
| 🖥️ IHM | Les structures `Cmd/State/Cfg/Bypass` restent le contrat PLC-IHM, distinct des flux internes. |

Un programme d'orchestration ST contient des déclarations d'instances, des constantes nommées et le câblage des entrées/sorties de FB par structures DUT. Il ne contient ni `IF` complexe, ni calcul, ni fusion de commandes, ni écriture de sortie physique hors `PRG_06_Outputs_LD`.

---

## 🗺️ 2. Organisation cible

**Regle de decoupage : par ensemble mecanique, pas par couche transverse.**
Chaque procede physique porte sa propre safety dans sa page CFC : le lien entre la surveillance
safety et le bloc metier commande doit etre visible sur le meme schema, sans ouvrir une autre page.

| N° | Programme | Langage | Responsabilite |
|---|---|---|---|
| 01 | 📥 `PRG_02_Acquisition` | ST pur (`.st`) | Producteur unique de `HwReal`, `HwSim`, `HwIn`, entrées normalisées, chaîne codeurs/joystick et diagnostics devices/bus. |
| — | ~~`PRG_01_Inputs_LD`~~ | ~~Ladder~~ | Couche historique en retrait ; suppression après remappage et preuve du filtrage. |
| 03 | 🎚️ `PRG_03_Modes_Cycle` | ST pur (`.st`) | Modes, droits, autorisations, sélections de sources et **séquenceur de cycle** (`FB_Cycle`). Produit des demandes ; ne commande aucune sortie. |
| 04 | 🪝 `PRG_04_Treuils_Benne` | ST pur (`.st`) | **Ensemble levage indissociable** : M1 (retenue) + M2 (benne) + synchronisation + benne + `FB_DiveSearch`/`FB_ExtractionSequence`, avec la safety M1/M2 appelée de manière explicite. |
| 05 | ↔️ `PRG_05_Translation` | ST pur (`.st`) | Positionnement M3 et arbitrage final translation, avec la safety M3 appelée de manière explicite. |
| 06 | ⚡ `PRG_06_Outputs_LD` | Ladder | Barrières finales, commandes physiques, **agrégation finale des demandes `PowerCutOff`** et réarmement. |
| 07 | 🔎 `PRG_07_Supervision` | ST pur (`.st`) | Agrégation IHM, troubleshooting et bypass. Lecture seule stricte : n'écrit ni commande, ni configuration, ni interlock. |

| Element transverse | Rattachement | Regle |
|---|---|---|
| 🖥️ Frontiere IHM | DUT `Cmd/State/Cfg/Bypass` | Chaque fonction porte son interface IHM dediee. Mapping et persistance restent **TBD**. |
| 🛑 Chaine AU physique | `PRG_02_Acquisition` | L'etat AU est un **fait d'entree qualifie** acquis avec les autres entrees : visible des l'acquisition pour la maintenance. Le FB agit ensuite sur les sorties via la barriere finale. La chaine materielle reste independante et proprietaire de la Partie 01. |
| ⚡ `PowerCutOff` | `PRG_06_Outputs_LD` | Chaque procede publie **sa demande** ; la barriere finale, seule au plus pres des sorties, realise l'agregation et coupe. |
| 🔀 Securites croisees | Procede qui **subit** l'interdiction | Une interdiction est portee par le domaine qui la subit (ex. interdire M3 selon un etat benne = dans `PRG_05_Translation`). Les Modes distribuent des **autorisations**, ils ne portent pas la responsabilite de l'interdiction metier. |

`FB_Cycle` reste une machine d'etat ST encapsulee : sa logique est plus lisible et testable sous cette
forme, mais elle est instanciee dans la page CFC Modes/Cycle. Les assistants de plongee/extraction
restent dans le domaine Treuils car ils sont aussi utilises en maintenance.

### Ce qui n'est pas une page CFC autonome

- Les sous-briques techniques restent privees dans leurs FB.
- Les structures IHM ne sont pas des bus internes et ne justifient pas a elles seules un programme CFC.
- La gestion d'arret d'urgence est une fonction de la chaine sortie/safety, pas une page parallele
  non raccordee.
- `PRG_GLOBAL_CFC` est un prototype historique ; il ne sert pas de reference cible.

---

## 🚌 3. Contrats de flux

Un DUT est un contrat de frontiere. Sa specification indique obligatoirement : proprietaire,
producteur unique, lecteurs, champs, unites, polarites, validite, comportement d'invalidite et
strategie de test.

| Frontiere | Produit | Consomme par |
|---|---|---|
| 🏗️ Acquisition qualifiee | Mesures conditionnees, polarites normalisees, disponibilite device et source reel/simule. | Safety, Modes, mouvements, Cycle et Supervision selon besoin. |
| 📡 Diagnostic device | Etat communication et disponibilite de chaque device. | Safety, Modes et Supervision. |
| 🕹️ Demande conduite | Intention operateur brute, sourcee et homme-mort valide. | Modes/arbitre proprietaire. |
| 🎚️ Autorisations | Mode arbitre, permissions et limitations. | Cycle et domaines mouvement. |
| 🛡️ Safety domaine | `SafeStop`, interdictions directionnelles, demande `PowerCutOff` et diagnostics du domaine. | Mouvements, Outputs et Supervision. |
| ⚙️ Commande arbitree | Une commande unique par mouvement, apres arbitrage des sources et interlocks metier. | FB mouvement concerne. |
| ⚡ Demande sortie | Demande brute de l'actionneur et confirmations necessaires a la barriere finale. | Outputs uniquement. |
| 👁️ Etat public | Mesures, etats et diagnostics produits par le domaine. | Supervision et IHM. |

Diagnostics (`Error`/`ErrorId`) portes par la frontiere "Etat public" : distinction Warning
(auto-efface) / Fault (acquittement explicite, pattern `Cause`/`Ack`) documentee dans
`DOC/CODE_QUALITY_STANDARDS.md §9`, pas reformulee ici.

Interdictions : GVL globale de commande, fusion de sources dans une interface de FB, lecture/ecriture

---

## ⏱️ 4. Execution cible

Les cadences terrain restent a confirmer avant migration. Tant qu'aucune decision ne les modifie,
la base existante est conservee : EtherCAT 4 ms, CANopen 20 ms et `MainTask` 10 ms avec surveillance
systeme 200 ms.

```text
MainTask 10 ms — ordre d'appel cible après retrait de la couche historique
  01. PRG_02_Acquisition           (source .st en ST pur — HwReal/HwSim/HwIn)
  02. PRG_03_Modes_Cycle           (source .st en ST pur d'orchestration)
  03. PRG_04_Treuils_Benne         (source .st en ST pur — safety M1/M2 intégrée)
  04. PRG_05_Translation           (source .st en ST pur — safety M3 intégrée)
  05. PRG_06_Outputs_LD            (source .st convertie en Ladder)
  06. PRG_07_Supervision           (source .st en ST pur — lecture seule)

> Phase transitoire : tant que le remappage n'est pas appliqué dans CODESYS, l'ancien
> `PRG_01_Inputs_LD` peut encore apparaître dans la tâche. Il ne doit recevoir aucun nouveau lien.
```

Ce flux est lineaire et sans retour arriere : entrees -> acquisition/diagnostic -> autorisations ->
procedes avec leur safety -> barriere finale -> observation. La safety n'est plus une couche separee
lue par les mouvements puis relue par elle-meme : chaque procede contient sa surveillance, ce qui
supprime par construction les cycles inter-programmes Safety <-> Treuils et Safety <-> Translation.

Frontiere IHM : DUT et structures `Cmd/State/Cfg/Bypass` ; mapping et persistance restent TBD, sans
programme MainTask dedie.

### Migration depuis le decoupage historique

Le decoupage transverse historique (safety globale separee des mouvements) est **abandonne** : il
creait les cycles Safety <-> Treuils et Safety <-> Translation. Correspondance de migration :

| POU actuel | Devient | Motif |
|---|---|---|
| `PRG_INPUTS_LD` | retrait contrôlé | La qualification est absorbée par `PRG_02_Acquisition` ; supprimer seulement après remappage prouvé des consommateurs.
| `PRG_ACQUISITION_CFC` + `PRG_01_Diagnostics` + `PRG_02_Encoders` + `PRG_AUXILIARY_CFC` | `PRG_02_Acquisition` | Acquérir une mesure, sa vitesse et sa santé est **une seule responsabilité** (ST pur). |
| `PRG_MODES_CFC` + `PRG_05_Cycle` | `PRG_03_Modes_Cycle` | Autorisations et séquences de conduite au même endroit (ST pur). |
| `PRG_TREUILS_CFC` + partie M1/M2/benne de `PRG_SAFETY_CFC` | `PRG_04_Treuils_Benne` | M1 et M2 sont mécaniquement indissociables (benne suspendue) ; leur safety est appelée au même endroit (ST pur). |
| `PRG_TRANSLATION_CFC` + partie M3 de `PRG_SAFETY_CFC` | `PRG_05_Translation` | Idem pour la translation (ST pur). |
| `PRG_OUTPUTS_LD` | `PRG_06_Outputs_LD` | Devient aussi l'agrégateur `PowerCutOff` (Ladder). |
| `PRG_SUPERVISION_CFC` + `PRG_TROUBLESHOOTING_CFC` | `PRG_07_Supervision` | Observation et diagnostic, lecture seule stricte (ST pur). |

📌 Dossier de decision : `DOC/AUDITS/Architecture/RU_C4_ARCHITECTURE_PROCEDES.md`.
**Aucun renommage ni fusion ne demarre sans lot dedie** : chaque etape exige remappage complet des
consommateurs, producteur unique et preuve de liaison.

📌 Dossiers de revue et audits d'architecture :
- `ARCHIVES/Doc/AUDITS/Architecture/TABLE_POU_ACTIFS_VS_LEGACY_v1.0.md` : Cartographie POU actifs vs legacy et procédure de nettoyage CODESYS.
- `ARCHIVES/Doc/AUDITS/Architecture/PLAN_Migration_MainTask_CFC_v1.0.md` : Preuves des cycles supprimés par le découpage par procédé.
Tant que les décisions de migration ne sont pas appliquées, cette section ne constitue pas une
autorisation de renommer prématurément les POU dans le code sans lot dédié.

### Regle d'ordonnancement

| Niveau | Regle | Mise en oeuvre |
|---|---|---|
| **INTRA-programme** | L'ordre d'execution a l'interieur d'une page CFC est automatique : il suit le flux de donnees entre instances et structures publiques. | CODESYS determine l'ordre topologique des blocs a partir des connexions. |
| **INTER-programmes** | L'ordre entre programmes est explicite et fige dans la `MainTask` par la numerotation `PRG_XX`. | Aucun programme ne doit lire une donnée produite par un programme execute plus tard dans le meme cycle, sauf retard d'un scan documente. |

Toute dependance lue avant son producteur doit etre supprimee ou documentee comme retard d'un scan,

---

## 🔧 5. Regles de maintenance et migration

- Un technicien doit pouvoir suivre un flux de gauche a droite : acquisition -> decision -> mouvement -> sortie -> etat public.
- Un domaine peut etre diagnostique depuis sa page CFC sans ouvrir une page machine globale.
- Le troubleshooting observe les contrats publics et ne peut jamais ecrire une commande, une configuration ou un interlock.
- Un remplacement se fait avec contrat de conservation, remappage complet des consommateurs et preuve de lien ; jamais par deux producteurs actifs (`_old` et nouveau).
- Les noms finaux des devices et E/S viennent du materiel/export CODESYS, puis se propagent dans les contrats.
- La chaine AU, sa polarite fail-safe, son auto-test et son rearmement sont proprietaires de la Partie 01.
- Les interfaces de FB et DUT sont proprietaires de la Partie 03.

## 📚 Documents lies

- Partie 01 : machine et securite electrique.
- Partie 03 : contrats composants, DUT et regles CFC.
- Parties 04 a 14 : exigences de chaque domaine, sans redefinir l'architecture cible.
