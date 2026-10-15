# T418 - Revue independante expert automatisme industriel

Reviewer expert_joystick, lecture seule, aucun fichier edite par le reviewer.

## Verdict final

PASS sur le geste simule, l'arbitrage exclusif manuel/automatique, le complement
de selection de source et le test de reference manuelle. Pret pour recette
CODESYS humaine ciblee apres controles finaux de l'orchestrateur.

## Conclusions

- Source inactive : reset sous-modele et image reelle exacte ; raccordement au
  selecteur effectif OperatorInputSourceSimulated, pas au flag global.
- Aucun filtre homing implemente. FB_Joystick, FB_CycleMachineHoming,
  FB_CycleSemiAuto et traitement PRG_02 depuis section 3 identiques au tag MES.
- Le MAJOR initial de reprise cachee a reselection est corrige et teste.
- Le front N2 vers HX1 est un comportement MES conserve ; ne pas le presenter
  comme une regression ni comme obstacle general au parcours N1/SEMI_AUTO.
- Test INT-009 : reference DEJA etablie par fixture ; aucun lancement homing
  lors des gestes N1/SEMI_AUTO. Pas une preuve de cycle automatique complet.
- Test REF-001 : vrai SimBench, vrais codeurs et benne, qualification issue
  de leurs sorties. Etat initial non reference ; M2 puis benne restent
  necessaires. Aucun Homed positif injecte et aucune tautologie identifiee.
- Les copies VAR_IN_OUT restituent les resultats publics des FB, sans inventer
  un datum. Le READBACK_ONLY passe par les retours de SimBench.
- Les sources, tests et dependances encodeur/cycle sont compares a la MES ;
  les echecs des anciennes suites restent une dette CI heritee visible.

## Limites de la revue et des essais

Geometrie, arret mecanique, permis et bus sont des conditions de fixture.
Le harnais valide les composants et le raccordement equivalent, pas les pages
IHM, l'approche physique, le PLC complet ou tous les cycles.
Aucun verdict de validation machine complete et aucun Device.export utilise.
