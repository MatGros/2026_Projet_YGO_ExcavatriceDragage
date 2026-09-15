# T262 — Fermeture benne → extraction sans arrêt franc

> 🔴 C4 · Responsable : Codex · 2026-09-15 · **Plan technique en revue, code non modifié**.
> Contrat : [TASK_CONTRACT_T262_AX10_CLOSE_BUCKET_THRESHOLD.yaml](TASK_CONTRACT_T262_AX10_CLOSE_BUCKET_THRESHOLD.yaml).

## 🎯 Besoin confirmé

Soulager M2 en engageant la montée des deux treuils avant la fermeture complète,
selon un seuil d'ouverture réglable. Enchaîner fermeture → AX11 (cible P2) → AX12.

| Réglage | Critère de passage |
|---|---|
| **0 %** | Critère historique de fin de fermeture, avec `Done AND (IsClosed OR IsRoughlyClosed)` ; 0 signifie désactivation du passage anticipé. |
| **Seuil positif** | Ouverture réelle valide **≤ seuil**, ou fin de fermeture historique atteinte auparavant. Ex. 20 % : passage à 20 % d'ouverture restante. |
| Mesure invalide | Le pourcentage ne peut pas autoriser un transfert ; les protections existantes restent prioritaires. |

Proposition de réglage : `GVL_IHM.CycleSemiAuto.Cfg.ExtractionStartOpening_Pct`,
type `INT`, persistant, défaut 0, borné 0..50 %. La borne 50 % vient du contrat
précédent et reste une proposition métier à valider. La comparaison `≤` précise
« atteindre le pourcentage » ; elle remplace le `<` du contrat précédent.

L'exception P2 benne partielle est limitée à l'extraction automatique engagée par
ce transfert. Elle ne relève pas un plafond dû au mou de câble, aux codeurs,
à une limite ou à une autre protection. AX12 conserve sa règle actuelle :
P1 tant que la fermeture franche n'est pas confirmée, vitesse de charge ensuite.

## 📏 Valeurs actuelles — passage AX10 → AX11

Les valeurs ci-dessous sont celles actuellement initialisées dans
`CODE/GVL_PERSISTENT.st`. Elles peuvent avoir été modifiées et sauvegardées à
l'IHM : l'essai doit toujours relever les valeurs persistantes actives.

| Élément actuel | Valeur | Effet réel aujourd'hui |
|---|---:|---|
| `OffsetOpenM` | **0,0 m** | Référence benne ouverte : `Delta = M2 − M1 = 0 m`. |
| `OffsetCloseM` | **15,0 m** | Référence benne fermée : `Delta = M2 − M1 = 15 m`. |
| `CoherenceLimitM` | **±1,0 m** | `IsClosed` est physiquement cohérent pour `Delta` entre **14,0 et 16,0 m**. |
| Tolérance « à peu près fermée » | **2,0 m** | `Benne_IsRoughlyClosed` est vrai si état intermédiaire et `Delta ≥ 13,0 m`, ou si `IsClosed`. |
| `CloseAnticipationM` | **1,2 m** | La fermeture M2 s'arrête dès `M2 ≥ M1 + 13,8 m`, pour absorber l'inertie. À cet instant le FB publie `Done := TRUE` et force son état fermé ; la classification continue reste contrôlée par la bande ±1 m. |
| Plafond fermeture M2 | **P2** | `MaxStepUp = 2` pendant l'action benne. |
| Délai initial AX10 | **1,0 s** | La demande de fermeture ne démarre qu'après entrée stable dans AX10. |

### Condition exacte actuelle

La sortie d'AX10 demande simultanément :

```text
DeadmanArmed
AND JoystickPull
AND Benne_Done
AND (Benne_IsClosed OR Benne_IsRoughlyClosed)
```

Après cette sortie, AX10b impose aujourd'hui un arrêt physique stable de **500 ms**
avant AX11 : vitesses M1/M2 valides, contacteurs M1/M2 tous relâchés, freins M1/M2
serrés, et `|vitesse| < 0,02 m/s` pour les deux treuils. Le joystick tiré et
l'homme-mort restent requis.

