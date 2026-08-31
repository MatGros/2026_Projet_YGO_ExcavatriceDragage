# 🖥️ Guide Visualisation CODESYS 3.5 — commandes & particularités (v1.0)

> 📌 **Guide pratique** sur l'outil *Visualisation* intégré à l'IDE CODESYS 3.5 (l'IHM faite
> « dans le logiciel de programmation »). Il couvre les **commandes disponibles**, leurs
> **compatibilités** et les **pièges** propres à ce contexte.
> Ne définit **aucun contrat de données** : les échanges PLC ↔ IHM (`GVL_IHM`, états, commandes)
> restent la propriété de [`AF_Partie-07_Interface_IHM_v2.2.md`](../../AF/AF_Partie-07_Interface_IHM_v2.3.md).
> Périmètre : **CODESYS Visualization (Runtime)** — pas TargetVisualization (sauf comparaisons ponctuelles).

---

## 🎯 1. Raison d'être

- **Problème résolu** : l'éditeur de Visualisation offre un large catalogue de commandes
  (Set, Reset, Write value, Eval ST…) dont la **disponibilité dépend du type de Visu, du type
  d'élément et du type de variable liée**. Beaucoup de « ça ne fait rien » viennent de là, pas d'un bug PLC.
- **Périmètre strict** : comment configurer les commandes d'un écran. Quoi câbler dans `GVL_IHM`
  → AF07. Nommage des variables → `NAMING_CONVENTION.md`.
- **Rappel cadre** : la Visu est créée **manuellement dans l'IDE** ; elle ne transite **pas** par
  le bundle PLCopenXML et **aucun gate ne vérifie son câblage** (voir §7).

---

## 🧱 2. Le socle : comment tourne une Runtime Visualization

| Fait | Conséquence pratique |
|---|---|
| La Visu s'exécute dans la **tâche** affectée au Visualisation Manager (par défaut la 1ʳᵉ tâche de la config) | Le rafraîchissement écran = cycle de cette tâche ; une Visu réactive mérite une tâche dédiée (ex. 200 ms) |
| Le code Visu est **interprété au runtime**, pas compilé avec l'appli | Moins performant que TargetVisu ; les handlers longs **gèlent tout l'affichage** |
| Une commande Visu s'exécute **au moment de l'événement** (clic…), dans le contexte de la tâche Visu | Écriture immédiatement visible, mais consommée par le PLC au **cycle suivant** — jamais « temps réel » |
| Les variables liées doivent être **accessibles** (GVL publiques, variables de POU exposées) | Une variable locale de FB n'est pas accessible à la liaison ; pour WebVisu avec accès restreint, cocher l'**accès public** de la variable |

---

## 🧰 3. Catalogue des commandes (onglet « Commandes » d'un élément)

### 3.1 · Compatibilité par type de Visu

| Commande | CODESYS Visu (Runtime) | TargetVisualization | Commentaire |
|---|---|---|---|
| `Set` / `Reset` / `Toggle` | ✅ | ✅ | Variable liée **BOOL uniquement** |
| `Write value` | ✅ | ✅ | Écrire une valeur littérale/constante dans la variable liée |
| Dialogue d'édition (`Dialog: Edit`) | ✅ | ❌ | Saisie opérateur, Runtime seulement |
| `Show message` / message box | ✅ | partiel | Boîtes texte/confirmation |
| Screen : afficher / suivant / précédent | ✅ | ✅ | Nécessite plusieurs **écrans** dans le même Visu Manager |
| `Login` / `Logout` | ✅ | ❌ | Gestion utilisateurs CODESYS runtime |
| **`Eval ST`** (code ST libre) | ✅ | ❌ | La commande « passe-partout » — Runtime uniquement |
| `Start` / `Stop` / `Reset Origin` (PLC) | ✅ | ✅ | ⛔ **Ne jamais exposer** `Stop` PLC au poste opérateur (la coupure brutale est réservée à la chaîne AU physique — `AGENTS.md`) |

### 3.2 · Compatibilité par type d'élément et de variable liée

| Élément / liaison | Commandes possibles | Piège |
|---|---|---|
| Button, Rectangle, Bitmap… avec variable **BOOL** | `Set`, `Reset`, `Toggle` | Sur une liaison REAL, les options Set/Reset sont **grisées** — ce n'est pas un bug |
| Variable **numérique** (INT, REAL…) | `Write value`, dialogue d'édition | `Write value` sur BOOL est possible mais **déconseillé** : préférer Set/Reset (sémantique) |
| Variable **STRUCT / DUT** en liaison directe | lecture seulement (champs individuels liables) | Lier un champ (`GVL_IHM.Modes.Cmd.BtnX`), jamais le struct entier pour une commande |
| Élément **sans variable liée** | uniquement les commandes qui n'écrivent pas (écran, message, Eval ST) | « Rien ne se passe » = souvent la variable liée est absente ou mal typée |
| Élément **Sandbox / composé** | commandes sur les enfants | Les événements du parent ne propagent pas automatiquement les commandes |

