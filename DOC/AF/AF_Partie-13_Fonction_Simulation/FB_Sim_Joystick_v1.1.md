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

**Bascule de source operateur :** `SimOperatorActive` est selectionne dans
PRG_02 independamment du Enable global du banc. Le sous-modele ne connait pas
cette selection et continue en arriere-plan. Une reselection pendant un geste
peut reprendre une demande sans nouvel appui IHM si le vrai joystick est
encore arme pendant sa grace. TC-T418-INT-008 reproduit ce constat par le meme
arbitrage X/Y/bouton en amont du vrai joystick (sans executer tout PRG_02).
La bascule de domaine doit donc rester au repos, boutons relaches ; ce lot
ne revendique aucune detection automatique de cette bascule. La revue expert
classe ce point MAJOR avant toute promesse d'absence d'effet cache.

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
| <nobr><code>TC-T418-INT-008</code></nobr> | Constat reprise a la reselection de source pendant la grace | CI SimOperatorJoystick |

Validation CI = logique hors PLC ; compilation et recette CODESYS restent humaines.
G528 controle le cablage exclusif, la reinitialisation et l'absence de production
de l'etat arme, avec mutations negatives. Aucun Device.export utilise.
