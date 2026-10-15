# T418 - Simulation joystick : restitution pour recette CODESYS ciblee

## Reference et conservation

Base metier : tag MES_FIN_20260923 resolu sur 44c2b368. Le registre du 26/09
confirme environ 100 cycles complets le 24/09. L'humain confirme des centaines
de cycles reels. Voir AUDIT_T418_BASELINE_MES.md pour preuves et divergences
historiques de metadonnees des commits.

FB_Joystick, FB_CycleMachineHoming, FB_CycleSemiAuto, FB_Bucket et PRG_04
restent identiques au tag. PRG_02 section 3 jusqu'a fin (joystick, references
manuelles, homing) est identique au tag. Aucun filtre homing ajoute.
Le complement PRG_02 consiste uniquement en un argument d'activation de
source dans l'appel de SimBench, section simulation.

Checkpoints autorises : 9630ddb5 et 19abfcdf. Aucun push.

## Comportement livre

Un bouton directionnel IHM produit appui armement au neutre (200 ms),
debattement progressif, relachement armement apres debut mouvement (200 ms),
puis maintien du manche jusqu'au relachement IHM et retour dynamique.
L'armement reel est exclusivement produit par FB_Joystick. La quantification
des phases depend des scans de 10 ms. Annulation, conflit et inversion
exigent retour et nouvel appui ; aucun geste differe apres OFF/ON tenu.

X/Y/bouton appartiennent ensemble au modele pendant le geste et son retour.
Les stimuli manuels concurrents bloquent le retour de propriete tant qu'ils
ne sont pas remis au neutre. La deselection de la source operateur simulee
reinitialise son geste et rend l'image reelle exacte. Reselection tenue :
aucune reprise automatique.

## Validation hors PLC

- Simulation : 12 FB / 110 tests PASS au dernier passage complet ; voir
  resultat definitif T418_CI_SIMULATION.txt.
- SimOperatorJoystick : 12/12 tests integraux de composants avec vrais FB,
  dont N1 puis SEMI_AUTO sur fixture referencee et ruptures de source.
- SimManualReference : 1/1. Trois commandes manuelles successives produisent
  les references via vrais codeurs/benne et retours SimBench. Aucun statut
  Homed positif injecte. Ce harnais ne remplace pas les pages IHM et PRG complets.
- Joystick reel : 29/29 ; SimBench : 43/43 avant et apres la reprise.
- Audit conservation MES : PASS ; G528 : PASS, 13 mutations negatives.
- Revue expert independante : PASS du geste, raccordement et reference manuelle.

Le harnais multibloc restitue explicitement les VAR_IN_OUT apres chaque appel :
l'adaptateur CI monobloc ne traite pas une entree sans FB source homonyme.
Les valeurs restituees viennent exclusivement des FB reels. G528 empeche
l'oubli de ce copy-out ainsi que des initialisations explicites des primitives.

## Auto-verification liaison

```text
Auto-verification liaison (G200_check_linkage.py) - PASS
  Linkage (L1-L7):    139 OK, 0 KO
  L8 (Output assign): 0 OK, 0 KO, 0 WARN
  L9 (I/O mapping):   0 OK, 0 KO, 25 WARN
  L10 (Single prod):  1990 OK, 1672 WARN
  L11 (Polarity):     0 OK, 30 WARN
  L12 (Timing):       7 OK, 0 KO, 0 WARN
  L13 (Orphelins):    89 OK, 0 KO
Linkage check: PASS (0 erreur(s), 1727 avertissement(s), 2136 instance(s) verifiee(s))
```

Original complet : T418_G200_LIAISON.txt. Bundle complet frais :
CODE_XML/CODE_Bundle.xml. Diff : CODE_XML/CODE_DiffBundle.xml, objets
FB_SimBench, FB_Sim_Joystick, PRG_02_Acquisition (+ types dependants).

## Limites visibles

Le front joystick en MAINT_N2 lance HX1 dans le code MES. Il ne s'agit pas
d'une regression recente ; ce comportement est conserve. Le parcours demande
est references manuelles via commandes IHM existantes, puis N1 et SEMI_AUTO.
T377 (refonte homing) n'est pas fusionnee avec cette correction du banc.

Les valeurs persistantes chargees, les pages IHM et les cycles complets dans
CODESYS n'ont pas ete testes par l'agent. Les conditions de geometrie, arret,
permis et bus du harnais sont des fixtures, pas des mesures machine.

Les gates globaux restent rouges sur G300/G100/G340/G430/G483/G519 (voir log).
Encoder : 38/40, cycle : 38/43 dans leurs anciennes suites ; sources ET tests
ET dependances compares identiques a la MES. Cette dette CI reste visible,
sans retouche du metier pour satisfaire des assertions. Benne : 41/41,
homing : 15/15. Aucun verdict de validation machine generale n'est emis.

Deux espaces de fin de ligne preexistants dans le traitement acquisition MES
reapparaissent dans le diff XML embarquant PRG_02 : ni source metier ni XML
genere modifies a la main pour les retirer. Aucun nettoyage automatique des
scratchs .tmp/.scratch ou des anciennes versions de documentation.

## Recette humaine proposee dans CODESYS simulation

1. Importer le diff bundle dans la copie de simulation et compiler.
2. Boutons directionnels relaches, demarrer/rearmer la simulation normalement.
3. Si les references manquent, utiliser les trois commandes IHM existantes,
   avec leurs conditions habituelles, puis verifier la qualification machine.
4. Passer N1 : maintenir un bouton directionnel puis relacher. Observer
   armement, debattement, maintien apres relachement armement et retour neutre.
   Aucun depart HX1 ne doit apparaitre en N1.
5. Tester un geste annule, un conflit et une deselection/reselection de source
   simulee avec bouton tenu : aucun depart differe ni reprise.
6. Passer SEMI_AUTO et verifier le parcours habituel. Cette recette humaine
   etablira ce que la CI de composants ne prouve pas : le cycle PLC complet.
