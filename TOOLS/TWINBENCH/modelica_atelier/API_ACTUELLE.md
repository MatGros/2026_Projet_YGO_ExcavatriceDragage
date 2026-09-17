# API réelle du POC Atelier

Relevé du code `server.py`, `runtime.py` et `app.js` au 2026-09-17.
Ce document décrit l'existant, contrairement au contrat cible proposé dans le brief.

## Transport et état

HTTP local sur `http://127.0.0.1:8766`. Le navigateur interroge l'état environ toutes les
100 ms ; le moteur avance par pas de 20 ms. Aucun WebSocket n'est actuellement implémenté.

`GET /state?after=42` renvoie :

| Champ | Type / sens |
|---|---|
| `ready` | booléen : moteur initialisé |
| `error` | texte, vide en absence d'erreur moteur |
| `running` | booléen : temps simulé en progression |
| `config` | valeurs des quatre paramètres ci-dessous |
| `frames` | échantillons conservés dont `seq > after` |
| `last` | dernière frame, objet vide avant le premier pas |
| `events` | jusqu'à 150 événements `{t, text}`, t en secondes simulées |
| `scenario` | `manual`, `brake` ou `reverse` |
| `epoch` | entier incrémenté à la remise à zéro |
| `stepMs` | durée du dernier appel de calcul natif, en millisecondes |
| `signals` | dictionnaire identifiant → `[libellé, unité]` |

Une frame est un objet plat : `t`, `seq`, puis les onze signaux ci-dessous. `seq` repart à
1 après une remise à zéro. L'API ne filtre pas selon une époque fournie par le client :
si `epoch` change, le client doit vider son acquisition et redemander `after=0`.
Une frame absente est une donnée indisponible, pas une valeur zéro ou une mesure initiale.

## Signaux disponibles

| Identifiant | Libellé | Unité | Origine / représentation |
|---|---|---|---|
| `position` | Position | m | sortie FMU simulée |
| `velocity` | Vitesse | m/s | sortie FMU simulée |
| `acceleration` | Accélération | m/s² | sortie FMU simulée |
| `motorForce` | Effort moteur | N | sortie FMU simulée |
| `brakeForce` | Effort de frein | N | sortie FMU simulée |
| `brake` | Serrage du frein | 0–1 | sortie FMU continue |
| `sensor` | Capteur | 0/1 | sortie FMU ; piste en escaliers |
| `energy` | Énergie cinétique | J | sortie FMU simulée |
| `overtravel` | Hors course | 0/1 | sortie FMU ; piste en escaliers |
| `lever` | Joystick | −1…1 | commande appliquée au pas, après choix manuel/scénario |
| `held` | Homme-mort | 0/1 | commande appliquée au pas ; piste en escaliers |

Ni courant électrique, ni température, ni tension de câble ne sont fournis. La future
interface peut présenter ces familles comme extensions, sans inventer de courbe calculée.

## Paramètres éditables

| Identifiant | Défaut | Domaine accepté | Unité |
|---|---:|---:|---|
| `mass` | 4000 | 500 à 12000 | kg |
| `forceLimit` | 3500 | 500 à 7000 | N |
| `brakeDelay` | 0,25 | 0,05 à 1,5 | s |
| `sensorPosition` | 21 | 1 à 29 | m |

Ces valeurs sont des entrées de la FMU. L'édition en cours de simulation est paramétrique.
Changer une masse en marche ne représente pas une prise de charge conservative.
La longueur de rail de 30 m et les équations ne sont pas éditables par cette API.

## Commandes

`POST /command`, corps JSON. Succès : `{"ok":true}`. Échec : `{"error":"texte"}`
avec statut HTTP non 2xx. Vérifier l'acquittement avant de présenter une action comme appliquée.

| `action` | Champs supplémentaires | Effet |
|---|---|---|
| `input` | `lever`: −1 à 1, `held`: 0 ou 1 | intentions manuelles et fraîcheur de présence |
| `play` | aucun | reprend l'horloge ; remet les intentions manuelles à zéro |
| `pause` | aucun | suspend l'horloge et annule le scénario |
| `manual` | aucun | quitte le scénario et remet les intentions à zéro |
| `reset` | aucun | pause, état initial, acquisition vidée ; conserve la configuration |
| `edit` | `params`: sous-ensemble des quatre paramètres | applique les entrées et journalise |
| `scenario` | `name`: `brake` ou `reverse` | démarre le scénario depuis l'état physique courant |

`brake` commande +0,75 avec homme-mort pendant 4 s puis le relâche ; fin à 10 s.
`reverse` commande +0,7 pendant 3 s, −0,7 jusqu'à 7 s, puis relâche ; fin à 10 s.
La fin du scénario rend la main, mais laisse l'horloge avancer.
L'absence d'une commande `input` fraîche pendant plus de 450 ms relâche l'homme-mort et
annule le scénario. Il n'existe pas de propriété de session ni d'arbitrage entre onglets.

## Exports

| Route | Contenu |
|---|---|
| `GET /model` | `MaVariante.mo` : source Atelier et modèle dérivé avec valeurs courantes |
| `GET /csv` | tampon de frames, colonnes `t,seq` et signaux |
| `GET /session` | configuration courante, événements retenus, frames, nom du modèle et note |

Le tampon retient 15000 pas, soit 300 secondes simulées. L'export JSON n'inclut pas un
journal exhaustif de toutes les modifications ni un état initial restaurable : il ne permet
pas de promettre un rejeu déterministe. Exporter n'implique pas qu'une fonction d'import existe.

## Écarts à traiter lors de la refonte

- Distinguer attente d'installation, compilation, prêt, erreur et données périmées.
- Identifier la source virtuelle/USB côté serveur et introduire un propriétaire du pilotage.
- Ajouter version du protocole, identité/hash du modèle chargé et identifiant de session.
- Détecter explicitement trous de séquence et troncature du tampon.
- Séparer pause de l'horloge et arrêt physique : Pause fige aussi la vitesse.
- Éviter que des données du modèle source modifié sur disque soient exportées comme si elles
  correspondaient à la FMU déjà chargée ; provenance du modèle à rendre explicite.
- Le contrôle du nom du paramètre et de sa plage existe ; la validation du corps JSON complet
  et la gestion des mutations natives doivent être renforcées avant des usages multi-clients.

Ces écarts sont des observations de lecture, pas des fonctions corrigées ou des preuves de recette.
