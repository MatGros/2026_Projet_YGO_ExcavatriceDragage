# Analyse Fonctionnelle - Partie 2 : Architecture Programme (v3.2)

> La tracabilite des versions programme/document est portee par `DOC/VERSION_HISTORY.md`.

## 🎯 Rôle et périmètre

- **Rôle** : définir l'architecture cible de l'automate — pages CFC, sortie Ladder, programme
  Cycle ST, frontières de flux et règles de lisibilité maintenance.
- **Périmètre** : découpage par procédé (7 POU), ordonnancement `MainTask`, contrats de flux
  inter-domaine. Ne définit pas : le détail des contrats FB/DUT (Partie 03), le contenu métier
  de chaque domaine (Parties 04-14).
- **Type de composant** : Fondations méta — pas de FB unique, pas de contrat AF03.
- ⚠️ L'architecture ST historique est archivée. Le code actuel reste une base de migration, pas
  le modèle cible.

## 📑 Sommaire

1. [🧪 Points de validation](#1--points-de-validation)
2. [🧱 Principes d'architecture](#2--principes-darchitecture)
3. [🗺️ Organisation cible](#3--organisation-cible)
4. [🚌 Contrats de flux](#4--contrats-de-flux)
5. [⏱️ Exécution cible](#5--exécution-cible)
6. [🔧 Règles de maintenance et migration](#6--règles-de-maintenance-et-migration)
7. [📜 Suivi historique](#7--suivi-historique)
8. [❓ TBD](#8--tbd)
9. [📚 Documents liés](#9--documents-liés)

## 🧪 1 · Points de validation

| ID | Intention | Preuve | Type | Réf |
|---|---|---|---|---|
| <nobr><code>TC-P02-001</code></nobr> | Un seul producteur par donnée | Aucun écouteur/écrivain multiple sur un contrat *(⚠️ `G200_check_linkage.py` L10 remonte des faux positifs intra-POU — voir TBD §8)* | `💻 AUTO` | <small>§2</small> |
| <nobr><code>TC-P02-002</code></nobr> | Page CFC sans logique métier | Zéro `IF`/calcul inline dans le CFC | `💻 AUTO` | <small>§2</small> |
| <nobr><code>TC-P02-003</code></nobr> | Sorties physiques via `PRG_06_Outputs` | Aucun autre POU n'écrit les Q/PDO finaux | `💻 AUTO` | <small>§3</small> |
| <nobr><code>TC-P02-004</code></nobr> | Ordre d'exécution MainTask conforme | Tâche CODESYS + `G200_check_linkage.py` PASS *(⚠️ ne vérifie pas l'ordre inter-POU — revue manuelle à ce jour, voir TBD §8)* | `⚡ SITE+AUTO` | <small>§5</small> |
| <nobr><code>TC-P02-005</code></nobr> | Troubleshooting lecture seule | Aucune écriture commande/config/interlock | `💻 AUTO` | <small>§3</small> |

---

## 🧱 2 · Principes d'architecture

| Principe | Exigence |
|---|---|
| 📑 ST lisible & structuré | Les programmes d'orchestration sont rédigés en **Structured Text (ST)**. Ils sont découpés en sections claires commentées avec des emojis (ex: `// === 📥 §1 ACQUISITION ===`), sans logique métier inline. |
| 🧩 POO | Les FB encapsulent calculs, machines d'état et briques techniques par composition. |
| ✍️ Producteur unique | Toute donnée, commande ou sortie physique a un seul écrivain identifié. |
| 🔗 Contrat par bus DUT | Tout flux inter-domaine passe par une structure DUT publique (`ST_*`), documentée et orientée rôle (`Auth`, `Qualified`, `Measurements`). |
| 🛡️ Safety visible | Les sorties safety et leurs consommateurs sont nommés et explicites ; aucun arbitrage safety anonyme n'est admis. |
| ⚡ Sortie finale | Une barrière finale (`PRG_06_Outputs`) est l'unique productrice de chaque commande physique. |
| 🧪 Simulation | Le choix réel/simulé est réalisé une fois à la frontière acquisition, par domaine. |
| 🖥️ IHM | Les structures `Cmd/State/Cfg/Bypass` restent le contrat PLC-IHM, distinct des flux internes. |

Un programme d'orchestration ST contient des déclarations d'instances, des constantes nommées et le câblage des entrées/sorties de FB par structures DUT. Il ne contient ni `IF` complexe, ni calcul, ni fusion de commandes, ni écriture de sortie physique hors `PRG_06_Outputs`.

---

## 🗺️ 3 · Organisation cible

**Regle de decoupage : par ensemble mecanique, pas par couche transverse.**
Chaque procede physique porte sa propre safety dans sa page CFC : le lien entre la surveillance
safety et le bloc metier commande doit etre visible sur le meme schema, sans ouvrir une autre page.

| N° | Programme | Langage | Responsabilite |
|---|---|---|---|
| 01 | 📥 `PRG_02_Acquisition` | ST pur (`.st`) | Producteur unique de `HwReal`, `HwSim`, `HwIn`, entrées normalisées, chaîne codeurs/joystick et diagnostics devices/bus. |
| — | ~~`PRG_01_Inputs_LD`~~ | ~~Ladder~~ | ✅ Retiré (2026-08-26, vérifié absent de `CODE/M_MAIN/`) — qualification absorbée par `PRG_02_Acquisition`. |
| 03 | 🎚️ `PRG_03_Modes_Cycle` | ST pur (`.st`) | Modes, droits, autorisations, sélections de sources et **séquenceur de cycle** (`FB_Cycle`). Produit des demandes ; ne commande aucune sortie. |
| 04 | 🪝 `PRG_04_Treuils_Benne` | ST pur (`.st`) | **Ensemble levage indissociable** : M1 (retenue) + M2 (benne) + synchronisation + benne + `FB_DiveSearch`/`FB_ExtractionSequence`, avec la safety M1/M2 appelée de manière explicite. |
| 05 | ↔️ `PRG_05_Translation` | ST pur (`.st`) | Positionnement M3 et arbitrage final translation, avec la safety M3 appelée de manière explicite. |
| 06 | ⚡ `PRG_06_Outputs` | Ladder | Barrières finales, commandes physiques, **agrégation finale des demandes `PowerCutOff`** et réarmement. |
| 07 | 🔎 `PRG_07_Supervision` | ST pur (`.st`) | Agrégation IHM, troubleshooting et bypass. Lecture seule stricte : n'écrit ni commande, ni configuration, ni interlock. |

| Element transverse | Rattachement | Regle |
|---|---|---|
| 🖥️ Frontiere IHM | DUT `Cmd/State/Cfg/Bypass` | Chaque fonction porte son interface IHM dediee. Mapping et persistance restent **TBD**. |
| 🛑 Chaine AU physique | `PRG_02_Acquisition` | L'etat AU est un **fait d'entree qualifie** acquis avec les autres entrees : visible des l'acquisition pour la maintenance. Le FB agit ensuite sur les sorties via la barriere finale. La chaine materielle reste independante et proprietaire de la Partie 01. |
| ⚡ `PowerCutOff` | `PRG_06_Outputs` | Chaque procede publie **sa demande** ; la barriere finale, seule au plus pres des sorties, realise l'agregation et coupe. |
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

## 🚌 4 · Contrats de flux

Un DUT est un contrat de frontiere. Sa specification indique obligatoirement : proprietaire,
producteur unique, lecteurs, champs, unites, polarites, validite, comportement d'invalidite et
strategie de test.

⚠️ Cette table nomme les frontières par **rôle**, pas par DUT concret (champs/types/unités) : le
détail complet est **Partie 03**. Un agent d'implémentation doit systématiquement croiser cette
table avec `AF_Partie-03_Contrats_Composants` pour retrouver le nom exact du `ST_*` qui réalise
chaque frontière — ne jamais deviner un nom de DUT à partir de cette seule table.

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
`DOC/STDS/CODE_QUALITY_STANDARDS.md §9`, pas reformulee ici.

Interdictions : GVL globale de commande, fusion de sources dans une interface de FB, lecture/ecriture

---

## ⏱️ 5 · Exécution cible

Les cadences terrain restent a confirmer avant migration. Tant qu'aucune decision ne les modifie,
la base existante est conservee : EtherCAT 4 ms, CANopen 20 ms et `MainTask` 10 ms avec surveillance
systeme 200 ms.

```text
MainTask 10 ms — ordre d'appel
  01. PRG_02_Acquisition           (source .st en ST pur — HwReal/HwSim/HwIn)
  02. PRG_03_Modes_Cycle           (source .st en ST pur d'orchestration)
  03. PRG_04_Treuils_Benne         (source .st en ST pur — safety M1/M2 intégrée)
  04. PRG_05_Translation           (source .st en ST pur — safety M3 intégrée)
  05. PRG_06_Outputs            (source .st convertie en Ladder)
  06. PRG_07_Supervision           (source .st en ST pur — lecture seule)
```

✅ **Migration source terminée** (vérifié 2026-08-26) : `CODE/M_MAIN/` ne contient plus que ces
6 POU cible — aucun `PRG_01_Inputs_LD` ni ancien `*_CFC` legacy sur le disque. Seul le statut de
la **tâche CODESYS en ligne** (projet ouvert dans l'IDE, pas le code source) reste à confirmer par
l'utilisateur lors du prochain import PLCopenXML — ce n'est plus une question de code manquant.

Ce flux est lineaire et sans retour arriere : entrees -> acquisition/diagnostic -> autorisations ->
procedes avec leur safety -> barriere finale -> observation. La safety n'est plus une couche separee
lue par les mouvements puis relue par elle-meme : chaque procede contient sa surveillance, ce qui
supprime par construction les cycles inter-programmes Safety <-> Treuils et Safety <-> Translation.

Frontiere IHM : DUT et structures `Cmd/State/Cfg/Bypass` ; mapping et persistance restent TBD, sans
programme MainTask dedie.

### Migration depuis le decoupage historique (terminee au niveau source)

Le decoupage transverse historique (safety globale separee des mouvements) est **abandonne** : il
creait les cycles Safety <-> Treuils et Safety <-> Translation. Correspondance de migration
(historique — table conservee pour comprendre le *pourquoi* du decoupage, plus une TODO) :

| POU actuel | Devient | Motif |
|---|---|---|
| `PRG_INPUTS_LD` | ✅ retiré | La qualification est absorbée par `PRG_02_Acquisition` ; retrait vérifié sur le code source (2026-08-26).
| `PRG_ACQUISITION_CFC` + `PRG_01_Diagnostics` + `PRG_02_Encoders` + `PRG_AUXILIARY_CFC` | `PRG_02_Acquisition` | Acquérir une mesure, sa vitesse et sa santé est **une seule responsabilité** (ST pur). |
| `PRG_MODES_CFC` + `PRG_05_Cycle` | `PRG_03_Modes_Cycle` | Autorisations et séquences de conduite au même endroit (ST pur). |
| `PRG_TREUILS_CFC` + partie M1/M2/benne de `PRG_SAFETY_CFC` | `PRG_04_Treuils_Benne` | M1 et M2 sont mécaniquement indissociables (benne suspendue) ; leur safety est appelée au même endroit (ST pur). |
| `PRG_TRANSLATION_CFC` + partie M3 de `PRG_SAFETY_CFC` | `PRG_05_Translation` | Idem pour la translation (ST pur). |
| `PRG_OUTPUTS_LD` | `PRG_06_Outputs` | Devient aussi l'agrégateur `PowerCutOff` (Ladder). |
| `PRG_SUPERVISION_CFC` + `PRG_TROUBLESHOOTING_CFC` | `PRG_07_Supervision` | Observation et diagnostic, lecture seule stricte (ST pur). |

📌 Décision d'architecture (7 POU par procédé) reportée dans `AF_Partie-02` §2/§4 ; historique de migration archivé (`ARCHIVES/Doc/AUDITS/Architecture_Migration7POU/`).
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

⚠️ **Cette règle n'est pas vérifiée automatiquement aujourd'hui.** `G200_check_linkage.py` valide
la liaison instance/interface, pas l'ordre de lecture/écriture inter-POU dans la `MainTask`. Le
respect de cette règle repose sur la revue humaine à ce jour — voir TBD §8.

Toute dependance lue avant son producteur doit etre supprimee ou documentee comme retard d'un scan,

---

## 🔧 6 · Règles de maintenance et migration

- Un technicien doit pouvoir suivre un flux de gauche a droite : acquisition -> decision -> mouvement -> sortie -> etat public.
- Un domaine peut etre diagnostique depuis sa page CFC sans ouvrir une page machine globale.
- Le troubleshooting observe les contrats publics et ne peut jamais ecrire une commande, une configuration ou un interlock.
- Un remplacement se fait avec contrat de conservation, remappage complet des consommateurs et preuve de lien ; jamais par deux producteurs actifs (`_old` et nouveau).
- Les noms finaux des devices et E/S viennent du materiel/export CODESYS, puis se propagent dans les contrats.
- La chaine AU, sa polarite fail-safe, son auto-test et son rearmement sont proprietaires de la Partie 01.
- Les interfaces de FB et DUT sont proprietaires de la Partie 03.

## 📜 7 · Suivi historique

| Version | Date | Changement |
|---|---|---|
| v3.2 | 2026-08-26 | Mise en conformite `GUIDE_EDITION_AF_v1.0` : Sommaire lie, section `🎯 Rôle et périmètre` explicite, ajout Suivi historique et TBD, renumerotation complete des sections. Correction §5/§6 : la migration source (7 POU) est **terminee** sur disque (verifie, plus de legacy `PRG_01_Inputs_LD`/`*_CFC`) — seul le statut de la tache CODESYS en ligne restait flou dans la formulation precedente. <nobr><code>TC-P02-001</code></nobr>/<nobr><code>TC-P02-004</code></nobr> annotes : `G200_check_linkage.py` ne couvre ni le vrai producteur-unique par-POU (faux positifs intra-POU, L10) ni l'ordre inter-programmes (revue humaine a ce jour) — voir TBD ci-dessous. Revue par sous-agent expert automatisme. |
| v3.1 | — | Version precedente (voir `ARCHIVES/Doc/`) |

## ❓ 8 · TBD

| # | Question | Impact |
|---|---|---|
| 1 | Cadences terrain (EtherCAT 4ms / CANopen 20ms / MainTask 10ms) a confirmer avant migration | Peut changer les contraintes temps reel de tous les domaines |
| 2 | Frontiere IHM : mapping et persistance des DUT `Cmd/State/Cfg/Bypass` non tranches | Bloque la specification complete du contrat PLC-IHM (Partie 07) |
| 3 | `G200_check_linkage.py` L10 (producteur unique) remonte des faux positifs : deux ecritures a la meme variable **dans le meme POU** (branchement normal) comptent comme "producteur multiple", indistinguable d'un vrai second POU ecrivain | <nobr><code>TC-P02-001</code></nobr> ne peut pas etre juge fiable sans correction du script (scoper par POU, pas par ligne) — 1019 WARN actuels, aucun distingue vrai/faux positif |
| 4 | Aucun gate n'existe pour verifier l'ordre inter-programmes (§7 "regle d'ordonnancement" — aucun programme ne doit lire une donnee produite plus tard dans le meme cycle) | <nobr><code>TC-P02-004</code></nobr> repose sur la revue manuelle ; un futur ajout de POU ou reordonnancement `MainTask` pourrait introduire une regression silencieuse |

## 📚 9 · Documents liés

- Partie 01 : machine et securite electrique.
- Partie 03 : contrats composants, DUT et regles CFC.
- Parties 04 a 14 : exigences de chaque domaine, sans redefinir l'architecture cible.
