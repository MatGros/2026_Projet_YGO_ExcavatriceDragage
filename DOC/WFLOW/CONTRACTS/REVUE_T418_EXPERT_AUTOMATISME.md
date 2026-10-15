# T418 — Revue independante expert automatisme industriel

Reviewer : agent `expert_joystick`, lecture seule. Orchestrateur : CDX01.
Reference du diff : checkpoint `9630ddb5`. Aucun commit de correction ni push.

## Verdict rendu par le reviewer

**MAJOR sur la bascule de source operateur ; PASS sur le geste simule dans
son perimetre nominal.**

Le diff fonctionnel reste limite aux deux FB autorises. L'armement reel,
les PRG, le homing et les modes sont inchanges. La sequence, les annulations,
les inversions, le verrou de relachement, le retour dynamique et l'arbitrage
exclusif manuel/automatique sont coherents.

## Constat majeur non corrige hors scope

- PRG_02_Acquisition:138,482 selectionne la simulation operateur par
  `SimOperatorActive`, independamment de l'activation globale du banc (:313).
- FB_SimBench appelle le sous-modele joystick active tant que le banc l'est.
- Le geste peut continuer quand la source operateur reelle est selectionnee,
  puis reapparaitre au retour simule sans nouvel appui IHM.
- Le test initial OFF/ON du banc ne couvre pas cette selection independante.
  L'orchestrateur a ajoute TC-T418-INT-008 pour caracteriser le risque avec
  l'arbitrage de source et le vrai FB_Joystick.

Le reviewer recommande : si cette frontiere reste hors scope, bascule de
domaine uniquement au repos, boutons relaches, sans pretendre que le modele
detecte la bascule. L'orchestrateur ne declare pas le lot valide pour une
utilisation generale avec changements de source en mouvement.

## Points confirmes

- Reinitialisation du sous-modele avant RETURN lorsque le banc est desactive.
- Propriete exclusive X/Y/bouton pendant geste, retour et conflit manuel.
- Conservation de l'armement reel pendant la grace testee.
- Maintien reel trop long refuse, aucun bypass.
- HX1 en N2 reproduit et annonce, aucun masquage dans la simulation.
- Le XML autonome PRG_02 change car il embarque les dependances simulation ;
  aucun changement du corps du PRG observe.
- G528 est un garde statique de cablage, pas une preuve dynamique.

## Position de l'orchestrateur

Le code reel reste intact conformement a l'instruction humaine. Les deux
interactions (HX1 N2 et selection de source) ne sont pas dissimulees et ne
sont pas corrigees en elargissant silencieusement le perimetre. La demande
d'absence d'effet de bord ne peut etre declaree satisfaite en l'etat.
La suite requiert un arbitrage humain sur le perimetre avant recette generale.