Ces valeurs sont le point de départ de T262. Le nouveau seuil d'ouverture ne doit
pas modifier `OffsetCloseM`, la bande de cohérence, l'anticipation de fermeture ou
la tolérance matière ; il ajoute seulement un critère de **préparation du transfert**
avant cette fin actuelle.

## 🔎 Pourquoi enlever AX10b ne suffit pas

| Fait vérifié dans le code | Conséquence pour le patch |
|---|---|
| `FB_Bucket.st:483-493` retire marche/sens M2 et `Busy` dès la fin de fermeture. PRG03 ne lit `Done` qu'au scan suivant. | Préparer le transfert avant la fin et le consommer dans PRG04 au même scan. |
| `FB_CycleSemiAuto.st:1211` impose ensuite AX10b et l'arrêt confirmé. | Cette attente peut être évitée seulement lorsque le transfert est prêt. |
| `PRG_04_Treuils_Benne.st:1593` neutralise Both si les vecteurs de sortie diffèrent ou si une direction est en attente. | M2 déjà P2 et M1 démarrant P1 peuvent produire une nouvelle coupure. |
| `FB_WinchDirectionInterlock.st:108` temporise un changement de sens ; M1 peut avoir fini sa dernière action en descente. | Préparer son intention montée, marche désactivée, pendant AX10. Vérifier aussi l'interlock final. |
| `PRG_04_Treuils_Benne.st:383`, `1214`, `1271` plafonne la benne partielle à P1. | Exception AX11 ciblée à spécifier ; aucun retrait du plafond mou de câble. |
| `PRG_06_Outputs.st:334` surveille les vecteurs finaux ; le maintien process de 4 s ne couvre pas cette surveillance. | Tester jusqu'aux DQ finales et aux freins, pas seulement les demandes du cycle. |

Correction du diagnostic initial : la garde `BucketBusy` de l'arbitre M1 appartient
à la branche manuelle. En automatique, examiner le front de fin de benne et les
barrières finales ; ne pas modifier la garde manuelle pour résoudre T262.

## ⚙️ Transfert proposé

| Phase interne | M1 | M2 | Condition de sortie |
|---|---|---|---|
| Préparation pendant AX10 | Intention montée préparée, **marche FALSE**, contacteurs au repos. | Ferme selon le pilotage actuel. | Seuil valide ou fin historique. |
| Raccordement | Attend prêt à monter. | Rejoint **P1**, avec sens maintenu et cadencement existant. | M2 réellement P1 et M1 prêt, protections autorisant le transfert. |
| Transfert effectif | Demande montée P1. | Demande montée P1 reprise par Both. | Fin de propriété benne et demandes Both produites dans **le même scan PRG04**. |
| Extraction AX11 | Cible P2 avec cadenceur. | Cible P2 avec cadenceur. | Les deux axes sont réellement au P1 avant la demande commune P2. |
| AX12 | Règle de charge actuelle. | Règle de charge actuelle. | Distance AX11 et conditions actuelles satisfaites. |

**P1 est le premier cran de raccordement vers P2, pas une pause avec frein serré.**
La durée dépend de la disponibilité et du cadencement existant, jamais d'une
nouvelle attente arbitraire à ajouter au cycle.

### Propriété et fraîcheur des données

- Le cycle émet l'autorisation de préparer le transfert dès AX10 sous geste maintenu.
- `FB_Bucket` conserve la propriété de la fermeture jusqu'au transfert qualifié ;
  il libère `CloseReq/Busy` avant que M1 puisse commencer à se déplacer.
- Le transfert anticipé publie un état dédié ; **il ne fabrique pas `IsClosed`
  ni un `Done` de fermeture complète**. À 0 %, conserver le vrai achèvement historique.
- PRG04 route l'autorisation de transfert aux deux arbitres dans le même scan.
  Aucune écriture dans les données de PRG03 depuis PRG04.
