# T418 — Geste operateur simule : restitution technique avec reserves

## Etat

Implementation et verification du geste nominal terminees. **Lot non valide
pour recette generale** : revue expert MAJOR sur deux interactions conservees
hors scope. Aucun test terrain demande en l'etat.

Checkpoint autorise avant toute modification : `9630ddb5` (42 fichiers de
l'etat initial, NON TESTE). Aucune autre creation de commit, aucun push.

## Changement fonctionnel

Code change uniquement dans `FB_Sim_Joystick.st` et `FB_SimBench.st`.
Un bouton directionnel IHM produit appui armement au neutre (200 ms),
debattement progressif, relachement armement apres debut du mouvement
(200 ms), puis maintien du manche jusqu'au relachement IHM et retour.
Les TON introduisent la quantification normale de quelques scans de 10 ms.
L'armement reel reste entierement produit par le vrai FB_Joystick.

Annulation, conflit, inversion directe et OFF/ON tenu ne generent pas de
depart differe. Les stimuli manuels et automatiques ne sont jamais melanges.
Un conflit manuel pendant geste conserve le modele au neutre jusqu'au
relachement des commandes et restauration des stimuli neutres.

Le code reel joystick, homing, modes, translation et PRG est identique au
checkpoint (controle git diff borne). Le XML autonome PRG_02 change seulement
par ses dependances embarquees, comme confirme par le reviewer.

## Preuves executees

| Verification | Resultat |
|---|---|
| Contrat T418 | PASS 0 erreur / 0 avertissement |
| Simulation complete | 11/11 FB PASS, 105/105 tests dont 8 integrations |
| FB_SimBench avant / apres | 43/43 PASS dans les deux etats |
| Joystick reel, code inchange | 29/29 PASS |
| G528 | PASS, selftest 9 mutations rejetees |
| git diff --check | PASS |
| Bundle complet et diff | Generes, source PLCopenXML complete fraiche |
| G200 | PASS, 0 erreur, 1726 avertissements, 2136 instances |
| Revue independante | MAJOR documente ; geste nominal valide dans le perimetre teste |

Log detaille CI : `T418_CI_SIMULATION.txt`. Revue :
`REVUE_T418_EXPERT_AUTOMATISME.md`. Gates : `T418_GATES_COMPLETS.txt`.
Le DSL STruCpp exige les avances de temps au niveau TEST ; les tests ST
exposent donc explicitement les scans. Les primitives de SETUP sont initialisees
dans chaque test : leurs initialiseurs de declaration ne sont pas emis par le
compilateur CI actuel. G528 empeche leur oubli dans l'integration.

## Auto-verification liaison (bloc du rapport G200)

```text
Auto-verification liaison (G200_check_linkage.py) - PASS
  Linkage (L1-L7):    139 OK, 0 KO
  L8 (Output assign): 0 OK, 0 KO, 0 WARN
  L9 (I/O mapping):   0 OK, 0 KO, 25 WARN
  L10 (Single prod):  1990 OK, 1671 WARN
  L11 (Polarity):     0 OK, 30 WARN
  L12 (Timing):       7 OK, 0 KO, 0 WARN
  L13 (Orphelins):    89 OK, 0 KO
Linkage check: PASS (0 erreur(s), 1726 avertissement(s), 2136 instance(s) verifiee(s))
```

Rapport original complet : `T418_G200_LIAISON.txt`.
Diff bundle : `CODE_XML/CODE_DiffBundle.xml` : FB_SimBench,
FB_Sim_Joystick, avec dependances de type. Ne remplace pas le bundle complet.

## Reserves avant recette

1. **MAINT_N2 / homing :** l'appui brut valide aussi le homing et lance HX1,
   meme avec reference benne valide. M3 est verrouille. TC-T418-INT-004
   caracterise ce comportement du code reel conserve. Aucun filtre du
   simulateur n'a ete ajoute pour le masquer.
2. **Bascule de source :** SimOperatorActive est selectionne dans PRG_02
   independamment du Enable de SimBench. Le geste continue en arriere-plan.
   TC-T418-INT-008 reproduit le selecteur et prouve la reprise a reselection
   pendant la grace reelle, sans nouvel appui IHM. Ce test n'execute pas tout
   PRG_02 : le branchement est reproduit et relu dans sa source inchangee.

L'exigence humaine d'absence d'effet de bord general ne peut donc pas etre
declaree satisfaite. Corriger ces frontieres necessite un lot distinct avec
extension de perimetre validee, en preservant FB_Joystick. Aucun elargissement
silencieux du code reel n'est effectue.

Les valeurs persistantes du joystick en CODESYS n'ont pas ete relevees. Les
tests utilisent la configuration source reelle par defaut et caracterisent le
refus d'un maintien trop long. Aucun Device.export lu, aucune compilation ou
recette du nouveau bundle dans CODESYS revendiquee.

## Gates globaux et artefacts

Les controles globaux restent rouges sur G300, G100, G340, G430, G483 et G519.
Ils concernent structure, liens/documents et code hors du changement fonctionnel.
Les erreurs de formatage TC du nouveau document detectees au premier passage
ont ete corrigees ; les erreurs restantes sont detaillees dans le log final.
Aucun bandeau "bundle exporte et valide" n'est justifie.

G300 signale `TOOLS/AGENT_WORKFLOW/.tmp` et `prototypes`. Les generateurs/CI
conservent leurs scratchs sous les chemins annonces (dont .scratch et .tmp).
Aucun nettoyage, suppression, deplacement ou masquage Git n'a ete effectue.
Les gates ont regenere WINCH_INTEG.html et l'index CI ; ces changements de
rapport restent visibles. La v1.0 de la fiche joystick n'est pas archivee
automatiquement ; la v1.1 est la version active pointee par le chapeau AF13.
