# 🖥️ Analyse Fonctionnelle — Partie 7 : Interface IHM (v1.6)

> Complément à `AF_Partie-07_Interface_IHM_v1.5.md`. Les structures non modifiées restent
> définies par v1.5.

## G. Translation M3 — ajout positionneur maintenance

`ST_TranslationHMI` ajoute deux champs :

| Champ | Type | Direction | IHM |
|---|---|---|---|
| `PositioningSelect` | BOOL | IHM→PLC | Sélecteur explicite : `FALSE`=Jog, `TRUE`=Positionneur |
| `PositionReached` | BOOL | PLC→IHM | Voyant cible atteinte en positionneur maintenance ou SEMI_AUTO ; non mémorisé |

En positionneur, l'IHM fournit également `SelectedTargetNum`. Le sens reste choisi par
`ReqFwd`/`ReqRev` ou par joystick selon `JoystickSelect`. En jog, `SelectedTargetNum` est
ignoré par le PLC. Le voyant `PositionReached` est le retour opérationnel d'arrivée ; ne pas
utiliser `Done`, qui n'est pas renseigné par `FB_Translation`.

## 🔧 Application CODESYS 3.5

Après import du bundle, ajouter à la vue M3 :

- un sélecteur Jog / Positionneur lié à `GVL_IHM.TranslationM3.PositioningSelect` ;
- un sélecteur cible actif seulement en positionneur, lié à `SelectedTargetNum` ;
- un voyant lecture seule "Position atteinte" lié à `PositionReached`.
