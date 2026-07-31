# Extraction de specifications - AF Partie 02 Architecture (v1.0)

> Sources analysees : `ARCHIVES/Doc/AF_Partie-02_Architecture_Programme_v3.0.md`,
> `ARCHIVES/Doc/AUDITS/SYNTHESE_Architecture_CFC_Bus_DUT_v1.0.md`,
> `ARCHIVES/Doc/AUDITS/MATRICE_Architecture_CFC_Bus_DUT_v1.0.md` et
> `ARCHIVES/Doc/AUDITS/PLAN_MIGRATION_Lot1_CFC_Acquisition_v1.0.md`.
> Statut : fiche de conservation et de cadrage. Elle ne remplace pas l'AF02.

## Statut des sources

| Source | Statut a retenir |
|---|---|
| AF02 v2.12 | Description de l'architecture ST actuellement documentee ; elle sera refondue. |
| Audits CFC/BUS/DUT | Propositions d'architecture, non decision d'architecture validee. Elles servent d'inspiration critique. |
| `PRG_GLOBAL_CFC.xml` | Prototype CFC present dans le code ; ses interfaces ne correspondent pas au code actuel et son rattachement de tache n'est pas prouve par cette analyse. |

## A conserver pour la future architecture

| Principe | Exigence |
|---|---|
| 🧩 POO | Un FB porte une responsabilite ; il compose ses briques internes. |
| 👁️ CFC | Le CFC sert a rendre les instances et flux lisibles en maintenance. La logique metier, les calculs et les arbitrages restent encapsules dans des FB proprietaires. |
| 🧭 Execution | L'ordre d'execution et le rattachement a une tache sont explicites, visibles et controles mecaniquement. |
| ✍️ Producteur unique | Une donnee ou commande a un seul ecrivain. Les consommateurs ne la recalculent pas. |
| 🔒 Frontieres | Les echanges entre domaines passent par des contrats types explicites ; pas par l'acces aux internes d'une instance. |
| 🛡️ Securite | Les sorties safety sont produites par leur domaine, consommees par les mouvements concernes et ne sont jamais masquees par un arbitrage anonyme. |
| 🧪 Simulation | La frontiere reel/simule reste unique, visible et reversible par domaine. |
| 🖥️ IHM | `GVL_IHM` et ses structures `Cmd/State/Cfg/Bypass` restent un contrat IHM distinct des flux internes CFC. |
| ⚡ Sorties | Les barrieres finales et l'ecriture physique restent en fin de chaine ; elles sont les seules productrices des sorties autorisees. |

## Etat observe utile au design cible

- `Acquisition (CFC)` porte deja une frontiere structuree `HwReal` / `HwSim` / `HwIn` de type `ST_HardwareImage`.
- Les contrats IHM sont deja structures par domaine dans `GVL_IHM`.
- Des structures de chaine existent (`ST_ChainWinch`, `ST_ChainTranslation` et sous-structures Inputs, Demandes, Control, Safety, Outputs), mais leur usage reel dans les programmes CFC reste a cartographier avant de les normaliser.
- Les barrieres finales `FB_WinchOutputInterlock_LD` et `FB_TranslationOutputInterlock_LD` materialisent une frontiere sortie pertinente pour la lisibilite et la surete.

## Propositions CFC/DUT : apports et limites

