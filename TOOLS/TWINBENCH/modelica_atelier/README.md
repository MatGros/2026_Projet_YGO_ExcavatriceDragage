# Atelier — POC Modelica interactif

Prototype indépendant du premier TwinBench. **Physique Modelica compilée en FMU,
exécutée par OMSimulator natif**. Aucun moteur physique de remplacement en JavaScript
ou Python. Aucune connexion au PLC et aucune modification de CODE/.

## Fondation réaliste en cours : M3 contractuel

Le modèle pédagogique `Atelier.AxisLab` reste utile pour l'IHM et le joystick. La migration
de SimBench démarre toutefois dans `Dredge.mo`, séparée de cette IHM :

- `Dredge.TranslationM3Plant` reçoit uniquement des **commandes finales PLC** M3 ;
- elle publie une image capteurs (fréquence, frein, cinq positions, StatusWord, défaut conflit) ;
- `dredge_runtime.py` l'exporte en FMU OpenModelica CS2 et l'exécute via OMSimulator ;
- aucune permission, safety, AU, reset ou sortie physique n'est implémentée dans la FMU.

Dans OMEdit : ouvrir `Dredge.mo`, choisir `Dredge.Examples.M3ContractCycle`, cliquer
**Simuler**, puis tracer `plant.positionM`, `plant.velocityMps`, `plant.brakeIsOpenDI` et
`plant.posMaintenanceDI`. Pour vérifier le chemin qui sera utilisé par l'adaptateur hors PLC :

```powershell
py -3.13 TOOLS/TWINBENCH/modelica_atelier/verify_dredge_m3.py
```

Cette étape n'autorise pas le remplacement de `FB_SimBench` : la parité M1/M2, benne, chaîne
machine et le rejeu déterministe restent obligatoires.

## Ouvrir

Double-cliquer `Lancer_Atelier.bat`, ou lancer :

```powershell
python TOOLS/TWINBENCH/modelica_atelier/server.py
```

Page locale : <http://127.0.0.1:8766>. La première compilation peut prendre du temps.
Prérequis : Python 3.11+ et installation **complète** OpenModelica Windows (compilateur,
outils FMU et OMSimulator). Pas de dépendance Python à installer.
`OPENMODELICAHOME` permet de sélectionner une installation explicitement.
Fermer le serveur avec Ctrl+C. Un seul onglet de pilotage à la fois dans ce POC.

## Expérience en 90 secondes

1. Démarrer, puis cliquer sur le levier pour lui donner le focus.
2. Maintenir Espace (homme-mort), utiliser les flèches gauche/droite ou glisser le levier.
   Le bouton homme-mort à l'écran est également maintenu, utile sur écran multitouch.
3. Relâcher Espace : observer le ralentissement et le serrage progressif du frein.
4. Ouvrir « Modifier la machine », changer la masse, refaire le même geste.
5. Déplacer le capteur dans le dessin ou avec son curseur.
6. Choisir « Capteur » puis « + Tracer ». Les booléens sont tracés en escaliers.
7. Lancer l'essai de freinage ; reprendre la main avec le bouton dédié.
8. Exporter le modèle pour OMEdit, les traces CSV ou la session JSON.

## USB

Choisir Joystick USB. Appuyer sur un bouton physique pour que le navigateur détecte
le périphérique. Choisir explicitement le bon appareil dans « Périphérique » :
vJoy et les autres appareils restent disponibles mais ne sont jamais choisis automatiquement.
Exception explicitement configurée : `STANDARD GAMEPAD Vendor: 045e Product: 0b22`
est choisi par défaut quand le navigateur l'expose. Cette sélection n'arme jamais le
joystick ; l'activation volontaire et l'homme-mort restent nécessaires.
Un changement ou une déconnexion neutralise le pilotage ; une reconnexion exige une
nouvelle sélection et activation. Le neutre est remis à zéro au changement d'appareil.
Affecter axe et bouton homme-mort, calibrer au neutre, régler zone
morte et inversion, puis activer volontairement le joystick. Profil sauvegardé dans
le navigateur. Déconnexion, perte de focus ou onglet masqué désactivent la commande.
La Gamepad API ne garantit pas tous les périphériques ; la recette matérielle doit
être effectuée avec le joystick de l'utilisateur.

### Apprentissage en direct

Après avoir choisi le périphérique, la zone **Apprentissage** affiche ses entrées :
`A0`, `A1`… sont les axes (valeurs de -1 à +1) et `B0`, `B1`… les boutons actifs.

1. Cliquer **Apprendre l’axe**, puis déplacer nettement la commande à utiliser.
2. Relâcher cette commande et cliquer **Calibrer le neutre**.
3. Cliquer **Apprendre l’homme-mort**, puis appuyer le bouton de maintien.
4. Cliquer **Activer le joystick** seulement après avoir vérifié ces affectations.

L’apprentissage ne retient qu’une entrée volontaire et ne démarre jamais le mouvement.
Pour piloter la machine complète, choisir successivement `M3`, `M1` et `M2` dans
« Axe à apprendre », puis actionner l'axe physique voulu. Les axes M1/M2 non affectés
restent à `−1 = neutre`, donc sans commande. Le calibrage mémorise un neutre séparé
pour chaque axe.

## Modelica / OMEdit

Ouvrir `Atelier.mo`, puis `Atelier.AxisLab` : le modèle contient M3 Translation,
M1 Retenue et M2 Benne. Les sous-modèles Drive, Carriage et Winch restent
inspectables et modifiables.

