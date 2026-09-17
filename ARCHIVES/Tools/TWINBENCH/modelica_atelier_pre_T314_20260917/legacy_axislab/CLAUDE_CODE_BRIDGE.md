# Pont de conception pour Claude Code — Atelier de simulation

Ce document est une consigne de travail prête à copier dans Claude Code. Il sert à concevoir
l’interface complète autour du POC `TOOLS/TWINBENCH/modelica_atelier/`.

## Mission

Concevoir puis implémenter une interface locale moderne pour un atelier de simulation de machine.
L’utilisateur doit pouvoir :

1. piloter avec joystick virtuel ou joystick USB ;
2. lancer, mettre en pause et reprendre des scénarios ;
3. reprendre la main à tout instant ;
4. modifier des paramètres physiques et des éléments de cinématique ;
5. choisir n’importe quelle grandeur et l’ajouter à un chronogramme en direct ;
6. exporter une session, des traces CSV et une variante `.mo` réouvrable dans OMEdit.

## Sources à lire avant toute proposition

- `TOOLS/TWINBENCH/modelica_atelier/API_ACTUELLE.md` — données et routes existantes
- `TOOLS/TWINBENCH/modelica_atelier/DESIGN_WORKFLOW.md` — proposition de parcours et lots
- `TOOLS/TWINBENCH/modelica_atelier/README.md`
- `TOOLS/TWINBENCH/modelica_atelier/Atelier.mo`
- `TOOLS/TWINBENCH/modelica_atelier/runtime.py`
- `TOOLS/TWINBENCH/modelica_atelier/server.py`
- `TOOLS/TWINBENCH/modelica_atelier/index.html`
- `TOOLS/TWINBENCH/modelica_atelier/app.js`
- `TOOLS/TWINBENCH/modelica_atelier/style.css`
- `TOOLS/TWINBENCH/DOC/SPEC_03_Interface_Devoilement_Progressif.md`
- `TOOLS/TEST_AUTO_CI/DIGITAL_TWIN/SPEC_INTERFACE_FRAME.md`
- `TOOLS/TEST_AUTO_CI/DIGITAL_TWIN/SPEC_ADAPTATEURS_SOURCES.md`
- `DOC/STDS/NAMING_CONVENTION.md`
- `DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md`

## Architecture imposée

```text
Entrée utilisateur / USB / scénario
        → arbitre de source et session
        → commandes brutes (intentions, jamais logique PLC)
        → OMSimulator / FMU Modelica
        → frames horodatées
        → scène + chronogrammes + journal
```

`Atelier.mo` est la source de vérité physique. Le navigateur ne calcule jamais position,
vitesse, frein ou énergie. Toute valeur visible doit venir d’une frame, avec unité et provenance.
Le contrôleur PLC réel n’est pas prétendu être exécuté par ce POC.

## Design à proposer

Écran initial sobre : machine visible, source active, joystick, Démarrer, Scénarios, Modifier,
Observer. Les détails se dévoilent au clic, conformément à `SPEC_03` : N0 scène, N1 objet,
N2 paramètres, N3 physique/courbes, N4 analyse.

Prévoir ces espaces :

- **Conduite** : virtuel, USB, homme-mort séparé, calibration, inversion, zone morte, perte de focus.
- **Scénarios** : préréglages et enregistrement de la conduite manuelle en scénario rejouable.
- **Édition** : paramètres bornés, unités, provenance, aperçu, undo/redo, variante, pause si changement structurel.
- **Chronogrammes** : pistes numériques et booléennes, curseur, zoom, déclenchement, comparaison,
  présélection Translation/Freinage/Forces, ajout libre d’un signal.
- **Journal** : commandes, changements, pannes, transitions, erreurs, temps simulé.
- **Confiance** : état du moteur, version Modelica/OMSimulator, provenance, retard du pas,
  bannière locale hors ligne persistante.

## Contrat de données UI

**Proposition cible, non implémentée.** L'API réellement disponible est documentée dans
`API_ACTUELLE.md`, à utiliser pour raccorder une interface dès maintenant. Ne pas considérer
les champs ci-dessous comme des données actuellement émises par le serveur.

La session cible devrait pouvoir exposer au minimum :

```json
{
  "schema_version": "0.1",
  "engine": {"kind":"OMSimulator", "model":"Atelier.AxisLab", "offline":true},
  "source": {"active":"virtual|usb|scenario", "session_id":"..."},
  "frame": {"t_s":0.0, "seq":0, "provenance":"FMU"},
  "commands": {"lever_req":0, "deadman_req":0, "scenario":"manual"},
  "signals": [{"id":"position","value":12,"unit":"m","kind":"simulated"}],
  "events": [{"t_s":0,"kind":"operator|engine|fault|edit","text":"..."}],
  "quality": {"step_ms":0.3,"dropped_steps":0,"buffered_seconds":300}
}
```

Pour les commandes, conserver la sémantique `Req → Tgt → Cmd → Act`. Une commande injectée
doit être identifiée et ne doit jamais être confondue avec une sortie compilée. Respecter
`NC-050` et `NC-030` pour toute nouvelle variable ST ou interface générée.

## Sécurité et comportement obligatoire

- serveur exclusivement `127.0.0.1` ; aucune écriture vers un PLC ou réseau industriel ;
- bannière `HORS-LIGNE / POC` permanente et non masquable ;
- homme-mort relâché sur relâchement, blur, onglet masqué, déconnexion ou absence de trame de commande ;
- source scénario désactivée dès que l’utilisateur reprend la main ;
- surcourse signalée, jamais écrêtée silencieusement ;
- paramètres rejetés s’ils sont NaN, infinis ou hors domaine ;
- ne jamais afficher une grandeur inconnue comme mesurée ;
- édition structurelle : pause, reconstruction et événement explicite ;
- ne jamais générer de connexion CODESYS dans ce lot.

## Critères de réussite

La proposition de workflow fournie est une base à challenger : Claude Code reste libre de
proposer une meilleure organisation, en justifiant les parcours et en gardant les besoins.

La proposition de Claude Code doit inclure :

1. wireframes des états initial, conduite, édition, courbe et défaut ;
2. inventaire des composants et des états UI ;
3. protocole d’événements et contrat JSON versionné ;
4. stratégie d’adaptation aux écrans tactiles et clavier ;
5. stratégie de courbes (buffer brut, downsampling d’affichage, booléens en escaliers) ;
6. recette USB sur un périphérique réel ;
7. tests UI et tests de non-régression du contrat de frames ;
8. vérification que la physique reste dans Modelica/OMSimulator ;
9. liste explicite des hypothèses et limites restantes.

## Demande prête à envoyer

> Lis `CLAUDE_CODE_BRIDGE.md` et tous les fichiers listés. Analyse l’interface actuelle, propose
> une architecture UX/UI complète pour Atelier, puis produis un plan d’implémentation par lots.
> Commence par des wireframes textuels et un contrat JSON versionné. Ne modifie aucun fichier
> avant d’avoir livré l’audit, les états, les flux de commandes, les risques et les critères de
> recette. Les changements futurs resteront sous `TOOLS/TWINBENCH/modelica_atelier/`.
