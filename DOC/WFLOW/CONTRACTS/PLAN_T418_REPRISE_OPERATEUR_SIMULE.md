# T418 — Reprise : geste operateur simule depuis un bouton IHM

Etat : plan valide et complete apres audit de la MES. Orchestrateur : CDX01.
Checkpoint initial : `9630ddb5` (etat existant NON TESTE, sans push).

## Besoin humain

Un bouton directionnel IHM maintenu doit reproduire le geste complet : appui
armement, maintien suffisant, debattement du manche, relachement armement,
maintien du manche, puis retour au neutre au relachement IHM.
L'ancien contrat T418 (homme-mort brut a manipuler separement) ne repond pas
a ce besoin et ne constitue pas le critere d'acceptation de cette reprise.

## Perimetre final — C3, patch simulation

- Code fonctionnel : `CODE/L_SIMULATION/FB_Sim_Joystick.st` et
  `CODE/L_SIMULATION/FB_SimBench.st` ; un argument de selection de source
  dans l'appel SimBench de `CODE/M_MAIN/PRG_02_Acquisition.st`.
- Tests, garde-fou dans `TOOLS/AGENT_WORKFLOW/scripts/`, documentation de
  simulation et bundles generes associes.
- Aucun changement du traitement joystick/codeurs/homing des PRG, des modes, du homing, des
  interlocks, de la physique M3 ou des liaisons IHM existantes.

## Sequence proposee

1. Repos : axes neutres et bouton armement relache.
2. Une seule direction demandee : bouton armement simule appuye, axes neutres.
3. Apres maintien suffisant : debattement progressif dans le sens demande.
4. Relachement du bouton armement ; manche maintenu tant que l'IHM est tenue.
5. Relachement IHM : retour dynamique au neutre ; aucun rearmement automatique.

Les durees de maintien et de transition doivent etre explicites, observables et
testees avec la configuration du vrai FB_Joystick. Ses valeurs par defaut sont
100 ms d'appui, 3 s de grace et 100 ms de maintien au neutre. Elles ne prouvent
pas les valeurs actuellement chargees dans CODESYS. Un temporisateur simulateur
ecoule ne doit jamais etre presente comme la preuve d'un armement effectivement
acquis : seul le vrai FB_Joystick produit DeadmanArmed.

Une demande annulee pendant l'appui ne doit pas produire de debattement ensuite.
Plusieurs directions simultanees doivent neutraliser le geste. Un changement
de sens et une demande deja presente a l'activation du banc doivent faire
l'objet d'une decision explicite avant implementation, pour eviter un
rearmement implicite ou une reprise surprise.

## Criteres de verification

- TC1 : un seul bouton IHM produit les phases dans l'ordre, sans manipulation
  manuelle du stimulus homme-mort et sans ecriture de DeadmanArmed.
- TC2 : integration avec le vrai FB_Joystick : armement obtenu, commande axe
  obtenue et conservee apres relachement du bouton armement simule.
- TC3 : relachement IHM pendant l'armement annule le geste ; aucun mouvement
  differe. Relachement en mouvement ramene les axes au neutre.
- TC4 : absence de permis : le vrai joystick refuse le mouvement ; aucun
  contournement ni nouvelle tentative automatique cachee par le simulateur.
- TC5 : retour au neutre et desarmement reel observes ; nouveau geste exige
  un nouvel appui IHM. Cas demandes multiples et changements de sens testes.
- TC6 : observation de l'appui brut par le vrai homing : tout lancement
  inattendu est rapporte, jamais masque par une modification de production.
- TC7 : garde-fou automatique rejetant le couplage combinatoire direct
  direction -> homme-mort et toute ecriture simulee de l'etat arme reel.
- TC8 : diff de production hors simulation vide depuis 9630ddb5 ; bundle
  complet + diff, G200 --report, gates et revue expert independante.

## Revue finale demandee

Un agent expert automatisme industriel relit le diff reel et les preuves,
en lecture seule. Il challenge chronologie, annulations, inversion, perte
de permis, redemarrage et interaction homing. CDX01 examine ses conclusions
avant restitution. Aucun verdict de fidelite terrain sans essai CODESYS humain.

## Ancrage MES et parcours retenu

Le besoin humain precise ensuite : partir du programme produisant des centaines
de cycles, references manuelles par les trois commandes IHM existantes, puis
N1 et SEMI_AUTO ; refonte homing T377 ulterieure. Le tag MES verifie est
44c2b368. Le filtre de lancement homing envisage n'a jamais ete implemente.
Seule extension d'adaptateur : source operateur simulee deselectionnee ->
reinitialisation du geste + image reelle exacte. Le traitement metier depuis
section 3 de PRG_02 reste identique au tag, controle par script dedie.
