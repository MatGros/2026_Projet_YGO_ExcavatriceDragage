# Recommandation ergonomique — Cockpit Superviseur

## 0. Note de périmètre (à lire une fois)

Je n'ai pas ouvert `TOOLS/AGENT_SUPERVISOR/ui/index.html` dans ce tour : **aucune vérification du fichier réel**. Ce qui suit s'appuie sur (a) les faits que vous énoncez (70 `<details>`, actions sous accordéon, chemins en texte brut, drops silencieux côté adaptateurs, service 8082 sans alerte) et (b) le référentiel D06–D16. Les propositions sont formulées avec des **critères d'acceptation observables**, pour être validées ensuite contre le fichier réel — c'est ce qui remplace ici la preuve terrain. Tout ce qui dépend de détails d'implémentation (noms de classes, structure exacte du DOM, présence d'un flux temps réel ou d'un simple refresh) est marqué comme *inférence* ou *inconnue*.

---

## 1. Diagnostic : pourquoi l'IHM actuelle produit un sentiment de « boîte noire »

Le problème n'est pas esthétique, il est **causal**. L'IHM actuelle donne des *résultats* sans donner la *chaîne qui les produit* : l'exploitant ne peut pas répondre, en moins de 3 secondes, aux trois seules questions qui comptent dans un cockpit de supervision :

