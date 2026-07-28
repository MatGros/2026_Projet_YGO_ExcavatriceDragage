# Politique de rédaction du code ST

## 1. Objectif

Produire du Structured Text CODESYS 3.5 lisible, importable, traçable et cohérent avec les
spécifications actives et les tests du projet.

## 2. Sources obligatoires avant modification

- `DOC/NAMING_CONVENTION.md`
- `DOC/AF_Partie-03_Template_FB_Commun_v1.3.md`
- `DOC/AF_Partie-02_Architecture_Programme_v2.12.md`
- la spécification métier active concernée
- les tests et le code des appelants impactés

`ARCHIVES/` n'est jamais une source active.

## 3. Nommage

- PascalCase partout, sans hongrois.
- Identifiants techniques en anglais selon la convention active.
- Commentaires en français.
- `FB_` : Function Block ; `ST_` : structure ; `E_` : enum.
- `PRG_XX_` : programme autonome numéroté.
- Unités explicites : `_M`, `_Pct`, `_Ms`, `_Hz`.
- Entrées de commande : `Enable`, `Reset`, `StartStop` selon le profil.
- Sorties d'état : `Ready`, `Busy`, `Done`, `Error`, `ErrorId`, `State`, `StateAtError`.
- `ReqX` : requête brute ; `CmdX` : commande finale arbitrée.
- Ne pas créer de nouvelle abréviation sans justification dans la convention.

## 4. Profils FB

### FB standard métier

Interface selon Partie 3 : `Enable`, `Reset`, `EmergencyStopOk`, `Mode` et sorties standard.

### FB de mouvement

Ajoute `StartStop` et `SafeStop`.

Précédence obligatoire :

```text
Enable > SafeStop > StartStop
```

- `Enable=FALSE` : neutralisation et sorties coupées.
- `SafeStop=TRUE` avec `Enable=TRUE` : rampe rapide.
- `StartStop=FALSE` sans `SafeStop` : rampe normale.

### Brique réduite

Interface minimale autorisée uniquement si son rôle est documenté dans la spec.

### Interdictions

- `CoupeEnable`.
- `FB_Watchdog` applicatif.
- `SafeStop`/`StartStop` sur un FB qui n'est pas de mouvement.
- redémarrage automatique après défaut.
- réimplémentation d'une librairie CODESYS déjà disponible.

## 5. Programmation orientée objet et encapsulation

### Principes obligatoires

- **Un objet = une responsabilité métier ou technique clairement nommée.** Le propriétaire d’une
  donnée est le FB qui l’acquiert, la calcule ou garantit sa cohérence. Un bloc safety surveille
  une mesure ; il ne devient pas son producteur par commodité de câblage.
- **Composition uniquement** : un FB utilise d’autres FB via des instances privées dans `VAR`.
  Pas d’héritage, pas de méthode/propriété ajoutée sans décision d’architecture explicite.
- Les variables internes d’un FB sont privées. Aucun appelant ne les écrit et aucun nouveau flux
  ne doit dépendre d’un accès à `Instance.VariableInterne`.
- Les échanges passent uniquement par une interface explicite : `VAR_INPUT`, `VAR_OUTPUT` et
  `VAR_IN_OUT` lorsqu’un partage par référence est réellement nécessaire et documenté.
- Une sortie possède **un seul producteur**. Plusieurs consommateurs peuvent la lire, mais ne la
  recalculent pas et ne créent pas de source parallèle.
- Une donnée dérivée est calculée une seule fois par son propriétaire, puis distribuée. Exemple :
  position/vitesse appartiennent à la chaîne codeur ; les blocs Winch, Cycle, Safety et IHM les
  consomment.

### Interfaces propres

- Chaque entrée exprime une information atomique et compréhensible : mesure, état, commande
  arbitrée, validité ou événement.
- Ne pas passer une succession de conditions métier anonymes directement dans un appel de FB.
  Une expression simple de conversion ou de comparaison locale reste admise ; une décision
  combinant plusieurs causes doit être calculée par son **propriétaire fonctionnel**, nommée et
  documentée avant l’appel.
- Interdit sans arbitrage explicite :

```pascal
// ❌ Sources de commande fusionnées anonymement à l’interface
Start := HmiButton OR JoystickActive OR CycleRequest;
```

- Forme attendue :

```pascal
// ✅ L’arbitre propriétaire choisit une source légitime et expose le résultat
StartArbitrated := ...;
Instance(Start := StartArbitrated);
```