- Le cycle reçoit l'acquittement au scan suivant et entre en AX11 ; la demande est
  tenue entre ces deux scans par le propriétaire du transfert, sans seconde machine
  de cycle dispersée dans PRG04.
- Le calcul d'ouverture reste celui de `FB_Bucket`, fondé sur M2−M1 et les références
  existantes. Pour l'utiliser plus tôt dans le scan, déplacer son calcul pur si nécessaire,
  sans modifier formule, calibration ou algorithme d'offset.
- Une géométrie invalide renvoie actuellement un affichage 0 % : ce zéro ne constitue
  **jamais** une preuve de fermeture. Exiger références fiables, configuration et état
  benne valides pour qualifier le seuil.

### Repli indispensable

Si la fermeture effective arrive avant que le raccordement soit prêt, arrêter
comme aujourd'hui puis reprendre par la séquence existante. **Ne pas continuer
à tirer avec M2 seul à la fermeture pour attendre M1.** Cela concerne notamment
0 %, un seuil trop tardif ou une disponibilité tardive de M1.

Le résultat attendu est une continuité nominale mesurable. Le plan ne promet pas
une absence d'arrêt sous défaut, perte de permis ou préparation inachevée.
Un arrêt/repli doit avoir un motif observable ; pas d'attente silencieuse.

La préparation est annulée à la sortie de contexte, perte de geste, conflit de
sens ou défaut. Une reprise réévalue les permis et la mesure ; elle ne réutilise
pas une transaction périmée. Aucun redémarrage après défaut sans acquittement prévu.

## 🪜 Livraison par phases — conservation de l'existant

Chaque phase est un lot autonome : elle reçoit son diff, son bundle, ses tests et
son essai. Une phase non validée ne déclenche pas la suivante.

| Phase | Diff limité | Comportement livré | Validation avant suite |
|---|---|---|---|
| **A — GVL / persistance** | `ST_CycleCfg`, raccordement IHM/persistance existant et publication de lecture. | Le réglage `ExtractionStartOpening_Pct` est visible, modifiable et sauvegardé. **Aucune condition AX10, commande treuil ou palier ne change.** | Écrire 0, une valeur positive, hors plage ; vérifier la borne, la persistance après redémarrage et le cycle nominal inchangé. |
| **B — Critère de transition** | Cycle + bus de demande/état nécessaires, sans toucher au transfert de contacteurs. | À 0 %, AX10 conserve exactement `Done AND (IsClosed OR IsRoughlyClosed)`. À seuil positif, le cycle prépare le transfert quand l'ouverture valide atteint le seuil, mais garde AX10b et son arrêt actuel. | Trace AX10 : 0 %, seuil−1 / seuil / seuil+1, mesure invalide et fermeture matière. Vérifier que la séquence garde l'arrêt actuel. |
| **C — Raccordement P1** | `FB_Bucket`, PRG04 et retour de disponibilité final strictement nécessaires. | M1 est préparé sans marche ; M2 rejoint P1 ; les deux commandes P1 sont reprises ensemble. Si prêt insuffisant, retour à AX10b actuel. | Chronogramme scan par scan jusqu'aux DQ et freins, M1 dernier sens montée/descente, M2 P1..P5, perte geste/permis/défaut. |
| **D — AX11 P2 puis AX12** | Exception P2 AX11 ciblée, sans relever les autres plafonds. | Après P1 commun confirmé, AX11 vise P2 avec ses cadenceurs actuels. AX12 conserve P1 benne non fermée, puis sa vitesse actuelle benne fermée. | Simulation puis machine : P1→P2, AX11→AX12, mou câble, limites, codeurs et mode manuel/maintenance inchangés. |

Chaque phase de code reçoit bundle complet + diff bundle, G200 et tests appropriés.
L'essai machine suit les preuves logicielles ; une simulation ne prouve pas à elle
seule l'effort mécanique réellement soulagé.

## 🧪 Preuves nécessaires au lot B

