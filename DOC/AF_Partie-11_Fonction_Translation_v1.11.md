# 📐 Analyse Fonctionnelle — Partie 11 : Translation M3 (v1.11)

> Complément à `AF_Partie-11_Fonction_Translation_v1.10.md`.

## 🕹️ Retour IHM déflexion joystick

`GVL_IHM.TranslationM3.JoystickDeflectionPct` expose la déflexion fonctionnelle signée de
l'axe X du joystick, issue de `FB_Joystick_0.AxisCmdX.SpeedRef` :

| Valeur | Sens IHM |
|---|---|
| `-100..0` | Déflexion côté direction négative |
| `0` | Joystick au neutre |
| `0..+100` | Déflexion côté direction positive |

Le signal est déjà calibré, filtré, rampé et borné par `FB_Joystick`. Il sert uniquement à
l'animation fonctionnelle de la vue M3. Les valeurs brutes et diagnostics du joystick restent
dans `GVL_IHM.JoystickJOY1` et ne sont pas dupliqués dans l'objet Translation.

## 📂 Sources CODESYS

- `CODE/SUPERVISION/ST_TranslationHMI.st`
- `CODE/MAIN/PRG_09_Supervision.st`