- Un `OR` reste légitime pour agréger des **états homogènes** clairement documentés, par exemple
  `AnyError := ErrorM1 OR ErrorM2`. Il ne doit jamais masquer un arbitrage de commandes, une
  priorité safety ou des causes de natures différentes.
- Une entrée ne doit pas obliger le FB à deviner la provenance de la donnée. Si la provenance est
  utile, transmettre un état ou un événement générique défini à la frontière propriétaire, pas
  une lecture directe d’une GVL étrangère dans le FB.
- Les paramètres influençant une fonction safety ne sont pas exposés à l’IHM ou en `PERSISTENT`
  sans exigence métier explicite, bornage, traçabilité et validation humaine. Une constante
  interne est préférée lorsque le réglage externe n’est pas requis.

### Flux PRG ↔ FB ↔ consommateurs

- Un `PRG_XX` orchestre ; il ne réimplémente pas la responsabilité d’un FB.
- Les données destinées à d’autres programmes sont exposées par les `VAR_OUTPUT` du programme.
  Les nouveaux consommateurs ne doivent pas traverser l’encapsulation avec
  `PRG_XX.Instance.Sortie` si une sortie de programme peut porter proprement le flux.
- Un consommateur lit la sortie publique du producteur ; il ne lit pas ses mémoires, timers,
  instances composées ou états intermédiaires.
- Quand plusieurs valeurs forment un contrat stable et cohérent, utiliser une `ST_*` dédiée
  (commande, mesure, état, diagnostic). Ne pas créer une structure fourre-tout ni une structure
  pour une paire de scalaires sans bénéfice de cohésion/versionnement.
- `VAR_IN_OUT` est réservé aux objets partagés intentionnels (configuration/état persistant ou
  référence documentée). Il ne sert pas à contourner l’interface ou à permettre plusieurs
  écrivains.
- Les GVL sont des frontières identifiées (IHM, persistance, simulation), jamais un canal caché
  entre FB. Un FB de calcul ou métier ne lit pas une GVL étrangère si l’information peut être
  fournie par son interface.

### Checklist d’architecture avant code

- [ ] Responsabilité et propriétaire de chaque nouvelle donnée identifiés.
- [ ] Un seul producteur par sortie ; aucune duplication de calcul.
- [ ] Internes inaccessibles aux nouveaux consommateurs.
- [ ] Commandes arbitrées avant l’appel ; aucun `OR` de sources improvisé.
- [ ] Interface minimale, sémantique et testable.
- [ ] Structure utilisée seulement si les données forment un contrat cohérent.
- [ ] Paramètres safety non exposés sans justification validée.
- [ ] Simulation et provenance cantonnées à leur frontière architecturale.

## 6. En-tête obligatoire

Chaque POU possède un en-tête court et lisible :

```pascal
(* ═══════════════════════════════════════════════════════════════
   🎯 Nom du POU — rôle métier
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-XX_...md §...
   🛡️ Sécurité : [règle ou domaine concerné]
   🧩 Dépendances : [FB/PRG principaux]
   ═══════════════════════════════════════════════════════════════ *)
```

Un en-tête décrit le rôle et les contraintes. Il ne recopie pas la spécification complète.

## 7. Commentaires

- Français, précis, orientés rôle/raison/risque.
- Emojis comme repères visuels, jamais comme décoration excessive.
- Une ligne pour une logique évidente ; détail obligatoire pour sécurité, interlock, temporisation,
  polarité, ordre d'appel et correction de bug.
- Commenter le **pourquoi** lorsqu'il n'est pas déductible du code.
- Conserver les références REX et dates lorsqu'elles justifient une décision.
- Ne pas commenter chaque affectation évidente.

Exemple :

```pascal
// 🛡️ SafeStop impose la rampe rapide ; Enable reste maintenu hors AU matériel.
```

## 8. Organisation d'un fichier

```text
En-tête
Déclarations d'interface
Déclarations internes
Initialisation / gates
Reset sur front
Sécurité et défauts
Logique métier
États et sorties
Diagnostic / IHM
```

Les sections sont séparées par des commentaires courts et stables.

## 9. Traçabilité

Toute modification CODE précise dans l'en-tête ou le contexte de tâche :

- document source ;
- section ;
- raison ;
- impact appelants ;
- tests attendus.

Le corps ST reste uniquement dans `CODE/`. La documentation métier référence le fichier sans le
recopier.

## 10. Contrôle avant livraison

```text
Scope → parsing → nommage/interdits → tests → bundle → review → validation CODESYS
```

La validation Python ne remplace pas la compilation/import CODESYS ni les essais terrain.