1. **Critère** : 0 %, seuil−ε / seuil / seuil+ε, négatif / >50, géométrie invalide,
   codeur non fiable, fin historique atteinte avant un petit seuil positif.
2. **Raccordement** : M2 initialement P1 à P5 ; M1 dernier sens montée ou descente ;
   AX8→AX10 direct (distance AX9 nulle) ; M1 pas prêt au point de fermeture.
3. **Chronogramme** : au pas MainTask, demandes, propriétaire, `Busy`, cible et palier
   appliqué, direction, barrières, DQ et commande frein. Aucune retombée nominale M2
   masquée par la simulation ; aucun départ M1 avant libération de la benne.
4. **Cadences** : montée commune P1→P2 compatible avec l'égalité des vecteurs dans
   PRG04, les temporisations des deux interlocks et la surveillance finale.
5. **Interruptions** : joystick relâché, homme-mort perdu, mode quitté, permis retiré,
   défaut avant/pendant/après transfert, puis reprise. Aucun jeton ancien réutilisé.
6. **Conservation** : pas de P2 obtenu sur mou de câble ou autre plafond ; pas de
   modification manuel/maintenance, AX3→plongée, mesure/offset, sécurité finale.
7. **AX12** : benne encore partielle puis fermée ; continuité des demandes et évolution
   des paliers selon la règle actuelle ; pas d'accélération sur le seul seuil positif.

Le garde-fou T262 sera enregistré dans `run_all_gates.py`. Il complète les tests
exécutant le ST ; une recherche de texte seule ne valide pas le chronogramme.

## 📂 Diff prévu — cible de 9 fichiers ST

| Fichier | Modification prévue | Objectif |
|---|---|---|
| `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCfg.st` | Ajouter le seuil INT persistant. | Réglage depuis l'IHM, 0 conserve le critère actuel. |
| `CODE/G_CYCLE/FB_CycleSemiAuto.st` | Préparation AX10, acquittement transfert, demande AX11 P2 et repli. | Enchaîner le cycle avec geste maintenu. |
| `CODE/M_MAIN/PRG_03_Modes_Cycle.st` | Raccorder réglage, demande et retour ; employer les messages existants. | Relier IHM, cycle et treuils. |
| `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ProgramBucketRequest.st` | Ajouter la demande explicite de transfert et ses paramètres nécessaires. | Éviter une lecture cachée de l'IHM ou des internes du cycle. |
| `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` | Préparer puis libérer la propriété fermeture, sortie de transfert distincte de Done. | Éviter le trou de commande et le faux état fermé. |
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | Raccordement des commandes locales aux arbitres existants ; P1 commun puis P2 autorisé AX11. | Transfert même scan et respect des autres plafonds. |
| `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_WinchInterPrg.st` | Ajouter l'état/acquittement de transfert nécessaire au cycle. | Retour explicite PRG04 → PRG03. |
| `CODE/M_MAIN/PRG_06_Outputs.st` | Publier la disponibilité finale existante, sans modifier les sorties. | Vérifier que M1 peut démarrer sans temporisation résiduelle. |
| `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_OutputsInterPrg.st` | Ajouter ce retour de disponibilité au bus. | Lecture publique PRG06 → PRG04, retard d'un scan explicite. |

Les arbitres M1/M2 seront réutilisés avec leurs interfaces actuelles. Les messages
existants du cycle porteront l'attente/le repli : pas de champ IHM supplémentaire
prévu dans `ST_CycleState`, pas de modification de `GVL_IHM` ni `ST_CommunCfg`.
Les FB codeurs, de mouvement, interlocks, synchronisme et SimBench restent des
objets de contrôle en lecture seule. Tout besoin supplémentaire sera annoncé et
justifié avant modification.

Fichiers d'accompagnement prévus :

- Nouveau `TOOLS/AGENT_WORKFLOW/scripts/G500_check_t262_bucket_ascent_handoff.py`.
- Modification `TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py` : enregistrer le garde-fou.
- Nouveau `TOOLS/tests/integration/test_t262_bucket_ascent_handoff.py` : essais exécutant
  la chaîne ST et vérifiant les sorties, selon le runner d'intégration existant.