---

## ⚡ 4. Événements — l'autre source de « particularités »

| Événement | Déclencheur | Particularité |
|---|---|---|
| `Click` | relâchement après appui | Le plus simple ; idéal « impulsion » |
| `Press` | appuyer | ⚠️ **`Release` n'est reçu QUE si le handler `Press` renvoie `TRUE`** — grand classique des boutons « qui restent enfoncés » |
| `Release` | relâcher | Inutile sans Press préalable |
| `Motion` | défilement molette | éléments sensibles requis |
| `Enter` / `Leave` | curseur entre/sort | effets visuels uniquement, pas de commande métier |
| `Update` | redraw écran | 🚫 **Ne jamais y écrire une commande** : il repart à chaque rafraîchissement → niveau au lieu d'un front |

**Retour `BOOL` des handlers** : dans une commande `Eval ST`, la valeur retournée pilote la
reprise des événements (cf. Press ci-dessus). Retourner `FALSE` par inadvertance casse le bouton.

---

## 🧪 5. Expressions dans les propriétés d'élément (invisibilité, couleur, texte…)

Plusieurs propriétés (onglet « Général » → cases « invisible », couleur de remplissage, etc.)
acceptent une **expression ST booléenne** (`<Dialog…>` sur le champ). Elle est **relue à chaque
rafraîchissement** de l'écran (cycle de la tâche Visu, cf. §2) — en **lecture seule** : une
expression ne fait jamais écrire une variable.

### 5.1 · Exemple projet — bouton visible seulement en mode maintenance N1

```iecst
(* Propriété « invisible » du bouton *)
GVL_IHM.Modes.State.CurrentMode <> E_Mode.MAINT_N1
```

| Maillon | Fait vérifié dans le code |
|---|---|
| Variable liée | `GVL_IHM.Modes.State.CurrentMode : E_Mode` (`ST_ModesState.st`) |
| Producteur unique | `PRG_07_Supervision.st` : `GVL_IHM.Modes.State.CurrentMode := PRG_03_Modes_Cycle.Data.Auth.Mode` |
| Énum | `E_Mode` (`CODE/F_MODES/E_Mode.st`) — comparables : `DISABLE`, `MAINT_N1`, `MAINT_N2`, `SEMI_AUTO` |

### 5.1bis · Les deux comparaisons sont valides — la **polarité de la propriété** change tout

La propriété s'appelle « **invisible** » : polarité négative, `TRUE` = **masqué**. `=` et `<>`
sont tous deux des écritures correctes, mais de sens **opposé** :

| Écriture dans « invisible » | Effet réel à l'écran |
|---|---|
| `GVL_IHM.Modes.State.CurrentMode <> E_Mode.MAINT_N1` | Bouton visible **seulement en N1** (masqué partout ailleurs) |
| `GVL_IHM.Modes.State.CurrentMode = E_Mode.MAINT_N1` | Bouton **masqué en N1**, visible dans les autres modes |

⚠️ **Règle de lecture** : raisonner toujours en terme affiché (« dans quel mode je VEUX le voir ? »)
et traduire dans le sens de la propriété. Un `<>` lu trop vite comme un `=` inverses l'effet —
c'est un défaut d'écran, pas de PLC.

### 5.2 · Règles d'écriture

| Règle | Exemple |
|---|---|
| Littéral d'énum **nommé** : `NomEnum.Membre` — jamais le pendant numérique | ✅ `E_Mode.MAINT_N1` · ❌ `<> 2` (magic number illisible et fragile au re-encodage) |
| Combinaison avec `=`, `<>`, `AND`, `OR`, `NOT` + parenthèses explicites | `NOT ((mode = E_Mode.SEMI_AUTO) OR (mode = E_Mode.DISABLE))` |
| Toujours lier **`GVL_IHM.*.State`** (état produit par le PLC) — jamais un `.Cmd` ni une variable interne de FB/PRG non exposée | la Visu ne reflète que ce qui est publié (AF07) |
| Expression = affichage, **pas arbitrage** | si la logique de visibilité devient un `IF` compliqué, c'est que le PLC doit publier un booléen dédié (ex. `BtnVisible_DI`-like dans `ST_*State`) |
| Coût | relue à chaque cycle Visu → pas d'appel de fonction lourd, pas de boucle |