| Proposition audit | Apport | Reserve obligatoire |
|---|---|---|
| CFC sans logique | Bonne regle de lisibilite et de maintenance. | Definir ce qui reste admissible dans le CFC : instanciation, cablage, constantes de configuration nommees uniquement. |
| Pages CFC par domaine | Evite un graphe machine illisible. | Les pages doivent couvrir tous les proprietaires : acquisition, codeurs, safety, modes, cycle, mouvements, sorties, supervision et diagnostic. Les cinq POU proposes omettent au minimum Modes, Cycle, Supervision, sorties et gestion AU explicite. |
| Bus structures | Reduit le fil-a-fil et rend un contrat observable. | Un bus ne doit pas devenir une GVL fourre-tout ni contenir des champs sans sens pour son domaine. |
| Cinq familles de bus | Distingue materiel, commande, safety, etat et diagnostic. | `State` et `Diag` se chevauchent ; leur separation doit etre definie par responsabilite, pas par habitude de nommage. |
| `Valid` / `Enable` dans chaque DUT | Intention de robustesse. | Ne pas generaliser sans semantique. `Enable` est une commande de cycle de vie, pas un en-tete universel ; `Valid` doit indiquer precisement ce qui est invalide et sa consequence sure. |
| `GVL_Global` pour les bus CFC | Facilite le cablage propose. | Incompatible avec le principe actif « pas de GVL comme canal de commande ». A remplacer par les sorties de programmes/FB ou une frontiere explicitement justifiee. |
| Doublement `_old` | Reversibilite apparente. | Ne pas dupliquer des producteurs actifs : risque de double ecriture et de divergence. La conservation doit passer par une branche/version, un contrat de conservation et une bascule atomique. |

## Familles de contrats a specifier, sans figer encore les bus metier

| Frontiere | Contenu minimal attendu | Interdits / vigilance |
|---|---|---|
| 🏗️ Materiel qualifie | Valeurs conditionnees, polarites normalisees, disponibilite source, diagnostic de validite si necessaire. | Commandes metier, arbitrage operateur, details de simulation hors frontiere. |
| 📡 Diagnostic device | Disponibilite, operationalite, erreurs et qualite de communication par device. | Decider un mouvement ou reevaluer une commande. |
| 🕹️ Demande de conduite | Intention brute sourcee : origine, marche, direction, valeur, homme-mort/validite. | Fusionner plusieurs sources ; l'arbitrage appartient a un proprietaire distinct. |
| 🎚️ Autorisations/modes | Mode arbitre, permissions de fonction, limitations et contexte explicite. | Requete IHM brute ou commande actionneur finale. |
| 🛡️ Safety domaine | Interdictions, `SafeStop`, demande de coupure puissance, diagnostics et causes du domaine. | Etat safety global non trace, commande IHM ou sortie physique directe hors proprietaire safety. |
| ⚙️ Commande arbitree mouvement | Demande unique apres choix des sources et interlocks metier. | Champs generiques non applicables a l'axe ; second arbitre aval. |
| ⚡ Demande sortie | Demande brute vers la barriere finale, avec toutes les confirmations necessaires au dernier interlock. | Ecriture Q/PDO dans un FB metier. |
| 👁️ Etat public | Etats, mesures et diagnostics publies par le proprietaire pour supervision/IHM. | Commandes ecrites par plusieurs consommateurs. |

## Alertes a resoudre avant AF02 v3

1. **CFC prototype non conforme** : `PRG_GLOBAL_CFC.xml` cite `ActiveMode` et `CycleActive`, absents des interfaces lues. Il ne peut pas servir d'exemple executable.
2. **Etat actuel vs cible** : les audits appellent leurs propositions « definitives » alors qu'aucune preuve de migration CFC complete n'est presente. AF02 v3 devra distinguer cible validee, etat transitoire et existant a retirer.
3. **GVL de flux** : la proposition de publication de tous les bus dans `GVL_Global` contredit les regles de producteur unique et les frontieres typees directes.
4. **Couverture fonctionnelle incomplete** : l'arborescence CFC proposee ne porte pas explicitement Modes, Cycle, Supervision, sorties physiques et gestion AU.
5. **Contrats trop precoces** : les huit bus proposes melangent parfois commande, configuration, safety et diagnostic. Le contrat de chaque frontiere doit etre defini avant tout nom de DUT ou schema CFC.
6. **CFC et ordre scan** : un schema visuel ne prouve ni l'ordre d'appel ni l'appartenance a la tache. AF02 v3 devra exiger une preuve CODESYS et `check_linkage.py`.