- `CODE_XML/CODE_Bundle.xml` et `CODE_XML/CODE_DiffBundle.xml` : régénération à la livraison.
- `DOC/WFLOW/TASKS.yaml`, contrat T262 et ce plan : suivi, décisions et preuves.
- `DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md` : spécification de l'exception AX11 P2
  et du transfert, à synchroniser avant livraison selon les règles documentaires.

## 👁️ Revue indépendante

Expert automatisme `/root/t262_handoff_expert`, lecture seule le 2026-09-15 :
**MAJOR sur le plan initial**, transfert préparé au P1 recommandé. Points retenus :
trou d'un scan à la fin benne, atomicité des vecteurs Both, dernier sens M1,
plafond P1 benne partielle, distinction synchronisme process/final, repli à la
fermeture. Le plan ci-dessus intègre ces constats.

Complément vérifié : l'interlock final purge ses délais pendant l'arrêt M1, frein
confirmé fermé (500 ms anti-redémarrage, 700 ms temps mort au réglage actuel).
`Ready` seul n'inclut pas ces conditions. Prévoir une publication de disponibilité
qualifiée depuis PRG06, consommée au scan suivant avec les permis courants.
Cette publication observe les interlocks existants ; elle ne change pas leurs délais.

**Encore à démontrer avant activation du transfert** : chronogramme complet de
raccordement et montée commune P2, y compris une fermeture très courte. La revue
de plan ne vaut ni revue de code ni validation machine.

### Signalement préexistant, hors correction T262

`FB_WinchOutputInterlock.st:240-264` écrit `LastDirection` à partir de la demande
avant de la comparer à `NewDirection`. Le branchement semble donc toujours choisir
le délai même sens. Constat relu par l'orchestrateur ; conséquence physique à auditer
séparément avec l'interlock de direction amont. Aucune correction dans ce lot.
La préparation T262 doit exiger la purge du délai maximal existant, et ne pas
s'appuyer sur ce choix même-sens pour déclarer M1 disponible.

## ⚡ Étude dynamique électromécanique — verrou avant phases C/D

> Analyse statique approfondie le 2026-09-15. Elle ne remplace pas les relevés
> intensité, vitesse, retours contacteurs et frein sur la machine.

### Faits de conception à respecter

| Fait vérifié | Risque physique si ignoré | Règle T262 |
|---|---|---|
| Les moteurs sont commandés par paliers de contacteurs ; la hausse P1→P2 est déjà cadencée par `FB_WinchStepShaper` puis bornée une seconde fois par la barrière finale. | Appeler directement P2 ou réinitialiser un shaper crée un appel de courant / transfert de couple non qualifié. | Raccordement obligatoirement **P1 commun**, puis P2 avec les cadenceurs existants. |
| Le frein suit le contacteur de sens (`BrakeCmd := RelayFwd OR RelayRev`). Toute retombée du sens referme le frein. | Micro-arrêt = choc de reprise, échauffement frein et appel au rotor au redémarrage. | En nominal, M2 conserve le sens montée et le frein ouvert ; aucun passage forcé à zéro entre fermeture et P1 commun. |
| La barrière finale impose 500 ms après arrêt freins serrés, puis un temps mort jusqu'à 700 ms pour le sens. | Une prétendue disponibilité M1 peut être fausse ; les vecteurs Both seraient neutralisés, ou M2 tirerait seul. | M1 ne peut rejoindre que si les interlocks amont **et finaux** sont purgés ; `Ready` seul est insuffisant. |
| En Both SEMI_AUTO, PRG04 neutralise les deux sorties si les vecteurs finaux diffèrent. | M2 P2 + M1 P1 ou direction non alignée = coupure précisément contraire au besoin. | Pré-aligner M2 à P1 avant l'intention Both ; le scan de bascule demande P1/montée identique aux deux axes. |
| La table active est P1=`R1..R4` ouverts, P2=`R1` fermé, puis ajout progressif de R2..R4. | M2 P2→P1 garde le sens et le frein, mais commute une étape de la chaîne de résistances ; le couple/vitesse réel doit être mesuré. | Le passage P2→P1 est une décélération à valider, jamais une « absence de manœuvre » électrique. Ne pas modifier la table dans T262. |
| La cinématique mesurée de la benne est `Delta = CablePosM2 - CablePosM1`. | Si les deux vitesses câble deviennent égales, `Delta` reste constant : aucune fermeture géométrique supplémentaire n'est garantie. | Ne jamais déclarer que la benne « finit de se fermer » pendant Both sans preuve terrain de baisse effective de `BucketOpening_Pct`. |
| AF10 §7.5 bride déjà une benne non franchement fermée à P1. | Lever ce plafond avant fermeture peut surcharger câble, réducteur, moteur ou mécanique de benne obstruée. | AX11 P2 n'est permis qu'après critère de fermeture confirmé ; sinon P1 reste la position sûre existante. |

