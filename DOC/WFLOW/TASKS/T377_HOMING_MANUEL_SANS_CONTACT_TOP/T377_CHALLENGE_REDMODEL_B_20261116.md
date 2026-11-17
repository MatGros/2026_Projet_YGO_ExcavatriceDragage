🟡 **ADVISORY**

**Verdict :** la réponse RT est juste sur le fond dans 3 points/5, mais contient 1 contradiction interne bloquante (point 5) et 1 inversion de charge de preuve en sécurité (amendement AC3). Le découpage « étapes puis mapping » est sain en développement, **non acceptable en déploiement** : aucun verrou mécanique n'empêche aujourd'hui de tester sur site un grafcet non relié.

**Impact :** le risque n'est pas « le grafcet ne marche pas » mais « le grafcet a l'air de marcher » (états qui avancent, sorties à 0 ou partiellement forcées) sur une machine à charge suspendue — c'est exactement l'inquiétude de l'exploitant, et elle est fondée.

**Accès dépôt / `AGENTS.md` :** absent en session. Aucun numéro de ligne, nom de signal ni contenu de fichier n'est vérifié ici. Tout ce qui dépend du code est traité comme hypothèse à prouver (script/grep), jamais comme PASS.

---

## Niveau 1 — Invariants

1. [❌ FAIL] Point 5 auto-contradictoire : « T377 pré-requis de tout essai » + « T377 après le premier test » → décision non exploitable. Exige scission T377a/T377b ou restriction explicite du périmètre du premier test M3.
2. [❌ FAIL] Point 1 : « l'escalade PowerCutOff n'a AUCUN chemin câblé » est mal formulé. La chaîne existe (FB_Safety_Winch / instSafetyWinch*) ; ce qui manque est un **canal de demande** propriétaire. Le blocage reste juste, la justification doit être « pas de canal de demande vérifié et propriété de sortie non négociable ».
3. [❌ FAIL] Point 2 : amender AC3 pour coller au masque PRG_04:1632 inverse la charge de preuve — on aligne l'exigence sur le défaut constaté, sans dossier de risque résiduel accepté ni mesure compensatoire testable.
4. [❌ FAIL] Point 2 : « stop au contact indépendant du grafcet » via retrait de `EffectivePermit*_Ascent` n'est pas une preuve d'arrêt : ni temps d'arrêt, ni comportement frein, ni survol mesuré ne sont spécifiés.
5. [❌ FAIL] Point 4 : liste fichiers incohérente avec le point 2. `PRG_03`, `PRG_04`, `FB_Safety_Winch`, l'écran IHM et la config variateur (preset 8,50 m) sont absents alors que la compatibilité revendiquée repose dessus.
6. [❌ FAIL] Point 3(b) : retirer cause 8 sans nommer le porteur de l'événement ni la liste des consommateurs de `Fault.Latched`/HX2A laisse intact le risque de stop hors checklist.
7. [✅ PASS] Point 1 : AC2 (4→5 gardes MAINT_N2 seul) et AC4 (23,5 m = référence benne ≠ homing) sont de vrais écarts de contrat, à amender de façon traçable.
8. [✅ PASS] Point 3(a) : le défaut du latch (TRUE/FALSE même scan, raté par l'IHM) est correctement identifié ; la famille de correction est la bonne.
9. [✅ PASS] Point 2 : traiter la barrière PRG_04:1126 comme fondement du « pas de FAIL » est cohérent avec le design voulu (contact ⇒ aucune référence écrite).
10. [❌ FAIL] Aucun point ne traite que le mode autorisant le homing est **celui qui neutralise** `SyncBlocksAscent/Descent` (PRG_04:501-514) → supervision M1/M2 affaiblie pendant la séquence.
11. [❌ FAIL] Aucun point ne nomme le propriétaire unique de `CmdWinchSelect` / `CmdWinchM1/M2` quand `MachineHoming.Active` (conflit PRG_03:95-99 vs FB_Modes direct).
12. [❌ FAIL] Sémantique du latch non spécifiée : front, ordre d'évaluation, remise à zéro sur sortie de mode / init / cycle, code cause. Un bit seul ne diagnostique rien sur site.
13. [❌ FAIL] « Grafcet plus tolérant » sans watchdog ni timeout par état : tolérant = états supplémentaires = façons supplémentaires de rester bloqué.
14. [❌ FAIL] « Garde manche-neutre » seule insuffisante : manquent zéro joystick maintenu N ms à l'entrée, homme-mort relâché à l'entrée, debounce de l'entrée analogique, non-reprise après E-stop.
15. [❌ FAIL] Source de vérité de la position non traitée : preset 8,50 m côté PLC vs position variateur (désynchronisation possible) + matrice d'invalidation `Homed` (E-stop, power cycle, perte codeur, défaut) absente.
16. [✅ PASS] D4 (translation sans homing, 0 occurrence de `MachineHomed`) est un hors-périmètre valable **si** le grep est re-exécuté ; non vérifiable ici.
17. [❌ FAIL] Estimation 1/2–1 j optimiste : hors mise en place banc, non-régression des 10 fichiers locaux **non commités** (aucune baseline), tests capteur et variateur.
18. [✅ PASS] Point 5 sur l'imputation est mécaniquement correct : deux lots sur les mêmes gardes sans baseline commitée ⇒ aucun échec n'est attribuable.
19. [❌ FAIL] Le découpage « étapes / mapping » est sain en développement, non en déploiement : rien dans la réponse RT ne rend le demi-produit **inactivable**.
20. [❌ FAIL] Barrière mono-canal unique, aucune diversité citée (butée mécanique, AU, montée couple/courant, delta codeur) alors que c'est la seule protection du design.
21. [❌ FAIL] Mode commun humain : validation visuelle et barrière reposent sur le même opérateur et la même position de référence ; aucun contrôle de cohérence post-référencement (mesure de recoupement) prévu.
22. [⚪ N/A] Numéros de ligne, noms de signaux (`SafetyPermit_Ascent` vs `AscentPermit`), contenus de fichiers : non vérifiables sans accès dépôt.

---

## Niveau 1 bis — Argumentaire technique

**P1 — D1 / AC3.** Le raisonnement « le FB homing n'a pas de sortie PowerCutOff, donc AC3 est incâblable » confond absence de sortie et absence de canal. Une **demande** (booléen surveillé) vers FB_Safety_Winch ne viole pas la propriété de sortie : le producteur reste le FB safety. À vérifier avant de bloquer : existence d'une entrée de demande externe dans la chaîne instSafetyWinch*, et périmètre exact du masque ligne 1632 (tout le PowerCutOff ou un sous-cas ?). Si un canal de demande existe, AC3 est implémentable sans amender le contrat.

**P2 — amendement AC3 inacceptable en l'état.** Si le masque `AND NOT MaintN2` couvre réellement tout le PowerCutOff dans le seul mode où le homing tourne, alors l'exigence de sécurité est **inobservable par construction**. Aligner AC3 sur ce constat revient à documenter un défaut comme spécification. Deux issues seulement : (a) mode `HOMING` distinct qui n'hérite pas du masque ; (b) risque résiduel explicitement accepté avec mesure compensatoire **testable** (butée mécanique + AU indépendant du PLC + détection de survol), pas « instruction IHM ». L'instruction IHM n'est pas une barrière.

**P3 — « stop au contact » n'est pas démontré.** Retirer un permis d'ascension n'arrête pas un treuil : cela retire une autorisation. Manquent : rampe de décélération, délai de fermeture du frein, survolmesure, comportement en charge (frein à ressort maintenant ou non). Sur un treuil de dragage à charge suspendue, la différence permis vs PowerCutOff peut être la chute de charge. Ce point doit être chiffré (distance de survol mesurée) avant tout test avec charge.

**P4 — M1/M2 en mode homing.** Le mode qui autorise le homing est celui qui neutralise `SyncBlocksAscent/Descent`. Si le homing pousse `CmdWinchM1/M2` avec des `StepTgt` non strictement asservis, on crée du gauchissement/torsion, et si la barrière TOP est unique pour deux treuils, un côté s'arrête et l'autre continue. À vérifier : barrière par treuil ou unique, et action du stop sur les deux axes.

**P5 — propriété des commandes.** `FB_Modes` passe `JoystickWinchSelectRequest` directement, `PRG_03` impose `MachineHoming.CmdWinchSelect` quand actif. Deux propriétaires = un sélecteur manipulé en cours de homing peut désélectionner le treuil en mouvement, ou perdre silencieusement la commande (mouvement nul → « bloqué » → l'opérateur jog → hazard). Exiger une règle d'arbitrage à propriétaire unique documentée et testée.

**P3(a) — latch.** La correction est la bonne famille mais sous-spécifiée. Il faut : set sur front montant du refus, clear sur front montant de l'appui **suivant**, ordre d'évaluation tel qu'un refus consécutif ne produise pas un pulse même-scan, clear sur sortie de mode/init, et **code cause** transporté avec le latch. Le défaut est une classe récurrente (IHM plus lente que le scan) : il faut la garantie de niveau (état maintenu ≥ 1 cycle IHM), pas un edge.

**P3(b) — cause 8.** Retirer cause 8 est la bonne direction. Non traité : qui porte l'événement « contact pendant homing » (sortie dédiée latée jusqu'à acquittement **et** sortie de mode), et quels consommateurs lisent `Fault.Latched`. Si un consommateur en dérive une inhibition de variateur, un TRUE transitoire en fenêtre HX2A déclenche un arrêt hors checklist. La liste des consommateurs doit être énumérée par outil, pas par relecture.

**Défaut manquant — source de vérité position.** Aucun point ne traite la double localisation : preset 8,50 m écrit côté PLC vs position détenue par le variateur. Écrire la référence dans un seul des deux plans produit une désynchronisation silencieuse, et un cycle de puissance variateur peut réintroduire l'ancienne position. À vérifier : qui détient la position, atomicité de l'écriture, et matrice d'invalidation de `Homed`.

**P4 files.** La liste omet les fichiers sur lesquels repose l'argument de compatibilité (PRG_03, PRG_04), le FB safety, l'écran IHM réel (GVL_Troubleshooting ne suffit pas) et le paramétrage variateur qui porte le preset 8,50 m. Une liste de fichiers qui ne contient pas les fichiers cités en preuve est un défaut de traçabilité, pas un détail.

**P5 séquencement — la contradiction à trancher.** Le RT dit lui-même : T377 = protocole de référencement, pré-requis de tout essai. Or il le place après le premier essai. Conséquence concrète : le premier test M3/MAINT_N2 tourne avec une position absolue non validée, donc ses résultats sont ininterprétables **et** l'essai se fait à référence fausse. Issue : scinder T377a (référencement manuel + barrière + latch + garde manche-neutre, **avant** le test M3) et T377b (grafcet tolérant, IHM, troubleshooting) après.

**Durée.** 1/2–1 j pour 13 TC + 6 scénarios ignore banc, non-régression des 10 fichiers modifiés localement, essais capteur et variateur, et la reprise du test homing seul (annoncée 15–30 min, soit le chemin heureux uniquement). Ordre de grandeur réaliste : 1/2 j pour le scénario nominal, 1 j complet avec cas dégradés, **à deux personnes** (opérateur + témoin), sur enregistrement écrit.

**Q2 — risques indirects non évidents.** (i) Charge/gravité : permis retiré ≠ arrêt ; survol et coup de frein répétés usent la barrière et la mécanique. (ii) Capteur shuné/figé : le design fait de la barrière **la** protection ; figé inactif = montée jusqu'à la butée, figé actif = homing impossible → pression au contournement. (iii) Mode commun humain : validation visuelle et barrière dépendent du même homme et du même point de vue (parallaxe, nuit, pluie) ; l'erreur est **systématique** et décale toutes les positions absolues — aucun logiciel ne la voit. (iv) Thermique/météo : dilatation du câble sur la course, condensation/givre sur le capteur, transitoires IO → une référence prise à froid dérive silencieusement. (v) Redémarrage : `Homed` conservé après perte codeur ou cycle variateur = machine « référencée » à tort. (vi) IHM : acquittements, textes, deux opérateurs, cycle plus lent que le scan. (vii) Lot local non commité : aucun diff de référence, risque de perte et de test sur une version qui sera écrasée.

**Q3 — le découpage est-il sain ?** Sain en développement (états sur SimBench d'abord), non sain en déploiement. Un grafcet ST compile et « avance » avec toutes les sorties à 0 : CODESYS ne signale rien. Un SimBench PASS prouve le contrat FB↔mock, **pas** FB↔IO — les mocks encodent précisément l'hypothèse de mapping qu'on veut vérifier. Trois verrous mécaniques pour interdire le site-test d'un demi-produit : (1) manifeste de mapping déclaré vs variables réellement écrites par le FB, comparé par script (diff ≠ 0 ⇒ blocage) ; (2) drapeau `MappingValidated := FALSE` par défaut dans la config **committée**, sans chemin IHM pour le mettre à TRUE — le FB refuse de quitter IDLE ; (3) preuve terminal : chaque sortie critique observée au bornier, valeur notée, machine bloquée. Le découpage n'est acceptable que si le produit livré au site est **inactivable par construction**, pas s'il est inactivable « par consigne ».

**Q4 — protocole site minimum (avant acceptation du lot).**
1. Mapping sans mouvement : chaque sortie critique (sélection M1/M2, sens, `StepTgt` > 0, contacteurs, chaîne de permis) observée **au bornier**, valeur notée. Critère d'arrêt : une sortie non observée = refus.
2. Garde manche-neutre : 10 tentatives de démarrage homing avec joystick à 5 % / 100 %, homme-mort appuyé, séquences de boutons, cycles de puissance rapides. Critère : 0 démarrage.
3. Barrière, approche lente : contact ⇒ **aucune écriture de référence** (comparer la valeur avant/après), latch actif, mouvement arrêté, survol mesuré en mm.
4. Barrière figée active, puis perte du signal barrière si réalisable sans risque : comportement conforme au document, message explicite, aucune référence. Critère : comportement spécifié, pas « ça n'a pas planté ».
5. Relâchement homme-mort en cours d'approche : arrêt, aucune référence, latch intact, redémarrage impossible sans reprise depuis zéro.
6. E-stop en cours puis reset : pas de reprise auto, état de `Homed` documenté, référence inchangée.
7. Validation volontairement décalée (±10 cm) : mesurer l'erreur absolue réelle vs bande +0,10/−0,10 annoncée. Critère : erreur < bande **et** bande justifiée.
8. Matrice de puissance : power cycle PLC, power cycle variateur, perte codeur (si autorisée) ⇒ `Homed` doit passer FALSE. Critère : les 4 cas documentés.
9. M1/M2 en approche lente : écart/gauchissement sous seuil chiffré ; cas « un côté barrière » si la barrière n'est pas par axe.
10. Geste habituel inchangé : 3 cycles opérateur, aucun nouvel alarme ; non-régression M3/MAINT_N2 constatée.

---

## Niveau 2 — Plan d'action chirurgical

**A1 — Tracer l'amendement AC3 ou le refuser**
Localisation : contrat T377 (AC3) + PRG_04:1632 et jumeau ~1653. Ancre : `instSafetyWinch*.PowerCutOff` sous `AND NOT MaintN2`. Action exacte : soit introduire un mode `HOMING` hors masque, soit ouvrir un dossier de risque résiduel nommant la mesure compensatoire testable ; interdiction d'amender AC3 sans l'un des deux. Outil déterministe : script Python d'inventaire des conditions affectant `PowerCutOff` (liste exhaustive des AND/OR par grep ciblé), à défaut `grep -rn` sur le signal — aucun PASS sans liste complète. Risque si ignoré : exigence de sécurité documentée comme inobservable, perte de la seule protection ultime dans le mode d'usage.

**A2 — Vérifier l'existence d'un canal de demande safety**
Localisation : interface de FB_Safety_Winch / instSafetyWinch*. Ancre : entrées booléennes de demande externe. Action : confirmer ou infirmer la conclusion « aucun chemin câblé ». Outil : grep interface + revue des appelants. Risque si ignoré : blocage d'AC3 pour un motif faux, ou amendement inutile du contrat.

**A3 — Manifeste de mapping + drapeau bloquant**
Localisation : config committée + FB homing. Ancre : `MappingValidated := FALSE` par défaut ; manifeste déclaratif des sorties critiques. Action : le FB refuse de quitter IDLE si FALSE ; aucune écriture IHM ne peut le passer à TRUE. Outil : script Python qui extrait les affectations `:=` du FB et les diffe contre le manifeste (échec = code retour ≠ 0), plus `pytest` sur un modèle Python de la logique de latch (garantie « pas de pulse même-scan » sur cycle IHM > scan). Risque si ignoré : site-test d'un demi-produit, exactement l'inquiétude exploitant.

**A4 — Spécifier latch et code cause**
Localisation : ST_HomingChecklist / FB_TroubleshootingView. Ancre : bit `LastValidationRefused`. Action : set sur front, clear sur front suivant, clear sur sortie de mode/init, cause associée obligatoire, maintien ≥ 1 cycle IHM. Outil : `pytest` sur modèle de la machine à états du latch (séquences refus/refus, refus/appui, sortie de mode). Risque si ignoré : refus invisible → opérateur répète, puis contourne.

**A5 — Débrancher cause 8 de `Fault.Latched`**
Localisation : FB_TroubleshootingView / GVL_Troubleshooting. Ancre : `Fault.Latched` (fenêtre HX2A). Action : énumérer **tous** les consommateurs de `Fault.Latched`, confirmer aucun n'induit d'inhibition variateur, porter l'événement sur sortie dédiée latée. Outil : grep exhaustif des consommateurs, sortie listée dans la revue. Risque si ignoré : arrêt hors checklist non décrit, donc non testé.

**A6 — Propriétaire unique des commandes en mode homing**
Localisation : PRG_03:95-99 + FB_Modes + FB_TranslationCmdArbitrationM3. Ancre : `CmdWinchSelect` sous `MachineHoming.Active`. Action : documenter la priorité, verrouiller la sélection pendant le homing, test « sélecteur bougé en cours de séquence ». Outil : revue de diff ciblée + TC dédié SimBench. Risque si ignoré : commande perdue silencieusement → jog opérateur → hazard.

**A7 — Superviser la synchronisation M1/M2 dans le mode homing**
Localisation : PRG_04:501-514 + PRG_04:1126-1129. Ancre : neutralisation `SyncBlocksAscent/Descent`. Action : réintroduire une supervision d'écart M1/M2 propre au homing, ou preuve que l'arbitrage l'assure. Outil : TC SimBench avec écart injecté + mesure site du gauchissement. Risque si ignoré : torsion mécanique sur un mode où les gardes sont justement neutralisées.

**A8 — Arrêt : permis vs PowerCutOff, chiffré**
Localisation : chaîne `EffectivePermit*_Ascent` + frein. Ancre : retrait de permis. Action : mesurer distance et temps d'arrêt, vérifier tenue de charge, documenter survol vs barrière. Outil : essai machine bloquée avec enregistrement (trace scope/variateur). Risque si ignoré : qualification d'« arrêt » sans preuve, sur charge suspendue.

**A9 — Source de vérité position + matrice d'invalidation `Homed`**
Localisation : preset 8,50 m (config variateur/PLC), ST_MachineHoming. Ancre : écriture de référence. Action : un seul plan de vérité, écriture atomique, `Homed` invalidé sur E-stop/power cycle/perte codeur/défaut, matrice écrite. Outil : TC SimBench des 4 cas + essai site de cycle de puissance. Risque si ignoré : machine « référencée » avec une position fausse après redémarrage.

**A10 — Scinder T377 en T377a / T377b**
Localisation : TASKS (coordinateur uniquement — le challengeur ne modifie pas le catalogue). Ancre : point 5 de la réponse RT. Action : T377a (référencement + barrière + latch + garde) **avant** le premier test M3/MAINT_N2 ; T377b (grafcet tolérant, IHM, troubleshooting, renommages) après. Outil : décision tracée du coordinateur + baseline commitée avant tout essai. Risque si ignoré : premier test M3 exécuté à référence non validée, résultats ininterprétables et essai non sûr.

**A11 — Protocole capteur unique**
Localisation : spécification mécanique/électrique barrière TOP. Ancre : mono-canal. Action : ajouter ou documenter une couche indépendante (butée mécanique + AU, détection couple/courant ou delta codeur) **et** un contrôle de cohérence post-référencement (mesure de recoupement sur repère fixe). Outil : essai de perte de signal capteur, procédure écrite. Risque si ignoré : point unique de défaillance sur la seule protection du design, plus erreur de référence systématique et invisible.