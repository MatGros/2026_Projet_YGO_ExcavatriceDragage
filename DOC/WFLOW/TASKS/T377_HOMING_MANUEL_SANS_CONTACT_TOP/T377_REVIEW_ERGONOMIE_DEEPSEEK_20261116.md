🔴 **BLOCK** — Verdict : 2 bloquants de conception, 8 majeurs, 1 mineur, 2 points à vérifier. Impact : le cycle peut se figer avec `M3Locked`, repartir sans diagnostic après Reset, ou imposer une montée longue sous homme-mort avec reprise non spécifiée. Durée : ~20 min ; horodatage : session lecture seule, date non fournie.

Limites : aucune lecture fichier ni exécution. Les constats sont des inférences sur l’état décrit ; les points ⚪ nécessitent vérification code/simulation.

**Constats**

1. ✅ PASS — Démarrage à froid : pas d’auto-start, `StartEdge`/`BtnValidationEdge` sont des edges. Action : conserver edge + debounce.
2. ❌ FAIL MAJOR — HX0 : `JoystickDeflected` bloque sans message ; en HX0 `M3Locked` est faux, donc M3 reste libre. Action : afficher « manche au neutre requis » et vérifier l’interlock M3.
3. ❌ FAIL BLOQUANT — HX2 : montée sous homme-mort + manche tiré jusqu’à 300 s ; relâchement → commande tombe, `ClimbTimer` reset, reprise au ré-appui sans re-arm ; arrêt/frein non spécifié. Action : définir hold/frein + re-arm explicite + timer anti-pompage.
4. ❌ FAIL MAJOR — HX2 : gardes couple/skew/capteur peuvent couper la montée sans cause IHM. Action : exposer la garde fautive.
5. ❌ FAIL MAJOR — HX2A : contact répétable sans compteur/limite, pas de timeout, C8 non persistant. Action : compteur + bannière persistante + limite/acquittement.
6. ❌ FAIL MAJOR — Refus validation : compteur seul, pas de message par garde. Action : message explicite par garde + compteur visible.
7. ❌ FAIL MINEUR — `BtnValidation` dual HX0/HX2 ; `BtnStart`/`BtnConfirm` séparés ; appui en HX1/HX1a/HX4/HX5 probablement no-op. Action : libellés contextuels + désactivation hors contexte.
8. ❌ FAIL BLOQUANT — Power cut / Enable FALSE / bascule mode : `PowerCutOff` masquée (`PRG_04:1632`), sync bypass (`PRG_06:355`), reprise non définie ; mode switch → `M3Locked` + Reset inaccessible ; états partiels benne/couplage et re-HomeReq possibles. Action : matrice abort/reprise + cause latch + HomeReq one-shot.
9. ❌ FAIL MAJOR — `M3Locked` pendant tout cycle : translation légitime bloquée ; HX7 + mode switch = deadlock. Action : abort contrôlé vers HX0 safe libérant M3.
10. ❌ FAIL MAJOR — `CmdWinchSelect` forcé (`PRG_03:95-99`) : sélecteur opérateur ignoré sans feedback ; désync post-cycle/codeur. Action : verrouiller/indiquer + resync fin de cycle.
11. ❌ FAIL MAJOR — HX7 : Reset unique peut relancer sans réparation ; timeout HX3 doit couper HomeReq ; 60 s à vérifier ; cause C8 non persistante. Action : diagnostic cause/étape/compteur + acquittement avant Reset.
12. ❌ FAIL MAJOR — Ergonomie : `BtnValidate` IHM vs homme-mort, séquence longue, latch peu visible, retour HX2 implicite, confirmation benne manuelle avec `BucketBusy` neutralisé (`PRG_04:501`). Action : guidage pas à pas + bannière + checklist benne.
13. ⚪ N/A — Interlock HX0 vs homing unitaire non décrit. Action : ajouter garde « unit homing actif » + feedback.
14. ⚪ N/A — Consommateurs/checklist/simulation non vérifiables sans fichiers. Action : revue des consommateurs + tests de simulation.

**Argumentaire technique**

Les gardes HX2 sont cohérentes ; les défauts sont aux sorties de cycle : mode, Enable, power cut et HX7. Le latch C8 est correct mais volatile, donc l’opérateur perd la trace après dégagement. Le refus de validation n’expose pas la garde fautive, ce qui favorise les répétitions aveugles. Les overrides `CmdWinchSelect`/`M3Locked` sont des effets globaux à tester chez tous les consommateurs.

**A. Effets de bord non visibles**

- `CmdWinchSelect` : `PRG_03:95-99` surcharge le sélecteur ; tout consommateur voit la valeur forcée, pas la position réelle.
- `M3Locked` : translation M3 ; HX7/mode exit peut bloquer sans échappatoire.
- `MachineHomed`/état cycle : rétention après reboot non spécifiée ; commit HX6 atomique à vérifier.
- `BtnValidationEdge` : dual HX0/HX2 ; bits IHM/checklist à contrôler.
- `BucketBusy`/`SyncBlocks` neutralisés : benne non surveillée ; checklist manuelle obligatoire.
- Simulation : injecter power cut, mode exit, Enable false, capteur bloqué, toggle sélecteur, validations répétées.

**B. Top 5 recommandations / plan chirurgical**

1. Localisation : `PRG_03:95-99`, `PRG_04:1632`, `PRG_06:355`. Ancre : overrides MAINT_N2. Action : matrice abort/reprise + cause latch + M3 safe. Outil : G200 + test simulation. Risque : reprise non déterministe.
2. Localisation : FB T377 HX2/HX2A/HX7. Ancre : gardes/latch. Action : diagnostic par garde + compteur + bannière persistante. Outil : G521/pytest. Risque : répétitions aveugles.
3. Localisation : HX3/HX4. Ancre : HomeReq one-shot/retry. Action : verrou persistant + timeout coupe HomeReq + atomicité preset. Outil : G340/pytest. Risque : preset accidentel.
4. Localisation : HX0 entry + homing unitaire. Ancre : `StartEdge`/`BtnValidationEdge`. Action : interlock unit homing + feedback joystick. Outil : G200. Risque : conflit cycle/homing.
5. Localisation : IHM `BtnValidation`/`BtnConfirm`/`BtnStart`. Ancre : libellés/context. Action : désactiver hors contexte + prompts + « sélecteur verrouillé ». Outil : revue IHM + simulation. Risque : erreur opérateur.