### Conclusion provisoire : deux hypothèses à départager au banc

```text
A — Both P1 fait encore diminuer l'ouverture réelle
    → possible seulement si la cinématique/les glissements mécaniques produisent
      une vitesse M2 effectivement supérieure à M1 malgré la même commande P1.
    → P1 jusqu'à IsClosed, puis AX11 P2.

B — Both P1 conserve l'ouverture (Delta quasi constant)
    → c'est le comportement cinématique attendu si les deux tambours avancent pareil.
    → le seuil anticipé soulage M2 mais la benne demeure intermédiaire : P1 reste
      nécessaire ; une montée P2 nécessiterait une nouvelle stratégie mécanique,
      pas un simple patch de séquence.
```

**Aucune des deux hypothèses ne doit être choisie par simulation seule.** La simulation
actuelle ne modélise ni courant rotor, ni couple, ni élasticité câble, ni inertie de
la benne, ni temporisation électromécanique réelle des contacteurs/freins.

> Limite de preuve documentaire : le dépôt ne contient pas le schéma de puissance
> des rotors ni les courbes constructeur moteurs/résistances. La lecture « R1..R4 »
> comme étages de résistances est cohérente avec un moteur à rotor bobiné, mais doit
> être confirmée sur le schéma électrique avant toute modification des séquences de
> paliers.

### Essai machine minimal avant activation C/D

1. À vide, seuil conservé à **0 %** : relever le chronogramme historique de référence.
2. Seuil prudent (proposé : **10 %**) : au raccordement P1, enregistrer pendant au
   moins 3 s `BucketOpening_Pct`, positions M1/M2, vitesses, paliers demandés/appliqués,
   retours contacteurs et freins.
3. Relever les intensités M1/M2 ou tout indicateur disponible de charge rotor/stator :
   rechercher appel brutal, oscillation ou surcharge persistante au raccordement.
4. Accepter P2 uniquement après `IsClosed` réel, vitesses stables et absence de
   déclenchement contacteur/synchro/frein. Sinon : conserver P1 et repli sûr.
5. Répéter avec charge représentative et benne volontairement non totalement fermée.

Critères d'arrêt immédiat d'essai : bruit/choc inhabituel, oscillation de vitesse,
retard de frein/contacteur, hausse anormale d'intensité, dégradation d'écart M1/M2,
ou toute perte de permis. L'essai ne sert pas à « forcer » la transition.

## ✅ Décisions et validation

- Acquis utilisateur : 0 % conserve le critère actuel ; seuil positif ; extraction
  cible P2 ; fluidité ; automatique uniquement ; responsabilité qualité et revue ciblée.
- Proposition présentée : plage 0..50 %, comparaison `≤`, raccordement P1 sans arrêt,
  repli historique si préparation insuffisante à la fermeture.
- **Validation humaine du plan technique encore requise** par `AGENTS.md`, avant ST.
  Aucun code ni bundle T262 livré à ce stade.
