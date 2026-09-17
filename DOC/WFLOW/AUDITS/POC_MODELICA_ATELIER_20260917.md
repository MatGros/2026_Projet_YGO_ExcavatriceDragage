# Audit de passation — POC Modelica Atelier — 2026-09-17

Le POC indépendant est disponible sous `TOOLS/TWINBENCH/modelica_atelier/`. Il contient une source
Modelica annotée (`Atelier.mo`), une compilation FMU OpenModelica, un pont ctypes OMSimulator, un
serveur loopback et une interface conduite/édition/courbes.

## Preuves

- `node --check TOOLS/TWINBENCH/modelica_atelier/app.js` : PASS.
- Contrat `TASK_CONTRACT_POC_MODELICA_ATELIER.yaml` : PASS.
- `verify.py` natif : PASS : homme-mort, deux sens, freinage, masse, capteur, surcourse, bornes,
  export et relecture Modelica.
- Performance du petit modèle : 1 200 pas / 24 s simulées en environ 0,069 s, soit environ
  0,058 ms par pas sur la machine de développement. Cette mesure ne prédit pas la performance
  d’une machine complète.

## Passation

Le fichier `CLAUDE_CODE_BRIDGE.md` est le contrat de design à transmettre à Claude Code.
Le fichier `CLAUDE_CODE_BRIDGE_PROMPT.md` est le prompt prêt à copier.

Reprise : ajout de `API_ACTUELLE.md` (routes, commandes, signaux, unités, plages, limites)
et `DESIGN_WORKFLOW.md` (parcours, états indépendants, édition et chronogrammes, lots).
Le JSON du brief est désormais explicitement identifié comme proposition cible non implémentée.
Sa grandeur physique est qualifiée de simulée et non de mesure réelle.
Ces compléments résultent d'une revue des sources ; aucune nouvelle recette native ou USB
n'a été effectuée pendant cette reprise documentaire.

## Limites déclarées

### Correctif multi-joysticks

- Cause : `find(Boolean)` choisissait le premier périphérique, notamment vJoy.
- Correction : sélection explicite par index et identifiant, liste actualisée,
  neutralisation au changement et à la perte du périphérique. Aucun repli automatique.
- Garde-fou `check_atelier_input.cjs` : PASS avec vJoy + gamepad simulés,
  changement, déconnexion et reconnexion sans réactivation. Recette matérielle attendue.

### Apprentissage joystick

- Ajout : télémétrie directe des axes `A<n>` et boutons `B<n>` du périphérique
  explicitement sélectionné, plus capture volontaire de l'axe et de l'homme-mort.
- Après capture d'axe, le pilote doit relâcher la commande et calibrer le neutre ;
  l'apprentissage n'arme jamais le joystick.
- Garde-fou `check_atelier_input.cjs` : PASS pour la capture d'un axe et d'un bouton
  réellement actionnés dans le double Gamepad API.

### Reprise interactive — commandes combinées

- `fix:` séparation du levier, des touches et du maintien au pointeur. Espace ne
  remet plus le levier souris au neutre ; une flèche ne désactive plus le maintien.
- Perte de focus et erreur réseau : purge des touches et gestes locaux en cours.
- `guard:` `TOOLS/AGENT_WORKFLOW/scripts/check_atelier_input.cjs` exerce les vrais
  gestionnaires JavaScript avec un DOM minimal (pas une recette navigateur/USB).
- Périmètre : interface seulement ; physique Modelica et code PLC inchangés.

### Premier jumeau mécanique M1–M2–M3

- Modèle Modelica étendu : M1 retenue, M2 benne et M3 translation.
- Conventions issues du projet : ouverture `M2−M1 = 0 m`, fermeture `15 m`,
  translation M3 permise si M1 et M2 sont tous deux au-dessus de 6 m.
- Preuve native `verify.py` : PASS pour la cinématique de benne et l'interlock M3.
- Les photos terrain confirment une benne preneuse à deux coquilles, biellettes et
  mouflage. Elles ne suffisent pas à identifier le nombre exact de brins, les rayons
  de poulies/tambours, les masses ni les rendements : ces paramètres restent à relever.

### Visibilité machine et pilotage multi-axes

- Ajout d'une vue cinématique visible M1/M2/benne sous le panneau M3, avec les mesures
  de câble, delta et pourcentage d'ouverture réellement issus de l'FMU.
- Les trois axes USB sont maintenant configurables et apprenables séparément : M3,
  M1 retenue et M2 benne. Les M1/M2 sont neutres tant qu'ils ne sont pas affectés.
- Contrat de protocole : le navigateur avertit si un processus serveur historique (M3
  seul) est encore lancé ; il doit être redémarré avant toute recette M1/M2.

Le modèle est pédagogique, non calibré, sans PLC réel, sans eau/terrain/thermique triphasé.
L’édition structurelle à chaud et le rejeu déterministe ne sont pas encore implémentés. Le
joystick USB est codé via Gamepad API mais doit être validé avec le périphérique réel.