1. **Est-ce que ça tourne ?** (le système est-il vivant, en pause, en rupture ?)
2. **Qu'est-ce qui vient d'arriver ?** (quel événement, d'où, avec quelle conséquence ?)
3. **Qu'est-ce que je dois faire ?** (quelle action, sur quel objet, maintenant ?)

### 1.1 Frictions classées par coût cognitif

| # | Friction | Mécanisme de la charge | Effet opérateur |
|---|---|---|---|
| F1 | **70 `<details>` imbriqués** | Profondeur > 3 niveaux ⇒ navigation *pull* : il faut se souvenir où est l'info. La mémoire de travail est consommée par la recherche, plus par le jugement. | « Je suis mené en bateau » ; perte de confiance dans l'exhaustivité (« est-ce que j'ai raté un truc ? »). |
| F2 | **Aucune preuve de vie** (pas de heartbeat, pas de timer, pas d'horodatage par zone) | Silence = **deux significations opposées** : « rien à signaler » ou « c'est mort ». Ambiguïté non résolvable par l'écran. | Angoisse, vérifications manuelles répétées, sur-sollicitation du service. |
| F3 | **Drops silencieux d'adaptateurs** | Perte de donnée *invisible* ⇒ violation du principe de conservation. L'opérateur ne peut pas savoir ce qu'il ne voit pas. | Le pire défaut possible pour un superviseur : **la confiance devient une croyance**. |
| F4 | **Actions sous accordéon** | Coût de 2 clics + **perte du contexte visuel** (on ne voit plus l'objet pendant qu'on agit). | Erreurs d'action sur le mauvais objet ; actions évitées. |
| F5 | **Chemins en texte brut** | Copier-coller manuel = source d'erreur, et **pas de vérification visuelle** que le chemin affiché est le fichier réel. | Rupture de la traçabilité affichée → traçabilité perçue. |
| F6 | **Chat superviseur en haut** | Mélange deux régimes temporels incompatibles : la conversation (asynchrone, délibérative) et le monitoring (synchrone, scannable). | Le premier regard est volé par du bavardage au lieu de l'état. |
| F7 | **Typo du compteur** `Constats · 0   ✓ rien à suivre` | Chaîne hétérogène (séparateur `·`, espaces multiples, glyphe `✓` dans le flux de texte) ⇒ pas d'alignement, pas de colonne, pas de tabularité. | Le compteur ne se lit pas « d'un coup d'œil » ; il se *déchiffre*. |
| F8 | **Pas de règle de vieillissement** | Densité non bornée ⇒ encombrement progressif, les constats actifs se noient dans les clos. | Cécité au signal. |
| F9 | **Couleur seule / absence d'état explicite** | Un point vert sans libellé n'est pas un état, c'est une décoration. | Inutilisable en daltonisme, en capture d'écran, en revue asynchrone. |

### 1.2 Le vrai anti-pattern à nommer

L'IHM actuelle est une **archive déguisée en tableau de bord**. Elle stocke (accordéons = stockage), elle ne *raconte* pas. Un cockpit temps réel doit être un **pipeline lisible** : une entrée, des transformations, une sortie, chaque étape montrant son compteur d'entrée, son compteur de sortie et **la raison de chaque écart**.

---

## 2. Wireframe textuel du nouveau cockpit

Principe directeur : **un seul axe de lecture vertical**, de la donnée brute vers la décision, avec une colonne latérale « état + commandes » toujours visible. Tout ce qui est conversationnel ou administratif est **sous la ligne de flottaison et replié**.

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║ ● COLLECTE ACTIVE · scan #482 · prochain dans 00:07 · dernier il y a 12 s     ║  ← barre de statut globale (sticky, 1 ligne)
║   [Pause]                                                                     ║     état + timer en Hz ≤ 1, aria-live="polite"
╚═══════════════════════════════════════════════════════════════════════════════╝
┌──────────────────────┬────────────────────────────────────────────────────────┐
│ RAIL GAUCHE (280px)  │  FLUX — colonne unique, lecture haut → bas            │
│ sticky               │                                                        │
│ ┌──────────────────┐ │ ┌─ ① SOURCE / ÉVÉNEMENTS CAPTURÉS ───────────────────┐ │
│ │ ● COLLECTE       │ │ │ Entrées 1 284 = retenus 12 + écartés 1 269        │ │
│ │   ACTIVE         │ │ │                + jetés 3 ⚠ + erreurs 0     ✓       │ │
│ │   (vert + texte) │ │ ├────────────────────────────────────────────────────┤ │
│ └──────────────────┘ │ │ 00:12  hook    prompt.md:44      → retenu         │ │
│                      │ │ 00:12  scan    src/a.py:12       → retenu         │ │
│ TESTS (D06/D07)      │ │ 00:11  adapt.  payload.json      → JETÉ (schéma) ⚠│ │
│  [🔊 1 bip]          │ │                                        [journal ▸] │ │
│  [🔊 2 bips]         │ └────────────────────────────────────────────────────┘ │
│  [🔔 Notif VS Code]  │                                                        │
│                      │ ┌─ ② FILTRAGE ───────────────────────────────────────┐ │
│ ALERTE SERVICE (D16) │ │ Retenus 12  │  Écartés 1 269                          │ │
│ ┌──────────────────┐ │ │ ⚠ 3 jetés par adaptateur — non silencieux  [voir] │ │
│ │ ▲ SERVICE 8082   │ │ │ Règles appliquées : R-01, R-07 …        [détail ▸] │ │
│ │   INJOIGNABLE    │ │ └────────────────────────────────────────────────────┘ │
│ │ depuis 42 s      │ │                                                        │
│ │ [Réessayer]      │ │ ┌─ ③ JUGEMENT ───────────────────────────────────────┐ │
│ └──────────────────┘ │ │ ✔ GO   confiance 0.92   règle R-07                  │ │
│                      │ │   cible src/a.py:12                  [trace ▸]     │ │
│ SOMMAIRE             │ │ ─────────────────────────────────────────────────── │ │
│  ① Source            │ │ ✕ NO-GO  motif : schéma invalide                    │ │
│  ② Filtrage          │ │   cible payload.json                                │ │
│  ③ Jugement          │ └────────────────────────────────────────────────────┘ │
│  ④ Constats          │                                                        │
│  ⑤ Système           │ ┌─ ④ CONSTATS & ACTIONS ──────────────────────────────┐ │
│  ⑥ Chat              │ │ Constats · 0      ✓ rien à suivre   ▓▓▓▓▓▓▓▓▓ 9/9   │ │
│                      │ │  (D13 tabular-nums)                  (D14 vert)    │ │
│                      │ ├────────────────────────────────────────────────────┤ │
│                      │ │ ▸ C-012  GO — src/a.py:12         il y a 3 s       │ │
│                      │ │   [Relancer] [Acquitter] [Archiver] [Ouvrir ↗]     │ │
│                      │ │ ▸ C-011  …                                         │ │
│                      │ │ max 5 ouverts · Archive des constats (12) ↗        │ │
│ [Chat (3) ▸]         │ └────────────────────────────────────────────────────┘ │
│                      │                                                        │
│                      │ ▸ ⑤ SYSTÈME / ADMIN (replié par défaut)               │
│                      │ ▸ ⑥ CHAT SUPERVISEUR (3 non lus, replié)              │
└──────────────────────┴────────────────────────────────────────────────────────┘
```

### 2.1 Détail des zones

**Barre de statut globale (sticky, en haut)** — répond à « est-ce que ça tourne ? » sans scroll. Contenu : pastille D12 + libellé, n° de cycle, **compte à rebours du prochain scan** (`00:07`, mis à jour à 1 Hz max, pas à chaque frame), ancienneté du dernier scan (`il y a 12 s`), bouton `Pause`. En rupture 8082 : la barre passe en état `degraded` (fond rouge très désaturé) **en plus** de l'alerte du rail.

**Rail gauche (sticky, 280 px)** — c'est la zone de *contrôle*, pas de contenu :
- **D12** étiquette de collecte : `● COLLECTE ACTIVE` / `● COLLECTE EN PAUSE` / `● COLLECTE ROMPUE`. Couleur **+ libellé texte + forme** (rond plein / demi / croix). Jamais la couleur seule.
- **D06/D07** groupe « Tests » : `1 bip`, `2 bips`, `Notif VS Code`. Trois boutons de taille cible ≥ 44 px, visibles **sans aucun dépliage**, libellés en clair, `aria-label` explicite (« Émettre 1 bip de test »).
- **D16** alerte 8082 : bandeau rouge **persistant** (pas de toast qui s'efface, pas d'auto-dismiss), avec `depuis 42 s`, bouton `Réessayer`, et — point clé — **le rail entier prend un liseré rouge** pour que l'alerte soit perceptible même hors zone de regard.
- Sommaire cliquable des 6 zones (ancres) : c'est le seul « menu » autorisé, et il ne cache rien.

**① Source / Événements capturés** — le flux brut, horodaté, sans jugement. Chaque ligne porte un lien `<a>` sur son chemin. En-tête : **l'équation de conservation** (voir R1).

**② Filtrage** — la zone qui manque le plus aujourd'hui. Deux colonnes *Retenus / Écartés* + **le compteur de rejets d'adaptateur** en évidence (`⚠ 3 jetés`), cliquable vers un journal. C'est ici que se joue la transparence : « pourquoi cette ligne n'est pas allée plus loin ».

**③ Jugement** — une carte par décision : verdict, confiance, **règle appliquée**, cible cliquable, lien `trace`. La carte montre déjà l'essentiel (3 lignes) ; le détail s'ouvre en **drawer latéral**, jamais en `<details>` (voir R3).

**④ Constats & Actions** — le cœur de l'action :
- Compteur D13 retravaillé : `Constats · 0` en chiffres tabulaires, séparateur `·` avec marges fixes, `✓ rien à suivre` dans une **colonne dédiée** alignée sur la même ligne de base (pas dans le flux de la phrase).
- **D14** jauge de complétude dans l'en-tête de zone : barre segmentée + `9/9` + libellé. Seuils : `< 8` rouge, `= 8` orange, `≥ 9` vert. Le chiffre est toujours écrit ; la couleur le double, elle ne le remplace pas.
- **D11** maximum **5 constats ouverts**. Le 6ᵉ plus ancien sort automatiquement vers `Archive des constats (N) ↗` — lien, pas accordéon — avec un toast sobre « 1 constat archivé — Annuler » (le toast est un confort, **jamais** le seul canal d'information).
- Boutons d'action **directement sur la carte** : `Relancer`, `Acquitter`, `Archiver`, `Ouvrir ↗`. Visibles en permanence ; sur écran dense, opacité réduite mais **jamais `display:none`**, et pleinement visibles au `:focus-within` (clavier).

**⑤ Système / Admin** — **replié par défaut**. C'est le **seul** `<details>` que je conserve : ce n'est pas du flux, c'est de la maintenance. Contenu : santé 8082, latence, uptime, version, journaux, redémarrage (avec confirmation).

**⑥ Chat Superviseur** — **D15** : ancré en bas de page, `replié` au chargement, rendu **après** les zones 1–5 dans le DOM. Un compteur de non-lus dans le rail suffit à signaler l'activité sans voler le premier regard.

### 2.2 Variantes d'état à maquetter (obligatoires)

| État | Barre globale | Rail gauche | Zone ④ |
|---|---|---|---|
| Nominal | vert, timer actif | `● ACTIVE` vert | jauge verte, 0–5 constats |
| Pause | orange, timer figé + « en pause depuis X » | `● EN PAUSE` orange | inchangé, horodatages vieillissants |
| Rupture 8082 | rouge, « dernier contact il y a Xs » | liseré rouge + bandeau D16 | bandeau « actions indisponibles » sur les boutons |
| Drops > 0 | normal | normal | badge `⚠ 3 jetés` + entrée dans le journal |
| Erreur adaptateur | normal | pastille erreur | bandeau + constat auto-généré |

---

## 3. Règles de design pour un flux 100 % transparent

Ce sont les règles que je pose comme **non négociables**. Elles sont numérotées pour être citées en revue.

### R1 — Conservation de la donnée affichée (l'invariant fondateur)
Toute entrée a **exactement un état terminal visible** : `retenu` | `écarté(règle)` | `jeté(adaptateur, motif)` | `erreur`. L'en-tête de la zone ① affiche l'équation :

> `Entrées 1 284 = retenus 12 + écartés 1 269 + jetés 3 + erreurs 0  ✓`

Si l'égalité ne tient pas, **c'est un bug d'adaptateur** et l'IHM affiche un bandeau d'alerte. C'est le garde-fou anti-« boîte noire » : un résultat ne peut plus être jeté en silence, il est *compté quelque part*.

### R2 — Le silence a toujours un nom
Aucune zone ne peut être vide. Une zone sans données affiche un **état explicite** : `aucun événement depuis 00:42 — collecte active`, `collecte en pause depuis 3 min`, `service injoignable`. « Vide » n'est pas un état, c'est une ambiguïté.

### R3 — Une seule profondeur d'expansion
- **Zéro `<details>` dans les zones ①–④.** Critère mesurable : `document.querySelectorAll('flux details').length === 0`.
- Le seul mécanisme d'expansion du flux est le **drawer latéral** (contexte visuel préservé, pas de reflow vertical, fermeture `Échap`).
- Le seul `<details>` toléré est la zone ⑤ (admin).

### R4 — L'action est au plus près de l'objet
Les boutons vivent sur la carte de l'objet concerné, pas dans un panneau global, pas sous un dépliant. Ils sont dans le DOM et atteignables au clavier en permanence.

### R5 — Tout chemin est un lien
Toute occurrence de chemin de fichier ou de `fichier:ligne` est rendue en `<a>` :
- `href="file:///…"` (ou `vscode://file/…` si le protocole est disponible), `title` = chemin absolu,
- bouton `Copier` adjacent,
- format `src/a.py:12` ⇒ lien vers le fichier **et** ancre de ligne.
Critère : aucun chemin ne doit apparaître dans un nœud texte sans ancêtre `<a>`.

### R6 — La couleur n'est jamais seule
Vert/Orange/Rouge toujours doublés d'un **libellé** et d'une **forme** (● / ▲ / ✕). Cela couvre le daltonisme, la capture d'écran en niveaux de gris et la revue asynchrone du rapport.

### R7 — Le temps est explicite et à deux faces
Chaque zone affiche `dernière mise à jour il y a Xs`. La barre globale affiche **dernier scan** *et* **prochain scan** (compte à rebours). Horodatages : relatif à l'écran, absolu dans le `title`. Une seule source de vérité pour l'horloge (le serveur), pas une par widget.

### R8 — Aucune animation qui mente
Clignotement réservé à l'état de rupture ; respect de `prefers-reduced-motion` ; pas de skeleton loader sur des données déjà en cache ; les mises à jour périodiques utilisent `aria-live="polite"`, **jamais** `assertive`.

### 3.1 Règles typographiques et de densité

| Sujet | Règle |
|---|---|
| Échelle | 12 / 13 / 14 / 20 / 28 px. Pas de police < 12 px pour du contenu lu. |
| Chiffres | `font-variant-numeric: tabular-nums` sur **tous** les compteurs, timers, latences (D13). |
| Grille | Espacement sur une base de 4 px ; marges du séparateur `·` = 8 px fixes (D13). |
| Alignement du compteur | `Constats · 0` et `✓ rien à suivre` sur **deux colonnes** de la même ligne de base, glyphe `✓` dans sa propre colonne. |
| Contraste | AA minimum (4,5:1 texte, 3:1 éléments d'interface) ; l'orange « pause » est le piège classique sur fond clair — le vérifier explicitement. |
| Densité | Max **7 ± 2** items visibles par zone avant scroll ; zones ①–④ tiennent dans **un écran** à 1280×800. Au-delà : virtualisation, pas d'accordéon. |
| Vieillissement | D11 : ≤ 5 constats ouverts ; sortie automatique du plus ancien ; archive consultable. |
| Casse | Phrases en casse de phrase ; majuscules réservées aux étiquettes d'état courtes (`COLLECTE ROMPUE`). |

---

## 4. Traçabilité des exigences → critères d'acceptation

| Exigence | Composant | Critère vérifiable |
|---|---|---|
| **D06/D07** | Rail gauche, groupe « Tests » | Les 3 boutons sont visibles **sans interaction** à 1280×800 ; aucun `<details>` ancêtre ; `aria-label` présents. |
| **D11** | Zone ④ | ≤ 5 constats ouverts rendus ; le 6ᵉ est archivé ; lien `Archive (N)` présent et fonctionnel. |
| **D12** | Rail gauche | 3 états distincts, chacun avec couleur **+ libellé** ; `aria-live="polite"` sur le changement d'état. |
| **D13** | Zone ④ | `tabular-nums` effectif ; `·` à 8 px ; `✓` dans une colonne dédiée alignée. |
| **D14** | En-tête zone ④ | 3 seuils rendus (<8 rouge / 8 orange / ≥9 vert) ; **chiffre toujours affiché**. |
| **D15** | Zone ⑥ | Replié au chargement ; dernier enfant du `<main>` ; n'occupe pas le premier écran. |
| **D16** | Rail gauche + barre globale | Alerte rouge **persistante** tant que 8082 est KO (aucun auto-dismiss) ; horodatage du dernier contact ; bouton `Réessayer`. |
| **Suppression `<details>`** | Zones ①–④ | `main details` → 0 occurrence. |
| **Liens cliquables** | Zones ①–⑤ | Tout chemin / `fichier:ligne` a un ancêtre `<a>` ; `title` = chemin absolu. |
| **Timer de scan** | Barre globale | Compte à rebours visible, décompte à 1 Hz, avec état explicite à l'expiration. |

---

## 5. Ce que je tranche, et ce que je refuse

**Je tranche :**
1. **Les `<details>` disparaissent du flux.** Un seul survit, en admin. C'est la décision structurante : sans elle, tout le reste est cosmétique.
2. **Une barre de statut globale en haut**, pas en bas : le premier pixel doit répondre à « est-ce que ça tourne ? ».
3. **Le chat descend et se replie** (D15). Il n'a aucune légitimité au-dessus de la ligne de flottaison.
4. **L'équation de conservation devient un élément d'interface** (R1). C'est ce qui transforme un adaptateur silencieux en composant observable.
5. **Un flux linéaire, pas une grille de tuiles KPI.** Une grille de tuiles donne des nombres sans causalité — exactement le reproche de « boîte noire », en plus joli. Le flux linéaire, lui, *raconte* : X entre → Y filtré → Z jugé → action.

**Je refuse explicitement :**
- Les tuiles KPI en page d'accueil (nombre sans cause).
- Toute action courante dans une modale.
- Un toast comme **seul** canal d'une perte de donnée (il s'efface ; le journal, non).
- Un loader bloquant sur des données déjà connues.
- Un compteur « temps réel » qui se met à jour à la fréquence du scan plutôt qu'à 1 Hz : un timer qui saute est un timer auquel on ne croit pas.

---

## 6. Inconnues à lever avant implémentation

1. **Le flux est-il réellement push (SSE/WebSocket) ou par polling ?** Toute la zone ① et les timers en dépendent. *Inconnue.*
2. **Les drops silencieux sont-ils instrumentés côté adaptateur** (compteur exposé) ou faut-il les instrumenter ? R1 exige un compteur ; s'il n'existe pas, c'est une modification backend, pas une retouche CSS. **C'est le point de périmètre le plus lourd.**
3. **Le service 8082 expose-t-il un endpoint de santé** pour distinguer « injoignable » de « lent » ? Sinon D16 ne pourra afficher qu'un booléen.
4. **Protocole disponible pour `vscode://`** dans l'environnement cible (navigateur, restriction d'ouverture de protocoles externes).
5. **Nombre réel de `<details>`** et leur répartition : le chiffre de 70 conditionne l'ampleur du chantier (réécriture vs refonte de template).

**Décision recommandée :** valider d'abord R1 et R3 (invariant de conservation + suppression des `<details>` du flux) — ce sont les deux règles qui produisent 80 % du gain de confiance. D06/D07, D11–D16 sont ensuite des ajustements localisés, chacun avec son critère d'acceptation ci-dessus.