# FB_Sim_Joystick — Spec composant (v1.1)

## 1. Role et perimetre

Simulation des entrees brutes joystick (bus CAN hors ligne), brique de banc
reduite AF03. Producteur : `FB_SimBench.instSimJoystick`. Le vrai
`FB_Joystick` reste seul proprietaire de `DeadmanArmed` et des consignes axes.
Cette version remplace la v1.0 pour le geste operateur T418 valide par humain.

## 2. Interface

| Entrees | Role |
|---|---|
| `Enable` | FALSE : neutre, bouton FALSE, timers et geste reinitialises |
| `BtnLeft_Rev_TREMIE`, `BtnRight_Fwd_MAINT`, `BtnFwd_Up_Close`, `BtnRev_Down_Open` | Un seul bouton IHM maintenu demande un geste complet |
| `GesturePermit` | Stimuli manuels neutres et bouton manuel relache ; aucun rapport avec le permis machine reel |
| `ArmHoldTime` | 200 ms avant debut debattement ; reglage local du modele |
| `ButtonReleaseDelay` | 200 ms apres debut phase mouvement, puis relachement bouton armement |
| `NeutralRaw`, `MaxRaw` | Neutre 5000 et pleine course 10000 par defaut |
| `RiseTimeS`, `FallTimeMs`, `CycleTimeS` | Dynamique analogique : 1,5 s, 200 ms, 10 ms par defaut |
| `OvershootActive`, `BagotementActive` | Injections explicites de depassement et oscillation au retour |

| Sorties | Role |
|---|---|
| `RawX`, `RawY` | Axes bruts dynamiques |
| `RawButton` | Appui armement sequence, relache alors que le manche reste deplace |
| `ModelActive` | Propriete exclusive des trois signaux bruts par le geste automatique |
| `ReturningActive` | Retour dynamique / bagotement en cours |

## 3. Sequence temporelle

```text
IHM direction     ____|==============================|_______
Bouton armement  ____|========|_____________________________
Manche           __________/========================\______
                     200 ms   200 ms apres debut mouvement
```

Le premier scan accepte seulement le relachement complet. Un nouvel appui
unique declenche l'appui armement au neutre ; le debattement commence apres
la phase de maintien. Le bouton armement retombe une fois le delai ecoule,
sans annuler le debattement maintenu. Le relachement IHM provoque le retour.

Annulation pendant appui : aucun debattement differe. Conflit ou inversion
directe : retour neutre, aucun nouveau geste avant boutons tous relaches
APRES stabilisation. Un nouvel appui pendant le retour n'est pas memorise.
OFF/ON avec bouton tenu ne relance pas le geste.

Les TON utilisent le temps de tache ; les rampes utilisent `CycleTimeS`.
Un parametre de rampe non positif neutralise le modele et reinitialise le geste.
Les constantes locales de phase sont comparees par IF/ELSIF pour compatibilite
avec le compilateur CI actuel.

## 4. Arbitrage SimBench

Au repos, les stimuli manuels `SimJoystickRawX/Y/Button` restent disponibles.
Un geste exige leur neutre nominal (5000/5000/FALSE). Pendant geste, annulation
et retour, le modele possede ensemble X, Y et bouton : aucun OR des sources.
Un stimulus manuel devenu non neutre annule le geste et bloque le retour de
propriete au manuel jusqu'a restauration des stimuli neutres. Cela evite un
saut analogique ou un front brut parasite apres le retour.

Hors `FB_SimBench.Enable`, l'image `HwReal` est rendue sans alteration, et le
sous-modele joystick est explicitement appele avec Enable FALSE.
`FB_SimBench.OperatorSourceActive` recoit le selecteur effectif
`OperatorInputSourceSimulated` de PRG_02. FALSE : reset du sous-modele et
publication directe de `HwReal.Operator`, sans fallback vers les stimuli.
La reselection avec bouton directionnel tenu exige un relachement complet.

## 5. Limites et preuves

