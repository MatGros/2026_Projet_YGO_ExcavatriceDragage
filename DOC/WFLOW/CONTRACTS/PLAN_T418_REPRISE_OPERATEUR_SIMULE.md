# T418 — Reprise : geste operateur simule depuis un bouton IHM

Etat : proposition a valider avant code. Orchestrateur : CDX01.
Checkpoint initial : `9630ddb5` (etat existant NON TESTE, sans push).

## Besoin humain

Un bouton directionnel IHM maintenu doit reproduire le geste complet : appui
armement, maintien suffisant, debattement du manche, relachement armement,
maintien du manche, puis retour au neutre au relachement IHM.
L'ancien contrat T418 (homme-mort brut a manipuler separement) ne repond pas
a ce besoin et ne constitue pas le critere d'acceptation de cette reprise.

## Perimetre propose — C2, patch simulation

- Code fonctionnel : `CODE/L_SIMULATION/FB_Sim_Joystick.st` et
  `CODE/L_SIMULATION/FB_SimBench.st` uniquement.
- Tests, garde-fou dans `TOOLS/AGENT_WORKFLOW/scripts/`, documentation de
  simulation et bundles generes associes.
- Aucun changement du joystick reel, des PRG, des modes, du homing, des
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