### 5.3 · Champ « Texte » avec variables formatées (`%d`, `%f`, `%2.2f`…)

Un élément de texte peut embarquer des **espaces de format type printf** dans sa propriété
« Texte » ; les variables correspondantes se déclarent dans le champ **« Variables… »** de
l'élément et sont mappées **dans l'ordre** (1ʳᵉ variable ↔ 1ᵉʳ `%`).

| Format | Type attendu de l'expression liée | Rendu |
|---|---|---|
| `%d` | INT / DINT / USINT… (entier) | entier signé |
| `%f` | REAL / LREAL | flottant (beaucoup de décimales par défaut) |
| `%2.2f` (format `%largeur.précisionf`) | REAL / LREAL | flottant à **2 décimales** (la largeur ne limite PAS les décimales, seul `.2` le fait) |
| `%s` | STRING / WSTRING | texte — idéal pour les chaînes préparées par le PLC (`CycleStateStr`, bannière `FB_Hmi_BannerFormatter`) |

Exemple projet — affichage position câble M1 (2 décimales, unité affichée) :

```text
(* Propriété « Texte » *)
Position M1 : %2.2f m

(* Champ « Variables… » de l'élément, en 1ʳᵉ position *)
GVL_IHM.M1TreuilRetenue.State.Position_M
```

| Maillon | Fait vérifié dans le code |
|---|---|
| Variable | `Position_M : REAL` (`ST_WinchState.st`, suffixe unité NC-030 = mètres) |
| Producteur | `PRG_07_Supervision.st` : `GVL_IHM.M1TreuilRetenue.State := PRG_04_Treuils_Benne.Data.WinchM1State` |

**Pièges du texte formaté** :

1. **Appariement positionnel** : insérer/retirer une variable dans « Variables… » décale tous les
   `%` suivants → vérifier l'ordre après toute modification.
2. **Format ≠ type** : `%d` sur un REAL affiche une valeur incohérente (pas de conversion
   implicite) ; le format doit correspondre au type de l'expression.
3. **Pas de conversion d'unité automatique** : `Position_M` est en **mètres** ; pour afficher en
   mm, écrire l'arithmétique dans le champ Variables (`GVL_IHM.M1TreuilRetenue.State.Position_M * 1000.0`)
   ET l'unité dans le texte — ne jamais laisser l'opérateur deviner l'unité.
4. **Booléens et énums au format `%d`** : affiche `0`/`1` ou un numéro brut — interdit pour un
   état machine ; préférer un élément dédié (couleur, case à cocher) ou une chaîne publiée par
   le PLC en `%s`.
5. Séparateur décimal selon la **locale** du client de visualisation → fige la mise en page
   (point vs virgule) ; à trancher au MES.

### 5.4 · Action au clic : « On mouse click » → « Exécuter le code » (Eval ST)

Le bouton avancé configure l'événement **Click** (press + relâchement) avec la commande
**Eval ST** (§3.1) : le code est exécuté **une fois par clic**. C'est l'emplacement correct pour
un « gros » bouton, dès que l'action n'est pas un simple Set/Reset booléen.

Exemple projet — sélecteur de mode maintenance N1 :

```iecst
(* On mouse click > Exécuter le code — ÉCRITURE CORRECTE *)
GVL_IHM.Modes.Cmd.SelMode := E_Mode.MAINT_N1;

(* ⚠️ NE JAMAIS ÉCRIRE *)
GVL_IHM.Modes.Cmd.SelMode := 1;   (* magic number : fonctionne tant que MAINT_N1 = 1… *)
```