Les temporisations simulees ne constituent PAS un acquittement d'armement.
Le modele ne lit ni ne force `DeadmanArmed` ou `ArmingPermit` machine. Il est
teste avec la configuration reelle par defaut : maintien 100 ms, grace 3 s,
neutre 100 ms. Une configuration differente peut legitimement refuser le geste.
Un nouveau geste rapproche peut debuter alors que le joystick reel est encore
arme : la grace est preservee. Aucun rearmement simule ne se repete quand
l'IHM reste tenue apres perte de permis reel.

**Interaction existante N2 :** `JoyBtnRaw` est aussi `BtnValidation` du vrai
homing. Un nouvel appui peut lancer HX1 meme sur machine referencee et
verrouiller M3. TC-T418-INT-004 caracterise ce comportement sans le masquer.
Ce lot ne revendique donc pas un jog M3 operationnel en N2 dans ce contexte.

**Bascule de source operateur :** le domaine est selectionne independamment
du Enable global, mais sa selection effective pilote maintenant le sous-modele.
TC-T418-INT-008/010/011 verifient absence de reprise apres reselection,
pendant mouvement, armement et retour. La transition vers un joystick PHYSIQUE
deja tenu conserve la semantique d'acquisition reelle de la MES et n'est pas
un cas de simulation de l'operateur ; aucune securisation generale des
changements de source sous commande physique n'est revendiquee.

## 6. Catalogue de validation

| ID | Verification | Preuve |
|---|---|---|
| <nobr><code>TC-P13-050</code></nobr> | Premier scan au neutre, aucun armement | CI FB_SimBench |
| <nobr><code>TC-P13-051</code></nobr> | Mode manuel via stimuli d'entree, hors propriete automatique | TC-T418-INT-005 |
| <nobr><code>TC-P13-052</code></nobr> | Debut appui au neutre puis sequence | CI FB_SimBench + TC-T418-001 |
| <nobr><code>TC-P13-JOY-001</code></nobr> | Enable FALSE neutralise le sous-modele | CI FB_Sim_Joystick |
| <nobr><code>TC-T418-001..006</code></nobr> | Chronologie, activation tenue, annulation, inversion, conflits, dynamique | CI FB_Sim_Joystick |
| <nobr><code>TC-T418-INT-001</code></nobr> | Vrai armement, maintien apres relachement, deux gestes rapproches puis desarmement | CI SimOperatorJoystick |
| <nobr><code>TC-T418-INT-002..003</code></nobr> | Refus et perte/restauration permis sans reprise | CI SimOperatorJoystick |
| <nobr><code>TC-T418-INT-004</code></nobr> | Constat HX1 en N2 sur appui brut | CI SimOperatorJoystick |
| <nobr><code>TC-T418-INT-005</code></nobr> | Priorite sources et absence de saut vers manuel | CI SimOperatorJoystick |
| <nobr><code>TC-T418-INT-006</code></nobr> | Repli reel et reactivation tenue | CI SimOperatorJoystick |
| <nobr><code>TC-T418-INT-007</code></nobr> | Maintien reel trop long : refus sans bypass | CI SimOperatorJoystick |
| <nobr><code>TC-T418-INT-008</code></nobr> | Reselection apres mouvement sans reprise tenue | CI SimOperatorJoystick |
| <nobr><code>TC-T418-INT-009</code></nobr> | Reference etablie, N1 puis SEMI_AUTO sans HX1 par geste | CI SimOperatorJoystick |
| <nobr><code>TC-T418-INT-010..012</code></nobr> | Deselection pendant armement/retour, image reelle exacte | CI SimOperatorJoystick |
| <nobr><code>TC-T418-REF-001</code></nobr> | Trois commandes manuelles, vrais codeurs/benne et retours SimBench | CI SimManualReference |

Validation CI = logique hors PLC ; compilation et recette CODESYS restent humaines.
G528 controle le cablage exclusif, la reinitialisation et l'absence de production
de l'etat arme, avec mutations negatives. Aucun Device.export utilise.
