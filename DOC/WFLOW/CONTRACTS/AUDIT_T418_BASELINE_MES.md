# T418 — Ancrage sur le programme en production

## Reference verifiee

Le tag Git annote `MES_FIN_20260923^{}` resout sur
`44c2b36825f8832b4de60b20635704715bdb17c2`.
Le journal de cloture du 23 septembre concorde avec ce commit. VERSION_HISTORY
cite un autre commit (4968a541) et le registre du 26 septembre mentionne
57076207 : ces metadonnees divergentes ne remplacent pas le tag resolu.
Aucun Device.export utilise et aucune identification du binaire PLC inventee.

## Preuve terrain documentaire

- `DOC/WFLOW/REGISTRES/REGISTRE_Suivi_MiseEnService_20260923.md` : correctifs
  testes sur machine pour inversion DI M1/M2, transfert AX10/AX10B/AX11,
  vidage AX15B/AX15D et translation M3.
- `DOC/WFLOW/REGISTRES/REGISTRE_PrepaNextMES_20260926.md`, J1 : environ
  100 cycles automatiques complets sans blocage majeur le 24 septembre.
- L'humain confirme aujourd'hui des centaines de cycles en exploitation.

## Comparaison mecanique et revue independante

FB_Joystick, FB_CycleMachineHoming, FB_CycleSemiAuto, FB_Bucket,
PRG_04_Treuils_Benne, F_MODES et E_CODEURS sont inchanges depuis le tag MES.
Dans PRG_02, avant notre complement, les 34 lignes ajoutees concernent
OpenModelica / echo M3, pas la conduite ni le homing. Notre complement ajoute
un seul argument dans l'appel de SimBench, section simulation. Le traitement
joystick/codeurs/homing depuis section 3 jusqu'a la fin reste strictement
identique au tag, verifie par audit_t418_commissioning_baseline.py.

Les trois chemins manuels sont conserves : BtnHome/BtnHomingAtZero M1 et M2,
confirmation benne ouverte/fermee avec preset M2 et publication de datum benne.
Leur receptivite d'arret et leurs conditions de mode restent inchangees.

## Rectification du cadrage

Le lancement HX1 sur front joystick en N2 existait a la MES. Il n'est pas une
regression recente du code metier. Les cycles reels valides ne prouvent pas
un parcours quelconque de manipulation N2. Le besoin courant est reference
manuelle existante puis N1 / SEMI_AUTO : ne pas le confondre avec une refonte
du homing ou l'exigence de supprimer tout comportement N2 historique.

Le filtre homing envisage a ete abandonne sans etre implemente. T377 reste
distincte et n'est pas declaree terminee. La simulation produit le geste,
sans changer FB_Joystick ni filtrer son bouton dans le homing.

## Verifications et limites

- TC-T418-INT-009 : reference deja etablie par fixture, gestes N1 puis
  SEMI_AUTO, aucun HX1 et reference conservee. Ce n'est pas un cycle complet.
- SimManualReference : vraie chaine SimBench -> codeurs -> benne ->
  qualification homing, avec trois commandes manuelles successives ; aucune
  valeur Homed positive injectee. Harnais de composants et raccordement
  equivalent, pas execution integrale des PRG ni des pages IHM.
- Les sources ET tests/dependances de FB_Encoder et FB_CycleSemiAuto sont
  identiques au tag MES. Leur execution actuelle rend respectivement 38/40
  et 38/43 : ces ecarts CI restent visibles, sans modifier le metier eprouve
  pour satisfaire des assertions. FB_Bucket 41/41, homing 15/15.
- Le complement corrige la continuation du geste lors de deselection du
  domaine simule : selecteur effectif -> reset du sous-modele et image reelle
  exacte ; reselection tenue ne reprend pas le geste.

Tout essai PLC reste a effectuer dans CODESYS par l'humain. Les reglages
persistants charges et l'IHM ne sont pas assimiles a la configuration de test.