### Premier essai autonome dans OMEdit

`AxisLab` attend normalement ses commandes de l'application externe. Pour apprendre
OMEdit sans joystick, développer `Atelier > Examples`, puis sélectionner
`CycleM1M2M3` et choisir **Simuler**. Après la simulation, passer dans la perspective
**Tracer** et développer `machine` dans le navigateur de variables. Cocher :

- `position`, `m1Position` et `m2Position` pour les déplacements en mètres ;
- `bucketOpening` pour l'ouverture en pourcentage ;
- `held` pour voir les phases d'homme-mort.

La durée configurée est 75 s. Ce scénario lève M1/M2, translate M3, ferme puis rouvre
la benne. Il sert uniquement de démonstration du workflow. Il ne contient pas encore
de géométrie animée.

Pour voir une vue 3D mobile, sélectionner `Atelier > Examples > AnimatedCycle`, puis
choisir **Simuler avec animation**. La scène montre un rail, le chariot M3, deux câbles,
une traverse et deux mâchoires dont l'écartement suit `bucketOpening`. Cette géométrie
est pédagogique : elle ne représente pas encore les dimensions ni le mouflage réels.

Le bouton « Exporter le modèle » télécharge `MaVariante.mo`, autonome, contenant le
package source et un modèle MaVariante avec les valeurs courantes comme valeurs
d'entrée par défaut. Ouvrir ce fichier seul (éviter deux définitions d'Atelier dans
la même session OMEdit), choisir MaVariante puis vérifier/simuler.

Le démarrage natif sans stimulus laisse le joystick au neutre : c'est attendu.
Une entrée lever et une entrée held doivent être stimulées pour conduire.
Les commandes externes peuvent remplacer les valeurs par défaut de la variante.

Modifier `Atelier.mo` dans OMEdit puis sauvegarder et **redémarrer le serveur** pour
recompiler. La clé de cache inclut son contenu. L'édition structurelle à chaud et
le chargement de variantes arbitraires depuis le navigateur ne sont pas implémentés.

## Architecture et sorties

- `Atelier.mo` : unique source des équations, connecteurs et schéma physique.
- `runtime.py` : compilation et interface ctypes avec l'API C d'OMSimulator.
- `server.py` : moteur à pas de 20 ms, arbitrage des commandes et HTTP loopback.
- `index.html`, `app.js`, `style.css` : pupitre, édition paramétrique et courbes.
- `verify.py` : essais fonctionnels de la vraie FMU et validation du fichier exporté.

Les produits du compilateur et scratchs OMSimulator restent sous le **temp système**,
dans TwinBenchAtelier. Ils ne sont jamais supprimés automatiquement. Les téléchargements
vont dans le dossier choisi par le navigateur. Le POC ne touche pas aux bundles CODESYS.

Acquisition limitée aux 15 000 derniers pas (300 s). Les courbes affichent 20 s.
Pause des courbes indépendante de la simulation. JSON et CSV exportent le tampon
disponible ; ils ne constituent pas encore un mécanisme de rejeu déterministe.

## Modèle et limites

M3 combine masse mobile, effort moteur filtré, traînée visqueuse, frein lissé et
capteur de proximité. M1 (retenue) et M2 (benne) sont deux treuils à vitesse de câble
filtrée : `M2 − M1 = 0 m` représente la benne ouverte, `15 m` la benne fermée.
M3 est inhibée lorsque M1 ou M2 passe sous 6 m, conformément à la configuration projet.
Les curseurs M1/M2 sont disponibles dans le pupitre virtuel et partagent l'homme-mort.
La vue « Mécanisme vivant » représente séparément les deux groupes de câble, la tête M1,
la traverse M2, les biellettes et les deux coquilles ; c'est un schéma cinématique, pas
un relevé dimensionnel de la machine.
Le frein est une approximation dissipative, pas un modèle validé de friction statique.
Pas de butée mécanique : une surcourse est visible et tracée, jamais écrêtée.
Changer la masse pendant un mouvement est une expérience paramétrique ; aucune
conservation de quantité de mouvement d'une prise de charge n'est revendiquée.
La scène ne borne pas la position : le chariot peut sortir du cadre au-delà du rail.

Contrôleur expérimental : pas le ST de la machine, pas les autorisations/interlocks PLC.
Pas de treuils, benne, eau, terrain, électrique triphasé ni thermique dans ce premier POC.
Temps réel souple : un pas en retard n'est pas supprimé ; le calcul par pas est affiché.
Le fil physique est indépendant des rafraîchissements du navigateur. Après 450 ms
sans commande fraîche, l'homme-mort est relâché (également pendant un scénario).

## Vérifier

```powershell
python TOOLS/TWINBENCH/modelica_atelier/verify.py
node --check TOOLS/TWINBENCH/modelica_atelier/app.js
node TOOLS/AGENT_WORKFLOW/scripts/check_atelier_input.cjs
```

Le test vérifie immobilité sans homme-mort, deux sens, freinage, influence de la masse,
édition du capteur, surcourse, cinématique M2−M1, interlock de hauteur M1/M2,
rejet de paramètres invalides et relecture Modelica.
La performance mesurée concerne le petit modèle du POC, pas une machine complète.

Le garde-fou JavaScript exerce les gestionnaires réels dans un DOM minimal : levier
à la souris + Espace, homme-mort au pointeur + flèches, relâchements combinés,
perte de focus et neutralisation locale après erreur réseau. Les champs de réglage
ne capturent pas les raccourcis de conduite. Ce test ne remplace pas une recette USB.
