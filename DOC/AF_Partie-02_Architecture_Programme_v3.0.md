# Analyse Fonctionnelle - Partie 2 : Architecture Programme (v3.0)

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
| 👁️ CFC lisible | Une page CFC represente un domaine de responsabilite. Elle montre les instances et contrats, sans logique metier cachee. |
| 🧩 POO | Les FB encapsulent calculs, machines d'etat et briques techniques par composition. |
| ✍️ Producteur unique | Toute donnee, commande ou sortie physique a un seul ecrivain identifie. |
| 🔗 Contrat type | Tout flux inter-domaine passe par une structure DUT publique, documentee et orientee role. |
| 🛡️ Safety visible | Les sorties safety et leurs consommateurs sont nommes et visibles ; aucun arbitrage safety anonyme n'est admis. |
| ⚡ Sortie finale | Une barriere finale est l'unique productrice de chaque commande physique. |
| 🧪 Simulation | Le choix reel/simule est realise une fois a la frontiere acquisition, par domaine. |
| 🖥️ IHM | Les structures `Cmd/State/Cfg/Bypass` restent le contrat PLC-IHM, distinct des flux internes. |

Une page CFC peut contenir des constantes nommees, des instances et des liaisons. Elle ne contient
ni `IF`, ni calcul, ni fusion de commandes, ni ecriture de sortie physique hors `PRG_OUTPUTS_LD`.

---

## 🗺️ 2. Organisation cible

| Programme | Langage | Responsabilite |
|---|---|---|
| 📥 `PRG_ACQUISITION_CFC` | CFC | Frontiere E/S, selection reel/simule, diagnostics devices, joystick, codeurs COD1/COD2, mise a l'echelle, vitesse et homing. |
| 🪜 `PRG_INPUTS_LD` | Ladder | Affichage qualifie des 21 E/S TOR via `FB_Input` ; lecture seule, aucune decision metier. |
| 🎚️ `PRG_MODES_CFC` | CFC | Modes, droits, autorisations, selections et arbitrages de sources autorises. |
| 🛡️ `PRG_SAFETY_CFC` | CFC | Safety M1, M2 et M3 ; interdictions, `SafeStop`, demandes de coupure puissance et diagnostics safety. |
| 🔄 `PRG_CYCLE` | ST | Instance `FB_Cycle` a machine d'etat/Grafcet. Il produit des demandes automatiques ; il ne commande pas les sorties. |
| 🪝 `PRG_TREUILS_CFC` | CFC | M1/M2, synchronisation, benne, `FB_DiveSearch`, `FB_ExtractionSequence`, arbitrage final treuil et demandes vers barrieres finales. |
| ↔️ `PRG_TRANSLATION_CFC` | CFC | Positionnement M3, arbitrage final translation et demande vers barriere finale. |
| ⚡ `PRG_OUTPUTS_LD` | Ladder | Barrieres finales, commandes physiques, gestion de la coupure puissance et du rearmement. |
| 🖥️ Frontiere IHM | DUT et structures `Cmd/State/Cfg/Bypass` | Chaque fonction porte son interface IHM dediee. Le mapping, la persistance, les agregats et l'eventuel programme ST restent **TBD**. |
| 🔎 Troubleshooting | Structures lecture seule | Affiche les donnees de debogage dans un ordre utile a la maintenance. Son type, son programme eventuel et son ordonnancement restent **TBD**. |

`PRG_CYCLE` reste en ST : sa machine d'etat est plus lisible, testable et maintenable sous cette
forme. Les assistants de plongee/extraction restent dans le domaine Treuils car ils sont aussi
utilises en maintenance.

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
MainTask
  - PRG_ACQUISITION_CFC
  - PRG_INPUTS_LD
  - PRG_MODES_CFC
  - PRG_SAFETY_CFC
  - PRG_CYCLE                 (ST)
  - PRG_TREUILS_CFC
  - PRG_TRANSLATION_CFC
  - PRG_OUTPUTS_LD
  8. Frontiere IHM                 (TBD : mapping et persistance)
  9. Troubleshooting lecture seule (TBD : type et ordonnancement)
```

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
