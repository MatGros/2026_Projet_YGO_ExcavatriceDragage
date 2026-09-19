# T262 — plafond AX10 automatique aligné AX11

| Cas | Mode / stimulus | Attendu |
|---|---|---|
| Auto P1 | SEMI_AUTO, fermeture active, joystick P1, AX11=P2 | M2 cible P1. |
| Auto P5 | SEMI_AUTO, fermeture active, joystick P5, AX11=P2 | M2 cible P2, jamais P3..P5. |
| Auto P5/P1 | SEMI_AUTO, fermeture active, joystick P5, AX11=P1 | M2 cible P1. |
| Manuel P5 | MAINT, fermeture M2 active, joystick P5, plafond benne P5 | M2 cible P5 : la règle AUTO ne s'applique pas. |
| Clamp aval | AUTO P5/AX11=P2 + codeur non fiable ou sync warning | M2 réel P1 ; le nouveau plafond ne relève aucun clamp. |

Preuves : test d'intégration de l'arbitre M2, génération bundle, G200 liaison et revue des sorties de trace. Hors micro-phase : transfert continu AX10→AX11, freins, contacteurs, SimBench.
