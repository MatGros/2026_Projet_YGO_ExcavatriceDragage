# 🖥️ Analyse Fonctionnelle — Partie 7 : Interface IHM (v1.7)

> Complément à `AF_Partie-07_Interface_IHM_v1.6.md`.

## G. Translation M3 — animation joystick

| Champ | Type | Direction | Rôle |
|---|---|---|---|
| `JoystickDeflectionPct` | REAL | PLC→IHM | Déflexion fonctionnelle signée axe X, `-100..+100 %`, `0` au neutre ; animation de la commande Translation M3 |

Ne pas utiliser `RawX` dans la vue M3 : il appartient au diagnostic joystick global. La vue M3
consomme la valeur fonctionnelle normalisée, identique à celle utilisée pour le pilotage joystick.