| Point | Règle |
|---|---|
| Pourquoi pas `1` | `E_Mode` (`CODE/F_MODES/E_Mode.st`) vaut `MAINT_N1 := 1` AUJOURD'HUI ; insérer un membre ou renuméroter ferait sélectionner **un autre mode en silence** — dont `MAINT_N2` (bypasses autorisés). Défaut de sécurité, pas de style. |
| Sémantique de `SelMode` | **Commande maintenue** (sélecteur, pas impulsion) : le `:=` reste écrit, aucun `Reset` à faire — cf. AF07 « commandes maintenues ou fronts » |
| La Visu demande, le PLC arbitre | `FB_Modes` peut **refuser** la sélection (ex. `SEMI_AUTO` + `EncoderFault`, N2 filtré) : le retour visuel se lit sur `GVL_IHM.Modes.State.CurrentMode`, pas sur le clic (§5.1 : l'élément « mode sélectionné » se pilote en visibilité depuis le State) |
| Filtre N2 | Un bouton écrivant `E_Mode.MAINT_N2` doit être **masqué** hors conditions d'accès (propriété invisible, §5.1bis) — le commentaire `ST_ModesCmd.st` le prévoit côté IHM |
| Contenu du script | Une seule écriture dans un champ `GVL_IHM.*.Cmd` ; pas de calcul, pas de `IF` métier (§7) |

---

## 🧨 6. Pièges connus (retour d'expérience IDE)

1. **Élément non réactif** → cocher la propriété *sensible aux entrées* (interactive) de l'élément.
2. **`Write value` qui « n'écrit pas »** : type non conforme (REAL↔BOOL), variable liée hors portée,
   ou l'élément est dans un écran différent de celui affiché.
3. **Bouton qui colle** : Press sans retour `TRUE`, ou `Set` sans `Reset` nulle part → niveau au
   lieu d'une impulsion.
4. **Handler `Eval ST` bloquant** : une boucle ou un Sleep dans le script **fige toute la Visu**
   (la tâche Visu attend). Jamais de logique dans les scripts — appeler un FB, pas un algorithme.
5. **Édition de valeur sur un `*.Rq` réglable** : la saisie se fait dans la langue/unité affichée —
   vérifier le formatage numérique de l'élément, source fréquente de « je tape 1,5 et ça met 15 ».
6. **Copier-coller d'écrans entre projets** : les scripts `Eval ST` suivent, les noms de variables
   liés **pas toujours** (recherche/remplacement systématique à faire après collage).
7. **WebVisu ne montre rien** : serveur de visualisation non activé dans la Configuration runtime
    du PLC, ou variables sans *accès public*, ou runtime sans licence Visu (plateformes embarquées).

---

## 📏 7. Règles projet (non négociables, appliquées à la Visu)

| Règle | Traduction en Visu |
|---|---|
| Producteur unique | Une variable `GVL_IHM.*.Cmd` n'est écrite **que** depuis la Visu ; le PLC ne l'écrit jamais (il produit `*.State`) |
| `Reset` = front | Bouton défaut : `Set` sur `Press` **et** `Reset` sur `Release` (ou Toggle), pour que le PLC voie un front conscient — jamais un maintien automatique côté Visu |
| Jamais de redémarrage auto | Aucun bouton ne fait un `Set` tout seul sans action opérateur visible ; pas de `Write value` dans un event `Update` |
| AF07 seule interface | Les commandes Visu pointent exclusivement des champs `GVL_IHM` déclarés dans AF07 — pas de variables maison « créée pour la Visu » |
| Troubleshooting = lecture seule | Les éléments de la vue dépannage n'ont **aucune** commande d'écriture (`AF_Partie-02`) |
| `Eval ST` sobre | Un script `Eval ST` ne fait qu'appeler une méthode/instance prévue à cet effet, jamais de calcul ni de `IF` métier |

⚠️ **Contrôle** : `G200_check_linkage.py` valide le câblage **PLC** (bundle XML), pas les écrans
Visu. Le câblage Visu → `GVL_IHM` se relit **manuellement** contre AF07 à chaque livraison d'écran.

---

## ✅ 8. Checklist de livraison d'un écran

- [ ] Chaque commande écrite pointe un champ `GVL_IHM.*.Cmd` existant dans AF07
- [ ] Expressions de visibilité/couleur : comparaisons nominales sur `GVL_IHM.*.State` uniquement (`E_Mode.MAINT_N1`, jamais de valeur numérique brute)
- [ ] Aucun événement `Update` avec écriture
- [ ] Tout bouton-impulsion a son `Set` ET son `Reset` (sémantique front)
- [ ] Pas de commande `Stop` PLC exposée opérateur
- [ ] Éléments réactifs : propriété sensible aux entrées cochée
- [ ] Types variables liées conformes (BOOL ↔ Set/Reset/Toggle)
- [ ] `Eval ST` = appel simple, pas de logique
- [ ] `Eval ST` : écritures en littéraux **nommés** (`E_Mode.MAINT_N1`), jamais numériques, et maintenance N2 filtrée par invisibilité
- [ ] Textes formatés : ordre `%` ↔ Variables cohérent, format conforme au type, unité affichée dans le texte

---

## 🔗 9. Références

- [`AF_Partie-07_Interface_IHM_v2.2.md`](../../AF/AF_Partie-07_Interface_IHM_v2.3.md) — contrats de données IHM
- [`AF_Partie-01_Analyse_Fonctionnelle_v2.1.md`](../../AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md) §6 — modèle de commande et d'arrêt (front, AU)
- [`NAMING_CONVENTION.md`](../NAMING_CONVENTION.md) — noms des écrans, boutons, variables liées
- Aide CODESYS 3.5 : *Visualization > Elements > Commands / Events*
